-- Class journey (Phase 13, the Class tab): this character's class quest road. The curated
-- stops come from Data/ClassJourneys.lua; done or not from the game's completed-quest list and
-- eligibility from ns.QuestRules, both through ns.Quests (QuestieDB is needed for eligibility,
-- so without it the road is "unavailable" with Quests' reason, never zero).
-- Rebuilt when quests change (AZF_QUESTS_UPDATED: a turn-in, a level, a refresh); announces
-- AZF_CLASS_UPDATED. Nothing is saved.
-- /azf debug class [questID ...] answers the Class tab's in-game checks
-- (docs/research/class-quests.md "Still to check in game"); read it with
-- `luajit tools/trace-report.lua class`.
local _, ns = ...

local ClassJourney = {}
ns.ClassJourney = ClassJourney

local result -- cached Get() result for the current character and completed list

local function character()
    local c = ns.character or {}
    return { classFile = c.classFile, side = c.faction, raceID = c.raceID, raceFile = c.raceFile, level = c.level }
end

-- This character's road:
--   { status = "ready", journey = ClassJourneyRules.Build result, char }
--   { status = "none", reason }            no curated road for this class and side
--   { status = "building"|"unavailable"|"idle", reason }   Quests isn't ready
function ClassJourney.Get()
    if result then return result end
    local char = character()
    local R = ns.ClassJourneyRules
    local journey = R.Journey(ns.ClassJourneyData, char.classFile, char.side)
    if not journey then
        return { status = "none", reason = "no class road for " .. tostring(char.classFile) .. " " .. tostring(char.side), char = char }
    end
    local qs = ns.Quests.State()
    if qs.status ~= "ready" then return { status = qs.status, reason = qs.reason, char = char } end
    local ctx = ns.Quests.Context()
    local function ev(id) return ns.QuestRules.Evaluate(ctx, id) end
    result = { status = "ready", char = char,
        journey = R.Build(journey, ev, ctx.completed, ns.QuestRules.RaceBit(char.raceID), char.level) }
    return result
end

function ClassJourney.Invalidate() result = nil end

ns.Events.On("AZF_QUESTS_UPDATED", function()
    result = nil
    ns.Events.Send("AZF_CLASS_UPDATED")
end)

---------------------------------------------------------------------------------------------
-- Debug
---------------------------------------------------------------------------------------------

-- Quest IDs above the 1.12 range: Season of Discovery era (78000-79999) and Forever (90000+).
local function newer(id) return (id >= 78000 and id < 80000) or id >= 90000 end

local function stopLine(s)
    local parts = {}
    for _, st in ipairs(s.steps) do parts[#parts + 1] = st.id .. ":" .. st.state end
    return string.format("%s %s %s %s/%s%s %s [%s]", s.kind, tostring(s.state), s.name, tostring(s.done or "?"), s.count,
        s.route and (" route " .. s.route) or "", s.order and "(order inferred)" or "", table.concat(parts, " "))
end

function ClassJourney.DebugReport(args)
    ClassJourney.Invalidate()
    local g = ClassJourney.Get()
    local c = g.char or character()
    local raceBit = ns.QuestRules.RaceBit(c.raceID)
    local entry = { report = true, status = g.status, reason = g.reason,
        character = string.format("%s %s raceID=%s raceFile=%s raceBit=%s level=%s", tostring(c.classFile), tostring(c.side),
            tostring(c.raceID), tostring(c.raceFile), raceBit and string.format("%.0f", raceBit) or "nil", tostring(c.level)) }
    ns.Printf("Class road: %s (%s)", tostring(g.status), entry.character)
    if g.status ~= "ready" then
        if g.reason then ns.Printf("  %s", g.reason) end
        ns.Debug.Trace("class", entry)
        return
    end
    local j, ctx = g.journey, ns.Quests.Context()
    local done = ctx and ctx.completed
    entry.totals = string.format("road %d/%d, side paths %d/%d, quests %d/%d, unknown stops %d, complete %s",
        j.road.done, j.road.count, j.side.done, j.side.count, j.quests.done, j.quests.count, j.unknown, tostring(j.complete))
    entry.completedKnown = done ~= nil
    -- Each stop with its steps; extras (lead-ins, repeatable-flagged sub-quests) with their state.
    entry.stops, entry.extras, entry.inferred = {}, {}, {}
    for i, s in ipairs(j.stops) do
        entry.stops[string.format("%02d %s", i, s.key)] = stopLine(s)
        local ex = {}
        for _, e in ipairs(s.extra) do ex[#ex + 1] = e.id .. ":" .. e.state end
        if #ex > 0 then entry.extras[s.key] = table.concat(ex, " ") end
        -- Stops whose order was inferred: do QuestieDB's in-game corrections link them?
        if s.order then
            local links = {}
            for _, st in ipairs(s.steps) do
                local r = ns.Quests.Info(st.id) or {}
                local pre = r.preSingle or r.preGroup
                links[#links + 1] = string.format("%d pre=%s next=%s", st.id,
                    type(pre) == "table" and table.concat(pre, ",") or tostring(pre or "-"), tostring(r.next or "-"))
            end
            entry.inferred[s.key] = table.concat(links, " | ")
        end
    end
    -- Every curated ID in QuestieDB's composed view (corrections applied): missing ones, and
    -- the newer IDs (78xxx, 9xxxx) that are there.
    local missing, newerSeen, total = {}, 0, 0
    for id in pairs(ns.ClassJourneyRules.AllIds(ns.ClassJourneyData)) do
        total = total + 1
        local p = ns.Quests.Probe(id)
        if p and p.exists == false then missing[#missing + 1] = id
        elseif p and p.exists and newer(id) then newerSeen = newerSeen + 1 end
    end
    table.sort(missing)
    entry.ids = string.format("%d curated IDs, %d not in QuestieDB, %d newer IDs present", total, #missing, newerSeen)
    entry.missing = table.concat(missing, " ")
    -- Quests asked for on the command line: QuestieDB's view, completed, eligibility.
    entry.probes = {}
    for _, a in ipairs(args or {}) do
        local id = tonumber(a)
        if id then
            local p = ns.Quests.Probe(id) or {}
            local s, why = ns.QuestRules.Evaluate(ctx, id)
            entry.probes[tostring(id)] = string.format("%s exists=%s completed=%s %s%s zoneOrSort=%s%s", tostring(p.name),
                tostring(p.exists), done and tostring(done[id] == true) or "unknown", tostring(s), why and (" (" .. why .. ")") or "",
                tostring(p.zoneOrSort), p.repeatable and " repeatable" or "")
        end
    end
    ns.Printf("  %s: %s", tostring(j.title), entry.totals)
    ns.Printf("  %s", entry.ids)
    for i, s in ipairs(j.stops) do ns.Printf("  %d. %s %s %s/%s", i, s.name, tostring(s.state), tostring(s.done or "?"), s.count) end
    ns.Print(ns.Debug.IsEnabled() and "  Full report in the trace: /reload, then luajit tools/trace-report.lua class"
        or "  Debug mode is off, so nothing was saved: type /azf debug, then run this again.")
    ns.Debug.Trace("class", entry)
end
