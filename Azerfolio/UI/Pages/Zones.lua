-- Zones tab, two views:
--   * catalogue (UI/Pages/ZonesCatalogue.lua): toolbar plus illustrated cards or a compact
--     list of every zone, filtered, sorted and grouped by ns.Zones;
--   * detail: one zone's banner and its Explore areas, To discover / Discovered, read live from
--     the game (Systems/Exploration.lua).
-- A (or a click) opens a zone; B (or the Back button) returns to the catalogue with the same
-- zone focused. Y cycles Cards / List, X searches. Level and Sort open a small popup. In a wide
-- window the list and the detail show side by side (see build). Uses the one-line strip.
local _, ns = ...

---------------------------------------------------------------------------------------------
-- Detail view
---------------------------------------------------------------------------------------------

-- Crops the 2:1 zone art to the banner, centred on the zone's landmark (Theme.bannerFocus).
local function cropBanner(banner)
    local w, h = banner:GetWidth(), banner:GetHeight()
    if not (w and h and w > 0) then return end
    local top, bottom = ns.Theme.BannerCrop(banner.mapID, w, h)
    banner.art:SetTexCoord(0, 1, top, bottom)
end

local function checkRow(parent)
    local T, L, S = ns.Theme, ns.Theme.layout, ns.Theme.space
    local row = ns.Widgets.FocusRow(parent, L.checkRow)
    row.done = row:CreateTexture(nil, "ARTWORK")
    row.done:SetSize(L.checkIcon, L.checkIcon)
    row.done:SetPoint("LEFT", S.s2, 0)
    row.done:SetTexture(T.files.checkDone)
    -- The client's check is green; the state language says discovered = gold.
    if row.done.SetDesaturated then row.done:SetDesaturated(true) end
    row.done:SetVertexColor(T.RGB("complete"))
    row.todo = row:CreateTexture(nil, "ARTWORK")
    row.todo:SetSize(L.checkIcon - 8, L.checkIcon - 8)
    row.todo:SetPoint("CENTER", row.done, "CENTER")
    row.todo:SetColorTexture(T.RGB("todo"))
    local mask = row:CreateMaskTexture()
    if mask then
        mask:SetAllPoints(row.todo)
        mask:SetTexture(T.circleMask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        pcall(row.todo.AddMaskTexture, row.todo, mask)
    end
    row.name = T.Text(row, "sm", "white")
    row.name:SetPoint("LEFT", row.done, "RIGHT", S.s2, 0)
    row.name:SetPoint("RIGHT", row, "RIGHT", -S.s2, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    return row
end

local function buildDetail(page)
    local T, L, S = ns.Theme, ns.Theme.layout, ns.Theme.space
    local d = CreateFrame("Frame", nil, page)
    d:SetAllPoints()
    d:Hide()

    local banner = CreateFrame("Frame", nil, d)
    banner:SetPoint("TOPLEFT"); banner:SetPoint("TOPRIGHT")
    banner:SetHeight(L.bannerHeight)
    banner.art = banner:CreateTexture(nil, "BACKGROUND")
    banner.art:SetAllPoints()
    banner:SetScript("OnSizeChanged", cropBanner)
    local shade = banner:CreateTexture(nil, "BORDER")
    shade:SetAllPoints()
    shade:SetColorTexture(1, 1, 1, 1)
    local ok = type(CreateColor) == "function" and pcall(shade.SetGradient, shade, "HORIZONTAL",
        CreateColor(0, 0, 0, 0.85), CreateColor(0, 0, 0, 0.15))
    if not ok then shade:SetColorTexture(0, 0, 0, 0.5) end
    local rule = T.Solid(banner, "divider", "ARTWORK")
    rule:SetPoint("BOTTOMLEFT"); rule:SetPoint("BOTTOMRIGHT"); rule:SetHeight(2)
    banner.name = T.Text(banner, "xxl", "gold")
    banner.name:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", S.s6, S.s6 + S.s2)
    banner.sub = T.Text(banner, "sm", "text")
    banner.sub:SetPoint("TOPLEFT", banner.name, "BOTTOMLEFT", 0, -S.s1)
    local back = CreateFrame("Button", nil, banner, "UIPanelButtonTemplate")
    back:SetSize(96, 24)
    back:SetPoint("TOPRIGHT", -S.s4, -S.s3)
    back:SetText("Zones")
    back:SetScript("OnClick", function() page:Back() end)
    d.back = back
    d.banner = banner

    local scroll = ns.Widgets.Scroll(d)
    scroll:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", 0, -S.s3)
    scroll:SetPoint("BOTTOMRIGHT", 0, S.s2)
    d.scroll = scroll
    d.headers = { ns.Widgets.Header(scroll.child), ns.Widgets.Header(scroll.child) }
    d.message = T.Text(scroll.child, "md", "dim")
    d.message:SetPoint("TOPLEFT", L.listInset, -S.s4)
    d.message:SetPoint("RIGHT", scroll.child, "RIGHT", -S.s6, 0)
    d.message:SetJustifyH("LEFT")
    d.pool = {}
    return d
end

local MESSAGES = {
    untracked = "The game has no Explore achievement for %s, so Azerfolio can't track its exploration.",
    unavailable = "The game isn't returning achievement data right now. Try again in a moment.",
}

-- The banner's second line: continent and level range (from the zone guide).
local function bannerSub(zone)
    local parts = { zone.continent }
    if zone.minLevel then
        parts[#parts + 1] = zone.minLevel == zone.maxLevel and ("Level " .. zone.minLevel)
            or string.format("Levels %d-%d", zone.minLevel, zone.maxLevel)
    end
    return table.concat(parts, "  ·  ")
end

-- Fills the detail view for a zone. Returns the focus rows.
local function fillDetail(d, zone)
    local T, L, S = ns.Theme, ns.Theme.layout, ns.Theme.space
    local art = T.ZoneArt(zone.mapID)
    if art then d.banner.art:SetTexture(art) else d.banner.art:SetColorTexture(0, 0, 0, 1) end
    d.banner.mapID = zone.mapID
    cropBanner(d.banner)
    d.banner.name:SetText(zone.name)
    d.banner.sub:SetText(bannerSub(zone))
    d.scroll:SetVerticalScroll(0)

    for _, r in ipairs(d.pool) do r:Hide() end
    for _, h in ipairs(d.headers) do h:Hide() end
    d.message:Hide()

    local ex = ns.Exploration.ForZone(zone)
    local rows, child = {}, d.scroll.child
    if ex.status ~= "tracked" then
        d.message:SetText(string.format(MESSAGES[ex.status] or MESSAGES.unavailable, zone.name))
        d.message:Show()
        child:SetHeight(100)
        return rows, ex
    end

    local groups = { { title = "To discover", list = {} }, { title = "Discovered", list = {} } }
    for _, c in ipairs(ex.objectives) do
        if c.completion == "complete" then table.insert(groups[2].list, c)
        elseif c.completion == "incomplete" then table.insert(groups[1].list, c) end
    end
    local counts = { ex.progress.remaining, ex.progress.completed }

    local y, used = 0, 0
    for gi, g in ipairs(groups) do
        if gi > 1 then y = y + S.s3 end
        local h = d.headers[gi]
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", child, "TOPLEFT", L.listInset, -y)
        h:SetPoint("TOPRIGHT", child, "TOPRIGHT", -S.s6, -y)
        h.text:SetText(g.title)
        h.count:SetText(counts[gi] == 1 and "1 area" or (counts[gi] .. " areas"))
        h:Show()
        y = y + L.listHeader + S.s1
        if #g.list == 0 then y = y + S.s2 end
        for i = 1, #g.list, 2 do
            local items = {}
            for col = 0, 1 do
                local c = g.list[i + col]
                if c then
                    used = used + 1
                    local row = d.pool[used]
                    if not row then row = checkRow(child); d.pool[used] = row end
                    row:ClearAllPoints()
                    if col == 0 then
                        row:SetPoint("TOPLEFT", child, "TOPLEFT", L.listInset, -y)
                        row:SetPoint("TOPRIGHT", child, "TOP", -S.s2, -y)
                    else
                        row:SetPoint("TOPLEFT", child, "TOP", S.s2 + L.listInset / 2, -y)
                        row:SetPoint("TOPRIGHT", child, "TOPRIGHT", -S.s6, -y)
                    end
                    local done = c.completion == "complete"
                    row.done:SetShown(done)
                    row.todo:SetShown(not done)
                    row.name:SetText(c.name or "?")
                    row.name:SetTextColor(T.RGB(done and "dim" or "white"))
                    row.item = { key = "c" .. tostring(c.id), frame = row, title = c.name,
                        detail = done and "Discovered" or "Not discovered yet", scroll = d.scroll,
                        topGap = L.listHeader + S.s1 + S.s2 }
                    row:Show()
                    items[#items + 1] = row.item
                end
            end
            rows[#rows + 1] = { items = items, section = gi }
            y = y + L.checkRow + 2
        end
    end
    child:SetHeight(math.max(1, y))
    return rows, ex
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
    page.detail = buildDetail(page)
    page.popup = buildPopup(page)

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

    -- Fills the detail view for `zone` (re-read from the game when `force`).
    local function show(zone, force)
        if not force and page.zone and page.zone.mapID == zone.mapID and page.detailRows then return end
        page.zone = zone
        page.detailRows = fillDetail(page.detail, zone)
    end

    local function refresh()
        local inDetail = page.mode == "detail"
        page.toolbar:SetShown(page.wide or not inDetail)
        page.list:SetShown(page.wide or not inDetail)
        page.detail:SetShown(inDetail or (page.wide and page.zone ~= nil))
        if page.popup:IsShown() then
            page.hasSections, page.backLabel = false, "Close"
        else
            page.hasSections = inDetail and page.detailRows and #page.detailRows > 0
                or (not inDetail and cat.sectionCount > 1)
            page.sectionLabel = "Section"
            page.backLabel = inDetail and "Back" or nil
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

    -- A on a zone: open its detail (narrow) or move into its areas (wide).
    function page:Open(zone)
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
        self.mode = "list"
        self.pendingFocusKey = self.zone and self.zone.mapID
        refresh()
        return true
    end

    -- X: search; Y: next view. Only on the catalogue.
    function page:OnButton(name)
        if self.popup:IsShown() or (self.mode == "detail" and not self.wide) then return false end
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
        if self.popup:IsShown() or (self.mode == "detail" and not self.wide) then return {} end
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

    -- Level-ups change "Your level"; redraw next time the page shows.
    ns.Events.On("AZF_CHARACTER_UPDATED", function() page.dirty = true end)
    page:SetScript("OnShow", function(self)
        if self.dirty then
            self.dirty = false
            self.building = true
            cat:Refresh()
            self.building = false
            refresh()
        end
    end)

    page:Layout() -- first layout: page.wide is nil, so this arranges and draws
    -- Open on the first zone, not the toolbar.
    if page.pendingFocusKey == nil and cat.firstZone then page.pendingFocusKey = cat.firstZone.mapID end
    return page
end

ns.UI.RegisterTab({
    id = "zones",
    label = "Zones",
    icon = "Interface\\Icons\\INV_Misc_Map_01",
    order = 2,
    compactHeader = true,
    info = "Every zone, its art and its exploration.",
    build = build,
})
