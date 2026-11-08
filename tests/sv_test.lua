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

local function milestone(id, time)
    return { kind = "area", category = "exploration", mapID = 1429, id = id, name = "Area " .. id, time = time }
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
        local saved = { schemaVersion = 4, lastTab = "zones", zones = { displayMode = "list", sort = "closest" },
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
        local saved = { schemaVersion = 3, debug = "yes", lastTab = "legacy", zones = "broken",
            window = { width = "wide", point = "MIDDLE" } }
        local account, _, fixes = SV.Load(saved, nil)
        t.eq(account.debug, false)
        t.eq(account.lastTab, "overview")
        t.eq(account.zones.displayMode, "cards")
        t.eq(account.window.width, 1160)
        t.eq(account.window.point, "CENTER")
        t.ok(has(fixes, "account debug: expected boolean"), "debug fix reported")
        t.ok(has(fixes, "lastTab: invalid value"), "enum fix reported")
        t.ok(has(fixes, "zones: expected table"), "table fix reported")
    end)

    t.test("out-of-range numbers are clamped, NaN reset", function()
        local _, SV = load()
        local nan = 0 / 0
        local account, _, fixes = SV.Load({ schemaVersion = 3, window = { width = 99999, height = 10, x = nan } }, nil)
        t.eq(account.window.width, 1800)
        t.eq(account.window.height, 640)
        t.eq(account.window.x, 0)
        t.ok(has(fixes, "clamped"))
    end)

    t.test("free-form containers keep their contents", function()
        local _, SV = load()
        local char = { schemaVersion = 1, milestones = { milestone(1), milestone(2) },
            baseline = { taken = true, exploration = { [1150] = true } } }
        local _, out = SV.Load(nil, char)
        t.eq(#out.milestones, 2)
        t.eq(out.baseline.taken, true)
        t.eq(out.baseline.exploration[1150], true)
    end)

    t.test("milestone history is trimmed to the newest entries", function()
        local _, SV, Config = load()
        local list = {}
        for i = 1, Config.LIMITS.milestones + 5 do list[i] = milestone(i) end
        local _, out = SV.Load(nil, { schemaVersion = 1, milestones = list })
        t.eq(#out.milestones, Config.LIMITS.milestones)
        t.eq(out.milestones[1].id, 6, "oldest dropped")
        t.eq(out.milestones[#out.milestones].id, Config.LIMITS.milestones + 5, "newest kept")
    end)

    t.test("damaged milestones and recent zones are cleaned entry by entry", function()
        local _, SV = load()
        local good = milestone(7, 1700000000)
        local _, out, fixes = SV.Load(nil, { schemaVersion = 1,
            milestones = { "junk", { kind = "area" }, { kind = "boss", category = "x", mapID = 1, id = 1 },
                good, { kind = "zone", category = "exploration", mapID = 1429, id = 1429, name = { "x" }, time = -5 },
                milestone(8, 0 / 0), milestone(9, 1e300) },
            recentZones = { 1429, "Elwynn", -3, 0 / 0, 1436, {} } })
        t.eq(#out.milestones, 4, "the four well-formed entries kept")
        t.ok(out.milestones[1] == good and good.time == 1700000000, "a valid time is kept")
        t.eq(out.milestones[2].name, nil, "a name that isn't text is dropped")
        t.eq(out.milestones[2].time, nil, "a negative time becomes 'not seen'")
        t.eq(out.milestones[3].time, nil, "NaN time dropped")
        t.eq(out.milestones[4].time, nil, "far-future time dropped")
        t.same(out.recentZones, { 1429, 1436 })
        t.ok(has(fixes, "milestones: 3 invalid entries dropped"))
        t.ok(has(fixes, "recentZones: 4 invalid entries dropped"))
        local _, out2 = SV.Load(nil, { schemaVersion = 1, milestones = "x", recentZones = 5 })
        t.same(out2.milestones, {}); t.same(out2.recentZones, {})
    end)

    t.test("data from a newer schema is discarded", function()
        local _, SV = load()
        local account, _, fixes = SV.Load({ schemaVersion = 99, lastTab = "zones" }, nil)
        t.eq(account.schemaVersion, 4)
        t.eq(account.lastTab, "overview")
        t.ok(has(fixes, "newer than supported"))
    end)

    t.test("schema 2 moves an untouched old window size to the design size", function()
        local _, SV = load()
        local account, _, fixes = SV.Load({ schemaVersion = 1,
            window = { width = 960, height = 640, x = 30, y = -20 } }, nil)
        t.eq(account.schemaVersion, 4)
        t.eq(account.window.width, 1160)
        t.eq(account.window.height, 740)
        t.eq(account.window.x, 30, "position kept")
        t.ok(has(fixes, "migrated to schema 2"))
    end)

    t.test("schema 2 keeps a window size the player chose", function()
        local _, SV = load()
        local account = SV.Load({ schemaVersion = 1, window = { width = 1300, height = 800 } }, nil)
        t.eq(account.window.width, 1300)
        t.eq(account.window.height, 800)
    end)

    t.test("schema 3 moves an untouched minimap angle off the crowded default", function()
        local _, SV = load()
        local account = SV.Load({ schemaVersion = 2, launcher = { minimapAngle = 200 } }, nil)
        t.eq(account.launcher.minimapAngle, 140)
        local kept = SV.Load({ schemaVersion = 2, launcher = { minimapAngle = 75 } }, nil)
        t.eq(kept.launcher.minimapAngle, 75, "a dragged angle is kept")
    end)

    t.test("schema 4 maps the old completion filter onto the status segments", function()
        local _, SV = load()
        local a = SV.Load({ schemaVersion = 3, zones = { completion = "completed", sort = "lowest" } }, nil)
        t.eq(a.zones.completion, "complete"); t.eq(a.zones.sort, "lowest", "other settings kept")
        local b = SV.Load({ schemaVersion = 3, zones = { completion = "incomplete" } }, nil)
        t.eq(b.zones.completion, "all", "no single segment for in progress + untouched")
        local c = SV.Load({ schemaVersion = 4, zones = { completion = "progress" } }, nil)
        t.eq(c.zones.completion, "progress", "a new value is valid")
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
