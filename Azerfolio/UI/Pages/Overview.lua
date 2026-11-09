-- Overview tab (spec §5, mockups/DESIGN.md "Overview" and "Step 6"): two columns that fit one
-- screen, every panel in the painted frame, section headers on painted plates.
--   Left: the Continue card (current zone, else the closest to finish, else the next for your
--   level), the Next goal, and Suggested next (up to 3 zones, each with its Next up picks:
--   areas, ready quests, a flight path).
--   Right: Tracked completion (one row per category plus Zones; the headline is the
--   equal-weight average of the categories with data), Recent zones (recently visited) and the
--   Atlas panel (the painted sea chart with every zone at its place; A opens the Atlas view).
-- What to show comes from ns.Overview (pure picks over ns.Zones and ns.Progression results);
-- this file only draws it. A on a zone opens Zone Detail, on a pick its page focused on it (B
-- comes back here); A on a category row opens Zones, on Zones opens it filtered.
-- Frames are pooled; the page redraws on discoveries, quest and flight updates, zone changes
-- and level-ups. (The Activity panel was removed in Phase 9 step 6, owner 2026-11-08.)
local _, ns = ...

local function color(name)
    local r, g, b = ns.Theme.RGB(name)
    return string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
end

local function zoneObject(z)
    return { mapID = z.mapID, name = z.name, continent = z.continent, minLevel = z.minLevel,
        maxLevel = z.maxLevel, entry = z }
end

-- Opens a zone's detail on the Zones tab (on one objective's page if given); B returns here.
local function openZone(z, target)
    ns.UI.SelectTab("zones")
    local frame = ns.UI.GetFrame()
    local zp = frame and frame.pages.zones
    if zp and zp.ShowZone then zp:ShowZone(zoneObject(z), target, "overview") end
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

-- Why a category has no numbers yet (Progression.Combine's pending reasons).
local PENDING = { achievements = "Waiting for the game's data", building = "Reading quests...",
    questiedb = "Needs the QuestieDB addon", flightmaster = "Talk to a flight master" }
local RULE = { current = "Current zone", closest = "Closest to complete", level = "Next for your level" }

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

local function buildGoal(parent)
    local T, L, S, W = ns.Theme, ns.Theme.layout, ns.Theme.space, ns.Widgets
    local g = newPanel(parent, true)
    g:SetHeight(L.goalHeight)
    g.flag = T.Text(g, "xs", "gold")
    g.flag:SetPoint("LEFT", S.s4, 0)
    g.flag:SetText("NEXT GOAL")
    g.text = T.Text(g, "sm", "text")
    g.bars = W.CatBars(g)
    g.bars:SetPoint("RIGHT", g, "RIGHT", -S.s4, 0)
    g.text:SetPoint("LEFT", g.flag, "RIGHT", S.s3, 0)
    g.text:SetPoint("RIGHT", g.bars, "LEFT", -S.s3, 0)
    g.text:SetJustifyH("LEFT"); g.text:SetWordWrap(false)
    return g
end

local function newGroup(parent)
    local T, L = ns.Theme, ns.Theme.layout
    local g = newPanel(parent, false)
    g.name = T.Text(g, "md", "white")
    g.name:SetPoint("TOPLEFT", L.panelPad, -L.panelPad + 2)
    g.why = T.Text(g, "xs", "dim")
    g.why:SetPoint("TOPRIGHT", -L.panelPad, -L.panelPad + 1)
    return g
end

-- One suggestion: category icon, name (quests in their difficulty colour), "Lv n" for quests.
local function newPick(parent)
    local T, L, S, W = ns.Theme, ns.Theme.layout, ns.Theme.space, ns.Widgets
    local b = W.FocusRow(parent, L.sugItem)
    b.bg = T.Solid(b, "ctlBg", "BACKGROUND", 0.9); b.bg:SetAllPoints()
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(18, 18); b.icon:SetPoint("LEFT", S.s2, 0)
    b.level = T.Text(b, "xs", "dim"); b.level:SetPoint("RIGHT", -S.s2, 0)
    b.name = T.Text(b, "sm", "white"); b.name:SetPoint("LEFT", b.icon, "RIGHT", S.s2, 0)
    b.name:SetPoint("RIGHT", b.level, "LEFT", -S.s2, 0)
    b.name:SetJustifyH("LEFT"); b.name:SetWordWrap(false)
    return b
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

local function newRecentRow(parent)
    local T, L, S, W = ns.Theme, ns.Theme.layout, ns.Theme.space, ns.Widgets
    local r = W.FocusRow(parent, L.recentRow)
    r.thumb = r:CreateTexture(nil, "ARTWORK")
    r.thumb:SetSize(L.recentThumb[1], L.recentThumb[2])
    r.thumb:SetPoint("LEFT", S.s2, 0)
    r.pct = T.Text(r, "sm", "text")
    r.pct:SetPoint("RIGHT", -S.s2, 0)
    r.pct:SetWidth(L.pctWidth); r.pct:SetJustifyH("RIGHT")
    r.name = T.Text(r, "sm", "white")
    r.name:SetPoint("TOPLEFT", r.thumb, "TOPRIGHT", S.s3, 1)
    r.name:SetPoint("RIGHT", r.pct, "LEFT", -S.s2, 0)
    r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
    r.bars = W.CatBars(r)
    r.bars:SetPoint("BOTTOMLEFT", r.thumb, "BOTTOMRIGHT", S.s3, 0)
    r.note = T.Text(r, "xs", "dim")
    r.note:SetPoint("BOTTOMLEFT", r.thumb, "BOTTOMRIGHT", S.s3, 0)
    return r
end

---------------------------------------------------------------------------------------------
-- Text
---------------------------------------------------------------------------------------------

local function percentText(z)
    if z.state == "untracked" then return "-" end
    return (z.combined and ns.Progression.PercentText(z.combined)) or "?"
end

-- "5 areas · 26 quests" (confirmed not done, per category with numbers).
local function leftText(z)
    local parts = {}
    for _, c in ipairs(z.cats or {}) do
        if not c.pending and (c.remaining or 0) > 0 then
            parts[#parts + 1] = c.remaining .. " " .. ns.Theme.category[c.key].unit
        end
    end
    return table.concat(parts, " · ")
end

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

    local pools = { groups = {}, picks = {}, recent = {}, track = {} }
    page.pools = pools
    local hero = buildHero(child)
    local goal = buildGoal(child)
    local sugPlate = T.Plate(child, L.plate)
    sugPlate.title:SetText("Suggested next")
    local sugEmpty = T.Text(child, "sm", "dim")
    sugEmpty:SetJustifyH("LEFT")

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

    local recentPlate = T.Plate(child, L.plate)
    recentPlate.title:SetText("Recent zones")
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
    local recentPanel = newPanel(child, false)
    local recentEmpty = T.Text(recentPanel, "sm", "dim")
    recentEmpty:SetJustifyH("LEFT")
    page.parts = { hero = hero, goal = goal, track = track, zonesRow = zrow, recent = recentPanel,
        sugEmpty = sugEmpty, recentEmpty = recentEmpty, sugPlate = sugPlate, recentPlate = recentPlate,
        atlas = atlas, atlasPlate = atlasPlate }

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
            group = group, scroll = scroll, actionLabel = actionLabel or "Open", topGap = topGap }
        frame:SetScript("OnClick", function() onActivate(frame.item) end)
        return frame.item
    end

    -- Draws the left column from x at width w. Returns its focus rows (each with a section).
    local function drawLeft(m, x, w)
        local rows, y, section = {}, 0, 1
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
                go) }, section = section }
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

        goal:SetShown(m.goal ~= nil)
        if m.goal then
            local z = m.goal
            y = y + S.s4
            goal:ClearAllPoints()
            goal:SetPoint("TOPLEFT", child, "TOPLEFT", x, -y)
            goal:SetWidth(w)
            goal.text:SetText(string.format("Finish %s%s|r · %d to go", color("white"), z.name, z.left or 0))
            goal.bars:Set(z.cats or {}, math.max(150, math.floor(w * 0.4)), true)
            rows[#rows + 1] = { items = { item(goal, "goal", "Next goal",
                string.format("%s: the zone in progress with the least left (%s).", z.name, leftText(z)),
                function() openZone(z) end, "L") }, section = section }
            y = y + L.goalHeight
        end

        -- Suggested next: one framed panel per zone with its Next up picks, two per line.
        y = y + S.s4
        sugPlate:ClearAllPoints()
        sugPlate:SetPoint("TOPLEFT", child, "TOPLEFT", x - 6, -y)
        sugPlate:SetWidth(w + 12)
        y = y + L.plate + S.s3
        for _, g in ipairs(pools.groups) do g:Hide() end
        for _, b in ipairs(pools.picks) do b:Hide() end
        sugEmpty:SetShown(#m.suggestions == 0)
        if #m.suggestions == 0 then
            sugEmpty:ClearAllPoints()
            sugEmpty:SetPoint("TOPLEFT", child, "TOPLEFT", x + S.s3, -y)
            sugEmpty:SetWidth(w - S.s3)
            sugEmpty:SetText(m.hero and "Nothing to suggest right now."
                or "Nothing to suggest: no zone you can do has anything left that the game confirms.")
            y = y + 24
        end
        local used = 0
        local pad = L.panelPad
        local colW = math.floor((w - 2 * pad - (L.sugCols - 1) * S.s2) / L.sugCols)
        for gi, s in ipairs(m.suggestions) do
            section = section + 1
            local g = pools.groups[gi]
            if not g then g = newGroup(child); pools.groups[gi] = g end
            g:ClearAllPoints()
            g:SetPoint("TOPLEFT", child, "TOPLEFT", x, -y)
            g:SetWidth(w)
            g.name:SetText(s.zone.name)
            local left = leftText(s.zone)
            g.why:SetText((RULE[s.rule] or "") .. (left ~= "" and (" · " .. left .. " left") or ""))
            g:Show()
            local top = pad + L.groupHead
            local row
            for i, it in ipairs(s.items) do
                used = used + 1
                local b = pools.picks[used]
                if not b then b = newPick(child); pools.picks[used] = b end
                local col, r = (i - 1) % L.sugCols, math.floor((i - 1) / L.sugCols)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", g, "TOPLEFT", pad + col * (colW + S.s2), -(top + r * (L.sugItem + S.s1)))
                b:SetWidth(colW)
                b.icon:SetTexture(T.category[it.kind] and T.category[it.kind].icon)
                b.name:SetText(it.name or "?")
                local dc = it.difficulty and ns.ZoneDetail.DifficultyColor(it.difficulty)
                if dc then b.name:SetTextColor(dc[1], dc[2], dc[3]) else b.name:SetTextColor(T.RGB("white")) end
                b.level:SetText(it.kind == "quests" and it.level and ("Lv " .. it.level) or "")
                b:Show()
                local zone, pick = s.zone, { kind = it.kind, id = it.id }
                local what = it.kind == "explore" and "Area to discover" or (it.kind == "flights" and "Flight path to discover"
                    or ("Quest, level " .. tostring(it.level or "?")))
                if col == 0 then row = { items = {}, section = section }; rows[#rows + 1] = row end
                table.insert(row.items, item(b, "pick:" .. it.kind .. ":" .. tostring(it.id), it.name or "?",
                    what .. " · " .. zone.name .. ". A opens it.", function() openZone(zone, pick) end,
                    "L", "Open", top + L.plate + S.s3))
            end
            local lines = math.ceil(#s.items / L.sugCols)
            local gh = top + lines * L.sugItem + (lines - 1) * S.s1 + pad
            g:SetHeight(gh)
            y = y + gh + S.s3
        end
        return rows, y
    end

    -- Draws the right column. Returns its focus items (one per row) and its height.
    local function drawRight(m, x, w)
        local items, y = {}, 0
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
            items[#items + 1] = item(r, "track:" .. cat.key, meta.label, detail, function() openZones() end, "R", "Zones")
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
        items[#items + 1] = item(zrow, "zones", "Zones",
            "Zones you can do (other faction's territory left out). Complete: exploration, quests and flight "
                .. "paths all done; in progress: some; untouched: none yet.",
            function() openZones(target) end, "R",
            target == "complete" and "Show complete" or (target == "progress" and "Show in progress" or "Zones"))
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
        y = y + ty + S.s4

        -- Recently visited zones, in a framed panel under their plate.
        recentPlate:ClearAllPoints()
        recentPlate:SetPoint("TOPLEFT", child, "TOPLEFT", x - 6, -y)
        recentPlate:SetWidth(w + 12)
        y = y + L.plate + S.s3
        recentPanel:ClearAllPoints()
        recentPanel:SetPoint("TOPLEFT", child, "TOPLEFT", x, -y)
        recentPanel:SetWidth(w)
        for _, r in ipairs(pools.recent) do r:Hide() end
        local ry = S.s3
        recentEmpty:SetShown(#m.recent == 0)
        if #m.recent == 0 then
            recentEmpty:ClearAllPoints()
            recentEmpty:SetPoint("TOPLEFT", recentPanel, "TOPLEFT", pad + 2, -ry - 2)
            recentEmpty:SetWidth(w - 2 * pad)
            recentEmpty:SetText("Zones you travel through will be listed here.")
            ry = ry + 24
        end
        for i, z in ipairs(m.recent) do
            local r = pools.recent[i]
            if not r then r = newRecentRow(recentPanel); pools.recent[i] = r end
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", recentPanel, "TOPLEFT", S.s2, -ry)
            r:SetWidth(w - 2 * S.s2)
            setArt(r.thumb, z)
            cropArt(r.thumb, z.mapID, L.recentThumb[1], L.recentThumb[2])
            r.name:SetText(z.name)
            r.pct:SetText(percentText(z))
            r.pct:SetTextColor(T.RGB(z.state == "complete" and "complete" or (z.state == "progress" and "todo" or "dim")))
            local hasCats = z.cats and #z.cats > 0
            r.bars:SetShown(hasCats)
            r.note:SetShown(not hasCats)
            if hasCats then
                r.bars:Set(z.cats, w - 2 * S.s2 - S.s2 - L.recentThumb[1] - S.s3 - L.pctWidth - S.s3, true)
            else
                r.note:SetText(z.state == "untracked" and "not tracked" or "no data")
            end
            r:Show()
            items[#items + 1] = item(r, "recent:" .. z.mapID, z.name, ns.ZonesCatalogue.ZoneDetail(z),
                function() openZone(z) end, "R", "Open", L.plate + S.s3 + S.s3)
            ry = ry + L.recentRow + 2
        end
        recentPanel:SetHeight(ry + S.s2)
        y = y + ry + S.s2 + S.s4

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
        items[#items + 1] = item(atlas, "atlas", "Atlas",
            "Every zone at its place on the map, with its art and progress. A opens the Atlas.",
            function() openAtlas() end, "R", "Open", L.plate + S.s3 + S.s3)
        y = y + L.atlasPanel + S.s2
        return items, y
    end

    -- Draws the model. Focus rows pair the left column's rows with the right column's items
    -- (FocusGrid groups keep up/down inside a column; left/right crosses).
    local function draw(m)
        page.model = m
        local w = width()
        local inner = w - L.listInset - S.s6 - S.s6
        local lw = math.floor(inner * L.overviewLeft)
        local rw = inner - lw
        local leftRows, lh = drawLeft(m, L.listInset, lw)
        local rightItems, rh = drawRight(m, L.listInset + lw + S.s6, rw)
        local rows, lastSection = {}, 1
        for i = 1, math.max(#leftRows, #rightItems) do
            local items, section = {}, lastSection
            if leftRows[i] then
                for _, it in ipairs(leftRows[i].items) do items[#items + 1] = it end
                section = leftRows[i].section
            end
            if rightItems[i] then items[#items + 1] = rightItems[i] end
            rows[#rows + 1] = { items = items, section = section }
            lastSection = section
        end
        page.rows = rows
        page.hasSections = lastSection > 1
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
        "AZF_QUESTS_UPDATED", "AZF_FLIGHTS_UPDATED" }) do
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
