-- Exploration objectives for a zone, read live from the game's "Explore <zone>" achievement
-- criteria (Phase 1, docs/research/exploration-validation.md): objective ID = criteriaID,
-- completion = the criterion's done flag, per character. [verified-ingame]
-- This is the native-API reader; counts come from ns.Progression. Phase 5 step 3 moves the
-- zone lookup to the generated catalogue and adds events; step 4 the baseline.
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

-- Exploration for a zone { mapID, name }:
--   { status = "tracked", achievementID, objectives, progress }
--       objectives: ns.Objectives (category "exploration", id = criteriaID); every criterion is
--       eligible (the game marks none ineligible, plan §9). progress: ns.Progression.Aggregate.
--   { status = "untracked" }   the game has no Explore achievement for this zone
--   { status = "unavailable" } achievement data can't be read right now
function Exploration.ForZone(zone)
    index = index or buildIndex()
    if not index then return { status = "unavailable" } end
    local achID = zone and zone.name and index[zone.name]
    if not achID then return { status = "untracked" } end
    local n = try("GetAchievementNumCriteria", GetAchievementNumCriteria, achID)
    if type(n) ~= "number" then return { status = "unavailable" } end
    local O = ns.Objectives
    local objectives = {}
    for i = 1, n do
        local name, _, done, _, _, _, _, _, _, criteriaID = try("GetAchievementCriteriaInfo",
            GetAchievementCriteriaInfo, achID, i)
        local o = O.New({ id = criteriaID, category = "exploration", zone = zone.mapID, name = name,
            completion = O.CompletionFromFlag(done), eligibility = O.ELIGIBLE, source = "achievement" })
        if o then objectives[#objectives + 1] = o end
    end
    -- A criterion without an ID can't be counted; the zone's list is then incomplete.
    local coverage = #objectives == n and "complete" or "partial"
    local progress = ns.Progression.Aggregate({
        { category = "exploration", coverage = coverage, objectives = objectives } })
    return { status = "tracked", achievementID = achID, objectives = objectives, progress = progress }
end

-- For tests: forget the index.
function Exploration.Reset() index = nil end
