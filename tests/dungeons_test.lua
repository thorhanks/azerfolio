-- Data/Dungeons.lua: the curated dungeon and raid list is well formed and agrees with the
-- other curated tables (zones, quest areas). NPC IDs against QuestieDB: `qdb.lua dungeons check`.
local wow = require("mocks.wow")

local function load()
    wow.install()
    local ns = {}
    for _, f in ipairs({ "Data/Zones.lua", "Data/QuestAreas.lua", "Data/Dungeons.lua" }) do
        wow.loadAddonFile("Azerfolio/" .. f, "Azerfolio", ns)
    end
    return ns
end

return function(t)
    t.test("every instance has the required fields", function()
        local ns = load()
        local keys = {}
        t.ok(#ns.DungeonData.instances >= 40, "instance count")
        for _, inst in ipairs(ns.DungeonData.instances) do
            local k = tostring(inst.key)
            t.ok(type(inst.key) == "string" and not keys[inst.key], "unique key " .. k)
            keys[inst.key] = true
            t.ok(type(inst.name) == "string" and inst.name ~= "", k .. " name")
            t.ok(inst.kind == "dungeon" or inst.kind == "raid", k .. " kind")
            t.ok(type(inst.levels) == "table" and inst.levels[1] <= inst.levels[2], k .. " levels")
            -- Stratholme and Upper Blackrock Spire run to 61 on the wiki.
            t.ok(inst.levels[1] >= 1 and inst.levels[2] <= 62, k .. " levels within 1-62")
            t.ok(type(inst.size) == "number" and inst.size >= 5, k .. " size")
            t.ok(type(inst.zones) == "table" and #inst.zones >= 1, k .. " zones")
            t.ok(type(inst.bosses) == "table" and #inst.bosses >= 1, k .. " bosses")
        end
    end)

    t.test("bosses have names and one NPC ID per member", function()
        local ns = load()
        for _, inst in ipairs(ns.DungeonData.instances) do
            for i, b in ipairs(inst.bosses) do
                local where = inst.key .. " boss " .. i
                t.ok(type(b.name) == "string" and b.name ~= "", where .. " name")
                t.ok(type(b.npcs) == "table" and #b.npcs >= 1, where .. " npcs")
                t.eq(#b.npcs, b.members and #b.members or 1, where .. " npcs per member")
                for _, id in ipairs(b.npcs) do t.ok(type(id) == "number" and id > 0, where .. " npc id") end
            end
        end
    end)

    t.test("entrance zones are curated zones; quest areas are dungeon or raid areas", function()
        local ns = load()
        local qa = ns.QuestAreaData
        for _, inst in ipairs(ns.DungeonData.instances) do
            for _, m in ipairs(inst.zones) do
                t.ok(ns.ZoneData.levels[m] or m == 1453 or m == 1454 or m == 1455,
                    inst.key .. " zone " .. m .. " is a curated zone or capital")
            end
            if inst.questArea and not inst.forever then
                local set = inst.kind == "raid" and qa.raid or qa.dungeon
                t.ok(set[inst.questArea], inst.key .. " quest area " .. inst.questArea .. " is a " .. inst.kind .. " area")
            end
        end
    end)

    t.test("every instance has a required boss", function()
        local ns = load()
        for _, inst in ipairs(ns.DungeonData.instances) do
            local last = inst.bosses[#inst.bosses]
            -- The last listed boss may be a rare or a side boss; at least one boss is required.
            local required = 0
            for _, b in ipairs(inst.bosses) do if not b.rare and not b.optional and not b.oneOf then required = required + 1 end end
            t.ok(required >= 1 or inst.key == "shapersTerrace", inst.key .. " has a required boss")
            t.ok(last.name, inst.key .. " last boss")
        end
    end)
end
