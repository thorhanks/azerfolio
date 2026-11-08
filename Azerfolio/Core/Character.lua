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
    c.race, c.raceFile, c.raceID = try("UnitRace", UnitRace, "player")
    c.className, c.classFile, c.classID = try("UnitClass", UnitClass, "player")
    c.faction, c.factionLocalized = try("UnitFactionGroup", UnitFactionGroup, "player")
    c.level = try("UnitLevel", UnitLevel, "player")
    c.maxLevel = try("GetMaxPlayerLevel", GetMaxPlayerLevel)
    c.xp = try("UnitXP", UnitXP, "player")
    c.xpMax = try("UnitXPMax", UnitXPMax, "player")
    c.isMaxLevel = type(c.level) == "number" and type(c.maxLevel) == "number" and c.level >= c.maxLevel
    return c
end

-- AZF_CHARACTER_UPDATED on every refresh (XP gains: the header's XP bar); AZF_LEVEL_CHANGED
-- only when the level changed, so pages that depend on the level alone (Overview picks, "Your
-- level") don't rebuild on every kill. (Phase 8 performance review.)
function Character.Refresh()
    local old = ns.character
    ns.character = Character.Read()
    ns.Events.Send("AZF_CHARACTER_UPDATED", ns.character)
    if old and old.level ~= ns.character.level then
        ns.Events.Send("AZF_LEVEL_CHANGED", ns.character.level)
    end
end
