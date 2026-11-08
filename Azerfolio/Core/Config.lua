-- Central configuration: defaults, allowed values, limits. Pure data; no WoW API use.
local _, ns = ...

local Config = {}
ns.Config = Config

Config.ACCOUNT_SCHEMA = 3
Config.CHAR_SCHEMA = 1

-- Account-wide settings (AzerfolioDB).
-- Window size is in UIParent units. 1160x740 is the size the approved design is laid out at
-- (mockups/DESIGN.md); about 1640 wide turns Zones into the split view (later step).
Config.ACCOUNT_DEFAULTS = {
    schemaVersion = Config.ACCOUNT_SCHEMA,
    debug = false,
    window = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0, width = 1160, height = 740 },
    lastTab = "overview",
    zones = {
        displayMode = "cards",
        faction = "relevant",
        completion = "all",
        level = "all",
        sort = "recommended",
    },
    -- 140 = top-left of the minimap; other addons' buttons sat at about 206 and 228 on the
    -- owner's client (WoWScrnShot_110726_181323).
    launcher = { minimapAngle = 140, minimapHidden = false },
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
    ["window.width"] = { 1000, 1800 },
    ["window.height"] = { 640, 1100 },
    ["window.x"] = { -4000, 4000 },
    ["window.y"] = { -4000, 4000 },
    ["launcher.minimapAngle"] = { 0, 360 },
}

Config.LIMITS = {
    milestones = 100,  -- newest kept
    recentZones = 10,
    errors = 50,       -- in-memory error log
}
