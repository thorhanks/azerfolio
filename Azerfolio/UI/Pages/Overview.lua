-- Overview tab (spec §5, mockups/DESIGN.md "Overview"): two columns that fit one screen.
--   Left: the Continue card (current zone, else the closest to finish, else the next for your
--   level), the Next goal, and Suggested next (up to 3 zones, up to 6 undiscovered areas each).
--   Right: Tracked completion (the categories it includes), Zones (stacked bar), Recent zones
--   (recently visited) and Activity (discoveries per day, latest milestones).
-- What to show comes from ns.Overview (pure picks over ns.Zones and ns.Progression results);
-- this file only draws it. A on a zone or an area opens Zone Detail (B comes back here); A on
-- Tracked completion opens Zones, on Zones opens it filtered to complete zones.
-- Frames are pooled; the page redraws on discoveries, milestones, zone changes and level-ups.
local _, ns = ...

local function color(name)
    local r, g, b = ns.Theme.RGB(name)
    return string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
end

local function plural(n, one, many) return n == 1 and (n .. " " .. one) or (n .. " " .. many) end

local function zoneObject(z)
    return { mapID = z.mapID, name = z.name, continent = z.continent, minLevel = z.minLevel,
        maxLevel = z.maxLevel, entry = z }
end

-- Opens a zone's detail on the Zones tab (focused on an area if given); B returns here.
local function openZone(z, criteriaID)
    ns.UI.SelectTab("zones")
    local frame = ns.UI.GetFrame()
    local zp = frame and frame.pages.zones
    if zp and zp.ShowZone then zp:ShowZone(zoneObject(z), criteriaID, "overview") end
end

local function openZones(status)
    ns.UI.SelectTab("zones")
    local frame = ns.UI.GetFrame()
    local zp = frame and frame.pages.zones
    if status and zp and zp.ShowStatus then zp:ShowStatus(status) end
end

---------------------------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------------------------

-- A dark card with a 1 px edge; focus = 2 px yellow edge (art cards and panels, DESIGN.md).
local function newPanel(parent, focusable)
    local T, W = ns.Theme, ns.Widgets
    local p = CreateFrame(focusable and "Button" or "Frame", nil, parent)
    p.bg = T.Solid(p, "cardBg", "BACKGROUND", 0.85)
    p.bg:SetAllPoints()
    p.edge = W.Edge(p, "ARTWORK")
    p.edgeColor = "cardEdge"
    function p:Paint()
        if self.focused then
            self.edge:SetColor("focus"); self.edge:SetThickness(2)
        else
            self.edge:SetColor(self.edgeColor); self.edge:SetThickness(1)
        end
    end
    function p:SetFocused(on) self.focused = on; self:Paint() end
    p:Paint()
    if focusable then W.HoverInfo(p) end
    return p
end

-- A thin bar: dark well, gold fill (fraction 0..1; nil = no fill).
local function newBar(parent)
    local T, L = ns.Theme, ns.Theme.layout
    local b = CreateFrame("Frame", nil, parent)
    b:SetHeight(L.statBar)
    b.bg = T.Solid(b, "black", "BACKGROUND")
    b.bg:SetAllPoints()
    b.fill = T.Solid(b, "complete", "ARTWORK")
    b.fill:SetPoint("TOPLEFT"); b.fill:SetPoint("BOTTOMLEFT")
    b.segs = {}
    function b:SetFraction(f, width)
        self.fill:SetShown(f ~= nil and f > 0)
        if f and f > 0 then self.fill:SetWidth(math.max(2, math.floor(width * math.min(1, f) + 0.5))) end
    end
    -- Stacked segments { { n, colorName }, ... } over `total`, 2 px apart.
    function b:SetStack(parts, total, width)
        self.fill:Hide()
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
    h.glyph = T.Glyph(h, "A")
    h.glyph:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", x - 4, S.s2)
    h.go = T.Text(h, "sm", "gold")
    h.pct = T.Text(h, "xxl", "white")
    h.pct:SetPoint("RIGHT", h, "RIGHT", -S.s4, S.s2)
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
    g.flag:SetPoint("LEFT", S.s3, 0)
    g.flag:SetText("NEXT GOAL")
    g.text = T.Text(g, "sm", "text")
    g.text:SetPoint("LEFT", g.flag, "RIGHT", S.s3, 0)
    g.text:SetWordWrap(false)
    g.pips = W.Pips(g)
    g.pips:SetPoint("LEFT", g.text, "RIGHT", S.s3, 0)
    return g
end

local function newGroup(parent)
    local T, S = ns.Theme, ns.Theme.space
    local g = newPanel(parent, false)
    g.name = T.Text(g, "md", "white")
    g.name:SetPoint("TOPLEFT", S.s3, -S.s2)
    g.why = T.Text(g, "xs", "dim")
    g.why:SetPoint("TOPRIGHT", -S.s3, -S.s2 - 2)
    g.more = T.Text(g, "xs", "dim")
    return g
end

local function newChip(parent)
    local T, L, S, W = ns.Theme, ns.Theme.layout, ns.Theme.space, ns.Widgets
    local c = W.Control(parent)
    c:SetHeight(L.chipHeight)
    c.dot = c:CreateTexture(nil, "ARTWORK")
    c.dot:SetSize(L.chipDot, L.chipDot)
    c.dot:SetPoint("LEFT", L.chipPad, 0)
    local r, g, b = T.RGB("todo")
    c.dot:SetColorTexture(r, g, b, 1)
    local mask = c:CreateMaskTexture()
    if mask then
        mask:SetAllPoints(c.dot)
        mask:SetTexture(T.circleMask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        pcall(c.dot.AddMaskTexture, c.dot, mask)
    end
    c.text:ClearAllPoints()
    c.text:SetPoint("LEFT", c.dot, "RIGHT", S.s2 - 2, 0)
    function c:SetName(text)
        self.text:SetText(text)
        self:SetWidth(math.floor((self.text:GetStringWidth() or 0) + 2 * L.chipPad + L.chipDot + S.s2 - 2 + 0.5))
    end
    return c
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
    r.pips = W.Pips(r)
    r.pips:SetPoint("BOTTOMLEFT", r.thumb, "BOTTOMRIGHT", S.s3, 1)
    r.note = T.Text(r, "xs", "dim")
    r.note:SetPoint("BOTTOMLEFT", r.thumb, "BOTTOMRIGHT", S.s3, 0)
    return r
end

local function newMilestone(parent)
    local T, L, S = ns.Theme, ns.Theme.layout, ns.Theme.space
    local m = CreateFrame("Frame", nil, parent)
    m:SetHeight(L.milestoneRow)
    m.rule = T.Solid(m, "white", "BACKGROUND", 0.07)
    m.rule:SetPoint("TOPLEFT"); m.rule:SetPoint("TOPRIGHT"); m.rule:SetHeight(1)
    m.icon = m:CreateTexture(nil, "ARTWORK")
    m.icon:SetSize(L.milestoneIcon, L.milestoneIcon)
    m.icon:SetPoint("LEFT", 0, 0)
    m.icon:SetTexture(T.files.checkDone)
    if m.icon.SetDesaturated then m.icon:SetDesaturated(true) end
    m.icon:SetVertexColor(T.RGB("complete"))
    m.time = T.Text(m, "xs", "dim")
    m.time:SetPoint("RIGHT", 0, 0)
    m.text = T.Text(m, "sm", "text")
    m.text:SetPoint("LEFT", m.icon, "RIGHT", S.s2, 0)
    m.text:SetPoint("RIGHT", m.time, "LEFT", -S.s2, 0)
    m.text:SetJustifyH("LEFT"); m.text:SetWordWrap(false)
    return m
end

---------------------------------------------------------------------------------------------
-- Text
---------------------------------------------------------------------------------------------

local function percentText(z)
    if z.state == "untracked" then return "-" end
    return (z.progress and ns.Progression.PercentText(z.progress)) or "?"
end

local function kicker(model)
    local hero, cur = model.hero, model.current
    if hero.why == "current" then
        local z, p = hero.zone, hero.zone.progress
        if z.state == "complete" then return "Your zone · claimed" end
        if p and p.denominator > 0 and p.remaining == 0 then return "Your zone · every area discovered" end
        return (z.state == "untouched" and "Start" or "Continue") .. " · your zone"
    end
    if cur and cur.state == "complete" then return cur.name .. " explored · next up" end
    if hero.why == "level" then return "Next for your level" end
    return "Continue exploring"
end

local function whyText(g)
    local left = g.zone.progress.remaining
    if g.rule == "current" then return "Current zone · " .. left .. " left" end
    if g.rule == "closest" then return "Closest to complete · " .. left .. " left" end
    if g.zone.state == "untouched" then return "Next for your level · " .. plural(left, "area", "areas") end
    return "Next for your level · " .. left .. " left"
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

    local pools = { groups = {}, chips = {}, recent = {}, milestones = {} }
    page.pools = pools
    local hero = buildHero(child)
    local goal = buildGoal(child)
    local sugHeader = W.Header(child)
    sugHeader.text:SetText("Suggested next")
    local sugEmpty = T.Text(child, "sm", "dim")
    sugEmpty:SetJustifyH("LEFT")

    local completion = newPanel(child, true)
    completion:SetHeight(L.counterHeight)
    completion.title = T.Text(completion, "sm", "gold")
    completion.title:SetPoint("TOPLEFT", S.s3, -S.s3)
    completion.title:SetText("Tracked completion")
    completion.pct = T.Text(completion, "lg", "white")
    completion.pct:SetPoint("TOPRIGHT", -S.s3, -S.s2)
    completion.bar = newBar(completion)
    completion.bar:SetPoint("TOPLEFT", S.s3, -36)
    completion.line = T.Text(completion, "xs", "dim")
    completion.line:SetPoint("BOTTOMLEFT", S.s3, S.s2)
    completion.line:SetPoint("RIGHT", -S.s3, 0)
    completion.line:SetJustifyH("LEFT"); completion.line:SetWordWrap(false)

    local zonesPanel = newPanel(child, true)
    zonesPanel:SetHeight(L.zonesCounterHeight)
    zonesPanel.title = T.Text(zonesPanel, "sm", "gold")
    zonesPanel.title:SetPoint("TOPLEFT", S.s3, -S.s3)
    zonesPanel.title:SetText("Zones")
    zonesPanel.count = T.Text(zonesPanel, "sm", "dim")
    zonesPanel.count:SetPoint("TOPRIGHT", -S.s3, -S.s3)
    zonesPanel.bar = newBar(zonesPanel)
    zonesPanel.bar:SetPoint("TOPLEFT", S.s3, -36)
    zonesPanel.legend = T.Text(zonesPanel, "xs", "dim")
    zonesPanel.legend:SetPoint("BOTTOMLEFT", S.s3, S.s3)

    local recentHeader = W.Header(child)
    recentHeader.text:SetText("Recent zones")
    local recentEmpty = T.Text(child, "sm", "dim")
    recentEmpty:SetJustifyH("LEFT")

    local actHeader = W.Header(child)
    actHeader.text:SetText("Activity")
    local act = newPanel(child, false)
    act.label = T.Text(act, "xs", "dim")
    act.label:SetPoint("TOPLEFT", S.s3, -S.s2)
    act.label:SetText("Areas discovered per day")
    act.today = T.Text(act, "xs", "dim")
    act.today:SetPoint("TOPRIGHT", -S.s3, -S.s2)
    act.from = T.Text(act, "xs", "dim")
    act.from:SetText("2 weeks ago")
    act.to = T.Text(act, "xs", "dim")
    act.to:SetText("Today")
    act.bars = {}
    for i = 1, ns.Overview.ACTIVITY_DAYS do act.bars[i] = act:CreateTexture(nil, "ARTWORK") end
    act.empty = T.Text(act, "sm", "dim")
    act.empty:SetJustifyH("LEFT")
    page.parts = { hero = hero, goal = goal, completion = completion, zones = zonesPanel, activity = act,
        sugEmpty = sugEmpty, recentEmpty = recentEmpty }

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
            local cp = z.combined
            hero.pct:SetText(z.state == "complete" and "Claimed" or (cp and ns.Progression.PercentText(cp) or "-"))
            hero.pct:SetTextColor(T.RGB(z.state == "complete" and "complete" or ((cp and cp.completed > 0) and "todo" or "white")))
            hero.count:SetText(p and string.format("%d of %d areas", p.completed, p.denominator) or "")
            local pad = ns.Gamepad and ns.Gamepad.IsActive()
            hero.glyph:SetShown(pad)
            hero.go:ClearAllPoints()
            if pad then
                hero.go:SetPoint("LEFT", hero.glyph, "RIGHT", S.s1, 0)
            else
                hero.go:SetPoint("BOTTOMLEFT", hero, "BOTTOMLEFT", L.heroArt + S.s4, S.s3)
            end
            local go = z.state == "complete" and "Open" or (z.state == "untouched" and "Start" or "Continue")
            hero.go:SetText(go)
            local detail = ns.ZonesCatalogue.ZoneDetail(z) .. "  ·  Open the zone to see what's left."
            rows[#rows + 1] = { items = { item(hero, "hero", z.name, detail, function() openZone(z) end, "L",
                go) }, section = section }
            y = y + L.heroHeight
        else
            hero.empty:ClearAllPoints()
            hero.empty:SetPoint("TOPLEFT", child, "TOPLEFT", x, -y - S.s2)
            hero.empty:SetWidth(w)
            local c = m.completion
            hero.empty:SetText((not c.progress or c.unavailable > 0)
                and "Waiting for the game's achievement data. It usually arrives a few seconds after login."
                or "Nothing left to continue: every zone you can explore is fully explored.")
            y = y + 48
        end

        goal:SetShown(m.goal ~= nil)
        if m.goal then
            local z, p = m.goal, m.goal.progress
            y = y + S.s3
            goal:ClearAllPoints()
            goal:SetPoint("TOPLEFT", child, "TOPLEFT", x, -y)
            goal:SetWidth(w)
            goal.text:SetText(string.format("Finish %s%s|r · %d to go", color("white"), z.name, p.remaining))
            local room = w - S.s3 - (goal.flag:GetStringWidth() or 0) - S.s3 - (goal.text:GetStringWidth() or 0) - 2 * S.s3
            goal.pips:Set(p.complete, p.incomplete, p.completionUnknown, math.max(40, room))
            rows[#rows + 1] = { items = { item(goal, "goal", "Next goal",
                string.format("%s: the zone in progress with the fewest areas left (%d).", z.name, p.remaining),
                function() openZone(z) end, "L") }, section = section }
            y = y + L.goalHeight
        end

        -- Suggested next: one panel per zone, its undiscovered areas as chips.
        y = y + S.s4
        sugHeader:ClearAllPoints()
        sugHeader:SetPoint("TOPLEFT", child, "TOPLEFT", x, -y)
        sugHeader:SetWidth(w)
        y = y + L.listHeader + S.s2
        for _, g in ipairs(pools.groups) do g:Hide() end
        for _, c in ipairs(pools.chips) do c:Hide() end
        sugEmpty:SetShown(#m.suggestions == 0)
        if #m.suggestions == 0 then
            sugEmpty:ClearAllPoints()
            sugEmpty:SetPoint("TOPLEFT", child, "TOPLEFT", x + S.s3, -y)
            sugEmpty:SetWidth(w - S.s3)
            sugEmpty:SetText(m.hero and "Nothing to suggest right now."
                or "Nothing to suggest: no zone you can explore has areas left that the game confirms.")
            y = y + 24
        end
        local chipsUsed = 0
        for gi, s in ipairs(m.suggestions) do
            section = section + 1
            local g = pools.groups[gi]
            if not g then g = newGroup(child); pools.groups[gi] = g end
            g:ClearAllPoints()
            g:SetPoint("TOPLEFT", child, "TOPLEFT", x, -y)
            g:SetWidth(w)
            g.name:SetText(s.zone.name)
            g.why:SetText(whyText(s))
            g:Show()
            local cx, cy, inner = S.s3, L.groupHead + S.s2, w - 2 * S.s3
            local row = {}
            local function flush()
                if #row > 0 then rows[#rows + 1] = { items = row, section = section } end
                row = {}
            end
            for _, o in ipairs(s.objectives) do
                chipsUsed = chipsUsed + 1
                local c = pools.chips[chipsUsed]
                if not c then c = newChip(child); pools.chips[chipsUsed] = c end
                c:SetName(o.name or "?")
                local cw = c:GetWidth()
                if cx > S.s3 and cx + cw > S.s3 + inner then
                    flush()
                    cx, cy = S.s3, cy + L.chipHeight + S.s2 - 2
                end
                c:ClearAllPoints()
                c:SetPoint("TOPLEFT", g, "TOPLEFT", cx, -cy)
                c:Show()
                local zone, id = s.zone, o.id
                row[#row + 1] = item(c, "chip:" .. tostring(o.id), o.name,
                    "Not discovered yet · " .. zone.name .. " · Exploration", function() openZone(zone, id) end,
                    "L", "Open", L.groupHead + S.s2 + L.listHeader)
                cx = cx + cw + S.s2 - 2
            end
            flush()
            g.more:SetShown(s.more > 0)
            if s.more > 0 then
                g.more:SetText("+" .. s.more .. " more")
                local mw = g.more:GetStringWidth() or 0
                if cx + mw > S.s3 + inner then cx, cy = S.s3, cy + L.chipHeight + S.s2 - 2 end
                g.more:ClearAllPoints()
                g.more:SetPoint("LEFT", g, "TOPLEFT", cx + S.s1, -(cy + L.chipHeight / 2))
            end
            local gh = cy + L.chipHeight + S.s2
            g:SetHeight(gh)
            y = y + gh + S.s2
        end
        return rows, y
    end

    -- Draws the right column. Returns its focus items (one per row) and its height.
    local function drawRight(m, x, w)
        local items, y = {}, 0
        -- Tracked completion: exploration is the only category so far.
        local c, p = m.completion, m.completion.progress
        completion:ClearAllPoints()
        completion:SetPoint("TOPLEFT", child, "TOPLEFT", x, -y)
        completion:SetWidth(w)
        local pct = p and ns.Progression.PercentText(p)
        completion.pct:SetText(pct or "-")
        completion.bar:SetWidth(w - 2 * S.s3)
        completion.bar:SetFraction(p and p.percent and p.percent / 100, w - 2 * S.s3)
        local line, detail
        if pct then
            local cat = c.categories[1]
            line = string.format("Includes %s: %d of %d areas discovered", cat.name, cat.completed, cat.denominator)
            if p.coverage ~= "complete" then line = line .. " (some zones left out)" end
            detail = string.format("Areas the game confirms discovered, out of every area in the %d zones with an "
                .. "Explore achievement. Only exploration is tracked so far.", c.zones)
        else
            line = c.unavailable > 0
                and string.format("Waiting for the game's data (%d of %d zones unreadable)", c.unavailable, c.zones)
                or "No tracked objectives yet"
            detail = "No percentage until the game returns every zone's exploration data."
        end
        completion.line:SetText(line)
        items[#items + 1] = item(completion, "completion", "Tracked completion", detail,
            function() openZones() end, "R", "Zones")
        y = y + L.counterHeight + S.s2

        -- Zones: complete / in progress / untouched (/ unknown) over the zones you can explore.
        local zc = m.zones
        zonesPanel:ClearAllPoints()
        zonesPanel:SetPoint("TOPLEFT", child, "TOPLEFT", x, -y)
        zonesPanel:SetWidth(w)
        zonesPanel.count:SetText(string.format("%s%d|r of %d complete", color("white"), zc.complete, zc.applicable))
        zonesPanel.bar:SetWidth(w - 2 * S.s3)
        zonesPanel.bar:SetStack({ { zc.complete, "complete" }, { zc.progress, "todo" }, { zc.untouched, "well" },
            { zc.unknown, "black" } }, zc.applicable, w - 2 * S.s3)
        local legend = string.format("%s%d complete|r   %s%d in progress|r   %d untouched", color("complete"),
            zc.complete, color("todo"), zc.progress, zc.untouched)
        if zc.unknown > 0 then legend = legend .. "   " .. zc.unknown .. " no data" end
        zonesPanel.legend:SetText(legend)
        local target = zc.complete > 0 and "complete" or (zc.progress > 0 and "progress" or "all")
        items[#items + 1] = item(zonesPanel, "zones", "Zones",
            "Zones with an Explore achievement that you can explore (other faction's territory left out). "
                .. "Complete: every area found; in progress: some; untouched: none yet.",
            function() openZones(target) end, "R",
            target == "complete" and "Show complete" or (target == "progress" and "Show in progress" or "Zones"))
        y = y + L.zonesCounterHeight + S.s4

        -- Recently visited zones.
        recentHeader:ClearAllPoints()
        recentHeader:SetPoint("TOPLEFT", child, "TOPLEFT", x, -y)
        recentHeader:SetWidth(w)
        y = y + L.listHeader + S.s1
        for _, r in ipairs(pools.recent) do r:Hide() end
        recentEmpty:SetShown(#m.recent == 0)
        if #m.recent == 0 then
            recentEmpty:ClearAllPoints()
            recentEmpty:SetPoint("TOPLEFT", child, "TOPLEFT", x + S.s3, -y - S.s1)
            recentEmpty:SetWidth(w - S.s3)
            recentEmpty:SetText("Zones you travel through will be listed here.")
            y = y + 24
        end
        for i, z in ipairs(m.recent) do
            local r = pools.recent[i]
            if not r then r = newRecentRow(child); pools.recent[i] = r end
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", child, "TOPLEFT", x, -y)
            r:SetWidth(w)
            setArt(r.thumb, z)
            cropArt(r.thumb, z.mapID, L.recentThumb[1], L.recentThumb[2])
            r.name:SetText(z.name)
            r.pct:SetText(percentText(z))
            r.pct:SetTextColor(T.RGB(z.state == "complete" and "complete" or (z.state == "progress" and "todo" or "dim")))
            local pr = z.progress
            r.pips:SetShown(pr ~= nil)
            r.note:SetShown(pr == nil)
            if pr then
                r.pips:Set(pr.complete, pr.incomplete, pr.completionUnknown,
                    w - S.s2 - L.recentThumb[1] - S.s3 - L.pctWidth - S.s3)
            else
                r.note:SetText(z.state == "untracked" and "not tracked" or "no data")
            end
            r:Show()
            items[#items + 1] = item(r, "recent:" .. z.mapID, z.name, ns.ZonesCatalogue.ZoneDetail(z),
                function() openZone(z) end, "R", "Open", L.listHeader + S.s1)
            y = y + L.recentRow + 2
        end
        y = y + S.s4

        -- Activity: discoveries per day and the latest milestones (not focusable).
        actHeader:ClearAllPoints()
        actHeader:SetPoint("TOPLEFT", child, "TOPLEFT", x, -y)
        actHeader:SetWidth(w)
        y = y + L.listHeader + S.s1
        local a = m.activity
        act:ClearAllPoints()
        act:SetPoint("TOPLEFT", child, "TOPLEFT", x, -y)
        act:SetWidth(w)
        act.today:SetText(color("white") .. a.today .. "|r today")
        local inner = w - 2 * S.s3
        local n = #act.bars
        local bw = (inner - (n - 1) * L.sparkGap) / n
        local base = S.s2 + 16 + S.s2 + L.sparkHeight
        for i, b in ipairs(act.bars) do
            local cnt = a.counts[i] or 0
            local h = cnt > 0 and math.max(4, math.floor(L.sparkHeight * cnt / math.max(1, a.max) + 0.5)) or 3
            local r, g, bl = T.RGB(cnt > 0 and "complete" or "well")
            b:SetColorTexture(r, g, bl, 1)
            b:ClearAllPoints()
            b:SetPoint("BOTTOMLEFT", act, "TOPLEFT", S.s3 + (i - 1) * (bw + L.sparkGap), -base)
            b:SetSize(math.max(1, bw), h)
        end
        act.from:ClearAllPoints(); act.from:SetPoint("TOPLEFT", act, "TOPLEFT", S.s3, -base - 2)
        act.to:ClearAllPoints(); act.to:SetPoint("TOPRIGHT", act, "TOPRIGHT", -S.s3, -base - 2)
        local ay = base + 2 + 16 + S.s1
        for _, r in ipairs(pools.milestones) do r:Hide() end
        act.empty:SetShown(#m.milestones == 0)
        if #m.milestones == 0 then
            act.empty:ClearAllPoints()
            act.empty:SetPoint("TOPLEFT", act, "TOPLEFT", S.s3, -ay - S.s1)
            act.empty:SetText("Your discoveries will appear here.")
            ay = ay + 26
        end
        for i, ms in ipairs(m.milestones) do
            local r = pools.milestones[i]
            if not r then r = newMilestone(act); pools.milestones[i] = r end
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", act, "TOPLEFT", S.s3, -ay)
            r:SetPoint("TOPRIGHT", act, "TOPRIGHT", -S.s3, -ay)
            if ms.kind == "zone" then
                r.text:SetText(color("complete") .. ms.zoneName .. " fully explored|r")
            else
                r.text:SetText(string.format("Discovered %s%s|r  %s· %s|r", color("white"), ms.name or "?",
                    color("dim"), ms.zoneName))
            end
            r.time:SetText(ms.when or "")
            r:Show()
            ay = ay + L.milestoneRow
        end
        act:SetHeight(ay + S.s2)
        y = y + ay + S.s2
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
    for _, msg in ipairs({ "AZF_EXPLORATION_UPDATED", "AZF_MILESTONE", "AZF_ZONE_VISITED", "AZF_LEVEL_CHANGED",
        "AZF_QUESTS_UPDATED", "AZF_FLIGHTS_UPDATED" }) do
        ns.Events.On(msg, changed)
    end
    -- Gamepad on/off changes the Continue card's A prompt.
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
    icon = "Interface\\Icons\\INV_Misc_Book_11",
    order = 1,
    info = "Your character's progress at a glance.",
    build = build,
})
