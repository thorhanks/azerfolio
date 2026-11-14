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

-- The zone to show reputation on: the player's zone if it has factions, else the zone with
-- the most (rivals first: their tags wrap), or nil when no zone has any.
local function repZone(zones, here)
    local best, bestScore
    for _, z in ipairs(zones) do
        local ok, list = pcall(ns.Reputation.ForZone, z)
        if ok and list then
            local score = #list * 10
            for _, f in ipairs(list) do if #(f.rivals or {}) > 0 then score = score + 5 end end
            if z.mapID == here then score = score + 1000 end
            if not bestScore or score > bestScore then best, bestScore = z, score end
        end
    end
    return best
end

-- Zone Detail's Reputation ledger (focus on its first faction) and that faction's page; with
-- `wide`, the same in the wide split view.
local function repSteps(zones, here, wide)
    local z = repZone(zones, here)
    if not z then return {} end
    local function focusFirst()
        local list = ns.Reputation.ForZone(z)
        if list then ns.Focus.FocusKey(ns.ZoneDetail.RepKey(list[1].factionID)); UI.RefreshHints() end
    end
    local function openPage()
        local page, list = zonesPage(), ns.Reputation.ForZone(z)
        if page and list then page:OpenRep(list[1].factionID) end
    end
    if wide then
        return {
            { label = "zones wide, reputation", fn = function()
                local page = zonesPage()
                if page then page:Open(z); UI.shotsOpenedDetail = true end
                focusFirst()
            end },
            { label = "zones wide, faction page", fn = openPage },
        }
    end
    local minW, minH = ns.Config.RANGES["window.width"][1], ns.Config.RANGES["window.height"][1]
    return {
        { label = "zone detail, reputation", fn = function() openDetail(z); focusFirst() end },
        { label = "zone detail, faction page", fn = openPage },
        -- The smallest window: the dashboard's right column scrolls to the last faction.
        { label = "zone detail, reputation at minimum size", fn = function()
            openDetail(z); UI.FitSize(minW, minH)
            -- Focus once the layout has settled (the column's scroll range is only known after
            -- the resize's size events), as when a player resizes and then moves.
            C_Timer.After(0.2, function()
                local list = ns.Reputation.ForZone(z)
                if list then ns.Focus.FocusKey(ns.ZoneDetail.RepKey(list[#list].factionID)); UI.RefreshHints() end
            end)
        end },
    }
end

local function repPage() return UI.GetFrame().pages.reputation end

-- The Reputation tab (Phase 12): the list, the Closest sort, the next section, a faction page
-- (a rival faction with sources if there is one: seesaw and reach), the minimum size; with
-- `wide`, the split view with focus in the list, then in the page. The sort is restored at
-- the end.
local function repTabSteps(wide)
    local function pick()
        local best
        for _, f in ipairs(ns.Reputation.AllFactions() or {}) do
            local score = #(f.sources or {}) + (#(f.rivals or {}) > 0 and 100 or 0) + ((f.reach and f.reach.count or 0) > 0 and 50 or 0)
            if not best or score > best.score then best = { id = f.factionID, score = score } end
        end
        return best and best.id
    end
    local function list()
        UI.SelectTab("reputation")
        local p = repPage()
        if p and p.mode == "detail" then p:Back() end
        if UI.shotsRepSort == nil then UI.shotsRepSort = ns.db.reputation.sort end
        if ns.db.reputation.sort ~= "group" then ns.db.reputation.sort = "group"; p:Redraw() end
        return p
    end
    local function openPick()
        local p, id = repPage(), pick()
        if p and id then p:OpenFaction(id) end
    end
    if wide then
        return {
            { label = "reputation wide", fn = function()
                local p = list()
                local id = pick()
                if p and id then p:ClickFaction(id) end
            end },
            { label = "reputation wide, in the page", fn = openPick },
        }
    end
    local minW, minH = ns.Config.RANGES["window.width"][1], ns.Config.RANGES["window.height"][1]
    return {
        { label = "reputation", fn = function() UI.ApplyGeometry(); UI.Relayout(); list() end },
        { label = "reputation, next section", fn = function() ns.Focus.Jump(1); UI.RefreshHints() end },
        { label = "reputation, closest sort", fn = function() local p = repPage(); if p then p:CycleSort() end end },
        { label = "reputation, faction page", fn = function() list(); openPick() end },
        { label = "reputation at minimum size", fn = function() list(); UI.FitSize(minW, minH) end },
        { label = "reputation page at minimum size", fn = openPick },
        { label = "normal size", fn = function() UI.ApplyGeometry(); UI.Relayout() end, skip = true },
    }
end

-- /azf shots reputation: the Reputation tab, then the zone ledger and the faction page,
-- normal size then wide.
local function reputationSteps(zones, here)
    local list = repTabSteps(false)
    for _, s in ipairs(repSteps(zones, here, false)) do list[#list + 1] = s end
    list[#list + 1] = { label = "reputation tab wide", fn = function() UI.FitSize(wideSize()) end, skip = true }
    for _, s in ipairs(repTabSteps(true)) do list[#list + 1] = s end
    if #repSteps(zones, here, false) == 0 then return list end
    list[#list + 1] = { label = "zones wide", fn = function()
        local page = zonesPage()
        if page and page.mode == "detail" then page:Back() end
        if page and page.mode == "detail" then page:Back() end
        UI.shotsOpenedDetail = nil
        UI.SelectTab("zones"); UI.FitSize(wideSize())
    end, skip = true }
    for _, s in ipairs(repSteps(zones, here, true)) do list[#list + 1] = s end
    return list
end

-- /azf shots class: the Class tab (Phase 13) on your current stop, that stop's steps, the
-- next stop (RT), the road's end, the minimum size, then wide.
local function classPage() return UI.GetFrame().pages.class end
local function classSteps()
    local minW, minH = ns.Config.RANGES["window.width"][1], ns.Config.RANGES["window.height"][1]
    local function road()
        UI.SelectTab("class")
        local p = classPage()
        if p and p.mode == "steps" then p:Back() end
        return p
    end
    local function current() local p = road(); if p and p.journey then p:FocusStop(p:CurrentStopKey()) end end
    return {
        { label = "class", fn = function() UI.ApplyGeometry(); UI.Relayout(); current() end },
        { label = "class, steps", fn = function() local p = classPage(); if p then p:EnterSteps() end end },
        { label = "class, next stop", fn = function() current(); ns.Focus.Jump(1); UI.RefreshHints() end },
        { label = "class, road's end", fn = function() local p = road(); if p and p.journey then p:FocusStop("end") end end },
        { label = "class, road's end list", fn = function() local p = classPage(); if p then p:EnterSteps() end end },
        -- Round 4: the first level with an ability you could train now (else the first mark).
        { label = "class, abilities", fn = function()
            local p = road()
            local tr = p and p.trainer
            local pick
            for _, mk in ipairs(tr and tr.abilities and tr.abilities.marks or {}) do
                if not pick or (mk.state == "available" and pick.state ~= "available") then pick = mk end
            end
            -- Round 5: stones can merge; focus the stone (its first level) that holds this level.
            local key
            for first, g in pairs(p and p.abilityGroups or {}) do
                for _, lv in ipairs(g.levels) do if pick and lv == pick.level then key = "a:" .. first end end
            end
            if key then p:FocusStop(key) end
        end },
        { label = "class at minimum size", fn = function() current(); UI.FitSize(minW, minH) end },
        { label = "class wide", fn = function() UI.FitSize(wideSize()); current() end },
        { label = "class wide, steps", fn = function() local p = classPage(); if p then p:EnterSteps() end end },
    }
end

-- Each step changes the window, then one screenshot is taken.
local function steps(which)
    if which == "banners" then return bannerSteps() end
    if which == "class" then return classSteps() end
    if which == "reputation" or which == "rep" then
        local here = C_Map and C_Map.GetBestMapForUnit
            and ns.Debug.Try("GetBestMapForUnit", C_Map.GetBestMapForUnit, "player")
        return reputationSteps(allZones(), here)
    end
    local minW, minH = ns.Config.RANGES["window.width"][1], ns.Config.RANGES["window.height"][1]
    local function size(w, h) return function() UI.FitSize(w, h) end end
    local list = {}
    for _, def in ipairs(UI.tabs) do
        list[#list + 1] = { label = def.id, fn = function()
            UI.ApplyGeometry(); UI.SelectTab(def.id)
            -- Start the Zones shots on the catalogue, even if Zone Detail was left open.
            local page = def.id == "zones" and zonesPage()
            if page and page.mode == "detail" then page:Back() end
        end }
    end
    -- Overview with focus on the class road window (round 3: its edge and the chevron).
    list[#list + 1] = { label = "overview, class road", fn = function()
        UI.ApplyGeometry(); UI.SelectTab("overview")
        local item = ns.Focus.Current()
        UI.shotsOverviewKey = item and item.key
        ns.Focus.FocusKey("classroad"); UI.RefreshHints()
    end }
    -- Focus after an RT jump: chevron, row highlight and scroll-into-view in one picture.
    list[#list + 1] = { label = "zones, next section", fn = function()
        UI.ApplyGeometry(); UI.SelectTab("zones")
        local item = ns.Focus.Current()
        UI.shotsFocusKey = item and item.key
        ns.Focus.Jump(1); UI.RefreshHints()
    end }
    -- The catalogue's other view and the Sort popup (the view is restored at the end). The wide
    -- split view always shows the list, so there the other view would repeat the last shot.
    if not UI.IsWide() then list[#list + 1] = { label = "zones, other view", fn = function()
        UI.ApplyGeometry(); UI.SelectTab("zones")
        local page = zonesPage()
        if UI.shotsView == nil then UI.shotsView = ns.db.zones.displayMode end
        page.catalogue:CycleView()
    end } end
    -- The Atlas view (Phase 10).
    if not UI.IsWide() then list[#list + 1] = { label = "zones, atlas", fn = function()
        local page = zonesPage()
        if UI.shotsView == nil then UI.shotsView = ns.db.zones.displayMode end
        ns.db.zones.displayMode = "atlas"; page.catalogue:Refresh()
    end } end
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
        if UI.shotsView and ns.db.zones.displayMode ~= UI.shotsView then
            ns.db.zones.displayMode = UI.shotsView; page.catalogue:Refresh()
        end
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
    -- Its category pages (the dashboard's tiles), where they open.
    for _, key in ipairs({ "explore", "quests", "flights" }) do
        list[#list + 1] = { label = "zone detail, " .. key, fn = function()
            local page = zonesPage()
            openDetail(pick)
            if page and page.OpenPage then page:OpenPage(key) end
        end }
    end
    -- The Reputation ledger and a faction page (Phase 11), where some zone has factions.
    for _, s in ipairs(repSteps(zones, here, false)) do list[#list + 1] = s end
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
    for _, s in ipairs(repSteps(zones, here, true)) do list[#list + 1] = s end
    for _, s in ipairs(repTabSteps(true)) do list[#list + 1] = s end
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
        if page and UI.shotsView and ns.db.zones.displayMode ~= UI.shotsView then
            ns.db.zones.displayMode = UI.shotsView; page.catalogue:Refresh()
        end
        UI.shotsView = nil
        local rp = UI.GetFrame().pages.reputation
        if rp then
            if rp.mode == "detail" then rp:Back() end
            if UI.shotsRepSort and ns.db.reputation.sort ~= UI.shotsRepSort then
                ns.db.reputation.sort = UI.shotsRepSort; rp:Redraw()
            end
        end
        UI.shotsRepSort = nil
        local cp = UI.GetFrame().pages.class
        if cp and cp.mode == "steps" then cp:Back() end
        if UI.shotsOpenedDetail then
            UI.SelectTab("zones")
            local zp = UI.GetFrame().pages.zones
            zp:Back() -- a category or faction page needs a second B to reach the catalogue
            if zp.mode == "detail" then zp:Back() end
            UI.shotsOpenedDetail = nil
        end
        if UI.shotsFocusKey ~= nil then
            UI.SelectTab("zones"); ns.Focus.FocusKey(UI.shotsFocusKey); UI.shotsFocusKey = nil
        end
        if UI.shotsOverviewKey ~= nil then
            UI.SelectTab("overview"); ns.Focus.FocusKey(UI.shotsOverviewKey); UI.shotsOverviewKey = nil
        end
        UI.SelectTab(startTab)
        ns.Print(msg)
    end
    local function nextStep()
        if not UI.IsShown() then return finish("Screenshots stopped: the window was closed.") end
        i = i + 1
        local s = list[i]
        if not s then return finish(string.format("Took %d screenshots.", pictures)) end
        local t = ns.Events.StartTiming()
        local ok, err = pcall(s.fn)
        ns.Events.StopTiming("shots: " .. s.label, t)
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
