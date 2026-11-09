-- The Overview dashboard's model (spec §5, plan Phase 7, Phase 9 step 6): tracked completion
-- per category, the Zones stat, the Continue card, the next goal, suggested objectives and the
-- recently visited zones. Overview.Build is pure: it takes the Zones catalogue entries
-- (ns.Zones), each zone's Next up picks (ns.Zones.NextUp), the providers' overall results and
-- the saved visits, and only picks and orders them. Every count it hands on comes from
-- ns.Progression, so the Overview and the Zones tab show the same numbers for a zone.
-- Overview.Gather() collects that input from the client; the visit tracker records the zones
-- the player enters (AzerfolioCharDB.recentZones, newest last).
-- The Activity panel (discoveries per day, latest milestones) was removed in Phase 9 step 6
-- (owner, 2026-11-08), with the milestone tracking behind it.
local _, ns = ...

local Overview = {}
ns.Overview = Overview

Overview.GROUPS = 3          -- suggestion groups (zones)
Overview.RECENT_ZONES = 5    -- recently visited zones shown
Overview.LEVEL_BEHIND = 2    -- "next for your level" looks from this many levels below yours

---------------------------------------------------------------------------------------------
-- Pure helpers
---------------------------------------------------------------------------------------------

-- A zone with something confirmed left to do (all categories, spec §7.7).
local function unfinished(z)
    return z.tracked and (z.state == "progress" or z.state == "untouched") and (z.left or 0) > 0
end

local function byName(a, b)
    local an, bn = a.name:lower(), b.name:lower()
    if an ~= bn then return an < bn end
    return a.mapID < b.mapID
end

-- Pure: in-progress zones, fewest objectives left first (all categories; then highest %,
-- then name).
function Overview.Closest(zones)
    local out = {}
    for _, z in ipairs(zones) do
        if z.state == "progress" and (z.left or 0) > 0 then out[#out + 1] = z end
    end
    table.sort(out, function(a, b)
        if a.left ~= b.left then return a.left < b.left end
        local pa, pb = a.percent or -1, b.percent or -1
        if pa ~= pb then return pa > pb end
        return byName(a, b)
    end)
    return out
end

-- Pure: unfinished zones in "next for your level" order. Zones in progress come first; then
-- zones that fit your level and aren't behind you (min level >= yours - LEVEL_BEHIND), zones
-- that fit, zones ahead of you, zones without a known range, zones behind you; within a tier
-- by minimum level, the current zone's continent first, then name.
function Overview.ForLevel(zones, level, continent)
    local function tier(z)
        local known = type(z.minLevel) == "number" and type(level) == "number"
        if not known then return 3 end
        local fits = ns.Zones.FitsLevel(z, level)
        if fits and z.minLevel >= level - Overview.LEVEL_BEHIND then return 0 end
        if fits then return 1 end
        if z.minLevel > level then return 2 end
        return 4
    end
    local out = {}
    for _, z in ipairs(zones) do
        if unfinished(z) then out[#out + 1] = z end
    end
    table.sort(out, function(a, b)
        local pa, pb = a.state == "progress", b.state == "progress"
        if pa ~= pb then return pa end
        local ta, tb = tier(a), tier(b)
        if ta ~= tb then return ta < tb end
        local la, lb = a.minLevel or 99, b.minLevel or 99
        if la ~= lb then return la < lb end
        local ca, cb = a.continent == continent, b.continent == continent
        if ca ~= cb then return ca end
        return byName(a, b)
    end)
    return out
end

-- Pure: moves mapID to the end of the visit list (newest last), capped at `limit`.
-- Returns true if the list changed.
function Overview.PushRecent(list, mapID, limit)
    if type(list) ~= "table" or type(mapID) ~= "number" then return false end
    if list[#list] == mapID then return false end
    for i = #list, 1, -1 do
        if list[i] == mapID then table.remove(list, i) end
    end
    list[#list + 1] = mapID
    while #list > (limit or 10) do table.remove(list, 1) end
    return true
end

-- Pure: tracked completion (spec §5.2, v1.1) from the providers' overall results (any may be
-- nil): ex = Exploration.Overall(), q = Quests.Overall(), f = FlightPaths.Overall().
-- The headline is Progression.Combine over the categories: the equal-weight average of those
-- with counted objectives; a category whose data isn't readable yet is listed with its reason
-- and left out of the average, never shown as 0%.
--   { combined (Combine result; its cats carry key, progress, completed, denominator,
--     percent, unchecked, pending), zones = ex.zones, exploreUnread = zones whose exploration
--     can't be read, flightsUnread = continent mapIDs without a flight master's list }
function Overview.Tracked(ex, q, f)
    local list = {}
    if ex and ex.progress and (ex.progress.denominator or 0) > 0 and ex.progress.percent then
        list[#list + 1] = { key = "explore", progress = ex.progress }
    elseif ex and (ex.unavailable or 0) > 0 then
        list[#list + 1] = { key = "explore", pending = "achievements" }
    end
    if q and q.status == "ready" then
        if q.progress and (q.progress.denominator or 0) > 0 then list[#list + 1] = { key = "quests", progress = q.progress } end
    elseif q and (q.status == "building" or q.status == "idle") then
        list[#list + 1] = { key = "quests", pending = "building" }
    elseif q and q.status == "unavailable" then
        list[#list + 1] = { key = "quests", pending = "questiedb" }
    end
    if f and f.status == "ready" and f.progress then
        list[#list + 1] = { key = "flights", progress = f.progress }
    elseif f and f.status == "pending" then
        list[#list + 1] = { key = "flights", pending = "flightmaster" }
    end
    return { combined = ns.Progression.Combine(list), zones = ex and ex.zones or 0,
        exploreUnread = ex and ex.unavailable or 0, flightsUnread = f and f.unread or {} }
end

---------------------------------------------------------------------------------------------
-- The model
---------------------------------------------------------------------------------------------

local function counts(zones, faction)
    local c = { applicable = 0, complete = 0, progress = 0, untouched = 0, unknown = 0 }
    for _, z in ipairs(zones) do
        if z.tracked and ns.Zones.IsRelevant(z, faction) then
            c.applicable = c.applicable + 1
            c[z.state] = (c[z.state] or 0) + 1
        end
    end
    return c
end

-- Pure. input:
--   zones        ns.Zones entries (Zones.All())
--   nextUpFor(mapID) -> the zone's Zones.NextUp picks (or nil)
--   overall      { explore = Exploration.Overall(), quests = Quests.Overall(),
--                  flights = FlightPaths.Overall() } (any may be nil)
--   current      the player's zone mapID (nil if unknown)
--   recent       visited zone mapIDs, newest last
--   char         { faction, level }
-- Returns:
--   completion   Overview.Tracked result
--   zones        { applicable, complete, progress, untouched, unknown }   (relevant tracked zones)
--   current      the current zone's entry (any state) or nil
--   hero         { zone, why = "current"|"closest"|"level" } or nil
--   goal         the in-progress zone with the fewest left, other than the hero's, or nil
--   suggestions  { { zone, rule, items (Zones.NextUp picks, >= 1) } } (<= GROUPS)
--   recent       recently visited zone entries, newest first, without the current zone
function Overview.Build(input)
    input = input or {}
    local zones, char = input.zones or {}, input.char or {}
    local byMap = {}
    for _, z in ipairs(zones) do byMap[z.mapID] = z end
    local relevant = {}
    for _, z in ipairs(zones) do
        if ns.Zones.IsRelevant(z, char.faction) then relevant[#relevant + 1] = z end
    end

    local overall = input.overall or {}
    local model = { all = zones, zones = counts(zones, char.faction),
        completion = Overview.Tracked(overall.explore, overall.quests, overall.flights) }

    local current = input.current and byMap[input.current]
    model.current = current

    -- The Continue card: the zone you're in whenever it's tracked, finished or not (owner,
    -- 2026-11-08); else the closest zone to finish, else the next one for your level.
    local closest = Overview.Closest(relevant)
    local forLevel = Overview.ForLevel(relevant, char.level, current and current.continent)
    if current and current.tracked then
        model.hero = { zone = current, why = "current" }
    elseif closest[1] then
        model.hero = { zone = closest[1], why = "closest" }
    elseif forLevel[1] then
        model.hero = { zone = forLevel[1], why = "level" }
    end
    local heroZone = model.hero and model.hero.zone
    for _, z in ipairs(closest) do
        if z ~= heroZone then model.goal = z break end
    end

    -- Suggestions (spec §5.5), grouped by zone: 1. the current zone; 2. the zone closest to
    -- completion; 3. the next zones for your level; then more close zones if room is left.
    -- Each group lists the zone's Next up picks (areas, ready quests, a flight path), which
    -- only hold objectives confirmed not done and eligible.
    local groups, used = {}, {}
    local function add(z, rule)
        if #groups >= Overview.GROUPS or used[z.mapID] then return end
        local items = input.nextUpFor and input.nextUpFor(z.mapID) or {}
        if #items == 0 then return end
        used[z.mapID] = true
        groups[#groups + 1] = { zone = z, rule = rule, items = items }
    end
    if current and unfinished(current) then add(current, "current") end
    local closeTaken = 0
    for _, z in ipairs(closest) do
        if closeTaken >= (#groups == 0 and 2 or 1) then break end
        if not used[z.mapID] then add(z, "closest"); closeTaken = closeTaken + 1 end
    end
    for _, z in ipairs(forLevel) do add(z, "level") end
    for _, z in ipairs(closest) do add(z, "closest") end
    model.suggestions = groups

    -- Recently visited, newest first, without the zone you're in.
    local recent, seen = {}, {}
    local list = input.recent or {}
    for i = #list, 1, -1 do
        local z = byMap[list[i]]
        if z and z ~= current and not seen[z.mapID] and #recent < Overview.RECENT_ZONES then
            seen[z.mapID] = true
            recent[#recent + 1] = z
        end
    end
    model.recent = recent
    return model
end

---------------------------------------------------------------------------------------------
-- Live: input from the client, and the visit tracker
---------------------------------------------------------------------------------------------

-- The player's zone: the tracked zone they're in, else the map itself (a capital such as
-- Stormwind City is a listed zone without exploration; its continent still orders the
-- "next for your level" picks).
local function currentMap()
    local tracked = ns.Exploration.CurrentZone()
    if tracked then return tracked end
    return C_Map and C_Map.GetBestMapForUnit
        and ns.Debug.Try("GetBestMapForUnit", C_Map.GetBestMapForUnit, "player") or nil
end

function Overview.Gather()
    return {
        zones = ns.Zones.All(),
        nextUpFor = function(mapID)
            return ns.Zones.NextUp(ns.Exploration.ForZone(mapID), ns.Quests and ns.Quests.ForZone(mapID),
                ns.FlightPaths and ns.FlightPaths.ForZone(mapID))
        end,
        overall = {
            explore = ns.Exploration.Overall(),
            quests = ns.Quests and ns.Quests.Overall() or nil,
            flights = ns.FlightPaths and ns.FlightPaths.Overall() or nil,
        },
        current = currentMap(),
        recent = ns.charDB and ns.charDB.recentZones or {},
        char = ns.character or {},
    }
end

function Overview.Model() return Overview.Build(Overview.Gather()) end

-- A continent's name for the coverage note (live), or nil.
function Overview.ContinentName(mapID)
    local info = C_Map and type(C_Map.GetMapInfo) == "function" and ns.Debug.Try("GetMapInfo", C_Map.GetMapInfo, mapID)
    return type(info) == "table" and info.name or nil
end

-- Records the tracked zone the player is in as the newest visit.
function Overview.NoteVisit()
    local char = ns.charDB
    if not char then return end
    local mapID = ns.Exploration.CurrentZone()
    if not mapID then return end
    if Overview.PushRecent(char.recentZones, mapID, ns.Config.LIMITS.recentZones) then
        ns.Debug.Trace("visit", { mapID = mapID })
        ns.Events.Send("AZF_ZONE_VISITED", mapID)
    end
end

if ns.Events then -- absent when tests load the pure part alone
    ns.Events.On("AZF_READY", function() Overview.NoteVisit() end)
    ns.Events.Register("ZONE_CHANGED_NEW_AREA", function()
        if ns.ready then Overview.NoteVisit() end
    end)
end

-- /azf debug overview: what the dashboard shows, in chat and (debug mode) in the trace.
function Overview.DebugReport()
    local m = Overview.Model()
    local c = m.completion.combined
    local cats = {}
    for _, cat in ipairs(c.cats) do
        cats[#cats + 1] = cat.pending and (cat.key .. " pending (" .. cat.pending .. ")")
            or string.format("%s %d/%d", cat.key, cat.completed, cat.denominator)
    end
    ns.Printf("Overview: tracked completion %s [%s], zones %d of %d complete (%d in progress, %d untouched, %d unknown)",
        ns.Progression.PercentText(c) or "unavailable", table.concat(cats, ", "),
        m.zones.complete, m.zones.applicable, m.zones.progress, m.zones.untouched, m.zones.unknown)
    ns.Printf("  continue: %s (%s); next goal: %s", m.hero and m.hero.zone.name or "none",
        m.hero and m.hero.why or "-", m.goal and m.goal.name or "none")
    local s = {}
    for _, g in ipairs(m.suggestions) do s[#s + 1] = string.format("%s (%s, %d picks)", g.zone.name, g.rule, #g.items) end
    ns.Printf("  suggestions: %s", #s > 0 and table.concat(s, ", ") or "none")
    local r = {}
    for _, z in ipairs(m.recent) do r[#r + 1] = z.name end
    ns.Printf("  recent zones: %s", #r > 0 and table.concat(r, ", ") or "none")
    ns.Debug.Trace("overview", { percent = c.percent, cats = cats, zones = m.zones,
        hero = m.hero and m.hero.zone.mapID, heroWhy = m.hero and m.hero.why, goal = m.goal and m.goal.mapID,
        suggestions = s, recent = r, flightsUnread = #m.completion.flightsUnread,
        exploreUnread = m.completion.exploreUnread })
end
