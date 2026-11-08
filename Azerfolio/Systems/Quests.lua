-- Quest catalogue and tracker (Phase 9 steps 2-3): which quests belong to which zone, read at
-- runtime from QuestieDB, an optional dependency (decision 2026-11-08,
-- docs/research/quest-data.md), with this character's completion and eligibility.
--
-- Build, once per session, in batches across frames:
--   1. index: each quest's zoneOrSort, specialFlags and questFlags, sorted into zones with
--      Data/QuestAreas.lua (curated, unofficial). Left out of zone counts, each counted by
--      reason for the coverage note: repeatable, quest sorts (class, profession, holiday...),
--      no zone, battleground, unmapped areas, read errors. Dungeon and raid quests aren't in
--      zone counts either; they're kept per instance for a Dungeons tab later.
--   2. details: the fields eligibility needs, for every quest in a zone (Quests.ReadDetails).
-- Completion comes from the client's completed-quest list (C_QuestLog.GetAllCompletedQuestIDs
-- [verified-ingame]), re-read after QUEST_TURNED_IN [verified-ingame, sniffer]. Eligibility is
-- ns.QuestRules; counts come from ns.Progression. The UI shows what this returns.
-- Without QuestieDB, or with a contract it doesn't support, quests are "unavailable" with the
-- reason, never zero. Exploration never depends on this.
-- Everything above "Live" is pure, so tests can load it without the client.
local _, ns = ...

local Quests = {}
ns.Quests = Quests

Quests.CATEGORY = "quests"
Quests.CONTRACT = 4      -- QuestieDB contract this was written against [verified-ingame]
Quests.BATCH = 500       -- index pass: quests per frame (3 reads each; 8.6 ms for 5,233 in game)
Quests.DETAIL_BATCH = 50 -- details pass: quests per frame (20 reads each; 100 gave one 15.7 ms frame)
Quests.START_DELAY = 5   -- seconds after AZF_READY: after the exploration baseline (3 s)
Quests.REFRESH_DELAY = 1 -- after QUEST_TURNED_IN, so the completed list has the quest [unverified]

-- Reasons a quest isn't in a zone count. "dungeon" and "raid" are kept per instance.
Quests.REASONS = { "repeatable", "sort", "nozone", "dungeon", "raid", "battleground", "unmapped", "error" }

local function rules() return ns.QuestRules end

---------------------------------------------------------------------------------------------
-- Pure
---------------------------------------------------------------------------------------------

-- Pure: is QuestieDB usable? lib = the LibQuestieDB global (or nil).
-- Returns true, or false and a reason for the coverage note.
function Quests.Detect(lib)
    if type(lib) ~= "table" then return false, "QuestieDB is not loaded" end
    if type(lib.RequireContract) ~= "function" then return false, "QuestieDB has no contract check" end
    local ok, fine, message = pcall(lib.RequireContract, Quests.CONTRACT)
    if not ok then return false, "QuestieDB contract check failed: " .. tostring(fine) end
    if not fine then
        return false, "QuestieDB contract " .. tostring(lib.contractVersion) .. " doesn't support "
            .. Quests.CONTRACT .. (message and (": " .. tostring(message)) or "")
    end
    local Q = lib.Quest
    if type(Q) ~= "table" or type(Q.GetAllIds) ~= "function" or type(Q.zoneOrSort) ~= "function"
        or type(Q.specialFlags) ~= "function" then
        return false, "QuestieDB has no quest readers"
    end
    return true
end

-- Pure: specialFlags bit 1, or a daily/weekly/monthly questFlags bit [verified-files].
function Quests.IsRepeatable(flags, questFlags) return rules().IsRepeatable(flags, questFlags) end

-- Pure: where a quest's zoneOrSort puts it. Returns kind, key:
--   "zone", mapID | "dungeon", areaID | "raid", areaID | "battleground", areaID
--   "sort", sortID (negative) | "nozone", nil | "unmapped", areaID
function Quests.Place(zoneOrSort, areas)
    local v = zoneOrSort
    if type(v) ~= "number" or v == 0 then return "nozone", nil end
    if v < 0 then return "sort", v end
    areas = areas or {}
    local map = areas.zone and areas.zone[v]
    if map then return "zone", map end
    if areas.dungeon and areas.dungeon[v] then return "dungeon", v end
    if areas.raid and areas.raid[v] then return "raid", v end
    if areas.battleground and areas.battleground[v] then return "battleground", v end
    return "unmapped", v
end

-- Pure: an empty index.
--   zones[mapID] = { ids = {questID...}, repeatable = n }   counted quests, and the zone's
--                                                         repeatables left out (for its note)
--   instances[areaID] = { kind = "dungeon"|"raid", ids }  kept for a Dungeons tab later
--   left[reason] = n          quests left out of zone counts, by reason (Quests.REASONS)
--   unmapped[areaID] = n      quests per unmapped area; sorts[sortID] = n
--   total = quests seen, counted = quests in a zone
function Quests.NewIndex()
    local left = {}
    for _, r in ipairs(Quests.REASONS) do left[r] = 0 end
    return { zones = {}, instances = {}, left = left, unmapped = {}, sorts = {}, total = 0, counted = 0 }
end

local function zoneOf(index, mapID)
    local z = index.zones[mapID]
    if not z then z = { ids = {}, repeatable = 0 }; index.zones[mapID] = z end
    return z
end

-- Pure: adds one quest. ok = false when its fields couldn't be read (counted as "error").
function Quests.Add(index, id, zoneOrSort, specialFlags, areas, ok, questFlags)
    index.total = index.total + 1
    local left = index.left
    if ok == false then
        left.error = left.error + 1
        return "error"
    end
    local kind, key = Quests.Place(zoneOrSort, areas)
    if Quests.IsRepeatable(specialFlags, questFlags) then
        left.repeatable = left.repeatable + 1
        if kind == "zone" then
            local z = zoneOf(index, key)
            z.repeatable = z.repeatable + 1
        end
        return "repeatable"
    end
    if kind == "zone" then
        local z = zoneOf(index, key)
        z.ids[#z.ids + 1] = id
        index.counted = index.counted + 1
        return kind
    end
    left[kind] = left[kind] + 1
    if kind == "dungeon" or kind == "raid" then
        local inst = index.instances[key]
        if not inst then inst = { kind = kind, ids = {} }; index.instances[key] = inst end
        inst.ids[#inst.ids + 1] = id
    elseif kind == "unmapped" then
        index.unmapped[key] = (index.unmapped[key] or 0) + 1
    elseif kind == "sort" then
        index.sorts[key] = (index.sorts[key] or 0) + 1
    end
    return kind
end

-- Fields read for eligibility and the checklist: record key -> QuestieDB reader.
Quests.DETAIL_FIELDS = {
    name = "name", level = "questLevel", reqLevel = "requiredLevel", maxLevel = "requiredMaxLevel",
    races = "requiredRaces", classes = "requiredClasses", preGroup = "preQuestGroup",
    preSingle = "preQuestSingle", exclusive = "exclusiveTo", next = "nextQuestInChain",
    parent = "parentQuest", breadcrumbFor = "breadcrumbForQuestId",
    untilCompleted = "availableUntilCompleted", startingWith = "availableStartingWith",
}
-- Requirements not checked yet: any of these makes the quest's eligibility unknown.
Quests.NEEDS_FIELDS = {
    { "requiredSkill", "profession" }, { "requiredRanks", "profession" },
    { "requiredSpecialization", "profession" }, { "requiredMinRep", "reputation" },
    { "requiredMaxRep", "reputation" }, { "requiredSpell", "spell" },
}

local function present(v)
    if v == nil or v == false or v == 0 then return false end
    if type(v) == "table" then return next(v) ~= nil end
    return true
end

-- Pure: one quest's record from the reader table Q. Readers the API doesn't have are skipped.
-- Only fields with a value are kept (memory). err = true when a read failed.
--   { name, level, reqLevel, maxLevel, races, classes, preGroup, preSingle, exclusive, next,
--     parent, breadcrumbFor, untilCompleted, startingWith, needs = "profession"|... , err }
function Quests.ReadDetails(Q, id)
    local r = {}
    for key, field in pairs(Quests.DETAIL_FIELDS) do
        local reader = Q[field]
        if type(reader) == "function" then
            local ok, v = pcall(reader, id)
            if not ok then r.err = true
            elseif present(v) then r[key] = v end
        end
    end
    for _, n in ipairs(Quests.NEEDS_FIELDS) do
        local reader = Q[n[1]]
        if type(reader) == "function" and not r.needs then
            local ok, v = pcall(reader, id)
            if not ok then r.err = true
            elseif present(v) then r.needs = n[2] end
        end
    end
    return r
end

-- Pure: a builder that reads `ids` through the reader table Q (QuestieDB's Quest API) in
-- steps: the index first, then details for every quest in a zone. builder.Step(n, d) reads up
-- to n quests in the index pass or d in the details pass (defaults BATCH, DETAIL_BATCH) and
-- returns true when both passes are done. Every read is pcall'd; a quest whose index read fails counts as "error".
function Quests.Builder(Q, ids, areas)
    local index, pos = Quests.NewIndex(), 0
    local details, todo, dpos = {}, nil, 0
    local b = { index = index, details = details, steps = 0, phase = "index" }
    local qf = type(Q.questFlags) == "function" and Q.questFlags or nil
    function b.Step(n, d)
        b.steps = b.steps + 1
        if b.phase == "index" then
            local last = math.min(#ids, pos + (n or Quests.BATCH))
            for i = pos + 1, last do
                local id = ids[i]
                local ok1, zs = pcall(Q.zoneOrSort, id)
                local ok2, flags = pcall(Q.specialFlags, id)
                local ok3, qflags = true, nil
                if qf then ok3, qflags = pcall(qf, id) end
                Quests.Add(index, id, ok1 and zs or nil, ok2 and flags or nil, areas, ok1 and ok2 and ok3,
                    ok3 and qflags or nil)
            end
            pos = last
            if pos >= #ids then
                todo = {}
                for _, z in pairs(index.zones) do
                    for _, id in ipairs(z.ids) do todo[#todo + 1] = id end
                end
                table.sort(todo)
                b.phase = "details"
            end
            return false
        end
        local last = math.min(#todo, dpos + math.max(1, d or Quests.DETAIL_BATCH))
        for i = dpos + 1, last do
            details[todo[i]] = Quests.ReadDetails(Q, todo[i])
        end
        dpos = last
        if dpos >= #todo then b.phase = "done"; return true end
        return false
    end
    function b.Progress()
        if b.phase == "index" then return pos, #ids, "index" end
        return dpos, todo and #todo or 0, b.phase
    end
    return b
end

-- Pure: a zone's quest objectives and progress for one character.
--   ctx: QuestRules.Context; ids: the zone's quest IDs; mapID; repeatable: left out count.
--   { status = "ready", mapID, objectives, progress, count, repeatable, reasons = { [reason] = n } }
-- objectives: ns.Objectives (category "quests", id = questID) plus questLevel, reqLevel, reason.
-- The set's coverage is "complete" when every quest was read without error; QuestieDB is the
-- catalogue (the coverage note says so and lists what's left out).
function Quests.Evaluate(ctx, mapID, ids, repeatable)
    local O, R = ns.Objectives, rules()
    local objectives, reasons, coverage = {}, {}, "complete"
    for _, id in ipairs(ids or {}) do
        local info = ctx.info(id)
        if not info or info.err then coverage = "partial" end
        local elig, why = R.Evaluate(ctx, id)
        local o = O.New({ id = id, category = Quests.CATEGORY, zone = mapID, name = info and info.name,
            completion = R.Completion(ctx.completed, id), eligibility = elig, source = "questiedb" })
        o.questLevel, o.reqLevel, o.reason = info and info.level, info and info.reqLevel, why
        objectives[#objectives + 1] = o
        if why then reasons[why] = (reasons[why] or 0) + 1 end
    end
    local progress = ns.Progression.Aggregate({ { category = Quests.CATEGORY, coverage = coverage, objectives = objectives } })
    return { status = "ready", mapID = mapID, objectives = objectives, progress = progress,
        count = #objectives, repeatable = repeatable or 0, reasons = reasons, coverage = coverage }
end

---------------------------------------------------------------------------------------------
-- Live
---------------------------------------------------------------------------------------------

-- state.status: "idle" (not started), "building", "ready", "unavailable" (with reason)
local state = { status = "idle" }
local completed      -- { [questID] = true }, or nil when the client gives no list
local ctx            -- QuestRules context for the current character and completed list
local results = {}   -- [mapID] = Evaluate result (cleared on turn-in, level change, refresh)
local lib            -- LibQuestieDB, once detected

local function clock() return type(debugprofilestop) == "function" and debugprofilestop() or nil end
local function round(ms) return ms and math.floor(ms * 100 + 0.5) / 100 or nil end
local function try(label, fn, ...) return ns.Debug.Try(label, fn, ...) end

function Quests.State() return state end

-- The client's completed quests as a set, or nil when it can't say.
function Quests.ReadCompleted()
    if C_QuestLog and type(C_QuestLog.GetAllCompletedQuestIDs) == "function" then
        local list = try("GetAllCompletedQuestIDs", C_QuestLog.GetAllCompletedQuestIDs)
        if type(list) == "table" then
            local s = {}
            for _, id in ipairs(list) do s[id] = true end
            return s, #list
        end
    end
    return nil
end

local function character()
    local c = ns.character or {}
    return { raceID = c.raceID, classID = c.classID, level = c.level }
end

-- Record for a quest: from the details pass, or read now (prerequisites outside any zone).
local function info(id)
    local d = state.details
    if not d then return nil end
    local r = d[id]
    if r == nil then
        local Q = lib and lib.Quest
        local exists = Q and type(Q.Exists) == "function" and try("QuestDB.Exists", Q.Exists, id)
        r = exists and Quests.ReadDetails(Q, id) or false
        d[id] = r
    end
    return r or nil
end

local function context()
    if not ctx then ctx = ns.QuestRules.Context(info, completed, character()) end
    return ctx
end

-- Forget per-character results (completion, level or character changed).
function Quests.Invalidate()
    ctx, results = nil, {}
end

local function finish(b, started, maxStep)
    local ms = started and clock() and (clock() - started) or nil
    completed = Quests.ReadCompleted()
    Quests.Invalidate()
    state = { status = "ready", index = b.index, details = b.details, steps = b.steps,
        maxStepMs = round(maxStep), workMs = round(b.workMs), elapsedMs = round(ms) }
    local i = b.index
    ns.Debug.Trace("quests", { status = "ready", total = i.total, counted = i.counted, left = i.left,
        steps = b.steps, workMs = state.workMs, maxStepMs = state.maxStepMs, completedKnown = completed ~= nil })
    ns.Events.Send("AZF_QUESTS_UPDATED")
end

local function unavailable(reason)
    state = { status = "unavailable", reason = reason }
    ns.Debug.Trace("quests", { status = "unavailable", reason = reason })
    ns.Events.Send("AZF_QUESTS_UPDATED")
end

-- Starts the one-time build (no-op once started). The index and details are the same for
-- every character; eligibility is evaluated per character on demand.
function Quests.Start()
    if state.status ~= "idle" then return end
    local L = rawget(_G, "LibQuestieDB")
    local ok, reason = Quests.Detect(L)
    if not ok then return unavailable(reason) end
    lib = L
    local got, ids = pcall(lib.Quest.GetAllIds)
    if not got or type(ids) ~= "table" then
        return unavailable("QuestieDB's quest list couldn't be read")
    end
    local b = Quests.Builder(lib.Quest, ids, ns.QuestAreaData)
    b.workMs = 0
    state = { status = "building", builder = b }
    local started, maxStep = clock(), 0
    local function step()
        local t0 = clock()
        local ran, done = pcall(b.Step, Quests.BATCH, Quests.DETAIL_BATCH)
        if t0 and clock() then
            local d = clock() - t0
            b.workMs = b.workMs + d
            if d > maxStep then maxStep = d end
        end
        if not ran then
            ns.Debug.Error("quests build", done)
            return unavailable("reading QuestieDB failed")
        end
        if done then return finish(b, started, maxStep) end
        C_Timer.After(0, step)
    end
    C_Timer.After(0, step)
end

-- A zone's quests (a mapID or { mapID }) for this character:
--   { status = "ready", mapID, objectives, progress, count, repeatable, reasons }  (see Evaluate;
--     count 0 = QuestieDB has none there)
--   { status = "building"|"unavailable"|"idle", reason }   no counts
function Quests.ForZone(zone)
    local mapID = type(zone) == "table" and zone.mapID or zone
    if state.status ~= "ready" then return { status = state.status, reason = state.reason } end
    local r = results[mapID]
    if r then return r end
    local z = state.index.zones[mapID]
    r = Quests.Evaluate(context(), mapID, z and z.ids or {}, z and z.repeatable or 0)
    results[mapID] = r
    return r
end

-- Every zone together: { status, progress, zones = zones with quests, left = index.left }.
function Quests.Overall()
    if state.status ~= "ready" then return { status = state.status, reason = state.reason } end
    local sets, zones = {}, 0
    for mapID in pairs(state.index.zones) do
        local r = Quests.ForZone(mapID)
        if r.count > 0 then
            zones = zones + 1
            sets[#sets + 1] = { category = Quests.CATEGORY, coverage = r.coverage, objectives = r.objectives }
        end
    end
    return { status = "ready", progress = ns.Progression.Aggregate(sets), zones = zones, left = state.index.left }
end

-- Re-read the completed list (after a turn-in or /azf refresh). Announces a change.
local function refreshCompleted(reason)
    if state.status ~= "ready" then return end
    local before = completed
    local n
    completed, n = Quests.ReadCompleted()
    local added = 0
    if completed and before then
        for id in pairs(completed) do if not before[id] then added = added + 1 end end
    end
    Quests.Invalidate()
    ns.Debug.Trace("quests", { refresh = reason, completed = n, added = added })
    ns.Events.Send("AZF_QUESTS_UPDATED")
end

ns.Events.On("AZF_READY", function()
    ns.Events.Debounce("quests-build", Quests.START_DELAY, Quests.Start)
end)
ns.Events.Register("QUEST_TURNED_IN", function()
    ns.Events.Debounce("quests-completed", Quests.REFRESH_DELAY, function() refreshCompleted("QUEST_TURNED_IN") end)
end)
ns.Events.On("AZF_REFRESH_REQUESTED", function() refreshCompleted("refresh") end)
ns.Events.On("AZF_LEVEL_CHANGED", function()
    if state.status ~= "ready" then return end
    Quests.Invalidate()
    ns.Events.Send("AZF_QUESTS_UPDATED")
end)

local function top(t, n)
    local list = {}
    for k, v in pairs(t) do list[#list + 1] = { k = k, v = v } end
    table.sort(list, function(a, b) if a.v ~= b.v then return a.v > b.v end return tostring(a.k) < tostring(b.k) end)
    local out = {}
    for i = 1, math.min(n, #list) do out[i] = string.format("%s %d", tostring(list[i].k), list[i].v) end
    return out
end

-- /azf debug quests: the catalogue's state and counts, in chat and the trace.
function Quests.DebugReport()
    if state.status == "idle" then Quests.Start() end
    if state.status ~= "ready" then
        local pos, n, phase
        if state.builder then pos, n, phase = state.builder.Progress() end
        ns.Printf("Quests: %s%s%s", state.status, state.reason and (" (" .. state.reason .. ")") or "",
            pos and string.format(", %s %d/%d", phase, pos, n) or "")
        ns.Debug.Trace("quests", { report = true, status = state.status, reason = state.reason })
        return
    end
    local i = state.index
    local L = i.left
    local t0 = clock()
    ns.Printf("Quests: %d in QuestieDB, %d in zone counts (built in %d frames, %s ms work, %s ms max frame)",
        i.total, i.counted, state.steps, tostring(state.workMs), tostring(state.maxStepMs))
    ns.Printf("  left out: repeatable %d, quest sorts %d, no zone %d, dungeon %d, raid %d, battleground %d, unmapped %d, errors %d",
        L.repeatable, L.sort, L.nozone, L.dungeon, L.raid, L.battleground, L.unmapped, L.error)

    -- Our zone list against the index: zones with no quests, and indexed maps we don't list.
    local listed, zones, empty, notListed = {}, {}, {}, {}
    local reasons = {}
    for _, s in ipairs(ns.Maps.Sections()) do
        for _, z in ipairs(s.zones) do
            listed[z.mapID] = true
            local q = Quests.ForZone(z.mapID)
            local p = q.progress
            zones[#zones + 1] = string.format("%d %s %d quests: %d/%d done, eligible %d, locked %d, unavailable %d, unknown %d, %s, coverage %s (+%d repeatable)",
                z.mapID, tostring(z.name), q.count, p.completed, p.denominator, p.eligible, p.locked, p.unavailable,
                p.eligibilityUnknown, ns.Progression.PercentText(p) or "no %", p.coverage, q.repeatable)
            if q.count == 0 then empty[#empty + 1] = tostring(z.name) end
            for why, n in pairs(q.reasons) do reasons[why] = (reasons[why] or 0) + n end
        end
    end
    for mapID, z in pairs(i.zones) do
        if not listed[mapID] then notListed[#notListed + 1] = string.format("%d (%d)", mapID, #z.ids) end
    end
    table.sort(notListed)
    local unmapped = {}
    for areaID, n in pairs(i.unmapped) do
        local name = C_Map and type(C_Map.GetAreaInfo) == "function" and try("GetAreaInfo", C_Map.GetAreaInfo, areaID)
        unmapped[#unmapped + 1] = string.format("%d %s (%d)", areaID, tostring(name or "?"), n)
    end
    table.sort(unmapped)

    local all = Quests.Overall()
    local ap = all.progress
    local evalMs = t0 and clock() and round(clock() - t0)
    local c = ns.character or {}
    ns.Printf("  %s (race %s, class %s, level %s); completed list: %s", tostring(c.name), tostring(c.raceID),
        tostring(c.classID), tostring(c.level), completed and "read" or "not available")
    ns.Printf("  all zones: %d/%d done (%s), eligible %d, locked %d, unavailable %d, unknown %d, coverage %s",
        ap.completed, ap.denominator, ns.Progression.PercentText(ap) or "no %", ap.eligible, ap.locked,
        ap.unavailable, ap.eligibilityUnknown, ap.coverage)
    ns.Printf("  reasons: %s", table.concat(top(reasons, 8), ", "))

    -- Where the character's completed quests fall: in a zone count, or left out and why.
    local done = {}
    if completed and lib then
        local Q = lib.Quest
        for id in pairs(completed) do
            local kind
            if type(Q.Exists) == "function" and not try("QuestDB.Exists", Q.Exists, id) then
                kind = "not in QuestieDB"
            else
                local zs = try("QuestDB.zoneOrSort", Q.zoneOrSort, id)
                local sf = try("QuestDB.specialFlags", Q.specialFlags, id)
                local qf = type(Q.questFlags) == "function" and try("QuestDB.questFlags", Q.questFlags, id) or nil
                kind = Quests.IsRepeatable(sf, qf) and "repeatable" or Quests.Place(zs, ns.QuestAreaData)
            end
            done[kind] = (done[kind] or 0) + 1
        end
        ns.Printf("  your completed quests by place: %s", table.concat(top(done, 10), ", "))
    end

    local here = ns.Exploration and ns.Exploration.CurrentZone and ns.Exploration.CurrentZone()
    local hq = here and Quests.ForZone(here)
    local hereList = {}
    if hq then
        local hp = hq.progress
        ns.Printf("  this zone (%d): %d quests, %d/%d done, eligible %d, locked %d, unavailable %d, unknown %d, %d repeatable left out",
            here, hq.count, hp.completed, hp.denominator, hp.eligible, hp.locked, hp.unavailable,
            hp.eligibilityUnknown, hq.repeatable)
        for _, o in ipairs(hq.objectives) do
            hereList[#hereList + 1] = string.format("%d %s L%s/%s %s %s %s", o.id, tostring(o.name),
                tostring(o.questLevel), tostring(o.reqLevel), o.completion, o.eligibility, tostring(o.reason or ""))
        end
    end
    ns.Printf("  listed zones without quests: %s", #empty > 0 and table.concat(empty, ", ") or "none")
    ns.Printf("  indexed maps not in the zone list: %s", #notListed > 0 and table.concat(notListed, ", ") or "none")
    ns.Printf("  unmapped areas: %s", #unmapped > 0 and table.concat(unmapped, ", ") or "none")
    local instances = 0
    for _ in pairs(i.instances) do instances = instances + 1 end
    ns.Debug.Trace("quests", { report = true, status = "ready", total = i.total, counted = i.counted, left = L,
        instances = instances, zones = zones, empty = empty, notListed = notListed, unmapped = unmapped,
        sorts = i.sorts, steps = state.steps, workMs = state.workMs, maxStepMs = state.maxStepMs,
        elapsedMs = state.elapsedMs, evalMs = evalMs, completedKnown = completed ~= nil,
        character = { name = c.name, raceID = c.raceID, classID = c.classID, level = c.level },
        all = { completed = ap.completed, denominator = ap.denominator, eligible = ap.eligible, locked = ap.locked,
            unavailable = ap.unavailable, unknown = ap.eligibilityUnknown, completionUnknown = ap.completionUnknown,
            coverage = ap.coverage, percent = ap.percent },
        reasons = reasons, here = here, hereList = hereList, completedByPlace = done })
end
