-- Data/ClassJourneys.lua: the curated class roads are well formed. QuestieDB itself is checked
-- offline by `luajit tools/qdb.lua class check`.
local function loadData()
    local ns = {}
    assert(loadfile("Azerfolio/Data/ClassJourneys.lua"))(nil, ns)
    return ns.ClassJourneyData
end

local CLASSES = { WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true, SHAMAN = true,
    MAGE = true, WARLOCK = true, DRUID = true }

local function eachJourney(data, fn)
    for token, sides in pairs(data) do
        if type(sides) == "table" then
            for side, j in pairs(sides) do fn(token, side, j) end
        end
    end
end

return function(t)
    t.test("class journeys: loads without WoW globals and has the Paladin's two roads", function()
        local data = loadData()
        t.ok(type(data.source) == "string", "source")
        t.ok(data.PALADIN and data.PALADIN.Alliance and data.PALADIN.Horde, "Paladin, both sides")
    end)

    t.test("class journeys: every class and side is known, every stop is complete", function()
        eachJourney(loadData(), function(token, side, j)
            local where = token .. " " .. side
            t.ok(CLASSES[token], "class token " .. token)
            t.ok(side == "Alliance" or side == "Horde", "side " .. where)
            t.ok(type(j.title) == "string" and #j.stops > 0, "title and stops " .. where)
            for _, s in ipairs(j.stops) do
                local at = where .. " " .. tostring(s.key)
                t.ok(type(s.key) == "string" and type(s.name) == "string", "key and name " .. at)
                t.ok(s.kind == "road" or s.kind == "side", "kind " .. at)
                t.ok(type(s.level) == "number" and s.level >= 1 and s.level <= 60, "level " .. at)
                t.ok(type(s.quests) == "table" and #s.quests > 0, "quests " .. at)
                for _, q in ipairs(s.quests) do
                    if type(q) == "table" then
                        t.ok(#q >= 2, "an any-of entry lists at least two quests " .. at)
                        for _, a in ipairs(q) do t.ok(type(a) == "number", "quest ID " .. at) end
                    else
                        t.ok(type(q) == "number", "quest ID " .. at)
                    end
                end
                for _, q in ipairs(s.extra or {}) do t.ok(type(q) == "number", "extra quest ID " .. at) end
                t.ok(s.order == nil or s.order == "inferred", "order " .. at)
            end
        end)
    end)

    t.test("class journeys: side paths branch off a road stop, road levels never go down", function()
        eachJourney(loadData(), function(token, side, j)
            local road, last = {}, 0
            for _, s in ipairs(j.stops) do
                if s.kind == "road" then
                    road[s.key] = true
                    t.ok(s.level >= last, token .. " " .. side .. ": road level goes down at " .. s.key)
                    last = s.level
                end
            end
            for _, s in ipairs(j.stops) do
                if s.kind == "side" then t.ok(road[s.from], token .. " " .. side .. ": " .. s.key .. " branches off a road stop") end
            end
        end)
    end)

    t.test("class journeys: a quest belongs to one stop (race versions share their key)", function()
        eachJourney(loadData(), function(token, side, j)
            local keyOf = {}
            for _, s in ipairs(j.stops) do
                local function see(id)
                    t.ok(keyOf[id] == nil or keyOf[id] == s.key, token .. " " .. side .. ": quest " .. id .. " in two stops")
                    keyOf[id] = s.key
                end
                for _, q in ipairs(s.quests) do
                    if type(q) == "table" then for _, a in ipairs(q) do see(a) end else see(q) end
                end
                for _, q in ipairs(s.extra or {}) do see(q) end
            end
        end)
    end)
end
