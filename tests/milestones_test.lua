-- Baseline and milestone rules (pure parts of Systems/Milestones.lua).
local wow = require("mocks.wow")

local function load()
    wow.install()
    local ns = {}
    wow.loadAddonFile("Azerfolio/Systems/Milestones.lua", "Azerfolio", ns)
    return ns.Milestones
end

-- result({ [id] = "complete"|"incomplete"|"unknown", ... }, trackedComplete)
local function result(states, complete)
    local objectives = {}
    for id, c in pairs(states) do objectives[#objectives + 1] = { id = id, name = "Area " .. id, completion = c } end
    table.sort(objectives, function(a, b) return a.id < b.id end)
    return { objectives = objectives, progress = { trackedComplete = complete == true } }
end

return function(t)
    t.test("first sight of a zone is its baseline: no milestones for existing progress", function()
        local M = load()
        local base, found = M.Compare(nil, result({ [1] = "complete", [2] = "incomplete", [3] = "unknown" }))
        t.eq(#found, 0)
        t.same(base.states, { [1] = true, [2] = false }, "unknown isn't stored")
        t.eq(base.complete, false)
    end)

    t.test("a zone already complete at baseline gives no zone milestone", function()
        local M = load()
        local base, found = M.Compare(nil, result({ [1] = "complete" }, true))
        t.eq(#found, 0); t.eq(base.complete, true)
        local _, again = M.Compare(base, result({ [1] = "complete" }, true))
        t.eq(#again, 0)
    end)

    t.test("not discovered -> discovered is a milestone, once", function()
        local M = load()
        local base = M.Compare(nil, result({ [1] = "complete", [2] = "incomplete" }))
        local base2, found = M.Compare(base, result({ [1] = "complete", [2] = "complete" }))
        t.eq(#found, 1); t.eq(found[1].kind, "area"); t.eq(found[1].id, 2); t.eq(found[1].name, "Area 2")
        t.eq(base2.states[2], true)
        local _, again = M.Compare(base2, result({ [1] = "complete", [2] = "complete" }))
        t.eq(#again, 0, "no repeat")
    end)

    t.test("unknown at baseline, then discovered: no milestone (it may have been done before)", function()
        local M = load()
        local base = M.Compare(nil, result({ [1] = "unknown" }))
        local base2, found = M.Compare(base, result({ [1] = "complete" }))
        t.eq(#found, 0); t.eq(base2.states[1], true)
    end)

    t.test("an area new to the baseline (a patch) is recorded without a milestone", function()
        local M = load()
        local base = M.Compare(nil, result({ [1] = "incomplete" }))
        local base2, found = M.Compare(base, result({ [1] = "incomplete", [9] = "complete" }))
        t.eq(#found, 0); t.eq(base2.states[9], true)
    end)

    t.test("a later unknown or not-done never erases a discovery", function()
        local M = load()
        local base = M.Compare(nil, result({ [1] = "complete", [2] = "complete" }))
        local base2, found = M.Compare(base, result({ [1] = "unknown", [2] = "incomplete" }))
        t.eq(#found, 0); t.eq(base2.states[1], true); t.eq(base2.states[2], true)
    end)

    t.test("an area missing from a read keeps its baseline state", function()
        local M = load()
        local base = M.Compare(nil, result({ [1] = "incomplete", [2] = "incomplete" }))
        local base2 = M.Compare(base, result({ [1] = "incomplete" }))
        t.eq(base2.states[2], false)
    end)

    t.test("finishing a zone adds a zone milestone after the area", function()
        local M = load()
        local base = M.Compare(nil, result({ [1] = "complete", [2] = "incomplete" }, false))
        local base2, found = M.Compare(base, result({ [1] = "complete", [2] = "complete" }, true))
        t.eq(#found, 2); t.eq(found[1].kind, "area"); t.eq(found[2].kind, "zone")
        t.eq(base2.complete, true)
        local _, again = M.Compare(base2, result({ [1] = "complete", [2] = "complete" }, true))
        t.eq(#again, 0)
    end)

    t.test("Append skips duplicates and damaged entries", function()
        local M = load()
        local list = { { kind = "area", category = "exploration", id = 1 }, "junk", { kind = "zone" } }
        local added = M.Append(list, {
            { kind = "area", category = "exploration", id = 1 },
            { kind = "area", category = "exploration", id = 2 },
            { kind = "area", category = "exploration", id = 2 },
            { kind = "zone", category = "exploration", id = 1 },
        })
        t.eq(#added, 2); t.eq(added[1].id, 2); t.eq(added[2].kind, "zone")
        t.eq(#list, 5)
    end)
end
