-- Loads Azerfolio from its TOC against the mock client and walks through startup and commands.
local wow = require("mocks.wow")

local function client(overrides)
    local env = {
        UnitName = function() return "Gideon" end,
        GetRealmName = function() return "Test Realm" end,
        UnitRace = function() return "Human", "Human", 1 end,
        UnitClass = function() return "Paladin", "PALADIN", 2 end,
        UnitFactionGroup = function() return "Alliance", "Alliance" end,
        UnitLevel = function() return 9 end,
        GetMaxPlayerLevel = function() return 60 end,
        UnitXP = function() return 273 end,
        UnitXPMax = function() return 6500 end,
        GetZoneText = function() return "Elwynn Forest" end,
        GetSubZoneText = function() return "Goldshire" end,
        C_Map = {
            GetBestMapForUnit = function() return 1429 end,
            GetMapInfo = function(id)
                local maps = {
                    [1429] = { name = "Elwynn Forest", parentMapID = 1415 },
                    [1415] = { name = "Eastern Kingdoms", parentMapID = 947 },
                    [947] = { name = "Azeroth", parentMapID = 0 },
                }
                return maps[id]
            end,
        },
        Screenshot = function() _G.screenshotsTaken = (_G.screenshotsTaken or 0) + 1 end,
    }
    for k, v in pairs(overrides or {}) do env[k] = v end
    return env
end

local function boot(savedAccount, savedChar, overrides)
    wow.install(client(overrides))
    _G.AzerfolioDB, _G.AzerfolioCharDB = savedAccount, savedChar
    _G.screenshotsTaken = 0
    local ns = wow.loadToc("Azerfolio", "Azerfolio")
    wow.fire("ADDON_LOADED", "SomeOtherAddon")
    wow.fire("ADDON_LOADED", "Azerfolio")
    wow.fire("PLAYER_LOGIN")
    return ns
end

local function slash(input) _G.SlashCmdList.AZERFOLIO(input) end
local function lastChat() return wow.chat[#wow.chat] or "" end

return function(t)
    t.test("TOC metadata", function()
        local meta = wow.tocMetadata("Azerfolio", "Azerfolio")
        t.eq(meta.Interface, "16001")
        t.eq(meta.SavedVariables, "AzerfolioDB")
        t.eq(meta.SavedVariablesPerCharacter, "AzerfolioCharDB")
    end)

    t.test("loads every TOC file and starts up in order", function()
        local ns = boot()
        t.ok(ns.loaded, "SavedVariables loaded")
        t.ok(ns.ready, "ready after login")
        t.eq(_G.AzerfolioDB.schemaVersion, 4)
        t.eq(_G.AzerfolioCharDB.schemaVersion, 2)
        t.ok(ns.db == _G.AzerfolioDB, "ns.db is the saved table")
        t.eq(ns.character.name, "Gideon")
        t.eq(ns.character.classFile, "PALADIN")
        t.eq(ns.character.isMaxLevel, false)
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("generated art index loads", function()
        local ns = boot()
        t.eq(type(ns.Art), "table")
        t.eq(type(ns.Art.zones), "table")
        t.eq(type(ns.Art.hasFallback), "boolean")
    end)

    t.test("ignores other addons' ADDON_LOADED", function()
        wow.install(client())
        _G.AzerfolioDB, _G.AzerfolioCharDB = nil, nil
        local ns = wow.loadToc("Azerfolio", "Azerfolio")
        wow.fire("ADDON_LOADED", "SomeOtherAddon")
        t.eq(ns.loaded, false)
    end)

    t.test("saved settings persist through a reload", function()
        local ns = boot()
        ns.db.zones.displayMode = "list"
        ns.db.lastTab = "zones"
        local saved, savedChar = _G.AzerfolioDB, _G.AzerfolioCharDB
        local ns2 = boot(saved, savedChar)
        t.eq(ns2.db.zones.displayMode, "list")
        t.eq(ns2.db.lastTab, "zones")
    end)

    t.test("corrupt settings recover to defaults", function()
        local ns = boot({ schemaVersion = 1, window = "oops", lastTab = 5 }, "bad")
        t.eq(ns.db.window.width, 1160)
        t.eq(ns.db.lastTab, "overview")
        t.eq(type(ns.charDB.recentZones), "table")
        t.eq(ns.charDB.milestones, nil)
    end)

    t.test("both slash commands are registered", function()
        boot()
        t.eq(_G.SLASH_AZERFOLIO1, "/azerfolio")
        t.eq(_G.SLASH_AZERFOLIO2, "/azf")
        t.ok(_G.SlashCmdList.AZERFOLIO, "handler registered")
    end)

    t.test("/azf opens the window without errors", function()
        local ns = boot()
        slash("")
        t.ok(ns.UI.IsShown(), "window shown")
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("/azf debug toggles and persists", function()
        local ns = boot()
        t.eq(ns.db.debug, false, "off by default")
        slash("debug")
        t.eq(ns.db.debug, true)
        slash("DEBUG")
        t.eq(ns.db.debug, false, "case-insensitive")
    end)

    t.test("/azf debug zone prints the map chain", function()
        boot()
        slash("debug zone")
        local all = table.concat(wow.chat, "\n")
        t.ok(all:find("Elwynn Forest %(1429%) < Eastern Kingdoms %(1415%) < Azeroth %(947%)"), all)
    end)

    t.test("/azf refresh sends the refresh message", function()
        local ns = boot()
        local got = false
        ns.Events.On("AZF_REFRESH_REQUESTED", function() got = true end)
        slash("refresh")
        t.ok(got)
    end)

    t.test("/azf shot calls Screenshot", function()
        boot()
        slash("shot")
        t.eq(_G.screenshotsTaken, 1)
    end)

    t.test("/azf shot without Screenshot() says so", function()
        boot(nil, nil, { Screenshot = false })
        _G.Screenshot = nil
        slash("shot")
        t.ok(lastChat():find("not available"))
    end)

    t.test("a failing command is caught and reported", function()
        local ns = boot()
        ns.Commands.Handle = function() error("kaboom") end
        slash("status")
        t.ok(lastChat():find("Something went wrong"))
        t.eq(#ns.Debug.errors, 1)
    end)

    t.test("/azf debug quests reports the catalogue, and says why without QuestieDB", function()
        _G.LibQuestieDB = nil
        boot()
        slash("debug quests")
        t.ok(lastChat():find("unavailable %(QuestieDB is not loaded%)"), lastChat())

        local ids = { 1, 2, 3 }
        local rows = { [1] = { 12, 0 }, [2] = { 133, 0 }, [3] = { -284, 0 } }
        _G.LibQuestieDB = {
            RequireContract = function() return true end,
            Quest = {
                GetAllIds = function() return ids end,
                zoneOrSort = function(id) return rows[id][1] end,
                specialFlags = function(id) return rows[id][2] end,
            },
        }
        local ns = boot(nil, nil, { C_QuestLog = { GetAllCompletedQuestIDs = function() return { 1, 3 } end } })
        wow.runTimers()
        t.eq(ns.Quests.State().status, "ready")
        slash("debug quests")
        _G.LibQuestieDB = nil
        local all = table.concat(wow.chat, "\n")
        t.ok(all:find("Quests: 3 in QuestieDB, 1 in zone counts"), all)
        t.ok(all:find("dungeon 1"), all)
        t.ok(all:find("this zone %(1429%): 1 quests, 1/1 done"), all)
        t.ok(all:find("your completed quests by place: sort 1, zone 1"), all)
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("/azf debug perf gc collects garbage first", function()
        local ns = boot()
        slash("debug")
        slash("debug perf gc")
        t.ok(table.concat(wow.chat, "\n"):find("after a full garbage collection"), table.concat(wow.chat, "\n"))
        t.eq(#ns.Debug.errors, 0)
    end)

    t.test("level-up refreshes the character once per burst", function()
        local level = 9
        local ns = boot(nil, nil, { UnitLevel = function() return level end })
        local updates = 0
        ns.Events.On("AZF_CHARACTER_UPDATED", function() updates = updates + 1 end)
        level = 10
        wow.fire("PLAYER_LEVEL_UP", 10)
        wow.fire("PLAYER_XP_UPDATE", "player")
        wow.runTimers()
        t.eq(updates, 1)
        t.eq(ns.character.level, 10)
    end)
end
