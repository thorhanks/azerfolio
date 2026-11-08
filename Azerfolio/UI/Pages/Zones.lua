-- Zones tab, two views:
--   * list: every zone the client's map tree lists, grouped by continent (Systems/Maps.lua);
--   * detail: one zone's banner and its Explore areas, To discover / Discovered, read live from
--     the game (Systems/Exploration.lua).
-- A (or a click) opens a zone; B (or the Back button) returns to the list with the same zone
-- focused. In a wide window both views show side by side (see build). Uses the one-line
-- character strip.
local _, ns = ...

local WHEEL_STEP = 72

---------------------------------------------------------------------------------------------
-- Shared pieces
---------------------------------------------------------------------------------------------

local function newScroll(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    scroll:SetScript("OnSizeChanged", function(_, w) child:SetWidth(w) end)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local new = self:GetVerticalScroll() - delta * WHEEL_STEP
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange() or 0, new)))
    end)
    scroll:SetScript("OnVerticalScroll", function() ns.Focus.Update(false) end)
    scroll.child = child
    return scroll
end

local function header(parent)
    local T, L, S = ns.Theme, ns.Theme.layout, ns.Theme.space
    local h = CreateFrame("Frame", nil, parent)
    h:SetHeight(L.listHeader)
    local bg = h:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    T.SetAtlas(bg, T.atlas.listHeader)
    h.text = T.Text(h, "md", "gold")
    h.text:SetPoint("LEFT", S.s3, 0)
    h.count = T.Text(h, "xs", "dim")
    h.count:SetPoint("RIGHT", -S.s3, 0)
    return h
end

-- A focusable row with the native highlight (hover and controller focus).
local function focusRow(parent, height)
    local T = ns.Theme
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(height)
    T.RowHighlight(row, "HIGHLIGHT")
    local focusHi = T.RowHighlight(row)
    focusHi:SetShown(false)
    -- The bar shows while the row is focused or selected (the zone the split view shows).
    function row:SetFocused(on) self.focused = on; focusHi:SetShown(on or self.selected) end
    function row:SetSelected(on) self.selected = on; focusHi:SetShown(on or self.focused) end
    row:SetScript("OnEnter", function(self) if self.item then ns.UI.SetInfo(self.item.title, self.item.detail) end end)
    row:SetScript("OnLeave", function() ns.UI.RestoreInfo() end)
    return row
end

---------------------------------------------------------------------------------------------
-- List view
---------------------------------------------------------------------------------------------

local function buildList(page)
    local S, L, T = ns.Theme.space, ns.Theme.layout, ns.Theme
    local list = CreateFrame("Frame", nil, page)
    list:SetAllPoints()
    local scroll = newScroll(list)
    scroll:SetPoint("TOPLEFT", 0, -S.s2)
    scroll:SetPoint("BOTTOMRIGHT", 0, S.s2)
    local child = scroll.child

    -- The split view's divider on the list's right edge.
    list.edge = T.Solid(list, "divider", "BORDER")
    list.edge:SetPoint("TOPRIGHT"); list.edge:SetPoint("BOTTOMRIGHT"); list.edge:SetWidth(1)
    list.edge:Hide()

    local sections = ns.Maps.Sections()
    local rows, byMap, y = {}, {}, 0
    local function place(f, height)
        f:SetPoint("TOPLEFT", child, "TOPLEFT", L.listInset, -y)
        f:SetPoint("TOPRIGHT", child, "TOPRIGHT", -S.s6, -y)
        y = y + height
    end
    for si, s in ipairs(sections) do
        if si > 1 then y = y + S.s3 end
        local h = header(child)
        h.text:SetText(s.title)
        h.count:SetText(#s.zones == 1 and "1 zone" or (#s.zones .. " zones"))
        place(h, L.listHeader + S.s1)
        for _, z in ipairs(s.zones) do
            local row = focusRow(child, L.listRow)
            local thumb = row:CreateTexture(nil, "ARTWORK")
            thumb:SetSize(L.thumb[1], L.thumb[2])
            thumb:SetPoint("LEFT", S.s2, 0)
            local art = T.ZoneArt(z.mapID)
            if art then thumb:SetTexture(art) else thumb:SetColorTexture(0, 0, 0, 0.5) end
            local name = T.Text(row, "md", "white")
            name:SetPoint("LEFT", thumb, "RIGHT", S.s3, 0)
            name:SetText(z.name)
            local zone = { mapID = z.mapID, name = z.name, continent = s.title }
            row.item = {
                key = z.mapID, frame = row, title = z.name, detail = s.title, scroll = scroll,
                topGap = L.listHeader + S.s1 + S.s2, -- keep the section header in view after a jump
                actionLabel = "Open", zone = zone,
                onActivate = function() page:Open(zone) end,
                -- Split view: A only means something if the zone has areas to move into.
                canActivate = function()
                    return not page.wide or not (page.zone and page.zone.mapID == zone.mapID)
                        or (page.detailRows ~= nil and #page.detailRows > 0)
                end,
            }
            row:SetScript("OnClick", function() page:Click(zone) end)
            place(row, L.listRow + 2)
            rows[#rows + 1] = { items = { row.item }, section = si }
            byMap[z.mapID] = row
            list.firstZone = list.firstZone or zone
        end
    end
    child:SetHeight(math.max(1, y))

    if #sections == 0 then
        local empty = T.Text(list, "md", "dim")
        empty:SetPoint("CENTER")
        empty:SetText("The game didn't list any zone maps.")
    end
    list.rows = rows
    list.byMap = byMap
    list.sectionCount = #sections
    return list
end

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
    local row = focusRow(parent, L.checkRow)
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

    local scroll = newScroll(d)
    scroll:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", 0, -S.s3)
    scroll:SetPoint("BOTTOMRIGHT", 0, S.s2)
    d.scroll = scroll
    d.headers = { header(scroll.child), header(scroll.child) }
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

-- Fills the detail view for a zone. Returns the focus rows.
local function fillDetail(d, zone)
    local T, L, S = ns.Theme, ns.Theme.layout, ns.Theme.space
    local art = T.ZoneArt(zone.mapID)
    if art then d.banner.art:SetTexture(art) else d.banner.art:SetColorTexture(0, 0, 0, 1) end
    d.banner.mapID = zone.mapID
    cropBanner(d.banner)
    d.banner.name:SetText(zone.name)
    d.banner.sub:SetText(zone.continent or "")
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
-- Page
---------------------------------------------------------------------------------------------

-- The zone the player stands in, if the list has it.
local function playerZone(list)
    local here = C_Map and C_Map.GetBestMapForUnit
        and ns.Debug.Try("GetBestMapForUnit", C_Map.GetBestMapForUnit, "player")
    local row = here and list.byMap[here]
    return row and row.item.zone
end

-- Two modes: "list" (focus in the zone list) and "detail" (focus in a zone's areas).
-- Narrow window: one view at a time. Wide window (UI.IsWide): split view, the list on the
-- left and the selected zone's detail on the right, following focus; A moves into the
-- areas, B comes back.
local function build(parent)
    local page = CreateFrame("Frame", nil, parent)
    page.list = buildList(page)
    page.detail = buildDetail(page)
    page.mode = "list"

    local function arrange()
        local L = ns.Theme.layout
        local list, d = page.list, page.detail
        list:ClearAllPoints(); d:ClearAllPoints()
        if page.wide then
            list:SetPoint("TOPLEFT"); list:SetPoint("BOTTOMLEFT")
            list:SetWidth(L.splitListWidth)
            d:SetPoint("TOPLEFT", list, "TOPRIGHT")
            d:SetPoint("BOTTOMRIGHT")
        else
            list:SetAllPoints(); d:SetAllPoints()
        end
        list.edge:SetShown(page.wide)
        d.back:SetShown(not page.wide)
        for _, r in ipairs(list.rows) do r.items[1].actionLabel = page.wide and "Checklist" or "Open" end
    end

    -- Marks the zone the split view shows (none in the narrow window).
    local function markSelected()
        local id = page.wide and page.zone and page.zone.mapID
        for mapID, row in pairs(page.list.byMap) do
            local on = mapID == id
            if (row.selected or false) ~= on then row:SetSelected(on) end
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
        page.list:SetShown(page.wide or not inDetail)
        page.detail:SetShown(inDetail or (page.wide and page.zone ~= nil))
        page.hasSections = inDetail and page.detailRows and #page.detailRows > 0
            or (not inDetail and page.list.sectionCount > 1)
        page.sectionLabel = inDetail and "Section" or "Continent"
        page.backLabel = inDetail and "Back" or nil
        markSelected()
        ns.Focus.Rebuild()
        ns.UI.RefreshHints()
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

    -- A click on a zone row: in the split view it selects the zone and keeps focus in the list.
    function page:Click(zone)
        if not self.wide then return self:Open(zone) end
        self.mode = "list"
        show(zone)
        self.pendingFocusKey = zone.mapID
        refresh()
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
        arrange()
        if wide and self.mode == "list" then
            -- Show the focused zone, else the player's zone, else the first one.
            local item = ns.UI.CurrentTab() == "zones" and ns.Focus.Current()
            local zone = (item and item.zone) or self.zone or playerZone(self.list) or self.list.firstZone
            if zone then
                show(zone)
                self.pendingFocusKey = zone.mapID
            end
        end
        refresh()
    end

    -- B: back to the list with the same zone focused. Returns true if handled.
    function page:Back()
        if self.mode ~= "detail" then return false end
        self.mode = "list"
        self.pendingFocusKey = self.zone and self.zone.mapID
        refresh()
        return true
    end

    function page:GetFocusRows()
        if self.mode == "detail" then return self.detailRows or {} end
        return self.list.rows
    end

    page:Layout()
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
