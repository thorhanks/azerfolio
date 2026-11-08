-- FocusGrid: pure gamepad focus movement.
local wow = require("mocks.wow")

local function load()
    wow.install()
    local ns = {}
    wow.loadAddonFile("Azerfolio/UI/FocusGrid.lua", "Azerfolio", ns)
    return ns.FocusGrid
end

local function item(key) return { key = key } end
local function row(section, ...)
    local items = {}
    for _, k in ipairs({ ... }) do items[#items + 1] = item(k) end
    return { items = items, section = section }
end

return function(t)
    t.test("empty grid has no focus and doesn't move", function()
        local G = load()
        local g = G.New()
        g:SetRows({})
        t.eq(g:Current(), nil)
        t.eq(g:Move("down"), false)
        t.eq(g:IsEmpty(), true)
    end)

    t.test("starts on the first item; empty rows are skipped", function()
        local G = load()
        local g = G.New()
        g:SetRows({ { items = {} }, row(nil, "a", "b") })
        t.eq(g:CurrentKey(), "a")
    end)

    t.test("moves within rows and between rows without wrapping", function()
        local G = load()
        local g = G.New()
        g:SetRows({ row(nil, "a", "b", "c"), row(nil, "d", "e", "f") })
        t.eq(g:Move("left"), false, "left edge")
        t.eq(g:Move("up"), false, "top edge")
        t.ok(g:Move("right")); t.eq(g:CurrentKey(), "b")
        t.ok(g:Move("down")); t.eq(g:CurrentKey(), "e")
        t.ok(g:Move("right")); t.ok(not g:Move("right"), "right edge")
        t.eq(g:CurrentKey(), "f")
        t.eq(g:Move("down"), false, "bottom edge")
    end)

    t.test("up/down remember the aimed column across a short row", function()
        local G = load()
        local g = G.New()
        g:SetRows({ row(nil, "a", "b", "c"), row(nil, "d"), row(nil, "e", "f", "g") })
        g:Focus(1, 3)
        g:Move("down"); t.eq(g:CurrentKey(), "d", "clamped to the short row")
        g:Move("down"); t.eq(g:CurrentKey(), "g", "back to column 3")
    end)

    t.test("focus survives SetRows by key", function()
        local G = load()
        local g = G.New()
        g:SetRows({ row(nil, "a"), row(nil, "b"), row(nil, "c") })
        g:FocusKey("c")
        g:SetRows({ row(nil, "x"), row(nil, "c"), row(nil, "a") })
        t.eq(g:CurrentKey(), "c")
    end)

    t.test("a removed item falls back to the nearest position", function()
        local G = load()
        local g = G.New()
        g:SetRows({ row(nil, "a"), row(nil, "b"), row(nil, "c") })
        g:FocusKey("c")
        g:SetRows({ row(nil, "a"), row(nil, "b") })
        t.eq(g:CurrentKey(), "b")
    end)

    t.test("LT/RT jump between sections; back goes to the section start first", function()
        local G = load()
        local g = G.New()
        g:SetRows({ row(1, "a"), row(1, "b"), row(2, "c"), row(2, "d"), row(3, "e") })
        t.ok(g:JumpSection(1)); t.eq(g:CurrentKey(), "c")
        t.ok(g:JumpSection(1)); t.eq(g:CurrentKey(), "e")
        t.eq(g:JumpSection(1), false, "no section after the last")
        g:FocusKey("d")
        t.ok(g:JumpSection(-1)); t.eq(g:CurrentKey(), "c", "start of the current section")
        t.ok(g:JumpSection(-1)); t.eq(g:CurrentKey(), "a", "then the previous section")
        t.eq(g:JumpSection(-1), false)
    end)

    t.test("without sections LT/RT page", function()
        local G = load()
        local g = G.New()
        local rows = {}
        for i = 1, 20 do rows[i] = row(nil, "r" .. i) end
        g:SetRows(rows)
        t.ok(g:JumpSection(1, 8)); t.eq(g:CurrentKey(), "r9")
        t.ok(g:JumpSection(1, 8)); t.eq(g:CurrentKey(), "r17")
        t.ok(g:JumpSection(1, 8)); t.eq(g:CurrentKey(), "r20", "clamped")
        t.eq(g:JumpSection(1, 8), false)
    end)

    t.test("groups: up/down stay in a column, skip rows without it; left/right cross", function()
        local G = load()
        local g = G.New()
        local function it(key, group) return { key = key, group = group } end
        -- Left column: hero, then a row of three chips, a row of one chip, two more rows.
        -- Right column: three panels beside the first three rows.
        g:SetRows({
            { items = { it("hero", "L"), it("p1", "R") } },
            { items = { it("c1", "L"), it("c2", "L"), it("c3", "L"), it("p2", "R") } },
            { items = { it("c4", "L"), it("p3", "R") } },
            { items = { it("c5", "L") } },
            { items = { it("c6", "L"), it("c7", "L") } },
        })
        t.ok(g:Move("right")); t.eq(g:CurrentKey(), "p1")
        t.ok(g:Move("down")); t.eq(g:CurrentKey(), "p2", "down the right column, not onto a chip")
        t.ok(g:Move("down")); t.eq(g:CurrentKey(), "p3")
        t.eq(g:Move("down"), false, "no more right items")
        t.ok(g:Move("left")); t.eq(g:CurrentKey(), "c4")
        t.ok(g:Move("up")); t.eq(g:CurrentKey(), "c1")
        t.ok(g:Move("right")); t.ok(g:Move("right")); t.eq(g:CurrentKey(), "c3")
        t.ok(g:Move("down")); t.eq(g:CurrentKey(), "c4", "shorter left row: its last chip")
        t.ok(g:Move("down")); t.ok(g:Move("down")); t.eq(g:CurrentKey(), "c7", "wanted column kept")
        t.ok(g:Move("up")); t.ok(g:Move("up")); t.ok(g:Move("up")); t.eq(g:CurrentKey(), "c3")
        g:FocusKey("p3")
        t.ok(g:Move("up")); t.eq(g:CurrentKey(), "p2")
    end)
end
