-- Objective model and Progression aggregation (pure).
local wow = require("mocks.wow")

local function load()
    wow.install()
    local ns = {}
    wow.loadAddonFile("Azerfolio/Systems/Objectives.lua", "Azerfolio", ns)
    wow.loadAddonFile("Azerfolio/Systems/Progression.lua", "Azerfolio", ns)
    return ns.Objectives, ns.Progression
end

-- obj(id, completion[, eligibility[, category]])
local function maker(O)
    return function(id, completion, eligibility, category)
        return O.New({ id = id, category = category or "exploration", completion = completion,
            eligibility = eligibility or "eligible" })
    end
end

local function set(objectives, coverage, category)
    return { category = category or "exploration", coverage = coverage or "complete", objectives = objectives }
end

return function(t)
    t.test("objective: invalid states become unknown, bad id or category is rejected", function()
        local O = load()
        local o = O.New({ id = 1, category = "exploration", completion = "done", eligibility = true })
        t.eq(o.completion, "unknown")
        t.eq(o.eligibility, "unknown")
        t.eq(O.New({ id = 1, category = "exploration" }).completion, "unknown")
        t.eq(O.New({ category = "exploration" }), nil)
        t.eq(O.New({ id = {}, category = "exploration" }), nil)
        t.eq(O.New({ id = 1 }), nil)
        t.eq(O.New("x"), nil)
    end)

    t.test("objective: only a real boolean flag is a confirmed completion", function()
        local O = load()
        t.eq(O.CompletionFromFlag(true), "complete")
        t.eq(O.CompletionFromFlag(false), "incomplete")
        t.eq(O.CompletionFromFlag(nil), "unknown")
        t.eq(O.CompletionFromFlag(1), "unknown")
        t.eq(O.CompletionFromFlag("true"), "unknown")
    end)

    t.test("Elwynn-like zone: 7 of 12 is 58%", function()
        local O, P = load()
        local obj, list = maker(O), {}
        for i = 1, 12 do list[i] = obj(1145 + i, i <= 7 and "complete" or "incomplete") end
        local r = P.Aggregate({ set(list) })
        t.eq(r.total, 12); t.eq(r.completed, 7); t.eq(r.remaining, 5); t.eq(r.denominator, 12)
        t.eq(r.coverage, "complete")
        t.eq(P.PercentText(r), "58%")
        t.eq(r.trackedComplete, false)
        t.same(r.categories, { "exploration" })
        t.same(r.excluded, {})
    end)

    t.test("unknown completion is never counted as complete or incomplete", function()
        local O, P = load()
        local obj = maker(O)
        local r = P.Aggregate({ set({ obj(1, "complete"), obj(2, "unknown"), obj(3, "incomplete") }) })
        t.eq(r.completed, 1); t.eq(r.remaining, 1); t.eq(r.denominator, 2)
        t.eq(r.completionUnknown, 1); t.eq(r.uncounted, 1)
        t.eq(r.coverage, "partial")
        t.eq(P.PercentText(r), "50%")
    end)

    t.test("all unknown gives no percentage and unavailable coverage", function()
        local O, P = load()
        local obj = maker(O)
        local r = P.Aggregate({ set({ obj(1, "unknown"), obj(2, "unknown") }) })
        t.eq(r.denominator, 0)
        t.eq(r.percent, nil)
        t.eq(P.PercentText(r), nil)
        t.eq(r.coverage, "unavailable")
        t.eq(r.trackedComplete, false)
    end)

    t.test("empty input gives no percentage, never 0%", function()
        local _, P = load()
        for _, r in ipairs({ P.Aggregate({}), P.Aggregate(nil), P.Aggregate({ set({}) }) }) do
            t.eq(r.total, 0); t.eq(r.percent, nil); t.eq(r.coverage, "unavailable")
            t.eq(r.trackedComplete, false)
        end
        t.eq(P.PercentText(nil), nil)
    end)

    t.test("eligibility: locked counts, unavailable and unknown do not", function()
        local O, P = load()
        local obj = maker(O)
        local r = P.Aggregate({ set({
            obj(1, "complete", "eligible"), obj(2, "incomplete", "locked"),
            obj(3, "incomplete", "unavailable"), obj(4, "complete", "unavailable"),
            obj(5, "incomplete", "unknown"),
        }) })
        t.eq(r.eligible, 1); t.eq(r.locked, 1); t.eq(r.unavailable, 2); t.eq(r.eligibilityUnknown, 1)
        t.eq(r.denominator, 2); t.eq(r.completed, 1); t.eq(r.remaining, 1)
        t.eq(r.uncounted, 1, "unknown eligibility is uncounted")
        t.eq(r.coverage, "partial")
    end)

    t.test("unavailable objectives alone don't block completion", function()
        local O, P = load()
        local obj = maker(O)
        local r = P.Aggregate({ set({ obj(1, "complete"), obj(2, "incomplete", "unavailable") }) })
        t.eq(r.coverage, "complete")
        t.eq(r.trackedComplete, true)
        t.eq(P.PercentText(r), "100%")
    end)

    t.test("duplicates are counted once", function()
        local O, P = load()
        local obj = maker(O)
        local r = P.Aggregate({
            set({ obj(1, "complete"), obj(2, "incomplete"), obj(1, "complete") }),
            set({ obj(2, "incomplete") }),
        })
        t.eq(r.total, 2); t.eq(r.denominator, 2); t.eq(r.conflicts, 0)
        t.eq(r.coverage, "complete")
    end)

    t.test("conflicting duplicates become unknown and lower coverage", function()
        local O, P = load()
        local obj = maker(O)
        local r = P.Aggregate({ set({ obj(1, "complete"), obj(2, "incomplete") }), set({ obj(1, "incomplete") }) })
        t.eq(r.total, 2); t.eq(r.conflicts, 1); t.eq(r.completionUnknown, 1)
        t.eq(r.completed, 0); t.eq(r.denominator, 1)
        t.eq(r.coverage, "partial")
    end)

    t.test("same ID in different categories is two objectives", function()
        local O, P = load()
        local obj = maker(O)
        local r = P.Aggregate({
            set({ obj(5, "complete") }),
            set({ obj(5, "incomplete", "eligible", "quests") }, "complete", "quests"),
        })
        t.eq(r.total, 2); t.eq(r.denominator, 2)
        t.same(r.categories, { "exploration", "quests" })
    end)

    t.test("objectives in a set of another category are ignored", function()
        local O, P = load()
        local obj = maker(O)
        local r = P.Aggregate({ set({ obj(1, "complete"), obj(2, "complete", "eligible", "quests") }) })
        t.eq(r.total, 1)
    end)

    t.test("partial or unavailable coverage leaves the category out of the percentage", function()
        local O, P = load()
        local obj = maker(O)
        local r = P.Aggregate({
            set({ obj(1, "complete"), obj(2, "incomplete") }),
            set({ obj(9, "complete", "eligible", "quests") }, "partial", "quests"),
        })
        t.eq(r.total, 3, "excluded objectives still counted in total"); t.eq(r.denominator, 2); t.eq(r.completed, 1)
        t.same(r.categories, { "exploration" }); t.same(r.excluded, { "quests" })
        t.eq(r.coverage, "partial")

        local only = P.Aggregate({ set({ obj(1, "complete") }, "unavailable") })
        t.eq(only.percent, nil); t.eq(only.coverage, "unavailable"); t.same(only.excluded, { "exploration" })
        t.eq(P.Aggregate({ set({ obj(1, "complete") }, "bogus") }).coverage, "unavailable")
    end)

    t.test("one partial zone excludes the whole category overall", function()
        local O, P = load()
        local obj = maker(O)
        local r = P.Aggregate({ set({ obj(1, "complete") }), set({ obj(2, "complete") }, "partial") })
        t.same(r.categories, {}); t.same(r.excluded, { "exploration" })
        t.eq(r.percent, nil); t.eq(r.trackedComplete, false)
    end)

    t.test("tracked complete needs every counted objective done and nothing unknown", function()
        local O, P = load()
        local obj = maker(O)
        t.eq(P.Aggregate({ set({ obj(1, "complete"), obj(2, "complete") }) }).trackedComplete, true)
        t.eq(P.Aggregate({ set({ obj(1, "complete"), obj(2, "unknown") }) }).trackedComplete, false)
        t.eq(P.Aggregate({ set({ obj(1, "complete"), obj(2, "incomplete") }) }).trackedComplete, false)
    end)

    t.test("percent text rounds down and never shows 100% early", function()
        local O, P = load()
        local obj, list = maker(O), {}
        for i = 1, 549 do list[i] = obj(i, i < 549 and "complete" or "incomplete") end
        local r = P.Aggregate({ set(list) })
        t.eq(P.PercentText(r), "99%")
        t.eq(P.PercentText({ percent = 99.99, completed = 9999, denominator = 10000 }), "99%")
        t.eq(P.PercentText({ percent = 100, completed = 3, denominator = 3 }), "100%")
        t.eq(P.PercentText({ percent = 0, completed = 0, denominator = 5 }), "0%")
    end)
end
