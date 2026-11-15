-- Dungeons: the game reads behind the Dungeons tab (Phase 16 task 3; spec §7.12, §8.13;
-- docs/research/dungeons.md). Systems/DungeonRules decides; this module builds its inputs:
--   * QuestieDB at runtime, once per session over frames (like Systems/ProfessionSources):
--     each instance quest's record in the DungeonRules shape (side from the race mask, class
--     mask, reputation rewards, earlier quests, giver and turn-in as place sources), the bosses'
--     and givers' NPC spawn areas (spawnAreas[npcID], for DungeonRules.PlaceContext), and every
--     item a boss NPC drops (npcDrops[itemID], with class, subclass and required level, for
--     DungeonRules.DropsByNpc and BossGear). Readers per Types/{Quest,Npc,Item}.t.lua, contract 4
--     [verified-files]; each one checked before use and every read pcall'd.
--   * Quest completion from Systems/Quests (the client's completed list). When the client gives
--     no list, `done` is unknown: CompletionKnown() is false and no quest is marked done.
--   * Item details from C_Item (name, quality, icon, slot as equipLoc, item level) [verified-ingame,
--     D1]; items the client hasn't cached are asked for and refreshed on GET_ITEM_INFO_RECEIVED.
--   * "In your bags" (and bank) and keys from C_Item.GetItemCount(id, true) [verified-ingame].
--   * Area names for areas Azerfolio doesn't map from C_Map.GetAreaInfo (pcall-guarded).
-- Without QuestieDB: status "unavailable" with the reason, and every reader returns nil.
-- Announces AZF_DUNGEONS_UPDATED (reason: "build" | "quests" | "items" | "bags").
--
-- Everything above "Live" is pure (no WoW globals), so tests load it with a fake QuestieDB.
local _, ns = ...
ns = ns or {}

local D = {}
ns.Dungeons = D

D.QUEST_BATCH = 20   -- quests between yields (about 22 reads each)
D.NPC_BATCH = 100    -- NPCs between yields (4 reads each)
-- Items between yields (1 read each; 4 more for the few a boss drops). At 500 the longest
-- stretch was 2.93 ms and the largest frame 5.9-6.9 ms (Gideon, 2026-11-15: 95 ms of work in
-- 21 frames, 205 ms elapsed); the first build after login once took a 14.8 ms frame (cold QuestieDB).
D.ITEM_BATCH = 250
D.FRAME_MS = 4       -- work per frame before waiting for the next
D.ITEM_REFRESH = 0.3 -- seconds to gather GET_ITEM_INFO_RECEIVED before announcing

-- QuestieDB's faction race masks when LibQuestieDB.Enum.factionRaceMasks is missing: the
-- classic races plus Forever's 2^32 / 2^33 (as tools/qdb.lua reads them) [verified-files].
D.DEFAULT_MASKS = { Alliance = 1 + 4 + 8 + 64 + 2 ^ 32, Horde = 2 + 16 + 32 + 128 + 2 ^ 33 }

local function hasBit(mask, bit) return math.floor(mask / bit) % 2 == 1 end

---------------------------------------------------------------------------------------------
-- Pure
---------------------------------------------------------------------------------------------

-- A quest's side from its race mask: "A" | "H" | nil (both, or no mask). masks = { Alliance,
-- Horde } (QuestieDB's factionRaceMasks; D.DEFAULT_MASKS when nil).
function D.SideOf(raceMask, masks)
    if type(raceMask) ~= "number" or raceMask <= 0 then return nil end
    masks = masks or D.DEFAULT_MASKS
    local A, H = masks.Alliance or D.DEFAULT_MASKS.Alliance, masks.Horde or D.DEFAULT_MASKS.Horde
    local a, h, b = false, false, 1
    while b <= raceMask do
        if hasBit(raceMask, b) then
            if hasBit(A, b) then a = true end
            if hasBit(H, b) then h = true end
        end
        b = b * 2
    end
    if a and not h then return "A" end
    if h and not a then return "H" end
    return nil
end

-- An NPC's spawn areas, ascending, from QuestieDB's spawns ({ [areaID] = coords }); its zoneID
-- when it has no spawns; {} when neither.
function D.SpawnAreas(spawns, zoneID)
    local out = {}
    if type(spawns) == "table" then
        for a in pairs(spawns) do if type(a) == "number" and a > 0 then out[#out + 1] = a end end
        table.sort(out)
    end
    if #out == 0 and type(zoneID) == "number" and zoneID > 0 then out[1] = zoneID end
    return out
end

-- A place source (DungeonRules header) from QuestieDB's startedBy / finishedBy
-- ({ npcIDs?, objectIDs?, itemIDs? }). npc(id) -> { name, areas, side } | nil; objectName(id),
-- itemName(id) -> name | nil; side = "A" | "H" | nil: of several NPCs, the first friendly to
-- it (friendlyToFaction "A" / "H" / "AH"; unknown counts as friendly), else the first known.
-- nil when QuestieDB names no starter.
function D.PlaceSource(by, npc, objectName, itemName, side)
    if type(by) ~= "table" then return nil end
    local npcs = by[1]
    if type(npcs) == "table" then
        local pick
        for _, id in ipairs(npcs) do
            local n = npc(id)
            if n then
                local friendly = not side or type(n.side) ~= "string" or n.side:find(side, 1, true) ~= nil
                if friendly then pick = n; break end
                pick = pick or n
            end
        end
        if pick then
            local s = { name = pick.name, kind = "npc" }
            if #pick.areas == 1 then s.area = pick.areas[1] elseif #pick.areas > 1 then s.areas = pick.areas end
            return s
        end
    end
    local objects, items = by[2], by[3]
    if type(objects) == "table" and type(objects[1]) == "number" then
        return { name = objectName and objectName(objects[1]) or nil, kind = "object" }
    end
    if type(items) == "table" and type(items[1]) == "number" then
        return { name = itemName and itemName(items[1]) or nil, kind = "item" }
    end
    return nil
end

local function addAll(out, seen, v)
    if type(v) == "number" and v > 0 then v = { v } end
    if type(v) ~= "table" then return end
    for _, id in ipairs(v) do
        if type(id) == "number" and not seen[id] then seen[id] = true; out[#out + 1] = id end
    end
end

-- One quest in the DungeonRules shape (done is set by the caller). d = Quests.ReadDetails's
-- record ({ name, level, reqLevel, races, classes, preSingle, preGroup, rep }).
function D.QuestRecord(id, d, giver, turnin, masks)
    local pre, seen = {}, {}
    addAll(pre, seen, d.preSingle)
    addAll(pre, seen, d.preGroup)
    local reps = {}
    for _, r in ipairs(type(d.rep) == "table" and d.rep or {}) do
        if type(r) == "table" and type(r[1]) == "number" and type(r[2]) == "number" then reps[#reps + 1] = { r[1], r[2] } end
    end
    return { id = id, name = d.name, level = d.level, reqLevel = d.reqLevel, side = D.SideOf(d.races, masks),
        classMask = type(d.classes) == "number" and d.classes or 0, reps = reps, giver = giver, turnin = turnin, pre = pre }
end

-- The quest IDs of every instance's quest area (wings share one), each once, and the boss NPC
-- IDs. index = Quests.Index(); data = ns.DungeonData.
function D.Plan(index, data)
    local quests, bosses, seenQ, seenN, areas = {}, {}, {}, {}, {}
    for _, inst in ipairs(data.instances) do
        local qa = inst.questArea
        if qa and not areas[qa] then
            areas[qa] = true
            local entry = index and index.instances and index.instances[qa]
            addAll(quests, seenQ, entry and entry.ids)
        end
        for _, b in ipairs(inst.bosses or {}) do addAll(bosses, seenN, b.npcs) end
    end
    table.sort(quests)
    return { questIDs = quests, bossNpcs = bosses }
end

-- The build, given QuestieDB (lib) and a plan ({ questIDs, bossNpcs, info(questID) -> details
-- record | nil, side, masks }). yield() is called between batches (coroutine.yield when run over
-- frames). Returns
--   { quests = { [questID] = record }, npcs = { [npcID] = { name, areas, side } | false },
--     spawnAreas = { [npcID] = { areaID, ... } }, npcDrops = { [itemID] = { npcID, ... } },
--     items = { [itemID] = { class, subclass, reqLevel } }, byNpc (DungeonRules.DropsByNpc),
--     counts = { quests, noRecord, npcs, itemsScanned, itemsKept, readErrors, itemList } }
-- npcDrops and items hold only the items a boss NPC drops (the full NPC list, for the world-drop
-- rule).
function D.Build(lib, plan, rawYield)
    rawYield = rawYield or function() end
    local out = { quests = {}, npcs = {}, spawnAreas = {}, npcDrops = {}, items = {},
        counts = { quests = 0, noRecord = 0, npcs = 0, itemsScanned = 0, itemsKept = 0, readErrors = 0 }, maxMs = {} }
    local c = out.counts
    -- The longest stretch between yields, per phase (plan.clock = debugprofilestop in game).
    local clk, phase, seg = plan.clock, "bosses", plan.clock and plan.clock()
    local function mark()
        if not clk then return end
        local d = clk() - seg
        if out.maxMs[phase] == nil or d > out.maxMs[phase] then out.maxMs[phase] = math.floor(d * 100 + 0.5) / 100 end
    end
    local function yield()
        mark()
        rawYield()
        if clk then seg = clk() end
    end
    local function enter(p) mark(); phase = p; if clk then seg = clk() end end
    local function rd(entity, field, id)
        local E = lib[entity]
        local f = type(E) == "table" and E[field]
        if type(f) ~= "function" then return nil end
        local ok, v = pcall(f, id)
        if not ok then c.readErrors = c.readErrors + 1; return nil end
        return v
    end
    local function npc(id)
        if out.npcs[id] ~= nil then return out.npcs[id] or nil end
        local name = rd("Npc", "name", id)
        if type(name) ~= "string" then out.npcs[id] = false; return nil end
        local areas = D.SpawnAreas(rd("Npc", "spawns", id), rd("Npc", "zoneID", id))
        local side = rd("Npc", "friendlyToFaction", id)
        local n = { name = name, areas = areas, side = type(side) == "string" and side or nil }
        out.npcs[id], out.spawnAreas[id] = n, areas
        c.npcs = c.npcs + 1
        return n
    end
    local function named(entity)
        return function(id)
            local v = rd(entity, "name", id)
            return type(v) == "string" and v or nil
        end
    end
    local objectName, itemName = named("Object"), named("Item")

    for i, id in ipairs(plan.bossNpcs or {}) do
        npc(id)
        if i % D.NPC_BATCH == 0 then yield() end
    end

    yield()
    enter("quests")
    for i, id in ipairs(plan.questIDs or {}) do
        local d = plan.info and plan.info(id)
        if type(d) == "table" then
            local giver = D.PlaceSource(rd("Quest", "startedBy", id), npc, objectName, itemName, plan.side)
            local turnin = D.PlaceSource(rd("Quest", "finishedBy", id), npc, objectName, itemName, plan.side)
            out.quests[id] = D.QuestRecord(id, d, giver, turnin, plan.masks)
            c.quests = c.quests + 1
        else
            c.noRecord = c.noRecord + 1
        end
        if i % D.QUEST_BATCH == 0 then yield() end
    end

    yield()
    local boss = {}
    for _, n in ipairs(plan.bossNpcs or {}) do boss[n] = true end
    enter("itemList")
    local ok, ids = false, nil
    if type(lib.Item) == "table" and type(lib.Item.GetAllIds) == "function" then ok, ids = pcall(lib.Item.GetAllIds) end
    yield()
    enter("items")
    if ok and type(ids) == "table" then
        c.itemList = true
        for i, id in ipairs(ids) do
            local drops = rd("Item", "npcDrops", id)
            if type(drops) == "table" then
                for _, n in ipairs(drops) do
                    if boss[n] then
                        out.npcDrops[id] = drops
                        out.items[id] = { class = rd("Item", "class", id), subclass = rd("Item", "subClass", id),
                            reqLevel = rd("Item", "requiredLevel", id) }
                        c.itemsKept = c.itemsKept + 1
                        break
                    end
                end
            end
            c.itemsScanned = i
            if i % D.ITEM_BATCH == 0 then yield() end
        end
    else
        c.itemList = false
    end
    yield()
    enter("drops")
    out.byNpc = ns.DungeonRules.DropsByNpc(out.npcDrops, out.items)
    mark()
    return out
end

-- Quest records with done from the completed set (nil = unknown: nothing is marked done).
-- Returns byArea[questArea] = { record, ... } (ascending IDs) for every instance quest area.
function D.QuestsFor(build, index, data, completed)
    local out = {}
    for _, inst in ipairs(data.instances) do
        local qa = inst.questArea
        if qa and not out[qa] then
            local list = {}
            local entry = index and index.instances and index.instances[qa]
            for _, id in ipairs(entry and entry.ids or {}) do
                local q = build.quests[id]
                if q then
                    q.done = completed and completed[id] and true or nil
                    list[#list + 1] = q
                end
            end
            table.sort(list, function(a, b) return a.id < b.id end)
            out[qa] = list
        end
    end
    return out
end

-- C_Item.GetItemInfo's returns as one table (nil without a name: not cached yet) [verified-ingame:
-- name, link, quality, item level, required level, type, subtype ... equipLoc, icon, ..., classID, subclassID].
function D.ItemFromInfo(name, _, quality, itemLevel, reqLevel, _, _, _, equipLoc, icon, _, classID, subclassID)
    if type(name) ~= "string" then return nil end
    return { name = name, quality = quality, itemLevel = itemLevel, reqLevel = reqLevel,
        equipLoc = type(equipLoc) == "string" and equipLoc ~= "" and equipLoc or nil, icon = icon,
        class = classID, subclass = subclassID }
end

---------------------------------------------------------------------------------------------
-- Live
---------------------------------------------------------------------------------------------

local state = { status = "idle" }
local build          -- D.Build's result, once ready
local ctxCache       -- DungeonRules.PlaceContext, once ready
local itemCache = {} -- [itemID] = merged item info (loaded ones only)
local pending = {}   -- [itemID] = true: asked the client for it
local pendingN = 0
local listening = false

local function clock() return type(debugprofilestop) == "function" and debugprofilestop() or nil end
local function round(ms) return ms and math.floor(ms * 100 + 0.5) / 100 or nil end

function D.State() return state end
function D.Ready() return state.status == "ready" end
function D.BuildResult() return build end

-- This character for DungeonRules: { level, faction, classFile, classBit }.
function D.Character()
    local c = ns.character or {}
    return { level = c.level, faction = c.faction, classFile = c.classFile, classBit = ns.QuestRules.ClassBit(c.classID) }
end

-- An instance by key; case doesn't matter (slash commands arrive lowercased).
function D.Instance(key)
    if type(key) ~= "string" then return nil end
    local want = key:lower()
    for _, inst in ipairs(ns.DungeonData.instances) do if inst.key:lower() == want then return inst end end
    return nil
end

local function completedSet()
    local ctx = ns.Quests.Context()
    return ctx and ctx.completed or nil
end

-- Does the client say which quests are done? (False: done is unknown, never zero.)
function D.CompletionKnown() return completedSet() ~= nil end

-- byArea[questArea] = this instance's quest records with done (nil before the build).
function D.QuestsByArea()
    if not build then return nil end
    return D.QuestsFor(build, ns.Quests.Index(), ns.DungeonData, completedSet())
end

-- One instance's quest records (all sides; DungeonRules.Progress picks this character's).
function D.Quests(inst)
    local by = D.QuestsByArea()
    if not by then return nil end
    return inst.questArea and by[inst.questArea] or {}
end

-- DungeonRules.Catalogue for this character: all, shown (nil before the build).
function D.Catalogue(filter)
    local by = D.QuestsByArea()
    if not by then return nil end
    return ns.DungeonRules.Catalogue(D.Character(), by, filter)
end

function D.PlaceContext()
    if not build then return nil end
    ctxCache = ctxCache or ns.DungeonRules.PlaceContext(build.spawnAreas)
    return ctxCache
end

-- A boss's own gear (item IDs), nil before the build.
function D.BossGear(inst, boss)
    if not build then return nil end
    return ns.DungeonRules.BossGear(inst, boss, build.byNpc, build.items)
end

local function cItem(name) return C_Item and type(C_Item[name]) == "function" and C_Item[name] or nil end

local function onItemInfo(itemID)
    if not pending[itemID] then return end
    pending[itemID] = nil
    pendingN = pendingN - 1
    itemCache[itemID] = nil
    if pendingN <= 0 and listening then
        pendingN = 0
        listening = false
        ns.Events.Unregister("GET_ITEM_INFO_RECEIVED", D.OnItemInfo)
    end
    ns.Events.Debounce("dungeons-items", D.ITEM_REFRESH, function() ns.Events.Send("AZF_DUNGEONS_UPDATED", "items") end)
end
function D.OnItemInfo(itemID) onItemInfo(itemID) end -- GET_ITEM_INFO_RECEIVED(itemID, success)

local function ask(id)
    if pending[id] then return end
    pending[id] = true
    pendingN = pendingN + 1
    if not listening then
        listening = ns.Events.Register("GET_ITEM_INFO_RECEIVED", D.OnItemInfo) ~= false
    end
    local req = cItem("RequestLoadItemDataByID")
    if req then pcall(req, id) end
end

-- An item for the page: { id, name, quality, icon, equipLoc, itemLevel, reqLevel, class, subclass,
-- loaded }. QuestieDB's class, subclass and required level fill in until the client has the item
-- (loaded = false; it's asked for, and AZF_DUNGEONS_UPDATED "items" follows).
function D.Item(id)
    if type(id) ~= "number" then return nil end
    if itemCache[id] then return itemCache[id] end
    local q = build and build.items[id] or {}
    local r = { id = id, class = q.class, subclass = q.subclass, reqLevel = q.reqLevel, loaded = false }
    local info = cItem("GetItemInfo")
    local g = info and (function(ok, ...) if ok then return D.ItemFromInfo(...) end end)(pcall(info, id))
    if g then
        for k, v in pairs(g) do r[k] = v end
        r.loaded = true
        itemCache[id] = r
        return r
    end
    local instant = cItem("GetItemInfoInstant")
    if instant then
        local ok, _, _, _, equipLoc, icon, classID, subclassID = pcall(instant, id)
        if ok then
            r.equipLoc = type(equipLoc) == "string" and equipLoc ~= "" and equipLoc or nil
            r.icon, r.class, r.subclass = icon, classID or r.class, subclassID or r.subclass
        end
    end
    local qual = cItem("GetItemQualityByID")
    if qual then
        local ok, v = pcall(qual, id)
        if ok and type(v) == "number" then r.quality = v end
    end
    ask(id)
    return r
end

-- How many you have in bags and bank, or nil when the client can't say.
function D.Count(id)
    local f = cItem("GetItemCount")
    if not f or type(id) ~= "number" then return nil end
    local ok, n = pcall(f, id, true)
    return ok and type(n) == "number" and n or nil
end

-- "For you" (DungeonRules.ForYou) for an item ID.
function D.ForYou(id)
    local c = D.Character()
    return ns.DungeonRules.ForYou(D.Item(id), c.classFile, c.level or 1)
end

-- An instance's keys with your count: { { key = data entry, item, count }, ... }.
function D.Keys(inst)
    local out = {}
    for _, k in ipairs(inst.keys or {}) do
        out[#out + 1] = { key = k, item = k.item and D.Item(k.item), count = k.item and D.Count(k.item) or nil }
    end
    return out
end

-- The client's name for an area (C_Map.GetAreaInfo), or nil.
function D.AreaName(areaID)
    if type(areaID) ~= "number" or not (C_Map and type(C_Map.GetAreaInfo) == "function") then return nil end
    local ok, name = pcall(C_Map.GetAreaInfo, areaID)
    return ok and type(name) == "string" and name ~= "" and name or nil
end

local function finish(info)
    local c = build.counts
    local gear = 0
    for _ in pairs(build.byNpc) do gear = gear + 1 end
    ctxCache = nil
    state = { status = "ready", workMs = round(info.workMs), maxStepMs = round(info.maxStep), steps = info.steps,
        elapsedMs = round(info.started and clock() and (clock() - info.started)), counts = c, npcsWithGear = gear }
    ns.Debug.Trace("dungeons", { event = "build", status = "ready", workMs = state.workMs, maxStepMs = state.maxStepMs,
        steps = info.steps, elapsedMs = state.elapsedMs, quests = c.quests, noRecord = c.noRecord, npcs = c.npcs,
        itemsScanned = c.itemsScanned, itemsKept = c.itemsKept, readErrors = c.readErrors, itemList = c.itemList,
        npcsWithGear = gear, phaseMaxMs = build.maxMs })
    ns.Events.Send("AZF_DUNGEONS_UPDATED", "build")
end

local function unavailable(reason)
    state = { status = "unavailable", reason = reason }
    ns.Debug.Trace("dungeons", { event = "build", status = "unavailable", reason = reason })
    ns.Events.Send("AZF_DUNGEONS_UPDATED", "build")
end

-- Starts the one-time build once Quests is ready (no-op once started, or while Quests builds).
function D.Start()
    if state.status ~= "idle" then return end
    local qs = ns.Quests.State()
    if qs.status == "unavailable" then return unavailable(qs.reason) end
    if qs.status ~= "ready" then return end
    local L = rawget(_G, "LibQuestieDB")
    local ok, reason = ns.Quests.Detect(L)
    if not ok then return unavailable(reason) end
    if type(L.Npc) ~= "table" or type(L.Npc.name) ~= "function" or type(L.Npc.spawns) ~= "function"
        or type(L.Item) ~= "table" or type(L.Item.GetAllIds) ~= "function" or type(L.Item.npcDrops) ~= "function"
        or type(L.Quest.startedBy) ~= "function" then
        return unavailable("QuestieDB has no NPC, item or quest-giver readers")
    end
    local masks = type(L.Enum) == "table" and type(L.Enum.factionRaceMasks) == "table" and L.Enum.factionRaceMasks or nil
    local plan = D.Plan(ns.Quests.Index(), ns.DungeonData)
    local f = (ns.character or {}).faction
    plan.side = f == "Alliance" and "A" or f == "Horde" and "H" or nil
    plan.masks = masks and { Alliance = masks.Alliance, Horde = masks.Horde } or nil
    plan.info = ns.Quests.Info
    plan.clock = type(debugprofilestop) == "function" and debugprofilestop or nil
    local info = { workMs = 0, maxStep = 0, steps = 0, started = clock() }
    local co = coroutine.create(function() build = D.Build(L, plan, coroutine.yield) end)
    state = { status = "building" }
    local function step()
        local t0 = clock()
        info.steps = info.steps + 1
        repeat
            local ran, err = coroutine.resume(co)
            if not ran then
                ns.Debug.Error("dungeons build", err)
                build = nil
                return unavailable("reading QuestieDB failed")
            end
        until coroutine.status(co) == "dead" or not t0 or not clock() or clock() - t0 >= D.FRAME_MS
        if t0 and clock() then
            local d = clock() - t0
            info.workMs = info.workMs + d
            if d > info.maxStep then info.maxStep = d end
        end
        if coroutine.status(co) == "dead" then return finish(info) end
        C_Timer.After(0, step)
    end
    C_Timer.After(0, step)
end

if ns.Events then
    -- After the profession sources (their build would compete for frame time), or when Quests
    -- can't build at all.
    ns.Events.On("AZF_PROFESSION_SOURCES", function()
        local s = ns.ProfessionSources and ns.ProfessionSources.State().status
        if s == "ready" or s == "unavailable" then D.Start() end
    end)
    ns.Events.On("AZF_QUESTS_UPDATED", function()
        local qs = ns.Quests.State()
        if state.status == "idle" and qs.status == "unavailable" then D.Start() end
        if state.status == "ready" then ns.Events.Send("AZF_DUNGEONS_UPDATED", "quests") end
    end)
    ns.Events.Register("BAG_UPDATE_DELAYED", function()
        if state.status ~= "ready" then return end
        ns.Events.Debounce("dungeons-bags", 0.5, function() ns.Events.Send("AZF_DUNGEONS_UPDATED", "bags") end)
    end)
end

---------------------------------------------------------------------------------------------
-- Debug: /azf debug dungeons [key]
---------------------------------------------------------------------------------------------

local QUALITY = { [0] = "poor", "common", "uncommon", "rare", "epic", "legendary" }

local function placeText(p)
    if p.kind == "zone" then return "zone " .. tostring(p.mapID) end
    if p.kind == "instance" then return "in " .. p.instance.key end
    if p.kind == "area" then return "area " .. tostring(p.area) .. " " .. tostring(D.AreaName(p.area) or "(no name)") end
    return p.kind
end

local function detail(inst, char, by)
    local R = ns.DungeonRules
    local out = { quests = {}, places = {}, bosses = {}, keys = {}, factions = {} }
    local p = R.Progress(inst, by[inst.questArea] or {}, char)
    local ctx = D.PlaceContext()
    for _, g in ipairs(R.QuestGroups(p, inst, char, ctx, "all")) do
        out.places[#out.places + 1] = string.format("%s: %d quests, givers %s", placeText(g), #g.quests, table.concat(g.givers, ", "))
        for _, v in ipairs(g.quests) do
            local q = v.quest
            out.quests[#out.quests + 1] = string.format("%d %s lvl %s req %s side %s class %s: %s at %s%s%s", q.id, tostring(q.name),
                tostring(q.level), tostring(q.reqLevel), tostring(q.side or "both"), tostring(q.classMask), v.state, placeText(v.place),
                v.turninPlace and (", turn in " .. placeText(v.turnin)) or "", #v.pre > 0 and (", needs " .. table.concat(v.pre, " ")) or "")
        end
    end
    local loading = 0
    for bi, b in ipairs(inst.bosses or {}) do
        local parts = {}
        for _, id in ipairs(D.BossGear(inst, b) or {}) do
            local it = D.Item(id)
            if not it.loaded then loading = loading + 1 end
            local n = D.Count(id)
            parts[#parts + 1] = string.format("%d %s [%s %s ilvl %s req %s%s%s]", id, tostring(it.name or "?"),
                tostring(QUALITY[it.quality] or it.quality), tostring(it.equipLoc or ("c" .. tostring(it.class) .. "/" .. tostring(it.subclass))),
                tostring(it.itemLevel), tostring(it.reqLevel), D.ForYou(id) and " foryou" or "", n and n > 0 and (" have " .. n) or "")
        end
        local areas = {}
        for _, npc in ipairs(b.npcs or {}) do
            for _, a in ipairs(build.spawnAreas[npc] or {}) do areas[#areas + 1] = a end
        end
        out.bosses[#out.bosses + 1] = string.format("%d %s (areas %s): %d gear %s", bi, b.name, table.concat(areas, " "), #parts,
            table.concat(parts, "; "))
    end
    for _, k in ipairs(D.Keys(inst)) do
        out.keys[#out.keys + 1] = string.format("%s item %s (%s): have %s", tostring(k.key.name), tostring(k.key.item),
            tostring(k.item and k.item.name or "?"), tostring(k.count))
    end
    for _, f in ipairs(R.Factions(p.quests)) do
        out.factions[#out.factions + 1] = string.format("faction %d +%d from %d quests", f.factionID, f.amount, f.quests)
    end
    out.loading = loading
    out.progress = string.format("%d/%d %s%s; ready %d red %d later %d done %d", p.done, p.total, p.state,
        p.none and (" (" .. p.none .. ")") or "", p.counts.ready, p.counts.red, p.counts.later, p.counts.done)
    return out
end

function D.DebugReport(args)
    local key = args and args[1]
    if state.status == "idle" then D.Start() end
    if state.status ~= "ready" then
        ns.Printf("Dungeons: %s%s. Try again once the quest index is built.", state.status,
            state.reason and (" (" .. state.reason .. ")") or "")
        ns.Debug.Trace("dungeons", { report = true, status = state.status, reason = state.reason })
        return
    end
    local t0 = clock()
    local char = D.Character()
    local all = D.Catalogue("all")
    local by = D.QuestsByArea()
    local lines, mine, done = {}, 0, 0
    local fit = 0
    for _, e in ipairs(all) do
        local p, inst = e.progress, e.inst
        local gear, bosses = 0, 0
        for _, b in ipairs(inst.bosses or {}) do
            bosses = bosses + 1
            if #(D.BossGear(inst, b) or {}) > 0 then gear = gear + 1 end
        end
        mine, done = mine + p.total, done + p.done
        if e.fit then fit = fit + 1 end
        lines[inst.key] = string.format("%-18s %2d-%-2d %s %-6s quests %d/%d %s%s, bosses %d (with gear %d), keys %d", inst.key,
            inst.levels[1], inst.levels[2], e.fit and "fit" or "   ", e.bracket.key, p.done, p.total, p.state,
            p.none and (" (" .. p.none .. ")") or "", bosses, gear, #(inst.keys or {}))
    end
    local entry = { report = true, status = "ready", key = key, level = char.level, faction = char.faction, classFile = char.classFile,
        classBit = char.classBit, completionKnown = D.CompletionKnown(), instances = lines, quests = mine, done = done, fit = fit,
        build = { workMs = state.workMs, maxStepMs = state.maxStepMs, steps = state.steps, elapsedMs = state.elapsedMs,
            counts = state.counts, npcsWithGear = state.npcsWithGear } }
    ns.Printf("Dungeons: %d instances, %d for your level; your quests %d done of %d%s. Build %s ms over %d frames (max %s ms).",
        #all, fit, done, mine, entry.completionKnown and "" or " (completion unknown)", tostring(state.workMs), state.steps or 0,
        tostring(state.maxStepMs))
    if key then
        local inst = D.Instance(key)
        if not inst then
            ns.Printf("No instance with key %q.", key)
        else
            local d = detail(inst, char, by)
            entry.detail = d
            ns.Printf("%s: %s; %d places, %d bosses, %d keys; %d items still loading", inst.name, d.progress, #d.places, #d.bosses,
                #d.keys, d.loading)
            for _, l in ipairs(d.places) do ns.Printf("  %s", l) end
            if d.loading > 0 then ns.Print("  Some items are still loading: run the command again in a moment.") end
        end
    end
    entry.ms = round(t0 and clock() and (clock() - t0))
    ns.Debug.Trace("dungeons", entry)
    ns.Print("Details in the trace: /reload, then luajit tools/trace-report.lua dungeons.")
end

return D
