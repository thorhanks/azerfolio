-- Zones tab: every zone the client's map tree lists, grouped by continent, as a scrolling list
-- in the native list style (gold group headers, row highlight). Names and continents come from
-- the client (Systems/Maps.lua); progress arrives with the progression service (Phase 5) and
-- Zone Detail with Phase 4 step 3. Uses the one-line character strip.
local _, ns = ...

local WHEEL_STEP = 72

local function header(parent, title, count)
    local T, L, S = ns.Theme, ns.Theme.layout, ns.Theme.space
    local h = CreateFrame("Frame", nil, parent)
    h:SetHeight(L.listHeader)
    local bg = h:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    T.SetAtlas(bg, T.atlas.listHeader)
    local text = T.Text(h, "md", "gold")
    text:SetPoint("LEFT", S.s3, 0)
    text:SetText(title)
    local n = T.Text(h, "xs", "dim")
    n:SetPoint("RIGHT", -S.s3, 0)
    n:SetText(count == 1 and "1 zone" or (count .. " zones"))
    return h
end

local function zoneRow(parent, zone)
    local T, L, S = ns.Theme, ns.Theme.layout, ns.Theme.space
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(L.listRow)
    T.RowHighlight(row, "HIGHLIGHT")          -- mouse hover
    local focusHi = T.RowHighlight(row)        -- controller focus
    focusHi:SetShown(false)
    function row:SetFocused(on) focusHi:SetShown(on) end

    local thumb = row:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(L.thumb[1], L.thumb[2])
    thumb:SetPoint("LEFT", S.s2, 0)
    local art = T.ZoneArt(zone.mapID)
    if art then thumb:SetTexture(art) else thumb:SetColorTexture(0, 0, 0, 0.5) end

    local name = T.Text(row, "md", "white")
    name:SetPoint("LEFT", thumb, "RIGHT", S.s3, 0)
    name:SetText(zone.name)
    return row
end

local function build(parent)
    local S, L = ns.Theme.space, ns.Theme.layout
    local page = CreateFrame("Frame", nil, parent)

    local scroll = CreateFrame("ScrollFrame", nil, page)
    scroll:SetPoint("TOPLEFT", 0, -S.s2)
    scroll:SetPoint("BOTTOMRIGHT", 0, S.s2)
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

    local sections = ns.Maps.Sections()
    local rows, y = {}, 0
    local function place(f, height)
        f:SetPoint("TOPLEFT", child, "TOPLEFT", L.listInset, -y)
        f:SetPoint("TOPRIGHT", child, "TOPRIGHT", -S.s6, -y)
        y = y + height
    end
    for si, s in ipairs(sections) do
        if si > 1 then y = y + S.s3 end
        place(header(child, s.title, #s.zones), L.listHeader + S.s1)
        for _, z in ipairs(s.zones) do
            local row = zoneRow(child, z)
            local item = { key = z.mapID, frame = row, title = z.name, detail = s.title, scroll = scroll,
                topGap = L.listHeader + S.s1 + S.s2 } -- keep the section header in view after a jump
            row:SetScript("OnEnter", function() ns.UI.SetInfo(item.title, item.detail) end)
            row:SetScript("OnLeave", function() ns.UI.RestoreInfo() end)
            place(row, L.listRow + 2)
            rows[#rows + 1] = { items = { item }, section = si }
        end
    end
    child:SetHeight(math.max(1, y))

    if #sections == 0 then
        local T = ns.Theme
        local empty = T.Text(page, "md", "dim")
        empty:SetPoint("CENTER")
        empty:SetText("The game didn't list any zone maps.")
    end

    page.scroll = scroll
    page.hasSections = #sections > 1
    function page:GetFocusRows() return rows end
    return page
end

ns.UI.RegisterTab({
    id = "zones",
    label = "Zones",
    icon = "Interface\\Icons\\INV_Misc_Map_01",
    order = 2,
    compactHeader = true,
    info = "Every zone, its art and its exploration.",
    sectionLabel = "Continent",
    build = build,
})
