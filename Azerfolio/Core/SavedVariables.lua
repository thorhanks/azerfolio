-- Loading, validating and migrating SavedVariables. Pure logic; no WoW API use.
local _, ns = ...

local SV = {}
ns.SavedVariables = SV

local function deepCopy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = deepCopy(x) end
    return out
end
SV.DeepCopy = deepCopy

local function isEmptyTable(t)
    return type(t) == "table" and next(t) == nil
end

-- Makes `saved` conform to `defaults`, in place. Returns the (possibly new) table and appends
-- a description of every correction to `fixes`.
--   * missing keys get the default
--   * values of the wrong type are replaced by the default
--   * enum paths must hold an allowed value; numeric range paths are clamped
--   * an empty default table is a free-form container: its saved contents are kept
--   * keys not in defaults are kept (forward compatibility)
local function normalize(saved, defaults, path, fixes, enums, ranges)
    if type(saved) ~= "table" then
        if saved ~= nil then fixes[#fixes + 1] = (path ~= "" and path or "<root>") .. ": not a table, reset" end
        return deepCopy(defaults)
    end
    for key, def in pairs(defaults) do
        local p = path == "" and key or (path .. "." .. key)
        local v = saved[key]
        if v == nil then
            saved[key] = deepCopy(def)
        elseif type(def) == "table" then
            if type(v) ~= "table" then
                fixes[#fixes + 1] = p .. ": expected table, reset"
                saved[key] = deepCopy(def)
            elseif not isEmptyTable(def) then
                saved[key] = normalize(v, def, p, fixes, enums, ranges)
            end
        elseif type(v) ~= type(def) then
            fixes[#fixes + 1] = string.format("%s: expected %s, got %s, reset", p, type(def), type(v))
            saved[key] = def
        else
            local allowed = enums and enums[p]
            if allowed and not allowed[v] then
                fixes[#fixes + 1] = string.format("%s: invalid value %q, reset", p, tostring(v))
                saved[key] = def
            end
            local range = ranges and ranges[p]
            if range and type(v) == "number" then
                if v ~= v then -- NaN
                    fixes[#fixes + 1] = p .. ": NaN, reset"
                    saved[key] = def
                elseif v < range[1] or v > range[2] then
                    fixes[#fixes + 1] = string.format("%s: %s out of range, clamped", p, tostring(v))
                    saved[key] = math.max(range[1], math.min(range[2], v))
                end
            end
        end
    end
    return saved
end
SV.Normalize = function(saved, defaults, enums, ranges)
    local fixes = {}
    local out = normalize(saved, defaults, "", fixes, enums, ranges)
    return out, fixes
end

-- Schema migrations. migrations[n] upgrades a table from version n-1 to n, in place.
SV.ACCOUNT_MIGRATIONS = {
    -- 2: the window default grew from 960x640 to the design size 1160x740. A size still at the
    -- old default was never chosen by the player, so it moves to the new one.
    [2] = function(db)
        local w = db.window
        if type(w) == "table" and w.width == 960 and w.height == 640 then
            w.width, w.height = 1160, 740
        end
    end,
    -- 3: the minimap button's default moved from 200 (on top of another addon's button) to 140.
    -- An angle still at the old default was never dragged, so it moves too.
    [3] = function(db)
        local l = db.launcher
        if type(l) == "table" and l.minimapAngle == 200 then l.minimapAngle = 140 end
    end,
    -- 4: the completion filter became the design's status segments. "completed" is now
    -- "complete"; "incomplete" (in progress or untouched) has no single segment, so it shows all.
    [4] = function(db)
        local z = db.zones
        if type(z) ~= "table" then return end
        if z.completion == "completed" then z.completion = "complete"
        elseif z.completion == "incomplete" then z.completion = "all" end
    end,
}
SV.CHAR_MIGRATIONS = {}

-- Applies migrations up to `target`. Data from a newer, unknown schema is discarded
-- (returns nil) because this code can't interpret it safely.
function SV.Migrate(saved, migrations, target, fixes)
    if type(saved) ~= "table" then return saved end
    local version = saved.schemaVersion
    if type(version) ~= "number" then
        if next(saved) ~= nil then fixes[#fixes + 1] = "schemaVersion missing, treated as current" end
        saved.schemaVersion = target
        return saved
    end
    if version > target then
        fixes[#fixes + 1] = string.format("schema %d is newer than supported %d, reset", version, target)
        return nil
    end
    while version < target do
        local step = migrations[version + 1]
        if step then step(saved) end
        version = version + 1
        saved.schemaVersion = version
        fixes[#fixes + 1] = "migrated to schema " .. version
    end
    return saved
end

-- Trims a list to its newest `limit` entries (newest are at the end).
function SV.TrimList(list, limit)
    if type(list) ~= "table" then return end
    local extra = #list - limit
    if extra <= 0 then return end
    for i = 1, #list - extra do list[i] = list[i + extra] end
    for i = #list, #list - extra + 1, -1 do list[i] = nil end
end

-- Free-form per-character lists are checked entry by entry (a hand-edited or damaged file must
-- not break the Overview): a milestone needs a known kind, a category and a numeric mapID; a
-- name that isn't text and a time that isn't a plausible positive number are dropped (the time
-- then reads "time not seen", never a made-up one). Recent zones keep only map IDs.
local function validTime(t) return type(t) == "number" and t == t and t > 0 and t < 4102444800 end -- before 2100

function SV.CleanMilestones(list, fixes)
    if type(list) ~= "table" then return {} end
    local out, dropped = {}, 0
    for i = 1, #list do
        local m = list[i]
        if type(m) == "table" and (m.kind == "area" or m.kind == "zone") and type(m.category) == "string"
            and type(m.mapID) == "number" and m.id ~= nil then
            if m.name ~= nil and type(m.name) ~= "string" then m.name = nil end
            if m.time ~= nil and not validTime(m.time) then m.time = nil end
            out[#out + 1] = m
        else
            dropped = dropped + 1
        end
    end
    if dropped > 0 and fixes then fixes[#fixes + 1] = string.format("character milestones: %d invalid entries dropped", dropped) end
    return out
end

function SV.CleanRecentZones(list, fixes)
    if type(list) ~= "table" then return {} end
    local out, dropped = {}, 0
    for i = 1, #list do
        local id = list[i]
        if type(id) == "number" and id == id and id > 0 then out[#out + 1] = id else dropped = dropped + 1 end
    end
    if dropped > 0 and fixes then fixes[#fixes + 1] = string.format("character recentZones: %d invalid entries dropped", dropped) end
    return out
end

-- Loads both SavedVariables tables. Returns account, char, fixes.
function SV.Load(account, char)
    local Config = ns.Config
    local fixes = {}

    account = SV.Migrate(account, SV.ACCOUNT_MIGRATIONS, Config.ACCOUNT_SCHEMA, fixes)
    local accountFixes
    account, accountFixes = SV.Normalize(account, Config.ACCOUNT_DEFAULTS, Config.ENUMS, Config.RANGES)
    for _, f in ipairs(accountFixes) do fixes[#fixes + 1] = "account " .. f end

    char = SV.Migrate(char, SV.CHAR_MIGRATIONS, Config.CHAR_SCHEMA, fixes)
    local charFixes
    char, charFixes = SV.Normalize(char, Config.CHAR_DEFAULTS)
    for _, f in ipairs(charFixes) do fixes[#fixes + 1] = "character " .. f end

    char.milestones = SV.CleanMilestones(char.milestones, fixes)
    char.recentZones = SV.CleanRecentZones(char.recentZones, fixes)
    SV.TrimList(account.trace, Config.LIMITS.trace)
    SV.TrimList(char.milestones, Config.LIMITS.milestones)
    SV.TrimList(char.recentZones, Config.LIMITS.recentZones)

    return account, char, fixes
end
