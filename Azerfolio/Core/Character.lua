-- Reads the player's character details from the client.
local _, ns = ...

local Character = {}
ns.Character = Character

local function try(label, fn, ...) return ns.Debug.Try(label, fn, ...) end

-- Returns a fresh snapshot. Fields the client doesn't provide are nil.
function Character.Read()
    local c = {}
    c.name = try("UnitName", UnitName, "player")
    c.realm = try("GetRealmName", GetRealmName)
    c.race, c.raceFile = try("UnitRace", UnitRace, "player")
    c.className, c.classFile = try("UnitClass", UnitClass, "player")
    c.faction, c.factionLocalized = try("UnitFactionGroup", UnitFactionGroup, "player")
    c.level = try("UnitLevel", UnitLevel, "player")
    c.maxLevel = try("GetMaxPlayerLevel", GetMaxPlayerLevel)
    c.xp = try("UnitXP", UnitXP, "player")
    c.xpMax = try("UnitXPMax", UnitXPMax, "player")
    c.isMaxLevel = type(c.level) == "number" and type(c.maxLevel) == "number" and c.level >= c.maxLevel
    return c
end

function Character.Refresh()
    ns.character = Character.Read()
    ns.Events.Send("AZF_CHARACTER_UPDATED", ns.character)
end
