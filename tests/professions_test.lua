-- Professions data (Phase 14): Data/Professions.lua and Data/Gathering.lua are well formed.
-- Item IDs and recipe subclasses are checked against QuestieDB by `luajit tools/qdb.lua gather check`.
local wow = require("mocks.wow")

local function load()
    wow.install()
    local ns = {}
    for _, f in ipairs({ "Data/Zones.lua", "Data/Professions.lua", "Data/Gathering.lua" }) do
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
end
