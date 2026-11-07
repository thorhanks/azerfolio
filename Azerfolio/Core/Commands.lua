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
    "/azf shot - take a test screenshot (development)",
    "/azf shots - screenshot every tab and state (development)",
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
    for i = math.max(1, #ns.Debug.errors - 2), #ns.Debug.errors do
        local e = ns.Debug.errors[i]
        ns.Printf("  error: %s: %s", e.label, e.err)
    end
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
            ns.Print("Debug output " .. (ns.db.debug and "on." or "off."))
        elseif sub == "zone" then
            debugZone()
        elseif sub == "exploration" or sub == "progress" then
            ns.Print("Not available yet: arrives with the progression engine (Phase 5).")
        else
            ns.Print("Unknown debug option. Type /azf help.")
        end
    elseif cmd == "shot" then
        shot()
    elseif cmd == "shots" then
        ns.UI.RunShots()
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
