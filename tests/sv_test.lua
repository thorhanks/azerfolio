-- SavedVariables loading, validation and migration (pure logic).
local wow = require("mocks.wow")

local function load()
    wow.install()
    local ns = {}
    wow.loadAddonFile("Azerfolio/Core/Config.lua", "Azerfolio", ns)
    wow.loadAddonFile("Azerfolio/Core/SavedVariables.lua", "Azerfolio", ns)
    return ns, ns.SavedVariables, ns.Config
end

local function has(fixes, pattern)
    for _, f in ipairs(fixes) do if f:find(pattern) then return true end end
    return false
end

return function(t)
    t.test("first load produces full defaults", function()
        local _, SV, Config = load()
        local account, char, fixes = SV.Load(nil, nil)
        t.same(account, Config.ACCOUNT_DEFAULTS)
        t.same(char, Config.CHAR_DEFAULTS)
        t.eq(#fixes, 0, "no fixes on a fresh install")
    end)

    t.test("defaults are copied, not shared", function()
        local _, SV, Config = load()
        local account = SV.Load(nil, nil)
        account.zones.displayMode = "list"
        t.eq(Config.ACCOUNT_DEFAULTS.zones.displayMode, "cards")
    end)

    t.test("valid saved values survive", function()
        local _, SV = load()
        local saved = { schemaVersion = 1, lastTab = "zones", zones = { displayMode = "list", sort = "closest" },
            window = { width = 1000, height = 700, x = 12, y = -40, point = "TOPLEFT", relativePoint = "TOPLEFT" } }
        local account, _, fixes = SV.Load(saved, nil)
        t.eq(account.lastTab, "zones")
        t.eq(account.zones.displayMode, "list")
        t.eq(account.zones.sort, "closest")
        t.eq(account.zones.faction, "relevant", "missing key filled")
        t.eq(account.window.point, "TOPLEFT")
        t.eq(#fixes, 0)
    end)

    t.test("wrong types and invalid enums reset to defaults", function()
        local _, SV = load()
        local saved = { schemaVersion = 1, debug = "yes", lastTab = "legacy", zones = "broken",
            window = { width = "wide", point = "MIDDLE" } }
        local account, _, fixes = SV.Load(saved, nil)
        t.eq(account.debug, false)
        t.eq(account.lastTab, "overview")
        t.eq(account.zones.displayMode, "cards")
        t.eq(account.window.width, 960)
        t.eq(account.window.point, "CENTER")
        t.ok(has(fixes, "account debug: expected boolean"), "debug fix reported")
        t.ok(has(fixes, "lastTab: invalid value"), "enum fix reported")
        t.ok(has(fixes, "zones: expected table"), "table fix reported")
    end)

    t.test("out-of-range numbers are clamped, NaN reset", function()
        local _, SV = load()
        local nan = 0 / 0
        local account, _, fixes = SV.Load({ schemaVersion = 1, window = { width = 99999, height = 10, x = nan } }, nil)
        t.eq(account.window.width, 1400)
        t.eq(account.window.height, 560)
        t.eq(account.window.x, 0)
        t.ok(has(fixes, "clamped"))
    end)

    t.test("free-form containers keep their contents", function()
        local _, SV = load()
        local char = { schemaVersion = 1, milestones = { { id = "a" }, { id = "b" } },
            baseline = { taken = true, exploration = { [1150] = true } } }
        local _, out = SV.Load(nil, char)
        t.eq(#out.milestones, 2)
        t.eq(out.baseline.taken, true)
        t.eq(out.baseline.exploration[1150], true)
    end)

    t.test("milestone history is trimmed to the newest entries", function()
        local _, SV, Config = load()
        local list = {}
        for i = 1, Config.LIMITS.milestones + 5 do list[i] = i end
        local _, out = SV.Load(nil, { schemaVersion = 1, milestones = list })
        t.eq(#out.milestones, Config.LIMITS.milestones)
        t.eq(out.milestones[1], 6, "oldest dropped")
        t.eq(out.milestones[#out.milestones], Config.LIMITS.milestones + 5, "newest kept")
    end)

    t.test("data from a newer schema is discarded", function()
        local _, SV = load()
        local account, _, fixes = SV.Load({ schemaVersion = 99, lastTab = "zones" }, nil)
        t.eq(account.schemaVersion, 1)
        t.eq(account.lastTab, "overview")
        t.ok(has(fixes, "newer than supported"))
    end)

    t.test("migrations run in order up to the current schema", function()
        local _, SV, Config = load()
        local calls = {}
        local migrations = {
            [2] = function(db) calls[#calls + 1] = 2; db.renamed = db.old; db.old = nil end,
            [3] = function(db) calls[#calls + 1] = 3 end,
        }
        local fixes = {}
        local out = SV.Migrate({ schemaVersion = 1, old = "x" }, migrations, 3, fixes)
        t.same(calls, { 2, 3 })
        t.eq(out.schemaVersion, 3)
        t.eq(out.renamed, "x")
        t.eq(#fixes, 2)
    end)
end
