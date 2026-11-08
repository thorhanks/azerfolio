-- Quest eligibility (Systems/QuestRules.lua) and zone evaluation (Quests.Evaluate). Pure.
local wow = require("mocks.wow")

local function load()
    wow.install()
    local ns = { Events = { On = function() end, Send = function() end, Debounce = function() end,
        Register = function() return true end }, Debug = { Trace = function() end, Error = function() end,
        Try = function(_, fn, ...) return fn(...) end } }
    for _, f in ipairs({ "Systems/Objectives.lua", "Systems/Progression.lua", "Systems/QuestRules.lua",
        "Systems/Quests.lua" }) do
        wow.loadAddonFile("Azerfolio/" .. f, "Azerfolio", ns)
    end
    return ns
end

local ALLIANCE, HORDE = 4294967373, 8589934770 -- QuestieDB masks, with Skyborne bits [verified-ingame]
local HUMAN_PALADIN_10 = { raceID = 1, classID = 2, level = 10 }

-- ctx over a table of records; completed is a list of IDs (nil = unknown).
local function ctx(ns, records, completed, char)
    local done
    if completed then
        done = {}
        for _, id in ipairs(completed) do done[id] = true end
    end
    return ns.QuestRules.Context(function(id) return records[id] end, done, char or HUMAN_PALADIN_10)
end

local function eval(ns, records, id, completed, char)
    return ns.QuestRules.Evaluate(ctx(ns, records, completed, char), id)
end

return function(t)
    t.test("rules: bits work above 2^32 and repeatables include dailies", function()
        local R = load().QuestRules
        t.eq(R.HasBit(ALLIANCE, R.RaceBit(1)), true, "Human in Alliance")
        t.eq(R.HasBit(HORDE, R.RaceBit(1)), false)
        t.eq(R.HasBit(HORDE, R.RaceBit(2)), true, "Orc in Horde")
        t.eq(R.HasBit(ALLIANCE, 2 ^ 32), true, "Skyborne Alliance bit")
        t.eq(R.RaceBit(10), nil, "races past 9 aren't checked")
        t.eq(R.ClassBit(2), 2)
        t.eq(R.IsRepeatable(1, 0), true)
        t.eq(R.IsRepeatable(0, 4096), true, "daily")
        t.eq(R.IsRepeatable(0, 4096 + 8), true)
        t.eq(R.IsRepeatable(0, 8), false)
        t.eq(R.IsRepeatable(nil, nil), false)
    end)

    t.test("rules: race, faction, class and level", function()
        local ns = load()
        local recs = {
            [1] = { races = ALLIANCE },
            [2] = { races = HORDE },
            [3] = { classes = 2 },              -- Paladin
            [4] = { classes = 1 },              -- Warrior
            [5] = { reqLevel = 12 },
            [6] = { maxLevel = 9 },
            [7] = {},
        }
        t.same({ eval(ns, recs, 1) }, { "eligible" })
        t.same({ eval(ns, recs, 2) }, { "unavailable", "race or faction" })
        t.same({ eval(ns, recs, 3) }, { "eligible" })
        t.same({ eval(ns, recs, 4) }, { "unavailable", "class" })
        t.same({ eval(ns, recs, 5) }, { "locked", "level 12" })
        t.same({ eval(ns, recs, 6) }, { "unavailable", "level too high" })
        t.same({ eval(ns, recs, 7) }, { "eligible" })
        t.same({ eval(ns, recs, 99) }, { "unknown", "not in QuestieDB" })
        t.same({ eval(ns, recs, 1, nil, { raceID = 30, classID = 2, level = 10 }) }, { "unknown", "race not checked" })
        t.same({ eval(ns, recs, 5, nil, { raceID = 1, classID = 2 }) }, { "unknown", "level not known" })
    end)

    t.test("rules: the worst rule wins; unknown outranks locked", function()
        local ns = load()
        local recs = {
            [1] = { races = HORDE, reqLevel = 20 },
            [2] = { reqLevel = 20, needs = "reputation" },
        }
        t.same({ eval(ns, recs, 1) }, { "unavailable", "race or faction" })
        t.same({ eval(ns, recs, 2) }, { "unknown", "reputation not checked" })
    end)

    t.test("rules: exclusive choices, chains, breadcrumbs and parent quests", function()
        local ns = load()
        local recs = {
            [1] = { exclusive = { 2 } }, [2] = { exclusive = { 1 } },
            [3] = { next = 4 }, [4] = {},
            [5] = { breadcrumbFor = 6 }, [6] = {},
            [7] = { untilCompleted = 8 }, [8] = {},
            [9] = { parent = 10 }, [10] = {},
        }
        t.same({ eval(ns, recs, 1, { 2 }) }, { "unavailable", "exclusive choice" })
        t.same({ eval(ns, recs, 2, { 2 }) }, { "eligible", "completed" })
        t.same({ eval(ns, recs, 1, {}) }, { "eligible" })
        t.same({ eval(ns, recs, 3, { 4 }) }, { "unavailable", "chain moved on" })
        t.same({ eval(ns, recs, 5, { 6 }) }, { "unavailable", "breadcrumb skipped" })
        t.same({ eval(ns, recs, 5, {}) }, { "eligible" })
        t.same({ eval(ns, recs, 7, { 8 }) }, { "unavailable", "no longer offered" })
        t.same({ eval(ns, recs, 9, { 10 }) }, { "unavailable", "parent quest done" })
        t.same({ eval(ns, recs, 9, {}) }, { "locked", "parent quest" })
        t.same({ eval(ns, recs, 1, nil) }, { "unknown", "completed quests not known" })
    end)

    t.test("rules: prerequisites (all of a group, one of a single list), recursively", function()
        local ns = load()
        local recs = {
            [1] = {}, [2] = {}, [3] = { races = HORDE },
            [10] = { preGroup = { 1, 2 } },
            [11] = { preSingle = { 1, 3 } },
            [12] = { preSingle = { 3 } },          -- only a Horde prerequisite
            [13] = { preGroup = { 3 } },
            [14] = { preSingle = { 12 } },         -- two steps from a Horde quest
            [15] = { preSingle = { 16 } }, [16] = { preSingle = { 15 } }, -- a loop in the data
            [17] = { startingWith = 1 },
        }
        t.same({ eval(ns, recs, 10, { 1 }) }, { "locked", "prerequisite" })
        t.same({ eval(ns, recs, 10, { 1, 2 }) }, { "eligible" })
        t.same({ eval(ns, recs, 11, {}) }, { "locked", "prerequisite" })
        t.same({ eval(ns, recs, 11, { 1 }) }, { "eligible" })
        t.same({ eval(ns, recs, 12, {}) }, { "unavailable", "prerequisite unavailable" })
        t.same({ eval(ns, recs, 13, {}) }, { "unavailable", "prerequisite unavailable" })
        t.same({ eval(ns, recs, 14, {}) }, { "unavailable", "prerequisite unavailable" })
        t.same({ eval(ns, recs, 15, {}) }, { "unknown", "prerequisite unknown" })
        t.same({ eval(ns, recs, 17, {}) }, { "locked", "prerequisite" })
        t.same({ eval(ns, recs, 17, { 1 }) }, { "eligible" })
        t.same({ eval(ns, recs, 10, nil) }, { "unknown", "completed quests not known" })
    end)

    t.test("rules: a read error or missing record is unknown", function()
        local ns = load()
        t.same({ eval(ns, { [1] = { err = true } }, 1) }, { "unknown", "QuestieDB read error" })
    end)

    t.test("details: reads only present fields and flags unchecked requirements", function()
        local ns = load()
        local Q = {
            name = function() return "Report to Goldshire" end, questLevel = function() return 5 end,
            requiredLevel = function() return 0 end, preQuestSingle = function() return {} end,
            requiredRaces = function() return ALLIANCE end, requiredMinRep = function() return { 59, 3000 } end,
            exclusiveTo = function() error("bad") end,
        }
        local r = ns.Quests.ReadDetails(Q, 1)
        t.eq(r.name, "Report to Goldshire")
        t.eq(r.level, 5)
        t.eq(r.reqLevel, nil, "0 isn't kept")
        t.eq(r.preSingle, nil, "an empty list isn't kept")
        t.eq(r.races, ALLIANCE)
        t.eq(r.needs, "reputation")
        t.eq(r.err, true)
    end)

    t.test("evaluate: a zone's objectives and progress leave unavailable and unknown out", function()
        local ns = load()
        local recs = {
            [1] = { name = "A" }, [2] = { name = "B" }, [3] = { name = "C", races = HORDE },
            [4] = { name = "D", reqLevel = 20 }, [5] = { name = "E", needs = "profession" },
        }
        local r = ns.Quests.Evaluate(ctx(ns, recs, { 1 }), 1429, { 1, 2, 3, 4, 5 }, 2)
        t.eq(r.count, 5)
        t.eq(r.repeatable, 2)
        local p = r.progress
        t.eq(p.completed, 1)
        t.eq(p.denominator, 3, "eligible A, B and locked D")
        t.eq(p.unavailable, 1)
        t.eq(p.eligibilityUnknown, 1)
        t.eq(p.coverage, "partial", "one quest's eligibility is unknown")
        t.eq(r.objectives[1].category, "quests")
        t.eq(r.objectives[1].completion, "complete")
        t.eq(r.objectives[4].reason, "level 20")
        t.eq(r.reasons["race or faction"], 1)

        local unknownList = ns.Quests.Evaluate(ctx(ns, recs, nil), 1429, { 1, 2 }, 0)
        t.eq(unknownList.progress.percent, nil, "no completed list: no percentage")
        t.eq(unknownList.objectives[1].completion, "unknown")
    end)
end
