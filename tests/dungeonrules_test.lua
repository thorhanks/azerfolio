-- Systems/DungeonRules (Phase 16 task 2) and Data/ClassGear.lua, on real rows: The Deadmines and
-- Blackrock Depths quests from `qdb.lua dungeons js` (tests/fixtures/dungeon_quests.lua) and
-- the curated Data/Dungeons.lua, Data/QuestAreas.lua.
local wow = require("mocks.wow")

local function load()
    wow.install()
    local ns = {}
    for _, f in ipairs({ "Data/Zones.lua", "Data/QuestAreas.lua", "Data/Dungeons.lua", "Data/ClassGear.lua", "Systems/DungeonRules.lua" }) do
        wow.loadAddonFile("Azerfolio/" .. f, "Azerfolio", ns)
    end
    return ns
end

local FIX = dofile("tests/fixtures/dungeon_quests.lua")

-- A fixture giver/turn-in { name, areaID, mapID, kind } as the place source Systems/Dungeons passes.
local function src(g)
    if not g then return nil end
    local kind = (g[4] == "object" or g[4] == "item") and g[4] or "npc"
    return { name = g[1], kind = kind, area = g[2] ~= 0 and g[2] or nil }
end

local function quests(key, doneFn)
    local out = {}
    for _, r in ipairs(FIX[key]) do
        out[#out + 1] = { id = r[1], name = r[2], level = r[3], reqLevel = r[4], side = r[5] ~= "" and r[5] or nil,
            classMask = r[6], reps = r[7], giver = src(r[8]), turnin = src(r[9]), pre = r[10],
            done = doneFn and doneFn(r[1]) or nil }
    end
    return out
end

local function gideon(level) return { level = level or 55, faction = "Alliance", classFile = "PALADIN", classBit = 2 } end
local function thragor(level) return { level = level or 55, faction = "Horde", classFile = "WARRIOR", classBit = 1 } end

local function keys(groups)
    local o = {}
    for i, g in ipairs(groups or {}) do o[i] = g.key end
    return table.concat(o, " ")
end

return function(t)
    local ns = load()
    local R, D = ns.DungeonRules, ns.DungeonData
    local function inst(key)
        for _, i in ipairs(D.instances) do if i.key == key then return i end end
    end
    -- Blackrock Depths' bosses spawn in area 1585 (not its quest area 1584); Pusillin in Dire Maul's 10022.
    local ctx = R.PlaceContext({ [9018] = { 1585 }, [14354] = { 10022 } })

    t.test("level fit follows the zone guide's rule", function()
        local dm = inst("deadmines").levels -- 15-23
        t.ok(not R.Fits(dm, 11), "4 below the start")
        t.ok(R.Fits(dm, 12), "3 below the start")
        t.ok(R.Fits(dm, 23), "at the end")
        t.ok(not R.Fits(dm, 24), "past the end")
        t.eq(select(2, R.FitState(dm, 10)), 5)
        t.eq(R.FitState(dm, 24), "below")
        t.eq(R.FitState(dm, 18), "fit")
    end)

    t.test("filters and brackets", function()
        local all, forever = R.Catalogue(gideon(20), {}, "forever")
        t.eq(#all, #D.instances)
        t.eq(#forever, 9, "nine dungeons new in Forever")
        local _, raids = R.Catalogue(gideon(20), {}, "raid")
        for _, e in ipairs(raids) do t.eq(e.inst.kind, "raid") end
        local _, fit = R.Catalogue(gideon(20), {}, "foryou")
        for _, e in ipairs(fit) do t.ok(e.fit, e.inst.key .. " fits 20") end
        t.ok(#fit > 0 and #fit < #all)
        t.eq(R.Bracket(inst("deadmines")).key, "13-19")
        t.eq(R.Bracket(inst("blackrockDepths")).key, "50-60")
        t.eq(R.Bracket(inst("moltenCore")).key, "raids")
        local groups = R.Groups(all)
        t.eq(groups[1].bracket.key, "13-19")
        t.eq(groups[#groups].bracket.key, "raids")
        local n = 0
        for _, g in ipairs(groups) do n = n + #g.entries end
        t.eq(n, #all, "every instance in one bracket")
    end)

    t.test("wings of a group", function()
        t.eq(#R.Wings(inst("smArmory")), 4, "Scarlet Monastery")
        t.eq(#R.Wings(inst("dmNorth")), 3, "Dire Maul")
        t.eq(#R.Wings(inst("deadmines")), 1)
    end)

    t.test("The Deadmines: 6 Alliance quests, none for the Horde", function()
        local dm = inst("deadmines")
        local p = R.Progress(dm, quests("deadmines"), gideon(15))
        t.eq(p.total, 6)
        t.eq(p.done, 0)
        t.eq(p.state, "untouched")
        t.same(p.counts, { ready = 3, red = 3, later = 0, done = 0 })
        local h = R.Progress(dm, quests("deadmines"), thragor(15))
        t.eq(h.total, 0)
        t.eq(h.state, "untracked")
        t.eq(h.none, "side")
        t.eq(R.Progress(dm, {}, gideon(15)).none, "none")
        t.eq(R.Progress({ levels = { 1, 2 } }, nil, gideon(15)).none, "unmapped")
        local some = R.Progress(dm, quests("deadmines", function(id) return id == 166 end), gideon(15))
        t.eq(some.state, "progress")
        local all = R.Progress(dm, quests("deadmines", function() return true end), gideon(15))
        t.eq(all.state, "complete")
        t.eq(all.counts.done, 6)
    end)

    t.test("quest states: ready, red, later, done", function()
        t.eq(R.QuestState({ level = 22, reqLevel = 14 }, 17), "red")
        t.eq(R.QuestState({ level = 22, reqLevel = 14 }, 18), "ready")
        t.eq(R.QuestState({ level = 22, reqLevel = 20 }, 18), "later")
        t.eq(R.QuestState({ level = 22, reqLevel = 20, done = true }, 18), "done")
        t.eq(R.Difficulty(22, 30), "grey")
    end)

    t.test("class masks", function()
        local qs = { { id = 1, level = 20, side = "A", classMask = 2 }, { id = 2, level = 20, classMask = 1 }, { id = 3, level = 20, classMask = 0 } }
        t.eq(R.Progress(inst("deadmines"), qs, gideon(20)).total, 2, "Paladin quest and any-class quest")
        t.eq(R.Progress(inst("deadmines"), qs, thragor(20)).total, 2, "Warrior quest and any-class quest")
    end)

    t.test("The Deadmines' pickups: Westfall 3, Stormwind City 3; 166 needs 155", function()
        local dm = inst("deadmines")
        local p = R.Progress(dm, quests("deadmines"), gideon(15))
        local shown, more = R.Pickups(p, dm, gideon(15), ctx)
        t.eq(keys(shown), "z:1436 z:1453")
        t.eq(more, nil)
        t.eq(#shown[1].quests, 3)
        t.eq(#shown[2].quests, 3)
        t.same(shown[2].givers, { "Wilder Thistlenettle", "Shoni the Shilent" })
        local q166
        for _, v in ipairs(shown[1].quests) do if v.quest.id == 166 then q166 = v end end
        t.same(q166.pre, { 155 })
        t.same(q166.preHere, {}, "155 is outside the instance")
        t.eq(q166.turnin, nil, "turned in to the giver")
        t.eq(q166.state, "red")
        -- Chain order inside Westfall: by level.
        t.eq(shown[1].quests[1].quest.id, 214)
        t.eq(shown[1].quests[3].quest.id, 166)
        -- Done quests leave the pickups.
        local p2 = R.Progress(dm, quests("deadmines", function(id) return id ~= 167 end), gideon(15))
        t.eq(keys((R.Pickups(p2, dm, gideon(15), ctx))), "z:1453")
    end)

    t.test("Blackrock Depths: 4 places with its key, the last one More places", function()
        local brd = inst("blackrockDepths")
        local p = R.Progress(brd, quests("blackrockDepths"), gideon(55))
        t.eq(p.total, 25, "Alliance and neutral quests")
        local shown, more, all = R.Pickups(p, brd, gideon(55), ctx)
        t.eq(#all, 9)
        t.eq(keys(shown), "inside z:1428 item")
        t.eq(keys(more), "z:1455 z:1446 object z:1426 z:1419 i:dmEast")
        t.eq(#shown[1].quests, 8)
        t.eq(#shown[2].quests, 8)
        t.eq(more[#more].instance.key, "dmEast", "a giver inside Dire Maul")
        -- Without the keys row there's room for five.
        local saved = brd.keys
        brd.keys = nil
        local five, more5 = R.Pickups(p, brd, gideon(55), ctx)
        brd.keys = saved
        t.eq(#five, 4)
        t.eq(#more5, 5)
    end)

    t.test("Blackrock Depths: chain order, earlier quests here, a different turn-in", function()
        local brd = inst("blackrockDepths")
        local p = R.Progress(brd, quests("blackrockDepths"), gideon(55))
        local groups = R.QuestGroups(p, brd, gideon(55), ctx, "all")
        local inside
        for _, g in ipairs(groups) do if g.key == "inside" then inside = g end end
        local order = {}
        for i, v in ipairs(inside.quests) do order[i] = v.quest.id end
        t.eq(table.concat(order, " "), "4295 4201 4242 4282 4322 4342 4361 4363")
        local bs
        for _, g in ipairs(groups) do if g.key == "z:1428" then bs = g end end
        local byId = {}
        for _, v in ipairs(bs.quests) do byId[v.quest.id] = v end
        t.ok(byId[3801] and byId[3802], "both Dark Iron Legacy steps")
        local i1, i2
        for i, v in ipairs(bs.quests) do if v.quest.id == 3801 then i1 = i elseif v.quest.id == 3802 then i2 = i end end
        t.ok(i1 < i2, "3802 after 3801")
        t.same(byId[3802].preHere, { 3801 })
        t.eq(byId[3802].turnin.kind, "object")
        t.eq(byId[4241].turnin.kind, "inside", "Marshal Windsor waits inside")
        t.ok(byId[4241].turninPlace)
        -- States at 55: 7604 (needs 60) and 9015 (58) open later.
        local states = {}
        for _, g in ipairs(groups) do for _, v in ipairs(g.quests) do states[v.quest.id] = v.state end end
        t.eq(states[7604], "later")
        t.eq(states[9015], "later")
        t.eq(states[4295], "ready")
        t.eq(R.Progress(brd, quests("blackrockDepths"), gideon(50)).counts.red > 0, true)
        -- Done filter.
        t.eq(#R.QuestGroups(p, brd, gideon(55), ctx, "done"), 0)
    end)

    t.test("places", function()
        local brd, sm = inst("blackrockDepths"), inst("smArmory")
        t.eq(R.Place(nil, brd, ctx).kind, "unknown")
        t.eq(R.Place({ name = "x", kind = "item" }, brd, ctx).key, "item")
        t.eq(R.Place({ name = "x", kind = "npc", area = 1584 }, brd, ctx).kind, "inside", "its quest area")
        t.eq(R.Place({ name = "x", kind = "npc", area = 1585 }, brd, ctx).kind, "inside", "a boss's spawn area")
        t.eq(R.Place({ name = "x", kind = "npc", area = 1585 }, brd, R.PlaceContext(nil)).kind, "area", "unknown without spawns")
        t.eq(R.Place({ name = "x", kind = "npc", area = 796 }, sm, ctx).kind, "inside", "a wing's shared area")
        t.eq(R.Place({ name = "x", kind = "npc", area = 1581 }, brd, ctx).key, "i:deadmines", "another instance")
        local z = R.Place({ name = "x", kind = "npc", areas = { 1519, 99999 } }, brd, ctx)
        t.eq(z.kind, "zone")
        t.eq(z.mapID, 1453)
        t.eq(R.Place({ name = "x", kind = "npc", area = 10074 }, brd, ctx).key, "a:10074", "the client names it")
    end)

    t.test("each boss's own gear", function()
        local dm = inst("deadmines")
        local G, A = 2, 4
        local items = {
            [872] = { class = G, subclass = 1, reqLevel = 18 }, [5187] = { class = G, subclass = 5, reqLevel = 16 },
            [273289] = { class = A, subclass = 1, reqLevel = 17 }, [1] = { class = A, subclass = 2, reqLevel = 20 },
            [2] = { class = A, subclass = 2, reqLevel = 2 }, [3] = { class = 0, subclass = 0, reqLevel = 15 },
            [5443] = { class = A, subclass = 6, reqLevel = 17 }, [5444] = { class = A, subclass = 1, reqLevel = 17 },
        }
        local drops = { [872] = { 644 }, [5187] = { 644 }, [273289] = { 644 }, [1] = { 644, 1, 2, 3, 4, 5, 6, 7, 8 },
            [2] = { 644 }, [3] = { 644 }, [5443] = { 3586 }, [5444] = { 3586, 644 } }
        local byNpc = R.DropsByNpc(drops, items)
        t.same(byNpc[644], { 2, 872, 5187, 5444, 273289 }, "no world drop, no non-gear")
        t.same(R.BossGear(dm, dm.bosses[1], byNpc, items), { 872, 5187, 5444, 273289 })
        t.same(byNpc[1], nil)
        -- Required level at least 15 - 12: item 2 (level 2) is old world gear.
        local low = R.DropsByNpc({ [2] = { 644 } }, items)
        t.same(R.BossGear(dm, dm.bosses[1], low, items), {})
        -- Each item once across a group's NPCs.
        t.same(R.BossGear(dm, { npcs = { 644, 3586 } }, byNpc, items), { 872, 5187, 5443, 5444, 273289 })
    end)

    t.test("For you: armour by level, weapons, shields, relics, cloaks", function()
        local W, A = 2, 4
        local function it(c, s, r, loc) return { class = c, subclass = s, reqLevel = r, equipLoc = loc } end
        t.ok(R.ForYou(it(W, 1, 18), "PALADIN", 15), "two-hand axe")
        t.ok(not R.ForYou(it(W, 15, 18), "PALADIN", 15), "no daggers")
        t.ok(R.ForYou(it(A, 3, 30), "PALADIN", 30), "mail before 40")
        t.ok(not R.ForYou(it(A, 4, 30), "PALADIN", 30))
        t.ok(R.ForYou(it(A, 4, 40), "PALADIN", 38), "plate it will wear at 40")
        t.ok(not R.ForYou(it(A, 3, 45), "PALADIN", 45), "mail after 40")
        t.ok(not R.ForYou(it(A, 1, 20), "PALADIN", 20), "cloth")
        t.ok(R.ForYou(it(A, 1, 20, "INVTYPE_CLOAK"), "PALADIN", 20), "a cloak")
        t.ok(R.ForYou(it(A, 0, 20), "WARLOCK", 20), "jewellery")
        t.ok(R.ForYou(it(A, 6, 20), "PALADIN", 20), "shield")
        t.ok(not R.ForYou(it(A, 6, 20), "HUNTER", 20))
        t.ok(R.ForYou(it(A, 7, 50), "PALADIN", 50), "libram")
        t.ok(not R.ForYou(it(A, 8, 50), "PALADIN", 50))
        t.ok(R.ForYou(it(A, 8, 50), "DRUID", 50), "idol")
        t.ok(R.ForYou(it(A, 9, 50), "SHAMAN", 50), "totem")
        t.ok(R.ForYou(it(A, 2, 30), "HUNTER", 30), "leather before 40")
        t.ok(R.ForYou(it(A, 3, 42), "HUNTER", 30), "mail from 40")
        t.ok(R.ForYou(it(A, 2, 60), "ROGUE", 60))
        t.ok(R.ForYou(it(W, 19, 20), "MAGE", 20), "wand")
        t.ok(not R.ForYou(it(W, 19, 20), "WARRIOR", 20))
        t.ok(not R.ForYou(it(W, 6, 20), "DRUID", 20), "no polearms in Classic")
        t.ok(not R.ForYou(it(0, 0, 20), "MAGE", 20), "not gear")
        t.ok(R.ForYou(it(A, 4, 60), "UNKNOWN", 60), "a class we don't know sees everything")
    end)

    t.test("ClassGear covers every class", function()
        local C = ns.ClassGearData.classes
        local n = 0
        for file, c in pairs(C) do
            n = n + 1
            t.ok(type(c.armor) == "table" and #c.armor >= 1 and c.armor[1].from == 1, file .. " armour from level 1")
            t.ok(type(c.weapons) == "table" and #c.weapons >= 4, file .. " weapons")
            t.ok(c.relic == nil or c.relic == 7 or c.relic == 8 or c.relic == 9, file .. " relic")
        end
        t.eq(n, 9)
        t.eq(R.ArmorFor("WARRIOR", 39), 3)
        t.eq(R.ArmorFor("WARRIOR", 40), 4)
        t.eq(R.ArmorFor("SHAMAN", 40), 3)
        t.eq(R.ArmorFor("PRIEST", 60), 1)
    end)

    t.test("factions raised", function()
        local p = R.Progress(inst("deadmines"), quests("deadmines"), gideon(15))
        local f = R.Factions(p.quests)
        t.eq(#f, 3)
        t.same(f[1], { factionID = 72, amount = 500, quests = 4 })
        t.same(f[2], { factionID = 47, amount = 200, quests = 2 })
        t.same(f[3], { factionID = 54, amount = 100, quests = 1 })
        t.eq(#R.Factions({ { reps = { { 72, -50 } } } }), 0, "losses don't count")
    end)

    t.test("links in (task 7): instances by entrance zone, and by quest area", function()
        local ns = load()
        local R = ns.DungeonRules
        local insts = ns.DungeonData.instances
        local function keysOf(list)
            local o = {}
            for i, x in ipairs(list) do o[i] = (x.inst or x).key end
            return table.concat(o, " ")
        end
        t.eq(keysOf(R.InZone(insts, 1436)), "deadmines", "Westfall")
        t.eq(keysOf(R.InZone(insts, 1453)), "stockade", "a capital: Stormwind City")
        t.eq(keysOf(R.InZone(insts, 1454)), "ragefire", "Orgrimmar")
        t.eq(#R.InZone(insts, 1420), 5, "Tirisfal Glades: the Scarlet Monastery's four wings and the Ruins of Lordaeron")
        t.eq(#R.InZone(insts, 1429), 0, "Elwynn Forest: none")
        local all = R.Catalogue(gideon(20), {}, "all")
        t.eq(keysOf(R.InZone(all, 1436)), "deadmines", "catalogue entries work too")
        t.eq(R.InZone(all, 1436)[1].progress.total, 0)
        t.eq(R.ForQuestArea(1581).key, "deadmines")
        t.eq(R.ForQuestArea(796).key, R.InZone(insts, 1420)[1].key, "a group's shared area opens its first wing")
        t.eq(R.ForQuestArea(123456), nil); t.eq(R.ForQuestArea(nil), nil)
    end)
end
