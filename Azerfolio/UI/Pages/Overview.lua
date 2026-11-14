-- Overview tab (spec §5, mockups/DESIGN.md "Overview", "Step 6" and "Round 3"): two columns that
-- fit one screen, every panel in the painted frame, section headers on painted plates.
--   Left: the Continue card (current zone, else the closest to finish, else the next for your
--   level) and Tracked completion (one row per category plus Zones; the headline is the
--   equal-weight average of the categories with data). The space under it is kept for a
--   Professions panel (owner, 2026-11-13).
--   Right: the Atlas panel (the painted sea chart with every zone at its place; A opens the
--   Atlas view) and your class road: a window onto the Class tab's strip at its own scale,
--   cropped around You, with a caption (counts, the Next line, abilities waiting at your
--   trainer); A opens the Class tab on your current stop.
-- Round 3 (owner, 2026-11-13) removed the Next goal, Suggested next and Recent zones panels.
-- What to show comes from ns.Overview (pure picks over ns.Zones and ns.Progression results) and
-- the Class page's summary (ns.ClassJourney, ns.ClassTrainer); this file only draws it.
-- A on the Continue card opens Zone Detail (B comes back here); A on a category row opens Zones,
-- on Zones opens it filtered.
-- The page redraws on discoveries, quest and flight updates, class updates, zone changes and
-- level-ups.
local _, ns = ...

local function color(name)
    local r, g, b = ns.Theme.RGB(name)
    return string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
end

local function zoneObject(z)
    return { mapID = z.mapID, name = z.name, continent = z.continent, minLevel = z.minLevel,
        maxLevel = z.maxLevel, entry = z }
end

-- Opens a zone's detail on the Zones tab; B returns here.
local function openZone(z)
    ns.UI.SelectTab("zones")
    local frame = ns.UI.GetFrame()
    local zp = frame and frame.pages.zones
    if zp and zp.ShowZone then zp:ShowZone(zoneObject(z), nil, "overview") end
end

local function openAtlas()
    ns.UI.SelectTab("zones")
    local frame = ns.UI.GetFrame()
    local zp = frame and frame.pages.zones
    if zp and zp.ShowAtlas then zp:ShowAtlas() end
end

local function openZones(status)
    ns.UI.SelectTab("zones")
    local frame = ns.UI.GetFrame()
    local zp = frame and frame.pages.zones
    if status and zp and zp.ShowStatus then zp:ShowStatus(status) end
end

-- The Class tab, focused on your current stop (the road's end once it's walked).
local function openClass()
    ns.UI.SelectTab("class")
    local frame = ns.UI.GetFrame()
    local cp = frame and frame.pages.class
    if cp and cp.FocusStop and cp.journey then cp:FocusStop(cp:CurrentStopKey()) end
end

-- Why a category has no numbers yet (Progression.Combine's pending reasons).
local PENDING = { achievements = "Waiting for the game's data", building = "Reading quests...",
    questiedb = "Needs the QuestieDB addon", flightmaster = "Talk to a flight master" }

---------------------------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------------------------

-- A dark panel in the painted frame (design round 2); without the art a 1 px edge. Focusable
-- panels show a 2 px yellow edge when focused (DESIGN.md).
local function newPanel(parent, focusable)
    local T, W = ns.Theme, ns.Widgets
    local p = CreateFrame(focusable and "Button" or "Frame", nil, parent)
    p.bg = T.Solid(p, "cardBg", "BACKGROUND", 0.85)
    p.bg:SetAllPoints()
    p.edge = W.Edge(p, "ARTWORK")
    p.frame = T.CardFrame(p, 22, 4)
    function p:Paint()
        if self.focused then
            self.edge:SetColor("focus"); self.edge:SetThickness(2)
        else
            self.edge:SetColor("cardEdge"); self.edge:SetThickness(1)
        end
        for i = 1, 4 do self.edge[i]:SetShown(self.frame == nil or self.focused == true) end
    end
    function p:SetFocused(on) self.focused = on; self:Paint() end
    p:Paint()
    if focusable then W.HoverInfo(p) end
    return p
end

-- Stacked segments { { n, colorName }, ... } over `total` (the Zones row).
local function newStack(parent)
    local T, L = ns.Theme, ns.Theme.layout
    local b = CreateFrame("Frame", nil, parent)
    b:SetHeight(L.statBar)
    b.bg = T.Solid(b, "black", "BACKGROUND")
    b.bg:SetAllPoints()
    b.segs = {}
    function b:SetStack(parts, total, width)
        local x, shown = 0, 0
        for _, p in ipairs(parts) do if p[1] > 0 then shown = shown + 1 end end
        local usable = width - math.max(0, shown - 1) * 2
        local i = 0
        for _, p in ipairs(parts) do
            if p[1] > 0 and total > 0 then
                i = i + 1
                local s = self.segs[i]
                if not s then s = self:CreateTexture(nil, "ARTWORK"); self.segs[i] = s end
                local w = math.max(2, math.floor(usable * p[1] / total + 0.5))
                if i == shown then w = math.max(2, width - x) end
                local r, g, bl = T.RGB(p[2])
                s:SetColorTexture(r, g, bl, 1)
                s:ClearAllPoints()
                s:SetPoint("TOPLEFT", self, "TOPLEFT", x, 0)
                s:SetSize(w, L.statBar)
                s:Show()
                x = x + w + 2
            end
        end
        for j = i + 1, #self.segs do self.segs[j]:Hide() end
    end
    return b
end

-- Crops 2:1 zone art to a w x h box (centred; tall boxes cut the sides).
local function cropArt(tex, mapID, w, h)
    local T = ns.Theme
    if not (w and h and w > 0 and h > 0) then return end
    if w / h >= 2 then
        local top, bottom = T.BannerCrop(mapID, w, h)
        tex:SetTexCoord(0, 1, top, bottom)
    else
        local f = (w / h) / 2
        tex:SetTexCoord((1 - f) / 2, (1 + f) / 2, 0, 1)
    end
end

local function setArt(tex, z)
    local art = ns.Theme.ZoneArt(z.mapID)
    if art then tex:SetTexture(art) else tex:SetColorTexture(0, 0, 0, 1) end
    local grey = z.state == "untouched" or z.state == "untracked"
    if tex.SetDesaturated then tex:SetDesaturated(grey) end
end

local function buildHero(parent)
    local T, L, S, W = ns.Theme, ns.Theme.layout, ns.Theme.space, ns.Widgets
    local h = newPanel(parent, true)
    h:SetHeight(L.heroHeight)
    h.art = h:CreateTexture(nil, "BORDER")
    h.art:SetPoint("TOPLEFT", 1, -1); h.art:SetPoint("BOTTOMLEFT", 1, 1)
    h.art:SetWidth(L.heroArt)
    local x = L.heroArt + S.s4
    h.kicker = T.Text(h, "xs", "gold")
    h.kicker:SetPoint("TOPLEFT", h, "TOPLEFT", x, -S.s3)
    h.name = T.Text(h, "xl", "white")
    h.name:SetPoint("TOPLEFT", h.kicker, "BOTTOMLEFT", 0, -S.s1)
    h.name:SetPoint("RIGHT", h, "RIGHT", -L.heroScore, 0)
    h.name:SetJustifyH("LEFT"); h.name:SetWordWrap(false)
    h.pips = W.Pips(h)
    h.pips:SetPoint("TOPLEFT", h.name, "BOTTOMLEFT", 0, -S.s2)
    h.left = T.Text(h, "sm", "text")
    h.left:SetPoint("TOPLEFT", h.pips, "BOTTOMLEFT", 0, -S.s2)
    h.banner = ns.ZoneBanner.New(h)
    h.banner:SetPoint("RIGHT", h, "RIGHT", -20, 0) -- offset in the banner's own (scaled) units
    h.pct = T.Text(h, "xxl", "white")
    h.pct:SetPoint("RIGHT", h.banner, "LEFT", -S.s1, S.s2)
    h.count = T.Text(h, "xs", "dim")
    h.count:SetPoint("TOPRIGHT", h.pct, "BOTTOMRIGHT", 0, -S.s1)
    -- Shown instead of the card when there is nothing to continue.
    h.empty = T.Text(parent, "md", "dim")
    h.empty:SetJustifyH("LEFT")
    return h
end

-- One Tracked completion row: icon, name, gilded bar, done / counted, % (or why it has none).
local function newTrackRow(parent)
    local T, L, S, W = ns.Theme, ns.Theme.layout, ns.Theme.space, ns.Widgets
    local r = W.FocusRow(parent, L.trackRow)
    r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(18, 18); r.icon:SetPoint("LEFT", S.s2, 0)
    r.label = T.Text(r, "sm", "white"); r.label:SetPoint("LEFT", r.icon, "RIGHT", S.s2, 0)
    r.label:SetWidth(L.trackLabel); r.label:SetJustifyH("LEFT"); r.label:SetWordWrap(false)
    r.pct = T.Text(r, "sm", "white"); r.pct:SetPoint("RIGHT", -S.s2, 0)
    r.pct:SetWidth(40); r.pct:SetJustifyH("RIGHT")
    r.count = T.Text(r, "xs", "dim"); r.count:SetPoint("RIGHT", r.pct, "LEFT", -S.s2, 0)
    r.count:SetWidth(L.trackCount); r.count:SetJustifyH("RIGHT")
    r.bar = T.GildedBar(r, L.trackBar)
    r.bar:SetPoint("LEFT", r.label, "RIGHT", S.s1, 0)
    r.bar:SetPoint("RIGHT", r.count, "LEFT", -S.s2, 0)
    r.note = T.Text(r, "xs", "dim"); r.note:SetPoint("RIGHT", -S.s2, 0)
    r.note:SetPoint("LEFT", r.label, "RIGHT", S.s1, 0)
    r.note:SetJustifyH("RIGHT"); r.note:SetWordWrap(false)
    return r
end

-- One Professions row (Phase 14; mockups/DESIGN.md "Overview"): the profession's coin, name, a
-- gilded skill bar over 1-300 with a tick at your cap, "33 / 75", the status tag.
local function newProfRow(parent)
    local T, L, S, W = ns.Theme, ns.Theme.layout, ns.Theme.space, ns.Widgets
    local r = W.FocusRow(parent, L.trackRow)
    r.coin = ns.ProfessionsPage and ns.ProfessionsPage.NewCoin(r)
    if r.coin then r.coin:SetPoint("LEFT", S.s1, 0) end
    r.label = T.Text(r, "sm", "white"); r.label:SetPoint("LEFT", S.s2 + 18 + S.s2, 0)
    r.label:SetWidth(L.trackLabel); r.label:SetJustifyH("LEFT"); r.label:SetWordWrap(false)
    r.tag = T.Text(r, "xs", "profGo"); r.tag:SetPoint("RIGHT", -S.s2, 0)
    r.tag:SetWidth(L.profTag); r.tag:SetJustifyH("RIGHT"); r.tag:SetWordWrap(false)
    r.count = T.Text(r, "xs", "dim"); r.count:SetPoint("RIGHT", r.tag, "LEFT", -S.s2, 0)
    r.count:SetWidth(56); r.count:SetJustifyH("RIGHT")
    r.bar = T.GildedBar(r, L.trackBar)
    r.bar:SetPoint("LEFT", r.label, "RIGHT", S.s1, 0)
    r.bar:SetPoint("RIGHT", r.count, "LEFT", -S.s2, 0)
    r.capTick = T.Solid(r.bar, "white", "OVERLAY", 0.8)
    r.capTick:SetSize(2, L.trackBar)
    -- The tick at your cap, placed along the well (again once the bar has its width).
    function r:PlaceCap()
        local bw = self.bar.well:GetWidth() or 0
        self.capTick:SetShown(self.capFrac ~= nil and bw > 0)
        if self.capFrac and bw > 0 then
            self.capTick:ClearAllPoints()
            self.capTick:SetPoint("CENTER", self.bar.well, "LEFT", bw * self.capFrac, 0)
        end
    end
    r.bar.onSized = function() r:PlaceCap() end
    return r
end

-- The class road panel: the Class page's strip in mini mode on top (a window onto the road), a
-- rule, then the caption. An overlay above the map takes the mouse, so a click anywhere on the
-- panel opens the Class tab (the map's own nodes never react).
local function buildClassPanel(parent)
    local T, L, S = ns.Theme, ns.Theme.layout, ns.Theme.space
    local p = newPanel(parent, true)
    p.win = CreateFrame("Frame", nil, p)
    p.win:SetPoint("TOPLEFT", 1, -1); p.win:SetPoint("TOPRIGHT", -1, -1)
    p.win:SetHeight(L.classMini)
    if p.win.SetClipsChildren then p.win:SetClipsChildren(true) end
    p.rule = T.Solid(p, "divider", "ARTWORK")
    p.rule:SetPoint("TOPLEFT", p.win, "BOTTOMLEFT"); p.rule:SetPoint("TOPRIGHT", p.win, "BOTTOMRIGHT")
    p.rule:SetHeight(1)
    p.count = T.Text(p, "xs", "dim")
    p.next = T.Text(p, "sm", "classPeach")
    p.next:SetWordWrap(false)
    p.train = T.Text(p, "xs", "classRedInkLight")
    for _, fs in ipairs({ p.count, p.next, p.train }) do fs:SetJustifyH("LEFT") end
    p.count:SetPoint("TOPLEFT", p.win, "BOTTOMLEFT", L.panelPad, -S.s2)
    p.count:SetPoint("RIGHT", p, "RIGHT", -L.panelPad, 0)
    p.next:SetPoint("TOPLEFT", p.count, "BOTTOMLEFT", 0, -2)
    p.next:SetPoint("RIGHT", p, "RIGHT", -L.panelPad, 0)
    p.train:SetPoint("TOPLEFT", p.next, "BOTTOMLEFT", 0, -2)
    -- Built when first drawn (the page needs its width).
    function p:EnsureMap(width)
        if self.map or not (ns.ClassPage and ns.ClassPage.BuildMini) then return self.map end
        local m = ns.ClassPage.BuildMini(self.win, width)
        m:SetAllPoints(self.win)
        self.map = m
        self.overlay = CreateFrame("Button", nil, self)
        self.overlay:SetAllPoints(self.win)
        self.overlay:SetFrameLevel((m:GetFrameLevel() or 0) + 50)
        self.overlay:SetScript("OnClick", function() local f = p:GetScript("OnClick"); if f then f(p) end end)
        self.overlay:SetScript("OnEnter", function() local f = p:GetScript("OnEnter"); if f then f(p) end end)
        self.overlay:SetScript("OnLeave", function() local f = p:GetScript("OnLeave"); if f then f(p) end end)
        return m
    end
    return p
end

---------------------------------------------------------------------------------------------
-- Text
---------------------------------------------------------------------------------------------

local function kicker(model)
    local hero, cur = model.hero, model.current
    if hero.why == "current" then
        local z, p = hero.zone, hero.zone.progress
        if z.state == "complete" then return "Your zone · claimed" end
        if p and p.denominator > 0 and p.remaining == 0 then return "Your zone · every area discovered" end
        return (z.state == "untouched" and "Start" or "Continue") .. " · your zone"
    end
    if cur and cur.state == "complete" then return cur.name .. " claimed · next up" end
    if hero.why == "level" then return "Next for your level" end
    return "Continue"
end

---------------------------------------------------------------------------------------------
-- Page
---------------------------------------------------------------------------------------------

local function build(parent)
    local T, L, S, W = ns.Theme, ns.Theme.layout, ns.Theme.space, ns.Widgets
    local page = CreateFrame("Frame", nil, parent)
    page.sectionLabel = "Section"
    local scroll = W.Scroll(page)
    scroll:SetPoint("TOPLEFT", 0, -S.s4)
    scroll:SetPoint("BOTTOMRIGHT", 0, S.s2)
    local child = scroll.child
    page.scroll = scroll

    local pools = { track = {} }
    page.pools = pools
    local hero = buildHero(child)

    local track = newPanel(child, false)
    track.title = T.Text(track, "sm", "gold")
    track.title:SetPoint("TOPLEFT", L.panelPad + 2, -L.panelPad - 4)
    track.title:SetText("Tracked completion")
    track.pct = T.Text(track, "xxl", "white")
    track.pct:SetPoint("TOPRIGHT", -L.panelPad - 2, -L.panelPad + 2)
    track.foot = T.Text(track, "xs", "dim")
    track.foot:SetJustifyH("LEFT"); track.foot:SetWordWrap(true)
    -- The Zones row: stacked bar, complete / applicable, and its legend underneath.
    local zrow = W.FocusRow(track, L.trackRow + 14)
    zrow.label = T.Text(zrow, "sm", "white"); zrow.label:SetPoint("TOPLEFT", S.s2 + 18 + S.s2, -7)
    zrow.label:SetText("Zones")
    zrow.count = T.Text(zrow, "xs", "dim"); zrow.count:SetPoint("TOPRIGHT", -S.s2, -8)
    zrow.bar = newStack(zrow)
    zrow.bar:SetPoint("TOPLEFT", zrow, "TOPLEFT", S.s2 + 18 + S.s2 + L.trackLabel + S.s1, -9)
    zrow.legend = T.Text(zrow, "xs", "dim")
    zrow.legend:SetPoint("BOTTOMLEFT", zrow, "BOTTOMLEFT", S.s2 + 18 + S.s2 + L.trackLabel + S.s1, 3)
    zrow.rule = T.Solid(zrow, "white", "BACKGROUND", 0.08)
    zrow.rule:SetPoint("TOPLEFT"); zrow.rule:SetPoint("TOPRIGHT"); zrow.rule:SetHeight(1)

    -- Professions (Phase 14): under Tracked completion, one row per profession.
    local prof = newPanel(child, false)
    prof.title = T.Text(prof, "sm", "gold")
    prof.title:SetPoint("TOPLEFT", L.panelPad + 2, -L.panelPad + 2)
    prof.title:SetText("Professions")
    prof.mastered = T.Text(prof, "sm", "white")
    prof.mastered:SetPoint("TOPRIGHT", -L.panelPad - 2, -L.panelPad + 2)
    prof.empty = T.Text(prof, "xs", "dim")
    prof.empty:SetJustifyH("LEFT")
    pools.prof = {}

    -- The Atlas panel (Phase 10): the painted sea chart with every zone's art at its place.
    local atlasPlate = T.Plate(child, L.plate)
    atlasPlate.title:SetText("Atlas")
    local atlas = ns.AtlasChart.New(child, true)
    W.HoverInfo(atlas)
    atlas.focusEdge = W.Edge(atlas, "OVERLAY")
    atlas.focusEdge:SetColor("focus"); atlas.focusEdge:SetThickness(2)
    function atlas:SetFocused(on)
        self.focused = on
        for i = 1, 4 do self.focusEdge[i]:SetShown(on == true) end
    end
    atlas:SetFocused(false)
    -- Your class road (round 3).
    local classPlate = T.Plate(child, L.plate)
    local classPanel = buildClassPanel(child)
    page.parts = { hero = hero, track = track, zonesRow = zrow, atlas = atlas, atlasPlate = atlasPlate,
        classPlate = classPlate, classPanel = classPanel }

    -- The width the page draws into (before the first layout, from the window).
    local function width()
        local w = scroll:GetWidth() or 0
        if w <= 1 then
            local f = ns.UI.GetFrame()
            w = (f and f:GetWidth() or 1160) - 2 * L.edgeInset
        end
        return w
    end

    local function item(frame, key, title, detail, onActivate, group, actionLabel, topGap)
        frame.item = { key = key, frame = frame, title = title, detail = detail, onActivate = onActivate,
            group = group, column = group == "L" and 1 or 2, scroll = scroll, actionLabel = actionLabel or "Open", topGap = topGap }
        frame:SetScript("OnClick", function() onActivate(frame.item) end)
        return frame.item
    end

    -- Tracked completion at (x, y), width w. Adds its rows (section 2) and returns the next y.
    local function drawTracked(m, x, y, w, rows)
        local tc = m.completion
        local c = tc.combined
        track:ClearAllPoints()
        track:SetPoint("TOPLEFT", child, "TOPLEFT", x, -y)
        track:SetWidth(w)
        track.pct:SetText(ns.Progression.PercentText(c) or "-")
        local pad = L.panelPad
        local ty = L.trackHead
        for _, r in ipairs(pools.track) do r:Hide() end
        local unread = {}
        for _, id in ipairs(tc.flightsUnread or {}) do unread[#unread + 1] = ns.Overview.ContinentName(id) or ("map " .. id) end
        local notes = {}
        local function add(it) rows[#rows + 1] = { items = { it }, section = 2 } end
        for i, cat in ipairs(c.cats) do
            local r = pools.track[i]
            if not r then r = newTrackRow(track); pools.track[i] = r end
            local meta = T.category[cat.key]
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", track, "TOPLEFT", pad - S.s1, -ty)
            r:SetPoint("RIGHT", track, "RIGHT", -pad + S.s1, 0)
            r.icon:SetTexture(meta.icon)
            r.label:SetText(meta.label)
            local pending = cat.pending ~= nil
            r.label:SetTextColor(T.RGB(pending and "dim" or "white"))
            r.bar:SetShown(not pending); r.count:SetShown(not pending); r.pct:SetShown(not pending)
            r.note:SetShown(pending)
            local detail
            if pending then
                r.note:SetText(PENDING[cat.pending] or "Not readable yet")
                detail = (PENDING[cat.pending] or "Not readable yet") .. ". Left out of the headline until then."
            else
                r.count:SetText(color("white") .. cat.completed .. "|r / " .. cat.denominator)
                r.pct:SetText(ns.Progression.PercentText(cat.progress) or "-")
                r.bar:Set(cat.completed / cat.denominator, cat.state)
                detail = string.format("%d of %d %s the game confirms done.", cat.completed, cat.denominator, meta.unit)
                if cat.key == "quests" and (cat.unchecked or 0) > 0 then
                    notes[#notes + 1] = cat.unchecked .. " quests can't be checked yet"
                    detail = detail .. " " .. cat.unchecked .. " more can't be checked yet."
                end
                if cat.key == "flights" and #unread > 0 then
                    notes[#notes + 1] = table.concat(unread, " and ") .. ": talk to a flight master there"
                    detail = detail .. " " .. table.concat(unread, " and ") .. " isn't counted until you talk to a flight master there."
                end
                if cat.key == "explore" and (tc.exploreUnread or 0) > 0 then
                    notes[#notes + 1] = tc.exploreUnread .. " zones' exploration can't be read yet"
                end
            end
            r:Show()
            add(item(r, "track:" .. cat.key, meta.label, detail, function() openZones() end, "L", "Zones"))
            ty = ty + L.trackRow
        end

        -- Zones: complete / in progress / untouched (/ unknown) over the zones you can do.
        local zc = m.zones
        zrow:ClearAllPoints()
        zrow:SetPoint("TOPLEFT", track, "TOPLEFT", pad - S.s1, -(ty + S.s1))
        zrow:SetPoint("RIGHT", track, "RIGHT", -pad + S.s1, 0)
        zrow.count:SetText(string.format("%s%d|r / %d complete", color("white"), zc.complete, zc.applicable))
        -- The bar ends before the count (a fixed width ran into "0 / 43 complete" in game,
        -- WoWScrnShot_110826_181134).
        local rowW = w - 2 * pad + 2 * S.s1
        local barStart = S.s2 + 18 + S.s2 + L.trackLabel + S.s1
        local countW = math.ceil(zrow.count:GetStringWidth() or L.trackCount)
        local barW = math.max(40, rowW - barStart - countW - S.s2 - S.s3)
        zrow.bar:SetWidth(barW)
        zrow.bar:SetStack({ { zc.complete, "complete" }, { zc.progress, "todo" }, { zc.untouched, "well" },
            { zc.unknown, "black" } }, zc.applicable, barW)
        local legend = string.format("%s%d in progress|r   %d untouched", color("todo"), zc.progress, zc.untouched)
        if zc.unknown > 0 then legend = legend .. "   " .. zc.unknown .. " no data" end
        zrow.legend:SetText(legend)
        local target = zc.complete > 0 and "complete" or (zc.progress > 0 and "progress" or "all")
        add(item(zrow, "zones", "Zones",
            "Zones you can do (other faction's territory left out). Complete: exploration, quests and flight "
                .. "paths all done; in progress: some; untouched: none yet.",
            function() openZones(target) end, "L",
            target == "complete" and "Show complete" or (target == "progress" and "Show in progress" or "Zones")))
        ty = ty + S.s1 + L.trackRow + 14 + S.s2

        local rule = "Each category counts equally"
        if c.pending then rule = rule .. "; those without data are left out" end
        table.insert(notes, 1, rule)
        track.foot:ClearAllPoints()
        track.foot:SetPoint("TOPLEFT", track, "TOPLEFT", pad + 2, -ty)
        track.foot:SetWidth(w - 2 * pad - 4)
        track.foot:SetText(table.concat(notes, " · ") .. ".")
        local fh = track.foot:GetStringHeight() or 0
        if fh < 12 then fh = 14 * math.ceil((track.foot:GetStringWidth() or 0) / math.max(1, w - 2 * pad - 4) + 0.001) end
        ty = ty + math.max(14, fh) + pad
        track:SetHeight(ty)
        return y + ty
    end

    -- The Professions panel at (x, y), width w (mockups/DESIGN.md "Overview": "n of m mastered",
    -- one row per profession; A opens the tab on it). Adds its rows (section 5) and returns the
    -- next y.
    local function drawProfessions(x, y, w, rows)
        local g = ns.Professions and ns.Professions.Get() or { professions = {}, summary = { mastered = 0, total = 0 } }
        local P = ns.ProfessionsPage
        prof:ClearAllPoints()
        prof:SetPoint("TOPLEFT", child, "TOPLEFT", x, -y)
        prof:SetWidth(w)
        local pad = L.panelPad
        local ty = L.profHead
        for _, r in ipairs(pools.prof) do r:Hide() end
        local list = g.professions
        prof.mastered:SetShown(#list > 0)
        prof.mastered:SetText(string.format("%d of %d mastered", g.summary.mastered, g.summary.total))
        prof.empty:SetShown(#list == 0)
        if #list == 0 then
            prof.empty:ClearAllPoints()
            prof.empty:SetPoint("TOPLEFT", prof, "TOPLEFT", pad + 2, -ty)
            prof.empty:SetWidth(w - 2 * pad)
            prof.empty:SetText("No professions learned yet.")
            ty = ty + 18
        end
        local max = ns.ProfessionData and ns.ProfessionData.maxSkill or 300
        for i, m in ipairs(list) do
            local r = pools.prof[i]
            if not r then r = newProfRow(prof); pools.prof[i] = r end
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", prof, "TOPLEFT", pad - S.s1, -ty)
            r:SetPoint("RIGHT", prof, "RIGHT", -pad + S.s1, 0)
            if r.coin then r.coin:Set(m, 20) end
            r.label:SetText(m.name)
            r.count:SetText(string.format("%s%s|r / %s", color("white"), tostring(m.skill or "?"), tostring(m.cap or "?")))
            r.bar:Set((m.skill or 0) / max, m.mastered and "complete" or nil)
            r.capFrac = (m.cap and m.cap < max) and (m.cap / max) or nil
            r:PlaceCap()
            local text, c = P and P.StatusText(m)
            r.tag:SetText(text or "")
            r.tag:SetTextColor(T.RGB(c or "dim"))
            r:Show()
            local line = m.skillLine
            rows[#rows + 1] = { items = { item(r, "prof:" .. line, m.name, (P and P.RailInfo(m) or "") .. " A opens it in the Professions tab.",
                function() if P then P.Open(line) end end, "L", "Professions") }, section = 5 }
            ty = ty + L.trackRow
        end
        ty = ty + S.s2
        prof:SetHeight(ty)
        return y + ty
    end

    -- Draws the left column from x at width w: the Continue card (section 1), then Tracked
    -- completion (section 2), then Professions (section 5). Returns its focus rows and its height.
    local function drawLeft(m, x, w)
        local rows, y = {}, 0
        local h = m.hero
        hero:SetShown(h ~= nil)
        hero.empty:SetShown(h == nil)
        if h then
            local z, p = h.zone, h.zone.progress
            hero:ClearAllPoints()
            hero:SetPoint("TOPLEFT", child, "TOPLEFT", x, -y)
            hero:SetWidth(w)
            setArt(hero.art, z)
            cropArt(hero.art, z.mapID, L.heroArt, L.heroHeight - 2)
            hero.kicker:SetText(kicker(m):upper())
            hero.name:SetText(z.name)
            -- Exploration's pips when the zone has them; the zone's overall % (all categories).
            hero.pips:SetShown(p ~= nil)
            if p then hero.pips:Set(p.complete, p.incomplete, p.completionUnknown, w - L.heroArt - L.heroScore - S.s4) end
            local left = {}
            for _, c in ipairs(z.cats or {}) do
                if not c.pending and c.remaining and c.remaining > 0 then
                    left[#left + 1] = color("complete") .. c.remaining .. "|r " .. T.category[c.key].unit
                end
            end
            hero.left:SetText(z.state == "complete" and "Every category complete"
                or (#left > 0 and (table.concat(left, "  ·  ") .. " to go") or ""))
            local faction = (ns.character and ns.character.faction == "Horde") and "Horde" or "Alliance"
            hero.banner:Set(z, faction, false, false) -- the mini standard: no effects
            hero.banner:SetScale((L.heroHeight - 12) / math.max(1, hero.banner:GetHeight() or 1))
            local cp = z.combined
            hero.pct:SetText(z.state == "complete" and "Claimed" or (cp and ns.Progression.PercentText(cp) or "-"))
            hero.pct:SetTextColor(T.RGB(z.state == "complete" and "complete" or ((cp and cp.completed > 0) and "todo" or "white")))
            -- Right after login QuestieDB is still being read: say so, so the % (which can't
            -- include quests yet) isn't taken for the whole zone (seen in game, 2026-11-08).
            local reading = false
            for _, c in ipairs(z.cats or {}) do if c.pending == "building" then reading = true end end
            hero.count:SetText(reading and "Reading quests..." or (p and string.format("%d of %d areas", p.completed, p.denominator) or ""))
            local go = z.state == "complete" and "Open" or (z.state == "untouched" and "Start" or "Continue")
            local detail = ns.ZonesCatalogue.ZoneDetail(z) .. "  ·  Open the zone to see what's left."
            rows[#rows + 1] = { items = { item(hero, "hero", z.name, detail, function() openZone(z) end, "L",
                go) }, section = 1 }
            y = y + L.heroHeight
        else
            hero.empty:ClearAllPoints()
            hero.empty:SetPoint("TOPLEFT", child, "TOPLEFT", x, -y - S.s2)
            hero.empty:SetWidth(w)
            hero.empty:SetText(m.completion.combined.applies == 0
                and "Waiting for the game's achievement data. It usually arrives a few seconds after login."
                or "Nothing left to continue: every zone you can do is complete.")
            y = y + 48
        end
        y = drawTracked(m, x, y + S.s4, w, rows)
        y = drawProfessions(x, y + S.s4, w, rows)
        return rows, y
    end

    -- Draws the right column: the Atlas (section 3) and your class road (section 4). Returns its
    -- focus rows and its height.
    local function drawRight(m, x, w)
        local rows, y = {}, 0
        -- The Atlas panel: A opens the Atlas view on your current zone.
        atlasPlate:ClearAllPoints()
        atlasPlate:SetPoint("TOPLEFT", child, "TOPLEFT", x - 6, -y)
        atlasPlate:SetWidth(w + 12)
        y = y + L.plate + S.s3
        atlas:ClearAllPoints()
        atlas:SetPoint("TOPLEFT", child, "TOPLEFT", x, -y)
        local zones = {}
        for _, z in ipairs(m.all or {}) do if z.tracked then zones[#zones + 1] = z end end
        ns.AtlasChart.Draw(atlas, zones, w, L.atlasPanel, { current = m.current and m.current.mapID })
        rows[#rows + 1] = { items = { item(atlas, "atlas", "Atlas",
            "Every zone at its place on the map, with its art and progress. A opens the Atlas.",
            function() openAtlas() end, "R", "Open", L.plate + S.s3 + S.s3) }, section = 3 }
        y = y + L.atlasPanel + S.s4

        -- Your class road: the strip around You, then its caption (the Class tab's plaque lines).
        local cs = ns.ClassPage and ns.ClassPage.Summary and ns.ClassPage.Summary() or { title = "Class road", next = "" }
        classPlate:ClearAllPoints()
        classPlate:SetPoint("TOPLEFT", child, "TOPLEFT", x - 6, -y)
        classPlate:SetWidth(w + 12)
        classPlate.title:SetText(cs.title or "Class road")
        classPlate.title:SetTextColor(T.RGB(cs.complete and "complete" or "gold"))
        y = y + L.plate + S.s3
        local p = classPanel
        p:ClearAllPoints()
        p:SetPoint("TOPLEFT", child, "TOPLEFT", x, -y)
        p:SetWidth(w)
        local mini = p:EnsureMap(w - 2)
        if mini then mini.miniWidth = w - 2 end
        p.count:SetShown(cs.count ~= nil)
        p.count:SetText(cs.count or "")
        p.next:SetText(cs.next or "")
        p.next:SetTextColor(T.RGB(cs.nextColor or "classPeach"))
        p.train:SetShown(cs.train ~= nil)
        p.train:SetText(cs.train and ((cs.train == 1 and "1 ability" or (cs.train .. " abilities")) .. " waiting at your trainer") or "")
        local lines = (cs.count and 1 or 0) + 1 + (cs.train and 1 or 0)
        local ph = 1 + L.classMini + 1 + S.s2 + lines * L.classMiniLine + S.s3
        p:SetHeight(ph)
        -- Sentences (the info line ran "Stormwind City 9 abilities waiting", WoWScrnShot_111326_200956).
        local function sentence(t) return (t and t ~= "") and (t:gsub("[%.%s]+$", "") .. ". ") or "" end
        local detail = sentence(cs.count) .. sentence(cs.next) .. sentence(cs.train and p.train:GetText())
            .. "A opens the Class tab at your stop."
        rows[#rows + 1] = { items = { item(p, "classroad", cs.title or "Class road", detail,
            function() openClass() end, "R", "Class tab", L.plate + S.s3 + S.s3) }, section = 4 }
        y = y + ph + S.s2
        return rows, y
    end

    -- Draws the model. Focus rows: the left column's, then the right's, in reading order
    -- (LT/RT: Continue, Tracked completion, Atlas, class road). Each column is a group, so
    -- up/down stay in it and left/right cross to the nearest row of the other.
    local function draw(m)
        page.model = m
        local w = width()
        local inner = w - L.listInset - S.s6 - S.s6
        local lw = math.floor(inner * L.overviewLeft)
        local rw = inner - lw
        local leftRows, lh = drawLeft(m, L.listInset, lw)
        local rightRows, rh = drawRight(m, L.listInset + lw + S.s6, rw)
        local rows = {}
        for _, r in ipairs(leftRows) do rows[#rows + 1] = r end
        for _, r in ipairs(rightRows) do rows[#rows + 1] = r end
        page.rows = rows
        page.hasSections = true
        child:SetHeight(math.max(1, lh, rh))
    end
    page.Draw = draw

    function page:Redraw()
        self.dirty = false
        draw(ns.Overview.Model())
        if ns.UI.CurrentTab() == "overview" then
            ns.Focus.Rebuild()
            ns.UI.RefreshHints()
        end
    end

    function page:GetFocusRows() return self.rows or {} end

    -- Redraw what changed: now if shown (once per burst), else on the next show.
    local function changed()
        if page:IsShown() then
            ns.Events.Debounce("overview-redraw", 0.1, function() page:Redraw() end)
        else
            page.dirty = true
        end
    end
    for _, msg in ipairs({ "AZF_EXPLORATION_UPDATED", "AZF_ZONE_VISITED", "AZF_LEVEL_CHANGED",
        "AZF_QUESTS_UPDATED", "AZF_FLIGHTS_UPDATED", "AZF_CLASS_UPDATED", "AZF_PROFESSIONS_UPDATED" }) do
        ns.Events.On(msg, changed)
    end
    ns.Events.On("AZF_WINDOW_SHOWN", function() if page:IsShown() then page:Redraw() end end)
    page:SetScript("OnShow", function(self) if self.dirty then self:Redraw() end end)
    scroll.onWidth = function(w)
        if page.model and math.abs((page.drawnWidth or 0) - w) >= 1 then
            page.drawnWidth = w
            draw(page.model)
            if ns.UI.CurrentTab() == "overview" then ns.Focus.Rebuild() end
        end
    end

    draw(ns.Overview.Model())
    return page
end

ns.UI.RegisterTab({
    id = "overview",
    label = "Overview",
    icon = ns.Theme.Icon("overview", "Interface\\Icons\\INV_Misc_Book_11"),
    order = 1,
    info = "Your character's progress at a glance.",
    build = build,
})
