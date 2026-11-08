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

    t.test("/azfdiag zones records raw levels and map rects per zone", function()
        boot()
        _G.C_Map.GetMapLevels = function(id) if id == ELWYNN then return 1, 10, 1, 10 end end
        _G.C_Map.GetMapRectOnMap = function() return 0.4, 0.5, 0.7, 0.8 end
        _G.GetZonePVPInfo = function() return "friendly" end
        _G.SlashCmdList.AZERFOLIODIAG("zones")
        local z = _G.AzerfolioDiagDB.zoneMeta
        t.eq(z.count, 1, "one zone map in the fixture")
        local e = z.zones[ELWYNN]
        t.eq(e.name, "Elwynn Forest")
        t.eq(e.levels.n, 4); t.eq(e.levels[1], 1); t.eq(e.levels[2], 10)
        t.eq(e.rect[3], 0.7)
        t.eq(z.player.pvp[1], "friendly")
        t.eq(z.has.GetMapLevels, "function")
        t.eq(#_G.AzerfolioDiagDB.errors, 0)
    end)

    t.test("/azfdiag zones copes with a client without GetMapLevels", function()
        boot()
        _G.SlashCmdList.AZERFOLIODIAG("zones")
        local z = _G.AzerfolioDiagDB.zoneMeta
        t.eq(z.has.GetMapLevels, "nil")
        t.eq(z.zones[ELWYNN].levels[1], nil, "nothing recorded")
        t.eq(#_G.AzerfolioDiagDB.errors, 0)
    end)

    -- A tiny stand-in for QuestieDB's public API (contract 4): three quests, one corrected.
    local function fakeQuestieDB()
        local base = {
            [7] = { name = "Kobold Camp Cleanup", questLevel = 2, requiredLevel = 1, requiredRaces = 77, zoneOrSort = 12,
                    specialFlags = 0, exclusiveTo = { 8 }, startedBy = { { 197 } } },
            [8] = { name = "Repeat Me", questLevel = 5, requiredLevel = 4, zoneOrSort = 12, specialFlags = 1 },
            [9] = { name = "Warrior Training", questLevel = 10, requiredLevel = 10, requiredClasses = 1, zoneOrSort = -81 },
        }
        local corrected = { [7] = { requiredLevel = 2 } }
        local Q = {}
        local fields = { "name", "questLevel", "requiredLevel", "requiredMaxLevel", "requiredRaces", "requiredClasses",
            "zoneOrSort", "specialFlags", "questFlags", "nextQuestInChain", "breadcrumbForQuestId", "availableUntilCompleted",
            "parentQuest", "exclusiveTo", "preQuestSingle", "preQuestGroup", "requiredSkill", "requiredMinRep",
            "requiredMaxRep", "startedBy" }
        for _, f in ipairs(fields) do
            Q[f] = function(id)
                local c = corrected[id]
                if c and c[f] ~= nil then return c[f] end
                return base[id] and base[id][f]
            end
        end
        Q.GetRaw = function(id, f) return base[id] and base[id][f] end
        Q.GetAllIds = function(hashmap)
            if hashmap then return { [7] = true, [8] = true, [9] = true } end
            return { 7, 8, 9 }
        end
        return {
            Quest = Q, contractVersion = 4, minSupportedContract = 1, readMode = "baked",
            RequireContract = function(n) return n == 4, n ~= 4 and "mismatch" or nil end,
            flavor = { expansion = "Forever", rules = "Classic" },
            Enum = { factionRaceMasks = { Alliance = 77, Horde = 178 }, classKeys = { WARRIOR = 1 },
                     byExpansion = { Forever = { raceKeys = { HUMAN = 1, ALL_ALLIANCE = 77 } } } },
            Support = { Get = function(name)
                if name == "ZoneDB" then
                    return { private = { areaIdToUiMapId = "return { [12] = 1429 }", areaIdToUiMapIdOverride = "return { [0] = 0 }" } }
                end
            end },
        }
    end

    t.test("/azfdiag questdb records the API, read cost, corrections, masks and areas", function()
        boot()
        local tick = 0
        _G.debugprofilestop = function() tick = tick + 0.5; return tick end
        _G.LibQuestieDB = fakeQuestieDB()
        _G.C_CreatureInfo = { GetRaceInfo = function(i) if i == 1 then return { raceName = "Human", clientFileString = "Human", raceID = 1 } end end }
        _G.GetClassInfo = function(i) if i == 1 then return "Warrior", "WARRIOR", 1 end end
        _G.C_AddOns.GetAddOnMetadata = function(_, key) if key == "Version" then return "1.0.12" end end
        _G.C_QuestLog.GetAllCompletedQuestIDs = function() return { 7, 4242 } end

        _G.SlashCmdList.AZERFOLIODIAG("questdb")
        wow.runTimers()
        local r = _G.AzerfolioDiagDB.questdb
        t.eq(#_G.AzerfolioDiagDB.errors, 0)
        t.eq(r.usable, true)
        t.eq(r.version, "1.0.12")
        t.eq(r.contractVersion, 4); t.eq(r.require4[1], true)
        t.eq(r.idCount, 3)
        t.eq(#r.stages, 7, "every stage ran")
        t.eq(r.scalarPass.reads, 3 * 13); t.eq(r.scalarPass.errors, 0)
        t.ok(r.scalarPass.ms > 0, "scalar pass timed")
        t.eq(r.areas[12], 2); t.eq(r.sorts[-81], 1); t.eq(r.missingZone, 0)
        t.eq(r.repeatable, 1)
        t.eq(r.tablePass.present.exclusiveTo, 1)
        t.eq(r.compare.changed.requiredLevel, 1, "the correction is seen")
        t.eq(r.compare.samples[1].base, 1); t.eq(r.compare.samples[1].composed, 2)
        t.eq(r.areaTable.base, true)
        t.eq(r.areaMap[12].uiMap, 1429)
        t.eq(r.areaMap[12].mapName, "Elwynn Forest"); t.eq(r.areaMap[12].isZone, true)
        t.eq(r.completed.count, 2); t.eq(r.completed.known, 1); t.same(r.completed.missing, { 4242 })
        t.eq(r.clientRaces[1].file, "Human"); t.eq(r.clientClasses[1].file, "WARRIOR")
        t.eq(r.factionRaceMasks.Alliance, 77); t.eq(r.raceKeys.HUMAN, 1)
        t.eq(r.sampleArea, 12, "samples from the player's zone")
        t.eq(#r.samples, 2); t.eq(r.samples[1].name, "Kobold Camp Cleanup")
        _G.LibQuestieDB, _G.debugprofilestop, _G.C_CreatureInfo, _G.GetClassInfo = nil, nil, nil, nil
    end)

    t.test("/azfdiag questdb without QuestieDB records that and stops", function()
        boot()
        _G.LibQuestieDB = nil
        _G.SlashCmdList.AZERFOLIODIAG("questdb")
        wow.runTimers()
        local r = _G.AzerfolioDiagDB.questdb
        t.eq(r.usable, false)
        t.eq(r.has.LibQuestieDB, "nil")
        t.eq(#_G.AzerfolioDiagDB.errors, 0)
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

    t.test("gamepad probe records presses and stops itself", function()
        boot()
        _G.SlashCmdList.AZERFOLIODIAG("pad")
        local db = _G.AzerfolioDiagDB
        t.eq(db.pad.enableButton, true)
        t.eq(db.pad.env.frameMethods.EnableGamePadButton, "function")
        local f = _G.AzerfolioDiagPadFrame
        t.eq(f.gamePadButton, true, "pad input captured")
        f.scripts.OnGamePadButtonDown(f, "PADDUP")
        f.scripts.OnGamePadButtonUp(f, "PADDUP")
        f.scripts.OnGamePadStick(f, "Right", 0, 1, 1)
        wow.runTimers()
        t.eq(#db.pad.presses, 2)
        t.eq(db.pad.presses[1].key, "PADDUP")
        t.eq(#db.pad.sticks, 1)
        t.eq(db.pad.stoppedBy, "timeout")
        t.eq(f.gamePadButton, false, "pad input released")
        t.eq(#db.errors, 0)
    end)

    t.test("skin probe records the native frame tree, atlases and templates", function()
        boot()
        local function obj(kind, fields)
            local o = fields or {}
            o.GetObjectType = function() return kind end
            o.IsShown = function() return true end
            o.IsVisible = function() return true end
            o.GetSize = function() return 10, 20 end
            return o
        end
        local corner = obj("Texture", { GetAtlas = function() return "UI-Frame-Gold-Corner" end,
            GetDrawLayer = function() return "OVERLAY", 0 end })
        local title = obj("FontString", { GetText = function() return "Reputation" end,
            GetFont = function() return "Fonts\\FRIZQT__.TTF", 14, "" end })
        local nine = obj("Frame", { GetDebugName = function() return "CharacterFrame.NineSlice" end,
            GetRegions = function() return corner end, GetChildren = function() end })
        _G.CharacterFrame = obj("Frame", { GetDebugName = function() return "CharacterFrame" end,
            GetRegions = function() return title end, GetChildren = function() return nine end })
        local legend = obj("Frame", { GetDebugName = function() return "GamepadLegendFrame" end })
        _G.EnumerateFrames = function(prev) if prev == nil then return legend end end
        _G.C_Texture = { GetAtlasInfo = function(name)
            if name == "gamepad-largecursor-white" then return { file = 123, width = 32, height = 32 } end
        end }

        _G.SlashCmdList.AZERFOLIODIAG("skin")
        local sk = _G.AzerfolioDiagDB.skin
        t.ok(sk, "skin recorded")
        local root = sk.roots.CharacterFrame
        t.eq(root.regions[1].text, "Reputation")
        t.eq(root.children[1].regions[1].atlas, "UI-Frame-Gold-Corner")
        t.eq(sk.roots.ReputationFrame, "missing")
        t.eq(#sk.overlays, 1)
        t.eq(sk.atlases["gamepad-largecursor-white"].width, 32)
        t.eq(sk.atlases["UI-Frame-InnerTopLeft"], false)
        t.eq(#sk.templates, 4)
        t.ok(sk.templates[1].ok, "template frame created")
        t.ok(_G.AzerfolioDiagSkinFrame:IsShown(), "test frame shown")
        _G.SlashCmdList.AZERFOLIODIAG("skin")
        t.eq(_G.AzerfolioDiagSkinFrame:IsShown(), false, "second call hides it")
        t.eq(#_G.AzerfolioDiagDB.errors, 0)
        _G.CharacterFrame, _G.EnumerateFrames, _G.C_Texture = nil, nil, nil
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
