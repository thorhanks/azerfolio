-- Slash commands: /azerfolio and /azf.
local _, ns = ...

local Commands = {}
ns.Commands = Commands

local HELP = {
    "/azf - open or close Azerfolio",
    "/azf refresh - re-read progress from the game",
    "/azf status - show version and state",
    "/azf debug - turn debug output on or off",
    "/azf debug zone - show the current map and zone",
    "/azf debug exploration - show the current zone's exploration and the total",
    "/azf debug zones - show the Zones catalogue's counts and filters",
    "/azf debug overview - show what the Overview picks and counts",
    "/azf debug quests - show the quest catalogue from QuestieDB (counts per zone, what's left out)",
    "/azf debug perf - event counts, timings and memory since debug was turned on (reset: start over)",
    "/azf shot - take a test screenshot (development)",
    "/azf shots - screenshot every tab and state (development)",
    "/azf shots banners - screenshot the zones with a banner offset (development)",
    "/azf minimap - show or hide the minimap button",
}

local function toggleWindow()
    if ns.UI and ns.UI.Toggle then
        ns.UI.Toggle()
    else
        ns.Print("The Azerfolio window isn't built yet. Type /azf help for commands.")
    end
end

local function debugZone()
    local Try = ns.Debug.Try
    local mapID = C_Map and Try("GetBestMapForUnit", C_Map.GetBestMapForUnit, "player")
    if not mapID then
        ns.Print("Current map: unknown")
        return
    end
    local chain, id, guard = {}, mapID, 0
    while id and id > 0 and guard < 10 do
        local info = Try("GetMapInfo", C_Map.GetMapInfo, id)
        if not info then break end
        chain[#chain + 1] = string.format("%s (%d)", tostring(info.name), id)
        id = info.parentMapID
        guard = guard + 1
    end
    ns.Printf("Map: %s", table.concat(chain, " < "))
    ns.Printf("Zone text: %s / %s", tostring(Try("GetZoneText", GetZoneText)), tostring(Try("GetSubZoneText", GetSubZoneText)))
end

local function status()
    local c = ns.character or {}
    ns.Printf("v%s, schema %s/%s, debug %s, errors this session: %d",
        ns.version,
        tostring(ns.db and ns.db.schemaVersion), tostring(ns.charDB and ns.charDB.schemaVersion),
        ns.Debug.IsEnabled() and "on" or "off", #ns.Debug.errors)
    ns.Printf("Character: %s, level %s %s %s (%s)", tostring(c.name), tostring(c.level),
        tostring(c.race), tostring(c.className), tostring(c.faction))
    if ns.Theme and ns.Theme.GlyphAtlas then
        local parts = {}
        for _, b in ipairs({ "A", "B", "X", "Y", "LB" }) do
            parts[#parts + 1] = b .. "=" .. tostring(ns.Theme.GlyphAtlas(b) or "drawn")
        end
        ns.Printf("Glyphs: %s", table.concat(parts, ", "))
    end
    for i = math.max(1, #ns.Debug.errors - 2), #ns.Debug.errors do
        local e = ns.Debug.errors[i]
        ns.Printf("  error: %s: %s", e.label, e.err)
    end
end

local function count(t)
    local n = 0
    if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end
    return n
end

-- What the addon keeps: SavedVariables list sizes, baseline size, tracker cache.
function Commands.Sizes()
    local db, char = ns.db or {}, ns.charDB or {}
    local base = type(char.baseline) == "table" and char.baseline.exploration or {}
    local areas = 0
    for _, z in pairs(base) do
        if type(z) == "table" then areas = areas + count(z.states) end
    end
    return {
        trace = count(db.trace), milestones = count(char.milestones), recentZones = count(char.recentZones),
        baselineZones = count(base), baselineAreas = areas,
        cachedZones = ns.Exploration and ns.Exploration.CacheSize and ns.Exploration.CacheSize() or 0,
        errors = #ns.Debug.errors,
    }
end

-- The client's own measurements, where it has them [unverified on Forever]: memory in KB,
-- and every C_AddOnProfiler metric the client's enum lists (no names guessed).
local function clientMetrics()
    local Try, out = ns.Debug.Try, {}
    if type(UpdateAddOnMemoryUsage) == "function" and type(GetAddOnMemoryUsage) == "function" then
        Try("UpdateAddOnMemoryUsage", UpdateAddOnMemoryUsage)
        out.memoryKB = Try("GetAddOnMemoryUsage", GetAddOnMemoryUsage, ns.name or "Azerfolio")
    end
    local P = C_AddOnProfiler
    local metrics = type(Enum) == "table" and Enum.AddOnProfilerMetric
    if type(P) == "table" and type(P.GetAddOnMetric) == "function" and type(metrics) == "table" then
        out.profilerEnabled = type(P.IsEnabled) == "function" and Try("C_AddOnProfiler.IsEnabled", P.IsEnabled) or nil
        out.profiler = {}
        for key, value in pairs(metrics) do
            local v = Try("C_AddOnProfiler.GetAddOnMetric", P.GetAddOnMetric, ns.name or "Azerfolio", value)
            if type(v) == "number" then out.profiler[key] = v end
        end
    end
    return out
end

local function ms(v) return string.format("%.2f", v or 0) end

-- /azf debug perf [reset]: event and callback counts since debug mode was turned on, memory,
-- and what the addon stores. In chat and in the trace.
local function debugPerf(sub)
    if sub == "reset" then
        ns.Events.ResetStats()
        ns.Print("Performance counters reset.")
        return
    end
    if not ns.Debug.IsEnabled() then
        ns.Print("Performance counters run only in debug mode. Type /azf debug first.")
        return
    end
    local since = ns.Events.statsSince
    local now = type(GetTime) == "function" and GetTime() or 0
    local list = ns.Events.StatsList()
    ns.Printf("Performance over %s s (%d callbacks counted):", since and string.format("%.0f", now - since) or "0", #list)
    local top = {}
    for i = 1, math.min(12, #list) do
        local s = list[i]
        ns.Printf("  %s: %d calls, %s ms total, %s ms max", s.name, s.count, ms(s.ms), ms(s.max))
        top[#top + 1] = { name = s.name, count = s.count, ms = math.floor(s.ms * 100 + 0.5) / 100,
            max = math.floor(s.max * 100 + 0.5) / 100 }
    end
    local m = clientMetrics()
    local sizes = Commands.Sizes()
    ns.Printf("  memory %s KB; trace %d, milestones %d, recent zones %d, baseline %d zones / %d areas, cache %d zones",
        m.memoryKB and string.format("%.0f", m.memoryKB) or "unknown", sizes.trace, sizes.milestones,
        sizes.recentZones, sizes.baselineZones, sizes.baselineAreas, sizes.cachedZones)
    ns.Debug.Trace("perf", { seconds = since and (now - since) or 0, top = top, memoryKB = m.memoryKB,
        profilerEnabled = m.profilerEnabled, profiler = m.profiler, sizes = sizes })
end

-- Takes one screenshot. Used to verify that addons may call Screenshot() on this client.
local function shot()
    if type(Screenshot) ~= "function" then
        ns.Print("Screenshot() is not available on this client.")
        return
    end
    local ok, err = pcall(Screenshot)
    if ok then
        ns.Print("Screenshot requested.")
    else
        ns.Print("Screenshot failed: " .. tostring(err))
        ns.Debug.Error("Screenshot", err)
    end
end

function Commands.Handle(input)
    if not ns.loaded then
        ns.Print("Still loading, try again in a moment.")
        return
    end
    local words = {}
    for w in tostring(input or ""):lower():gmatch("%S+") do words[#words + 1] = w end
    local cmd, sub = words[1], words[2]

    if cmd == nil then
        toggleWindow()
    elseif cmd == "help" then
        for _, line in ipairs(HELP) do ns.Print(line) end
    elseif cmd == "refresh" then
        ns.Events.Send("AZF_REFRESH_REQUESTED")
        ns.Print("Refreshing.")
    elseif cmd == "status" then
        status()
    elseif cmd == "debug" then
        if sub == nil then
            ns.db.debug = not ns.db.debug
            if ns.db.debug then ns.Events.ResetStats() end -- counters start when debug starts
            ns.Print("Debug output " .. (ns.db.debug and "on." or "off."))
        elseif sub == "zone" then
            debugZone()
        elseif sub == "exploration" or sub == "progress" then
            ns.Exploration.DebugReport()
        elseif sub == "zones" then
            ns.Zones.DebugReport()
        elseif sub == "overview" then
            ns.Overview.DebugReport()
        elseif sub == "quests" then
            ns.Quests.DebugReport()
        elseif sub == "perf" then
            debugPerf(words[3])
        else
            ns.Print("Unknown debug option. Type /azf help.")
        end
    elseif cmd == "shot" then
        shot()
    elseif cmd == "shots" then
        ns.UI.RunShots(sub)
    elseif cmd == "minimap" then
        local shown = ns.Launcher.ToggleMinimapButton()
        ns.Print(shown and "Minimap button shown." or "Minimap button hidden. Type /azf minimap to bring it back.")
    else
        ns.Print("Unknown command. Type /azf help.")
    end
end

SLASH_AZERFOLIO1 = "/azerfolio"
SLASH_AZERFOLIO2 = "/azf"
SlashCmdList.AZERFOLIO = function(input)
    local ok, err = pcall(Commands.Handle, input)
    if not ok then
        ns.Debug.Error("slash command", err)
        ns.Print("Something went wrong. Type /azf status for details.")
    end
end
