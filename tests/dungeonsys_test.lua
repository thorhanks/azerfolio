-- Systems/Dungeons (Phase 16 task 3): the pure helpers and the build, on a fake QuestieDB
-- shaped as Types/{Quest,Npc,Item}.t.lua (contract 4), with the curated Data/Dungeons.lua.
local wow = require("mocks.wow")

local function load()
    wow.install()
    local ns = {}
    for _, f in ipairs({ "Data/Zones.lua", "Data/QuestAreas.lua", "Data/Dungeons.lua", "Data/ClassGear.lua",
        "Systems/DungeonRules.lua", "Systems/Dungeons.lua" }) do
        wow.loadAddonFile("Azerfolio/" .. f, "Azerfolio", ns)
    end
    return ns
end

-- A fake LibQuestieDB: rows per entity, one reader per field (nil for unknown IDs).
local function fakeLib(rows, opts)
    opts = opts or {}
    local lib = {}
    for entity, byId in pairs(rows) do
        local E = {}
        local fields = {}
        for _, r in pairs(byId) do for k in pairs(r) do fields[k] = true end end
        for k in pairs(fields) do
            E[k] = function(id)
                if opts.fail == entity .. "." .. k then error("boom") end
                local r = byId[id]
                return r and r[k]
            end
        end
        E.GetAllIds = function()
            local ids = {}
            for id in pairs(byId) do ids[#ids + 1] = id end
            table.sort(ids)
            return ids
        end
        lib[entity] = E
    end
    return lib
end

local function many(n, first)
    local t = { first }
    for i = 2, n do t[i] = 90000 + i end
    return t
end

local ROWS = {
    Npc = {
        [639] = { name = "Edwin VanCleef", spawns = { [1581] = { { 1, 2 } } }, zoneID = 1581, friendlyToFaction = nil },
        [646] = { name = "Mr. Smite", spawns = { [1581] = {} } },
        [234] = { name = "Gryan Stoutmantle", spawns = { [40] = {} }, friendlyToFaction = "A" },
        [9001] = { name = "Horde Giver", spawns = { [17] = {} }, friendlyToFaction = "H" },
        [9002] = { name = "Ally Giver", spawns = { [12] = {}, [40] = {} }, friendlyToFaction = "A" },
    },
    Item = {
        [5191] = { name = "Cruel Barb", npcDrops = { 639 }, class = 2, subClass = 7, requiredLevel = 18 },
        [5193] = { name = "Cape of the Brotherhood", npcDrops = { 639 }, class = 4, subClass = 1, requiredLevel = 17 },
        [7777] = { name = "Old World Ring", npcDrops = many(10, 639), class = 4, subClass = 0, requiredLevel = 20 },
        [5000] = { name = "Trade Goods", npcDrops = { 646 }, class = 15, subClass = 0, requiredLevel = 0 },
        [6000] = { name = "Elsewhere Sword", npcDrops = { 12345 }, class = 2, subClass = 7, requiredLevel = 20 },
        [3000] = { name = "Defias Letter" },
    },
    Object = { [77] = { name = "Wanted Poster" } },
    Quest = {
        [166] = { startedBy = { { 9001, 9002, 234 } }, finishedBy = { { 234 } } },
        [214] = { startedBy = { nil, { 77 } }, finishedBy = { { 234 } } },
        [373] = { startedBy = { nil, nil, { 3000 } }, finishedBy = {} },
    },
}

local DETAILS = {
    [166] = { name = "The Defias Brotherhood", level = 22, reqLevel = 14, races = 77, preSingle = { 155 }, preGroup = { 155, 160 },
        rep = { { 72, 250 } } },
    [214] = { name = "Red Silk Bandanas", level = 17, reqLevel = 14 },
    [373] = { name = "The Unsent Letter", level = 22, reqLevel = 16, classes = 2 },
}

local INDEX = { instances = { [1581] = { kind = "dungeon", ids = { 373, 214, 166, 999 } } } }

return function(t)
    local ns = load()
    local D = ns.Dungeons

    t.test("SideOf reads the race mask as a side", function()
        t.eq(D.SideOf(1), "A")
        t.eq(D.SideOf(1 + 4 + 8 + 64), "A")
        t.eq(D.SideOf(2 + 16 + 32 + 128), "H")
        t.eq(D.SideOf(1 + 2), nil)
        t.eq(D.SideOf(0), nil)
        t.eq(D.SideOf(nil), nil)
        t.eq(D.SideOf(2 ^ 32), "A")
        t.eq(D.SideOf(2 ^ 33), "H")
        t.eq(D.SideOf(1, { Alliance = 1, Horde = 2 }), "A")
        t.eq(D.SideOf(4, { Alliance = 1, Horde = 2 }), nil, "a bit in neither mask says nothing")
    end)

    t.test("SpawnAreas sorts spawn areas and falls back to the zone", function()
        local a = D.SpawnAreas({ [1585] = {}, [1584] = {}, [0] = {} }, 1584)
        t.eq(#a, 2); t.eq(a[1], 1584); t.eq(a[2], 1585)
        local z = D.SpawnAreas(nil, 1581)
        t.eq(#z, 1); t.eq(z[1], 1581)
        t.eq(#D.SpawnAreas({}, nil), 0)
    end)

    t.test("PlaceSource picks a friendly NPC, then objects and items", function()
        local npcs = { [1] = { name = "H", areas = { 17 }, side = "H" }, [2] = { name = "A", areas = { 12, 40 }, side = "A" },
            [3] = { name = "Any", areas = {}, side = nil } }
        local function npc(id) return npcs[id] end
        local s = D.PlaceSource({ { 1, 2 } }, npc, nil, nil, "A")
        t.eq(s.name, "A"); t.eq(s.kind, "npc"); t.eq(s.area, nil); t.eq(#s.areas, 2)
        local h = D.PlaceSource({ { 1, 2 } }, npc, nil, nil, "H")
        t.eq(h.name, "H"); t.eq(h.area, 17)
        local f = D.PlaceSource({ { 1 } }, npc, nil, nil, "A")
        t.eq(f.name, "H", "no friendly NPC: the first known")
        local u = D.PlaceSource({ { 3 } }, npc, nil, nil, "A")
        t.eq(u.name, "Any"); t.eq(u.area, nil); t.eq(u.areas, nil)
        local o = D.PlaceSource({ nil, { 77 } }, npc, function() return "Poster" end)
        t.eq(o.kind, "object"); t.eq(o.name, "Poster")
        local i = D.PlaceSource({ {}, {}, { 5 } }, npc, nil, function() return "Letter" end)
        t.eq(i.kind, "item"); t.eq(i.name, "Letter")
        t.eq(D.PlaceSource({ { 99 } }, npc), nil, "no known starter")
        t.eq(D.PlaceSource(nil, npc), nil)
    end)

    t.test("QuestRecord builds the DungeonRules shape", function()
        local q = D.QuestRecord(166, DETAILS[166], { name = "G" }, nil)
        t.eq(q.id, 166); t.eq(q.name, "The Defias Brotherhood"); t.eq(q.level, 22); t.eq(q.reqLevel, 14)
        t.eq(q.side, "A"); t.eq(q.classMask, 0)
        t.eq(#q.pre, 2, "earlier quests once each"); t.eq(q.pre[1], 155); t.eq(q.pre[2], 160)
        t.eq(#q.reps, 1); t.eq(q.reps[1][1], 72); t.eq(q.reps[1][2], 250)
        t.eq(q.giver.name, "G"); t.eq(q.done, nil)
        local c = D.QuestRecord(373, DETAILS[373])
        t.eq(c.classMask, 2); t.eq(c.side, nil); t.eq(#c.pre, 0); t.eq(#c.reps, 0)
    end)

    t.test("Plan takes each quest area once and every boss NPC", function()
        local idx = { instances = { [796] = { ids = { 3, 1, 2 } } } }
        local data = { instances = {
            { key = "a", questArea = 796, bosses = { { npcs = { 10, 11 } } } },
            { key = "b", questArea = 796, bosses = { { npcs = { 11, 12 } } } },
            { key = "c", bosses = {} },
        } }
        local p = D.Plan(idx, data)
        t.eq(#p.questIDs, 3); t.eq(p.questIDs[1], 1); t.eq(p.questIDs[3], 3)
        t.eq(#p.bossNpcs, 3)
    end)

    t.test("Build reads quests, spawns and boss drops", function()
        local yields = 0
        local old = { D.ITEM_BATCH, D.QUEST_BATCH }
        D.ITEM_BATCH, D.QUEST_BATCH = 2, 1
        local plan = { questIDs = { 166, 214, 373, 999 }, bossNpcs = { 639, 646 }, side = "A",
            info = function(id) return DETAILS[id] end }
        local b = D.Build(fakeLib(ROWS), plan, function() yields = yields + 1 end)
        D.ITEM_BATCH, D.QUEST_BATCH = old[1], old[2]
        t.ok(yields > 0, "yields between batches")
        t.eq(b.counts.quests, 3); t.eq(b.counts.noRecord, 1); t.eq(b.counts.readErrors, 0); t.eq(b.counts.itemList, true)
        local q = b.quests[166]
        t.eq(q.giver.name, "Ally Giver", "the first Alliance-friendly giver"); t.eq(#q.giver.areas, 2)
        t.eq(q.turnin.name, "Gryan Stoutmantle"); t.eq(q.turnin.area, 40)
        t.eq(b.quests[214].giver.kind, "object"); t.eq(b.quests[214].giver.name, "Wanted Poster")
        t.eq(b.quests[373].giver.kind, "item"); t.eq(b.quests[373].giver.name, "Defias Letter")
        t.eq(b.quests[373].turnin, nil, "no finisher")
        t.eq(b.spawnAreas[639][1], 1581)
        -- Drops: only items a boss drops are kept; world drops and non-gear are left to DungeonRules.
        t.ok(b.npcDrops[5191] and b.npcDrops[5193] and b.npcDrops[7777] and b.npcDrops[5000], "boss drops kept")
        t.eq(b.npcDrops[6000], nil, "another NPC's drop isn't kept")
        t.eq(b.items[5191].class, 2); t.eq(b.items[5191].subclass, 7); t.eq(b.items[5191].reqLevel, 18)
        local gear = b.byNpc[639]
        t.eq(#gear, 2, "world drop (10 NPCs) left out"); t.eq(gear[1], 5191); t.eq(gear[2], 5193)
        t.eq(b.byNpc[646], nil, "trade goods aren't gear")
        local inst = ns.DungeonData.instances[2]
        t.eq(inst.key, "deadmines")
        local bg = ns.DungeonRules.BossGear(inst, inst.bosses[8], b.byNpc, b.items)
        t.eq(#bg, 2)
        -- Boss spawn areas feed PlaceContext.
        local ctx = ns.DungeonRules.PlaceContext(b.spawnAreas)
        t.eq(ctx.owner[1581].key, "deadmines")
    end)

    t.test("Build counts failed reads and works without an item list", function()
        local lib = fakeLib(ROWS, { fail = "Quest.startedBy" })
        lib.Item.GetAllIds = nil
        local b = D.Build(lib, { questIDs = { 166 }, bossNpcs = { 639 }, info = function(id) return DETAILS[id] end })
        t.eq(b.counts.readErrors, 1); t.eq(b.quests[166].giver, nil); t.eq(b.quests[166].turnin.name, "Gryan Stoutmantle")
        t.eq(b.counts.itemList, false); t.eq(next(b.byNpc), nil)
    end)

    t.test("Build times the longest stretch per phase", function()
        local now = 0
        local plan = { questIDs = { 166, 214 }, bossNpcs = { 639 }, info = function(id) now = now + 3; return DETAILS[id] end,
            clock = function() return now end }
        local b = D.Build(fakeLib(ROWS), plan)
        t.eq(b.maxMs.quests, 6, "both quests in one stretch (batch 20)")
        t.ok(b.maxMs.items ~= nil and b.maxMs.itemList ~= nil and b.maxMs.drops ~= nil, "every phase timed")
    end)

    t.test("QuestsFor sets done from the completed list, never when it's unknown", function()
        local b = D.Build(fakeLib(ROWS), { questIDs = { 166, 214, 373 }, bossNpcs = {}, side = "A",
            info = function(id) return DETAILS[id] end })
        local by = D.QuestsFor(b, INDEX, ns.DungeonData, { [214] = true })
        local list = by[1581]
        t.eq(#list, 3, "the quest QuestieDB has no record for is left out")
        t.eq(list[1].id, 166); t.eq(list[1].done, nil); t.eq(list[2].id, 214); t.eq(list[2].done, true)
        local p = ns.DungeonRules.Progress(ns.DungeonData.instances[2], list,
            { level = 20, faction = "Alliance", classFile = "PALADIN", classBit = 2 })
        t.eq(p.total, 3); t.eq(p.done, 1); t.eq(p.state, "progress")
        local unknown = D.QuestsFor(b, INDEX, ns.DungeonData, nil)
        for _, q in ipairs(unknown[1581]) do t.eq(q.done, nil) end
        t.ok(by[2437] and #by[2437] == 0, "an instance area with no quests in the index is empty")
    end)

    t.test("ItemFromInfo reads C_Item.GetItemInfo's returns", function()
        local r = D.ItemFromInfo("Cape of the Brotherhood", "link", 3, 24, 17, "Armor", "Cloth", 1, "INVTYPE_CLOAK", 133762, 500, 4, 1)
        t.eq(r.name, "Cape of the Brotherhood"); t.eq(r.quality, 3); t.eq(r.itemLevel, 24); t.eq(r.reqLevel, 17)
        t.eq(r.equipLoc, "INVTYPE_CLOAK"); t.eq(r.icon, 133762); t.eq(r.class, 4); t.eq(r.subclass, 1)
        t.ok(ns.DungeonRules.ForYou(r, "PALADIN", 20), "a cloak is for a paladin")
        t.eq(D.ItemFromInfo(nil), nil)
        t.eq(D.ItemFromInfo("Ring", nil, 2, 20, 15, nil, nil, nil, "").equipLoc, nil)
    end)
end
