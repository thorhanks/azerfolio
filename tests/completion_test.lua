-- Zone completion across categories (Progression.Combine, Zones.Categories), flight paths
-- (Systems/FlightPaths.lua, pure part), quest storylines and difficulty (Quests.Shape,
-- Quests.Difficulty), and the saved flight masters' lists (SavedVariables.CleanFlights).
local wow = require("mocks.wow")

local function load()
    wow.install()
    local ns = {
        Events = { On = function() end, Send = function() end, Register = function() return true end,
            Debounce = function(_, _, fn) fn() end },
        Debug = { Trace = function() end, Error = function() end, Try = function(_, fn, ...) return fn(...) end },
    }
    for _, f in ipairs({ "Core/Config.lua", "Core/SavedVariables.lua", "Data/QuestAreas.lua", "Data/FlightPaths.lua",
        "Systems/Objectives.lua", "Systems/Progression.lua", "Systems/QuestRules.lua", "Systems/Quests.lua",
        "Systems/FlightPaths.lua", "Systems/Zones.lua" }) do
        wow.loadAddonFile("Azerfolio/" .. f, "Azerfolio", ns)
    end
    return ns
end

-- An Aggregate result for `done` of `total` eligible objectives (+ `unknown` eligibility unknown).
local function agg(ns, category, done, total, unknown, completionUnknown)
    local list = {}
    for i = 1, total do
        list[i] = ns.Objectives.New({ id = i, category = category, completion = i <= done and "complete" or "incomplete",
            eligibility = "eligible" })
    end
    for i = 1, unknown or 0 do
        list[#list + 1] = ns.Objectives.New({ id = 100 + i, category = category, completion = "incomplete", eligibility = "unknown" })
    end
    for i = 1, completionUnknown or 0 do
        list[#list + 1] = ns.Objectives.New({ id = 200 + i, category = category, completion = "unknown", eligibility = "eligible" })
    end
    return ns.Progression.Aggregate({ { category = category, coverage = "complete", objectives = list } })
end

return function(t)
    t.test("combine: equal weight per category; a category that doesn't apply is left out", function()
        local ns = load()
        local c = ns.Progression.Combine({ { key = "explore", progress = agg(ns, "exploration", 7, 12) },
            { key = "quests", progress = agg(ns, "quests", 42, 68, 2) },
            { key = "flights", progress = agg(ns, "flights", 0, 0) } })
        t.eq(c.applies, 2)
        t.eq(#c.cats, 2, "the empty flight category isn't listed")
        t.eq(math.floor(c.percent * 100 + 0.5), math.floor((7 / 12 * 100 + 42 / 68 * 100) / 2 * 100 + 0.5))
        t.eq(c.state, "progress")
        t.eq(c.unchecked, true, "2 quests couldn't be checked")
        t.eq(c.cats[2].unchecked, 2)
        t.eq(c.remaining, 5 + 26)
        t.eq(ns.Progression.PercentText(c), "60%")
    end)

    t.test("combine: complete only when every category is; unchecked or pending blocks it", function()
        local ns = load()
        local P = ns.Progression
        local full = function() return { key = "explore", progress = agg(ns, "exploration", 3, 3) } end
        t.eq(P.Combine({ full(), { key = "flights", progress = agg(ns, "flights", 1, 1) } }).state, "complete")
        local u = P.Combine({ full(), { key = "quests", progress = agg(ns, "quests", 4, 4, 1) } })
        t.eq(u.state, "progress", "100% of counted quests but one unknown")
        t.eq(P.PercentText(u), "100%")
        local pend = P.Combine({ full(), { key = "flights", pending = "flightmaster" } })
        t.eq(pend.state, "progress")
        t.eq(pend.applies, 1)
        t.eq(pend.pending, true)
        t.eq(pend.cats[2].pending, "flightmaster")
        t.eq(P.Combine({}).state, "untracked")
        t.eq(P.Combine({ { key = "quests", pending = "building" } }).state, "unknown")
        t.eq(P.Combine({ { key = "explore", progress = agg(ns, "exploration", 0, 4) },
            { key = "quests", progress = agg(ns, "quests", 0, 9, 3) } }).state, "untouched")
        t.eq(P.Combine({ { key = "explore", progress = agg(ns, "exploration", 0, 4, 0, 1) } }).state, "unknown",
            "an area whose state is unknown might be discovered")
    end)

    t.test("zones: entries combine exploration, quests and flight paths", function()
        local ns = load()
        local ex = { status = "tracked", progress = agg(ns, "exploration", 2, 4) }
        local q = { status = "ready", progress = agg(ns, "quests", 1, 4) }
        local f = { status = "ready", progress = agg(ns, "flights", 1, 1) }
        local e = ns.Zones.Entry({ mapID = 1436, name = "Westfall" }, ex, q, f)
        t.eq(e.state, "progress")
        t.eq(#e.cats, 3)
        t.eq(math.floor(e.percent + 0.5), math.floor((50 + 25 + 100) / 3 + 0.5))
        t.eq(e.progress, ex.progress, "exploration's progress stays for the Overview's suggestions")
        t.eq(e.left, 2 + 3)
        local city = ns.Zones.Entry({ mapID = 1453, name = "Stormwind City" }, { status = "untracked" },
            { status = "ready", progress = agg(ns, "quests", 0, 5) }, { status = "none", count = 0 })
        t.eq(city.tracked, true, "a capital is tracked through its quests")
        t.eq(city.state, "untouched")
        local none = ns.Zones.Entry({ mapID = 2, name = "x" }, { status = "untracked" }, { status = "unavailable" }, nil)
        t.eq(none.state, "untracked", "no QuestieDB and nothing else to track: still untracked")
        local exDone = { status = "tracked", progress = agg(ns, "exploration", 4, 4) }
        local noDB = ns.Zones.Entry({ mapID = 4, name = "z" }, exDone, { status = "unavailable" }, nil)
        t.eq(noDB.cats[2].pending, "questiedb")
        t.ok(noDB.state ~= "complete", "every area found, quests unknown: not claimed (was " .. noDB.state .. ")")
        t.eq(math.floor(noDB.percent + 0.5), 100, "the % still shows what is known")
        local building = ns.Zones.Entry({ mapID = 3, name = "y" }, ex, { status = "building" }, nil)
        t.eq(building.cats[2].pending, "building")
    end)

    t.test("flight paths: names split into place and zone; zones from the curated table", function()
        local ns = load()
        local F, D = ns.FlightPaths, ns.FlightPathData
        local p, z = F.Split("Sentinel Hill, Westfall")
        t.eq(p, "Sentinel Hill"); t.eq(z, "Westfall")
        t.eq(select(1, F.Split("Moonglade")), "Moonglade")
        t.eq(F.ZoneOf({ nodeID = 4, name = "Sentinel Hill, Westfall" }, D), 1436)
        t.eq(F.ZoneOf({ nodeID = 2, name = "Stormwind, Elwynn" }, D), 1453, "override: the capital")
        t.eq(F.ZoneOf({ nodeID = 84, name = "Plaguewood Tower, Eastern Plaguelands" }, D), nil, "excluded tower")
        t.eq(F.ZoneOf({ nodeID = 3207, name = "zzOLDRiverglades, Farholde Keep" }, D), nil, "obsolete")
        t.eq(F.ZoneOf({ nodeID = 49, name = "Moonglade" }, D), 1450)
        local cat, unmapped = F.Catalogue({ { nodeID = 19, name = "Booty Bay, Stranglethorn", faction = 2, continent = 1415 },
            { nodeID = 18, name = "Booty Bay, Stranglethorn", faction = 1, continent = 1415 },
            { nodeID = 20, name = "Grom'gol, Stranglethorn", faction = 1, continent = 1415 },
            { nodeID = 19, name = "Booty Bay, Stranglethorn", faction = 2, continent = 1415 },
            { nodeID = 900, name = "Somewhere, Nowhere", faction = 0, continent = 1415 } }, D)
        t.eq(#cat[1434], 3, "duplicates by nodeID dropped")
        t.eq(cat[1434][1].place, "Booty Bay")
        t.same(unmapped, { "Somewhere, Nowhere" })
    end)

    t.test("flight paths: the flight master's list decides known, not known and not for you", function()
        local ns = load()
        local F = ns.FlightPaths
        local rec = F.Record({ { name = "Stormwind, Elwynn", type = "CURRENT" }, { name = "Sentinel Hill, Westfall", type = "REACHABLE" },
            { name = "Lakeshire, Redridge", type = "DISTANT" }, { name = "Odd", type = "NONE" }, { type = "DISTANT" } }, 1000)
        t.same(rec.nodes, { ["Stormwind, Elwynn"] = "known", ["Sentinel Hill, Westfall"] = "known", ["Lakeshire, Redridge"] = "distant" })
        local stv = { { nodeID = 18, name = "Booty Bay, Stranglethorn", place = "Booty Bay", faction = 1 },
            { nodeID = 19, name = "Booty Bay, Stranglethorn", place = "Booty Bay", faction = 2 },
            { nodeID = 20, name = "Grom'gol, Stranglethorn", place = "Grom'gol", faction = 1 } }
        local pending = F.Evaluate(1434, stv, nil, 2)
        t.eq(pending.status, "pending")
        t.eq(pending.count, 1, "only the Alliance node")
        t.eq(pending.objectives[1].completion, "unknown")
        t.eq(pending.progress.denominator, 0, "nothing counted before a flight master is seen")
        local seen = F.Evaluate(1434, stv, F.Record({ { name = "Booty Bay, Stranglethorn", type = "DISTANT" } }), 2)
        t.eq(seen.status, "ready")
        t.eq(seen.progress.completed .. "/" .. seen.progress.denominator, "0/1")
        local known = F.Evaluate(1434, stv, F.Record({ { name = "Booty Bay, Stranglethorn", type = "REACHABLE" } }), 2)
        t.eq(known.progress.trackedComplete, true)
        t.eq(F.Evaluate(1434, stv, F.Record({}), 2).status, "none", "the flight master didn't list it: not for you")
        t.eq(F.Evaluate(1429, nil, nil, 2).status, "none")
    end)

    t.test("quests: difficulty follows the client's quest colours", function()
        local ns = load()
        local D = ns.Quests.Difficulty
        t.eq(D(15, 10, 6), "red"); t.eq(D(13, 10, 6), "orange"); t.eq(D(12, 10, 6), "yellow")
        t.eq(D(8, 10, 6), "yellow"); t.eq(D(7, 10, 6), "green"); t.eq(D(4, 10, 6), "green"); t.eq(D(3, 10, 6), "grey")
        t.eq(D(nil, 10), nil)
        t.eq(ns.Quests.GreenRange(10), 6)
    end)

    t.test("quests: storylines from chain links, columns by depth, branches stack", function()
        local ns = load()
        local function o(id, name, level, completion, eligibility)
            local x = ns.Objectives.New({ id = id, category = "quests", name = name, completion = completion,
                eligibility = eligibility or "eligible" })
            x.questLevel = level
            x.kind = ns.Quests.KindOf(x)
            return x
        end
        -- The lost guards (Elwynn): 40 -> 35 -> 37 -> 45 -> 71 -> 39 -> { 46, 59 }; plus a single.
        local list = { o(40, "A Fishy Peril", 10, "complete"), o(35, "Further Concerns", 10, "incomplete"),
            o(37, "Find the Lost Guards", 10, "incomplete", "locked"), o(45, "Discover Rolf's Fate", 10, "incomplete", "locked"),
            o(71, "Report to Thomas", 10, "incomplete", "locked"), o(39, "Deliver Thomas' Report", 10, "incomplete", "locked"),
            o(46, "Bounty on Murlocs", 10, "incomplete", "locked"), o(59, "Cloth and Leather Armor", 10, "incomplete", "locked"),
            o(176, "WANTED: \"Hogger\"", 11, "incomplete"), o(7, "Kobold Camp Cleanup", 2, "complete"),
            o(15, "Investigate Echo Ridge", 3, "complete") }
        local info = { [35] = { preSingle = { 40 } }, [37] = { preSingle = { 35 } }, [45] = { preSingle = { 37 } },
            [71] = { preSingle = { 45 } }, [39] = { preSingle = { 71 } }, [46] = { preSingle = { 39 } },
            [59] = { preSingle = { 39 } }, [40] = { next = 35 }, [7] = { next = 15 } }
        local s = ns.Quests.Shape(list, function(id) return info[id] or {} end)
        t.eq(#s.stories, 1)
        local story = s.stories[1]
        t.eq(story.name, "A Fishy Peril")
        t.eq(#story.columns, 7)
        t.eq(#story.columns[7], 2, "the branch stacks")
        t.eq(story.done .. "/" .. story.total, "1/8")
        t.eq(story.ready, 1)
        t.eq(#s.finished, 1)
        t.eq(s.finished[1].name, "Kobold Camp Cleanup")
        t.eq(#s.singles, 1)
        t.eq(#s.ready, 2)
        t.eq(s.ready[1].id, 35, "by level, then name")
    end)

    t.test("next up: two areas, ready quests nearest your level, one flight path; at most five", function()
        local ns = load()
        local ex = { status = "tracked", objectives = { { id = 1, name = "A", completion = "complete" },
            { id = 2, name = "B", completion = "incomplete" }, { id = 3, name = "C", completion = "unknown" },
            { id = 4, name = "D", completion = "incomplete" }, { id = 5, name = "E", completion = "incomplete" } } }
        local q = { status = "ready", ready = { { id = 10, name = "Grey", questLevel = 1, difficulty = "grey" },
            { id = 11, name = "Hogger", questLevel = 11, difficulty = "yellow" }, { id = 12, name = "Apple", questLevel = 10, difficulty = "yellow" },
            { id = 13, name = "Easy", questLevel = 7, difficulty = "green" }, { id = 14, name = "Hard", questLevel = 13, difficulty = "orange" } } }
        local f = { status = "ready", objectives = { { id = 4, name = "Sentinel Hill", completion = "incomplete" } } }
        local n = ns.Zones.NextUp(ex, q, f)
        t.eq(#n, 5, "capped")
        t.eq(n[1].name, "B"); t.eq(n[2].name, "D", "unknown areas aren't suggested")
        t.eq(n[3].name, "Apple"); t.eq(n[4].name, "Hogger"); t.eq(n[5].name, "Hard", "yellow first, then orange")
        local n2 = ns.Zones.NextUp(nil, { status = "ready", ready = {} }, f)
        t.eq(#n2, 1); t.eq(n2[1].kind, "flights")
        t.eq(#ns.Zones.NextUp({ status = "untracked" }, { status = "building" }, { status = "pending" }), 0)
    end)

    t.test("saved flight masters' lists: bad entries are dropped", function()
        local ns = load()
        local fixes = {}
        local out = ns.SavedVariables.CleanFlights({ [1415] = { time = 1794100000, nodes = { ["A, B"] = "known", ["C, D"] = "maybe", [3] = "known" } },
            [1414] = "x", foo = { nodes = {} }, [947] = { time = -5, nodes = {} } }, fixes)
        t.same(out[1415].nodes, { ["A, B"] = "known" })
        t.eq(out[1415].time, 1794100000)
        t.eq(out[1414], nil)
        t.eq(out.foo, nil)
        t.eq(out[947].time, nil, "an implausible time is dropped, the list kept")
        t.eq(#fixes, 1)
    end)
end
