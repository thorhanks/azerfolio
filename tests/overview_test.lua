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
    return ns.Zones.Entry(z, ex), objectives
end

-- Elwynn (current, 2 of 5), Westfall (10 of 12: closest), Redridge (1 of 9), Dun Morogh
-- (untouched, 1-10), Loch Modan (untouched, 10-20), Durotar (Horde, 1 of 3), Stormwind (not
-- tracked), Duskwood (complete).
local function world(ns)
    local list, objs = {}, {}
    local function add(...)
        local z, o = zone(ns, ...)
        list[#list + 1] = z
        objs[z.mapID] = o
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
    return list, objs
end

local function input(ns, over)
    local zones, objs = world(ns)
    local i = {
        zones = zones,
        objectivesFor = function(mapID) return objs[mapID] end,
        overall = { progress = ns.Progression.Aggregate({}), zones = 7, unavailable = 0 },
        current = 1429,
        recent = {},
        milestones = {},
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

-- Days as numbers so tests don't depend on the clock or time zone.
local DAY = 86400
local function dayOf(t) return tostring(math.floor(t / DAY)) end
local function clock(t) return string.format("%02d:%02d", math.floor(t % DAY / 3600), math.floor(t % 3600 / 60)) end

return function(t)
    t.test("overview: Continue is the current zone while it has areas left", function()
        local ns = load()
        local m = ns.Overview.Build(input(ns))
        t.eq(m.hero.zone.name, "Elwynn Forest"); t.eq(m.hero.why, "current")
        t.eq(m.goal.name, "Westfall", "next goal: fewest left, not the Continue zone")
        t.eq(m.current.name, "Elwynn Forest")
    end)

    t.test("overview: a complete or untracked current zone hands Continue to the closest zone", function()
        local ns = load()
        local m = ns.Overview.Build(input(ns, { current = 1431 }))
        t.eq(m.hero.zone.name, "Westfall"); t.eq(m.hero.why, "closest")
        t.eq(m.goal.name, "Elwynn Forest", "the next closest (3 left)")
        m = ns.Overview.Build(input(ns, { current = 1453 }))
        t.eq(m.hero.zone.name, "Westfall"); t.eq(m.current.state, "untracked")
        m = ns.Overview.Build(input(ns, { current = false }))
        t.eq(m.hero.zone.name, "Westfall", "current zone unknown")
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
        t.eq(m.goal, nil, "no zone in progress: no next goal")
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

    t.test("overview: suggestions follow the spec's rules in order, with reasons and limits", function()
        local ns = load()
        local m = ns.Overview.Build(input(ns))
        t.eq(names(m.suggestions, "zone"), "Elwynn Forest,Westfall,Redridge Mountains")
        t.eq(m.suggestions[1].rule, "current"); t.eq(m.suggestions[2].rule, "closest")
        t.eq(m.suggestions[3].rule, "level", "the first level pick not already shown")
        t.eq(#m.suggestions[1].objectives, 3); t.eq(m.suggestions[1].objectives[1].name, "Elwynn Forest 3",
            "the first area not discovered yet, in the game's order")
        t.eq(#m.suggestions[3].objectives, 6, "at most six chips"); t.eq(m.suggestions[3].more, 2)
        for _, g in ipairs(m.suggestions) do
            for _, o in ipairs(g.objectives) do t.eq(o.completion, "incomplete") end
            t.ok(g.zone.name ~= "Durotar", "the other faction's territory isn't suggested")
        end
    end)

    t.test("overview: unknown, unavailable and discovered areas are never suggested", function()
        local ns = load()
        local i = input(ns)
        local objs = {}
        local O = ns.Objectives
        objs[1] = O.New({ id = 1, category = "exploration", name = "known", completion = "incomplete", eligibility = "eligible" })
        objs[2] = O.New({ id = 2, category = "exploration", name = "unknown", completion = "unknown", eligibility = "eligible" })
        objs[3] = O.New({ id = 3, category = "exploration", name = "locked", completion = "incomplete", eligibility = "unknown" })
        objs[4] = O.New({ id = 4, category = "exploration", name = "gone", completion = "incomplete", eligibility = "unavailable" })
        objs[5] = O.New({ id = 5, category = "exploration", name = "done", completion = "complete", eligibility = "eligible" })
        local s = ns.Overview.Suggestable(objs)
        t.eq(#s, 1); t.eq(s[1].name, "known")
        -- A zone whose only unfinished areas have unknown state gets no group.
        i.objectivesFor = function(mapID) if mapID == 1429 then return { objs[2] } end end
        local m = ns.Overview.Build(i)
        t.eq(#m.suggestions, 0)
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

    t.test("overview: tracked completion passes the overall result on, or none", function()
        local ns = load()
        local m = ns.Overview.Build(input(ns, { overall = { zones = 43, unavailable = 2,
            progress = ns.Progression.Aggregate({ { category = "exploration", coverage = "unavailable", objectives = {} } }) } }))
        t.eq(m.completion.progress.percent, nil, "no percentage while zones are unreadable")
        t.eq(m.completion.unavailable, 2); t.eq(m.completion.categories[1].name, "Exploration")
        m = ns.Overview.Build({})
        t.eq(m.completion.progress, nil); t.eq(m.hero, nil); t.eq(#m.suggestions, 0)
    end)

    t.test("overview: recent zones are newest first, deduplicated, without the current zone", function()
        local ns = load()
        local m = ns.Overview.Build(input(ns, { recent = { 1426, 1436, 9999, 1429, 1433, 1436 } }))
        t.eq(names(m.recent), "Westfall,Redridge Mountains,Dun Morogh")
        local list = {}
        t.ok(ns.Overview.PushRecent(list, 1, 3)); t.ok(ns.Overview.PushRecent(list, 2, 3))
        t.eq(ns.Overview.PushRecent(list, 2, 3), false, "already the newest")
        t.ok(ns.Overview.PushRecent(list, 1, 3)); t.same(list, { 2, 1 })
        ns.Overview.PushRecent(list, 3, 3); ns.Overview.PushRecent(list, 4, 3)
        t.same(list, { 1, 3, 4 }, "capped, oldest dropped")
    end)

    t.test("overview: activity counts timed area discoveries per day; milestones newest first", function()
        local ns = load()
        local now = 100 * DAY + 15 * 3600
        local ms = {
            { kind = "area", category = "exploration", mapID = 1429, id = 1, name = "Goldshire", time = now - 13 * DAY },
            { kind = "area", category = "exploration", mapID = 1429, id = 2, name = "Old", time = now - 14 * DAY },
            { kind = "area", category = "exploration", mapID = 1429, id = 3, name = "No time" },
            { kind = "zone", category = "exploration", mapID = 1431, id = 1431, time = now - DAY },
            { kind = "area", category = "exploration", mapID = 1436, id = 4, name = "Moonbrook", time = now - 3600 },
            { kind = "area", category = "exploration", mapID = 1436, id = 5, name = "Sentinel Hill", time = now - 60 },
        }
        local m = ns.Overview.Build(input(ns, { milestones = ms, now = now, dayOf = dayOf, clock = clock }))
        local a = m.activity
        t.eq(#a.counts, 14); t.eq(a.counts[1], 1, "13 days ago is the first bar"); t.eq(a.today, 2); t.eq(a.max, 2)
        local sum = 0
        for _, c in ipairs(a.counts) do sum = sum + c end
        t.eq(sum, 3, "too old, untimed and zone milestones aren't area discoveries in the strip")
        t.eq(#m.milestones, 3)
        t.eq(m.milestones[1].name, "Sentinel Hill"); t.eq(m.milestones[1].zoneName, "Westfall")
        t.eq(m.milestones[1].when, "Today, 14:59")
        t.eq(m.milestones[3].kind, "zone"); t.eq(m.milestones[3].zoneName, "Duskwood")
        t.eq(m.milestones[3].when, "Yesterday, 15:00")
        t.eq(ns.Overview.TimeText(nil, now, dayOf, clock), "time not seen", "no invented times")
        t.eq(ns.Overview.TimeText(now - 3 * DAY, now, dayOf, clock), "3 days ago")
    end)
end
