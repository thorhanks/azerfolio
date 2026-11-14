-- Central configuration: defaults, allowed values, limits. Pure data; no WoW API use.
local _, ns = ...

local Config = {}
ns.Config = Config

Config.ACCOUNT_SCHEMA = 4
Config.CHAR_SCHEMA = 3

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
        showUnavailable = false, -- Zone Detail, Quests page: show quests you can't do
    },
    reputation = { filter = "all", sort = "group" }, -- Reputation tab toolbar (Phase 12)
    -- 140 = top-left of the minimap; other addons' buttons sat at about 206 and 228 on the
    -- owner's client (WoWScrnShot_110726_181323).
    launcher = { minimapAngle = 140, minimapHidden = false },
    notifications = { enabled = true },
    trace = {}, -- debug mode only (Debug.Trace); capped at LIMITS.trace
}

-- Per-character data (AzerfolioCharDB).
-- Empty tables in defaults are free-form containers: their contents are kept as-is.
Config.CHAR_DEFAULTS = {
    schemaVersion = Config.CHAR_SCHEMA,
    recentZones = {},
    -- Flight masters' lists, by continent mapID: { time, nodes = { [name] = "known"|"distant" } }
    -- (Systems/FlightPaths.lua). Free-form; checked by SavedVariables.CleanFlights.
    flights = {},
    -- Your class trainer's list, read whenever you open it (Systems/ClassTrainer.lua):
    -- { time, class, services = { { name, rank, kind = used|available|unavailable, level, icon, cost } } }.
    -- Free-form; checked by SavedVariables.CleanTrainer.
    trainer = {},
    -- Professions (Systems/Professions.lua): each profession window's recipe list and the
    -- profession trainers' services, by skill line:
    -- { windows = { [line] = { time, rows = { { id, name, learned, grey, category, item } }, categories = { [id] = name } } },
    --   trainers = { [line] = { time, services = { [name] = { kind, skill, cost } } } } }.
    -- Free-form; checked by SavedVariables.CleanProfessions.
    professions = {},
}

-- Allowed values, by dotted path. Anything else resets to the default.
Config.ENUMS = {
    ["lastTab"] = { overview = true, zones = true, reputation = true, class = true, professions = true },
    ["reputation.filter"] = { all = true, met = true, unmet = true },
    ["reputation.sort"] = { group = true, closest = true, name = true },
    ["window.point"] = {
        CENTER = true, TOP = true, BOTTOM = true, LEFT = true, RIGHT = true,
        TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true,
    },
    ["zones.displayMode"] = { cards = true, list = true, atlas = true },
    ["zones.faction"] = { relevant = true, all = true },
    -- The design's status segments (mockups/DESIGN.md): All / In progress / Untouched / Complete.
    ["zones.completion"] = { all = true, progress = true, untouched = true, complete = true },
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
    recentZones = 10,
    errors = 50,       -- in-memory error log
    trace = 100,       -- debug trace in AzerfolioDB
}
