-- Exploration objectives for a zone, read live from the game's "Explore <zone>" achievement
-- criteria (Phase 1, docs/research/exploration-validation.md): objective ID = criteriaID,
-- completion = the criterion's done flag, per character. [verified-ingame]
-- This is the native-API reader; Phase 5 adds the generated catalogue, events and baseline.
-- The UI shows what this returns and never counts on its own.
local _, ns = ...

local Exploration = {}
ns.Exploration = Exploration

-- Zone achievements live in these categories (Eastern Kingdoms, Kalimdor). [verified-ingame]
Exploration.CATEGORIES = { 14777, 14778 }

local index -- [zone name] = achievementID, built once the game has achievement data

local function try(label, fn, ...) return ns.Debug.Try(label, fn, ...) end

-- Builds the name index. Returns nil (and caches nothing) if the game returned no
-- achievements yet, so a later call can try again.
local function buildIndex()
    if type(GetCategoryNumAchievements) ~= "function" or type(GetAchievementInfo) ~= "function" then
        return nil
    end
    local found, any = {}, false
    for _, cat in ipairs(Exploration.CATEGORIES) do
        local total = try("GetCategoryNumAchievements", GetCategoryNumAchievements, cat, true) or 0
        for i = 1, total do
            local id, name = try("GetAchievementInfo", GetAchievementInfo, cat, i)
            local zone = type(name) == "string" and name:match("^Explore (.+)$")
            if id and zone then found[zone] = id; any = true end
        end
    end
    return any and found or nil
end

-- Pure: summary counts from a criteria list. Unknown completion is counted separately and
-- never as done or not done.
function Exploration.Summarize(criteria)
    local s = { total = #criteria, done = 0, todo = 0, unknown = 0 }
    for _, c in ipairs(criteria) do
        if c.completed == true then s.done = s.done + 1
        elseif c.completed == false then s.todo = s.todo + 1
        else s.unknown = s.unknown + 1 end
    end
    return s
end

-- Exploration for a zone { mapID, name }:
--   { status = "tracked", achievementID, criteria = { { id, name, completed } }, summary }
--   { status = "untracked" }   the game has no Explore achievement for this zone
--   { status = "unavailable" } achievement data can't be read right now
function Exploration.ForZone(zone)
    index = index or buildIndex()
    if not index then return { status = "unavailable" } end
    local achID = zone and zone.name and index[zone.name]
    if not achID then return { status = "untracked" } end
    local n = try("GetAchievementNumCriteria", GetAchievementNumCriteria, achID)
    if type(n) ~= "number" then return { status = "unavailable" } end
    local criteria = {}
    for i = 1, n do
        local name, _, done, _, _, _, _, _, _, criteriaID = try("GetAchievementCriteriaInfo",
            GetAchievementCriteriaInfo, achID, i)
        local completed -- nil = unknown, unless the game returned a boolean
        if type(done) == "boolean" then completed = done end
        criteria[#criteria + 1] = { id = criteriaID, name = name, completed = completed }
    end
    return { status = "tracked", achievementID = achID, criteria = criteria,
        summary = Exploration.Summarize(criteria) }
end

-- For tests: forget the index.
function Exploration.Reset() index = nil end
