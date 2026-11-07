-- Loads AzerfolioDiag against the mock client and checks the main flows don't error.
local wow = require("mocks.wow")

local ELWYNN, EK, EXPLORE_ELWYNN, CAT = 1429, 1415, 776, 14777

local function fakeClient()
    local criteria = {
        { name = "Northshire Valley", done = true, asset = 9, id = 1001 },
        { name = "Goldshire", done = true, asset = 87, id = 1002 },
        { name = "Fargodeep Mine", done = false, asset = 57, id = 1003 },
    }
    local areas = { [9] = "Northshire Valley", [87] = "Goldshire", [57] = "Fargodeep Mine" }
    local maps = {
        [EK] = { mapID = EK, name = "Eastern Kingdoms", mapType = 2, parentMapID = 947 },
        [ELWYNN] = { mapID = ELWYNN, name = "Elwynn Forest", mapType = 3, parentMapID = EK },
    }
    local explored = { { textureWidth = 256, fileDataIDs = { 1, 2 } } }

    local env = {
        Enum = { UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3, Dungeon = 4 } },
        GetBuildInfo = function() return "1.60.1", "70862", "Nov 1 2026", 16001 end,
        GetLocale = function() return "enUS" end,
        UnitName = function() return "Tester" end,
        UnitRace = function() return "Human", "Human", 1 end,
        UnitClass = function() return "Warrior", "WARRIOR", 1 end,
        UnitFactionGroup = function() return "Alliance", "Alliance" end,
        UnitLevel = function() return 10 end,
        UnitXP = function() return 100 end,
        UnitXPMax = function() return 1000 end,
        GetRealmName = function() return "Test" end,
        GetZoneText = function() return "Elwynn Forest" end,
        GetRealZoneText = function() return "Elwynn Forest" end,
        GetSubZoneText = function() return "Goldshire" end,
        GetMinimapZoneText = function() return "Goldshire" end,
        C_Map = {
            GetBestMapForUnit = function() return ELWYNN end,
            GetMapInfo = function(id) return maps[id] end,
            GetMapArtID = function() return 1 end,
            GetMapGroupID = function() return nil end,
            GetPlayerMapPosition = function() return { x = 0.4, y = 0.6 } end,
            GetAreaInfo = function(id) return areas[id] end,
        },
        C_MapExplorationInfo = {
            GetExploredMapTextures = function(id) if id == ELWYNN then return explored end return {} end,
            GetExploredAreaIDsAtPosition = function() return { 87 } end,
        },
        C_QuestLog = {
            IsQuestFlaggedCompleted = function(id) return id == 783 end,
            GetAllCompletedQuestIDs = function() return { 783, 7 } end,
            GetTitleForQuestID = function() return "A Quest" end,
            GetNumQuestLogEntries = function() return 3 end,
        },
        GetCategoryList = function() return { CAT } end,
        GetCategoryInfo = function() return "Eastern Kingdoms", 97, 0 end,
        GetCategoryNumAchievements = function() return 1, 0 end,
        GetAchievementInfo = function(a, b)
            if b or a == EXPLORE_ELWYNN then
                return EXPLORE_ELWYNN, "Explore Elwynn Forest", 10, false, nil, nil, nil, "Explore Elwynn Forest", 0, 0, "", false, false, nil
            end
        end,
        GetAchievementNumCriteria = function() return #criteria end,
        GetAchievementCriteriaInfo = function(_, i)
            local c = criteria[i]
            return c.name, 0, c.done, 0, 0, "", 0, c.asset, "", c.id, true
        end,
        C_AddOns = {
            GetNumAddOns = function() return 1 end,
            GetAddOnInfo = function() return "AzerfolioDiag" end,
            IsAddOnLoaded = function() return true end,
        },
    }
    return env, criteria, explored
end

local function boot()
    local env, criteria, explored = fakeClient()
    wow.install(env)
    _G.AzerfolioDiagDB = nil
    wow.loadAddonFile("AzerfolioDiag/Diag.lua", "AzerfolioDiag")
    wow.fire("ADDON_LOADED", "AzerfolioDiag")
    wow.fire("PLAYER_ENTERING_WORLD", true, false)
    wow.runTimers()
    return criteria, explored
end

return function(t)
    t.test("loads and initializes SavedVariables", function()
        boot()
        local db = _G.AzerfolioDiagDB
        t.ok(db, "AzerfolioDiagDB created")
        t.eq(db.version, 1)
        t.ok(db.session and db.session.player == "Tester", "session recorded")
        t.ok(_G.SlashCmdList.AZERFOLIODIAG, "slash command registered")
    end)

    t.test("/azfdiag all dumps every section without errors", function()
        boot()
        _G.SlashCmdList.AZERFOLIODIAG("all")
        local db = _G.AzerfolioDiagDB
        t.eq(#db.errors, 0, "errors recorded")
        t.eq(db.env.build[4], 16001)
        t.eq(db.maps.count, 2)
        local a = db.achievements.explore[EXPLORE_ELWYNN]
        t.ok(a, "explore achievement captured")
        t.eq(#a.criteria, 3)
        t.eq(a.criteria[3].assetAreaName, "Fargodeep Mine")
        t.same(a.matchedMapIDs, { ELWYNN })
        t.eq(db.quests.allCompletedCount, 2)
        t.ok(db.zoneSnapshots[1].exploreAchievement, "zone snapshot found the achievement")
    end)

    t.test("discovering an area records a criteria diff", function()
        local criteria, explored = boot()
        criteria[3].done = true
        explored[2] = { textureWidth = 128, fileDataIDs = { 3 } }
        wow.fire("MAP_EXPLORATION_UPDATED")
        wow.fire("UI_INFO_MESSAGE", 372, "Discovered Fargodeep Mine")
        wow.runTimers()
        local diffs = _G.AzerfolioDiagDB.diffs
        t.eq(#diffs, 1, "one diff")
        t.eq(diffs[1].changes[1].name, "Fargodeep Mine")
        t.eq(diffs[1].changes[1].to, true)
        t.eq(diffs[1].textures.before, 1)
        t.eq(diffs[1].textures.after, 2)
        t.eq(#diffs[1].triggers, 2, "both triggering events kept")
    end)

    t.test("an unknown event name does not break loading", function()
        local env = fakeClient()
        wow.install(env)
        wow.unknownEvents.CRITERIA_COMPLETE = true
        _G.AzerfolioDiagDB = nil
        wow.loadAddonFile("AzerfolioDiag/Diag.lua", "AzerfolioDiag")
        wow.fire("ADDON_LOADED", "AzerfolioDiag")
        t.ok(_G.AzerfolioDiagDB.eventRegistration.CRITERIA_COMPLETE ~= true, "failure recorded")
        t.eq(_G.AzerfolioDiagDB.eventRegistration.MAP_EXPLORATION_UPDATED, true)
    end)
end
