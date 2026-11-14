-- Professions (Phase 14): Data/Professions.lua and Data/Gathering.lua are well formed, and
-- Systems/ProfessionRules on Gideon's real probe lists (tests/fixtures/professions_probe.lua).
-- Item IDs and recipe subclasses are checked against QuestieDB by `luajit tools/qdb.lua gather check`.
local wow = require("mocks.wow")

local function load()
    wow.install()
    local ns = {}
    for _, f in ipairs({ "Data/Zones.lua", "Data/Professions.lua", "Data/Gathering.lua", "Systems/ProfessionRules.lua" }) do
        wow.loadAddonFile("Azerfolio/" .. f, "Azerfolio", ns)
    end
    return ns
end

return function(t)
    local ns = load()
    local P, G, Z = ns.ProfessionData, ns.GatheringData, ns.ZoneData

    local function knownZone(id) return Z.levels[id] ~= nil or Z.faction[id] ~= nil end

    t.test("ranks climb to the max skill", function()
        t.eq(P.maxSkill, 300)
        local prevCap, prevAt = 0, 0
        for i, r in ipairs(P.ranks) do
            t.ok(type(r.name) == "string" and r.name ~= "", "rank " .. i .. " has a name")
            t.ok(r.cap > prevCap and r.at > prevAt or i == 1, "rank " .. i .. " climbs")
            t.ok(r.at <= prevCap or i == 1, r.name .. " is trained at or below the previous cap")
            prevCap, prevAt = r.cap, r.at
        end
        t.eq(P.ranks[#P.ranks].cap, P.maxSkill, "the top rank's cap is the max skill")
        t.eq(P.ranks[2].at, 50, "Journeyman at 50 (Gideon's trainers)")
    end)

    t.test("twelve professions with consistent facts", function()
        local n, keys, secondary = 0, {}, 0
        for line, d in pairs(P.skills) do
            n = n + 1
            t.ok(type(line) == "number", "keyed by skill line")
            t.ok(not keys[d.key], "unique key " .. d.key); keys[d.key] = true
            t.ok(d.kind == "primary" or d.kind == "secondary", d.name .. " kind")
            t.ok(d.role == "crafting" or d.role == "gathering" or d.role == "both", d.name .. " role")
            t.ok(type(d.noun) == "string", d.name .. " noun")
            if d.gather then t.ok(G[d.gather] ~= nil, d.name .. " gather table exists") end
            if d.role == "crafting" then t.ok(d.recipeSubclass ~= nil, d.name .. " crafting has a recipe subclass") end
            if d.kind == "secondary" then secondary = secondary + 1 end
        end
        t.eq(n, 12)
        t.eq(secondary, 3, "Cooking, First Aid, Fishing")
        t.eq(P.skills[164].name, "Blacksmithing")
        t.eq(P.skills[186].gather, "mining")
        t.ok(P.seasonCategories[2593], "Season of Discovery category")
    end)

    t.test("gathering nodes: ordered by skill, real zones, provenance", function()
        for _, kind in ipairs({ "mining", "herbalism" }) do
            local prev, names = 0, {}
            for _, node in ipairs(G[kind]) do
                t.ok(type(node.name) == "string" and not names[node.name], kind .. " unique name " .. tostring(node.name))
                names[node.name] = true
                t.ok(type(node.src) == "string" and node.src ~= "", node.name .. " has a source")
                t.ok(type(node.zones) == "table" and type(node.items) == "table", node.name .. " zones and items")
                if node.skill ~= nil then
                    t.ok(node.skill >= 1 and node.skill <= P.maxSkill, node.name .. " skill in range")
                    t.ok(node.skill >= prev, node.name .. " in skill order")
                    prev = node.skill
                    t.ok(#node.items > 0, node.name .. " gives an item")
                else
                    t.eq(#node.zones, 0, node.name .. ": no skill, so no zones claimed")
                end
                for _, z in ipairs(node.zones) do t.ok(knownZone(z), node.name .. " zone " .. z .. " is in Data/Zones.lua") end
                for _, a in ipairs(node.alt or {}) do t.ok(a ~= node.skill, node.name .. " alt differs") end
            end
        end
        t.eq(G.mining[1].name, "Copper Vein")
        t.eq(G.greyAfter, 100)
    end)

    t.test("fishing brackets and the skinning rule", function()
        local prev = 0
        for _, b in ipairs(G.fishing) do
            t.ok(b.skill > prev, b.name .. " climbs"); prev = b.skill
            t.ok(#b.zones > 0, b.name .. " has zones")
            for _, z in ipairs(b.zones) do t.ok(knownZone(z), b.name .. " zone " .. z) end
        end
        local s = G.skinning
        t.ok(s.lowUntil and s.lowDiv and s.lowAdd and s.highDiv and s.src, "skinning rule fields")
        -- The rule is continuous at its seam: skill 100 skins level 20 either way.
        t.eq(s.lowUntil / s.lowDiv + s.lowAdd, s.lowUntil / s.highDiv)
    end)

    -- ProfessionRules ---------------------------------------------------------------------
    local R = ns.ProfessionRules
    local FX = dofile("tests/fixtures/professions_probe.lua")
    local function prof(line, skill, cap) return R.Profession({ skillLine = line, skill = skill, cap = cap }) end
    local function recipes(name, skill, extra)
        local fx = FX[name]
        local o = { skill = skill, trainer = fx.trainer, items = fx.items }
        for k, v in pairs(extra or {}) do o[k] = v end
        return R.Recipes(fx.rows, o)
    end
    local function find(list, name)
        for _, r in ipairs(list) do if r.name == name then return r end end
    end

    t.test("rules: ranks, titles", function()
        t.eq(R.RankFor(75).name, "Apprentice")
        t.eq(R.RankFor(150).name, "Journeyman")
        t.eq(R.RankFor(300).name, "Artisan")
        t.eq(R.RankFor(nil), nil)
        t.eq(R.RankFor(0), nil, "a cap below every rank is unknown")
        t.eq(R.NextRank(75).name, "Journeyman")
        t.eq(R.NextRank(300), nil)
        t.eq(R.Title(R.Info(164), R.RankFor(75)), "Apprentice Blacksmith")
        t.eq(R.Title(R.Info(129), R.RankFor(150)), "Journeyman in First Aid")
    end)

    t.test("rules: Gideon's professions (probe skills)", function()
        local bs = prof(164, 33, 75)
        t.eq(bs.name, "Blacksmithing"); t.eq(bs.title, "Apprentice Blacksmith")
        t.eq(bs.next.name, "Journeyman"); t.eq(bs.togo, 17)
        t.ok(not bs.atCap and not bs.trainNow and not bs.mastered)
        local mining = prof(186, 59, 75)
        t.ok(mining.trainNow and not mining.atCap, "Mining 59: train Journeyman now")
        t.eq(mining.togo, 0)
        local capped = prof(129, 75, 75)
        t.ok(capped.atCap, "75 / 75 is at cap")
        local m = prof(186, 300, 300)
        t.ok(m.mastered and not m.atCap and m.next == nil, "300 is mastered")
        local unknown = prof(164, 40, 0)
        t.eq(unknown.rank, nil); t.eq(unknown.next, nil); t.ok(not unknown.atCap)
        t.ok(prof(182, 1, 75).hasRecipes == false, "Herbalism has no recipes")
        t.ok(prof(186, 1, 75).hasRecipes, "Mining has smelting")
    end)

    t.test("rules: skill road stones", function()
        local s = R.Stones(59, 75)
        t.eq(#s, 3)
        t.eq(s[1].rank.name, "Journeyman"); t.eq(s[1].state, "now")
        t.eq(s[2].state, "later"); t.eq(s[3].state, "later")
        s = R.Stones(212, 225)
        t.eq(s[1].state, "trained"); t.eq(s[2].state, "trained"); t.eq(s[3].state, "now")
        s = R.Stones(300, 300)
        for _, st in ipairs(s) do t.eq(st.state, "trained") end
        s = R.Stones(33, 75)
        t.eq(s[1].state, "later", "Journeyman needs 50")
    end)

    t.test("rules: status, most urgent first", function()
        local rec = recipes("First Aid", 42)
        t.eq(R.Status(prof(186, 300, 300), rec).kind, "mastered")
        t.eq(R.Status(prof(129, 75, 75), rec).kind, "atcap")
        t.eq(R.Status(prof(186, 59, 75), nil).kind, "trainnow")
        local s = R.Status(prof(129, 42, 75), rec)
        t.eq(s.kind, "learn"); t.eq(s.n, 2)
        t.eq(R.Status(prof(185, 23, 75), nil).kind, "unread", "Cooking's window not read")
        t.eq(R.Status(prof(182, 10, 75), nil), nil, "Herbalism has no window to read")
    end)

    t.test("rules: First Aid's collection (Gideon at 42)", function()
        local rec = recipes("First Aid", 42)
        local c = rec.counts
        t.eq(c.total, 32); t.eq(c.known, 2); t.eq(c.now, 2)
        t.eq(c.all + c.nosource, c.total, "counted plus no known source is everything")
        t.eq(c.known + c.now + c.later, c.all)
        t.eq(rec.list[1].name, "Minor Healing Potion", "levelling order: learn at 1 first")
        t.eq(find(rec.list, "Heavy Linen Bandage").state, "now")
        t.eq(find(rec.list, "Lesser Healing Potion").state, "later")
        t.eq(find(rec.list, "Heavy Mageweave Bandage").state, "nosource", "no trainer seen, no recipe item")
        local linen = find(rec.list, "Linen Bandage")
        t.ok(linen.known and linen.givesSkill, "Linen Bandage greys at 60")
        local kit = find(rec.list, "First Aid Kit")
        t.ok(kit.known and not kit.givesSkill, "First Aid Kit greys at 20")
        local heavySilk = find(rec.list, "Heavy Silk Bandage")
        t.eq(heavySilk.state, "later"); t.eq(heavySilk.learnAt, nil, "a vendor recipe's learn-at isn't known")
        t.eq(heavySilk.sources[1].kind, "vendor")
        t.eq(c.foryou, 4, "two to learn, Linen Bandage, Lesser Healing Potion at 55")
        for i = 2, #rec.list do
            t.ok(rec.list[i - 1].order <= rec.list[i].order, "levelling order at " .. i)
        end
    end)

    t.test("rules: live learned state and tracking", function()
        local rec = recipes("First Aid", 42, { known = function(id) if id == 3276 then return true end end,
            tracked = { [3275] = true } })
        t.eq(find(rec.list, "Heavy Linen Bandage").state, "known", "IsPlayerSpell wins over the recorded list")
        t.eq(find(rec.list, "Linen Bandage").state, "known", "nil from the live check keeps the recorded state")
        t.ok(find(rec.list, "Linen Bandage").tracked)
        t.eq(rec.counts.known, 3)
    end)

    t.test("rules: Blacksmithing's Season of Discovery is never counted", function()
        local rec = recipes("Blacksmithing", 33)
        local c = rec.counts
        t.eq(c.total, 500); t.eq(c.known, 16); t.eq(c.sod, 58)
        t.ok(c.nosource >= 58, "every Season of Discovery recipe is under no known source")
        for _, r in ipairs(rec.list) do
            if r.sod and not r.known then t.eq(r.state, "nosource", r.name) end
            if r.state == "nosource" then t.eq(#r.sources, 0, r.name .. " has no sources") end
        end
        t.eq(#R.Filter(rec, "all", 33), c.all)
        t.eq(#R.Filter(rec, "nosource", 33), c.nosource)
        t.eq(#R.Filter(rec, "foryou", 33), c.foryou)
        t.ok(c.foryou < 40, "For you now stays short (" .. c.foryou .. ")")
    end)

    t.test("rules: a Season of Discovery category is known by its name too", function()
        local rec = R.Recipes({ { id = 1, name = "Cooking SoD dish", learned = false, grey = 300, category = 2700, categoryName = "SEASON OF DISCOVERY" },
            { id = 2, name = "Mixed case", learned = false, grey = 300, category = 2701, categoryName = "Season of Discovery" },
            { id = 3, name = "Everyday", learned = false, grey = 50, category = 2702, categoryName = "Everyday Meals" } },
            { skill = 20, trainer = { ["Cooking SoD dish"] = 10, ["Everyday"] = 10 } })
        t.eq(rec.counts.sod, 2)
        t.eq(find(rec.list, "Cooking SoD dish").state, "nosource", "never counted, even with a trainer")
        t.eq(find(rec.list, "Mixed case").state, "nosource")
        t.eq(rec.counts.now, 1)
    end)

    t.test("rules: recipe items and their sources", function()
        t.eq(R.RecipeNameOfItem("Plans: Copper Chain Belt"), "Copper Chain Belt")
        t.eq(R.RecipeNameOfItem("Formula: Enchant Bracer - Minor Health"), "Enchant Bracer - Minor Health")
        t.eq(R.RecipeNameOfItem("Copper Ore"), nil)
        local s = R.ItemSources({ vendors = { { npc = "Deneb Walker", maps = { 1417 } } }, drops = { { maps = { 1431 } }, { maps = { 1431, 1417 } } }, quests = 1 })
        t.eq(s[1].kind, "vendor"); t.eq(s[2].kind, "drop"); t.eq(s[2].n, 2); t.eq(#s[2].maps, 2); t.eq(s[3].kind, "quest")
        s = R.ItemSources({})
        t.eq(#s, 1); t.eq(s[1].kind, "item", "a recipe item with no known place")
    end)

    t.test("rules: trainers from NPC subNames, and which to name for a rank", function()
        local bs, fa = R.Info(164), R.Info(129)
        t.eq(R.TrainerOf("Journeyman Blacksmith", bs).rank, "Journeyman")
        t.eq(R.TrainerOf("Artisan Blacksmith", bs).level, 4)
        t.eq(R.TrainerOf("Junior Blacksmithing Trainer", bs).rank, "Junior")
        local plain = R.TrainerOf("First Aid Trainer", fa)
        t.ok(plain and plain.rank == nil, "rank not stated")
        t.eq(R.TrainerOf("Expert Blacksmith", fa), nil, "another profession")
        t.eq(R.TrainerOf("Dragonscale Leatherworking Trainer", R.Info(165)), nil, "a specialisation trainer")
        t.eq(R.TrainerOf("Blacksmithing Supplies", bs), nil)
        t.eq(R.TrainerOf("Master Leatherworking Trainer", R.Info(165)).level, 5)
        t.ok(R.TrainerOf("Fishing Trainer & Supplies", R.Info(356)), "a fishing trainer who also sells")
        t.ok(R.TrainerOf("Physician", fa), "Goldshire's First Aid trainer")
        t.eq(R.TrainerOf("Physician", bs), nil)
        local list = {
            { name = "Snarl", rank = "Expert", level = 3, mapID = 1454, side = "H" },
            { name = "Therum Deepforge", rank = "Expert", level = 3, mapID = 1453, side = "A" },
            { name = "Smith Argus", rank = "Journeyman", level = 2, mapID = 1429, side = "A" },
            { name = "Jason Stonepike", rank = "Junior", level = 1, mapID = 1429, side = "A" },
            { name = "Nowhere", rank = "Artisan", level = 4, side = "A" },
            { name = "Plain", mapID = 1453, side = "AH" },
        }
        local j = R.TrainersFor(list, "Journeyman", "A")
        t.eq(#j, 3); t.eq(j[1].name, "Smith Argus"); t.eq(j[2].name, "Therum Deepforge"); t.eq(j[3].name, "Plain")
        t.eq(#R.TrainersFor(list, "Expert", "H"), 2, "Snarl, and the plain trainer")
        -- Your side's territory first: Stormwind (1453) before a contested Riverglades (2548).
        local terr = Z.faction
        local two = R.TrainersFor({ { name = "Alphonse Dumas", rank = "Journeyman", level = 2, mapID = 2548, side = "A" },
            { name = "Dane Lindgren", rank = "Journeyman", level = 2, mapID = 1453, side = "A" } }, "Journeyman", "A", terr)
        t.eq(two[1].name, "Dane Lindgren")
        -- Within your side, the nearest first: the zone you're in, then your continent.
        local fa3 = { { name = "Byancie", mapID = 1438, side = "A" }, { name = "Michelle Belle", mapID = 1429, side = "A" },
            { name = "Shaina Fuller", mapID = 1453, side = "A" } }
        local near = function(mapID) return mapID == 1429 and 0 or (mapID == 1453 and 1) or 2 end
        local ordered = R.TrainersFor(fa3, "Journeyman", "A", terr, near)
        t.eq(ordered[1].name, "Michelle Belle"); t.eq(ordered[2].name, "Shaina Fuller"); t.eq(ordered[3].name, "Byancie")
        local z = R.OrderZones({ 1411, 1412, 1420, 2521, 1429, 1426, 1438 }, terr, "Alliance")
        t.eq(z[1], 1429, "Elwynn first for an Alliance character"); t.eq(z[#z], 1420, "Tirisfal last")
        t.eq(R.OrderZones({ 1411, 1429 }, terr, "Horde")[1], 1411, "Durotar first for the Horde")
        t.eq(R.RecipeItemNames("Heavy Silk Bandage")[6], "Manual: Heavy Silk Bandage")
    end)

    t.test("rules: ingredients, have / need, where to get each", function()
        local nodes = R.NodesByItem()
        t.eq(nodes[2770].name, "Copper Vein")
        t.eq(nodes[10620].name, "Small Thorium Vein", "the lowest node wins")
        local ctx = { nodes = nodes, craftedBy = { [3530] = { id = 3276, name = "Heavy Linen Bandage" } },
            sources = { [2320] = { vendors = { { npc = "Brog Hamfist", maps = { 1429 } }, { npc = "X", maps = {} } } }, [2996] = { drops = 3 } },
            have = { [2770] = 12, [3530] = 1, [2320] = 0 } }
        local g = R.Reagents({ { itemID = 2770, need = 2 }, { itemID = 3530, need = 3 }, { itemID = 2320, need = 1 },
            { itemID = 2996, need = 1 }, { itemID = 99999, need = 1 } }, ctx)
        t.eq(g.items[1].where.kind, "gather"); t.ok(g.items[1].ok)
        t.eq(g.items[2].where.kind, "craft"); t.ok(not g.items[2].ok)
        t.eq(g.items[3].where.kind, "vendor"); t.eq(g.items[3].where.more, 1)
        t.eq(g.items[4].where.kind, "drop"); t.eq(g.items[4].have, nil)
        t.eq(g.items[5].where.kind, "unknown")
        t.eq(g.missing, 2); t.ok(g.unknown); t.ok(not g.ready)
        g = R.Reagents({ { itemID = 2770, need = 1 } }, ctx)
        t.ok(g.ready, "you have everything for one")
    end)

    t.test("rules: where to gather", function()
        local g = R.Gather("mining", 59)
        t.eq(g.current.name, "Copper Vein"); t.eq(g.current.greyAt, 101)
        t.eq(g.nextRow.name, "Tin Vein"); t.eq(g.nextRow.togo, 6)
        g = R.Gather("mining", 200)
        t.eq(g.rows[1].state, "grey", "Copper greys at 101")
        t.eq(g.current.name, "Mithril Deposit", "the highest node still giving skill")
        t.eq(g.nextRow.name, "Truesilver Deposit")
        local last = g.rows[#g.rows]
        t.eq(last.name, "Heavy Thorium Vein"); t.eq(last.state, "unknown")
        local h = R.Gather("herbalism", 1)
        t.eq(h.rows[1].state, "gives"); t.eq(h.nextRow.name, "Earthroot")
        t.eq(R.SkinningSkill(10), 1); t.eq(R.SkinningSkill(15), 50); t.eq(R.SkinningSkill(20), 100)
        t.eq(R.SkinningSkill(21), 105); t.eq(R.SkinningSkill(60), 300)
        local sk = R.Gather("skinning", 120, Z.levels)
        t.eq(#sk.rows, 0 + (function() local n = 0; for _ in pairs(Z.levels) do n = n + 1 end; return n end)())
        t.eq(sk.rows[1].from, 1)
        t.ok(sk.current and sk.current.from <= 120, "a zone to skin at 120")
        t.ok(sk.nextRow.from > 120)
        local f = R.Gather("fishing", 20)
        t.ok(f.fishing); t.eq(f.current.name, "Starting zones"); t.eq(f.nextRow.togo, 55)
        t.eq(f.rows[2].state, "later")
        f = R.Gather("fishing", 160)
        t.eq(f.rows[1].state, "earlier"); t.eq(f.current.name, "Open waters")
    end)

    t.test("rules: Next up", function()
        local mining = prof(186, 59, 75)
        local items = R.NextUp(mining, recipes("Mining", 59), R.Gather("mining", 59))
        t.eq(items[1].kind, "rank"); t.ok(items[1].now)
        local kinds = {}
        for _, it in ipairs(items) do kinds[it.kind] = it end
        t.eq(kinds.skillup.recipes[1].name, "Smelt Copper", "Smelt Copper greys at 70")
        t.eq(kinds.gather.row.name, "Copper Vein"); t.eq(kinds.gathernext.row.name, "Tin Vein")
        t.ok(#items <= R.NEXT_UP)
        local fa = prof(129, 42, 75)
        items = R.NextUp(fa, recipes("First Aid", 42), nil)
        t.eq(items[1].kind, "rank"); t.eq(items[1].togo, 8)
        t.eq(items[2].kind, "learn"); t.eq(items[2].n, 2)
        t.eq(items[3].kind, "skillup")
        items = R.NextUp(prof(185, 23, 75), nil, nil)
        t.eq(items[#items].kind, "unread")
        items = R.NextUp(prof(186, 300, 300), nil, R.Gather("mining", 300))
        t.eq(items[1].kind, "mastered")
        local fish = R.NextUp(prof(356, 20, 75), nil, R.Gather("fishing", 20))
        for _, it in ipairs(fish) do t.ok(it.kind ~= "gather", "fishing shows only the next bracket") end
    end)

    -- Systems/Professions against a mock client (Gideon's probe values) ---------------------
    local function boot(state)
        local env = {
            UnitName = function() return "Gideon" end, GetRealmName = function() return "Test Realm" end,
            UnitRace = function() return "Human", "Human", 1 end, UnitClass = function() return "Paladin", "PALADIN", 2 end,
            UnitFactionGroup = function() return "Alliance", "Alliance" end, UnitLevel = function() return 10 end,
            GetMaxPlayerLevel = function() return 60 end, UnitXP = function() return 0 end, UnitXPMax = function() return 1 end,
            GetZoneText = function() return "Elwynn Forest" end, GetSubZoneText = function() return "" end,
            C_Map = { GetBestMapForUnit = function() return 1429 end, GetMapInfo = function() return nil end },
            GetProfessions = function() return 6, 8, nil, 9, 7, 5 end,
            GetProfessionInfo = function(slot)
                local s = state.slots[slot]
                if s then return s[1], 100 + slot, s[2], s[3], 1, 0, s[4] end
            end,
            IsPlayerSpell = function(id) return state.known[id] == true end,
            C_TradeSkillUI = {
                IsTradeSkillReady = function() return state.window ~= nil end,
                IsTradeSkillLinked = function() return state.linked == true end,
                GetBaseProfessionInfo = function() return state.window and { professionID = state.window.line } end,
                GetAllRecipeIDs = function() local o = {}; for i, r in ipairs(state.window.rows) do o[i] = r.recipeID end; return o end,
                GetRecipeInfo = function(id) for _, r in ipairs(state.window.rows) do if r.recipeID == id then return r end end end,
                GetCategoryInfo = function(id) return id == 7 and { name = "Bandages", categoryID = 7 } or nil end,
                GetRecipesTracked = function()
                    local o = {}
                    for id in pairs(state.tracked or {}) do o[#o + 1] = id end
                    return o
                end,
                SetRecipeTracked = function(id, on, isRecraft)
                    if isRecraft == nil then error("Usage: C_TradeSkillUI.SetRecipeTracked(recipeID, tracked, isRecraft)") end
                    if state.trackRefuses then return end
                    state.tracked = state.tracked or {}
                    state.tracked[id] = on or nil
                end,
                GetRecipeSchematic = function(id) return state.schematics and state.schematics[id] end,
            },
            C_Item = { GetItemCount = function(id) return (state.bags or {})[id] or 0 end,
                GetItemNameByID = function() return nil end },
            LibQuestieDB = state.qdb,
            IsTradeskillTrainer = function() return state.trainer ~= nil end,
            GetNumTrainerServices = function() return state.trainer and #state.trainer or 0 end,
            GetTrainerServiceInfo = function(i) local s = state.trainer[i]; return s[1], s[2] end,
            GetTrainerServiceSkillLine = function(i) return state.trainer[i][3] end,
            GetTrainerServiceSkillReq = function(i) return state.trainer[i][3], state.trainer[i][4], true end,
            GetTrainerServiceCost = function() return 100 end,
            GetTrainerServiceTypeFilter = function() return true end,
            SetTrainerServiceTypeFilter = function() state.filterSets = (state.filterSets or 0) + 1 end,
        }
        wow.install(env)
        _G.LibQuestieDB = state.qdb -- nil clears a previous test's
        _G.AzerfolioDB, _G.AzerfolioCharDB = nil, nil
        local n = wow.loadToc("Azerfolio", "Azerfolio")
        wow.fire("ADDON_LOADED", "Azerfolio")
        wow.fire("PLAYER_LOGIN")
        wow.runTimers()
        return n
    end
    local function probeState()
        return {
            -- slot -> name, skill, cap, skill line (Gideon, /azfdiag profs run 4)
            slots = { [6] = { "Blacksmithing", 33, 75, 164 }, [8] = { "Mining", 59, 75, 186 }, [5] = { "First Aid", 42, 75, 129 },
                [9] = { "Fishing", 20, 75, 356 }, [7] = { "Cooking", 23, 75, 185 } },
            known = { [3275] = true },
        }
    end
    local firstAidWindow = { line = 129, rows = {
        { recipeID = 3275, name = "Linen Bandage", learned = true, maxTrivialLevel = 60, categoryID = 7 },
        { recipeID = 3276, name = "Heavy Linen Bandage", learned = false, maxTrivialLevel = 100, categoryID = 7 },
        { recipeID = 1244431, name = "Minor Healing Potion", learned = false, maxTrivialLevel = 95, categoryID = 0 },
    } }
    local firstAidTrainer = { { "Journeyman First Aid", "unavailable", "First Aid", 50 },
        { "Heavy Linen Bandage", "available", "First Aid", 40 }, { "Minor Healing Potion", "available", "First Aid", 1 } }

    t.test("system: skills from the game, nothing recorded yet", function()
        local state = probeState()
        local n = boot(state)
        local g = n.Professions.Get()
        t.eq(#g.professions, 5)
        t.eq(g.professions[1].name, "Blacksmithing"); t.eq(g.professions[2].name, "Mining")
        local mining = n.Professions.Find(186)
        t.eq(mining.status.kind, "trainnow")
        t.eq(n.Professions.Find(129).status.kind, "unread", "First Aid's window not read yet")
        t.eq(n.Professions.Find(129).recipes, nil)
        t.eq(n.Professions.Find(356).status, nil, "Fishing has no window to read")
        t.eq(g.summary.total, 5); t.eq(g.summary.mastered, 0)
    end)

    t.test("system: records the window and a trainer, learned stays live", function()
        local state = probeState()
        local n = boot(state)
        state.window = firstAidWindow
        wow.fire("TRADE_SKILL_SHOW"); wow.runTimers()
        local rec = _G.AzerfolioCharDB.professions.windows[129]
        t.eq(#rec.rows, 3); t.eq(rec.categories[7], "Bandages")
        local fa = n.Professions.Find(129)
        t.eq(fa.recipes.counts.total, 3); t.eq(fa.recipes.counts.known, 1)
        t.eq(fa.recipes.counts.nosource, 2, "no trainer seen yet")
        state.window = nil
        state.trainer = firstAidTrainer
        wow.fire("TRAINER_SHOW"); wow.runTimers()
        local tr = _G.AzerfolioCharDB.professions.trainers[129]
        t.eq(tr.services["Heavy Linen Bandage"].skill, 40)
        t.eq(tr.services["Journeyman First Aid"].skill, 50)
        t.eq(_G.AzerfolioCharDB.trainer.services, nil, "a profession trainer isn't the class trainer")
        fa = n.Professions.Find(129)
        t.eq(fa.recipes.counts.now, 2); t.eq(fa.status.kind, "learn")
        state.known[3276] = true
        wow.fire("NEW_RECIPE_LEARNED", 3276); wow.runTimers()
        fa = n.Professions.Find(129)
        t.eq(fa.recipes.counts.known, 2, "IsPlayerSpell read again after learning")
        t.eq(fa.recipes.counts.now, 1)
    end)

    t.test("system: a trainer list that arrives after TRAINER_SHOW, and no re-read loop", function()
        local state = probeState()
        boot(state)
        state.trainer = {} -- the list isn't there yet when the window opens
        wow.fire("TRAINER_SHOW"); wow.runTimers()
        t.eq((_G.AzerfolioCharDB.professions.trainers or {})[129], nil)
        state.trainer = firstAidTrainer
        wow.fire("TRAINER_UPDATE"); wow.runTimers()
        t.eq(_G.AzerfolioCharDB.professions.trainers[129].services["Heavy Linen Bandage"].skill, 40, "read when the list arrives")
        local sets = state.filterSets
        -- The client's TRAINER_UPDATEs for our own filter changes, a frame later: nothing new.
        for _ = 1, 3 do wow.fire("TRAINER_UPDATE"); wow.runTimers() end
        t.eq(state.filterSets, sets, "no re-read on an unchanged list")
        wow.fire("TRAINER_SHOW"); wow.runTimers()
        t.ok(state.filterSets > sets, "opening the trainer again reads again")
    end)

    t.test("system: the class trainer isn't re-read on its own updates", function()
        local state = probeState()
        boot(state)
        _G.IsTradeskillTrainer = function() return false end
        _G.GetTrainerServiceInfo = function(i) return "Seal of Might " .. i, "available" end
        _G.GetNumTrainerServices = function() return 3 end
        _G.GetTrainerServiceLevelReq = function() return 4 end
        wow.fire("TRAINER_SHOW"); wow.runTimers()
        t.eq(#_G.AzerfolioCharDB.trainer.services, 3)
        local sets = state.filterSets
        for _ = 1, 3 do wow.fire("TRAINER_UPDATE"); wow.runTimers() end
        t.eq(state.filterSets, sets, "no loop at the class trainer")
    end)

    -- A small LibQuestieDB: the readers Systems/Quests and Systems/ProfessionSources use.
    local function mockQuestieDB()
        local npcs = {
            [514] = { name = "Smith Argus", zoneID = 12, subName = "Journeyman Blacksmith", friendlyToFaction = "A" },
            [5511] = { name = "Therum Deepforge", zoneID = 1519, subName = "Expert Blacksmith", friendlyToFaction = "A" },
            [1383] = { name = "Snarl", zoneID = 1637, subName = "Expert Blacksmith", friendlyToFaction = "H" },
            [2327] = { name = "Shaina Fuller", zoneID = 1519, subName = "First Aid Trainer", friendlyToFaction = "A" },
            [247221] = { name = "Harold Justice", subName = "Junior First Aid Trainer" },
            [2843] = { name = "Deneb Walker", zoneID = 45, subName = "Medic", friendlyToFaction = "A" },
            [100] = { name = "Defias Thug", zoneID = 12 },
        }
        local itemsDB = {
            [16112] = { name = "Manual: Heavy Silk Bandage", class = 9, subClass = 7, vendors = { 2843 } },
            [99001] = { name = "Recipe: Heavy Silk Bandage", class = 9, subClass = 6, vendors = { 1383 } }, -- Alchemy: not First Aid
            [2589] = { name = "Linen Cloth", class = 7, subClass = 5, npcDrops = { 100 } },
            [2770] = { name = "Copper Ore", class = 7, subClass = 7 },
        }
        local byName = {}
        for id, it in pairs(itemsDB) do byName[it.name] = byName[it.name] or {}; table.insert(byName[it.name], id) end
        local function entity(rows, fields)
            local E = { GetAllIds = function() local o = {}; for id in pairs(rows) do o[#o + 1] = id end; table.sort(o); return o end }
            for _, f in ipairs(fields) do E[f] = function(id) return rows[id] and rows[id][f] end end
            return E
        end
        local lib = { RequireContract = function() return true end, contractVersion = 4,
            Quest = { GetAllIds = function() return {} end, zoneOrSort = function() end, specialFlags = function() end },
            Npc = entity(npcs, { "name", "zoneID", "subName", "friendlyToFaction" }),
            Item = entity(itemsDB, { "name", "class", "subClass", "vendors", "npcDrops", "objectDrops", "itemDrops", "questRewards" }) }
        lib.Item.BuildNameIndexAsync = function() coroutine.yield() end
        lib.Item.IdsByName = function(n) return byName[n] end
        return lib
    end

    t.test("system: recipe sources, trainers, ingredients and tracking (mock QuestieDB)", function()
        local state = probeState()
        state.qdb = mockQuestieDB()
        state.schematics = { [3275] = { outputItemID = 1251, reagentSlotSchematics = { { reagents = { { itemID = 2589 } }, quantityRequired = 1 } } },
            [3276] = { outputItemID = 2581, reagentSlotSchematics = { { reagents = { { itemID = 2589 } }, quantityRequired = 2 },
                { reagents = { { itemID = 1251 } }, quantityRequired = 1 } } } }
        state.bags = { [2589] = 1 }
        local n = boot(state)
        t.eq(n.ProfessionSources.State().status, "ready", "built after the quest index")
        state.window = { line = 129, rows = {
            { recipeID = 3275, name = "Linen Bandage", learned = true, maxTrivialLevel = 60, categoryID = 7, hyperlink = "|Hitem:1251::|h[Linen Bandage]|h" },
            { recipeID = 3276, name = "Heavy Linen Bandage", learned = false, maxTrivialLevel = 100, categoryID = 7, hyperlink = "|Hitem:2581::|h[x]|h" },
            { recipeID = 7929, name = "Heavy Silk Bandage", learned = false, maxTrivialLevel = 240, categoryID = 7 },
        } }
        wow.fire("TRADE_SKILL_SHOW"); wow.runTimers()
        local fa = n.Professions.Find(129)
        local silk = find(fa.recipes.list, "Heavy Silk Bandage")
        t.eq(silk.state, "later"); t.eq(#silk.sources, 1, "the Alchemy recipe item of the same name is left out")
        t.eq(silk.sources[1].kind, "vendor"); t.eq(silk.sources[1].npc, "Deneb Walker")
        t.eq(fa.trainers[1].name, "Shaina Fuller", "First Aid's plain trainer for Journeyman; the Junior one has no zone")
        local bs = n.Professions.Find(164)
        t.eq(bs.trainers[1].name, "Smith Argus"); t.eq(bs.trainers[2].name, "Therum Deepforge")
        for _, tr in ipairs(bs.trainers) do t.ok(tr.name ~= "Snarl", "a Horde trainer isn't named for an Alliance character") end
        -- Ingredients: Heavy Linen Bandage needs 2 Linen Cloth (1 in the bags, drops) and a Linen Bandage (crafted).
        local rg = n.Professions.Reagents(3276, fa)
        t.eq(#rg.items, 2)
        t.eq(rg.items[1].name, "Linen Cloth"); t.eq(rg.items[1].have, 1); t.ok(not rg.items[1].ok)
        t.eq(rg.items[1].where.kind, "drop")
        t.eq(rg.items[2].where.kind, "craft"); t.eq(rg.items[2].where.recipe.name, "Linen Bandage")
        t.eq(rg.missing, 2); t.ok(not rg.ready)
        t.eq(n.Professions.Reagents(99999, fa), nil, "no schematic")
        -- Tracking through the game.
        t.eq(n.Professions.SetTracked(3276, true), true)
        t.ok(n.Professions.Get().tracked[3276]); t.ok(find(n.Professions.Find(129).recipes.list, "Heavy Linen Bandage").tracked)
        state.tracked = { [3275] = true } -- changed in the game's own window
        t.ok(n.Professions.Get().tracked[3275] and not n.Professions.Get().tracked[3276], "Get notices the game's change")
        state.trackRefuses = true
        t.eq(n.Professions.SetTracked(3276, true), false, "reports what the game says, not what was asked")
    end)

    t.test("system: without QuestieDB, sources are unavailable and only trainers count", function()
        local state = probeState()
        local n = boot(state)
        n.ProfessionSources.Start()
        t.eq(n.ProfessionSources.State().status, "unavailable")
        t.eq(n.ProfessionSources.RecipeItem(129, "Heavy Silk Bandage"), nil)
        t.eq(n.Professions.Find(164).trainers, nil)
    end)

    t.test("system: a gathering profession's recorded window shows its recipes", function()
        local state = probeState()
        local n = boot(state)
        t.eq(n.Professions.Find(356).recipes, nil)
        state.window = { line = 356, rows = { { recipeID = 1229745, name = "Fish Bowl", learned = true, maxTrivialLevel = 20, categoryID = 2715 },
            { recipeID = 1262990, name = "Fishing Rack", learned = false, maxTrivialLevel = 140, categoryID = 2715 } } }
        state.known[1229745] = true
        wow.fire("TRADE_SKILL_SHOW"); wow.runTimers()
        local fish = n.Professions.Find(356)
        t.ok(fish.hasRecipes); t.eq(fish.recipes.counts.total, 2); t.eq(fish.recipes.counts.known, 1)
    end)

    t.test("system: a linked window or an unknown profession isn't recorded", function()
        local state = probeState()
        boot(state)
        state.window = firstAidWindow; state.linked = true
        wow.fire("TRADE_SKILL_SHOW"); wow.runTimers()
        t.eq((_G.AzerfolioCharDB.professions.windows or {})[129], nil)
        state.linked = false
        state.window = { line = 2933, rows = firstAidWindow.rows } -- "Test Profession [DNT]"
        wow.fire("TRADE_SKILL_SHOW"); wow.runTimers()
        t.eq((_G.AzerfolioCharDB.professions.windows or {})[2933], nil)
    end)

    -- The tab (UI/Pages/Professions.lua) -------------------------------------------------------
    local function openTab(n)
        n.UI.Show()
        n.UI.SelectTab("professions")
        return n.UI.GetFrame().pages.professions
    end

    t.test("ui: the rail follows focus, A goes into the page, B back, Y and X", function()
        local state = probeState()
        state.tracked = { [3275] = true }
        state.schematics = { [3275] = { outputItemID = 1251, reagentSlotSchematics = { { reagents = { { itemID = 2589 } }, quantityRequired = 1 } } } }
        state.bags = { [2589] = 4 }
        local n = boot(state)
        state.window = { line = 129, rows = {
            { recipeID = 3275, name = "Linen Bandage", learned = true, maxTrivialLevel = 60, categoryID = 7 },
            { recipeID = 3276, name = "Heavy Linen Bandage", learned = false, maxTrivialLevel = 100, categoryID = 7 } } }
        wow.fire("TRADE_SKILL_SHOW"); wow.runTimers()
        local p = openTab(n)
        t.eq(#p.railFocus, 5, "one rail entry per profession")
        t.eq(p.sel, 164, "Blacksmithing first")
        t.eq(p.mode, "rail")
        n.Focus.FocusKey("p:129")
        t.eq(p.sel, 129, "the page follows the rail's focus")
        t.eq(n.Focus.Current().key, "p:129")
        t.eq(#p.views, 2, "First Aid: Journey and Recipes")
        p:EnterPage()
        t.eq(p.mode, "page")
        t.eq(n.Focus.Current().key, "stone:Journeyman", "into the road's first stone")
        local cards = 0
        for _, row in ipairs(p.pageFocus) do for _, it in ipairs(row.items) do if it.recipeID then cards = cards + 1 end end end
        t.eq(cards, 1, "Linen Bandage's Tracked card")
        n.Focus.FocusKey("track:3275")
        t.eq(n.Focus.Current().recipeID, 3275)
        t.ok(p:OnButton("x"), "X stops tracking")
        t.eq(state.tracked[3275], nil)
        t.ok(p:Back()); t.eq(p.mode, "rail"); t.eq(n.Focus.Current().key, "p:129")
        t.ok(p:OnButton("y")); t.eq(p.view, "recipes")
        t.ok(p:OnButton("y")); t.eq(p.view, "journey", "Y cycles back")
        n.Focus.FocusKey("p:186")
        t.eq(#p.views, 3, "Mining: Journey, Recipes (smelting; asks for its window) and Gather")
        t.eq(#n.Debug.errors, 0)
    end)

    t.test("ui: Recipes (filters, list, detail, Track) and Gather", function()
        local state = probeState()
        state.schematics = { [3276] = { outputItemID = 2581, reagentSlotSchematics = {
            { reagents = { { itemID = 2589 } }, quantityRequired = 2 }, { reagents = { { itemID = 1251 } }, quantityRequired = 1 } } } }
        state.bags = { [2589] = 4 }
        local n = boot(state)
        state.window = { line = 129, rows = {
            { recipeID = 3275, name = "Linen Bandage", learned = true, maxTrivialLevel = 60, categoryID = 7, hyperlink = "|Hitem:1251::|h[x]|h" },
            { recipeID = 3276, name = "Heavy Linen Bandage", learned = false, maxTrivialLevel = 100, categoryID = 7 },
            { recipeID = 1244431, name = "Minor Healing Potion", learned = false, maxTrivialLevel = 95, categoryID = 0 },
            { recipeID = 10841, name = "Heavy Mageweave Bandage", learned = false, maxTrivialLevel = 300, categoryID = 7 } } }
        wow.fire("TRADE_SKILL_SHOW"); wow.runTimers()
        state.window = nil
        state.trainer = firstAidTrainer
        wow.fire("TRAINER_SHOW"); wow.runTimers()
        local p = openTab(n)
        n.Focus.FocusKey("p:129")
        t.ok(p:OnButton("y")); t.eq(p.view, "recipes")
        p:EnterPage()
        t.eq(n.Focus.Current().key, "r:1244431", "the first recipe in levelling order (learn at 1)")
        t.eq(p.filter, "foryou")
        local keys = {}
        for _, row in ipairs(p.pageFocus) do for _, it in ipairs(row.items) do keys[#keys + 1] = it.key end end
        t.eq(table.concat(keys, ","), "chip:foryou,chip:all,chip:known,chip:now,chip:later,chip:nosource,r:1244431,r:3276,r:3275",
            "chips, then For you now: two to learn and Linen Bandage (still gives skill)")
        n.Focus.FocusKey("r:3276")
        t.eq(p.recipeSel, 3276, "the detail follows focus")
        p:EnterDetail()
        t.eq(p.recipeFocus, "detail")
        local dkeys = {}
        for _, row in ipairs(p:GetFocusRows()) do dkeys[#dkeys + 1] = row.items[1].key end
        t.eq(table.concat(dkeys, ","), "src:1,ing:1,ing:2,track", "its source, two ingredients, Track")
        t.ok(p:OnButton("x"), "X tracks it from the detail")
        t.ok(state.tracked[3276])
        t.ok(p:Back()); t.eq(p.recipeFocus, "list"); t.eq(n.Focus.Current().key, "r:3276", "B back to the row")
        p:SetFilter("nosource")
        local seen = {}
        for _, row in ipairs(p.pageFocus) do for _, it in ipairs(row.items) do if it.recipe then seen[#seen + 1] = it.recipe.name end end end
        t.eq(table.concat(seen, ","), "Heavy Mageweave Bandage")
        t.ok(p:Back()); t.eq(p.mode, "rail")
        -- A Tracked card on Journey opens its recipe in Recipes.
        p:SetView("journey"); p:EnterPage()
        n.Focus.FocusKey("track:3276")
        n.Focus.Activate()
        t.eq(p.view, "recipes"); t.eq(n.Focus.Current().key, "r:3276")
        -- Gather (Mining): the node table.
        p:Back(); n.Focus.FocusKey("p:186")
        p:SetView("gather"); p:EnterPage()
        t.eq(n.Focus.Current().title, "Copper Vein")
        t.ok(n.Focus.Current().detail:find("Needs skill 1"), n.Focus.Current().detail)
        t.eq(#n.Debug.errors, 0)
    end)

    t.test("system: an ingredient another of your professions makes (Copper Bar from Mining)", function()
        local state = probeState()
        state.schematics = { [2662] = { outputItemID = 2852, reagentSlotSchematics = { { reagents = { { itemID = 2840 } }, quantityRequired = 4 } } } }
        local n = boot(state)
        state.window = { line = 186, rows = { { recipeID = 2657, name = "Smelt Copper", learned = true, maxTrivialLevel = 70, categoryID = 0,
            hyperlink = "|Hitem:2840::|h[Copper Bar]|h" } } }
        wow.fire("TRADE_SKILL_SHOW"); wow.runTimers()
        state.window = { line = 164, rows = { { recipeID = 2662, name = "Rough Copper Vest", learned = true, maxTrivialLevel = 55, categoryID = 0 } } }
        wow.fire("TRADE_SKILL_SHOW"); wow.runTimers()
        local bs = n.Professions.Find(164)
        local rg = n.Professions.Reagents(2662, bs)
        t.eq(rg.items[1].where.kind, "craft")
        t.eq(rg.items[1].where.recipe.name, "Smelt Copper"); t.eq(rg.items[1].where.recipe.prof, "Mining")
    end)

    t.test("ui: the Overview's Professions panel", function()
        local state = probeState()
        state.slots[9] = { "Fishing", 300, 300, 356 } -- one mastered
        local n = boot(state)
        n.UI.Show(); n.UI.SelectTab("overview")
        local ov = n.UI.GetFrame().pages.overview
        local keys = {}
        for _, row in ipairs(ov:GetFocusRows()) do
            local it = row.items[1]
            if it.key:find("^prof:") then keys[#keys + 1] = it.key .. "=" .. row.section end
        end
        t.eq(table.concat(keys, ","), "prof:164=5,prof:186=5,prof:185=5,prof:129=5,prof:356=5", "rail order, its own section")
        local fishing = ov.pools.prof[5]
        t.eq(fishing.tag:GetText(), "Mastered")
        t.eq(ov.pools.prof[2].tag:GetText(), "Train Journeyman now", "Mining at 59")
        n.Focus.FocusKey("prof:186")
        n.Focus.Activate()
        t.eq(n.UI.CurrentTab(), "professions")
        t.eq(n.Focus.Current().key, "p:186", "the tab opens on Mining")
        t.eq(n.UI.GetFrame().pages.professions.sel, 186)
        t.eq(#n.Debug.errors, 0)
    end)

    t.test("ui: no professions yet", function()
        local state = probeState()
        state.slots = {}
        local n = boot(state)
        local p = openTab(n)
        t.ok(p.empty:IsShown())
        t.eq(#p:GetFocusRows(), 0)
        _G.Screenshot = function() _G.screenshotsTaken = (_G.screenshotsTaken or 0) + 1 end
        _G.screenshotsTaken = 0
        _G.SlashCmdList.AZERFOLIO("shots professions"); wow.runTimers()
        t.eq(_G.screenshotsTaken, 3, "the empty page at each size")
        t.eq(#n.Debug.errors, 0)
    end)

    t.test("ui: /azf shots professions", function()
        local state = probeState()
        local n = boot(state)
        _G.Screenshot = function() _G.screenshotsTaken = (_G.screenshotsTaken or 0) + 1 end
        _G.screenshotsTaken = 0
        _G.SlashCmdList.AZERFOLIO("shots professions"); wow.runTimers()
        t.eq(_G.screenshotsTaken, 10, "the tab, the road, Next up, 4 more professions, Gather (Mining; no window read, so no Recipes), minimum size, wide")
        t.eq(n.UI.GetFrame().pages.professions.mode, "rail", "back on the rail")
        t.eq(#n.Debug.errors, 0)
    end)

    t.test("rules: rail order and the Overview summary", function()
        local list = R.Order({ prof(185, 23, 75), prof(186, 300, 300), prof(129, 42, 75), prof(164, 33, 75) })
        t.eq(list[1].name, "Blacksmithing"); t.eq(list[2].name, "Mining"); t.eq(list[3].name, "Cooking"); t.eq(list[4].name, "First Aid")
        local s = R.Summary(list)
        t.eq(s.mastered, 1); t.eq(s.total, 4)
    end)
end
