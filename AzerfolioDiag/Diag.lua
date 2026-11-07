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
    "AREA_POIS_UPDATED", "ADDON_LOADED",
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
}

local artFrame
local function showArt()
    if not artFrame then
        local f = CreateFrame("Frame", "AzerfolioDiagArtFrame", UIParent, "BackdropTemplate")
        f:SetSize(4 * 150 + 20, 2 * 170 + 40)
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
        for i, test in ipairs(ART_TESTS) do
            local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
            local tex = f:CreateTexture(nil, "ARTWORK")
            tex:SetSize(128, 128)
            tex:SetPoint("TOPLEFT", 10 + col * 150 + 11, -34 - row * 170)
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
    "/azfdiag sniff  - toggle logging of every event name",
    "/azfdiag art    - show the image-format test frame",
    "/azfdiag pad    - gamepad probe: press each button once (stops after 25 s)",
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
    elseif cmd == "sniff" then setSniff(not DB.sniffOn)
    elseif cmd == "art" then showArt()
    elseif cmd == "pad" then togglePad()
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
