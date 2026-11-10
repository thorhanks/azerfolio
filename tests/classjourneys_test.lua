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
            for side, j in pairs(sides) do
                if side ~= "ignore" then fn(token, side, j) end
            end
        end
    end
end

local function loadRules()
    return require("mocks.wow").loadAddonFile("Azerfolio/Systems/ClassJourneyRules.lua", "Azerfolio", {}).ClassJourneyRules
end

local function set(list)
    local s = {}
    for _, id in ipairs(list) do s[id] = true end
    return s
end

return function(t)
    t.test("journey rules: a step is done by any of its quests, left out when none is for you", function()
        local R = loadRules()
        local function ev(id) if id == 2 then return "unavailable", "race or faction" end return "eligible" end
        local s = R.Step({ 1, 2 }, ev, set({ 2 }))
        t.eq(s.state, "done"); t.eq(s.id, 2)
        t.eq(R.Step(2, ev, set({})), nil)
        s = R.Step({ 2, 3 }, ev, set({}))
        t.eq(s.state, "eligible"); t.eq(s.id, 3)
        -- Without the completed list nothing is done or not done.
        t.eq(R.Step(3, ev, nil).state, "unknown")
    end)

    t.test("journey rules: routes, race masks and race versions", function()
        local R = loadRules()
        local function ev(id) if id >= 100 then return "unavailable" end return "locked", "level 10" end
        -- A finished route wins over a longer one further along nowhere.
        local stop = { key = "k", kind = "road", name = "S", level = 10,
            routes = { { 1, 2, 3, name = "long" }, { 4, name = "short" } } }
        local s = R.Stop(stop, ev, set({ 4 }), 1)
        t.eq(s.route, "short"); t.eq(s.state, "done"); t.eq(s.count, 1)
        s = R.Stop(stop, ev, set({ 1 }), 1)
        t.eq(s.route, "long"); t.eq(s.state, "progress"); t.eq(s.done, 1); t.eq(s.count, 3)
        -- raceMask: only for those races; an unknown race bit leaves the stop out.
        local sky = { key = "i", kind = "road", name = "Sky", level = 2, quests = { 5 }, raceMask = 2 ^ 32 }
        t.eq(R.Stop(sky, ev, set({}), 1), nil)
        t.eq(R.Stop(sky, ev, set({}), nil), nil)
        t.ok(R.Stop(sky, ev, set({}), 2 ^ 32), "Skyborne sees it")
        -- Race versions: the one with steps for this character.
        local j = { title = "T", stops = {
            { key = "intro", kind = "road", name = "Theirs", level = 1, quests = { 100 } },
            { key = "intro", kind = "road", name = "Mine", level = 1, quests = { 6 } } } }
        local b = R.Build(j, ev, set({}), 1)
        t.eq(#b.stops, 1); t.eq(b.stops[1].name, "Mine"); t.eq(b.stops[1].state, "later")
    end)

    t.test("journey rules: Gideon's road at level 10 (Human Paladin, the letter done)", function()
        local R = loadRules()
        local data = loadData()
        -- Dwarf versions are another race's: unavailable. Everything else waits on level.
        local dwarf = set({ 3107, 1645, 1646, 1647, 1648, 1778, 1779, 1783, 1784, 1785, 2997, 2999, 3000, 1789 })
        local function ev(id)
            if dwarf[id] then return "unavailable", "race or faction" end
            return "locked", "level"
        end
        local b = R.Build(R.Journey(data, "PALADIN", "Alliance"), ev, set({ 3101 }), 1)
        t.eq(b.title, "The Paladin's Road")
        t.eq(#b.stops, 7)
        t.eq(b.stops[1].name, "Consecrated Letter"); t.eq(b.stops[1].state, "done")
        t.eq(b.stops[2].key, "divinity"); t.eq(b.stops[2].steps[1].id, 1642); t.eq(b.stops[2].state, "later")
        t.eq(b.road.count, 5); t.eq(b.road.done, 1); t.eq(b.side.count, 2); t.eq(b.side.done, 0)
        t.eq(b.complete, false)
        -- The warhorse: any of three trainers' quests counts as the one step.
        local nob = b.stops[5]
        t.eq(nob.key, "nobility"); t.eq(nob.count, 1)
        -- Without the completed list: every stop unknown, completion not claimed.
        local u = R.Build(R.Journey(data, "PALADIN", "Alliance"), ev, nil, 1)
        t.eq(u.complete, nil); t.eq(u.unknown, #u.stops); t.eq(u.road.done, 0)
    end)

    t.test("journey rules: every curated road builds, all done when every quest is", function()
        local R = loadRules()
        local data = loadData()
        local all = R.AllIds(data)
        local function ev() return "eligible" end
        eachJourney(data, function(token, side, j)
            local b = R.Build(j, ev, all, 1)
            t.ok(#b.stops >= 3, token .. " " .. side .. " has stops")
            t.ok(b.complete == true, token .. " " .. side .. " complete when every quest is done")
            local seen = {}
            for _, s in ipairs(b.stops) do
                t.ok(not seen[s.key], token .. " " .. side .. ": one stop per key " .. s.key)
                seen[s.key] = true
            end
        end)
    end)

    t.test("class journeys: loads without WoW globals and has all nine classes on both sides", function()
        local data = loadData()
        t.ok(type(data.source) == "string", "source")
        for token in pairs(CLASSES) do
            t.ok(data[token] and data[token].Alliance and data[token].Horde, token .. ", both sides")
        end
    end)

    t.test("class journeys: ignored quests carry a reason", function()
        for token, c in pairs(loadData()) do
            if type(c) == "table" and c.ignore then
                for id, why in pairs(c.ignore) do
                    t.ok(type(id) == "number" and type(why) == "string" and #why > 0, token .. " ignore " .. tostring(id))
                end
            end
        end
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
                t.ok((s.quests == nil) ~= (s.routes == nil), "quests or routes, not both " .. at)
                local function checkList(qs)
                    t.ok(type(qs) == "table" and #qs > 0, "quests " .. at)
                    for _, q in ipairs(qs) do
                        if type(q) == "table" then
                            t.ok(#q >= 2, "an any-of entry lists at least two quests " .. at)
                            for _, a in ipairs(q) do t.ok(type(a) == "number", "quest ID " .. at) end
                        else
                            t.ok(type(q) == "number", "quest ID " .. at)
                        end
                    end
                end
                if s.routes then
                    t.ok(#s.routes >= 2, "at least two routes " .. at)
                    for _, r in ipairs(s.routes) do
                        checkList(r)
                        t.ok(r.name == nil or type(r.name) == "string", "route name " .. at)
                    end
                else
                    checkList(s.quests)
                end
                t.ok(s.raceMask == nil or (type(s.raceMask) == "number" and s.raceMask > 0), "raceMask " .. at)
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
                for _, qs in ipairs(s.routes or { s.quests }) do
                    for _, q in ipairs(qs) do
                        if type(q) == "table" then for _, a in ipairs(q) do see(a) end else see(q) end
                    end
                end
                for _, q in ipairs(s.extra or {}) do see(q) end
            end
        end)
    end)
end
