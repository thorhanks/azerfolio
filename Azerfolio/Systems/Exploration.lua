-- Exploration tracker. Zones and their achievements come from the generated catalogue
-- (Data/Exploration.lua); names and completion are read live from the game's "Explore <zone>"
-- achievement criteria (docs/research/exploration-validation.md): objective ID = criteriaID,
-- completion = the criterion's done flag, per character. [verified-ingame]
-- Counts come from ns.Progression. Results are cached per zone; discovery events re-read only
-- the zone the player is in and announce AZF_EXPLORATION_UPDATED(mapIDs) (nil = every zone).
-- The UI shows what this returns and never counts on its own.
local _, ns = ...

local Exploration = {}
ns.Exploration = Exploration

Exploration.CATEGORY = "exploration"
Exploration.REFRESH_DELAY = 0.5 -- one refresh per discovery burst (plan §9)

local cache = {} -- [mapID] = ForZone result (only readable results are cached)

local function try(label, fn, ...) return ns.Debug.Try(label, fn, ...) end
local function catalogue() return ns.ExplorationCatalogue or { zones = {} } end

-- Pure: compares the live criteria IDs with the catalogue's.
-- Returns match (same set of IDs), missing (in the catalogue, not live), extra (live only).
function Exploration.Compare(expected, live)
    local want, have, missing, extra = {}, {}, {}, {}
    for _, id in ipairs(expected or {}) do want[id] = true end
    for _, id in ipairs(live or {}) do
        have[id] = true
        if not want[id] then extra[#extra + 1] = id end
    end
    for _, id in ipairs(expected or {}) do
        if not have[id] then missing[#missing + 1] = id end
    end
    return #missing == 0 and #extra == 0, missing, extra
end

-- Is this map a zone the catalogue tracks?
function Exploration.IsTracked(mapID) return catalogue().zones[mapID] ~= nil end

-- The tracked zone a map belongs to: the map itself or its nearest tracked parent (so a micro
-- map or a cave still finds its zone). nil when there is none.
function Exploration.ZoneForMap(mapID)
    local guard = 0
    while type(mapID) == "number" and mapID > 0 and guard < 10 do
        if Exploration.IsTracked(mapID) then return mapID end
        local info = C_Map and try("GetMapInfo", C_Map.GetMapInfo, mapID)
        mapID = info and info.parentMapID
        guard = guard + 1
    end
    return nil
end

local function read(mapID)
    local entry = catalogue().zones[mapID]
    if not entry then return { status = "untracked", mapID = mapID } end
    local achID = entry.achievementID
    local n = try("GetAchievementNumCriteria", GetAchievementNumCriteria, achID)
    -- Before the client has achievement data it may return nothing or 0. [unverified]
    if type(n) ~= "number" or n < 1 then return { status = "unavailable", mapID = mapID } end

    local O = ns.Objectives
    local objectives, liveIDs = {}, {}
    for i = 1, n do
        local name, _, done, _, _, _, _, _, _, criteriaID = try("GetAchievementCriteriaInfo",
            GetAchievementCriteriaInfo, achID, i)
        local o = O.New({ id = criteriaID, category = Exploration.CATEGORY, zone = mapID, name = name,
            completion = O.CompletionFromFlag(done), eligibility = O.ELIGIBLE, source = "achievement" })
        if o then
            objectives[#objectives + 1] = o
            liveIDs[#liveIDs + 1] = criteriaID
        end
    end
    if #objectives == 0 then return { status = "unavailable", mapID = mapID } end

    -- Plan §8: when the game and the catalogue disagree (a patch), trust the game's list and
    -- completion, don't change its totals, and mark the result uncertain. A criterion the game
    -- returns without an ID can't be counted, so the zone's coverage is partial.
    local match, missing, extra = Exploration.Compare(entry.criteria, liveIDs)
    local coverage = #objectives == n and "complete" or "partial"
    if not match or coverage ~= "complete" then
        ns.Debug.Print("exploration %d: live criteria differ from the catalogue (%d missing, %d extra, %d without ID)",
            mapID, #missing, #extra, n - #objectives)
    end
    local progress = ns.Progression.Aggregate({
        { category = Exploration.CATEGORY, coverage = coverage, objectives = objectives } })
    return { status = "tracked", mapID = mapID, achievementID = achID, objectives = objectives,
        progress = progress, catalogueMatch = match, uncertain = not match, missing = missing, extra = extra }
end

-- Exploration for a zone (a mapID or { mapID }):
--   { status = "tracked", mapID, achievementID, objectives, progress, catalogueMatch, uncertain,
--     missing, extra }   uncertain = the game's criteria differ from the catalogue
--       objectives: ns.Objectives (category "exploration", id = criteriaID); every criterion is
--       eligible (the game marks none ineligible, plan §9). progress: ns.Progression.Aggregate.
--   { status = "untracked" }   not in the catalogue (capitals, Zephras Isle): no Explore achievement
--   { status = "unavailable" } achievement data can't be read right now (not cached; retried)
local function load(mapID, live)
    local r = read(mapID)
    if r.status ~= "unavailable" then cache[mapID] = r end
    -- Every fresh read updates the baseline and records confirmed transitions.
    if r.status == "tracked" and ns.Milestones then ns.Milestones.Observe(r, live) end
    return r
end

function Exploration.ForZone(zone)
    local mapID = type(zone) == "table" and zone.mapID or zone
    if type(mapID) ~= "number" then return { status = "untracked" } end
    return cache[mapID] or load(mapID, false)
end

-- Every tracked zone together. A zone that can't be read right now makes the category's
-- coverage unavailable, so there is no overall percentage until it can.
--   { progress, zones = tracked zone count, unavailable = zones not readable }
function Exploration.Overall()
    local sets, zones, unavailable = {}, 0, 0
    for mapID in pairs(catalogue().zones) do
        zones = zones + 1
        local r = Exploration.ForZone(mapID)
        if r.status == "tracked" then
            sets[#sets + 1] = { category = Exploration.CATEGORY, coverage = r.progress.coverage == "complete"
                and "complete" or "partial", objectives = r.objectives }
        else
            unavailable = unavailable + 1
            sets[#sets + 1] = { category = Exploration.CATEGORY, coverage = "unavailable", objectives = {} }
        end
    end
    return { progress = ns.Progression.Aggregate(sets), zones = zones, unavailable = unavailable }
end

function Exploration.Invalidate(mapID) cache[mapID] = nil end
function Exploration.InvalidateAll() cache = {} end

-- Did any objective's completion change between two results?
local function changed(old, new)
    if not old or old.status ~= new.status then return true end
    if new.status ~= "tracked" then return false end
    if #old.objectives ~= #new.objectives then return true end
    local before = {}
    for _, o in ipairs(old.objectives) do before[o.id] = o.completion end
    for _, o in ipairs(new.objectives) do
        if before[o.id] ~= o.completion then return true end
    end
    return false
end

-- Re-reads one zone. Announces AZF_EXPLORATION_UPDATED({ mapID }) if anything changed.
-- `live`: caused by a discovery event (milestones found get a time).
-- Returns the new result and whether it changed.
function Exploration.RefreshZone(mapID, live)
    local old = cache[mapID]
    cache[mapID] = nil
    local new = load(mapID, live)
    local diff = changed(old, new)
    local p = new.progress
    ns.Debug.Trace("exploration", { mapID = mapID, status = new.status, changed = diff,
        completed = p and p.completed, denominator = p and p.denominator })
    if diff then ns.Events.Send("AZF_EXPLORATION_UPDATED", { mapID }) end
    return new, diff
end

-- The player's current tracked zone, or nil.
function Exploration.CurrentZone()
    local here = C_Map and try("GetBestMapForUnit", C_Map.GetBestMapForUnit, "player")
    return Exploration.ZoneForMap(here)
end

local function refreshCurrent()
    local mapID = Exploration.CurrentZone()
    if mapID then Exploration.RefreshZone(mapID, true) end
end

-- Reads every zone once, so each one has a baseline before the player discovers anything in
-- it (a zone first read by a discovery would otherwise take that discovery as its baseline).
Exploration.BASELINE_DELAY = 3 -- achievement data was readable 3 s after login [verified-ingame]
local function readAll()
    local all = Exploration.Overall()
    ns.Debug.Trace("baseline", { zones = all.zones, unavailable = all.unavailable })
end

-- Forget everything and tell the UI to re-read (login data arrived, /azf refresh).
local function refreshAll(reason)
    Exploration.InvalidateAll()
    ns.Debug.Trace("exploration", { all = true, reason = reason })
    ns.Events.Send("AZF_EXPLORATION_UPDATED", nil)
    if ns.ready then ns.Events.Debounce("exploration-all", 1, readAll) end
end

ns.Events.On("AZF_READY", function()
    ns.Events.Debounce("exploration-all", Exploration.BASELINE_DELAY, readAll)
end)

-- A discovery fires CRITERIA_UPDATE, then MAP_EXPLORATION_UPDATED about 0.4 s later
-- [verified-ingame]; CRITERIA_UPDATE also fires for unrelated criteria, so it is debounced and
-- only announces a change when a criterion actually flipped.
local function onDiscoveryEvent(event)
    if not ns.ready then return end
    ns.Events.Debounce("exploration", Exploration.REFRESH_DELAY, refreshCurrent)
end

ns.Events.Register("CRITERIA_UPDATE", function() onDiscoveryEvent("CRITERIA_UPDATE") end)
ns.Events.Register("MAP_EXPLORATION_UPDATED", function() onDiscoveryEvent("MAP_EXPLORATION_UPDATED") end)
ns.Events.Register("RECEIVED_ACHIEVEMENT_LIST", function() refreshAll("RECEIVED_ACHIEVEMENT_LIST") end)
ns.Events.On("AZF_REFRESH_REQUESTED", function() refreshAll("refresh") end)

-- /azf debug exploration: the current zone's state, in chat.
function Exploration.DebugReport()
    local here = C_Map and try("GetBestMapForUnit", C_Map.GetBestMapForUnit, "player")
    local mapID = Exploration.ZoneForMap(here)
    if not mapID then
        ns.Printf("Exploration: map %s is not a tracked zone.", tostring(here))
        return
    end
    local r = Exploration.RefreshZone(mapID)
    if r.status ~= "tracked" then
        ns.Printf("Exploration %d: %s.", mapID, r.status)
        return
    end
    local p = r.progress
    ns.Printf("Exploration %d (achievement %d): %d/%d discovered, %s, coverage %s, catalogue %s",
        mapID, r.achievementID, p.completed, p.denominator, ns.Progression.PercentText(p) or "no %",
        p.coverage, r.catalogueMatch and "matches" or
        string.format("differs (%d missing, %d extra)", #r.missing, #r.extra))
    if p.completionUnknown > 0 then ns.Printf("  %d areas with unknown state", p.completionUnknown) end
    local all = Exploration.Overall()
    local ap = all.progress
    local count = ap.percent and string.format("%d/%d, %s", ap.completed, ap.denominator,
        ns.Progression.PercentText(ap)) or "no total yet"
    ns.Printf("All zones: %s, coverage %s (%d zones, %d unreadable)", count, ap.coverage,
        all.zones, all.unavailable)
    local ms = ns.Milestones.Summary(3)
    if ms then
        ns.Printf("Baseline: %d zones; milestones: %d", ms.zones, ms.count)
        for _, m in ipairs(ms.recent) do
            ns.Printf("  %s %s (zone %s)%s", m.kind, tostring(m.name or m.id), tostring(m.mapID),
                m.time and "" or ", time not seen")
        end
    end
    ns.Debug.Trace("report", { mapID = mapID, completed = p.completed, denominator = p.denominator,
        unknown = p.completionUnknown, coverage = p.coverage, catalogueMatch = r.catalogueMatch,
        allCompleted = ap.completed, allDenominator = ap.denominator, allCoverage = ap.coverage,
        allUnavailable = all.unavailable })
end
