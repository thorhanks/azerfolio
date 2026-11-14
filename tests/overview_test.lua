-- Overview model: what the dashboard picks and counts (pure).
local wow = require("mocks.wow")

local function load()
    wow.install()
    local ns = {}
    for _, f in ipairs({ "Systems/Objectives.lua", "Systems/Progression.lua", "Systems/Zones.lua",
        "Systems/Overview.lua" }) do
        wow.loadAddonFile("Azerfolio/" .. f, "Azerfolio", ns)
    end
    return ns
end

-- A zone with `done` discovered, `todo` not, `unknown` unknown areas. Returns the catalogue
-- entry and its objectives (IDs mapID*100 + n, names "<zone> n").
local function zone(ns, mapID, name, done, todo, unknown, extra)
    local O, objectives = ns.Objectives, {}
    local function add(completion, n)
        for _ = 1, n or 0 do
            local i = #objectives + 1
            objectives[i] = O.New({ id = mapID * 100 + i, category = "exploration", name = name .. " " .. i,
                completion = completion, eligibility = "eligible" })
        end
    end
    add("complete", done); add("incomplete", todo); add("unknown", unknown)
    local ex = { status = "tracked", objectives = objectives, progress = ns.Progression.Aggregate({
        { category = "exploration", coverage = "complete", objectives = objectives } }) }
    local z = { mapID = mapID, name = name, continent = "Eastern Kingdoms", rank = 1 }
    for k, v in pairs(extra or {}) do z[k] = v end
    return ns.Zones.Entry(z, ex), objectives, ex
end

-- Elwynn (current, 2 of 5), Westfall (10 of 12: closest), Redridge (1 of 9), Dun Morogh
-- (untouched, 1-10), Loch Modan (untouched, 10-20), Durotar (Horde, 1 of 3), Stormwind (not
-- tracked), Duskwood (complete).
local function world(ns)
    local list, objs, exs = {}, {}, {}
    local function add(...)
        local z, o, ex = zone(ns, ...)
        list[#list + 1] = z
        objs[z.mapID] = o
        exs[z.mapID] = ex
    end
    add(1429, "Elwynn Forest", 2, 3, 0, { minLevel = 1, maxLevel = 10, faction = "Alliance" })
    add(1436, "Westfall", 10, 2, 0, { minLevel = 10, maxLevel = 20, faction = "Alliance" })
    add(1433, "Redridge Mountains", 1, 8, 0, { minLevel = 15, maxLevel = 25, faction = "Contested" })
    add(1426, "Dun Morogh", 0, 8, 0, { minLevel = 1, maxLevel = 10, faction = "Alliance" })
    add(1432, "Loch Modan", 0, 9, 0, { minLevel = 10, maxLevel = 20, faction = "Alliance" })
    add(1411, "Durotar", 1, 2, 0, { minLevel = 1, maxLevel = 10, faction = "Horde", continent = "Kalimdor" })
    add(1431, "Duskwood", 7, 0, 0, { minLevel = 18, maxLevel = 30, faction = "Contested" })
    list[#list + 1] = ns.Zones.Entry({ mapID = 1453, name = "Stormwind City", continent = "Eastern Kingdoms",
        rank = 1 }, { status = "untracked" })
    return list, objs, exs
end

local function input(ns, over)
    local zones = world(ns)
    local i = {
        zones = zones,
        overall = {},
        current = 1429,
        char = { faction = "Alliance", level = 9 },
    }
    for k, v in pairs(over or {}) do i[k] = v end
    return i
end

local function names(list, field)
    local out = {}
    for i, x in ipairs(list) do out[i] = field and x[field].name or x.name end
    return table.concat(out, ",")
end

return function(t)
    t.test("overview: Continue is the current zone while it has areas left", function()
        local ns = load()
        local m = ns.Overview.Build(input(ns))
        t.eq(m.hero.zone.name, "Elwynn Forest"); t.eq(m.hero.why, "current")
        t.eq(m.current.name, "Elwynn Forest")
    end)

    t.test("overview: a complete current zone stays on Continue; an untracked one hands it to the closest", function()
        local ns = load()
        local m = ns.Overview.Build(input(ns, { current = 1431 }))
        t.eq(m.hero.zone.name, "Duskwood", "your zone, even complete (owner, 2026-11-08)"); t.eq(m.hero.why, "current")
        m = ns.Overview.Build(input(ns, { current = 1453 }))
        t.eq(m.hero.zone.name, "Westfall"); t.eq(m.current.state, "untracked")
        m = ns.Overview.Build(input(ns, { current = false }))
        t.eq(m.hero.zone.name, "Westfall", "current zone unknown")
    end)

    t.test("overview: in a capital, next-for-level prefers the capital's continent", function()
        local ns = load()
        local i = input(ns, { current = 1453 })
        local keep = {}
        for _, z in ipairs(i.zones) do if z.state ~= "progress" then keep[#keep + 1] = z end end
        i.zones = keep
        i.zones[#i.zones + 1] = zone(ns, 1439, "Darkshore", 0, 9, 0, { minLevel = 10, maxLevel = 20,
            faction = "Alliance", continent = "Kalimdor" })
        local m = ns.Overview.Build(i)
        t.eq(m.hero.zone.name, "Loch Modan", "Stormwind City is in the Eastern Kingdoms; Darkshore isn't")
        t.eq(m.current.state, "untracked")
        i.current = false
        m = ns.Overview.Build(i)
        t.eq(m.hero.zone.name, "Darkshore", "without a continent: by name")
    end)

    t.test("overview: with nothing in progress, Continue is the next zone for your level", function()
        local ns = load()
        local i = input(ns, { current = false })
        local keep = {}
        for _, z in ipairs(i.zones) do if z.state ~= "progress" then keep[#keep + 1] = z end end
        i.zones = keep
        local m = ns.Overview.Build(i)
        t.eq(m.hero.why, "level")
        t.eq(m.hero.zone.name, "Loch Modan", "fits level 9 and isn't behind you (10-20 over 1-10)")
    end)

    t.test("overview: next-for-level order: in progress, fits and ahead, fits, ahead, unknown", function()
        local ns = load()
        local zones = world(ns)
        local order = ns.Overview.ForLevel(zones, 9, "Eastern Kingdoms")
        t.eq(names(order), "Westfall,Elwynn Forest,Durotar,Redridge Mountains,Loch Modan,Dun Morogh",
            "in progress first: fits and ahead, fits (current continent first), ahead; then untouched alike")
        local none = ns.Overview.ForLevel(zones, nil, nil)
        t.eq(#none, 6, "no level: still every unfinished zone")
    end)

    t.test("overview: stat counts use the zones you can explore; numbers match the Zones entries", function()
        local ns = load()
        local i = input(ns)
        local m = ns.Overview.Build(i)
        t.eq(m.zones.applicable, 6, "7 tracked minus Durotar; Stormwind isn't tracked")
        t.eq(m.zones.complete, 1); t.eq(m.zones.progress, 3); t.eq(m.zones.untouched, 2)
        t.ok(m.hero.zone == i.zones[1], "the Continue card shows the catalogue's own entry")
        t.eq(ns.Progression.PercentText(m.hero.zone.progress), "40%")
        m = ns.Overview.Build(input(ns, { char = { faction = "Horde", level = 5 } }))
        t.eq(m.zones.applicable, 3, "Horde: Redridge, Durotar, Duskwood (Alliance territory left out)")
    end)

    t.test("overview: tracked completion averages the categories with data; the others say why", function()
        local ns = load()
        local P, O = ns.Progression, ns.Objectives
        local function agg(done, todo, cov)
            local list = {}
            for n = 1, done + todo do
                list[n] = O.New({ id = n, category = "c", completion = n <= done and "complete" or "incomplete", eligibility = "eligible" })
            end
            return P.Aggregate({ { category = "c", coverage = cov or "complete", objectives = list } })
        end
        local tc = ns.Overview.Tracked({ progress = agg(10, 90), zones = 43, unavailable = 0 },
            { status = "ready", progress = agg(30, 70) }, { status = "ready", progress = agg(1, 1), unread = { 1414 } })
        t.eq(tc.combined.applies, 3)
        t.eq(math.floor(tc.combined.percent + 0.5), 30, "(10% + 30% + 50%) / 3")
        t.same(tc.flightsUnread, { 1414 }, "a continent without a flight master's list is named")
        tc = ns.Overview.Tracked({ progress = agg(10, 90), zones = 43, unavailable = 0 },
            { status = "building" }, { status = "pending", unread = { 1414, 1415 } })
        t.eq(tc.combined.applies, 1); t.eq(math.floor(tc.combined.percent + 0.5), 10, "only exploration counts")
        t.eq(tc.combined.cats[2].pending, "building"); t.eq(tc.combined.cats[3].pending, "flightmaster")
        tc = ns.Overview.Tracked({ progress = agg(0, 0), zones = 43, unavailable = 43 }, { status = "unavailable" }, nil)
        t.eq(tc.combined.percent, nil, "nothing readable: no percentage")
        t.eq(tc.combined.cats[1].pending, "achievements"); t.eq(tc.combined.cats[2].pending, "questiedb")
        local m = ns.Overview.Build({})
        t.eq(m.completion.combined.percent, nil); t.eq(m.hero, nil)
    end)
    t.test("overview: the visit list keeps the newest last, capped", function()
        local ns = load()
        local list = {}
        t.ok(ns.Overview.PushRecent(list, 1, 3)); t.ok(ns.Overview.PushRecent(list, 2, 3))
        t.eq(ns.Overview.PushRecent(list, 2, 3), false, "already the newest")
        t.ok(ns.Overview.PushRecent(list, 1, 3)); t.same(list, { 2, 1 })
        ns.Overview.PushRecent(list, 3, 3); ns.Overview.PushRecent(list, 4, 3)
        t.same(list, { 1, 3, 4 }, "capped, oldest dropped")
    end)

end
