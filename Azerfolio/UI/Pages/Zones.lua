-- Zones tab, two views:
--   * catalogue (UI/Pages/ZonesCatalogue.lua): toolbar plus illustrated cards or a compact
--     list of every zone, filtered, sorted and grouped by ns.Zones;
--   * detail (UI/Pages/ZoneDetail.lua): the zone's dashboard (war banner, one tile per
--     category) or one category's page (Exploration, Quests, Flight paths).
-- A (or a click) opens a zone's dashboard; A on a tile opens its page; B steps back: page ->
-- dashboard -> catalogue (same zone focused). Y cycles Cards / List, X searches (catalogue) or
-- opens the world map (detail). In a wide window the list and the detail show side by side
-- (see build). Uses the one-line strip.
local _, ns = ...

---------------------------------------------------------------------------------------------
-- Detail view: UI/Pages/ZoneDetail.lua (dashboard and category pages).
---------------------------------------------------------------------------------------------

-- The zone's entry, built now from the providers' (cached) results, so the detail is never
-- behind the catalogue, even for a zone filtered out of it (opened from the Overview).
local function entryFor(_, zone)
    return ns.Zones.Entry(zone, ns.Exploration.ForZone(zone.mapID), ns.Quests.ForZone(zone.mapID),
        ns.FlightPaths.ForZone(zone.mapID))
end

---------------------------------------------------------------------------------------------
-- Popup (Level, Sort, Show): a small list under its toolbar control; A picks, B closes.
---------------------------------------------------------------------------------------------

local function buildPopup(page)
    local T, L, S = ns.Theme, ns.Theme.layout, ns.Theme.space
    local p = CreateFrame("Frame", nil, page)
    p:SetFrameLevel((page:GetFrameLevel() or 1) + 20)
    p:SetWidth(L.popupWidth)
    p.bg = T.Solid(p, "ctlBg", "BACKGROUND", 0.98)
    p.bg:SetAllPoints()
    p.edge = ns.Widgets.Edge(p, "BORDER")
    p.edge:SetColor("gold"); p.edge:SetThickness(2)
    p:EnableMouse(true)
    p.buttons = {}
    p:Hide()

    -- Shows the option's values under `control`. Returns the focus rows.
    function p:Open(option, control)
        self.option, self.control = option, control
        local current = ns.db.zones[option.key]
        local rows = {}
        for i, it in ipairs(option.items) do
            local b = self.buttons[i]
            if not b then
                b = ns.Widgets.FocusRow(self, L.popupRow)
                b.text = T.Text(b, "sm", "text")
                b.text:SetPoint("LEFT", S.s3, 0)
                self.buttons[i] = b
            end
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", self, "TOPLEFT", S.s1, -S.s1 - (i - 1) * L.popupRow)
            b:SetPoint("TOPRIGHT", self, "TOPRIGHT", -S.s1, -S.s1 - (i - 1) * L.popupRow)
            local on = it[1] == current
            b.text:SetText((on and "|TInterface\\RaidFrame\\ReadyCheck-Ready:12|t " or "") .. it[2])
            b.text:SetTextColor(T.RGB(on and "gold" or "text"))
            local value = it[1]
            b.item = { key = "pop:" .. value, frame = b, title = option.label .. ": " .. it[2],
                actionLabel = "Choose", onActivate = function() page:ChoosePopup(value) end }
            b:SetScript("OnClick", function() page:ChoosePopup(value) end)
            b:Show()
            rows[#rows + 1] = { items = { b.item } }
        end
        for i = #option.items + 1, #self.buttons do self.buttons[i]:Hide() end
        self:SetHeight(#option.items * L.popupRow + 2 * S.s1)
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", control, "BOTTOMLEFT", 0, -S.s1)
        self:Show()
        self.rows = rows
        return rows, "pop:" .. tostring(current)
    end

    function p:Close() self:Hide(); self.option, self.control, self.rows = nil, nil, nil end
    return p
end

---------------------------------------------------------------------------------------------
-- Page
---------------------------------------------------------------------------------------------

-- The zone the player stands in, if the catalogue lists it.
local function playerZone(cat)
    local here = C_Map and C_Map.GetBestMapForUnit
        and ns.Debug.Try("GetBestMapForUnit", C_Map.GetBestMapForUnit, "player")
    local mapID = here and ns.Exploration.ZoneForMap(here) or here
    return (mapID and cat:ZoneFor(mapID)) or (here and cat:ZoneFor(here))
end

-- Modes: "list" (focus in the catalogue) and "detail" (focus in a zone's areas); a popup
-- over the toolbar takes focus while open. Narrow window: catalogue or detail. Wide window
-- (UI.IsWide): toolbar on top, the compact list on the left and the selected zone's detail on
-- the right, following focus; A moves into the areas, B comes back.
local function build(parent)
    local page = CreateFrame("Frame", nil, parent)
    page.mode = "list"
    local cat = ns.ZonesCatalogue.New(page)
    page.catalogue = cat
    page.toolbar, page.list = cat.toolbar, cat.list
    page.detail = ns.ZoneDetail.New(page)
    page.popup = buildPopup(page)
    page.detailPage = nil      -- nil = the dashboard, else "explore" | "quests" | "flights" | "rep:<factionID>"
    page.openStories = {}      -- finished storylines unfolded on the Quests page (this session)

    local function arrange()
        local L = ns.Theme.layout
        local tb, list, d = page.toolbar, page.list, page.detail
        tb:ClearAllPoints(); list:ClearAllPoints(); d:ClearAllPoints()
        tb:SetPoint("TOPLEFT"); tb:SetPoint("TOPRIGHT")
        if page.wide then
            list:SetPoint("TOPLEFT", tb, "BOTTOMLEFT"); list:SetPoint("BOTTOMLEFT")
            list:SetWidth(L.splitListWidth)
            d:SetPoint("TOPLEFT", list, "TOPRIGHT")
            d:SetPoint("BOTTOMRIGHT")
        else
            list:SetPoint("TOPLEFT", tb, "BOTTOMLEFT"); list:SetPoint("BOTTOMRIGHT")
            d:SetAllPoints()
        end
        list.edge:SetShown(page.wide)
        page.detail.back:SetShown(not page.wide)
        local map, S = page.detail.mapButton, ns.Theme.space
        map:ClearAllPoints()
        if page.wide then
            map:SetPoint("TOPRIGHT", page.detail.banner, "TOPRIGHT", -S.s4, -S.s3)
        else
            map:SetPoint("RIGHT", page.detail.back, "LEFT", -S.s2, 0)
        end
    end

    -- Marks the zone the split view shows (none in the narrow window).
    local function markSelected()
        local id = page.wide and page.zone and page.zone.mapID
        for mapID, f in pairs(cat.byMap) do
            if f.SetSelected then
                local on = mapID == id
                if (f.selected or false) ~= on then f:SetSelected(on) end
            end
        end
    end

    -- Fills the detail view for `zone` on page.detailPage (re-read when `force`). A different
    -- zone always starts on its dashboard, with the banner rising.
    local function show(zone, force)
        if not force and page.zone and page.zone.mapID == zone.mapID and page.detailRows then return end
        if not (page.zone and page.zone.mapID == zone.mapID) then page.detailPage = nil; page.animateBanner = true end
        page.zone = zone
        page.detailRows = ns.ZoneDetail.Fill(page.detail, zone, entryFor(cat, zone), page.detailPage, page)
    end

    local function refresh()
        local inDetail = page.mode == "detail"
        page.toolbar:SetShown(page.wide or not inDetail)
        page.list:SetShown(page.wide or not inDetail)
        page.detail:SetShown(inDetail or (page.wide and page.zone ~= nil))
        if page.popup:IsShown() then
            page.hasSections, page.backLabel = false, "Close"
        else
            page.hasSections = inDetail and page.detailPage ~= nil and page.detailRows and #page.detailRows > 0
                or (not inDetail and cat.sectionCount > 1)
            page.sectionLabel = "Section"
            page.backLabel = inDetail and (page.detailPage and "Overview" or "Zones") or nil
        end
        markSelected()
        ns.Focus.Rebuild()
        ns.UI.RefreshHints()
    end
    page.Redraw = refresh

    -- The catalogue redrew (filters, sort, view, data). In the split view keep a zone shown:
    -- the same one if it's still listed, else the first one; none if nothing matches.
    function page:OnCatalogueChanged()
        if self.building then return end
        if self.wide and self.mode == "list" then
            local keep = self.zone and cat:ZoneFor(self.zone.mapID)
            local zone = keep or cat.firstZone
            if zone then show(zone) else self.zone, self.detailRows = nil, nil end
        end
        if ns.UI.CurrentTab() == "zones" then refresh() end
    end

    -- A on a dashboard tile: that category's page, focused on its first item.
    function page:OpenPage(key)
        if not self.zone then return end
        self.detailPage = key
        show(self.zone, true)
        self.mode = "detail"
        local first = self.detailRows[1] and self.detailRows[1].items[1]
        self.pendingFocusKey = first and first.key
        refresh()
    end

    -- A on a faction in the Reputation ledger: its page, focused on its first quest.
    function page:OpenRep(factionID)
        self:OpenPage(ns.ZoneDetail.RepKey(factionID))
    end

    -- Quests page: unfold or fold a finished storyline; show or hide quests you can't do.
    function page:ToggleStory(id)
        self.openStories[id] = not self.openStories[id] or nil
        self.pendingFocusKey = "fold:" .. tostring(id)
        show(self.zone, true)
        refresh()
    end
    function page:ToggleUnavailable()
        ns.db.zones.showUnavailable = not ns.db.zones.showUnavailable
        self.pendingFocusKey = "toggle"
        show(self.zone, true)
        refresh()
    end

    -- A on a zone: open its dashboard (narrow) or move into it (wide).
    function page:Open(zone)
        self.returnTo = nil
        if not (self.zone and self.zone.mapID == zone.mapID) then self.animateBanner = true end
        self.detailPage = nil
        show(zone, true)
        local first = self.detailRows[1] and self.detailRows[1].items[1]
        if self.wide and not first then -- nothing to move into; the detail already shows why
            self.mode = "list"
        else
            self.mode = "detail"
            self.pendingFocusKey = first and first.key
        end
        refresh()
    end

    -- A click on a zone: in the split view it selects the zone and keeps focus in the list.
    function page:Click(zone)
        if not self.wide then return self:Open(zone) end
        self.returnTo = nil
        self.mode = "list"
        show(zone)
        self.pendingFocusKey = zone.mapID
        refresh()
    end

    function page:OpenPopup(option, control)
        if self.popup:IsShown() and self.popup.option == option then return self:ClosePopup() end
        local _, key = self.popup:Open(option, control)
        self.pendingFocusKey = key
        refresh()
    end

    function page:ClosePopup()
        local control = self.popup.control
        self.popup:Close()
        self.pendingFocusKey = control and control.item.key
        refresh()
    end

    function page:ChoosePopup(value)
        local option, control = self.popup.option, self.popup.control
        if not option then return end
        ns.db.zones[option.key] = value
        self.popup:Close()
        self.pendingFocusKey = control and control.item.key
        cat:Refresh()
    end

    -- Split view: the detail follows the focused zone.
    function page:OnFocusChanged(item)
        if self.wide and self.mode == "list" and item and item.zone then
            show(item.zone)
            markSelected()
        end
    end

    -- Called on every window resize (UI.Relayout); acts when the window crosses the wide size.
    function page:Layout()
        local wide = ns.UI.IsWide()
        if wide == self.wide then return end
        self.wide = wide
        if self.popup:IsShown() then self.popup:Close() end
        arrange()
        self.building = true
        cat:Refresh()
        self.building = false
        if wide and self.mode == "list" then
            -- Show the focused zone, else the player's zone, else the first one.
            local item = ns.UI.CurrentTab() == "zones" and ns.Focus.Current()
            local zone = (item and item.zone and cat:ZoneFor(item.zone.mapID)) or
                (self.zone and cat:ZoneFor(self.zone.mapID)) or playerZone(cat) or cat.firstZone
            if zone then
                show(zone)
                self.pendingFocusKey = zone.mapID
            end
        end
        refresh()
    end

    -- B: close the popup, leave the search box, or go back from the detail. True if handled.
    function page:Back()
        if self.popup:IsShown() then self:ClosePopup(); return true end
        if cat:SearchHasFocus() then cat.searchBox:ClearFocus(); return true end
        if self.mode ~= "detail" then return false end
        -- A category page goes back to the zone's dashboard, on that category's tile; one
        -- opened straight from another tab (an Overview area) goes back there.
        if self.detailPage and not self.returnTo then
            local key = self.detailPage
            self.detailPage = nil
            show(self.zone, true)
            -- A faction page goes back to the same faction's line; a category page to its tile.
            self.pendingFocusKey = ns.ZoneDetail.RepFaction(key) and key or ("tile:" .. key)
            refresh()
            return true
        end
        self.mode = "list"
        self.pendingFocusKey = self.zone and self.zone.mapID
        refresh()
        -- Opened from another tab (the Overview): B goes back there.
        local back = self.returnTo
        self.returnTo = nil
        if back then ns.UI.SelectTab(back) end
        return true
    end

    -- Opens a zone's detail from another tab, focused on one of its objectives if given: a
    -- criteria ID (an area) or a Next up pick { kind, id } (Overview suggestions). B returns
    -- to `returnTo`. The caller selects the Zones tab first.
    function page:ShowZone(zone, target, returnTo)
        if self.popup:IsShown() then self.popup:Close() end
        self:Open(zone)
        if self.mode ~= "detail" then return end
        local kind, id = "explore", target
        if type(target) == "table" then kind, id = target.kind, target.id end
        if id ~= nil and ns.ZoneDetail.FocusKey(kind, id) then
            self:OpenPage(kind)
            self.pendingFocusKey = ns.ZoneDetail.FocusKey(kind, id)
            refresh()
        end
        self.returnTo = returnTo
    end

    -- Shows the catalogue with one status filter (the Overview's Zones card).
    function page:ShowStatus(value)
        if self.popup:IsShown() then self.popup:Close() end
        self.returnTo = nil
        self.mode = "list"
        ns.db.zones.completion = value
        self.building = true
        cat:Refresh()
        self.building = false
        if self.wide then
            local zone = cat.firstZone
            if zone then show(zone) else self.zone, self.detailRows = nil, nil end
        end
        self.pendingFocusKey = cat.firstZone and cat.firstZone.mapID
        refresh()
    end

    -- Shows the Atlas view, focused on your current zone (the Overview's Atlas panel). It's the
    -- catalogue, so B closes the window as there. The split view has no Atlas: it shows its list.
    function page:ShowAtlas()
        if self.popup:IsShown() then self.popup:Close() end
        self.returnTo = nil
        self.mode = "list"
        ns.db.zones.displayMode = "atlas"
        self.building = true
        cat:Refresh()
        self.building = false
        self.pendingFocusKey = cat.firstZone and cat.firstZone.mapID
        refresh()
    end

    -- Opens the world map on the shown zone. The map needs the controller, so Azerfolio hides
    -- while it's open and comes back when it closes. Returns true if the map opened.
    function page:OpenMap()
        local zone = self.zone
        if not zone then return false end
        if type(InCombatLockdown) == "function" and InCombatLockdown() then
            ns.Print("The world map can't be opened from Azerfolio during combat.")
            return false
        end
        local ok, how = false, nil
        if type(OpenWorldMap) == "function" then
            ok = pcall(OpenWorldMap, zone.mapID); how = "OpenWorldMap"
        end
        if not ok and C_Map and type(C_Map.OpenWorldMap) == "function" then
            ok = pcall(C_Map.OpenWorldMap, zone.mapID); how = "C_Map.OpenWorldMap"
        end
        local wm = WorldMapFrame
        local shown = ok and wm ~= nil and wm.IsShown ~= nil and wm:IsShown() and true or false
        ns.Debug.Trace("worldmap", { mapID = zone.mapID, ok = ok, how = how, shown = shown,
            mapShown = shown and wm.GetMapID and ns.Debug.Try("GetMapID", wm.GetMapID, wm) or nil })
        if not shown then
            ns.Print("Couldn't open the world map.")
            return false
        end
        if wm.HookScript and not self.mapHooked then
            self.mapHooked = true
            wm:HookScript("OnHide", function()
                if page.reopenAfterMap then page.reopenAfterMap = false; ns.UI.Show() end
            end)
        end
        self.reopenAfterMap = self.mapHooked == true
        ns.UI.Hide()
        return true
    end

    -- X: search on the catalogue, world map in Zone Detail; Y: next view (catalogue only).
    function page:OnButton(name)
        if self.popup:IsShown() then return false end
        if self.mode == "detail" then
            if name == "x" then return self:OpenMap() end
            return false
        end
        if name == "x" then
            self.mode = "list"
            self.pendingFocusKey = cat.search.item.key
            refresh()
            cat:FocusSearch()
            return true
        elseif name == "y" then
            return cat:CycleView()
        end
        return false
    end

    function page:GetHints()
        if self.popup:IsShown() then return {} end
        -- The window adds A from the focused item's actionLabel (a tile's "Open").
        if self.mode == "detail" then return { { "X", "World map" } } end
        local hints = {}
        if not self.wide then hints[#hints + 1] = { "Y", "View" } end
        hints[#hints + 1] = { "X", "Search" }
        return hints
    end

    function page:GetFocusRows()
        if self.popup:IsShown() then return self.popup.rows or {} end
        if self.mode == "detail" then return self.detailRows or {} end
        return cat.focusRows or {}
    end

    -- The tracker re-read some zones (nil = all): redraw the catalogue's numbers, and the
    -- detail if it shows one of them, keeping focus on the same area.
    ns.Events.On("AZF_EXPLORATION_UPDATED", function(mapIDs)
        local zone = page.zone
        local hit = zone ~= nil and mapIDs == nil
        for _, id in ipairs(mapIDs or {}) do if zone and id == zone.mapID then hit = true end end
        if not page:IsShown() then
            page.dirty = true
            if hit then page.detailRows = nil end
            return
        end
        local current = ns.UI.CurrentTab() == "zones" and ns.Focus.Current()
        page.building = true
        cat:Refresh()
        page.building = false
        if hit and page.detail:IsShown() then
            show(zone, true)
            if page.mode == "detail" and not page.detailRows[1] then -- nothing left to focus in it
                page.mode = "list"
                page.pendingFocusKey = zone.mapID
            end
        elseif hit then
            page.detailRows = nil
        end
        if current and page.pendingFocusKey == nil then page.pendingFocusKey = current.key end
        if ns.UI.CurrentTab() == "zones" then refresh() end
    end)

    -- Quests (built, a turn-in, a level-up) or flight paths (a flight master's list) changed:
    -- every zone's numbers may have moved. Redraw like an exploration update of all zones.
    for _, msg in ipairs({ "AZF_QUESTS_UPDATED", "AZF_FLIGHTS_UPDATED" }) do
        ns.Events.On(msg, function()
            if not page:IsShown() then page.dirty = true; page.detailRows = nil; return end
            local current = ns.UI.CurrentTab() == "zones" and ns.Focus.Current()
            page.building = true
            cat:Refresh()
            page.building = false
            if page.zone and page.detail:IsShown() then show(page.zone, true) end
            if current and page.pendingFocusKey == nil then page.pendingFocusKey = current.key end
            if ns.UI.CurrentTab() == "zones" then refresh() end
        end)
    end

    -- Standing changed (a turn-in, a kill, the first read after login): only the detail shows
    -- reputation, so only it redraws (the dashboard's ledger, or a faction page), keeping focus.
    ns.Events.On("AZF_REPUTATION_UPDATED", function()
        if not page.zone then return end
        if not (page:IsShown() and page.detail:IsShown()) then page.detailRows = nil; page.dirty = true; return end
        local current = ns.UI.CurrentTab() == "zones" and ns.Focus.Current()
        show(page.zone, true)
        if current and page.pendingFocusKey == nil then page.pendingFocusKey = current.key end
        if ns.UI.CurrentTab() == "zones" then refresh() end
    end)

    -- Level-ups change "Your level"; redraw next time the page shows.
    ns.Events.On("AZF_LEVEL_CHANGED", function() page.dirty = true end)
    page:SetScript("OnShow", function(self)
        if self.dirty then
            self.dirty = false
            self.building = true
            cat:Refresh()
            self.building = false
            if self.zone and (self.mode == "detail" or self.wide) and not self.detailRows then show(self.zone, true) end
            refresh()
        end
    end)

    -- Leaving the tab another way (LB/RB) forgets where B would have returned to.
    page:SetScript("OnHide", function(self) self.returnTo = nil end)

    page:Layout() -- first layout: page.wide is nil, so this arranges and draws
    -- Open on the first zone, not the toolbar.
    if page.pendingFocusKey == nil and cat.firstZone then page.pendingFocusKey = cat.firstZone.mapID end
    return page
end

ns.UI.RegisterTab({
    id = "zones",
    label = "Zones",
    icon = ns.Theme.Icon("zones", "Interface\\Icons\\INV_Misc_Map_01"),
    order = 2,
    compactHeader = true,
    info = "Every zone: exploration, quests and flight paths.",
    build = build,
})
