-- The Zones catalogue (spec §6, mockups/DESIGN.md "Zones"): a toolbar (status segments,
-- Level / Sort popups, zone count, search, Cards / List toggle) above the big art cards
-- (default; Phase 16 task 7: the Dungeons cards' look, three across, 16:10, frame A, the zone's
-- art in the living Atlas's sepia wash with colour fading in by %), a compact list grouped into
-- sections, or the Atlas (UI/AtlasChart.lua). Data, filters, sorts and counts come from
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
local VIEWS = { { "cards", "Cards" }, { "list", "List" }, { "atlas", "Atlas" } }
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

-- The zone's combined percentage (spec §7.7), from Progression.
local function percentText(z)
    if z.state == "untracked" then return "-" end
    return (z.combined and ns.Progression.PercentText(z.combined)) or "?"
end

-- One phrase per category for the info line: "Exploration 7 of 12", "Quests 42 of 68 (2 unchecked)".
function Catalogue.CategoryText(z)
    local out = {}
    for _, c in ipairs(z.cats or {}) do
        local meta = ns.Theme.category[c.key]
        if c.pending then
            out[#out + 1] = meta.label .. (c.pending == "flightmaster" and ": visit a flight master to check"
                or c.pending == "building" and ": reading QuestieDB" or ": not readable right now")
        else
            local s = string.format("%s %d of %d", meta.label, c.completed, c.denominator)
            if c.unchecked and c.unchecked > 0 then s = s .. string.format(" (%d unchecked)", c.unchecked) end
            out[#out + 1] = s
        end
    end
    return out
end

-- The info line: what the card doesn't already say.
function Catalogue.ZoneDetail(z)
    local parts = { z.continent }
    if z.minLevel then
        parts[#parts + 1] = (z.minLevel == z.maxLevel and ("Level " .. z.minLevel)
            or string.format("Levels %d-%d", z.minLevel, z.maxLevel)) .. " (guide)"
    end
    if z.faction == "Alliance" or z.faction == "Horde" then
        parts[#parts + 1] = z.faction .. " territory"
    elseif z.faction == "Contested" then
        parts[#parts + 1] = "Contested"
    end
    if z.state == "untracked" then
        parts[#parts + 1] = "Nothing tracked here (no Explore achievement, quests or flight paths)"
    else
        for _, s in ipairs(Catalogue.CategoryText(z)) do parts[#parts + 1] = s end
        if z.uncertain then parts[#parts + 1] = "the game's area list differs from the catalogue" end
    end
    return table.concat(parts, "  ·  ")
end

---------------------------------------------------------------------------------------------
-- Cards and rows
---------------------------------------------------------------------------------------------

-- The big art cards (Phase 16 task 7; DESIGN "Dungeons tab" round 3 "Zones cards = the Dungeons
-- cards", round 4 frame A; the mockup's card() / .zcard2). Pure helpers first.

-- The full-colour layer's strength over the sepia wash: the zone's % fades it in from 18% (the
-- living Atlas's colourMin) to full when claimed; nothing tracked, no colour. The % is the
-- progression service's (z.percent); the UI only maps it to an alpha.
function Catalogue.CardColour(z, colourMin)
    colourMin = colourMin or 0.18
    if z.state == "complete" then return 1 end
    if z.state == "untracked" then return 0 end
    local p = math.max(0, math.min(1, (z.percent or 0) / 100))
    return colourMin + (1 - colourMin) * p
end

-- The tags top left: Recommended next, Your level (not once claimed), the zone's faction.
-- { { text, style = "rec" | "lvl" | "fac", faction }, ... }
function Catalogue.CardTags(z, rec, level)
    local out = {}
    if rec then out[#out + 1] = { text = "Recommended next", style = "rec" } end
    if z.state ~= "complete" and ns.Zones.FitsLevel(z, level) then out[#out + 1] = { text = "Your level", style = "lvl" } end
    if z.faction then out[#out + 1] = { text = z.faction, style = "fac", faction = z.faction } end
    return out
end

-- The foot's line: "Lv 10-20  ·  Eastern Kingdoms".
function Catalogue.CardMeta(z)
    local lv = levelText(z) or "Lv ?"
    if z.continent and z.continent ~= "" then return lv .. "  ·  " .. z.continent end
    return lv
end

-- The card's %: "not tracked" without anything to track, "?" while unknown.
function Catalogue.CardPct(z)
    if z.state == "untracked" then return "not tracked" end
    return percentText(z)
end

local function newCard(parent)
    local T, W, D, Z = ns.Theme, ns.Widgets, ns.Theme.layout.dunTab, ns.Theme.layout.zoneCard
    local P = ns.DungeonsPage.Pieces
    local c = CreateFrame("Button", nil, parent)
    c.bg = T.Solid(c, "cardBg", "BACKGROUND")
    c.bg:SetAllPoints()
    -- The living Atlas's two layers: the sepia wash, the full colour over it by the zone's %.
    c.wash = c:CreateTexture(nil, "BORDER")
    c.wash:SetAllPoints()
    c.colour = c:CreateTexture(nil, "BORDER", nil, 1)
    c.colour:SetAllPoints()
    c.shade = c:CreateTexture(nil, "ARTWORK")
    c.shade:SetPoint("BOTTOMLEFT"); c.shade:SetPoint("BOTTOMRIGHT")
    P.gradient(c.shade, "VERTICAL", 0.95, 0)
    c.standard = c:CreateTexture(nil, "OVERLAY", nil, 3)
    c.standard:SetSize(Z.standard[1], Z.standard[2])
    c.standard:SetPoint("TOPRIGHT", c, "TOPRIGHT", -D.pad, -6)
    c.check = c:CreateTexture(nil, "OVERLAY", nil, 3) -- the ✓ without the standard's art
    c.check:SetSize(D.check, D.check)
    c.check:SetPoint("TOPRIGHT", c, "TOPRIGHT", -D.pad + 4, -D.pad + 6)
    c.check:SetTexture(T.files.checkDone)
    if c.check.SetDesaturated then c.check:SetDesaturated(true) end
    c.check:SetVertexColor(T.RGB("complete"))
    c.tagHolder = CreateFrame("Frame", nil, c)
    c.tagHolder:SetAllPoints()
    c.bars = W.CatBars(c)
    c.bars:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", D.pad, D.pad - 3)
    c.meta = T.Text(c, "xs", "text")
    c.meta:SetJustifyH("LEFT"); c.meta:SetWordWrap(false)
    c.pct = T.Text(c, "xl", "white")
    c.pct:SetJustifyH("RIGHT"); c.pct:SetWordWrap(false)
    c.name = T.Text(c, "xl", "gold")
    c.name:SetJustifyH("LEFT"); c.name:SetWordWrap(false)
    c.frame = T.CardFrame(c, D.frameCorner, D.frameOut, "OVERLAY", "card-frame-a")
    -- The state and focus edge, over the frame's band (as the Dungeons cards).
    c.ring = CreateFrame("Frame", nil, c)
    c.ring:SetAllPoints(c) -- on frame A's band, the card's own edge
    if c.ring.SetFrameLevel and c.GetFrameLevel then c.ring:SetFrameLevel(c:GetFrameLevel() + 3) end
    c.edge = W.Edge(c.ring, "OVERLAY")
    function c:SetFocused(on) self.focused = on; self:Paint() end
    function c:Paint()
        local state = self.zone and self.zone.state
        local col = self.focused and "focus" or STATE_EDGE[state] or (not self.frame and "cardEdge") or nil
        for i = 1, 4 do self.edge[i]:SetShown(col ~= nil) end
        if col then self.edge:SetColor(col); self.edge:SetThickness(self.focused and 2 or 1) end
    end
    W.HoverInfo(c)
    return c
end

-- Fills a card `width` wide (16:10). rec = the one "Recommended next" zone. Returns its height.
local function fillCard(c, z, width, rec)
    local T, S, D, Z = ns.Theme, ns.Theme.space, ns.Theme.layout.dunTab, ns.Theme.layout.zoneCard
    local P = ns.DungeonsPage.Pieces
    local h = math.floor(width * D.cardAspect + 0.5)
    c:SetSize(width, h)
    local art = T.ZoneArt(z.mapID)
    local l, r, t, b = T.CoverCoords(width, h, 1024, 512)
    for _, tex in ipairs({ c.wash, c.colour }) do
        if art then tex:SetTexture(art); tex:SetTexCoord(l, r, t, b) else tex:SetColorTexture(0.1, 0.07, 0.04, 1) end
    end
    -- Part sepia, not fully grey (fully desaturated art all looked alike in game).
    if c.wash.SetDesaturation then c.wash:SetDesaturation(Z.sepia)
    elseif c.wash.SetDesaturated then c.wash:SetDesaturated(true) end
    local dim = z.state == "untracked" and 0.6 or 1
    c.wash:SetVertexColor(Z.washTint[1] * dim, Z.washTint[2] * dim, Z.washTint[3] * dim)
    local a = art and Catalogue.CardColour(z, T.atlasLiving.colourMin) or 0
    if c.colour.SetDesaturated then c.colour:SetDesaturated(false) end
    c.colour:SetVertexColor(1, 1, 1)
    c.colour:SetAlpha(a)
    c.colour:SetShown(a > 0)
    c.shade:SetHeight(math.floor(h * D.shade + 0.5))
    -- Claimed: the painted standard top right (the ✓ without its art).
    local claimed = z.state == "complete"
    local faction = (ns.character and ns.character.faction == "Horde") and "Horde" or "Alliance"
    local std = claimed and T.Pennant(faction) or nil
    if std then c.standard:SetTexture(std) end
    c.standard:SetShown(std ~= nil)
    c.check:SetShown(claimed and std == nil)
    -- Tags top left; ones that don't fit beside the standard are left out (never cut).
    local inner = width - 2 * D.pad
    local room = inner + 2 - (claimed and (Z.standard[1] + S.s2) or 0)
    local tags = Catalogue.CardTags(z, rec, char().level)
    while #tags > 0 and P.placeTags(c.tagHolder, tags, D.pad - 2, -(D.pad - 4)) > room do tags[#tags] = nil end
    if #tags == 0 then P.placeTags(c.tagHolder, tags, D.pad - 2, -(D.pad - 4)) end
    -- The foot, bottom up: the category bars side by side, the meta line, the name and %.
    c.bars:SetShown(z.state ~= "untracked")
    local barsH = 0
    if z.state ~= "untracked" then
        c.bars:Set(z.cats, inner, true)
        barsH = c.bars:GetHeight() + 4
    end
    c.meta:ClearAllPoints()
    c.meta:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", D.pad, D.pad - 3 + barsH)
    c.meta:SetWidth(inner)
    c.meta:SetText(Catalogue.CardMeta(z))
    c.pct:ClearAllPoints()
    c.pct:SetPoint("BOTTOMRIGHT", c.meta, "TOPRIGHT", 0, 4)
    local pct = Catalogue.CardPct(z)
    c.pct:SetText((claimed and "|TInterface\\RaidFrame\\ReadyCheck-Ready:20|t " or "") .. pct)
    local pctSize = z.state == "untracked" and "sm" or "xl"
    T.SetFont(c.pct, pctSize)
    c.pct:SetTextColor(T.RGB(claimed and "complete" or (z.state == "progress" and "zoneCardPct")
        or (z.state == "untracked" and "dim") or "white"))
    -- Measured apart (a string's own width bounds its measure once it has one).
    local pctW = math.ceil(T.MeasureText(pct, pctSize) + (claimed and 24 or 0)) + 1
    c.pct:SetWidth(pctW)
    c.name:ClearAllPoints()
    c.name:SetPoint("BOTTOMLEFT", c.meta, "TOPLEFT", 0, 4)
    c.name:SetText(z.name)
    -- A long name steps down a size before it's cut ("Stranglethorn Vale" at the minimum window).
    T.FitFont(c.name, z.name, inner - pctW - S.s3, { "xl", "lg" }, 1)
    c.name:SetWidth(math.max(1, inner - pctW - S.s3))
    c.zone = z
    c:Paint()
    return h
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
    r.lv:SetWidth(L.levelTextWidth); r.lv:SetJustifyH("RIGHT"); r.lv:SetWordWrap(false)
    r.name = T.Text(r, "md", "white")
    r.name:SetPoint("TOPLEFT", r.thumb, "TOPRIGHT", S.s3, 2)
    r.name:SetPoint("RIGHT", r.lv, "LEFT", -S.s3, 0)
    r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
    r.bars = W.CatBars(r)
    r.bars:SetPoint("BOTTOMLEFT", r.thumb, "BOTTOMRIGHT", S.s3, 0)
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
    -- Category bars side by side under the name, in the name column.
    local bar = compact and 0 or (S.s2 + L.levelBarWidth)
    local room = width - (S.s2 + L.zoneThumb[1] + S.s3)
        - (L.levelTextWidth + bar + S.s3 + L.pctWidth + S.s2 + S.s3)
    r.bars:SetShown(z.state ~= "untracked")
    r.bars:Set(z.cats, math.max(120, room), true)
    r.note:ClearAllPoints()
    r.note:SetPoint("BOTTOMLEFT", r.thumb, "BOTTOMRIGHT", S.s3, 0)
    r.note:SetText(z.state == "untracked" and "Nothing tracked here" or "")
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

    -- Toolbar buttons are the game's red panel buttons (owner, 2026-11-14), sized to their text;
    -- the search box stays a dark control (`plain`), as it holds typed text.
    local function control(key, title, detail, onActivate, actionLabel, plain)
        local b
        if plain then b = W.Control(tb) else b = W.PanelButton(tb); b.minWidth = 0 end
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

    -- Search: the toolbar's red button with an edit box on it (W.SearchBox, Phase 15 step 11).
    -- A or X focuses it; Enter or Escape leaves.
    local search = W.SearchBox(tb, function(text)
        if text ~= (cat.searchText or "") then
            cat.searchText = text
            ns.Events.Debounce("zones-search", 0.15, function() cat:Refresh() end)
        end
    end)
    search.item = { key = "tb:search", frame = search, title = "Search",
        detail = "Type part of a zone's name. Enter or Escape to finish.",
        onActivate = function() cat:FocusSearch() end, actionLabel = "Type" }
    search:SetScript("OnClick", function() cat:FocusSearch() end)
    cat.controls[#cat.controls + 1] = search
    search:SetWidth(L.searchWidth)
    cat.search, cat.searchBox = search, search.box

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
    -- Cards re-size with the width (three across, 16:10).
    scroll.onWidth = function(w)
        if cat.view == "cards" and math.abs((cat.cardsWidth or 0) - (w or 0)) >= 1 then cat:Refresh() end
        -- The Atlas scales with the width.
        if cat.view == "atlas" and math.abs((cat.atlasWidth or 0) - (w or 0)) >= 1 then cat.atlasWidth = w; cat:Refresh() end
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

    -- The big art cards are three across at every width (task 7, as the Dungeons cards).
    function cat:Columns()
        return T.layout.dunTab.cols
    end

    -- The view in use: the split view's list is always the compact list.
    function cat:View()
        if page.wide then return "list" end
        local m = settings().displayMode
        return (m == "list" or m == "atlas") and m or "cards"
    end

    -- Y: Cards -> List -> Atlas -> Cards.
    local NEXT_VIEW = { cards = "list", list = "atlas", atlas = "cards" }
    function cat:CycleView()
        if page.wide then return false end
        settings().displayMode = NEXT_VIEW[self:View()]
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

    -- Lays out the left group (segments, then Show / Level / Sort). `short` drops the
    -- "Show: " / "Level: " / "Sort: " prefixes (the info line still names the control).
    -- Returns where the group ends.
    local function layoutLeft(available, short)
        local s, x = settings(), L.listInset
        local pad = short and L.controlPadTight or L.controlPad
        local function place(b)
            b:ClearAllPoints()
            b:SetPoint("LEFT", tb, "LEFT", x, 0)
            x = x + b:GetWidth() + S.s2
            b:Show()
        end
        for _, b in ipairs(cat.status) do
            b:SetLabel(b.item.title, pad)
            b:SetOn(s.completion == b.value)
            place(b)
        end
        x = x + S.s2
        for _, o in ipairs(OPTIONS) do
            local b = cat.options[o.key]
            if o.needs and not available[o.needs] then
                b:Hide()
            else
                local value = "|cffffffff" .. label(o, s[o.key]) .. "|r" -- white on the red button's gold label
                b:SetLabel(short and value or (o.label .. ": " .. value), pad)
                b.item.detail = label(o, s[o.key]) .. ". Press A to choose."
                place(b)
            end
        end
        return x
    end

    -- The view toggle at the right (not in the split view); returns the room it takes.
    local function layoutViews()
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
        return right
    end

    local function layoutToolbar(available)
        -- Right side first: view toggle; search goes to its left.
        local function compact(on) for _, b in ipairs(cat.controls) do if b.SetCompact then b:SetCompact(on) end end end
        compact(false)
        local right = layoutViews()
        local width = tb:GetWidth() or 0
        if width <= 1 then local f = ns.UI.GetFrame(); width = (f and f:GetWidth() or 1160) - 2 * L.edgeInset end
        -- Narrow windows: short labels on the game's small button font if the full ones leave no
        -- room for the smallest search box (WoWScrnShot_110726_213029: at 1000 wide, Sort ran
        -- into Cards; WoWScrnShot_111426_155718: the red buttons' font is wider), then drop the
        -- count, then shrink the search box.
        local x = layoutLeft(available, false)
        cat.shortLabels = width - right - x - S.s2 < L.searchMinWidth
        if cat.shortLabels then
            compact(true)
            right = layoutViews()
            x = layoutLeft(available, true)
        end
        cat.count:ClearAllPoints()
        cat.count:SetPoint("LEFT", tb, "LEFT", x + S.s1, 0)
        local countEnd = x + S.s1 + (cat.count:GetStringWidth() or 0)
        local searchW = L.searchWidth
        local room = width - right - countEnd - S.s3
        cat.count:SetShown(room >= searchW)
        if room < searchW then room = width - right - x - S.s2 end
        searchW = math.max(L.searchMinWidth, math.min(L.searchWidth, room))
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
        self.all = all -- every zone's entry, for the dashboard's "Also for your level"
        self.count:SetText(q.shown == q.total and (q.total .. " zones") or string.format("%d of %d zones", q.shown, q.total))
        layoutToolbar(available)

        for _, c in ipairs(self.cards) do c:Hide() end
        for _, r in ipairs(self.rows) do r:Hide() end
        for _, h in ipairs(self.headers) do h:Hide() end
        local child, width = scroll.child, self:Width()
        if self.chart then self.chart:SetShown(self.view == "atlas") end
        if self.view == "atlas" then return self:DrawAtlas(all, q, child, width) end
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
        local D = T.layout.dunTab
        local cols = self:Columns()
        self.columns, self.cardsWidth = cols, width
        local cardW = math.floor((inner - (cols - 1) * D.cardGap) / cols)
        -- The grid's rounding remainder goes into the gaps, so the last column ends at the edge.
        local gap = cols > 1 and (inner - cols * cardW) / (cols - 1) or D.cardGap
        -- Frame A reaches frameOut past each card: headers match that edge.
        local out = self.view == "cards" and D.frameOut or 0
        -- The one "Recommended next" zone (of those shown).
        local c = char()
        local here = C_Map and C_Map.GetBestMapForUnit and ns.Debug.Try("GetBestMapForUnit", C_Map.GetBestMapForUnit, "player")
        local hereZone = here and (ns.Exploration.ZoneForMap(here) or here)
        local homeContinent
        for _, z in ipairs(all) do if z.mapID == hereZone then homeContinent = z.continent end end
        local rec = self.view == "cards" and ns.Zones.RecommendedNext(q.zones,
            { faction = c.faction, level = c.level, continent = homeContinent }) or nil
        self.recommended = rec and rec.mapID or nil
        for gi, g in ipairs(q.groups) do
            if g.title then
                if gi > 1 then y = y + S.s3 end
                local h = take("headers", W.Header)
                h:SetPoint("TOPLEFT", child, "TOPLEFT", L.listInset - out, -y)
                h:SetPoint("TOPRIGHT", child, "TOPRIGHT", -S.s6 + out, -y)
                h.text:SetText(g.title)
                h.count:SetText(g.tracked == 0 and "not tracked" or string.format("%d of %d complete", g.complete, g.tracked))
                y = y + L.listHeader + S.s2 + out
            end
            if self.view == "cards" then
                for i = 1, #g.zones, cols do
                    local items, rowH = {}, 0
                    for col = 0, cols - 1 do
                        local z = g.zones[i + col]
                        if z then
                            local card = take("cards", newCard)
                            rowH = fillCard(card, z, cardW, rec ~= nil and z.mapID == rec.mapID)
                            card:SetPoint("TOPLEFT", child, "TOPLEFT", math.floor(L.listInset + col * (cardW + gap) + 0.5), -y)
                            items[#items + 1] = zoneItem(card, z)
                            byMap[z.mapID] = card
                        end
                    end
                    rows[#rows + 1] = { items = items, section = gi }
                    y = y + rowH + D.cardGap
                end
                y = y - D.cardGap + out + S.s2
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

    -- The Atlas view (Phase 10): every tracked zone on the painted sea chart, those outside
    -- the filters dimmed; opens on your current zone.
    function cat:DrawAtlas(all, q, child, width)
        self.emptyTitle:Hide(); self.emptyText:Hide()
        self.chart = self.chart or ns.AtlasChart.New(child, false)
        local chart = self.chart
        chart:ClearAllPoints()
        chart:SetPoint("TOPLEFT", child, "TOPLEFT", L.listInset, 0)
        chart:Show()
        local tracked, shown, tiles = {}, {}, {}
        for _, z in ipairs(all) do if z.tracked then tracked[#tracked + 1] = z; tiles[z.mapID] = true end end
        for _, z in ipairs(q.zones) do shown[z.mapID] = true end
        local w = width - L.listInset - S.s6
        local h = math.floor(w / ns.AtlasChart.SOURCE_ASPECT + 0.5)
        local current = ns.Exploration.CurrentIn(tiles)
        local rows, byMap = ns.AtlasChart.Draw(chart, tracked, w, h, { shown = shown, current = current,
            item = function(tile, z) return zoneItem(tile, z) end })
        local focus = { toolbarRow() }
        for _, r in ipairs(rows) do focus[#focus + 1] = r end
        child:SetHeight(h + S.s2)
        self.focusRows, self.byMap = focus, byMap
        self.sectionCount = 0
        local here = current and byMap[current]
        self.firstZone = (here and here.item and here.item.zone) or (q.zones[1] and zoneObject(q.zones[1])) or nil
        if page.OnCatalogueChanged then page:OnCatalogueChanged() end
    end
    -- The zone object for a mapID that's in the current list, or nil.
    function cat:ZoneFor(mapID)
        local f = self.byMap[mapID]
        return f and f.item and f.item.zone
    end

    return cat
end
