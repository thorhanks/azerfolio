-- The Overview dashboard's model (spec §5, plan Phase 7): tracked completion, the Zones stat,
-- the Continue card, the next goal, suggested objectives, recently visited zones, the activity
-- strip and recent milestones. Overview.Build is pure: it takes the Zones catalogue entries
-- (ns.Zones), the zones' objectives, the overall Progression result and the saved history, and
-- only picks and orders them. Every count it hands on comes from ns.Progression, so the
-- Overview and the Zones tab show the same numbers for a zone.
-- Overview.Gather() collects that input from the client; the visit tracker records the zones
-- the player enters (AzerfolioCharDB.recentZones, newest last).
local _, ns = ...

local Overview = {}
ns.Overview = Overview

Overview.GROUPS = 3          -- suggestion groups (zones)
Overview.CHIPS = 6           -- area chips per group
Overview.RECENT_ZONES = 3    -- recently visited zones shown
Overview.RECENT_MILESTONES = 3
Overview.ACTIVITY_DAYS = 14
Overview.LEVEL_BEHIND = 2    -- "next for your level" looks from this many levels below yours

local DAY = 24 * 60 * 60

---------------------------------------------------------------------------------------------
-- Pure helpers
---------------------------------------------------------------------------------------------

local function unfinished(z)
    return z.tracked and (z.state == "progress" or z.state == "untouched") and z.progress ~= nil
end

local function byName(a, b)
    local an, bn = a.name:lower(), b.name:lower()
    if an ~= bn then return an < bn end
    return a.mapID < b.mapID
end

-- Pure: in-progress zones, fewest areas left first (then highest %, then name).
function Overview.Closest(zones)
    local out = {}
    for _, z in ipairs(zones) do
        if z.state == "progress" and z.progress and z.progress.remaining > 0 then out[#out + 1] = z end
    end
    table.sort(out, function(a, b)
        local ra, rb = a.progress.remaining, b.progress.remaining
        if ra ~= rb then return ra < rb end
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
        if unfinished(z) and z.progress.remaining > 0 then out[#out + 1] = z end
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

-- Pure: the objectives worth suggesting: confirmed not done and eligible (never unknown).
function Overview.Suggestable(objectives)
    local out = {}
    for _, o in ipairs(objectives or {}) do
        if o.completion == "incomplete" and o.eligibility == "eligible" then out[#out + 1] = o end
    end
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

-- Pure: discoveries per day for the last `days` days, oldest first, today last. Only area
-- milestones with a time count (one found later has no time, so no day). dayOf(t) names a day.
function Overview.Activity(milestones, now, dayOf, days)
    days = days or Overview.ACTIVITY_DAYS
    local index, counts = {}, {}
    for i = 1, days do
        counts[i] = 0
        if now and dayOf then index[dayOf(now - (days - i) * DAY)] = i end
    end
    if now and dayOf then
        for _, m in ipairs(milestones or {}) do
            if type(m) == "table" and m.kind == "area" and type(m.time) == "number" and m.time <= now then
                local i = index[dayOf(m.time)]
                if i then counts[i] = counts[i] + 1 end
            end
        end
    end
    local max = 0
    for _, c in ipairs(counts) do if c > max then max = c end end
    return { counts = counts, today = counts[days], max = max }
end

-- Pure: when a milestone happened, in words. nil time = it wasn't seen when it happened.
function Overview.TimeText(t, now, dayOf, clock)
    if type(t) ~= "number" then return "time not seen" end
    if not (now and dayOf) then return "" end
    local hm = clock and clock(t) or ""
    if dayOf(t) == dayOf(now) then return "Today, " .. hm end
    if dayOf(t) == dayOf(now - DAY) then return "Yesterday, " .. hm end
    for d = 2, 13 do
        if dayOf(t) == dayOf(now - d * DAY) then return d .. " days ago" end
    end
    return dayOf(t)
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
--   objectivesFor(mapID) -> the zone's objectives (Exploration.ForZone(...).objectives) or nil
--   overall      Exploration.Overall() result: { progress, zones, unavailable }
--   current      the player's zone mapID (nil if unknown)
--   recent       visited zone mapIDs, newest last
--   milestones   AzerfolioCharDB.milestones (newest last)
--   char         { faction, level }
--   now, dayOf, clock   time() and day/clock formatters (activity, milestone times)
-- Returns:
--   completion   { progress (overall Progression result or nil), zones, unavailable,
--                  categories = { { name, completed, denominator } } }
--   zones        { applicable, complete, progress, untouched, unknown }   (relevant tracked zones)
--   current      the current zone's entry (any state) or nil
--   hero         { zone, why = "current"|"closest"|"level" } or nil
--   goal         the in-progress zone with the fewest left, other than the hero's, or nil
--   suggestions  { { zone, why, rule, objectives (<= CHIPS), more } } (<= GROUPS)
--   recent       recently visited zone entries, newest first, without the current zone
--   activity     Overview.Activity result
--   milestones   newest first: { kind, name, zoneName, mapID, time, when }
function Overview.Build(input)
    input = input or {}
    local zones, char = input.zones or {}, input.char or {}
    local byMap = {}
    for _, z in ipairs(zones) do byMap[z.mapID] = z end
    local relevant = {}
    for _, z in ipairs(zones) do
        if ns.Zones.IsRelevant(z, char.faction) then relevant[#relevant + 1] = z end
    end

    local model = { zones = counts(zones, char.faction) }

    -- Tracked completion: exploration is the only category so far.
    local overall = input.overall or {}
    local op = overall.progress
    model.completion = { progress = op, zones = overall.zones or 0, unavailable = overall.unavailable or 0,
        categories = { { name = "Exploration", completed = op and op.completed or 0,
            denominator = op and op.denominator or 0 } } }

    local current = input.current and byMap[input.current]
    model.current = current

    local function objectives(z)
        return Overview.Suggestable(input.objectivesFor and input.objectivesFor(z.mapID))
    end

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
    local groups, used = {}, {}
    local function add(z, rule, why)
        if #groups >= Overview.GROUPS or used[z.mapID] then return end
        local list = objectives(z)
        if #list == 0 then return end
        used[z.mapID] = true
        local shown = {}
        for i = 1, math.min(#list, Overview.CHIPS) do shown[i] = list[i] end
        groups[#groups + 1] = { zone = z, rule = rule, why = why, objectives = shown,
            more = #list - #shown, left = #list }
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

    model.activity = Overview.Activity(input.milestones, input.now, input.dayOf)
    local ms, all = {}, input.milestones or {}
    for i = #all, 1, -1 do
        local m = all[i]
        if type(m) == "table" and (m.kind == "area" or m.kind == "zone") then
            local z = byMap[m.mapID]
            ms[#ms + 1] = { kind = m.kind, name = m.name, mapID = m.mapID, time = m.time,
                zoneName = z and z.name or ("Zone " .. tostring(m.mapID)),
                when = Overview.TimeText(m.time, input.now, input.dayOf, input.clock) }
            if #ms >= Overview.RECENT_MILESTONES then break end
        end
    end
    model.milestones = ms
    return model
end

---------------------------------------------------------------------------------------------
-- Live: input from the client, and the visit tracker
---------------------------------------------------------------------------------------------

local function dayOf(t) return date("%Y-%m-%d", t) end
local function clock(t) return date("%H:%M", t) end

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
    local hasDate = type(date) == "function"
    return {
        zones = ns.Zones.All(),
        objectivesFor = function(mapID)
            local ex = ns.Exploration.ForZone(mapID)
            return ex.status == "tracked" and ex.objectives or nil
        end,
        overall = ns.Exploration.Overall(),
        current = currentMap(),
        recent = ns.charDB and ns.charDB.recentZones or {},
        milestones = ns.charDB and ns.charDB.milestones or {},
        char = ns.character or {},
        now = type(time) == "function" and time() or nil,
        dayOf = hasDate and dayOf or nil,
        clock = hasDate and clock or nil,
    }
end

function Overview.Model() return Overview.Build(Overview.Gather()) end

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
    local p = m.completion.progress
    ns.Printf("Overview: tracked completion %s (%s), zones %d of %d complete (%d in progress, %d untouched, %d unknown)",
        p and p.percent and ns.Progression.PercentText(p) or "unavailable",
        p and string.format("%d/%d", p.completed, p.denominator) or "-",
        m.zones.complete, m.zones.applicable, m.zones.progress, m.zones.untouched, m.zones.unknown)
    ns.Printf("  continue: %s (%s); next goal: %s", m.hero and m.hero.zone.name or "none",
        m.hero and m.hero.why or "-", m.goal and m.goal.name or "none")
    local s = {}
    for _, g in ipairs(m.suggestions) do s[#s + 1] = string.format("%s (%s, %d left)", g.zone.name, g.rule, g.left) end
    ns.Printf("  suggestions: %s", #s > 0 and table.concat(s, ", ") or "none")
    local r = {}
    for _, z in ipairs(m.recent) do r[#r + 1] = z.name end
    ns.Printf("  recent zones: %s; discoveries today: %d", #r > 0 and table.concat(r, ", ") or "none", m.activity.today)
    ns.Debug.Trace("overview", { percent = p and p.percent, completed = p and p.completed,
        denominator = p and p.denominator, zones = m.zones, hero = m.hero and m.hero.zone.mapID,
        heroWhy = m.hero and m.hero.why, goal = m.goal and m.goal.mapID, suggestions = s, recent = r,
        today = m.activity.today, milestones = #m.milestones })
end
