-- The Zones catalogue: every zone the client lists (Systems/Maps.lua) with its exploration
-- state (Systems/Exploration.lua, counts from ns.Progression), plus the catalogue's filters,
-- sorts and section groups (spec §6.2-6.4). The UI shows what this returns and never counts.
-- Everything except Zones.All() is pure, so tests can load it without the client.
--
-- The client gives no level ranges or faction territory (probe /azfdiag zones). Both come
-- from the hand-curated, unofficial guide in Data/Zones.lua (owner-approved); zones it
-- doesn't list stay unknown (nil).
local _, ns = ...

local Zones = {}
ns.Zones = Zones

-- Zone states (the design's state language, mockups/DESIGN.md).
Zones.COMPLETE = "complete"    -- every area confirmed discovered (Progression.trackedComplete)
Zones.PROGRESS = "progress"    -- some areas confirmed discovered
Zones.UNTOUCHED = "untouched"  -- every area confirmed not discovered
Zones.UNKNOWN = "unknown"      -- tracked, but the game's data doesn't settle it right now
Zones.UNTRACKED = "untracked"  -- no Explore achievement (capitals, Zephras Isle)

-- "For my level": a zone fits from LEVEL_REACH levels below its minimum to its maximum.
Zones.LEVEL_REACH = 3

---------------------------------------------------------------------------------------------
-- Entries
---------------------------------------------------------------------------------------------

-- Pure: a zone's state from its Exploration.ForZone result.
function Zones.StateOf(ex)
    if not ex or ex.status == "untracked" then return Zones.UNTRACKED end
    if ex.status ~= "tracked" or not ex.progress then return Zones.UNKNOWN end
    local p = ex.progress
    if p.trackedComplete then return Zones.COMPLETE end
    if p.completed > 0 then return Zones.PROGRESS end
    if p.denominator > 0 and p.coverage == "complete" then return Zones.UNTOUCHED end
    return Zones.UNKNOWN
end

-- Pure: the category list for Progression.Combine (spec §7.7) from the three providers'
-- ForZone results (any may be nil). Pending: data that will come (achievements not loaded,
-- QuestieDB still reading, no flight master seen on the continent yet). A provider that can't
-- ever answer here (no Explore achievement, no QuestieDB, no flight path) is left out.
function Zones.Categories(ex, q, f)
    local list = {}
    if ex and ex.status == "tracked" then list[#list + 1] = { key = "explore", progress = ex.progress }
    elseif ex and ex.status == "unavailable" then list[#list + 1] = { key = "explore", pending = "achievements" } end
    if q and q.status == "ready" then
        if q.progress and q.progress.denominator > 0 then list[#list + 1] = { key = "quests", progress = q.progress } end
    elseif q and (q.status == "building" or q.status == "idle") then
        list[#list + 1] = { key = "quests", pending = "building" }
    end
    if f and f.status == "ready" then list[#list + 1] = { key = "flights", progress = f.progress }
    elseif f and f.status == "pending" then list[#list + 1] = { key = "flights", progress = f.progress, pending = "flightmaster" } end
    return list
end

-- Pure: one catalogue entry. zone = { mapID, name, continent, rank }; ex, q, f = the
-- exploration, quest and flight path ForZone results (q and f may be nil).
--   { mapID, name, continent, rank, tracked, state (combined, spec §7.7), percent (combined, nil
--     without one), combined (Progression.Combine result), cats (= combined.cats), left (confirmed
--     not done, all categories), progress (exploration's; nil unless tracked and readable),
--     minLevel, maxLevel, faction (nil = unknown) }
function Zones.Entry(zone, ex, q, f)
    local combined = ns.Progression.Combine(Zones.Categories(ex, q, f))
    local progress = ex and ex.status == "tracked" and ex.progress or nil
    local state = combined.state
    if state ~= Zones.COMPLETE and state ~= Zones.PROGRESS and state ~= Zones.UNTOUCHED and state ~= Zones.UNTRACKED then
        state = Zones.UNKNOWN
    end
    return {
        mapID = zone.mapID, name = zone.name or "", continent = zone.continent, rank = zone.rank or 0,
        tracked = state ~= Zones.UNTRACKED, state = state, progress = progress, combined = combined,
        cats = combined.cats, percent = combined.percent, left = combined.remaining,
        uncertain = ex and ex.uncertain or false,
        minLevel = zone.minLevel, maxLevel = zone.maxLevel, faction = zone.faction,
    }
end

-- Pure: a zone's level range from the curated data, or nil, nil when it has none or the entry
-- isn't a sane range (two whole numbers, 1 <= min <= max <= 60).
function Zones.LevelsFor(data, mapID)
    local r = type(data) == "table" and type(data.levels) == "table" and data.levels[mapID]
    if type(r) ~= "table" then return nil, nil end
    local lo, hi = r[1], r[2]
    if type(lo) ~= "number" or type(hi) ~= "number" or lo ~= math.floor(lo) or hi ~= math.floor(hi)
        or lo < 1 or hi > 60 or lo > hi then
        return nil, nil
    end
    return lo, hi
end

local FACTIONS = { Alliance = true, Horde = true, Contested = true }

-- Pure: a zone's faction territory from the curated data ("Alliance", "Horde", "Contested"),
-- or nil when it has none or the entry is anything else.
function Zones.FactionFor(data, mapID)
    local f = type(data) == "table" and type(data.faction) == "table" and data.faction[mapID]
    return FACTIONS[f] and f or nil
end

-- Every zone, in the client's continent order (live: reads the map tree and the tracker).
function Zones.All()
    local out = {}
    for rank, s in ipairs(ns.Maps.Sections()) do
        for _, z in ipairs(s.zones) do
            local lo, hi = Zones.LevelsFor(ns.ZoneData, z.mapID)
            local zone = { mapID = z.mapID, name = z.name, continent = s.title, rank = rank,
                minLevel = lo, maxLevel = hi, faction = Zones.FactionFor(ns.ZoneData, z.mapID) }
            out[#out + 1] = Zones.Entry(zone, ns.Exploration.ForZone(z.mapID),
                ns.Quests and ns.Quests.ForZone(z.mapID), ns.FlightPaths and ns.FlightPaths.ForZone(z.mapID))
        end
    end
    return out
end

---------------------------------------------------------------------------------------------
-- Filters (spec §6.2)
---------------------------------------------------------------------------------------------

local OPPOSITE = { Alliance = "Horde", Horde = "Alliance" }

-- Pure: should this zone be listed for a character of this faction? Only a zone known to be
-- the other faction's territory is left out; contested, neutral and unknown zones always stay.
function Zones.IsRelevant(z, faction)
    local other = OPPOSITE[faction]
    return not (other and z.faction == other)
end

-- Pure: is the zone's level range known and right for this level?
function Zones.FitsLevel(z, level)
    if type(level) ~= "number" or type(z.minLevel) ~= "number" or type(z.maxLevel) ~= "number" then
        return false
    end
    return z.minLevel <= level + Zones.LEVEL_REACH and z.maxLevel >= level
end

local function trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

-- Pure: case-insensitive name match (plain text, not a pattern).
function Zones.Matches(z, search)
    local q = trim(search):lower()
    if q == "" then return true end
    return z.name:lower():find(q, 1, true) ~= nil
end

-- Pure: the zones that pass every filter, in their original order.
-- opts = { faction = "relevant"|"all", completion = "all"|"progress"|"untouched"|"complete",
--          level = "all"|"appropriate", search = text }; char = { faction, level }.
-- A status filter shows only zones confirmed in that state: unknown and untracked zones are
-- never counted as in progress or untouched (spec §6.2).
function Zones.Filter(list, opts, char)
    opts, char = opts or {}, char or {}
    local out = {}
    for _, z in ipairs(list) do
        local ok = true
        if opts.faction == "relevant" and not Zones.IsRelevant(z, char.faction) then ok = false end
        if ok and opts.completion and opts.completion ~= "all" and z.state ~= opts.completion then ok = false end
        if ok and opts.level == "appropriate" and not Zones.FitsLevel(z, char.level) then ok = false end
        if ok and not Zones.Matches(z, opts.search) then ok = false end
        if ok then out[#out + 1] = z end
    end
    return out
end

-- Pure: which filters have data behind them (a filter without data would hide or keep
-- everything, so the UI leaves it out).
function Zones.Available(list)
    local has = { levels = false, faction = false }
    for _, z in ipairs(list) do
        if type(z.minLevel) == "number" and type(z.maxLevel) == "number" then has.levels = true end
        if OPPOSITE[z.faction] then has.faction = true end
    end
    return has
end

---------------------------------------------------------------------------------------------
-- Sorting (spec §6.3). Every order ends on name, then mapID, so ties are stable.
---------------------------------------------------------------------------------------------

local function byName(a, b)
    local an, bn = a.name:lower(), b.name:lower()
    if an ~= bn then return an < bn end
    return a.mapID < b.mapID
end

local function levelKey(z)
    if type(z.minLevel) == "number" and type(z.maxLevel) == "number" then return 0, z.minLevel, z.maxLevel end
    return 1, 0, 0
end

-- Zones with a percentage first; zones without completion data (unknown, untracked) after
-- them, by name, so a confirmed 0% never mixes with "no data".
local function withPercent(cmp)
    return function(a, b)
        local ha, hb = a.percent ~= nil, b.percent ~= nil
        if ha ~= hb then return ha end
        if ha then
            local r = cmp(a, b)
            if r ~= nil then return r end
        end
        return byName(a, b)
    end
end

local SORTS = {
    -- Levels where known (low to high), zones with unknown levels after, by continent.
    recommended = function(a, b)
        local ua, mina, maxa = levelKey(a)
        local ub, minb, maxb = levelKey(b)
        if ua ~= ub then return ua < ub end
        if mina ~= minb then return mina < minb end
        if maxa ~= maxb then return maxa < maxb end
        if a.rank ~= b.rank then return a.rank < b.rank end
        return byName(a, b)
    end,
    alphabetical = byName,
    highest = withPercent(function(a, b) if a.percent ~= b.percent then return a.percent > b.percent end end),
    lowest = withPercent(function(a, b) if a.percent ~= b.percent then return a.percent < b.percent end end),
    -- Highest % first (the zone's categories weigh equally), then fewest objectives left;
    -- complete zones after the unfinished ones.
    closest = withPercent(function(a, b)
        local ca, cb = a.state == Zones.COMPLETE, b.state == Zones.COMPLETE
        if ca ~= cb then return cb end
        if a.percent ~= b.percent then return a.percent > b.percent end
        local ra, rb = a.left or 0, b.left or 0
        if ra ~= rb then return ra < rb end
    end),
}
Zones.SORTS = SORTS

-- Pure: a sorted copy. Unknown sort names fall back to recommended.
function Zones.Sort(list, sort)
    local out = {}
    for i, z in ipairs(list) do out[i] = z end
    table.sort(out, SORTS[sort] or SORTS.recommended)
    return out
end

---------------------------------------------------------------------------------------------
-- Sections
---------------------------------------------------------------------------------------------

-- Pure: the section a zone goes under in the recommended order: its level bracket when the
-- range is known, else its continent.
function Zones.SectionOf(z)
    if type(z.minLevel) == "number" and type(z.maxLevel) == "number" then
        if z.minLevel < 10 then return "Levels 1-10" end
        if z.minLevel >= 60 then return "Level 60" end -- the level cap; no 60-70 bracket
        local b = math.floor(z.minLevel / 10) * 10
        return string.format("Levels %d-%d", b, b + 10)
    end
    return z.continent or "Other places"
end

-- Pure: consecutive zones of a sorted list grouped into sections. The recommended sort has
-- sections (LT/RT jump between them); other sorts are one untitled section.
--   { { title, zones, complete = confirmed complete zones, tracked = zones with exploration } }
function Zones.Groups(list, sort)
    local groups = {}
    for _, z in ipairs(list) do
        local title = (sort == nil or sort == "recommended" or not SORTS[sort]) and Zones.SectionOf(z) or nil
        local g = groups[#groups]
        if not g or g.title ~= title then
            g = { title = title, zones = {}, complete = 0, tracked = 0 }
            groups[#groups + 1] = g
        end
        g.zones[#g.zones + 1] = z
        if z.tracked then g.tracked = g.tracked + 1 end
        if z.state == Zones.COMPLETE then g.complete = g.complete + 1 end
    end
    return groups
end

-- /azf debug zones: the catalogue as the character sees it with the saved filters, in chat
-- and (debug mode) in the trace, so the in-game check can be read from SavedVariables.
function Zones.DebugReport()
    local all, c, s = Zones.All(), ns.character or {}, ns.db.zones
    local q = Zones.Query(all, { completion = s.completion, faction = s.faction, level = s.level, sort = s.sort }, c)
    local states, zones, hidden = {}, {}, {}
    for _, z in ipairs(all) do
        states[z.state] = (states[z.state] or 0) + 1
        local p = z.progress
        zones[#zones + 1] = string.format("%d %s %s %s %s", z.mapID, z.state,
            p and (p.completed .. "/" .. p.denominator) or "-",
            z.minLevel and (z.minLevel .. "-" .. z.maxLevel) or "?", z.faction or "?")
        if not Zones.IsRelevant(z, c.faction) then hidden[#hidden + 1] = z.name end
    end
    local shown = {}
    for _, z in ipairs(q.zones) do shown[#shown + 1] = z.mapID end
    ns.Printf("Zones: %d listed, %d shown (status %s, show %s, level %s, sort %s, view %s)", q.total, q.shown,
        s.completion, s.faction, s.level, s.sort, s.displayMode)
    ns.Printf("  complete %d, in progress %d, untouched %d, unknown %d, not tracked %d",
        states.complete or 0, states.progress or 0, states.untouched or 0, states.unknown or 0, states.untracked or 0)
    ns.Printf("  other faction's territory (%s): %s", tostring(c.faction),
        #hidden > 0 and table.concat(hidden, ", ") or "none")
    ns.Debug.Trace("zones", { character = c.name, faction = c.faction, level = c.level,
        completion = s.completion, show = s.faction, levelFilter = s.level, sort = s.sort, view = s.displayMode,
        total = q.total, shown = q.shown, shownIDs = shown, states = states, otherFaction = hidden, zones = zones })
end

-- Pure: filter, sort and group in one go.
--   { zones (filtered, sorted), groups, total = #list, shown = #zones, available = Available(list) }
function Zones.Query(list, opts, char)
    opts = opts or {}
    local zones = Zones.Sort(Zones.Filter(list, opts, char), opts.sort)
    return { zones = zones, groups = Zones.Groups(zones, opts.sort), total = #list, shown = #zones,
        available = Zones.Available(list) }
end
