-- Quest catalogue (Phase 9 step 2): which quests belong to which zone, read at runtime from
-- QuestieDB, an optional dependency (decision 2026-11-08, docs/research/quest-data.md).
-- Each quest's `zoneOrSort` and `specialFlags` are read once per session, in batches across
-- frames, and sorted into a per-zone index with Data/QuestAreas.lua (curated, unofficial).
-- Left out of zone counts, each counted by reason for the coverage note: repeatable quests,
-- quest sorts (class, profession, holiday...), quests with no zone, battleground quests,
-- unmapped areas and read errors. Dungeon and raid quests aren't in zone counts either; they
-- are kept per instance for a Dungeons tab later.
-- No completion or eligibility here (step 3), and nothing is shown yet (step 4).
-- Without QuestieDB, or with a contract it doesn't support, quests are "unavailable" with the
-- reason, never zero. Exploration never depends on this.
-- Everything above "Live" is pure, so tests can load it without the client.
local _, ns = ...

local Quests = {}
ns.Quests = Quests

Quests.CONTRACT = 4      -- QuestieDB contract this was written against [verified-ingame]
Quests.BATCH = 500       -- quests per frame: about 2 reads each, ~1.5 ms [measured: 13 fields x 5,233 = 36 ms]
Quests.START_DELAY = 5   -- seconds after AZF_READY: after the exploration baseline (3 s)

-- Reasons a quest isn't in a zone count. "dungeon" and "raid" are kept per instance.
Quests.REASONS = { "repeatable", "sort", "nozone", "dungeon", "raid", "battleground", "unmapped", "error" }

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

-- Pure: specialFlags bit 1 = repeatable [verified-files, QuestieDB questMeta].
function Quests.IsRepeatable(flags)
    return type(flags) == "number" and flags % 2 == 1
end

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

-- Pure: adds one quest. ok = false when its fields couldn't be read (counted as "error").
function Quests.Add(index, id, zoneOrSort, specialFlags, areas, ok)
    index.total = index.total + 1
    local left = index.left
    if ok == false then
        left.error = left.error + 1
        return "error"
    end
    local kind, key = Quests.Place(zoneOrSort, areas)
    if Quests.IsRepeatable(specialFlags) then
        left.repeatable = left.repeatable + 1
        if kind == "zone" then
            local z = index.zones[key]
            if not z then z = { ids = {}, repeatable = 0 }; index.zones[key] = z end
            z.repeatable = z.repeatable + 1
        end
        return "repeatable"
    end
    if kind == "zone" then
        local z = index.zones[key]
        if not z then z = { ids = {}, repeatable = 0 }; index.zones[key] = z end
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

-- Pure: a builder that reads `ids` through the reader table Q (QuestieDB's Quest API) in
-- steps. builder.Step(n) reads up to n quests and returns true when every quest is read.
-- Every read is pcall'd; a quest whose read fails counts as "error".
function Quests.Builder(Q, ids, areas)
    local index, pos = Quests.NewIndex(), 0
    local b = { index = index, steps = 0 }
    function b.Step(n)
        local last = math.min(#ids, pos + (n or Quests.BATCH))
        for i = pos + 1, last do
            local id = ids[i]
            local ok1, zs = pcall(Q.zoneOrSort, id)
            local ok2, flags = pcall(Q.specialFlags, id)
            Quests.Add(index, id, ok1 and zs or nil, ok2 and flags or nil, areas, ok1 and ok2)
        end
        pos = last
        b.steps = b.steps + 1
        return pos >= #ids
    end
    function b.Progress() return pos, #ids end
    return b
end

-- Pure: a zone's quests from a finished index.
--   { status = "ready", mapID, ids, count, repeatable }   (count 0 = QuestieDB has none there)
--   { status = "unavailable"|"building", reason }
function Quests.ZoneFrom(state, mapID)
    if not state or state.status ~= "ready" then
        return { status = state and state.status or "unavailable", reason = state and state.reason }
    end
    local z = state.index.zones[mapID]
    local ids = z and z.ids or {}
    return { status = "ready", mapID = mapID, ids = ids, count = #ids, repeatable = z and z.repeatable or 0 }
end

---------------------------------------------------------------------------------------------
-- Live
---------------------------------------------------------------------------------------------

-- state.status: "idle" (not started), "building", "ready", "unavailable" (with reason)
local state = { status = "idle" }

local function clock() return type(debugprofilestop) == "function" and debugprofilestop() or nil end
local function round(ms) return ms and math.floor(ms * 100 + 0.5) / 100 or nil end

function Quests.State() return state end

local function finish(b, started, maxStep)
    local ms = started and clock() and (clock() - started) or nil
    state = { status = "ready", index = b.index, steps = b.steps, maxStepMs = round(maxStep),
        workMs = round(b.workMs), elapsedMs = round(ms) }
    local i = b.index
    ns.Debug.Trace("quests", { status = "ready", total = i.total, counted = i.counted, left = i.left,
        steps = b.steps, workMs = state.workMs, maxStepMs = state.maxStepMs })
    ns.Events.Send("AZF_QUESTS_UPDATED")
end

local function unavailable(reason)
    state = { status = "unavailable", reason = reason }
    ns.Debug.Trace("quests", { status = "unavailable", reason = reason })
    ns.Events.Send("AZF_QUESTS_UPDATED")
end

-- Starts the one-time build (no-op once started). The index is the same for every character;
-- eligibility and completion come later (step 3).
function Quests.Start()
    if state.status ~= "idle" then return end
    local lib = rawget(_G, "LibQuestieDB")
    local ok, reason = Quests.Detect(lib)
    if not ok then return unavailable(reason) end
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
        local ran, done = pcall(b.Step, Quests.BATCH)
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

-- A zone's quests (a mapID or { mapID }); see Quests.ZoneFrom.
function Quests.ForZone(zone)
    local mapID = type(zone) == "table" and zone.mapID or zone
    return Quests.ZoneFrom(state, mapID)
end

ns.Events.On("AZF_READY", function()
    ns.Events.Debounce("quests-build", Quests.START_DELAY, Quests.Start)
end)

-- /azf debug quests: the catalogue's state and counts, in chat and the trace.
function Quests.DebugReport()
    if state.status == "idle" then Quests.Start() end
    if state.status ~= "ready" then
        local pos, n
        if state.builder then pos, n = state.builder.Progress() end
        ns.Printf("Quests: %s%s%s", state.status, state.reason and (" (" .. state.reason .. ")") or "",
            pos and string.format(", %d/%d read", pos, n) or "")
        ns.Debug.Trace("quests", { report = true, status = state.status, reason = state.reason })
        return
    end
    local i = state.index
    local L = i.left
    ns.Printf("Quests: %d in QuestieDB, %d in zone counts (built in %d frames, %s ms work, %s ms max frame)",
        i.total, i.counted, state.steps, tostring(state.workMs), tostring(state.maxStepMs))
    ns.Printf("  left out: repeatable %d, quest sorts %d, no zone %d, dungeon %d, raid %d, battleground %d, unmapped %d, errors %d",
        L.repeatable, L.sort, L.nozone, L.dungeon, L.raid, L.battleground, L.unmapped, L.error)

    -- Our zone list against the index: zones with no quests, and indexed maps we don't list.
    local listed, zones, empty, notListed = {}, {}, {}, {}
    for _, s in ipairs(ns.Maps.Sections()) do
        for _, z in ipairs(s.zones) do
            listed[z.mapID] = true
            local q = Quests.ForZone(z.mapID)
            zones[#zones + 1] = string.format("%d %s %d (+%d repeatable)", z.mapID, tostring(z.name), q.count, q.repeatable)
            if q.count == 0 then empty[#empty + 1] = tostring(z.name) end
        end
    end
    for mapID, z in pairs(i.zones) do
        if not listed[mapID] then notListed[#notListed + 1] = string.format("%d (%d)", mapID, #z.ids) end
    end
    table.sort(notListed)
    local unmapped = {}
    for areaID, n in pairs(i.unmapped) do
        local name = C_Map and type(C_Map.GetAreaInfo) == "function" and ns.Debug.Try("GetAreaInfo", C_Map.GetAreaInfo, areaID)
        unmapped[#unmapped + 1] = string.format("%d %s (%d)", areaID, tostring(name or "?"), n)
    end
    table.sort(unmapped)
    local here = ns.Exploration and ns.Exploration.CurrentZone and ns.Exploration.CurrentZone()
    local hq = here and Quests.ForZone(here)
    if hq then ns.Printf("  this zone (%d): %d quests, %d repeatable left out", here, hq.count, hq.repeatable) end
    ns.Printf("  listed zones without quests: %s", #empty > 0 and table.concat(empty, ", ") or "none")
    ns.Printf("  indexed maps not in the zone list: %s", #notListed > 0 and table.concat(notListed, ", ") or "none")
    ns.Printf("  unmapped areas: %s", #unmapped > 0 and table.concat(unmapped, ", ") or "none")
    local instances = 0
    for _ in pairs(i.instances) do instances = instances + 1 end
    ns.Debug.Trace("quests", { report = true, status = "ready", total = i.total, counted = i.counted, left = L,
        instances = instances, zones = zones, empty = empty, notListed = notListed, unmapped = unmapped,
        sorts = i.sorts, steps = state.steps, workMs = state.workMs, maxStepMs = state.maxStepMs,
        elapsedMs = state.elapsedMs, here = here, hereCount = hq and hq.count })
end
