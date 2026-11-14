-- AzerfolioDiag: development-only diagnostics for Azerfolio.
-- Dumps client capabilities and exploration behavior into AzerfolioDiagDB (SavedVariables),
-- which the agent reads from disk after the player types /reload.
-- Everything is pcall-guarded: a missing or changed API is recorded, never fatal.

local ADDON_NAME = ...
local DB_VERSION = 1
local MAX_LOG, MAX_DIFFS, MAX_SNAPSHOTS, MAX_ERRORS = 600, 200, 25, 200
local MAX_STR = 300

local DB -- AzerfolioDiagDB, set on ADDON_LOADED

local function msg(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cffd4af37AzerfolioDiag|r " .. tostring(text))
end

---------------------------------------------------------------------------
-- Safety helpers
---------------------------------------------------------------------------

local function recordError(label, err)
    if not DB then return end
    DB.errors = DB.errors or {}
    local e = DB.errors
    e[#e + 1] = { t = time(), label = tostring(label), err = tostring(err) }
    while #e > MAX_ERRORS do table.remove(e, 1) end
end

local function packn(...) return { n = select("#", ...), ... } end

-- Calls fn(...) under pcall. Returns fn's results, or nil if fn is missing or errors.
local function try(label, fn, ...)
    if type(fn) ~= "function" then return nil end
    local r = packn(pcall(fn, ...))
    if not r[1] then
        recordError(label, r[2])
        return nil
    end
    return unpack(r, 2, r.n)
end

-- Converts any value into something SavedVariables can store.
local function plain(v, depth)
    depth = depth or 0
    local t = type(v)
    if t == "table" then
        if depth > 6 then return "<deep>" end
        local o = {}
        for k, x in pairs(v) do
            local kt = type(k)
            if kt == "string" or kt == "number" then o[k] = plain(x, depth + 1) end
        end
        return o
    elseif t == "string" then
        if #v > MAX_STR then return v:sub(1, MAX_STR) .. "..." end
        return v
    elseif t == "number" or t == "boolean" or t == "nil" then
        return v
    end
    return "<" .. t .. ">"
end

local function safePlain(v)
    local ok, r = pcall(plain, v)
    if ok then return r end
    return "<unreadable>"
end

local function packArgs(...)
    local out = { n = select("#", ...) }
    for i = 1, out.n do out[i] = safePlain((select(i, ...))) end
    return out
end

local function push(list, item, cap)
    list[#list + 1] = item
    while #list > cap do table.remove(list, 1) end
end

---------------------------------------------------------------------------
-- Current location
---------------------------------------------------------------------------

local function currentMapID()
    return C_Map and try("GetBestMapForUnit", C_Map.GetBestMapForUnit, "player")
end

local function where()
    local mapID = currentMapID()
    local w = {
        map = mapID,
        zone = try("GetZoneText", GetZoneText),
        realZone = try("GetRealZoneText", GetRealZoneText),
        subzone = try("GetSubZoneText", GetSubZoneText),
        minimapZone = try("GetMinimapZoneText", GetMinimapZoneText),
    }
    if mapID and C_Map then
        local pos = try("GetPlayerMapPosition", C_Map.GetPlayerMapPosition, mapID, "player")
        if pos then
            local x, y = pos.x, pos.y
            if pos.GetXY then x, y = try("pos:GetXY", pos.GetXY, pos) end
            w.x, w.y = x, y
            if C_MapExplorationInfo and C_MapExplorationInfo.GetExploredAreaIDsAtPosition then
                local ids = try("GetExploredAreaIDsAtPosition", C_MapExplorationInfo.GetExploredAreaIDsAtPosition, mapID, pos)
                if ids then
                    w.areas = {}
                    for _, id in ipairs(ids) do
                        w.areas[#w.areas + 1] = { id = id, name = try("GetAreaInfo", C_Map.GetAreaInfo, id) }
                    end
                end
            end
        end
    end
    return w
end

---------------------------------------------------------------------------
-- Environment
---------------------------------------------------------------------------

local LEGACY_GLOBALS = {
    "GetBuildInfo", "GetQuestsCompleted", "IsQuestFlaggedCompleted", "GetCategoryList", "GetCategoryInfo",
    "GetCategoryNumAchievements", "GetAchievementInfo", "GetAchievementNumCriteria", "GetAchievementCriteriaInfo",
    "GetAchievementCriteriaInfoByID", "GetStatisticsCategoryList", "GetMapOverlayInfo", "GetNumMapOverlays",
    "UnitXP", "UnitXPMax", "GetMaxPlayerLevel", "GetExpansionLevel", "SetPortraitTexture", "SetPortraitToTexture",
    "CreateFrame", "C_Timer", "Mixin", "CreateFromMixins", "CreateDataProvider", "CreateScrollBoxListLinearView",
    "CreateScrollBoxListGridView", "ScrollUtil", "UISpecialFrames", "AddonCompartmentFrame", "Settings",
    "EncounterJournal", "EncounterJournal_LoadUI", "AchievementFrame", "AchievementFrame_LoadUI",
    "WorldMapFrame", "OpenWorldMap", "ToggleWorldMap", "LibStub", "Enum", "Constants",
    "MAX_PLAYER_LEVEL", "ERR_ZONE_EXPLORED", "ERR_ZONE_EXPLORED_XP", "WOW_PROJECT_ID",
}

local TEMPLATES = {
    "BackdropTemplate", "ButtonFrameTemplate", "PortraitFrameTemplate", "DefaultPanelTemplate",
    "BasicFrameTemplate", "BasicFrameTemplateWithInset", "InsetFrameTemplate", "UIPanelButtonTemplate",
    "UIPanelCloseButton", "UIPanelScrollFrameTemplate", "ScrollFrameTemplate", "WowScrollBoxList",
    "WowScrollBox", "MinimalScrollBar", "SearchBoxTemplate", "InputBoxTemplate", "UICheckButtonTemplate",
    "UIDropDownMenuTemplate", "WowStyle1DropdownTemplate", "WowStyle1FilterDropdownTemplate",
    "PanelTabButtonTemplate", "CharacterFrameTabButtonTemplate", "TooltipBackdropTemplate",
    "SharedTooltipTemplate", "GameTooltipTemplate", "UIMenuButtonStretchTemplate",
}

local CANDIDATE_EVENTS = {
    "MAP_EXPLORATION_UPDATED", "UI_INFO_MESSAGE", "CRITERIA_UPDATE", "CRITERIA_EARNED", "CRITERIA_COMPLETE",
    "ACHIEVEMENT_EARNED", "TRACKED_ACHIEVEMENT_UPDATE", "RECEIVED_ACHIEVEMENT_LIST",
    "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "NEW_WMO_CHUNK",
    "PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP", "PLAYER_XP_UPDATE",
    "QUEST_TURNED_IN", "QUEST_REMOVED", "QUEST_ACCEPTED", "QUEST_LOG_UPDATE", "QUEST_DATA_LOAD_RESULT",
    "AREA_POIS_UPDATED", "ADDON_LOADED", "TAXIMAP_OPENED", "TAXIMAP_CLOSED", "PLAYER_INTERACTION_MANAGER_FRAME_SHOW",
    "UPDATE_FACTION", "CHAT_MSG_COMBAT_FACTION_CHANGE", "QUEST_LOG_CRITERIA_UPDATE",
}

local function dumpEnv()
    local e = { t = time() }
    e.build = packArgs(try("GetBuildInfo", GetBuildInfo))
    e.lua = _VERSION
    e.locale = try("GetLocale", GetLocale)
    e.projectID = WOW_PROJECT_ID
    e.projectConstants = {}
    e.namespaces = {}
    e.matchingGlobals = {}
    for k, v in pairs(_G) do
        if type(k) == "string" then
            if k:match("^WOW_PROJECT_") then e.projectConstants[k] = safePlain(v) end
            if k:match("^C_") and type(v) == "table" then
                local fns = {}
                for fk, fv in pairs(v) do
                    if type(fv) == "function" then fns[#fns + 1] = fk end
                end
                table.sort(fns)
                e.namespaces[k] = fns
            end
            local lk = k:lower()
            if lk:find("legacy", 1, true) or lk:find("forever", 1, true) or lk:find("explor", 1, true) then
                e.matchingGlobals[k] = type(v)
            end
        end
    end
    e.globals = {}
    for _, name in ipairs(LEGACY_GLOBALS) do e.globals[name] = type(_G[name]) end
    if Enum and Enum.UIMapType then e.uiMapType = safePlain(Enum.UIMapType) end

    e.templates = {}
    for _, tpl in ipairs(TEMPLATES) do
        local result = false
        for _, frameType in ipairs({ "Frame", "Button", "ScrollFrame", "EditBox", "CheckButton" }) do
            local ok, f = pcall(CreateFrame, frameType, nil, nil, tpl)
            if ok and f then
                f:Hide()
                result = frameType
                break
            end
        end
        e.templates[tpl] = result
    end

    e.player = {
        name = try("UnitName", UnitName, "player"),
        realm = try("GetRealmName", GetRealmName),
        race = packArgs(try("UnitRace", UnitRace, "player")),
        class = packArgs(try("UnitClass", UnitClass, "player")),
        faction = packArgs(try("UnitFactionGroup", UnitFactionGroup, "player")),
        level = try("UnitLevel", UnitLevel, "player"),
        xp = try("UnitXP", UnitXP, "player"),
        xpMax = try("UnitXPMax", UnitXPMax, "player"),
        maxLevel = try("GetMaxPlayerLevel", GetMaxPlayerLevel) or MAX_PLAYER_LEVEL,
    }

    e.addons = {}
    local numAddons = (C_AddOns and try("GetNumAddOns", C_AddOns.GetNumAddOns)) or try("GetNumAddOns", GetNumAddOns) or 0
    for i = 1, numAddons do
        local name = (C_AddOns and try("GetAddOnInfo", C_AddOns.GetAddOnInfo, i)) or try("GetAddOnInfo", GetAddOnInfo, i)
        local loaded = (C_AddOns and try("IsAddOnLoaded", C_AddOns.IsAddOnLoaded, i)) or try("IsAddOnLoaded", IsAddOnLoaded, i)
        if name then e.addons[#e.addons + 1] = { name = name, loaded = loaded and true or false } end
    end

    e.eventRegistration = DB.eventRegistration
    DB.env = e
end

---------------------------------------------------------------------------
-- Maps
---------------------------------------------------------------------------

local function dumpMaps()
    if not (C_Map and C_Map.GetMapInfo) then DB.maps = { missing = true }; return end
    local zoneType = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
    local maps = {}
    local count = 0
    for id = 1, 3000 do
        local info = try("GetMapInfo", C_Map.GetMapInfo, id)
        if info and info.mapID then
            local m = {
                id = id, name = info.name, mapType = info.mapType, parent = info.parentMapID, flags = info.flags,
                artID = try("GetMapArtID", C_Map.GetMapArtID, id),
                groupID = try("GetMapGroupID", C_Map.GetMapGroupID, id),
            }
            if C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures then
                local tex = try("GetExploredMapTextures", C_MapExplorationInfo.GetExploredMapTextures, id)
                if type(tex) == "table" then
                    m.exploredTextureCount = #tex
                    if info.mapType == zoneType then m.exploredTextures = safePlain(tex) end
                end
            end
            maps[id] = m
            count = count + 1
        end
    end
    DB.maps = { t = time(), count = count, byID = maps }
end

---------------------------------------------------------------------------
-- Achievements
---------------------------------------------------------------------------

local function criteriaOf(achID)
    local list = {}
    local n = try("GetAchievementNumCriteria", GetAchievementNumCriteria, achID) or 0
    for i = 1, n do
        local cs, ctype, done, qty, reqQty, charName, flags, assetID, qtyString, criteriaID, eligible =
            try("GetAchievementCriteriaInfo", GetAchievementCriteriaInfo, achID, i)
        local c = {
            index = i, name = cs, type = ctype, done = done and true or false, qty = qty, reqQty = reqQty,
            charName = charName, flags = flags, assetID = assetID, qtyString = qtyString,
            criteriaID = criteriaID, eligible = eligible,
        }
        if type(assetID) == "number" and assetID > 0 and C_Map and C_Map.GetAreaInfo then
            c.assetAreaName = try("GetAreaInfo(asset)", C_Map.GetAreaInfo, assetID)
        end
        list[i] = c
    end
    return list
end

local function achievementRecord(achID, catID)
    local id, name, points, done, month, day, year, desc, flags, icon, reward, isGuild, byMe, earnedBy =
        try("GetAchievementInfo", GetAchievementInfo, achID)
    return {
        id = id or achID, name = name, category = catID, points = points, done = done and true or false,
        date = done and month and string.format("%d-%02d-%02d", (year or 0) + 2000, month, day or 0) or nil,
        desc = desc, flags = flags, icon = icon, reward = reward, earnedByMe = byMe, earnedBy = earnedBy,
        criteria = criteriaOf(achID),
    }
end

local function isExploreAchievement(name, catName)
    if type(name) ~= "string" then return false end
    if name:match("^Explore ") then return true end
    return type(catName) == "string" and catName:find("Exploration", 1, true) ~= nil
end

-- Rebuilds the list of exploration achievement IDs. Returns the full dump when wantAll.
local function scanAchievements(wantAll)
    if not GetCategoryList then return nil end
    local out = { t = time(), categories = {}, explore = {}, all = wantAll and {} or nil }
    local exploreIDs = {}
    for _, cat in ipairs(try("GetCategoryList", GetCategoryList) or {}) do
        local catName, parent, catFlags = try("GetCategoryInfo", GetCategoryInfo, cat)
        local parentName = type(parent) == "number" and parent > 0 and try("GetCategoryInfo", GetCategoryInfo, parent) or nil
        local total, completed = try("GetCategoryNumAchievements", GetCategoryNumAchievements, cat, true)
        out.categories[#out.categories + 1] = {
            id = cat, name = catName, parent = parent, parentName = parentName, flags = catFlags,
            total = total, completed = completed,
        }
        for i = 1, (total or 0) do
            local id, name, _, done = try("GetAchievementInfo", GetAchievementInfo, cat, i)
            if id then
                if wantAll then out.all[#out.all + 1] = { id = id, name = name, cat = cat, done = done and true or false } end
                if isExploreAchievement(name, catName) or isExploreAchievement(name, parentName) then
                    exploreIDs[#exploreIDs + 1] = id
                    if wantAll then out.explore[id] = achievementRecord(id, cat) end
                end
            end
        end
    end
    DB.exploreIDs = exploreIDs
    return out
end

-- Matches "Explore <name>" achievements to map IDs by name (Phase 1 will verify this).
local function matchExploreToMaps()
    if not (DB.achievements and DB.maps and DB.maps.byID) then return end
    local byName = {}
    for id, m in pairs(DB.maps.byID) do
        if m.name then
            byName[m.name] = byName[m.name] or {}
            table.insert(byName[m.name], id)
        end
    end
    for _, a in pairs(DB.achievements.explore) do
        local zone = type(a.name) == "string" and a.name:match("^Explore (.+)$")
        a.matchedMapIDs = zone and byName[zone] or nil
    end
end

---------------------------------------------------------------------------
-- Exploration change tracking (diffs)
---------------------------------------------------------------------------

local exploreState = nil   -- ["achID:index"] = done
local textureCounts = {}   -- [mapID] = explored texture count
local pendingTriggers = {}
local scanScheduled = false

local function snapshotExplore()
    local state = {}
    for _, achID in ipairs(DB.exploreIDs or {}) do
        local n = try("GetAchievementNumCriteria", GetAchievementNumCriteria, achID) or 0
        for i = 1, n do
            local _, _, done = try("GetAchievementCriteriaInfo", GetAchievementCriteriaInfo, achID, i)
            state[achID .. ":" .. i] = done and true or false
        end
    end
    return state
end

local function textureCount(mapID)
    if not (mapID and C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures) then return nil end
    local tex = try("GetExploredMapTextures", C_MapExplorationInfo.GetExploredMapTextures, mapID)
    return type(tex) == "table" and #tex or nil
end

local function rescan()
    scanScheduled = false
    if not DB.exploreIDs then scanAchievements(false) end
    local triggers = pendingTriggers
    pendingTriggers = {}

    local newState = snapshotExplore()
    local mapID = currentMapID()
    local newCount = textureCount(mapID)
    local oldCount = mapID and textureCounts[mapID]
    if mapID then textureCounts[mapID] = newCount end

    if not exploreState then
        exploreState = newState
        return
    end

    local changes = {}
    for key, done in pairs(newState) do
        if exploreState[key] ~= nil and exploreState[key] ~= done then
            local achID, idx = key:match("^(%d+):(%d+)$")
            achID, idx = tonumber(achID), tonumber(idx)
            local cs, _, _, _, _, _, _, assetID, _, criteriaID = try("GetAchievementCriteriaInfo", GetAchievementCriteriaInfo, achID, idx)
            local _, achName = try("GetAchievementInfo", GetAchievementInfo, achID)
            changes[#changes + 1] = {
                ach = achID, achName = achName, index = idx, name = cs, assetID = assetID,
                criteriaID = criteriaID, from = exploreState[key], to = done,
            }
        end
    end
    exploreState = newState

    local textureChanged = oldCount ~= nil and newCount ~= nil and oldCount ~= newCount
    if #changes > 0 or textureChanged then
        push(DB.diffs, {
            t = time(), gt = GetTime(), where = where(), triggers = triggers, changes = changes,
            textures = { map = mapID, before = oldCount, after = newCount },
        }, MAX_DIFFS)
        msg(string.format("exploration change recorded: %d criteria, textures %s -> %s",
            #changes, tostring(oldCount), tostring(newCount)))
    end
end

local function scheduleRescan(event)
    pendingTriggers[#pendingTriggers + 1] = { e = event, gt = GetTime() }
    if scanScheduled then return end
    scanScheduled = true
    C_Timer.After(1, rescan)
end

---------------------------------------------------------------------------
-- Quests
---------------------------------------------------------------------------

-- A few early Elwynn Forest quests (IDs from Classic data; verify in game).
local SAMPLE_QUESTS = { 783, 7, 33, 5261, 15, 18, 3903 }

local function dumpQuests()
    local q = { t = time(), has = {} }
    q.has["C_QuestLog.IsQuestFlaggedCompleted"] = C_QuestLog and type(C_QuestLog.IsQuestFlaggedCompleted) == "function" or false
    q.has["C_QuestLog.GetAllCompletedQuestIDs"] = C_QuestLog and type(C_QuestLog.GetAllCompletedQuestIDs) == "function" or false
    q.has["GetQuestsCompleted"] = type(GetQuestsCompleted) == "function"
    q.has["IsQuestFlaggedCompleted"] = type(IsQuestFlaggedCompleted) == "function"

    local ids = C_QuestLog and try("GetAllCompletedQuestIDs", C_QuestLog.GetAllCompletedQuestIDs)
    if type(ids) == "table" then
        q.allCompletedCount = #ids
        table.sort(ids)
        q.allCompletedSample = {}
        for i = 1, math.min(#ids, 100) do q.allCompletedSample[i] = ids[i] end
    end
    local legacy = try("GetQuestsCompleted", GetQuestsCompleted)
    if type(legacy) == "table" then
        local n = 0
        for _ in pairs(legacy) do n = n + 1 end
        q.legacyCompletedCount = n
    end
    q.samples = {}
    for _, id in ipairs(SAMPLE_QUESTS) do
        local done = C_QuestLog and try("IsQuestFlaggedCompleted", C_QuestLog.IsQuestFlaggedCompleted, id)
        local title = C_QuestLog and try("GetTitleForQuestID", C_QuestLog.GetTitleForQuestID, id)
        q.samples[#q.samples + 1] = { id = id, done = done, title = title }
    end
    q.logEntries = C_QuestLog and try("GetNumQuestLogEntries", C_QuestLog.GetNumQuestLogEntries)
    DB.quests = q
end

---------------------------------------------------------------------------
-- QuestieDB probe (Azerfolio Phase 9): is QuestieDB's public API usable, what does a full read
-- of the quest fields Azerfolio needs cost, do its corrections change those fields, which race
-- and class masks does it use, and how do its quest areas map to the client's zone maps?
-- Read-only: it never invalidates QuestieDB's cache or registers corrections. Runs in stages,
-- one per frame, so no single frame does all the work. Records counts and small samples only.
---------------------------------------------------------------------------

local QDB_SCALARS = { "name", "questLevel", "requiredLevel", "requiredMaxLevel", "requiredRaces",
    "requiredClasses", "zoneOrSort", "specialFlags", "questFlags", "nextQuestInChain",
    "breadcrumbForQuestId", "availableUntilCompleted", "parentQuest" }
local QDB_TABLES = { "exclusiveTo", "preQuestSingle", "preQuestGroup", "requiredSkill",
    "requiredMinRep", "requiredMaxRep", "startedBy" }
local QDB_COMPARE = { "zoneOrSort", "specialFlags", "requiredRaces", "requiredClasses", "questLevel",
    "requiredLevel", "requiredMaxLevel", "name" }
local QDB_SAMPLE_DIFFS, QDB_SAMPLE_QUESTS, QDB_SAMPLE_MISSING = 30, 8, 30

local function clock()
    if type(debugprofilestop) == "function" then return debugprofilestop(), "debugprofilestop" end
    return (GetTime and GetTime() or 0) * 1000, "GetTime"
end

local function luaKB()
    local ok, kb = pcall(collectgarbage, "count")
    return ok and kb or nil
end

local function addonKB(name)
    local update = (C_AddOns and C_AddOns.UpdateAddOnMemoryUsage) or UpdateAddOnMemoryUsage
    local get = (C_AddOns and C_AddOns.GetAddOnMemoryUsage) or GetAddOnMemoryUsage
    if type(update) ~= "function" or type(get) ~= "function" then return nil end
    try("UpdateAddOnMemoryUsage", update)
    return try("GetAddOnMemoryUsage", get, name)
end

local function metadata(name, key)
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return try("GetAddOnMetadata", get, name, key)
end

-- Runs a QuestDB field reader over every ID, timed. Returns ms, read count, error count.
local function timedPass(Q, ids, fields, onValue)
    local start = clock()
    local reads, errs = 0, 0
    for i = 1, #ids do
        local id = ids[i]
        for f = 1, #fields do
            local reader = Q[fields[f]]
            local ok, v = pcall(reader, id)
            if ok then
                reads = reads + 1
                if onValue then onValue(id, fields[f], v) end
            else
                errs = errs + 1
                if errs <= 5 then recordError("questdb:" .. fields[f], v) end
            end
        end
    end
    return clock() - start, reads, errs
end

local function scalarOrType(v)
    local t = type(v)
    if t == "number" or t == "string" or t == "boolean" or t == "nil" then return safePlain(v) end
    return "<" .. t .. ">"
end

local questdbRunning = false

local function probeQuestDB()
    if questdbRunning then msg("questdb probe already running"); return end
    local r = { t = time(), stages = {} }
    DB.questdb = r
    local lib = rawget(_G, "LibQuestieDB")
    r.loaded = C_AddOns and try("IsAddOnLoaded", C_AddOns.IsAddOnLoaded, "QuestieDB")
    r.questieLoaded = C_AddOns and try("IsAddOnLoaded", C_AddOns.IsAddOnLoaded, "Questie")
    r.version = metadata("QuestieDB", "Version")
    r.flavorMeta = metadata("QuestieDB", "X-Flavor")
    r.modeMeta = metadata("QuestieDB", "X-Mode")
    r.has = {
        LibQuestieDB = type(lib), QuestDB = type(rawget(_G, "QuestDB")),
        C_EncodingUtil = type(rawget(_G, "C_EncodingUtil")), debugprofilestop = type(debugprofilestop),
        RequireContract = lib and type(lib.RequireContract) or "nil",
    }
    local Q = lib and lib.Quest
    if type(Q) ~= "table" or type(Q.GetAllIds) ~= "function" then
        r.usable = false
        msg("questdb: LibQuestieDB.Quest not available (is QuestieDB enabled?). Type /reload to save.")
        return
    end
    r.contractVersion, r.minSupportedContract, r.readMode = lib.contractVersion, lib.minSupportedContract, lib.readMode
    r.require4 = packArgs(try("RequireContract", lib.RequireContract, 4))
    r.flavor = safePlain(lib.flavor)

    -- Player and the client's race and class tables, to read the masks against.
    local _, _, raceID = UnitRace("player")
    local _, _, classID = UnitClass("player")
    r.player = { raceID = raceID, classID = classID, faction = (UnitFactionGroup("player")),
        level = UnitLevel("player"), map = currentMapID() }
    r.clientRaces, r.clientClasses = {}, {}
    if C_CreatureInfo and C_CreatureInfo.GetRaceInfo then
        for i = 1, 40 do
            local info = try("GetRaceInfo", C_CreatureInfo.GetRaceInfo, i)
            if type(info) == "table" then
                r.clientRaces[i] = { name = info.raceName, file = info.clientFileString, id = info.raceID }
            end
        end
    end
    if GetClassInfo then
        for i = 1, 20 do
            local name, file, id = try("GetClassInfo", GetClassInfo, i)
            if name then r.clientClasses[i] = { name = name, file = file, id = id } end
        end
    end
    local enum = lib.Enum or {}
    r.factionRaceMasks = safePlain(enum.factionRaceMasks)
    r.classKeys = safePlain(enum.classKeys)
    local exp = lib.flavor and lib.flavor.expansion
    r.raceKeys = safePlain(exp and enum.byExpansion and enum.byExpansion[exp] and enum.byExpansion[exp].raceKeys)

    local ids
    local stages = {
        { "ids", function()
            local t0 = clock()
            ids = Q.GetAllIds()
            r.idsMs = clock() - t0
            r.idCount = type(ids) == "table" and #ids or nil
            if type(ids) ~= "table" then error("GetAllIds returned " .. type(ids)) end
            r.memBefore = { lua = luaKB(), questiedb = addonKB("QuestieDB") }
        end },
        { "scalars", function()
            local areas, sorts, missingZone, repeatable = {}, {}, 0, 0
            local ms, reads, errs = timedPass(Q, ids, QDB_SCALARS, function(_, field, v)
                if field == "zoneOrSort" then
                    if type(v) == "number" and v > 0 then
                        areas[v] = (areas[v] or 0) + 1
                    elseif type(v) == "number" and v < 0 then
                        sorts[v] = (sorts[v] or 0) + 1
                    else
                        missingZone = missingZone + 1
                    end
                elseif field == "specialFlags" and type(v) == "number" and v % 2 == 1 then
                    repeatable = repeatable + 1
                end
            end)
            r.scalarPass = { ms = ms, reads = reads, errors = errs, fields = #QDB_SCALARS, clock = select(2, clock()) }
            r.areas, r.sorts, r.missingZone, r.repeatable = areas, sorts, missingZone, repeatable
            r.memAfterScalars = { lua = luaKB(), questiedb = addonKB("QuestieDB") }
        end },
        { "scalars again", function()
            local ms, reads, errs = timedPass(Q, ids, QDB_SCALARS)
            r.scalarPassCached = { ms = ms, reads = reads, errors = errs }
        end },
        { "tables", function()
            local present = {}
            local ms, reads, errs = timedPass(Q, ids, QDB_TABLES, function(_, field, v)
                if type(v) == "table" then present[field] = (present[field] or 0) + 1 end
            end)
            r.tablePass = { ms = ms, reads = reads, errors = errs, fields = #QDB_TABLES, present = present }
            r.memAfterTables = { lua = luaKB(), questiedb = addonKB("QuestieDB") }
        end },
        { "compare", function()
            -- Composed (corrected) value vs base data, for the fields Azerfolio would count with.
            if type(Q.GetRaw) ~= "function" then r.compare = { missing = true }; return end
            local cmp = { changed = {}, samples = {} }
            local t0 = clock()
            for i = 1, #ids do
                local id = ids[i]
                for _, field in ipairs(QDB_COMPARE) do
                    local okA, a = pcall(Q[field], id)
                    local okB, b = pcall(Q.GetRaw, id, field)
                    if okA and okB and type(a) ~= "table" and a ~= b then
                        cmp.changed[field] = (cmp.changed[field] or 0) + 1
                        if #cmp.samples < QDB_SAMPLE_DIFFS then
                            cmp.samples[#cmp.samples + 1] = { id = id, field = field,
                                composed = scalarOrType(a), base = scalarOrType(b) }
                        end
                    end
                end
            end
            cmp.ms = clock() - t0
            r.compare = cmp
        end },
        { "areas", function()
            -- QuestieDB's area -> uiMap table (private support data) for the quest areas, checked
            -- against the client's own names.
            local zoneDB = lib.Support and lib.Support.Get and lib.Support.Get("ZoneDB")
            local private = zoneDB and zoneDB.private
            local function load(src)
                if type(src) ~= "string" then return nil end
                local chunk = loadstring(src)
                if not chunk then return nil end
                setfenv(chunk, {})
                local ok, t = pcall(chunk)
                return ok and type(t) == "table" and t or nil
            end
            local base = load(private and private.areaIdToUiMapId)
            local over = load(private and private.areaIdToUiMapIdOverride)
            r.areaTable = { base = base ~= nil, override = over ~= nil }
            local zoneType = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
            r.areaMap = {}
            for area, n in pairs(r.areas or {}) do
                local ui = (over and over[area]) or (base and base[area])
                local e = { quests = n, uiMap = ui,
                    areaName = C_Map and try("GetAreaInfo", C_Map.GetAreaInfo, area) }
                if ui and ui > 0 and C_Map then
                    local info = try("GetMapInfo", C_Map.GetMapInfo, ui)
                    if info then e.mapName, e.mapType, e.parent = info.name, info.mapType, info.parentMapID end
                    e.isZone = info and info.mapType == zoneType or false
                end
                r.areaMap[area] = e
            end
        end },
        { "completed", function()
            local done = C_QuestLog and try("GetAllCompletedQuestIDs", C_QuestLog.GetAllCompletedQuestIDs)
            local c = { count = type(done) == "table" and #done or nil, known = 0, missing = {} }
            if type(done) == "table" then
                local known = Q.GetAllIds(true)
                for _, id in ipairs(done) do
                    if type(known) == "table" and known[id] then
                        c.known = c.known + 1
                    elseif #c.missing < QDB_SAMPLE_MISSING then
                        c.missing[#c.missing + 1] = id
                    end
                end
            end
            r.completed = c
            -- A few full records from the player's current zone, to see real shapes.
            r.samples = {}
            local here = r.player.map
            for area, e in pairs(r.areaMap or {}) do
                if e.uiMap and e.uiMap == here then r.sampleArea = area end
            end
            if r.sampleArea then
                for i = 1, #ids do
                    if #r.samples >= QDB_SAMPLE_QUESTS then break end
                    local okZ, z = pcall(Q.zoneOrSort, ids[i])
                    if okZ and z == r.sampleArea then
                        local rec = { id = ids[i] }
                        for _, f in ipairs(QDB_SCALARS) do rec[f] = scalarOrType((select(2, pcall(Q[f], ids[i])))) end
                        for _, f in ipairs(QDB_TABLES) do rec[f] = safePlain((select(2, pcall(Q[f], ids[i])))) end
                        r.samples[#r.samples + 1] = rec
                    end
                end
            end
        end },
    }

    questdbRunning = true
    local i = 0
    local function step()
        i = i + 1
        local s = stages[i]
        if not s then
            questdbRunning = false
            r.usable = true
            msg(string.format("questdb: %s quests, scalar pass %.1f ms (cached %.1f ms), table pass %.1f ms, %d errors. Type /reload to save.",
                tostring(r.idCount), r.scalarPass and r.scalarPass.ms or -1, r.scalarPassCached and r.scalarPassCached.ms or -1,
                r.tablePass and r.tablePass.ms or -1, #DB.errors))
            return
        end
        local ok, err = pcall(s[2])
        r.stages[#r.stages + 1] = { name = s[1], ok = ok, err = not ok and tostring(err) or nil }
        if not ok then
            recordError("questdb:" .. s[1], err)
            questdbRunning = false
            msg("questdb probe stopped at '" .. s[1] .. "': " .. tostring(err))
            return
        end
        C_Timer.After(0.05, step)
    end
    msg("questdb probe running (a few seconds)...")
    C_Timer.After(0, step)
end

---------------------------------------------------------------------------
-- Current-zone snapshot
---------------------------------------------------------------------------

local function dumpZone()
    local mapID = currentMapID()
    local s = { t = time(), where = where() }
    if mapID and C_Map then
        local chain, id, guard = {}, mapID, 0
        while id and id > 0 and guard < 10 do
            local info = try("GetMapInfo", C_Map.GetMapInfo, id)
            if not info then break end
            chain[#chain + 1] = { id = id, name = info.name, mapType = info.mapType }
            id = info.parentMapID
            guard = guard + 1
        end
        s.mapChain = chain
        if C_MapExplorationInfo then
            s.exploredTextures = safePlain(try("GetExploredMapTextures", C_MapExplorationInfo.GetExploredMapTextures, mapID))
        end
        local zoneName = chain[1] and chain[1].name
        if zoneName and GetCategoryList then
            if not DB.exploreIDs then scanAchievements(false) end
            for _, achID in ipairs(DB.exploreIDs or {}) do
                local _, name = try("GetAchievementInfo", GetAchievementInfo, achID)
                if name == ("Explore " .. zoneName) then s.exploreAchievement = achievementRecord(achID) end
            end
        end
    end
    push(DB.zoneSnapshots, s, MAX_SNAPSHOTS)
    local a = s.exploreAchievement
    if a then
        local done = 0
        for _, c in ipairs(a.criteria) do if c.done then done = done + 1 end end
        msg(string.format("zone snapshot: map %s, '%s' %d/%d", tostring(mapID), a.name, done, #a.criteria))
    else
        msg(string.format("zone snapshot: map %s, no matching Explore achievement", tostring(mapID)))
    end
end

---------------------------------------------------------------------------
-- Zone metadata probe (Azerfolio Phase 6): does the client give level ranges, faction or
-- map positions for each zone? Records raw returns only; the agent judges them.
---------------------------------------------------------------------------

local function dumpZoneMeta()
    if not (C_Map and C_Map.GetMapInfo) then DB.zoneMeta = { missing = true }; return end
    local zoneType = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
    local z = {
        t = time(),
        player = {
            level = try("UnitLevel", UnitLevel, "player"),
            faction = packArgs(try("UnitFactionGroup", UnitFactionGroup, "player")),
            map = currentMapID(),
            pvp = packArgs(try("GetZonePVPInfo", GetZonePVPInfo)),
        },
        has = {
            GetMapLevels = type(C_Map.GetMapLevels),
            GetMapRectOnMap = type(C_Map.GetMapRectOnMap),
            GetZonePVPInfo = type(GetZonePVPInfo),
            OpenWorldMap = type(C_Map.OpenWorldMap),
        },
        zones = {},
    }
    local count = 0
    for id = 1, 3000 do
        local info = try("GetMapInfo", C_Map.GetMapInfo, id)
        if info and info.mapType == zoneType then
            local parent = info.parentMapID
            z.zones[id] = {
                name = info.name, parent = parent, flags = info.flags,
                levels = packArgs(try("GetMapLevels", C_Map.GetMapLevels, id)),
                rect = parent and packArgs(try("GetMapRectOnMap", C_Map.GetMapRectOnMap, id, parent)) or nil,
                -- Where the zone sits on the world map (Azeroth, 947): the Atlas places zones
                -- that belong to no continent (Zephras Isle) this way (Phase 10).
                world = packArgs(try("GetMapRectOnMap", C_Map.GetMapRectOnMap, id, 947)),
            }
            count = count + 1
        end
    end
    -- The continents on the world map, to line the islands up with them.
    z.continents = {}
    for _, id in ipairs({ 1414, 1415 }) do
        z.continents[id] = packArgs(try("GetMapRectOnMap", C_Map.GetMapRectOnMap, id, 947))
    end
    z.count = count
    DB.zoneMeta = z
    msg(string.format("zone metadata: %d zones. Type /reload to save.", count))
end

---------------------------------------------------------------------------
-- Flight paths (/azfdiag taxi; also recorded automatically at a flight master)
-- Question: can the client say which flight paths this character knows, per zone, without
-- the flight map open? Candidates: C_TaxiMap.GetTaxiNodesForMap (fields such as state or
-- atlas name), C_TaxiMap.GetAllTaxiNodes, and the classic flight-master API (NumTaxiNodes,
-- TaxiNodeName, TaxiNodeGetType "CURRENT"/"REACHABLE"/"DISTANT"/"NONE"), only while open.
---------------------------------------------------------------------------

local function taxiMasterNodes()
    local n = try("NumTaxiNodes", NumTaxiNodes)
    if type(n) ~= "number" or n <= 0 then return { count = n } end
    local nodes = {}
    for i = 1, math.min(n, 200) do
        nodes[i] = {
            name = try("TaxiNodeName", TaxiNodeName, i),
            type = try("TaxiNodeGetType", TaxiNodeGetType, i),
            pos = packArgs(try("TaxiNodePosition", TaxiNodePosition, i)),
        }
    end
    return { count = n, nodes = nodes }
end

local function dumpTaxi(reason)
    local T = C_TaxiMap
    local r = {
        t = time(), reason = reason, map = currentMapID(),
        faction = packArgs(try("UnitFactionGroup", UnitFactionGroup, "player")),
        has = {
            GetTaxiNodesForMap = T and type(T.GetTaxiNodesForMap) or "no C_TaxiMap",
            GetAllTaxiNodes = T and type(T.GetAllTaxiNodes) or "no C_TaxiMap",
            ShouldMapShowTaxiNodes = T and type(T.ShouldMapShowTaxiNodes) or "no C_TaxiMap",
            NumTaxiNodes = type(NumTaxiNodes), TaxiNodeGetType = type(TaxiNodeGetType),
            TaxiNodeName = type(TaxiNodeName), FlightPathState = Enum and Enum.FlightPathState and safePlain(Enum.FlightPathState) or "none",
        },
        zones = {}, all = {},
    }
    if T and C_Map and C_Map.GetMapInfo then
        local zoneType = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
        local zones, nodes = 0, 0
        for id = 1, 3000 do
            local info = try("GetMapInfo", C_Map.GetMapInfo, id)
            if info and (info.mapType == zoneType or info.mapType == 2) then
                local list = try("GetTaxiNodesForMap", T.GetTaxiNodesForMap, id)
                if type(list) == "table" and #list > 0 then
                    r.zones[id] = { name = info.name, mapType = info.mapType,
                        show = try("ShouldMapShowTaxiNodes", T.ShouldMapShowTaxiNodes, id), nodes = safePlain(list) }
                    zones, nodes = zones + 1, nodes + #list
                end
            end
        end
        r.zoneCount, r.nodeCount = zones, nodes
        for _, id in ipairs({ 1414, 1415, 947, currentMapID() or 0 }) do
            local list = try("GetAllTaxiNodes", T.GetAllTaxiNodes, id)
            if type(list) == "table" then r.all[id] = { count = #list, nodes = safePlain(list) } end
        end
    end
    r.master = taxiMasterNodes()
    DB.taxi = DB.taxi or {}
    DB.taxi[reason == "TAXIMAP_OPENED" and "master" or "probe"] = r
    msg(string.format("flight paths (%s): %d zones with nodes, %d nodes; flight master list %s. Type /reload to save.",
        tostring(reason), r.zoneCount or 0, r.nodeCount or 0, tostring(r.master.count)))
end

---------------------------------------------------------------------------
-- Reputation probe (/azfdiag reps): which faction APIs exist, the full faction list
-- (collapsed headers are expanded to read them, then collapsed again), lookups by ID for
-- factions that quests in our zones reward (tools/qdb.lua reps), standing labels.
---------------------------------------------------------------------------

-- Faction IDs from quest reputation rewards [verified-files, offline QuestieDB survey 2026-11-08].
local REP_PROBE_IDS = {
    21, 47, 54, 59, 67, 68, 69, 72, 76, 81, 87, 92, 93, 169, 270, 349, 369, 469, 470, 471, 509, 510,
    529, 530, 576, 577, 589, 609, 729, 730, 749, 809, 889, 890, 909, 910,
    2586, 2587, 2719, 2740, 2747, 2758, 2765, 2778, 2779, 2782, 2787, 2798, 2799, 2819, 2826, 2827,
}

local function dumpReps()
    local R = C_Reputation
    local r = { t = time(), map = currentMapID(), has = {}, list = {}, cList = {}, byID = {}, cByID = {}, labels = {} }
    for _, name in ipairs({ "GetNumFactions", "GetFactionInfo", "GetFactionInfoByID", "ExpandFactionHeader",
        "CollapseFactionHeader", "ExpandAllFactionHeaders", "IsFactionInactive", "GetWatchedFactionInfo",
        "SetWatchedFactionIndex", "GetFriendshipReputation" }) do
        r.has[name] = type(_G[name])
    end
    if R then
        for k, v in pairs(R) do r.has["C_Reputation." .. k] = type(v) end
    else
        r.has.C_Reputation = "nil"
    end
    r.has.C_GossipInfo_GetFriendshipReputation = C_GossipInfo and type(C_GossipInfo.GetFriendshipReputation) or "nil"
    r.has.ReputationFrame = type(_G.ReputationFrame)
    for i = 0, 9 do r.labels[i] = _G["FACTION_STANDING_LABEL" .. i] end

    -- Expand collapsed headers bottom-up (indices above don't shift), remembering them by name.
    local expanded = {}
    if GetNumFactions and GetFactionInfo and ExpandFactionHeader then
        r.countBefore = try("GetNumFactions", GetNumFactions)
        for i = (r.countBefore or 0), 1, -1 do
            local v = packArgs(try("GetFactionInfo", GetFactionInfo, i))
            -- classic returns: name, description, standingID, barMin, barMax, barValue, atWarWith,
            -- canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID, ...
            if v[9] and v[10] then
                expanded[#expanded + 1] = v[1]
                try("ExpandFactionHeader", ExpandFactionHeader, i)
            end
        end
        r.expandedHeaders = expanded
        r.count = try("GetNumFactions", GetNumFactions)
        for i = 1, math.min(r.count or 0, 400) do
            r.list[i] = packArgs(try("GetFactionInfo", GetFactionInfo, i))
            if IsFactionInactive then r.list[i].inactive = try("IsFactionInactive", IsFactionInactive, i) end
        end
    end
    if R and R.GetNumFactions and R.GetFactionDataByIndex then
        r.cCount = try("C_Reputation.GetNumFactions", R.GetNumFactions)
        for i = 1, math.min(r.cCount or 0, 400) do
            r.cList[i] = safePlain(try("C_Reputation.GetFactionDataByIndex", R.GetFactionDataByIndex, i))
        end
    end
    -- Collapse what we expanded, bottom-up again, matching by name.
    if #expanded > 0 and CollapseFactionHeader then
        local want = {}
        for _, n in ipairs(expanded) do want[n] = true end
        for i = (try("GetNumFactions", GetNumFactions) or 0), 1, -1 do
            local v = packArgs(try("GetFactionInfo", GetFactionInfo, i))
            if v[9] and want[v[1]] and not v[10] then try("CollapseFactionHeader", CollapseFactionHeader, i) end
        end
        r.countAfter = try("GetNumFactions", GetNumFactions)
    end

    for _, id in ipairs(REP_PROBE_IDS) do
        if GetFactionInfoByID then r.byID[id] = packArgs(try("GetFactionInfoByID", GetFactionInfoByID, id)) end
        if R and R.GetFactionDataByID then r.cByID[id] = safePlain(try("C_Reputation.GetFactionDataByID", R.GetFactionDataByID, id)) end
    end
    r.watched = packArgs(GetWatchedFactionInfo and try("GetWatchedFactionInfo", GetWatchedFactionInfo))
    DB.reps = r
    msg(string.format("reputation: %s factions listed (%d headers expanded and restored; %s before, %s after), %d IDs looked up. Type /reload to save.",
        tostring(r.count), #expanded, tostring(r.countBefore), tostring(r.countAfter or r.count), #REP_PROBE_IDS))
end

---------------------------------------------------------------------------
-- Spell probe (/azfdiag spells; Class tab abilities, docs/research/class-spells.md): which spell
-- and spellbook APIs exist, every spellbook item with its type (does the client list spells you
-- haven't learned yet, as the modern spellbook does?) and the level it's learned at, and the
-- trainer's list when a class trainer's window is open.
---------------------------------------------------------------------------

local function dumpSpells()
    local SB, SP = C_SpellBook, C_Spell
    local r = { t = time(), level = UnitLevel and UnitLevel("player"), class = UnitClass and select(2, UnitClass("player")),
        has = {}, enum = {}, lines = {}, items = {}, byType = {}, trainer = nil }
    for _, name in ipairs({ "IsSpellKnown", "IsPlayerSpell", "IsSpellKnownOrOverridesKnown", "GetSpellInfo",
        "GetSpellBookItemInfo", "GetSpellBookItemName", "GetNumSpellTabs", "GetSpellTabInfo", "GetSpellLevelLearned",
        "GetNumTrainerServices", "GetTrainerServiceInfo", "GetTrainerServiceLevelReq", "GetTrainerServiceSkillLine",
        "GetTrainerServiceCost", "GetTrainerServiceIcon", "GetTrainerServiceDescription", "SetTrainerServiceTypeFilter",
        "GetTrainerServiceTypeFilter", "IsTradeskillTrainer" }) do
        r.has[name] = type(_G[name])
    end
    for label, tbl in pairs({ C_SpellBook = SB, C_Spell = SP, C_ClassTrainer = rawget(_G, "C_ClassTrainer") }) do
        if type(tbl) == "table" then for k, v in pairs(tbl) do r.has[label .. "." .. k] = type(v) end
        else r.has[label] = "nil" end
    end
    if Enum then
        for _, e in ipairs({ "SpellBookItemType", "SpellBookSpellBank", "SpellBookSkillLineIndex" }) do
            if type(Enum[e]) == "table" then r.enum[e] = safePlain(Enum[e]) end
        end
    end
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    if SB and SB.GetNumSpellBookSkillLines and SB.GetSpellBookSkillLineInfo and SB.GetSpellBookItemInfo then
        local n = try("C_SpellBook.GetNumSpellBookSkillLines", SB.GetNumSpellBookSkillLines) or 0
        for l = 1, n do
            local line = try("C_SpellBook.GetSpellBookSkillLineInfo", SB.GetSpellBookSkillLineInfo, l)
            r.lines[l] = safePlain(line)
            if type(line) == "table" then
                for i = (line.itemIndexOffset or 0) + 1, (line.itemIndexOffset or 0) + (line.numSpellBookItems or 0) do
                    if #r.items >= 400 then break end
                    local it = try("C_SpellBook.GetSpellBookItemInfo", SB.GetSpellBookItemInfo, i, bank)
                    local rec = safePlain(it) or {}
                    if type(rec) ~= "table" then rec = { value = rec } end
                    rec.index, rec.line = i, l
                    if SB.GetSpellBookItemLevelLearned then
                        rec.levelLearned = try("C_SpellBook.GetSpellBookItemLevelLearned", SB.GetSpellBookItemLevelLearned, i, bank)
                    end
                    local sid = type(it) == "table" and it.spellID
                    if sid and SP and SP.GetSpellLevelLearned then
                        rec.spellLevelLearned = try("C_Spell.GetSpellLevelLearned", SP.GetSpellLevelLearned, sid)
                    end
                    if sid and IsSpellKnown then rec.known = try("IsSpellKnown", IsSpellKnown, sid) end
                    if sid and IsPlayerSpell then rec.playerSpell = try("IsPlayerSpell", IsPlayerSpell, sid) end
                    r.items[#r.items + 1] = rec
                    local ty = tostring(type(it) == "table" and it.itemType)
                    r.byType[ty] = (r.byType[ty] or 0) + 1
                end
            end
        end
    end
    -- The spells each level grants (the modern C_SpellBook.GetCurrentLevelSpells(level)), with
    -- their names, ranks and the level the client says they're learned at (probe v2).
    if SB and SB.GetCurrentLevelSpells then
        r.levelSpells = {}
        for lv = 1, 60 do
            local ids = try("C_SpellBook.GetCurrentLevelSpells", SB.GetCurrentLevelSpells, lv)
            local list = {}
            if type(ids) == "table" then
                for _, id in ipairs(ids) do
                    local e = { id = id }
                    if SP and SP.GetSpellName then e.name = try("C_Spell.GetSpellName", SP.GetSpellName, id) end
                    if SP and SP.GetSpellSubtext then e.sub = try("C_Spell.GetSpellSubtext", SP.GetSpellSubtext, id) end
                    if SP and SP.GetSpellLevelLearned then e.learnedAt = try("C_Spell.GetSpellLevelLearned", SP.GetSpellLevelLearned, id) end
                    if IsSpellKnown then e.known = try("IsSpellKnown", IsSpellKnown, id) end
                    list[#list + 1] = e
                end
            end
            r.levelSpells[lv] = { type = type(ids), list = list }
        end
    end
    -- The trainer's list, when its window is open: with every filter on (available, unavailable,
    -- used), then the filters put back as they were.
    if GetNumTrainerServices then
        local filters, saved = { "available", "unavailable", "used" }, {}
        if GetTrainerServiceTypeFilter and SetTrainerServiceTypeFilter then
            for _, f in ipairs(filters) do
                saved[f] = try("GetTrainerServiceTypeFilter", GetTrainerServiceTypeFilter, f)
                try("SetTrainerServiceTypeFilter", SetTrainerServiceTypeFilter, f, 1)
            end
        end
        local n = try("GetNumTrainerServices", GetNumTrainerServices)
        if type(n) == "number" and n > 0 then
            r.trainer = { count = n, services = {}, filtersBefore = saved }
            for i = 1, math.min(n, 300) do
                local s = { info = packArgs(try("GetTrainerServiceInfo", GetTrainerServiceInfo, i)) }
                if GetTrainerServiceLevelReq then s.level = try("GetTrainerServiceLevelReq", GetTrainerServiceLevelReq, i) end
                if GetTrainerServiceCost then s.cost = packArgs(try("GetTrainerServiceCost", GetTrainerServiceCost, i)) end
                r.trainer.services[i] = s
            end
        end
        if SetTrainerServiceTypeFilter then
            for _, f in ipairs(filters) do
                if saved[f] ~= nil then try("SetTrainerServiceTypeFilter", SetTrainerServiceTypeFilter, f, saved[f] and 1 or 0) end
            end
        end
    end
    DB.spells = r
    local types = {}
    for k, v in pairs(r.byType) do types[#types + 1] = k .. "=" .. v end
    msg(string.format("spells: %d spellbook items (types %s), trainer %s. Type /reload to save.",
        #r.items, table.concat(types, " "), r.trainer and (r.trainer.count .. " services") or "window not open"))
end

---------------------------------------------------------------------------
-- Profession probe (/azfdiag profs; Professions tab, docs/research/professions.md): the
-- character's professions and skill ranks, whether recipe state is readable with the window shut
-- (IsPlayerSpell), and, depending on what's open when it runs:
--   profession window: every recipe the client lists, with "show unlearned" on, then restored;
--   trainer: its services with skill requirements;   vendor: recipe items with tooltip lines
--   ("Already known", "Requires Tailoring (125)");   always: recipe items in the bags.
---------------------------------------------------------------------------

local function tooltipLines(data)
    if type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
    local out = {}
    for i, line in ipairs(data.lines) do
        if i > 14 then break end
        local text = line.leftText
        if type(text) == "string" and text ~= "" then
            local c = line.leftColor
            local red = type(c) == "table" and c.r and c.r > 0.9 and (c.g or 1) < 0.2
            out[#out + 1] = (red and "[red] " or "") .. text
        end
    end
    return out
end

local function recipeItem(itemID, tip)
    local e = { id = itemID }
    if C_Item and C_Item.GetItemInfoInstant then
        local _, _, _, _, _, classID, subClassID = try("C_Item.GetItemInfoInstant", C_Item.GetItemInfoInstant, itemID)
        e.class, e.sub = classID, subClassID
    end
    if C_Item and C_Item.GetItemNameByID then e.name = try("C_Item.GetItemNameByID", C_Item.GetItemNameByID, itemID) end
    if C_Item and C_Item.GetItemSpell then e.spell = packArgs(try("C_Item.GetItemSpell", C_Item.GetItemSpell, itemID)) end
    e.tip = tooltipLines(tip)
    return e
end

local function dumpProfessions()
    local T, S, SB = C_TradeSkillUI, C_SkillInfo, C_SpellBook
    local r = { t = time(), level = UnitLevel and UnitLevel("player"), has = {}, profs = {}, skills = {}, lines = {} }
    for _, name in ipairs({ "GetProfessions", "GetProfessionInfo", "IsPlayerSpell", "IsSpellKnown", "GetNumTradeSkills",
        "GetTradeSkillInfo", "GetTradeSkillLine", "GetNumSkillLines", "GetSkillLineInfo", "GetMerchantNumItems",
        "GetMerchantItemID", "GetTrainerServiceSkillReq", "GetTrainerServiceSkillLine", "IsTradeskillTrainer" }) do
        r.has[name] = type(_G[name])
    end
    r.has.C_TooltipInfo = type(rawget(_G, "C_TooltipInfo"))
    r.has.C_ProfSpecs = type(rawget(_G, "C_ProfSpecs"))

    -- The character's professions (the book's source) and every skill line (secondary ones too).
    if GetProfessions then
        r.slots = packArgs(try("GetProfessions", GetProfessions))
        for i = 1, r.slots.n or 0 do
            local slot = r.slots[i]
            if type(slot) == "number" and GetProfessionInfo then
                local p = { slot = slot, info = packArgs(try("GetProfessionInfo", GetProfessionInfo, slot)) }
                local line = p.info[7]
                if type(line) == "number" and T and T.GetProfessionInfoBySkillLineID then
                    p.bySkillLine = safePlain(try("GetProfessionInfoBySkillLineID", T.GetProfessionInfoBySkillLineID, line))
                end
                r.profs[#r.profs + 1] = p
            end
        end
    end
    if S and S.GetNumSkillLines and S.GetSkillLineInfo then
        for i = 1, math.min(try("C_SkillInfo.GetNumSkillLines", S.GetNumSkillLines) or 0, 80) do
            r.skills[i] = safePlain(try("C_SkillInfo.GetSkillLineInfo", S.GetSkillLineInfo, i))
        end
    end
    if T and T.GetAllProfessionTradeSkillLines then
        local ids = try("GetAllProfessionTradeSkillLines", T.GetAllProfessionTradeSkillLines)
        if type(ids) == "table" then
            for _, id in ipairs(ids) do
                r.lines[#r.lines + 1] = { id = id, info = T.GetProfessionInfoBySkillLineID
                    and safePlain(try("GetProfessionInfoBySkillLineID", T.GetProfessionInfoBySkillLineID, id)) }
            end
        end
    end
    -- Known-state with the window shut: classic recipe spells (Linen Bandage 3275, Heavy Linen
    -- Bandage 3276, Rough Sharpening Stone 2660, Smelt Copper 2657, Minor Healing Potion 2330,
    -- Linen Cloak 2387, Brown Linen Vest 2385, Charred Wolf Meat 2538, Enchant Bracer - Minor Health 7418).
    r.spellCheck = {}
    for _, id in ipairs({ 3275, 3276, 2660, 2657, 2330, 2387, 2385, 2538, 7418 }) do
        r.spellCheck[#r.spellCheck + 1] = { id = id,
            player = IsPlayerSpell and try("IsPlayerSpell", IsPlayerSpell, id),
            known = SB and SB.IsSpellKnown and try("C_SpellBook.IsSpellKnown", SB.IsSpellKnown, id),
            name = C_Spell and C_Spell.GetSpellName and try("C_Spell.GetSpellName", C_Spell.GetSpellName, id) }
    end

    -- An open profession window: its recipe list with learned and unlearned shown.
    if T and T.IsTradeSkillReady and try("IsTradeSkillReady", T.IsTradeSkillReady) then
        local w = { base = safePlain(T.GetBaseProfessionInfo and try("GetBaseProfessionInfo", T.GetBaseProfessionInfo)),
            child = safePlain(T.GetChildProfessionInfo and try("GetChildProfessionInfo", T.GetChildProfessionInfo)),
            showLearned = T.GetShowLearned and try("GetShowLearned", T.GetShowLearned),
            showUnlearned = T.GetShowUnlearned and try("GetShowUnlearned", T.GetShowUnlearned),
            recipes = {}, sources = {} }
        local function ids(fn) local v = fn and try("recipeIDs", fn); return type(v) == "table" and v or nil end
        local all, filtered = ids(T.GetAllRecipeIDs), ids(T.GetFilteredRecipeIDs)
        w.allBefore, w.filteredBefore = all and #all, filtered and #filtered
        if T.SetShowUnlearned then try("SetShowUnlearned", T.SetShowUnlearned, true) end
        if T.SetShowLearned then try("SetShowLearned", T.SetShowLearned, true) end
        all, filtered = ids(T.GetAllRecipeIDs), ids(T.GetFilteredRecipeIDs)
        w.all, w.filtered = all and #all, filtered and #filtered
        local learned, unlearned, agree, disagree = 0, 0, 0, 0
        for i, id in ipairs(all or {}) do
            if i > 1200 then break end
            local info = T.GetRecipeInfo and try("GetRecipeInfo", T.GetRecipeInfo, id)
            if i <= 3 then w.sample = w.sample or {}; w.sample[i] = safePlain(info) end
            if type(info) == "table" then
                local e = { id = id, name = info.name, learned = info.learned, src = info.sourceType,
                    cat = info.categoryID, sla = info.skillLineAbilityID, diff = info.relativeDifficulty,
                    trivial = info.maxTrivialLevel, ups = info.numSkillUps, item = info.hyperlink and info.hyperlink:match("item:(%d+)") }
                if IsPlayerSpell then
                    e.player = try("IsPlayerSpell", IsPlayerSpell, id)
                    if e.player == info.learned then agree = agree + 1 else disagree = disagree + 1 end
                end
                if T.GetRecipeRequirements and i <= 40 then e.req = safePlain(try("GetRecipeRequirements", T.GetRecipeRequirements, id)) end
                if info.learned then learned = learned + 1 else
                    unlearned = unlearned + 1
                    if T.GetRecipeSourceText and #w.sources < 80 then
                        w.sources[#w.sources + 1] = { id = id, text = try("GetRecipeSourceText", T.GetRecipeSourceText, id) }
                    end
                end
                w.recipes[#w.recipes + 1] = e
            end
        end
        w.learned, w.unlearned, w.playerAgree, w.playerDisagree = learned, unlearned, agree, disagree
        -- Category names: GetCategories listed none on First Aid (run 2026-11-13), so look up each
        -- recipe's categoryID and its parents.
        w.categories = {}
        if T.GetCategoryInfo then
            local seen, queue = {}, {}
            for _, e in ipairs(w.recipes) do if e.cat then queue[#queue + 1] = e.cat end end
            while #queue > 0 do
                local c = table.remove(queue)
                if not seen[c] then
                    seen[c] = true
                    local info = try("GetCategoryInfo", T.GetCategoryInfo, c)
                    w.categories[#w.categories + 1] = { id = c, info = safePlain(info) }
                    if type(info) == "table" and info.parentCategoryID and info.parentCategoryID ~= 0 then queue[#queue + 1] = info.parentCategoryID end
                end
            end
        end
        if T.SetShowUnlearned and w.showUnlearned ~= nil then try("SetShowUnlearned", T.SetShowUnlearned, w.showUnlearned) end
        if T.SetShowLearned and w.showLearned ~= nil then try("SetShowLearned", T.SetShowLearned, w.showLearned) end
        r.window = w
    end

    -- An open trainer: its services, with every filter on, then restored.
    if GetNumTrainerServices and IsTradeskillTrainer and try("IsTradeskillTrainer", IsTradeskillTrainer) then
        local filters, saved = { "available", "unavailable", "used" }, {}
        for _, f in ipairs(filters) do
            if GetTrainerServiceTypeFilter and SetTrainerServiceTypeFilter then
                saved[f] = try("GetTrainerServiceTypeFilter", GetTrainerServiceTypeFilter, f)
                try("SetTrainerServiceTypeFilter", SetTrainerServiceTypeFilter, f, 1)
            end
        end
        local n = try("GetNumTrainerServices", GetNumTrainerServices) or 0
        r.trainer = { count = n, services = {} }
        for i = 1, math.min(n, 300) do
            local s = { info = packArgs(try("GetTrainerServiceInfo", GetTrainerServiceInfo, i)) }
            if GetTrainerServiceSkillReq then s.skill = packArgs(try("GetTrainerServiceSkillReq", GetTrainerServiceSkillReq, i)) end
            if GetTrainerServiceLevelReq then s.level = try("GetTrainerServiceLevelReq", GetTrainerServiceLevelReq, i) end
            if GetTrainerServiceCost then s.cost = try("GetTrainerServiceCost", GetTrainerServiceCost, i) end
            if GetTrainerServiceSkillLine then s.line = try("GetTrainerServiceSkillLine", GetTrainerServiceSkillLine, i) end
            r.trainer.services[i] = s
        end
        for _, f in ipairs(filters) do
            if saved[f] ~= nil then try("SetTrainerServiceTypeFilter", SetTrainerServiceTypeFilter, f, saved[f] and 1 or 0) end
        end
    end

    -- An open vendor: its recipe items (class 9) with tooltip lines.
    local TI = rawget(_G, "C_TooltipInfo")
    if GetMerchantNumItems and GetMerchantItemID then
        local n = try("GetMerchantNumItems", GetMerchantNumItems) or 0
        if n > 0 then
            r.vendor = { count = n, items = {} }
            for i = 1, math.min(n, 120) do
                local id = try("GetMerchantItemID", GetMerchantItemID, i)
                if id then
                    local e = recipeItem(id, TI and TI.GetMerchantItem and try("GetMerchantItem", TI.GetMerchantItem, i))
                    if e.class == 9 then r.vendor.items[#r.vendor.items + 1] = e end
                end
            end
        end
    end
    -- Recipe items in the bags, and each one's tooltip by item ID (does "Already known" show there too?).
    r.bags = {}
    if C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemID then
        for bag = 0, 4 do
            for slot = 1, (try("GetContainerNumSlots", C_Container.GetContainerNumSlots, bag) or 0) do
                local id = try("GetContainerItemID", C_Container.GetContainerItemID, bag, slot)
                if id and #r.bags < 30 then
                    local e = recipeItem(id, TI and TI.GetBagItem and try("GetBagItem", TI.GetBagItem, bag, slot))
                    if e.class == 9 then
                        e.byID = TI and TI.GetItemByID and tooltipLines(try("GetItemByID", TI.GetItemByID, id))
                        r.bags[#r.bags + 1] = e
                    end
                end
            end
        end
    end
    -- Each run is kept (window, trainer and vendor are usually separate runs).
    DB.profs = nil
    DB.profRuns = DB.profRuns or {}
    push(DB.profRuns, r, 8)
    msg(string.format("professions: %d professions, %d skill lines; window %s, trainer %s, vendor %s, %d recipe items in bags. Type /reload to save.",
        #r.profs, #r.skills, r.window and ((r.window.all or 0) .. " recipes") or "not open",
        r.trainer and (r.trainer.count .. " services") or "not open",
        r.vendor and (#r.vendor.items .. " recipes") or "not open", #r.bags))
end

---------------------------------------------------------------------------
-- Image format / native texture test
---------------------------------------------------------------------------

local ART_TESTS = {
    { label = "test.tga", path = "Interface\\AddOns\\AzerfolioDiag\\Media\\test.tga" },
    { label = "test.png", path = "Interface\\AddOns\\AzerfolioDiag\\Media\\test.png" },
    { label = "test (no ext)", path = "Interface\\AddOns\\AzerfolioDiag\\Media\\test" },
    { label = "EJ background", path = "Interface\\EncounterJournal\\UI-EJ-BACKGROUND-Default" },
    { label = "Quest parchment", path = "Interface\\QuestFrame\\QuestBG" },
    { label = "Achievement parchment", path = "Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal" },
    { label = "Dialog border", path = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border" },
    { label = "Class icon (atlas file)", path = "Interface\\TargetingFrame\\UI-Classes-Circles" },
    { label = "Elwynn .blp (DXT1)", path = "Interface\\AddOns\\Azerfolio\\Media\\Zones\\1429.blp", wide = true },
    { label = "Tanaris .blp (DXT1)", path = "Interface\\AddOns\\Azerfolio\\Media\\Zones\\1446.blp", wide = true },
}

local artFrame
local function showArt()
    if not artFrame then
        local f = CreateFrame("Frame", "AzerfolioDiagArtFrame", UIParent, "BackdropTemplate")
        f:SetSize(4 * 150 + 20, 2 * 170 + 170 + 40)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        if f.SetBackdrop then
            f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
            f:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
            f:SetBackdropBorderColor(0.8, 0.7, 0.3, 1)
        end
        f:EnableMouse(true)
        f:SetMovable(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -8)
        title:SetText("AzerfolioDiag art test - screenshot me, then /azfdiag art to close")
        DB.art = { t = time(), results = {} }
        local wideCount = 0
        for i, test in ipairs(ART_TESTS) do
            local tex = f:CreateTexture(nil, "ARTWORK")
            if test.wide then -- 2:1 zone art spans two columns on the third row
                tex:SetSize(278, 139)
                tex:SetPoint("TOPLEFT", 10 + wideCount * 300 + 11, -34 - 2 * 170)
                wideCount = wideCount + 1
            else
                local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
                tex:SetSize(128, 128)
                tex:SetPoint("TOPLEFT", 10 + col * 150 + 11, -34 - row * 170)
            end
            local ok, ret = pcall(tex.SetTexture, tex, test.path)
            local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            label:SetPoint("TOP", tex, "BOTTOM", 0, -4)
            label:SetText(test.label)
            DB.art.results[i] = {
                label = test.label, path = test.path, pcallOk = ok, setTextureReturn = safePlain(ret),
                getTexture = safePlain(try("GetTexture", tex.GetTexture, tex)),
                getTextureFileID = safePlain(try("GetTextureFileID", tex.GetTextureFileID, tex)),
            }
        end
        artFrame = f
        msg("art test shown. Take a screenshot (PrtScn), then /reload.")
        return
    end
    artFrame:SetShown(not artFrame:IsShown())
end

---------------------------------------------------------------------------
-- Skin probe: what draws the native Forever frames? (/azfdiag skin)
-- 1. Walks the live CharacterFrame (open Reputation first) and records every texture's atlas,
--    file and file ID, every font, and the frame tree. Read-only: nothing is changed.
-- 2. Lists visible gamepad overlay frames (button legend, prompts, pointer).
-- 3. Checks candidate atlas names with C_Texture.GetAtlasInfo.
-- 4. Shows a test frame built from candidate templates, for a screenshot.
---------------------------------------------------------------------------

local SKIN_ROOTS = { "CharacterFrame", "ReputationFrame" }
local SKIN_MAX_NODES, SKIN_MAX_DEPTH = 1500, 7
local SKIN_OVERLAY_PATTERNS = { "gamepad", "legend", "prompt", "smartnav", "pointer", "cursor", "controls" }
local SKIN_ATLASES = {
    "UI-Frame-PortraitMetal-CornerTopLeft", "UI-Frame-Metal-CornerTopRight", "_UI-Frame-Metal-EdgeTop",
    "!UI-Frame-Metal-EdgeLeft", "UI-Frame-InnerTopLeft", "_UI-Frame-InnerTopTile",
    "gamepad-largecursor-white", "gamepad-mapquestlog-cursor-diamond-gold",
    "gamepad-reticletargeting-indicator-x1",
}
local SKIN_TEMPLATES = {
    { template = "PortraitFrameTemplate", w = 300, h = 220 },
    { template = "ButtonFrameTemplate", w = 300, h = 220 },
    { template = "DefaultPanelTemplate", w = 300, h = 220 },
    { template = "InsetFrameTemplate", w = 300, h = 220 },
}

local function call(obj, method, ...)
    local fn = obj and obj[method]
    if type(fn) ~= "function" then return nil end
    return try(method, fn, obj, ...)
end

local function packed(obj, method, ...)
    local fn = obj and obj[method]
    if type(fn) ~= "function" then return nil end
    local r = packn(pcall(fn, obj, ...))
    if not r[1] then return nil end
    local out = {}
    for i = 2, r.n do out[i - 1] = safePlain(r[i]) end
    return out
end

-- One region or frame, flattened into plain values.
local function describe(obj)
    local d = {
        type = call(obj, "GetObjectType"),
        name = safePlain(call(obj, "GetDebugName")),
        key = safePlain(call(obj, "GetParentKey")),
        shown = call(obj, "IsShown"),
        size = packed(obj, "GetSize"),
    }
    if d.type == "Texture" or d.type == "MaskTexture" then
        d.atlas = safePlain(call(obj, "GetAtlas"))
        d.texture = safePlain(call(obj, "GetTexture"))
        d.fileID = safePlain(call(obj, "GetTextureFileID"))
        d.layer = packed(obj, "GetDrawLayer")
        d.color = packed(obj, "GetVertexColor")
        d.coords = packed(obj, "GetTexCoord")
        d.blend = safePlain(call(obj, "GetBlendMode"))
        d.alpha = safePlain(call(obj, "GetAlpha"))
    elseif d.type == "FontString" then
        d.text = safePlain(call(obj, "GetText"))
        d.font = packed(obj, "GetFont")
        d.color = packed(obj, "GetTextColor")
        d.layer = packed(obj, "GetDrawLayer")
    end
    return d
end

local function walk(frame, depth, budget)
    budget.n = budget.n + 1
    local node = describe(frame)
    if budget.n > SKIN_MAX_NODES then node.truncated = true return node end
    node.regions = {}
    for _, r in ipairs({ call(frame, "GetRegions") }) do
        budget.n = budget.n + 1
        node.regions[#node.regions + 1] = describe(r)
    end
    if depth < SKIN_MAX_DEPTH then
        node.children = {}
        for _, c in ipairs({ call(frame, "GetChildren") }) do
            if budget.n > SKIN_MAX_NODES then node.truncated = true break end
            node.children[#node.children + 1] = walk(c, depth + 1, budget)
        end
    end
    return node
end

local function overlayFrames()
    local found = {}
    if type(EnumerateFrames) ~= "function" then return found end
    local f, guard = EnumerateFrames(), 0
    while f and guard < 20000 and #found < 60 do
        guard = guard + 1
        if call(f, "IsVisible") then
            local name = tostring(call(f, "GetDebugName") or ""):lower()
            for _, pat in ipairs(SKIN_OVERLAY_PATTERNS) do
                if name:find(pat, 1, true) then
                    found[#found + 1] = walk(f, SKIN_MAX_DEPTH - 2, { n = 0 })
                    break
                end
            end
        end
        f = EnumerateFrames(f)
    end
    return found
end

local skinFrame
local function buildSkinTestFrame()
    local holder = CreateFrame("Frame", "AzerfolioDiagSkinFrame", UIParent)
    holder:SetSize(2 * 320, 2 * 250 + 80)
    holder:SetPoint("RIGHT", UIParent, "RIGHT", -60, 0)
    holder:SetFrameStrata("DIALOG")
    local title = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -4)
    title:SetText("AzerfolioDiag skin test - screenshot, then /azfdiag skin to close")
    local results = {}
    for i, spec in ipairs(SKIN_TEMPLATES) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        local ok, f = pcall(CreateFrame, "Frame", nil, holder, spec.template)
        results[i] = { template = spec.template, ok = ok, err = not ok and safePlain(f) or nil }
        if ok and f then
            f:SetSize(spec.w, spec.h)
            f:SetPoint("TOPLEFT", holder, "TOPLEFT", 10 + col * 320, -40 - row * 250)
            if f.SetTitle then pcall(f.SetTitle, f, spec.template) end
            local portrait = f.PortraitContainer and f.PortraitContainer.portrait or f.portrait
            if portrait and SetPortraitTexture then pcall(SetPortraitTexture, portrait, "player") end
            local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            label:SetPoint("CENTER")
            label:SetText(spec.template)
            results[i].tree = walk(f, 3, { n = 0 })
        end
    end
    -- Pointer candidates, tinted like the SmartNavigation cursor.
    for i, atlas in ipairs({ "gamepad-largecursor-white", "gamepad-mapquestlog-cursor-diamond-gold" }) do
        local tex = holder:CreateTexture(nil, "OVERLAY")
        tex:SetSize(32, 32)
        tex:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 10 + (i - 1) * 200, 10)
        local ok = pcall(tex.SetAtlas, tex, atlas)
        if i == 1 then tex:SetVertexColor(1, 0.9, 0, 1) end
        local label = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("LEFT", tex, "RIGHT", 6, 0)
        label:SetText(atlas .. (ok and "" or " (failed)"))
    end
    return holder, results
end

local function runSkinProbe()
    if skinFrame and skinFrame:IsShown() then
        skinFrame:Hide()
        msg("skin test hidden.")
        return
    end
    local skin = { t = time(), roots = {}, atlases = {} }
    for _, name in ipairs(SKIN_ROOTS) do
        local f = _G[name]
        skin.roots[name] = f and walk(f, 0, { n = 0 }) or "missing"
    end
    skin.overlays = overlayFrames()
    for _, atlas in ipairs(SKIN_ATLASES) do
        local info = C_Texture and try("GetAtlasInfo", C_Texture.GetAtlasInfo, atlas)
        skin.atlases[atlas] = info and safePlain(info) or false
    end
    if not skinFrame then
        local frame, results = buildSkinTestFrame()
        skinFrame, skin.templates = frame, results
    end
    skinFrame:Show()
    DB.skin = skin
    local shown = type(skin.roots.CharacterFrame) == "table" and skin.roots.CharacterFrame.shown
    msg(string.format("skin recorded (Character frame %s). Take a screenshot, then /reload.",
        shown and "open" or "NOT open - open Reputation first and run again"))
end

---------------------------------------------------------------------------
-- Gamepad probe: can an addon frame receive pad input, and what are the names?
---------------------------------------------------------------------------

local PAD_TIMEOUT = 25 -- seconds; the probe captures pad buttons, so it must never trap the player
local padFrame, padStopTimer

local function padEnvironment()
    local env = { t = time() }
    env.InputUtil = type(InputUtil)
    env.IsGamepadUIEnabled = InputUtil and safePlain(try("IsGamepadUIEnabled", InputUtil.IsGamepadUIEnabled))
    env.GamePadEnableCVar = safePlain(try("GetCVar", GetCVar, "GamePadEnable")
        or (C_CVar and try("C_CVar.GetCVar", C_CVar.GetCVar, "GamePadEnable")))
    env.C_GamePad = type(C_GamePad)
    if C_GamePad then
        env.IsEnabled = safePlain(try("C_GamePad.IsEnabled", C_GamePad.IsEnabled))
        env.GetActiveDeviceID = safePlain(try("GetActiveDeviceID", C_GamePad.GetActiveDeviceID))
        local fns = {}
        for k, v in pairs(C_GamePad) do if type(v) == "function" then fns[#fns + 1] = k end end
        table.sort(fns)
        env.C_GamePadFunctions = fns
    end
    env.SmartNavigation = type(SmartNavigation)
    env.GamepadMode = type(GamepadMode)
    env.InCombatLockdown = safePlain(try("InCombatLockdown", InCombatLockdown))
    local probe = CreateFrame("Frame")
    env.frameMethods = {}
    for _, m in ipairs({ "EnableGamePadButton", "EnableGamePadStick", "FocusGamepad", "UnfocusGamepad",
        "SetPropagateKeyboardInput", "SetPropagateGamepadInput", "IsGamePadButtonEnabled" }) do
        env.frameMethods[m] = type(probe[m])
    end
    probe:Hide()
    env.constants = {}
    for k, v in pairs(_G) do
        if type(k) == "string" and (k:match("^GAMEPAD_") or k:match("^SMART_NAV")) and type(v) ~= "table" and type(v) ~= "function" then
            env.constants[k] = safePlain(v)
        end
    end
    return env
end

local function stopPad(reason)
    if not padFrame then return end
    pcall(padFrame.EnableGamePadButton, padFrame, false)
    pcall(padFrame.EnableGamePadStick, padFrame, false)
    if padFrame.UnfocusGamepad then pcall(padFrame.UnfocusGamepad, padFrame) end
    padFrame:Hide()
    DB.pad.stoppedBy = reason
    msg(string.format("gamepad probe stopped (%s): %d presses recorded. /reload to save.", reason, #DB.pad.presses))
end

local function startPad()
    DB.pad = { env = padEnvironment(), presses = {}, sticks = {}, startedAt = GetTime() }
    if not padFrame then
        local f = CreateFrame("Frame", "AzerfolioDiagPadFrame", UIParent, "BackdropTemplate")
        f:SetSize(520, 120)
        f:SetPoint("TOP", 0, -120)
        f:SetFrameStrata("DIALOG")
        if f.SetBackdrop then
            f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 2 })
            f:SetBackdropColor(0.05, 0.05, 0.05, 0.92)
            f:SetBackdropBorderColor(0.83, 0.69, 0.22, 1)
        end
        f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        f.text:SetPoint("TOPLEFT", 12, -12)
        f.text:SetPoint("BOTTOMRIGHT", -12, 12)
        f.text:SetJustifyH("LEFT")
        local lastStick = -math.huge
        f:SetScript("OnGamePadButtonDown", function(self, key)
            local p = DB.pad.presses
            p[#p + 1] = { key = tostring(key), down = true, gt = GetTime() }
            self.text:SetText("Gamepad probe: press every button once (D-pad, A/B/X/Y, LB/RB, LT/RT, sticks, Start/Back).\nLast: " .. tostring(key) .. "   Total: " .. #p .. "\nStops by itself after " .. PAD_TIMEOUT .. " s.")
        end)
        f:SetScript("OnGamePadButtonUp", function(_, key)
            local p = DB.pad.presses
            p[#p + 1] = { key = tostring(key), down = false, gt = GetTime() }
        end)
        f:SetScript("OnGamePadStick", function(_, stick, x, y, len)
            local now = GetTime()
            if now - lastStick < 0.25 or #DB.pad.sticks >= 60 then return end
            lastStick = now
            local s = DB.pad.sticks
            s[#s + 1] = { stick = tostring(stick), x = x, y = y, len = len, gt = now }
        end)
        padFrame = f
    end
    padFrame.text:SetText("Gamepad probe: press every button once (D-pad, A/B/X/Y, LB/RB, LT/RT, sticks, Start/Back).\nStops by itself after " .. PAD_TIMEOUT .. " s.")
    padFrame:Show()
    local okButton, errButton = pcall(padFrame.EnableGamePadButton, padFrame, true)
    local okStick, errStick = pcall(padFrame.EnableGamePadStick, padFrame, true)
    DB.pad.enableButton = okButton and true or tostring(errButton)
    DB.pad.enableStick = okStick and true or tostring(errStick)
    if padFrame.FocusGamepad then
        local okFocus, errFocus = pcall(padFrame.FocusGamepad, padFrame)
        DB.pad.focusGamepad = okFocus and true or tostring(errFocus)
    end
    local token = {}
    padStopTimer = token
    C_Timer.After(PAD_TIMEOUT, function() if padStopTimer == token and padFrame:IsShown() then stopPad("timeout") end end)
    msg("gamepad probe started: press each controller button once. It stops by itself after " .. PAD_TIMEOUT .. " s.")
end

local function togglePad()
    if padFrame and padFrame:IsShown() then stopPad("command") else startPad() end
end

---------------------------------------------------------------------------
-- Event sniffer (counts every event name; records first few argument sets)
---------------------------------------------------------------------------

local sniffFrame
local function setSniff(on)
    if not sniffFrame then
        sniffFrame = CreateFrame("Frame")
        sniffFrame:SetScript("OnEvent", function(_, event, ...)
            local s = DB.sniff
            s.counts[event] = (s.counts[event] or 0) + 1
            local samples = s.samples[event]
            if not samples then
                samples = {}
                s.samples[event] = samples
            end
            if #samples < 3 then samples[#samples + 1] = { gt = GetTime(), args = packArgs(...) } end
        end)
    end
    if on then
        DB.sniff = DB.sniff or { counts = {}, samples = {} }
        DB.sniff.startedAt = time()
        local ok, err = pcall(sniffFrame.RegisterAllEvents, sniffFrame)
        if not ok then recordError("RegisterAllEvents", err); msg("sniff unavailable: " .. tostring(err)); return end
        DB.sniffOn = true
        msg("event sniffer ON (stays on across /reload until you turn it off)")
    else
        pcall(sniffFrame.UnregisterAllEvents, sniffFrame)
        DB.sniffOn = false
        msg("event sniffer OFF")
    end
end

---------------------------------------------------------------------------
-- Event log
---------------------------------------------------------------------------

local QUIET = { CRITERIA_UPDATE = true, QUEST_LOG_UPDATE = true, ADDON_LOADED = true }
local RESCAN_ON = {
    MAP_EXPLORATION_UPDATED = true, CRITERIA_UPDATE = true, CRITERIA_EARNED = true, CRITERIA_COMPLETE = true,
    ACHIEVEMENT_EARNED = true, UI_INFO_MESSAGE = true, ZONE_CHANGED = true, ZONE_CHANGED_NEW_AREA = true,
}

local frame = CreateFrame("Frame")
local registration = {} -- [event] = true or the registration error

local function onEvent(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= ADDON_NAME then return end
        AzerfolioDiagDB = AzerfolioDiagDB or {}
        DB = AzerfolioDiagDB
        if DB.version ~= DB_VERSION then
            for k in pairs(DB) do DB[k] = nil end
            DB.version = DB_VERSION
        end
        DB.log = DB.log or {}
        DB.diffs = DB.diffs or {}
        DB.zoneSnapshots = DB.zoneSnapshots or {}
        DB.errors = DB.errors or {}
        DB.eventCounts = DB.eventCounts or {}
        DB.exploreIDs = nil -- rebuilt each session
        DB.eventRegistration = registration
        if DB.sniffOn then setSniff(true) end
        return
    end
    if not DB then return end

    DB.eventCounts[event] = (DB.eventCounts[event] or 0) + 1
    if not QUIET[event] then
        push(DB.log, { t = time(), gt = GetTime(), e = event, args = packArgs(...), where = where() }, MAX_LOG)
    end

    if event == "PLAYER_ENTERING_WORLD" then
        DB.session = { t = time(), build = packArgs(try("GetBuildInfo", GetBuildInfo)), player = try("UnitName", UnitName, "player") }
        C_Timer.After(3, function()
            scanAchievements(false)
            exploreState = nil
            rescan() -- establishes the baseline
        end)
    elseif event == "TAXIMAP_OPENED" or (event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" and ... == 5) then
        -- Forever opens the flight map through the interaction manager (type 5 = taxi node)
        -- [verified-ingame, sniffer 2026-11-08]; TAXIMAP_OPENED never fired.
        C_Timer.After(0.5, function() pcall(dumpTaxi, "TAXIMAP_OPENED") end)
    elseif RESCAN_ON[event] then
        scheduleRescan(event)
    end
end

frame:SetScript("OnEvent", onEvent)
for _, ev in ipairs(CANDIDATE_EVENTS) do
    local ok, err = pcall(frame.RegisterEvent, frame, ev)
    registration[ev] = ok and true or tostring(err)
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local function runAll()
    local steps = {
        { "env", dumpEnv },
        { "maps", dumpMaps },
        { "achievements", function() DB.achievements = scanAchievements(true) end },
        { "match", matchExploreToMaps },
        { "quests", dumpQuests },
        { "zone", dumpZone },
    }
    for _, s in ipairs(steps) do
        local ok, err = pcall(s[2])
        if not ok then recordError("all:" .. s[1], err); msg(s[1] .. " failed: " .. tostring(err)) end
    end
    local exploreCount = 0
    if DB.achievements then for _ in pairs(DB.achievements.explore) do exploreCount = exploreCount + 1 end end
    msg(string.format("done: %d maps, %d explore achievements, %d errors. Type /reload to save.",
        DB.maps and DB.maps.count or 0, exploreCount, #DB.errors))
end

local HELP = {
    "/azfdiag all    - dump everything (env, maps, achievements, quests, current zone)",
    "/azfdiag zone   - snapshot the current zone",
    "/azfdiag zones  - record each zone's level range, faction info and map position (raw)",
    "/azfdiag questdb - QuestieDB probe: API, read cost, corrections, race masks, quest areas",
    "/azfdiag taxi   - flight paths per zone (also recorded when a flight master's map opens)",
    "/azfdiag reps   - reputation probe: faction APIs, the full faction list, lookups by ID",
    "/azfdiag spells - spell probe: spellbook APIs, every spellbook item and its level (run again with a class trainer open)",
    "/azfdiag profs - profession probe: skills, recipe known-state (run with a profession window, trainer or recipe vendor open)",
    "/azfdiag sniff  - toggle logging of every event name",
    "/azfdiag art    - show the image-format test frame",
    "/azfdiag pad    - gamepad probe: press each button once (stops after 25 s)",
    "/azfdiag skin   - record what draws the native frames (open Reputation first) and show a template test",
    "/azfdiag status - show what has been recorded",
    "/azfdiag clear  - clear logs and diffs",
    "Then /reload to write results to disk.",
}

SLASH_AZERFOLIODIAG1 = "/azfdiag"
SlashCmdList.AZERFOLIODIAG = function(input)
    local cmd = (input or ""):lower():match("^%s*(%S*)")
    if not DB then msg("not initialized yet"); return end
    if cmd == "all" then runAll()
    elseif cmd == "env" then dumpEnv(); msg("env dumped")
    elseif cmd == "maps" then dumpMaps(); msg("maps dumped")
    elseif cmd == "ach" then DB.achievements = scanAchievements(true); matchExploreToMaps(); msg("achievements dumped")
    elseif cmd == "quests" then dumpQuests(); msg("quests dumped")
    elseif cmd == "zone" then dumpZone()
    elseif cmd == "zones" then dumpZoneMeta()
    elseif cmd == "questdb" then probeQuestDB()
    elseif cmd == "taxi" then dumpTaxi("command")
    elseif cmd == "reps" then dumpReps()
    elseif cmd == "spells" then dumpSpells()
    elseif cmd == "profs" then dumpProfessions()
    elseif cmd == "sniff" then setSniff(not DB.sniffOn)
    elseif cmd == "art" then showArt()
    elseif cmd == "pad" then togglePad()
    elseif cmd == "skin" then runSkinProbe()
    elseif cmd == "clear" then
        DB.log, DB.diffs, DB.zoneSnapshots, DB.errors, DB.eventCounts, DB.sniff = {}, {}, {}, {}, {}, nil
        msg("cleared")
    elseif cmd == "status" then
        msg(string.format("log %d, diffs %d, snapshots %d, errors %d, sniff %s, explore achievements %d",
            #DB.log, #DB.diffs, #DB.zoneSnapshots, #DB.errors, DB.sniffOn and "on" or "off", #(DB.exploreIDs or {})))
    else
        for _, line in ipairs(HELP) do msg(line) end
    end
end
