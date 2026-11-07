-- Central configuration: defaults, allowed values, limits. Pure data; no WoW API use.
local _, ns = ...

local Config = {}
ns.Config = Config

Config.ACCOUNT_SCHEMA = 1
Config.CHAR_SCHEMA = 1

-- Account-wide settings (AzerfolioDB).
Config.ACCOUNT_DEFAULTS = {
    schemaVersion = Config.ACCOUNT_SCHEMA,
    debug = false,
    window = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0, width = 960, height = 640 },
    lastTab = "overview",
    zones = {
        displayMode = "cards",
        faction = "relevant",
        completion = "all",
        level = "all",
        sort = "recommended",
    },
    launcher = { minimapAngle = 200, minimapHidden = false },
    notifications = { enabled = true },
}

-- Per-character data (AzerfolioCharDB).
-- Empty tables in defaults are free-form containers: their contents are kept as-is.
Config.CHAR_DEFAULTS = {
    schemaVersion = Config.CHAR_SCHEMA,
    baseline = { taken = false, exploration = {} },
    milestones = {},
    recentZones = {},
}

-- Allowed values, by dotted path. Anything else resets to the default.
Config.ENUMS = {
    ["lastTab"] = { overview = true, zones = true },
    ["window.point"] = {
        CENTER = true, TOP = true, BOTTOM = true, LEFT = true, RIGHT = true,
        TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true,
    },
    ["zones.displayMode"] = { cards = true, list = true },
    ["zones.faction"] = { relevant = true, all = true },
    ["zones.completion"] = { all = true, incomplete = true, completed = true },
    ["zones.level"] = { all = true, appropriate = true },
    ["zones.sort"] = { recommended = true, alphabetical = true, highest = true, lowest = true, closest = true },
}
Config.ENUMS["window.relativePoint"] = Config.ENUMS["window.point"]

-- Numeric ranges, by dotted path. Out-of-range values are clamped.
Config.RANGES = {
    ["window.width"] = { 800, 1400 },
    ["window.height"] = { 560, 1000 },
    ["window.x"] = { -4000, 4000 },
    ["window.y"] = { -4000, 4000 },
    ["launcher.minimapAngle"] = { 0, 360 },
}

Config.LIMITS = {
    milestones = 100,  -- newest kept
    recentZones = 10,
    errors = 50,       -- in-memory error log
}
