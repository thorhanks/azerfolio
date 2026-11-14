-- Profession sources from QuestieDB (Phase 14 step 5; spec §8.12), read at runtime like
-- Systems/Quests (QuestieDB is an optional dependency; nothing is copied into the addon):
--   * recipe items: QuestieDB's item name index (Item.BuildNameIndexAsync / IdsByName, contract 4
--     [verified-files: src/read/shared.lua]) finds "<Word>: <recipe name>"; the item must be a
--     recipe (class 9) of the profession's subclass. Its vendors (with zone and side), drops,
--     containers and quest rewards are the recipe's sources.
--   * profession trainers: every NPC whose subName names a trainer of the profession ("Expert
--     Blacksmith", "First Aid Trainer"), with zone and side.
--   * a reagent's vendors and drops (Item vendors / npcDrops), for "where to get it".
-- Built once per session over frames, after the quest index (no competing for frame time).
-- Without QuestieDB: status "unavailable", and the tab shows only trainer sources.
-- Announces AZF_PROFESSION_SOURCES (status changed).
local _, ns = ...

local S = {}
ns.ProfessionSources = S

-- IDs between yields. At 500 the largest frame was 7.7 ms (Gideon, 2026-11-14: 122 ms of work
-- in 21 frames, 23,862 items and 15,563 NPCs in QuestieDB), over the 4 ms budget.
S.NPC_BATCH = 250
S.ITEM_BATCH = 250
S.FRAME_MS = 4      -- work per frame before waiting for the next
S.MAX_VENDORS = 12  -- vendors read per item
S.MAX_DROP_ZONES = 30 -- dropping NPCs read for their zones

local function clock() return type(debugprofilestop) == "function" and debugprofilestop() or nil end
local function round(ms) return ms and math.floor(ms * 100 + 0.5) / 100 or nil end

local state = { status = "idle" }
local lib
local trainers = {}  -- [skillLine] = { trainer ... }
local npcs = {}      -- [npcID] = npc info or false
local items = {}     -- [itemID] = sources or false
local recipes = {}   -- [skillLine .. "|" .. name] = recipe item or false

function S.State() return state end

local function read(entity, field, id)
    local E = lib and lib[entity]
    local f = type(E) == "table" and E[field]
    if type(f) ~= "function" then return nil end
    local ok, v = pcall(f, id)
    if ok then return v end
    return nil
end

local function areaName(areaID)
    if type(areaID) ~= "number" or not (C_Map and type(C_Map.GetAreaInfo) == "function") then return nil end
    local ok, name = pcall(C_Map.GetAreaInfo, areaID)
    return ok and type(name) == "string" and name ~= "" and name or nil
end

-- An NPC's name, zone and side: { id, name, mapID, place, side = "A"|"H"|"AH"|nil }.
-- mapID: the zone map of its area (Data/QuestAreas), like the Class tab's "Where it starts".
function S.Npc(id)
    if npcs[id] ~= nil then return npcs[id] or nil end
    if not lib or type(id) ~= "number" then return nil end
    local name = read("Npc", "name", id)
    if type(name) ~= "string" then npcs[id] = false; return nil end
    local area = read("Npc", "zoneID", id)
    local zones = ns.QuestAreaData and ns.QuestAreaData.zone
    local side = read("Npc", "friendlyToFaction", id)
    local n = { id = id, name = name, mapID = type(area) == "number" and zones and zones[area] or nil,
        place = areaName(area), side = (side == "A" or side == "H" or side == "AH") and side or nil }
    npcs[id] = n
    return n
end

-- Where an item comes from, by QuestieDB: { vendors = { npc ... }, drops = n, dropMaps = { mapID },
-- objects = n, containers = n, quests = n }. nil before the index is ready.
function S.Item(itemID)
    if state.status ~= "ready" or type(itemID) ~= "number" then return nil end
    if items[itemID] ~= nil then return items[itemID] or nil end
    local out = { vendors = {}, drops = 0, dropMaps = {}, objects = 0, containers = 0, quests = 0 }
    local vendors = read("Item", "vendors", itemID)
    if type(vendors) == "table" then
        for i, id in ipairs(vendors) do
            if i > S.MAX_VENDORS then out.moreVendors = #vendors - S.MAX_VENDORS; break end
            local n = S.Npc(id)
            if n then out.vendors[#out.vendors + 1] = { npc = n.name, maps = n.mapID and { n.mapID } or {}, place = n.place, side = n.side } end
        end
    end
    local drops = read("Item", "npcDrops", itemID)
    if type(drops) == "table" then
        out.drops = #drops
        local seen = {}
        for i, id in ipairs(drops) do
            if i > S.MAX_DROP_ZONES then break end
            local n = S.Npc(id)
            if n and n.mapID and not seen[n.mapID] then seen[n.mapID] = true; out.dropMaps[#out.dropMaps + 1] = n.mapID end
        end
    end
    local objects = read("Item", "objectDrops", itemID)
    out.objects = type(objects) == "table" and #objects or 0
    local containers = read("Item", "itemDrops", itemID)
    out.containers = type(containers) == "table" and #containers or 0
    local quests = read("Item", "questRewards", itemID)
    out.quests = type(quests) == "table" and #quests or 0
    items[itemID] = out
    return out
end

-- The recipe item that teaches a recipe of this profession, as ProfessionRules.ItemSources
-- reads it, or nil (none, or the index isn't ready).
function S.RecipeItem(skillLine, recipeName)
    if state.status ~= "ready" or type(recipeName) ~= "string" then return nil end
    local key = tostring(skillLine) .. "|" .. recipeName
    if recipes[key] ~= nil then return recipes[key] or nil end
    local info = ns.ProfessionData.skills[skillLine]
    local found = false
    if info and info.recipeSubclass and lib.Item and type(lib.Item.IdsByName) == "function" then
        for _, name in ipairs(ns.ProfessionRules.RecipeItemNames(recipeName)) do
            local ok, ids = pcall(lib.Item.IdsByName, name)
            for _, id in ipairs(ok and type(ids) == "table" and ids or {}) do
                if read("Item", "class", id) == 9 and read("Item", "subClass", id) == info.recipeSubclass then
                    local src = S.Item(id)
                    if src then
                        found = { itemID = id, vendors = src.vendors, drops = src.drops, dropMaps = src.dropMaps,
                            objects = src.objects + src.containers, quests = src.quests }
                        break
                    end
                end
            end
            if found then break end
        end
    end
    recipes[key] = found
    return found or nil
end

-- This profession's trainers (any rank, any side): { { name, rank, level, mapID, place, side } }.
function S.Trainers(skillLine) return trainers[skillLine] or {} end

-- Runs inside the build's coroutine: yields every NPC_BATCH NPCs.
local function scanTrainers()
    local ok, ids = pcall(lib.Npc.GetAllIds)
    if not ok or type(ids) ~= "table" then return 0 end
    local R, skills, found = ns.ProfessionRules, ns.ProfessionData.skills, 0
    for i, id in ipairs(ids) do
        local sub = read("Npc", "subName", id)
        if type(sub) == "string" then
            for line, info in pairs(skills) do
                local t = R.TrainerOf(sub, info)
                if t then
                    local n = S.Npc(id)
                    if n then
                        trainers[line] = trainers[line] or {}
                        table.insert(trainers[line], { id = id, name = n.name, rank = t.rank, level = t.level,
                            mapID = n.mapID, place = n.place, side = n.side })
                        found = found + 1
                    end
                    break
                end
            end
        end
        if i % S.NPC_BATCH == 0 then coroutine.yield() end
    end
    return found
end

local function finish(info)
    state = { status = "ready", workMs = round(info.workMs), maxStepMs = round(info.maxStep), steps = info.steps,
        trainers = info.trainers, elapsedMs = round(info.started and clock() and (clock() - info.started)) }
    ns.Debug.Trace("professions", { event = "sources", status = "ready", trainers = info.trainers, workMs = state.workMs,
        maxStepMs = state.maxStepMs, steps = info.steps })
    ns.Events.Send("AZF_PROFESSION_SOURCES")
end

local function unavailable(reason)
    state = { status = "unavailable", reason = reason }
    ns.Debug.Trace("professions", { event = "sources", status = "unavailable", reason = reason })
    ns.Events.Send("AZF_PROFESSION_SOURCES")
end

-- Starts the one-time build (no-op once started).
function S.Start()
    if state.status ~= "idle" then return end
    local L = rawget(_G, "LibQuestieDB")
    local ok, reason = ns.Quests.Detect(L)
    if not ok then return unavailable(reason) end
    if type(L.Item) ~= "table" or type(L.Item.IdsByName) ~= "function" or type(L.Item.BuildNameIndexAsync) ~= "function"
        or type(L.Npc) ~= "table" or type(L.Npc.GetAllIds) ~= "function" then
        return unavailable("QuestieDB has no item name index")
    end
    lib = L
    local info = { workMs = 0, maxStep = 0, steps = 0, started = clock() }
    local co = coroutine.create(function()
        lib.Item.BuildNameIndexAsync(S.ITEM_BATCH)
        info.trainers = scanTrainers()
    end)
    state = { status = "building" }
    local function step()
        local t0 = clock()
        info.steps = info.steps + 1
        repeat
            local ran, err = coroutine.resume(co)
            if not ran then
                ns.Debug.Error("profession sources", err)
                return unavailable("reading QuestieDB failed")
            end
        until coroutine.status(co) == "dead" or not t0 or not clock() or clock() - t0 >= S.FRAME_MS
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

-- After the quest index is built (QuestieDB loaded and its frames free), or when asked.
ns.Events.On("AZF_QUESTS_UPDATED", function()
    local q = ns.Quests.State()
    if state.status == "idle" and (q.status == "ready" or q.status == "unavailable") then S.Start() end
end)
