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

    t.test("rules: recipe items and their sources", function()
        t.eq(R.RecipeNameOfItem("Plans: Copper Chain Belt"), "Copper Chain Belt")
        t.eq(R.RecipeNameOfItem("Formula: Enchant Bracer - Minor Health"), "Enchant Bracer - Minor Health")
        t.eq(R.RecipeNameOfItem("Copper Ore"), nil)
        local s = R.ItemSources({ vendors = { { npc = "Deneb Walker", maps = { 1417 } } }, drops = { { maps = { 1431 } }, { maps = { 1431, 1417 } } }, quests = 1 })
        t.eq(s[1].kind, "vendor"); t.eq(s[2].kind, "drop"); t.eq(s[2].n, 2); t.eq(#s[2].maps, 2); t.eq(s[3].kind, "quest")
        s = R.ItemSources({})
        t.eq(#s, 1); t.eq(s[1].kind, "item", "a recipe item with no known place")
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

    t.test("rules: rail order and the Overview summary", function()
        local list = R.Order({ prof(185, 23, 75), prof(186, 300, 300), prof(129, 42, 75), prof(164, 33, 75) })
        t.eq(list[1].name, "Blacksmithing"); t.eq(list[2].name, "Mining"); t.eq(list[3].name, "Cooking"); t.eq(list[4].name, "First Aid")
        local s = R.Summary(list)
        t.eq(s.mastered, 1); t.eq(s.total, 4)
    end)
end
