-- Quest catalogue (Systems/Quests.lua): detection, placement, the index and the batched build.
local wow = require("mocks.wow")

-- Loads the pure module with stub services; `events` collects On() handlers.
local function load()
    wow.install()
    local events, sent, traces = {}, {}, {}
    local ns = {
        Events = {
            On = function(msg, fn) events[msg] = fn end,
            Send = function(msg) sent[#sent + 1] = msg end,
            Debounce = function(_, _, fn) fn() end,
        },
        Debug = { Trace = function(kind, f) traces[#traces + 1] = { kind = kind, f = f } end,
            Error = function() end, Try = function(_, fn, ...) return fn(...) end },
    }
    wow.loadAddonFile("Azerfolio/Data/QuestAreas.lua", "Azerfolio", ns)
    wow.loadAddonFile("Azerfolio/Systems/Quests.lua", "Azerfolio", ns)
    return ns, events, sent, traces
end

-- A fake QuestieDB: quests = { [id] = { zoneOrSort, specialFlags } }.
local function fakeLib(quests, opts)
    opts = opts or {}
    local ids = {}
    for id in pairs(quests) do ids[#ids + 1] = id end
    table.sort(ids)
    local Q = {
        GetAllIds = function() return ids end,
        zoneOrSort = function(id)
            if opts.failOn == id then error("bad row") end
            return quests[id][1]
        end,
        specialFlags = function(id) return quests[id][2] end,
    }
    return {
        contractVersion = opts.contract or 4,
        RequireContract = function(n) return n <= (opts.contract or 4), "too old" end,
        Quest = Q,
    }
end

local AREAS = {
    zone = { [12] = 1429, [9] = 1429, [16732] = 1437, [1519] = 1453 },
    dungeon = { [133] = true }, raid = { [3456] = true }, battleground = { [2597] = true },
}

return function(t)
    t.test("quests: detects QuestieDB, a contract mismatch and missing readers", function()
        local ns = load()
        local D = ns.Quests.Detect
        t.eq(D(nil), false)
        t.eq(select(2, D(nil)), "QuestieDB is not loaded")
        t.eq(D(fakeLib({})), true)
        local ok, why = D(fakeLib({}, { contract = 3 }))
        t.eq(ok, false)
        t.ok(why:find("contract 3"), why)
        t.eq(D({ RequireContract = function() return true end, Quest = {} }), false, "no readers")
        t.eq(D({ RequireContract = function() error("boom") end }), false, "check raises")
    end)

    t.test("quests: placement by area, sort, dungeon, raid, battleground and unmapped", function()
        local ns = load()
        local P = ns.Quests.Place
        t.same({ P(12, AREAS) }, { "zone", 1429 })
        t.same({ P(9, AREAS) }, { "zone", 1429 }, "subzone to its zone")
        t.same({ P(16732, AREAS) }, { "zone", 1437 }, "curated: Excavation Site: Wetlands")
        t.same({ P(133, AREAS) }, { "dungeon", 133 })
        t.same({ P(3456, AREAS) }, { "raid", 3456 })
        t.same({ P(2597, AREAS) }, { "battleground", 2597 })
        t.same({ P(-284, AREAS) }, { "sort", -284 })
        t.same({ P(0, AREAS) }, { "nozone" })
        t.same({ P(nil, AREAS) }, { "nozone" })
        t.same({ P(25, AREAS) }, { "unmapped", 25 })
    end)

    t.test("quests: repeatable is specialFlags bit 1", function()
        local ns = load()
        local R = ns.Quests.IsRepeatable
        t.eq(R(1), true); t.eq(R(3), true); t.eq(R(2), false); t.eq(R(0), false); t.eq(R(nil), false)
    end)

    t.test("quests: the index counts zone quests and every left-out reason", function()
        local ns = load()
        local Q = ns.Quests
        local i = Q.NewIndex()
        Q.Add(i, 1, 12, 0, AREAS)       -- Elwynn
        Q.Add(i, 2, 9, 0, AREAS)        -- Northshire -> Elwynn
        Q.Add(i, 3, 12, 1, AREAS)       -- Elwynn, repeatable: left out, noted on the zone
        Q.Add(i, 4, 133, 0, AREAS)      -- Gnomeregan: dungeon, kept per instance
        Q.Add(i, 5, 3456, 0, AREAS)     -- Naxxramas: raid
        Q.Add(i, 6, 2597, 0, AREAS)     -- Alterac Valley
        Q.Add(i, 7, -284, 0, AREAS)     -- a quest sort
        Q.Add(i, 8, 0, 0, AREAS)        -- no zone
        Q.Add(i, 9, 25, 0, AREAS)       -- unmapped
        Q.Add(i, 10, nil, nil, AREAS, false) -- read error
        Q.Add(i, 11, 1519, 0, AREAS)    -- Stormwind City: capitals count
        t.eq(i.total, 11)
        t.eq(i.counted, 3)
        t.same(i.zones[1429].ids, { 1, 2 })
        t.eq(i.zones[1429].repeatable, 1)
        t.same(i.zones[1453].ids, { 11 })
        t.same(i.left, { repeatable = 1, sort = 1, nozone = 1, dungeon = 1, raid = 1, battleground = 1,
            unmapped = 1, error = 1 })
        t.same(i.instances[133], { kind = "dungeon", ids = { 4 } })
        t.same(i.instances[3456], { kind = "raid", ids = { 5 } })
        t.eq(i.unmapped[25], 1)
        t.eq(i.sorts[-284], 1)
        -- Every quest is either counted or left out for exactly one reason.
        local left = 0
        for _, n in pairs(i.left) do left = left + n end
        t.eq(i.counted + left, i.total)
    end)

    t.test("quests: the builder reads in batches and survives a failing row", function()
        local ns = load()
        local quests = {}
        for id = 1, 23 do quests[id] = { 12, 0 } end
        quests[7] = { 133, 0 }
        local lib = fakeLib(quests, { failOn = 9 })
        local b = ns.Quests.Builder(lib.Quest, lib.Quest.GetAllIds(), AREAS)
        t.eq(b.Step(10), false)
        t.eq(select(1, b.Progress()), 10)
        t.eq(b.Step(10), false)
        t.eq(b.Step(10), true)
        t.eq(b.steps, 3)
        t.eq(b.index.total, 23)
        t.eq(b.index.counted, 21)
        t.eq(b.index.left.dungeon, 1)
        t.eq(b.index.left.error, 1)
    end)

    t.test("quests: unavailable with the reason when QuestieDB is missing, never zero", function()
        local ns, events, sent = load()
        _G.LibQuestieDB = nil
        events.AZF_READY()
        local s = ns.Quests.State()
        t.eq(s.status, "unavailable")
        t.eq(s.reason, "QuestieDB is not loaded")
        local z = ns.Quests.ForZone(1429)
        t.eq(z.status, "unavailable")
        t.eq(z.count, nil, "no count without data")
        t.eq(sent[#sent], "AZF_QUESTS_UPDATED")
    end)

    t.test("quests: builds across frames on AZF_READY and answers per zone", function()
        local ns, events, sent = load()
        local quests = {}
        for id = 1, 1200 do quests[id] = { 12, 0 } end
        quests[5] = { 12, 1 }
        quests[6] = { 1519, 0 }
        _G.LibQuestieDB = fakeLib(quests)
        events.AZF_READY()
        t.eq(ns.Quests.State().status, "building")
        t.eq(ns.Quests.ForZone(1429).status, "building")
        wow.runTimers()
        _G.LibQuestieDB = nil
        local s = ns.Quests.State()
        t.eq(s.status, "ready")
        t.eq(s.steps, 3, "1,200 quests in batches of 500")
        local z = ns.Quests.ForZone({ mapID = 1429 })
        t.eq(z.count, 1198)
        t.eq(z.repeatable, 1)
        t.eq(ns.Quests.ForZone(1453).count, 1)
        t.eq(ns.Quests.ForZone(1426).count, 0, "a listed zone QuestieDB has nothing for")
        t.eq(sent[#sent], "AZF_QUESTS_UPDATED")
        ns.Quests.Start()
        t.eq(ns.Quests.State(), s, "builds once")
    end)

    t.test("maps: Darkspear Islands (type 6) is listed; other type 6 maps aren't", function()
        wow.install({ C_Map = { GetMapInfo = function(id)
            local maps = {
                [1414] = { name = "Kalimdor", mapType = 2, parentMapID = 947 },
                [947] = { name = "Azeroth", mapType = 1, parentMapID = 0 },
                [1411] = { name = "Durotar", mapType = 3, parentMapID = 1414 },
                [2524] = { name = "Darkspear Islands", mapType = 6, parentMapID = 1414 },
                [1460] = { name = "Warsong Gulch", mapType = 6, parentMapID = 1414 },
            }
            return maps[id]
        end } })
        local ns = wow.loadAddonFile("Azerfolio/Systems/Maps.lua", "Azerfolio", {})
        local sections = ns.Maps.Sections()
        t.eq(#sections, 1)
        local names = {}
        for _, z in ipairs(sections[1].zones) do names[#names + 1] = z.name end
        t.eq(table.concat(names, ","), "Darkspear Islands,Durotar")
        t.eq(sections[1].title, "Kalimdor")
    end)

    t.test("quest areas: the curated table is consistent", function()
        local ns = load()
        local A = ns.QuestAreaData
        local seen, zones = {}, 0
        for _, kind in ipairs({ "zone", "dungeon", "raid", "battleground" }) do
            for areaID in pairs(A[kind]) do
                t.ok(not seen[areaID], "area " .. areaID .. " in two groups")
                seen[areaID] = kind
                if kind == "zone" then zones = zones + 1 end
            end
        end
        t.eq(zones, 65)
        t.eq(A.zone[16732], 1437, "Excavation Site: Wetlands -> Wetlands")
        t.eq(A.zone[16606], 2524, "Darkspear Islands")
        for _, dungeonOnZone in ipairs({ 133, 978, 1517, 1717 }) do
            t.eq(seen[dungeonOnZone], "dungeon", "area " .. dungeonOnZone)
        end
        for _, left in ipairs({ 25, 2257, 16544, 16611, 16919, 16941 }) do
            t.eq(seen[left], nil, "area " .. left .. " stays unmapped")
        end
    end)
end
