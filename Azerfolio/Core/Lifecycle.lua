-- Startup sequence. Loaded last, after every module is defined.
--   1. Files load (modules defined, no game state read).
--   2. ADDON_LOADED: load, migrate and validate SavedVariables.
--   3. PLAYER_LOGIN: read the character, then announce AZF_READY.
--   Data providers and UI (later phases) initialize on AZF_READY; the UI is built lazily on first open.
local ADDON_NAME, ns = ...

local Events = ns.Events

local function onAddonLoaded(name)
    if name ~= ADDON_NAME then return end
    local account, char, fixes = ns.SavedVariables.Load(AzerfolioDB, AzerfolioCharDB)
    AzerfolioDB, AzerfolioCharDB = account, char
    ns.db, ns.charDB = account, char
    ns.loaded = true
    for _, fix in ipairs(fixes) do ns.Debug.Print("settings: %s", fix) end
    Events.Unregister("ADDON_LOADED", onAddonLoaded)
end

local function onPlayerLogin()
    ns.Character.Refresh()
    ns.ready = true
    ns.Debug.Print("ready: %s level %s", tostring(ns.character.name), tostring(ns.character.level))
    Events.Send("AZF_READY")
end

local function onCharacterChanged()
    Events.Debounce("character", 0.5, ns.Character.Refresh)
end

Events.Register("ADDON_LOADED", onAddonLoaded)
Events.Register("PLAYER_LOGIN", onPlayerLogin)
Events.Register("PLAYER_LEVEL_UP", onCharacterChanged)
Events.Register("PLAYER_XP_UPDATE", onCharacterChanged)
