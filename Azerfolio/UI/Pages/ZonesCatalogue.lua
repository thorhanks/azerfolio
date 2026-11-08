-- The Zones catalogue (spec §6, mockups/DESIGN.md "Zones"): a toolbar (status segments,
-- Level / Sort popups, zone count, search, Cards / List toggle) above illustrated cards
-- (default) or a compact list, grouped into sections. Data, filters, sorts and counts come from
-- ns.Zones; this file only draws them. Cards, rows and headers are pooled and reused on every
-- redraw. Used by UI/Pages/Zones.lua, which owns the page, Zone Detail and the split view.
local _, ns = ...

local Catalogue = {}
ns.ZonesCatalogue = Catalogue

local STATUS = {
    { "all", "All" }, { "progress", "In progress" }, { "untouched", "Untouched" }, { "complete", "Complete" },
}
-- Toolbar popups. `needs` = the ns.Zones.Available flag the option needs to be offered.
local OPTIONS = {
    { key = "faction", label = "Show", needs = "faction",
        items = { { "relevant", "Relevant to me" }, { "all", "All zones" } } },
    { key = "level", label = "Level", needs = "levels",
        items = { { "all", "All levels" }, { "appropriate", "For my level" } } },
    { key = "sort", label = "Sort",
        items = { { "recommended", "Recommended" }, { "alphabetical", "A-Z" }, { "highest", "Highest %" },
            { "lowest", "Lowest %" }, { "closest", "Closest to done" } } },
}
local VIEWS = { { "cards", "Cards" }, { "list", "List" } }
Catalogue.OPTIONS, Catalogue.STATUS, Catalogue.VIEWS = OPTIONS, STATUS, VIEWS

local STATE_EDGE = { complete = "complete", progress = "todo" }
local STATE_PCT = { complete = "complete", progress = "todo", untouched = "dim", unknown = "dim", untracked = "dim" }

local function label(option, value)
    for _, it in ipairs(option.items) do if it[1] == value then return it[2] end end
    return option.items[1][2]
end

local function settings() return ns.db.zones end
local function char() return ns.character or {} end

---------------------------------------------------------------------------------------------
-- Text for a zone (what the cards, rows and the info line say). Numbers come from Progression.
---------------------------------------------------------------------------------------------

local function levelText(z)
    if not z.minLevel then return nil end
    if z.minLevel == z.maxLevel then return "Lv " .. z.minLevel end
    return string.format("Lv %d-%d", z.minLevel, z.maxLevel)
end

local function countText(z)
    if z.state == "untracked" then return "not tracked" end
    local p = z.progress
    if not p or p.denominator == 0 then return "no data" end
    return string.format("%d/%d", p.completed, p.denominator)
end

local function percentText(z)
    if z.state == "untracked" then return "-" end
    return (z.progress and ns.Progression.PercentText(z.progress)) or "?"
end

-- The info line: what the card doesn't already say.
function Catalogue.ZoneDetail(z)
    local parts = { z.continent }
    if z.minLevel then
        parts[#parts + 1] = (z.minLevel == z.maxLevel and ("Level " .. z.minLevel)
            or string.format("Levels %d-%d", z.minLevel, z.maxLevel)) .. " (guide)"
    end
    if z.state == "untracked" then
        parts[#parts + 1] = "Exploration not tracked (no Explore achievement)"
    elseif not z.progress then
        parts[#parts + 1] = "No exploration data right now"
    else
        local p = z.progress
        local s = string.format("%d of %d discovered", p.completed, p.denominator)
        if p.completionUnknown > 0 then s = s .. string.format(", %d unknown", p.completionUnknown) end
        parts[#parts + 1] = s
        if z.uncertain then parts[#parts + 1] = "the game's list differs from the catalogue" end
    end
    return table.concat(parts, "  ·  ")
end

---------------------------------------------------------------------------------------------
-- Cards and rows
---------------------------------------------------------------------------------------------

local function newCard(parent)
    local T, L, S, W = ns.Theme, ns.Theme.layout, ns.Theme.space, ns.Widgets
    local c = CreateFrame("Button", nil, parent)
    c.bg = T.Solid(c, "cardBg", "BACKGROUND")
    c.bg:SetAllPoints()
    c.art = c:CreateTexture(nil, "BORDER")
    c.art:SetPoint("TOPLEFT", 1, -1); c.art:SetPoint("TOPRIGHT", -1, -1)
    c.edge = W.Edge(c, "ARTWORK")
    c.emblem = c:CreateTexture(nil, "OVERLAY")
    c.emblem:SetSize(L.checkIcon + 4, L.checkIcon + 4)
    c.emblem:SetPoint("TOPRIGHT", c.art, "TOPRIGHT", -S.s2, -S.s2)
    c.emblem:SetTexture(T.files.checkDone)
    if c.emblem.SetDesaturated then c.emblem:SetDesaturated(true) end
    c.emblem:SetVertexColor(T.RGB("complete"))
    c.name = T.Text(c, "md", "white")
    c.name:SetPoint("TOPLEFT", c.art, "BOTTOMLEFT", S.s3, -S.s2)
    c.name:SetJustifyH("LEFT"); c.name:SetWordWrap(false)
    c.pct = T.Text(c, "md", "text")
    c.pct:SetPoint("TOPRIGHT", c.art, "BOTTOMRIGHT", -S.s3, -S.s2)
    c.name:SetPoint("RIGHT", c.pct, "LEFT", -S.s2, 0)
    c.pips = W.Pips(c)
    c.pips:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -S.s2)
    c.lv = T.Text(c, "xs", "dim")
    c.lv:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", S.s3, S.s3)
    c.fit = T.Text(c, "xs", "fit")
    c.fit:SetPoint("LEFT", c.lv, "RIGHT", S.s2, 0)
    c.fit:SetText("Your level")
    c.n = T.Text(c, "xs", "dim")
    c.n:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -S.s3, S.s3)
    function c:SetFocused(on)
        self.focused = on
        self:Paint()
    end
    function c:Paint()
        local z = self.zone
        if self.focused then
            self.edge:SetColor("focus"); self.edge:SetThickness(2)
        else
            self.edge:SetColor(STATE_EDGE[z and z.state] or "cardEdge"); self.edge:SetThickness(1)
        end
    end
    W.HoverInfo(c)
    return c
end

local function fillCard(c, z, width)
    local T, L, S = ns.Theme, ns.Theme.layout, ns.Theme.space
    local artH = math.floor(width * L.cardArtAspect + 0.5)
    c:SetSize(width, artH + L.cardBody)
    c.art:SetHeight(artH)
    local art = T.ZoneArt(z.mapID)
    if art then c.art:SetTexture(art) else c.art:SetColorTexture(0, 0, 0, 1) end
    local top, bottom = T.BannerCrop(z.mapID, width, artH)
    c.art:SetTexCoord(0, 1, top, bottom)
    local grey = z.state == "untouched" or z.state == "untracked"
    if c.art.SetDesaturated then c.art:SetDesaturated(grey) end
    local dim = z.state == "untracked" and 0.45 or (grey and 0.7 or 1)
    c.art:SetVertexColor(dim, dim, dim)
    c.emblem:SetShown(z.state == "complete")
    c.name:SetText(z.name)
    c.name:SetTextColor(T.RGB(grey and "dim" or "white"))
    c.pct:SetText(percentText(z))
    c.pct:SetTextColor(T.RGB(STATE_PCT[z.state] or "dim"))
    local p = z.progress
    c.pips:SetShown(p ~= nil)
    if p then c.pips:Set(p.complete, p.incomplete, p.completionUnknown, width - 2 * S.s3) end
    c.lv:SetText(levelText(z) or "Lv ?")
    c.fit:SetShown(z.state ~= "complete" and ns.Zones.FitsLevel(z, char().level))
    c.n:SetText(countText(z))
    c.zone = z
    c:Paint()
end

local function newRow(parent)
    local T, L, S, W = ns.Theme, ns.Theme.layout, ns.Theme.space, ns.Widgets
    local r = W.FocusRow(parent, L.zoneRow)
    r.thumb = r:CreateTexture(nil, "ARTWORK")
    r.thumb:SetSize(L.zoneThumb[1], L.zoneThumb[2])
    r.thumb:SetPoint("LEFT", S.s2, 0)
    r.mark = T.Solid(r, "complete", "ARTWORK")
    r.mark:SetPoint("TOPLEFT"); r.mark:SetPoint("BOTTOMLEFT"); r.mark:SetWidth(3)
    r.pct = T.Text(r, "sm", "text")
    r.pct:SetPoint("RIGHT", r, "RIGHT", -S.s2, 0)
    r.pct:SetWidth(L.pctWidth); r.pct:SetJustifyH("RIGHT")
    -- Level column, on one line in the row's middle: "Lv a-b" then the bar.
    r.lvbar = W.LevelBar(r)
    r.lvbar:SetPoint("RIGHT", r.pct, "LEFT", -S.s3, 0)
    r.lv = T.Text(r, "xs", "dim")
    r.lv:SetPoint("RIGHT", r.lvbar, "LEFT", -S.s2, 0)
    r.lv:SetWidth(L.levelTextWidth); r.lv:SetJustifyH("RIGHT")
    r.name = T.Text(r, "md", "white")
    r.name:SetPoint("TOPLEFT", r.thumb, "TOPRIGHT", S.s3, 2)
    r.name:SetPoint("RIGHT", r.lv, "LEFT", -S.s3, 0)
    r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
    r.pips = W.Pips(r)
    r.pips:SetPoint("BOTTOMLEFT", r.thumb, "BOTTOMRIGHT", S.s3, 2)
    r.note = T.Text(r, "xs", "dim")
    return r
end

local function fillRow(r, z, width)
    local T, L, S = ns.Theme, ns.Theme.layout, ns.Theme.space
    local art = T.ZoneArt(z.mapID)
    if art then r.thumb:SetTexture(art) else r.thumb:SetColorTexture(0, 0, 0, 0.5) end
    local grey = z.state == "untouched" or z.state == "untracked"
    if r.thumb.SetDesaturated then r.thumb:SetDesaturated(grey) end
    local dim = z.state == "untracked" and 0.45 or 1
    r.thumb:SetVertexColor(dim, dim, dim)
    r.name:SetText(z.name)
    r.name:SetTextColor(T.RGB(grey and "dim" or "white"))
    local edge = STATE_EDGE[z.state]
    r.mark:SetShown(edge ~= nil)
    if edge then local cr, cg, cb = T.RGB(edge); r.mark:SetColorTexture(cr, cg, cb, 1) end
    r.pct:SetText(z.state == "complete" and ("|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t " .. percentText(z))
        or percentText(z))
    r.pct:SetTextColor(T.RGB(STATE_PCT[z.state] or "dim"))
    r.lv:SetText(levelText(z) or "Lv ?")
    r.lvbar:Set(z.minLevel, z.maxLevel, char().level, ns.Zones.FitsLevel(z, char().level))
    -- The split view's narrow list keeps the level text and drops the bar (room for pips).
    local compact = width < L.levelBarMinRow
    r.lvbar:SetShown(not compact)
    r.lv:ClearAllPoints()
    if compact then
        r.lv:SetPoint("RIGHT", r.pct, "LEFT", -S.s3, 0)
    else
        r.lv:SetPoint("RIGHT", r.lvbar, "LEFT", -S.s2, 0)
    end
    local p = z.progress
    r.pips:SetShown(p ~= nil)
    r.note:ClearAllPoints()
    -- Room for pips: the name column minus the "n/m" note.
    local bar = compact and 0 or (S.s2 + L.levelBarWidth)
    local room = width - (S.s2 + L.zoneThumb[1] + S.s3)
        - (L.levelTextWidth + bar + S.s3 + L.pctWidth + S.s2 + S.s3) - 60
    if p then
        local used = r.pips:Set(p.complete, p.incomplete, p.completionUnknown, math.max(40, room))
        r.note:SetPoint("LEFT", r.pips, "LEFT", used + S.s2, 0)
    else
        r.note:SetPoint("BOTTOMLEFT", r.thumb, "BOTTOMRIGHT", S.s3, 0)
    end
    r.note:SetText(z.state == "untracked" and "Exploration not tracked" or countText(z))
    r.zone = z
end

---------------------------------------------------------------------------------------------
-- The catalogue object
---------------------------------------------------------------------------------------------

-- Builds the toolbar and list frames for `page` (positioned by the page). Returns the object.
-- page must implement Open(zone), Click(zone), OpenPopup(option, control), and have `wide`.
function Catalogue.New(page)
    local T, L, S, W = ns.Theme, ns.Theme.layout, ns.Theme.space, ns.Widgets
    local cat = { cards = {}, rows = {}, headers = {}, controls = {}, byMap = {} }

    -- Toolbar ---------------------------------------------------------------------------------
    local tb = CreateFrame("Frame", nil, page)
    tb:SetHeight(L.toolbarHeight)
    local shade = T.Solid(tb, "black", "BACKGROUND", 0.28)
    shade:SetAllPoints()
    local rule = T.Solid(tb, "divider", "BORDER")
    rule:SetPoint("BOTTOMLEFT"); rule:SetPoint("BOTTOMRIGHT"); rule:SetHeight(1)
    cat.toolbar = tb

    local function control(key, title, detail, onActivate, actionLabel)
        local b = W.Control(tb)
        b.item = { key = key, frame = b, title = title, detail = detail, onActivate = onActivate,
            actionLabel = actionLabel }
        b:SetScript("OnClick", function() onActivate(b.item) end)
        cat.controls[#cat.controls + 1] = b
        return b
    end

    cat.status = {}
    for _, s in ipairs(STATUS) do
        local value = s[1]
        cat.status[#cat.status + 1] = control("tb:status:" .. value, s[2],
            value == "all" and "Show every zone." or ("Show only zones confirmed " .. s[2]:lower() .. "."),
            function() settings().completion = value; cat:Refresh() end, "Show")
        cat.status[#cat.status].value = value
    end
    cat.options = {}
    for _, o in ipairs(OPTIONS) do
        local b = control("tb:" .. o.key, o.label, "Press A to choose.", function()
            page:OpenPopup(o, cat.options[o.key])
        end, "Choose")
        b.option = o
        cat.options[o.key] = b
    end
    cat.count = T.Text(tb, "xs", "dim")

    -- Search: a plain edit box in a control frame. A or X focuses it; Enter or Escape leaves.
    local search = control("tb:search", "Search", "Type part of a zone's name. Enter or Escape to finish.",
        function() cat:FocusSearch() end, "Type")
    search:SetWidth(L.searchWidth)
    search.text:Hide()
    local box = CreateFrame("EditBox", nil, search)
    box:SetPoint("TOPLEFT", L.controlPad, 0); box:SetPoint("BOTTOMRIGHT", -L.controlPad, 0)
    box:SetAutoFocus(false)
    box:SetMaxLetters(40)
    T.SetFont(box, "sm")
    box:SetTextColor(T.RGB("white"))
    box.hint = T.Text(search, "sm", "dim")
    box.hint:SetPoint("LEFT", L.controlPad, 0)
    box.hint:SetText("Search")
    box:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        self.hint:SetShown(text == "")
        if text ~= (cat.searchText or "") then
            cat.searchText = text
            ns.Events.Debounce("zones-search", 0.15, function() cat:Refresh() end)
        end
    end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    cat.search, cat.searchBox = search, box

    cat.views = {}
    for _, v in ipairs(VIEWS) do
        local value = v[1]
        local b = control("tb:view:" .. value, v[2] .. " view", "Y cycles the views.", function()
            settings().displayMode = value; cat:Refresh()
        end, "Switch")
        b.value = value
        cat.views[#cat.views + 1] = b
    end

    -- List -------------------------------------------------------------------------------------
    local list = CreateFrame("Frame", nil, page)
    local scroll = W.Scroll(list)
    scroll:SetPoint("TOPLEFT", 0, -S.s2)
    scroll:SetPoint("BOTTOMRIGHT", 0, S.s2)
    cat.list, cat.scroll = list, scroll
    -- The split view's divider on the list's right edge.
    list.edge = T.Solid(list, "divider", "BORDER")
    list.edge:SetPoint("TOPRIGHT"); list.edge:SetPoint("BOTTOMRIGHT"); list.edge:SetWidth(1)
    list.edge:Hide()
    cat.emptyTitle = T.Text(scroll.child, "lg", "gold")
    cat.emptyTitle:SetPoint("TOP", 0, -60)
    cat.emptyText = T.Text(scroll.child, "md", "dim")
    cat.emptyText:SetPoint("TOP", cat.emptyTitle, "BOTTOM", 0, -S.s2)
    -- Cards re-flow when the width changes their column count.
    scroll.onWidth = function()
        if cat.view == "cards" and cat.columns ~= cat:Columns() then cat:Refresh() end
    end

    ---------------------------------------------------------------------------------------------

    -- The width the list draws into (before the first layout, from the window).
    function cat:Width()
        local w = self.scroll:GetWidth() or 0
        if w <= 1 then
            local f = ns.UI.GetFrame()
            w = page.wide and L.splitListWidth or ((f and f:GetWidth() or 1160) - 2 * L.edgeInset)
        end
        return w
    end

    function cat:Columns()
        local inner = self:Width() - L.listInset - S.s6
        return math.max(1, math.floor((inner + L.cardGap) / (L.cardMinWidth + L.cardGap)))
    end

    -- The view in use: the split view's list is always the compact list.
    function cat:View()
        if page.wide then return "list" end
        return settings().displayMode == "list" and "list" or "cards"
    end

    function cat:CycleView()
        if page.wide then return false end
        settings().displayMode = self:View() == "cards" and "list" or "cards"
        self:Refresh()
        return true
    end

    function cat:FocusSearch()
        self.searchBox:SetFocus()
    end

    function cat:SearchHasFocus()
        return self.searchBox.HasFocus and self.searchBox:HasFocus() or false
    end

    -- The filters in effect: a filter whose data is unknown everywhere is left out (all).
    function cat:Options(available)
        local s = settings()
        return {
            completion = s.completion,
            faction = available.faction and s.faction or "all",
            level = available.levels and s.level or "all",
            sort = s.sort,
            search = self.searchText,
        }
    end

    local function layoutToolbar(available)
        local s, x = settings(), L.listInset
        local function place(b)
            b:ClearAllPoints()
            b:SetPoint("LEFT", tb, "LEFT", x, 0)
            x = x + b:GetWidth() + S.s2
            b:Show()
        end
        for _, b in ipairs(cat.status) do
            b:SetLabel(b.item.title)
            b:SetOn(s.completion == b.value)
            place(b)
        end
        x = x + S.s2
        for _, o in ipairs(OPTIONS) do
            local b = cat.options[o.key]
            if o.needs and not available[o.needs] then
                b:Hide()
            else
                b:SetLabel(o.label .. ": |cffffd100" .. label(o, s[o.key]) .. "|r")
                b.item.detail = label(o, s[o.key]) .. ". Press A to choose."
                place(b)
            end
        end
        cat.count:ClearAllPoints()
        cat.count:SetPoint("LEFT", tb, "LEFT", x + S.s1, 0)
        -- Right side: view toggle (not in the split view), then search to its left.
        local right = S.s4
        for i = #cat.views, 1, -1 do
            local b = cat.views[i]
            b:SetShown(not page.wide)
            if not page.wide then
                b:SetLabel(VIEWS[i][2])
                b:SetOn(cat:View() == b.value)
                b:ClearAllPoints()
                b:SetPoint("RIGHT", tb, "RIGHT", -right, 0)
                right = right + b:GetWidth() + (i == 1 and S.s3 or 0)
            end
        end
        -- Narrow windows: drop the count first, then shrink the search box.
        local width = tb:GetWidth() or 0
        if width <= 1 then local f = ns.UI.GetFrame(); width = (f and f:GetWidth() or 1160) - 2 * L.edgeInset end
        local countEnd = x + S.s1 + (cat.count:GetStringWidth() or 0)
        local searchW = L.searchWidth
        local room = width - right - countEnd - S.s3
        cat.count:SetShown(room >= searchW)
        if room < searchW then room = width - right - x - S.s2 end
        searchW = math.max(90, math.min(L.searchWidth, room))
        cat.search:SetWidth(searchW)
        cat.search:ClearAllPoints()
        cat.search:SetPoint("RIGHT", tb, "RIGHT", -right, 0)
        cat.search:Show()
    end

    -- A resized window re-fits the toolbar (count and search width).
    tb:SetScript("OnSizeChanged", function()
        if cat.available then layoutToolbar(cat.available) end
    end)

    local function toolbarRow()
        local items = {}
        for _, b in ipairs(cat.status) do items[#items + 1] = b.item end
        for _, o in ipairs(OPTIONS) do
            local b = cat.options[o.key]
            if b:IsShown() then items[#items + 1] = b.item end
        end
        items[#items + 1] = cat.search.item
        for _, b in ipairs(cat.views) do if b:IsShown() then items[#items + 1] = b.item end end
        return { items = items, section = 0 }
    end

    local function zoneObject(z)
        return { mapID = z.mapID, name = z.name, continent = z.continent, minLevel = z.minLevel,
            maxLevel = z.maxLevel, entry = z }
    end

    local function zoneItem(frame, z)
        local zone = zoneObject(z)
        frame.item = {
            key = z.mapID, frame = frame, title = z.name, detail = Catalogue.ZoneDetail(z), scroll = scroll,
            topGap = L.listHeader + S.s1 + S.s2, zone = zone,
            actionLabel = page.wide and "Checklist" or "Open",
            onActivate = function() page:Open(zone) end,
            -- Split view: A only means something if the zone has areas to move into.
            canActivate = function()
                return not page.wide or not (page.zone and page.zone.mapID == zone.mapID)
                    or (page.detailRows ~= nil and #page.detailRows > 0)
            end,
        }
        frame:SetScript("OnClick", function() page:Click(zone) end)
        return frame.item
    end

    -- Re-reads the zones, applies the filters and redraws. Keeps focus on the same key.
    function cat:Refresh()
        local all = ns.Zones.All()
        local available = ns.Zones.Available(all)
        local opts = self:Options(available)
        local q = ns.Zones.Query(all, opts, char())
        self.query, self.view, self.available = q, self:View(), available
        self.count:SetText(q.shown == q.total and (q.total .. " zones") or string.format("%d of %d zones", q.shown, q.total))
        layoutToolbar(available)

        for _, c in ipairs(self.cards) do c:Hide() end
        for _, r in ipairs(self.rows) do r:Hide() end
        for _, h in ipairs(self.headers) do h:Hide() end
        local child, width = scroll.child, self:Width()
        local rows, byMap, used = { toolbarRow() }, {}, { cards = 0, rows = 0, headers = 0 }
        local function take(kind, make)
            used[kind] = used[kind] + 1
            local f = self[kind][used[kind]]
            if not f then f = make(child); self[kind][used[kind]] = f end
            f:ClearAllPoints()
            f:Show()
            return f
        end

        local empty = q.shown == 0
        self.emptyTitle:SetShown(empty); self.emptyText:SetShown(empty)
        if empty then
            self.emptyTitle:SetText("No zones match")
            self.emptyText:SetText(opts.search and opts.search ~= "" and "Try another name, or clear the search."
                or "Try a different status or filter.")
        end

        local y, inner = 0, width - L.listInset - S.s6
        local cols = self:Columns()
        self.columns = cols
        local cardW = math.floor((inner - (cols - 1) * L.cardGap) / cols)
        for gi, g in ipairs(q.groups) do
            if g.title then
                if gi > 1 then y = y + S.s3 end
                local h = take("headers", W.Header)
                h:SetPoint("TOPLEFT", child, "TOPLEFT", L.listInset, -y)
                h:SetPoint("TOPRIGHT", child, "TOPRIGHT", -S.s6, -y)
                h.text:SetText(g.title)
                h.count:SetText(g.tracked == 0 and "not tracked" or string.format("%d of %d complete", g.complete, g.tracked))
                y = y + L.listHeader + S.s2
            end
            if self.view == "cards" then
                for i = 1, #g.zones, cols do
                    local items, rowH = {}, 0
                    for col = 0, cols - 1 do
                        local z = g.zones[i + col]
                        if z then
                            local c = take("cards", newCard)
                            fillCard(c, z, cardW)
                            c:SetPoint("TOPLEFT", child, "TOPLEFT", L.listInset + col * (cardW + L.cardGap), -y)
                            items[#items + 1] = zoneItem(c, z)
                            byMap[z.mapID] = c
                            rowH = c:GetHeight()
                        end
                    end
                    rows[#rows + 1] = { items = items, section = gi }
                    y = y + rowH + L.cardGap
                end
            else
                for _, z in ipairs(g.zones) do
                    local r = take("rows", newRow)
                    r:SetPoint("TOPLEFT", child, "TOPLEFT", L.listInset, -y)
                    r:SetPoint("TOPRIGHT", child, "TOPRIGHT", -S.s6, -y)
                    fillRow(r, z, width - L.listInset - S.s6)
                    rows[#rows + 1] = { items = { zoneItem(r, z) }, section = gi }
                    byMap[z.mapID] = r
                    y = y + L.zoneRow + 2
                end
            end
        end
        child:SetHeight(math.max(1, y))
        self.focusRows, self.byMap = rows, byMap
        self.sectionCount = #q.groups
        self.firstZone = q.zones[1] and zoneObject(q.zones[1]) or nil
        if page.OnCatalogueChanged then page:OnCatalogueChanged() end
    end

    -- The zone object for a mapID that's in the current list, or nil.
    function cat:ZoneFor(mapID)
        local f = self.byMap[mapID]
        return f and f.item and f.item.zone
    end

    return cat
end
