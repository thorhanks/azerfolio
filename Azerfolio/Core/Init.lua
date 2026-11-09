-- Azerfolio namespace. Every file receives (addonName, ns) from the client; modules hang off ns.
local ADDON_NAME, ns = ...

ns.name = ADDON_NAME
ns.version = "1.2.0"

ns.db = nil       -- account-wide SavedVariables (AzerfolioDB), set on ADDON_LOADED
ns.charDB = nil   -- per-character SavedVariables (AzerfolioCharDB), set on ADDON_LOADED
ns.character = nil -- latest character snapshot (Character.lua)
ns.loaded = false  -- SavedVariables ready
ns.ready = false   -- player logged in, character known

local PREFIX = "|cffd4af37Azerfolio|r "

function ns.Print(text)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(text))
end

function ns.Printf(fmt, ...)
    ns.Print(string.format(fmt, ...))
end
