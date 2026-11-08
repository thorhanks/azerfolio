-- /azf shots: opens the window and screenshots each tab and state, so the agent can review the
-- real UI from <game>\Screenshots (plan §4.3). Development aid; changes nothing it doesn't restore.
local _, ns = ...

local UI = ns.UI

local SETTLE = 0.5 -- seconds after a change before the screenshot
local GAP = 1.0    -- seconds after a screenshot before the next change

local function zonesPage() return UI.GetFrame().pages.zones end

-- Every listed zone as { mapID, name, continent }.
local function allZones()
    local out = {}
    for _, s in ipairs(ns.Maps.Sections()) do
        for _, z in ipairs(s.zones) do out[#out + 1] = { mapID = z.mapID, name = z.name, continent = s.title } end
    end
    return out
end

-- Opens a zone's detail in the normal-size window (restored when the shots end).
local function openDetail(zone)
    UI.ApplyGeometry(); UI.Relayout(); UI.SelectTab("zones")
    local page = zonesPage()
    if zone and page and page.Open then page:Open(zone); UI.shotsOpenedDetail = true end
end

-- The wide split view's size: the design's 1640, within the allowed range.
local function wideSize()
    local r = ns.Config.RANGES
    local w = math.max(ns.Theme.layout.wideMinWidth, math.min(1640, r["window.width"][2]))
    return w, ns.db.window.height
end

-- /azf shots banners: the Zone Detail of every zone with a banner offset.
local function bannerSteps()
    local list = {}
    for _, z in ipairs(allZones()) do
        if ns.Theme.bannerFocus[z.mapID] then
            list[#list + 1] = { label = "banner " .. z.name, fn = function() openDetail(z) end }
        end
    end
    return list
end

-- Each step changes the window, then one screenshot is taken.
local function steps(which)
    if which == "banners" then return bannerSteps() end
    local minW, minH = ns.Config.RANGES["window.width"][1], ns.Config.RANGES["window.height"][1]
    local function size(w, h) return function() UI.GetFrame():SetSize(w, h); UI.Relayout() end end
    local list = {}
    for _, def in ipairs(UI.tabs) do
        list[#list + 1] = { label = def.id, fn = function() UI.ApplyGeometry(); UI.SelectTab(def.id) end }
    end
    -- Focus after an RT jump: chevron, row highlight and scroll-into-view in one picture.
    list[#list + 1] = { label = "zones, next section", fn = function()
        UI.ApplyGeometry(); UI.SelectTab("zones")
        local item = ns.Focus.Current()
        UI.shotsFocusKey = item and item.key
        ns.Focus.Jump(1); UI.RefreshHints()
    end }
    -- The catalogue's other view and the Sort popup (the view is restored at the end).
    list[#list + 1] = { label = "zones, other view", fn = function()
        UI.ApplyGeometry(); UI.SelectTab("zones")
        local page = zonesPage()
        if UI.shotsView == nil then UI.shotsView = ns.db.zones.displayMode end
        page.catalogue:CycleView()
    end }
    list[#list + 1] = { label = "zones, sort popup", fn = function()
        local page = zonesPage()
        local cat = page.catalogue
        for _, o in ipairs(ns.ZonesCatalogue.OPTIONS) do
            if o.key == "sort" then page:OpenPopup(o, cat.options.sort) end
        end
    end }
    list[#list + 1] = { label = "zones, popup closed", fn = function()
        local page = zonesPage()
        if page.popup:IsShown() then page:ClosePopup() end
        if UI.shotsView and ns.db.zones.displayMode ~= UI.shotsView then page.catalogue:CycleView() end
    end, skip = true }
    for _, def in ipairs(UI.tabs) do
        list[#list + 1] = { label = def.id .. " at minimum size", fn = function()
            UI.SelectTab(def.id); size(minW, minH)()
        end }
    end
    -- Zone Detail for the zone the player stands in (or the first listed zone).
    local zones = allZones()
    local here = C_Map and C_Map.GetBestMapForUnit
        and ns.Debug.Try("GetBestMapForUnit", C_Map.GetBestMapForUnit, "player")
    local pick = zones[1]
    for _, z in ipairs(zones) do if z.mapID == here then pick = z end end
    list[#list + 1] = { label = "zone detail", fn = function() openDetail(pick) end }
    -- A zone the game has no Explore achievement for (the "can't track" message).
    for _, z in ipairs(zones) do
        local ok, ex = pcall(ns.Exploration.ForZone, z)
        if ok and ex and ex.status == "untracked" then
            list[#list + 1] = { label = "zone detail, not tracked", fn = function() openDetail(z) end }
            break
        end
    end
    -- Wide window: the split view with focus in the list, then in the selected zone's areas.
    list[#list + 1] = { label = "zones wide", fn = function()
        local page = zonesPage()
        if page and page.mode == "detail" then page:Back() end
        UI.shotsOpenedDetail = nil
        UI.SelectTab("zones"); size(wideSize())()
        if page and pick then page:Click(pick) end -- start on the player's zone, which has areas
    end }
    list[#list + 1] = { label = "zones wide, checklist", fn = function()
        local page = zonesPage()
        local item = ns.Focus.Current()
        if page and item and item.zone then page:Open(item.zone); UI.shotsOpenedDetail = true end
    end }
    return list
end
UI.ShotSteps = steps

function UI.RunShots(which)
    if type(Screenshot) ~= "function" then
        ns.Print("Screenshot() is not available on this client.")
        return
    end
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        ns.Print("Not during combat.")
        return
    end
    if UI.shotsRunning then return end
    UI.Show()
    if not UI.IsShown() then return end

    local list, startTab, i = steps(which), UI.CurrentTab(), 0
    if #list == 0 then return ns.Print("Nothing to screenshot.") end
    local pictures = 0
    for _, s in ipairs(list) do if not s.skip then pictures = pictures + 1 end end
    UI.shotsRunning = true
    local function finish(msg)
        UI.shotsRunning = false
        UI.ApplyGeometry(); UI.Relayout()
        local page = zonesPage()
        if page and page.popup:IsShown() then page:ClosePopup() end
        if page and UI.shotsView and ns.db.zones.displayMode ~= UI.shotsView then page.catalogue:CycleView() end
        UI.shotsView = nil
        if UI.shotsOpenedDetail then
            UI.SelectTab("zones"); UI.GetFrame().pages.zones:Back(); UI.shotsOpenedDetail = nil
        end
        if UI.shotsFocusKey ~= nil then
            UI.SelectTab("zones"); ns.Focus.FocusKey(UI.shotsFocusKey); UI.shotsFocusKey = nil
        end
        UI.SelectTab(startTab)
        ns.Print(msg)
    end
    local function nextStep()
        if not UI.IsShown() then return finish("Screenshots stopped: the window was closed.") end
        i = i + 1
        local s = list[i]
        if not s then return finish(string.format("Took %d screenshots.", pictures)) end
        local ok, err = pcall(s.fn)
        if not ok then
            ns.Debug.Error("shots " .. s.label, err)
            return finish("Screenshots stopped: " .. tostring(err))
        end
        if s.skip then return C_Timer.After(SETTLE, nextStep) end -- a tidy-up step, no picture
        C_Timer.After(SETTLE, function()
            local sok, serr = pcall(Screenshot)
            if not sok then ns.Debug.Error("Screenshot", serr) end
            ns.Debug.Print("shot %d: %s", i, s.label)
            C_Timer.After(GAP, nextStep)
        end)
    end
    ns.Printf("Taking %d screenshots; keep the window open.", pictures)
    nextStep()
end
