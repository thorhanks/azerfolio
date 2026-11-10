-- Class tab (Phase 13, mockups/DESIGN.md "Class tab"): this character's class quests as a
-- journey. Left: the journey strip, one node per stop with a bead per quest, side paths that end
-- at a cairn, the road's end; a plaque above it with the counts. Until the painted strip exists
-- the strip is a stand-in drawn from the curated stops (Theme.classStrip, or laid out here).
-- Right: the selected stop (or the road's end). Data only from ns.ClassJourney.Get(); quest
-- names, levels and starters from ns.Quests (QuestieDB). The page draws the states and counts
-- ClassJourneyRules gives; it never decides what is done.
-- Gamepad: up/down along the road, left/right onto a side path, LT/RT stop to stop, A into the
-- steps, B back to the road.
local _, ns = ...

local STATE_LABEL = { done = "Done", progress = "In progress", ready = "You can start it", later = "Later",
    unknown = "Not known yet" }
local WHY = { prerequisite = "needs the step before it", ["parent quest"] = "comes inside the step before it",
    ["completed quests not known"] = "your completed quests aren't known yet" }

local function N(n) return tostring(n) end

-- "level 12" -> "opens at level 12"; known reasons in words; others as given.
local function whyText(reason)
    if type(reason) ~= "string" then return nil end
    local lv = reason:match("^level (%d+)")
    if lv then return "opens at level " .. lv end
    return WHY[reason] or reason
end

local function questName(id)
    local r = ns.Quests.Info(id)
    return r and r.name or ("Quest " .. tostring(id))
end

local function questLevel(id)
    local r = ns.Quests.Info(id)
    return r and (r.level or r.reqLevel)
end

-- "Duthorian Rall · Stormwind City", "A Strange Artifact (object) · Ashenvale", nil.
local function starterText(id)
    local s = ns.Quests.Starter and ns.Quests.Starter(id)
    if not s then return nil end
    local name = s.name or "Someone"
    if s.kind == "object" then name = name .. " (object)" elseif s.kind == "item" then name = name .. " (item)" end
    return s.place and (name .. "  ·  " .. s.place) or name
end

local function charLevel() return ns.character and ns.character.level end

-- One line under a node: what the stop asks of you now.
local function stopSub(s)
    if s.state == "done" then return "All " .. s.count .. (s.count == 1 and " quest done" or " quests done") end
    if s.state == "progress" then return s.done .. " of " .. s.count .. " quests" end
    if s.state == "ready" then return "Open now  ·  " .. s.count .. (s.count == 1 and " quest" or " quests") end
    if s.state == "later" then return "Opens at level " .. tostring(s.level or "?") end
    return s.count .. (s.count == 1 and " quest" or " quests") .. "  ·  done or not not known"
end

-- The info line for a stop (title is its name).
local function stopInfo(s, action)
    local parts = {}
    if s.kind == "side" then parts[#parts + 1] = "Side path." end
    parts[#parts + 1] = "Level " .. tostring(s.level or "?") .. "."
    if s.state == "done" then parts[#parts + 1] = "Done."
    elseif s.done then parts[#parts + 1] = s.done .. " of " .. s.count .. " quests done."
    else parts[#parts + 1] = s.count .. " quests; done or not isn't known yet." end
    parts[#parts + 1] = "Reward: " .. (s.reward or "not known yet") .. "."
    local lv = charLevel()
    if s.state == "later" and s.level and lv and s.level > lv then
        parts[#parts + 1] = "Opens at level " .. s.level .. " (" .. (s.level - lv) .. " to go)."
    end
    if action then parts[#parts + 1] = action end
    return table.concat(parts, " ")
end

-- Per-step display: done; the first step you can do now is your "next"; other open steps
-- "after"; locked "later"; unknown.
local function stepKinds(stop)
    local out, given = {}, false
    for i, st in ipairs(stop.steps) do
        local k
        if st.state == "done" then k = "done"
        elseif st.state == "eligible" then k = given and "after" or "next"; given = true
        elseif st.state == "locked" then k = "later"
        else k = "unknown" end
        out[i] = k
    end
    return out
end

---------------------------------------------------------------------------------------------
-- Strip geometry (logical units, Theme.layout.classTab.mapW wide)
---------------------------------------------------------------------------------------------

local function bez(p, t)
    local u = 1 - t
    local a, b, c, d = u * u * u, 3 * u * u * t, 3 * u * t * t, t * t * t
    return a * p[1][1] + b * p[2][1] + c * p[3][1] + d * p[4][1], a * p[1][2] + b * p[2][2] + c * p[3][2] + d * p[4][2]
end

-- Road segment from a stop to the next (as the mockup's roadSegs).
local function roadSeg(a, b)
    local dy = b[2] - a[2]
    return { { a[1], a[2] }, { a[1], a[2] + dy * 0.55 }, { b[1], b[2] - dy * 0.55 }, { b[1], b[2] } }
end

local function sideSeg(from, to)
    return { { from[1], from[2] }, { from[1] + (to[1] - from[1]) * 0.6, from[2] + 10 },
        { to[1], to[2] - (to[2] - from[2]) * 0.6 }, { to[1], to[2] } }
end

-- The layout for a built journey: { W, H, pos = { [key] = {x, y} }, endPos, road = { stop... },
-- sides = { [roadKey] = { stop... } }, segs = { [key] = curve }, from = { [sideKey] = roadKey } }.
-- Hand-placed positions (Theme.classStrip) when every stop has one; otherwise laid out: road
-- stops zigzag down, a stop's side paths stack on the far side of its segment.
local function layoutFor(journey, classFile, side)
    local CT = ns.Theme.layout.classTab
    local W = CT.mapW
    local road, sides, from = {}, {}, {}
    local lastRoad
    for _, s in ipairs(journey.stops) do
        if s.kind == "side" and (lastRoad or s.from) then
            local f = s.from
            local onRoad = false
            for _, r in ipairs(road) do if r.key == f then onRoad = true end end
            if not onRoad then f = lastRoad and lastRoad.key end
            if f then
                sides[f] = sides[f] or {}
                table.insert(sides[f], s)
                from[s.key] = f
            else
                road[#road + 1] = s; lastRoad = s
            end
        else
            road[#road + 1] = s; lastRoad = s
        end
    end
    local hand = ns.Theme.classStrip[classFile] and ns.Theme.classStrip[classFile][side]
    if hand then
        for _, s in ipairs(journey.stops) do if not hand[s.key] then hand = nil; break end end
    end
    local pos, H, endPos = {}, nil, nil
    if hand then
        for _, s in ipairs(journey.stops) do pos[s.key] = { hand[s.key][1], hand[s.key][2] } end
        H, endPos = hand.H, { hand["end"][1], hand["end"][2] }
    else
        local y = 92
        for i, r in ipairs(road) do
            local x = i == 1 and W / 2 or (i % 2 == 0 and 300 or 120)
            pos[r.key] = { x, y }
            local n = sides[r.key] and #sides[r.key] or 0
            y = y + 240 + 110 * n
        end
        endPos = { W / 2, y - 40 }
        H = endPos[2] + 90
        -- Side paths: stacked on the far side of their stop's segment.
        for i, r in ipairs(road) do
            local list = sides[r.key]
            if list then
                local a = pos[r.key]
                local b = road[i + 1] and pos[road[i + 1].key] or endPos
                local far = (a[1] + b[1]) / 2 > W / 2 and 64 or W - 64
                for j, s in ipairs(list) do
                    pos[s.key] = { far, a[2] + (b[2] - a[2]) * (0.3 + 0.55 * (j - 0.5) / #list) + 30 }
                end
            end
        end
    end
    local segs = {}
    for i, r in ipairs(road) do
        local nxt = road[i + 1] and pos[road[i + 1].key] or endPos
        segs[r.key] = roadSeg(pos[r.key], nxt)
    end
    for rk, list in pairs(sides) do
        for j, s in ipairs(list) do
            local bx, by = bez(segs[rk], j / (#list + 1))
            segs[s.key] = sideSeg({ bx, by }, pos[s.key])
        end
    end
    return { W = W, H = H, pos = pos, endPos = endPos, road = road, sides = sides, segs = segs, from = from }
end

-- Points every `step` units along a curve: { {x, y, angle, t} ... } (angle in screen terms).
local function along(p, step)
    local n, acc, pts = 48, { 0 }, {}
    local px, py = bez(p, 0)
    for i = 1, n do
        local x, y = bez(p, i / n)
        acc[i + 1] = acc[i] + math.sqrt((x - px) ^ 2 + (y - py) ^ 2)
        px, py = x, y
    end
    local len = acc[n + 1]
    local d, i = 0, 1
    while d <= len do
        while i < n and acc[i + 1] < d do i = i + 1 end
        local seg = acc[i + 1] - acc[i]
        local t = ((i - 1) + (seg > 0 and (d - acc[i]) / seg or 0)) / n
        local x, y = bez(p, t)
        local x2, y2 = bez(p, math.min(1, t + 0.01))
        local x1, y1 = bez(p, math.max(0, t - 0.01))
        pts[#pts + 1] = { x, y, math.atan2(-(y2 - y1), x2 - x1), t }
        d = d + step
    end
    return pts
end

---------------------------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------------------------

local function circle(parent, layer, size, sub)
    local t = parent:CreateTexture(nil, layer, nil, sub)
    t:SetSize(size, size)
    local m = parent:CreateMaskTexture()
    if m then
        m:SetAllPoints(t)
        m:SetTexture(ns.Theme.circleMask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        pcall(t.AddMaskTexture, t, m)
    end
    t:SetColorTexture(1, 1, 1, 1)
    return t
end

local function tint(tex, name, alpha)
    local r, g, b = ns.Theme.RGB(name)
    tex:SetColorTexture(r, g, b, alpha or 1)
end

local function pulse(frame, from, to)
    if not frame.CreateAnimationGroup then return end
    local ag = frame:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local a = ag:CreateAnimation("Alpha")
    pcall(a.SetFromAlpha, a, from); pcall(a.SetToAlpha, a, to)
    a:SetDuration(0.9)
    if a.SetSmoothing then a:SetSmoothing("IN_OUT") end
    frame.anim = ag
end

-- A node: the seal (ring, fill, level or check), the open-now glow, the focus ring, and its
-- label plate (level line, name, what it asks). Clicking either selects the stop.
local function newNode(parent)
    local T, CT, W = ns.Theme, ns.Theme.layout.classTab, ns.Widgets
    local b = CreateFrame("Button", nil, parent)
    b.glowFrame = CreateFrame("Frame", nil, b)
    b.glowFrame:SetPoint("CENTER")
    b.glowFrame:SetSize(1, 1)
    b.glow = circle(b.glowFrame, "BACKGROUND", 10)
    b.glow:SetPoint("CENTER")
    pulse(b.glowFrame, 0.25, 0.9)
    b.focusRing = circle(b, "BACKGROUND", 10, 1)
    b.focusRing:SetPoint("CENTER")
    tint(b.focusRing, "focus")
    b.focusRing:Hide()
    b.ring = circle(b, "BORDER", 10)
    b.ring:SetPoint("CENTER")
    b.fill = circle(b, "ARTWORK", 10)
    b.fill:SetPoint("CENTER")
    b.check = b:CreateTexture(nil, "OVERLAY")
    b.check:SetTexture(T.files.checkDone)
    b.check:SetPoint("CENTER")
    b.text = T.Text(b, "md", "white")
    b.text:SetPoint("CENTER", 0, 0)

    local lab = CreateFrame("Button", nil, b)
    lab.bg = T.Solid(lab, "classLabel", "BACKGROUND", 0.82)
    lab.bg:SetAllPoints()
    lab.edge = W.Edge(lab, "BORDER")
    lab.edge:SetColor("cardEdge")
    lab.lv = T.Text(lab, "xs", "dim")
    lab.name = T.Text(lab, "sm", "white")
    lab.sub = T.Text(lab, "xs", "text")
    for _, fs in ipairs({ lab.lv, lab.name, lab.sub }) do fs:SetWordWrap(false) end
    b.label = lab

    function b:Paint()
        local edge = self.focused and "focus" or (self.selected and "gold" or "cardEdge")
        lab.edge:SetColor(edge)
        self.focusRing:SetShown(self.focused == true)
    end
    function b:SetFocused(on) self.focused = on; self:Paint() end
    function b:SetSelected(on) self.selected = on; self:Paint() end
    W.HoverInfo(b)
    lab:SetScript("OnEnter", function() if b.item then ns.UI.SetInfo(b.item.title, b.item.detail) end end)
    lab:SetScript("OnLeave", function() ns.UI.RestoreInfo() end)
    b:SetScript("OnClick", function(self) if self.onClick then self.onClick() end end)
    lab:SetScript("OnClick", function() if b.onClick then b.onClick() end end)
    return b
end

-- Seal colours per state: ring, fill, text.
local SEAL = {
    done = { "classBeadOn", "complete", "ink" },
    progress = { "classPeach", "todo", "white" },
    ready = { "classPeach", "ctlOn", "white" },
    later = { "untouched", "cardBg", "dim" },
    unknown = { "untouched", "cardBg", "dim" },
}

-- Paints a node for a stop (or the road's end: s = nil, endState = "done"|"todo"|"unknown").
local function paintNode(b, size, state, text, lines, labelSide)
    local T, CT = ns.Theme, ns.Theme.layout.classTab
    b:SetSize(size, size)
    local c = SEAL[state] or SEAL.unknown
    b.ring:SetSize(size, size); tint(b.ring, c[1])
    b.fill:SetSize(size - 2 * CT.ring, size - 2 * CT.ring); tint(b.fill, c[2])
    b.focusRing:SetSize(size + 8, size + 8)
    b.glow:SetSize(size + CT.glow, size + CT.glow); tint(b.glow, "classPeach", 0.55)
    b.glowFrame:SetShown(state == "ready")
    if b.glowFrame.anim then
        if state == "ready" then b.glowFrame.anim:Play() else b.glowFrame.anim:Stop() end
    end
    b.check:SetSize(size * 0.55, size * 0.55)
    b.check:SetShown(state == "done")
    if state == "done" then b.check:SetVertexColor(0.35, 0.22, 0.02) end
    b.text:SetShown(state ~= "done")
    b.text:SetText(text or "")
    T.SetFont(b.text, size >= CT.node and "md" or "xs")
    b.text:SetTextColor(T.RGB(c[3]))
    -- The label plate.
    local lab = b.label
    lab.lv:SetText(lines[1] or ""); lab.name:SetText(lines[2] or ""); lab.sub:SetText(lines[3] or "")
    lab.name:SetTextColor(T.RGB(state == "done" and "complete" or ((state == "later" or state == "unknown") and "dim" or "white")))
    lab.sub:SetTextColor(T.RGB(state == "progress" and "classPeach" or "text"))
    local w = 0
    for _, fs in ipairs({ lab.lv, lab.name, lab.sub }) do w = math.max(w, fs:GetStringWidth() or 0) end
    w = math.min(CT.label, math.ceil(w) + 2 * CT.labelPad)
    local hasLv = (lines[1] or "") ~= ""
    local h = 2 * CT.labelPad - 2 + T.size.sm + T.size.xs + 2 + (hasLv and (T.size.xs + 2) or 0)
    lab:SetSize(w, h)
    lab:ClearAllPoints()
    for _, fs in ipairs({ lab.lv, lab.name, lab.sub }) do fs:ClearAllPoints(); fs:SetWidth(w - 2 * CT.labelPad) end
    local just = labelSide == "left" and "RIGHT" or (labelSide == "below" and "CENTER" or "LEFT")
    for _, fs in ipairs({ lab.lv, lab.name, lab.sub }) do fs:SetJustifyH(just) end
    lab.lv:SetShown(hasLv)
    if hasLv then
        lab.lv:SetPoint("TOPLEFT", lab, "TOPLEFT", CT.labelPad, -CT.labelPad + 1)
        lab.name:SetPoint("TOPLEFT", lab.lv, "BOTTOMLEFT", 0, -2)
    else
        lab.name:SetPoint("TOPLEFT", lab, "TOPLEFT", CT.labelPad, -CT.labelPad + 1)
    end
    lab.sub:SetPoint("TOPLEFT", lab.name, "BOTTOMLEFT", 0, -2)
    if labelSide == "left" then lab:SetPoint("RIGHT", b, "LEFT", -CT.labelGap, 0)
    elseif labelSide == "below" then lab:SetPoint("TOP", b, "BOTTOM", 0, -4)
    else lab:SetPoint("LEFT", b, "RIGHT", CT.labelGap, 0) end
    b:Paint()
end

-- A step row (right pane): state icon, name with its starter below, level on the right.
local function newStepRow(parent)
    local T, CT, W = ns.Theme, ns.Theme.layout.classTab, ns.Widgets
    local row = W.FocusRow(parent, CT.stepRow)
    row.ring = circle(row, "BORDER", CT.stepIcon)
    row.ring:SetPoint("LEFT", ns.Theme.space.s2, 0)
    row.fill = circle(row, "ARTWORK", CT.stepIcon - 2)
    row.fill:SetPoint("CENTER", row.ring, "CENTER")
    row.dot = circle(row, "OVERLAY", 8)
    row.dot:SetPoint("CENTER", row.ring, "CENTER")
    row.check = row:CreateTexture(nil, "OVERLAY")
    row.check:SetTexture(T.files.checkDone)
    row.check:SetSize(14, 14)
    row.check:SetPoint("CENTER", row.ring, "CENTER")
    row.check:SetVertexColor(0.35, 0.22, 0.02)
    row.glyph = T.Text(row, "xs", "dim")
    row.glyph:SetPoint("CENTER", row.ring, "CENTER", 0, 0)
    row.lv = T.Text(row, "xs", "dim")
    row.lv:SetPoint("RIGHT", row, "RIGHT", -ns.Theme.space.s3, 0)
    row.lv:SetJustifyH("RIGHT")
    row.name = T.Text(row, "sm", "white")
    row.name:SetPoint("TOPLEFT", row.ring, "TOPRIGHT", ns.Theme.space.s3, 2)
    row.name:SetPoint("RIGHT", row.lv, "LEFT", -ns.Theme.space.s3, 0)
    row.name:SetJustifyH("LEFT"); row.name:SetWordWrap(false)
    row.sub = T.Text(row, "xs", "dim")
    row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
    row.sub:SetPoint("RIGHT", row.lv, "LEFT", -ns.Theme.space.s3, 0)
    row.sub:SetJustifyH("LEFT"); row.sub:SetWordWrap(false)
    row:SetScript("OnClick", function(self) if self.item and self.item.onActivate then self.item.onActivate(self.item) end end)
    -- Focused, a faint row reads at full strength (grey on the light bar washed out,
    -- WoWScrnShot_110926_221339).
    local base = row.SetFocused
    function row:SetFocused(on)
        base(self, on)
        self:Tone()
    end
    function row:Tone()
        local lit = self.focused and true or false
        local c = self.nameColor or "white"
        if lit and c == "dim" then c = "text" end
        self.name:SetTextColor(T.RGB(c))
        self.sub:SetTextColor(T.RGB(lit and "text" or "dim"))
        self.name:SetAlpha((self.faint and not lit) and 0.85 or 1)
        self.ring:SetAlpha((self.faint and not lit) and 0.7 or 1)
    end
    return row
end

-- kind: done | next | after | later | unknown | extra (not counted) | progress (a stop row).
local function paintStepRow(row, kind, name, sub, lv)
    local T = ns.Theme
    local ringC = ({ done = "classBeadOn", next = "classPeach", progress = "classPeach" })[kind] or "levelRange"
    local fillC = ({ done = "complete", progress = "todo" })[kind] or "cardBg"
    tint(row.ring, ringC); tint(row.fill, fillC)
    row.check:SetShown(kind == "done")
    row.dot:SetShown(kind == "next")
    tint(row.dot, "todo")
    row.glyph:SetShown(kind == "unknown")
    row.glyph:SetText(kind == "unknown" and "?" or "")
    row.name:SetText(name or "")
    row.nameColor = kind == "done" and "complete" or ((kind == "later" or kind == "extra" or kind == "unknown") and "dim" or "white")
    row.sub:SetText(sub or "")
    row.lv:SetText(lv or "")
    row.faint = kind == "later" or kind == "extra"
    row:Tone()
end

---------------------------------------------------------------------------------------------
-- Page
---------------------------------------------------------------------------------------------

local function build(parent)
    local T, L, S, W = ns.Theme, ns.Theme.layout, ns.Theme.space, ns.Widgets
    local CT = L.classTab
    local page = CreateFrame("Frame", nil, parent)
    page.mode = "road"            -- "road" (focus on the strip) | "steps" (focus in the right pane)
    page.nodes, page.dots, page.beads, page.cairns = {}, {}, {}, {}
    page.stepRows, page.headers, page.notes = {}, {}, {}

    -- Left: the plaque and the map --------------------------------------------------------------
    local strip = CreateFrame("Frame", nil, page)
    strip:SetPoint("TOPLEFT"); strip:SetPoint("BOTTOMLEFT")
    local plaque = CreateFrame("Frame", nil, strip)
    plaque:SetPoint("TOPLEFT"); plaque:SetPoint("TOPRIGHT"); plaque:SetHeight(CT.plaque)
    T.Solid(plaque, "black", "BACKGROUND", 0.35):SetAllPoints()
    local prule = T.Solid(plaque, "divider", "BORDER")
    prule:SetPoint("BOTTOMLEFT"); prule:SetPoint("BOTTOMRIGHT"); prule:SetHeight(1)
    plaque.title = T.Text(plaque, "lg", "gold")
    plaque.title:SetPoint("TOP", 0, -S.s2)
    plaque.count = T.Text(plaque, "xs", "dim")
    plaque.count:SetPoint("TOP", plaque.title, "BOTTOM", 0, -S.s1)
    page.plaque = plaque
    local mscroll = W.Scroll(strip)
    mscroll:SetPoint("TOPLEFT", plaque, "BOTTOMLEFT", S.s2, -S.s2)
    mscroll:SetPoint("BOTTOMRIGHT", strip, "BOTTOMRIGHT", -S.s2, S.s2)
    local map = mscroll.child
    page.map, page.mscroll = map, mscroll
    -- The sky: one gradient band between each pair of colour stops.
    page.sky = {}
    for i = 1, #T.classSky - 1 do
        local t = map:CreateTexture(nil, "BACKGROUND")
        t:SetColorTexture(1, 1, 1, 1)
        local top, bottom = T.classSky[i][2], T.classSky[i + 1][2]
        local ok = type(CreateColor) == "function" and pcall(t.SetGradient, t, "VERTICAL",
            CreateColor(bottom[1], bottom[2], bottom[3], 1), CreateColor(top[1], top[2], top[3], 1))
        if not ok then t:SetColorTexture(top[1], top[2], top[3], 1) end
        page.sky[i] = t
    end
    local stripEdge = T.Solid(strip, "divider", "BORDER")
    stripEdge:SetPoint("TOPRIGHT"); stripEdge:SetPoint("BOTTOMRIGHT"); stripEdge:SetWidth(1)
    -- The road's end and "you".
    page.endNode = newNode(map)
    page.you = CreateFrame("Frame", nil, map)
    page.you:SetSize(CT.you, CT.you)
    page.you.ring = circle(page.you, "BORDER", CT.you)
    page.you.ring:SetPoint("CENTER")
    tint(page.you.ring, "white")
    page.you.icon = circle(page.you, "ARTWORK", CT.you - 4)
    page.you.icon:SetPoint("CENTER")

    -- Right: the stop -----------------------------------------------------------------------------
    local d = CreateFrame("Frame", nil, page)
    d:SetPoint("TOPLEFT", strip, "TOPRIGHT"); d:SetPoint("BOTTOMRIGHT")
    local hero = CreateFrame("Frame", nil, d)
    hero:SetPoint("TOPLEFT"); hero:SetPoint("TOPRIGHT"); hero:SetHeight(CT.hero)
    hero.bg = hero:CreateTexture(nil, "BACKGROUND")
    hero.bg:SetAllPoints()
    hero.bg:SetColorTexture(1, 1, 1, 1)
    function hero:SetLook(gold)
        local a, b = gold and { 0.54, 0.39, 0.13 } or { 0.24, 0.16, 0.08 }, gold and { 0.23, 0.15, 0.05 } or { 0.08, 0.05, 0.02 }
        local ok = type(CreateColor) == "function" and pcall(self.bg.SetGradient, self.bg, "HORIZONTAL",
            CreateColor(b[1], b[2], b[3], 1), CreateColor(a[1], a[2], a[3], 1))
        if not ok then self.bg:SetColorTexture(a[1], a[2], a[3], 1) end
    end
    local hrule = T.Solid(hero, "divider", "ARTWORK")
    hrule:SetPoint("BOTTOMLEFT"); hrule:SetPoint("BOTTOMRIGHT"); hrule:SetHeight(2)
    hero.score = T.Text(hero, "huge", "classPeach")
    hero.score:SetPoint("BOTTOMRIGHT", hero, "BOTTOMRIGHT", -S.s6, S.s6 + S.s2)
    hero.check = hero:CreateTexture(nil, "OVERLAY")
    hero.check:SetTexture(T.files.checkDone)
    hero.check:SetSize(44, 44)
    hero.check:SetPoint("BOTTOMRIGHT", hero, "BOTTOMRIGHT", -S.s6, S.s6 + S.s2)
    hero.check:SetVertexColor(T.RGB("complete"))
    hero.small = T.Text(hero, "xs", "text")
    hero.small:SetPoint("BOTTOMRIGHT", hero, "BOTTOMRIGHT", -S.s6, S.s3)
    hero.sub = T.Text(hero, "sm", "text")
    hero.sub:SetPoint("BOTTOMLEFT", hero, "BOTTOMLEFT", S.s6, S.s3)
    hero.sub:SetPoint("RIGHT", hero, "RIGHT", -(S.s6 + CT.heroScore), 0)
    hero.sub:SetJustifyH("LEFT"); hero.sub:SetWordWrap(false)
    hero.name = T.Text(hero, "xxl", "gold")
    hero.name:SetPoint("BOTTOMLEFT", hero.sub, "TOPLEFT", 0, S.s1)
    hero.name:SetPoint("RIGHT", hero, "RIGHT", -(S.s6 + CT.heroScore), 0)
    hero.name:SetJustifyH("LEFT"); hero.name:SetWordWrap(false)
    hero.kicker = T.Text(hero, "xs", "dim")
    hero.kicker:SetPoint("BOTTOMLEFT", hero.name, "TOPLEFT", 0, S.s1)
    d.hero = hero
    local dscroll = W.Scroll(d)
    dscroll:SetPoint("TOPLEFT", hero, "BOTTOMLEFT", 0, -S.s3)
    dscroll:SetPoint("BOTTOMRIGHT", 0, S.s2)
    d.scroll = dscroll
    local dc = dscroll.child
    d.facts = {}
    for i = 1, 3 do
        local k = T.Text(dc, "xs", "gold"); k:SetJustifyH("LEFT")
        local v = T.Text(dc, "sm", "text"); v:SetJustifyH("LEFT"); v:SetWordWrap(true)
        d.facts[i] = { k = k, v = v }
    end
    d.bar = T.GildedBar(dc, CT.bar)
    d.foot = T.Text(dc, "xs", "dim"); d.foot:SetJustifyH("LEFT"); d.foot:SetWordWrap(true)
    page.detail = d

    -- The empty state (no road, QuestieDB missing, still reading).
    page.emptyTitle = T.Text(page, "lg", "gold")
    page.emptyTitle:SetPoint("TOP", 0, -100)
    page.emptyText = T.Text(page, "md", "dim")
    page.emptyText:SetPoint("TOP", page.emptyTitle, "BOTTOM", 0, -S.s2)
    page.emptyText:SetWidth(560); page.emptyText:SetWordWrap(true)

    ---------------------------------------------------------------------------------------------

    local function take(pool, make, parentFrame)
        page.used[pool] = (page.used[pool] or 0) + 1
        local f = page[pool][page.used[pool]]
        if not f then f = make(parentFrame); page[pool][page.used[pool]] = f end
        if f.ClearAllPoints then f:ClearAllPoints() end
        f:Show()
        return f
    end
    local function hideRest(pool)
        for i = (page.used[pool] or 0) + 1, #page[pool] do page[pool][i]:Hide() end
    end
    local function newTex(layer, sub) return function() return map:CreateTexture(nil, layer, nil, sub) end end
    local function newHeader() return W.Header(dc) end
    local function newNote()
        local fs = T.Text(dc, "sm", "text"); fs:SetJustifyH("LEFT"); fs:SetWordWrap(true)
        return fs
    end

    local function stopByKey(key)
        for _, s in ipairs(page.journey and page.journey.stops or {}) do if s.key == key then return s end end
    end

    -- The map, its road, beads, nodes and the road's end. Returns the focus rows.
    local function drawMap(j, lay)
        local mapW = math.max(1, (mscroll:GetWidth() or 0) > 1 and mscroll:GetWidth() or ((page.wide and CT.stripWide or CT.strip) - 2 * S.s2))
        local s = mapW / lay.W
        page.scale = s
        -- Room under the road's end for its label (it was cut off, WoWScrnShot_110926_221342).
        local endBottom = lay.endPos[2] * s + CT.endNode / 2 + CT.endLabel
        map:SetHeight(math.floor(math.max(lay.H * s, endBottom) + 0.5))
        local H = lay.H * s
        for i, t in ipairs(page.sky) do
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", map, "TOPLEFT", 0, -T.classSky[i][1] * H)
            t:SetPoint("TOPRIGHT", map, "TOPRIGHT", 0, -T.classSky[i][1] * H)
            t:SetHeight(math.max(1, (T.classSky[i + 1][1] - T.classSky[i][1]) * H))
        end
        local function at(tex, x, y) tex:SetPoint("CENTER", map, "TOPLEFT", x * s, -y * s) end
        -- Road and side tracks.
        for _, st in ipairs(j.stops) do
            local seg = lay.segs[st.key]
            if seg then
                local side = st.kind == "side" or lay.from[st.key] ~= nil
                local lit = st.done and st.count > 0 and st.done / st.count or 0
                for _, p in ipairs(along(seg, side and CT.sideStep or CT.roadStep)) do
                    local tex = take("dots", newTex("BORDER", 1), map)
                    local size = (side and CT.sideDot or CT.road) * s
                    tex:SetSize(size, size)
                    local on = p[4] <= lit and lit > 0
                    tint(tex, on and "complete" or "classRoad", on and 1 or 0.9)
                    if tex.SetRotation then tex:SetRotation(side and 0 or p[3]) end
                    at(tex, p[1], p[2])
                end
                -- A bead per quest.
                local n = st.count
                for k, step in ipairs(st.steps) do
                    local t = side and (k / (n + 1)) * 0.86 or k / (n + 1)
                    local bx, by = bez(seg, t)
                    local size = (side and CT.sideBead or CT.bead)
                    local ring = take("beads", function() return circle(map, "ARTWORK", size, 1) end, map)
                    ring:SetSize(size + 2, size + 2); tint(ring, "ink")
                    at(ring, bx, by)
                    local dot = take("beads", function() return circle(map, "ARTWORK", size, 2) end, map)
                    dot:SetSize(size, size)
                    tint(dot, step.state == "done" and "classBeadOn" or "classBead", step.state == "unknown" and 0.5 or 1)
                    at(dot, bx, by)
                end
            end
        end
        -- Cairns under side paths: three stones.
        for _, st in ipairs(j.stops) do
            if lay.from[st.key] then
                local p = lay.pos[st.key]
                for k, sz in ipairs({ { 22, 9, 8 }, { 16, 8, 1 }, { 10, 6, -5 } }) do
                    local c = take("cairns", function() return circle(map, "ARTWORK", 10, 3) end, map)
                    c:SetSize(sz[1], sz[2]); tint(c, "classCairn")
                    c:SetPoint("CENTER", map, "TOPLEFT", p[1] * s, -(p[2] + 30 + sz[3]) * s - 0)
                end
            end
        end
        -- Nodes.
        local byKey, rows = {}, {}
        local function nodeItem(st, b)
            local key = st.key
            b.item = { key = "n:" .. key, frame = b, title = st.name, detail = stopInfo(st, "A shows the steps."),
                scroll = mscroll, stopKey = key, actionLabel = "Steps",
                onActivate = function() page:EnterSteps() end }
            b.onClick = function() page:SelectStop(key, true) end
            return b.item
        end
        for _, st in ipairs(j.stops) do
            local b = take("nodes", newNode, map)
            local p = lay.pos[st.key]
            local side = lay.from[st.key] ~= nil
            local size = side and CT.sideNode or CT.node
            local state = st.state or "unknown"
            local lines = { "Level " .. tostring(st.level or "?") .. (side and "  ·  side path" or ""), st.name, stopSub(st) }
            paintNode(b, size, state, tostring(st.level or "?"), lines, p[1] > lay.W * 0.58 and "left" or "right")
            b:SetPoint("CENTER", map, "TOPLEFT", p[1] * s, -p[2] * s)
            b:SetFrameLevel(map:GetFrameLevel() + 5)
            byKey[st.key] = b
            nodeItem(st, b)
        end
        hideRest("dots"); hideRest("beads"); hideRest("cairns"); hideRest("nodes")
        -- The road's end.
        local e = page.endNode
        local qs = j.quests
        local walked = j.complete == true
        local endState = walked and "done" or (j.complete == nil and "unknown" or "later")
        paintNode(e, CT.endNode, endState, "", { "", walked and "The road walked" or "The road's end",
            qs.count .. " quests" .. (j.complete == nil and "  ·  done not known" or ("  ·  " .. qs.done .. " done")) }, "below")
        if not walked then tint(e.fill, "ink"); tint(e.ring, "levelRange") end
        e:SetPoint("CENTER", map, "TOPLEFT", lay.endPos[1] * s, -lay.endPos[2] * s)
        e:SetFrameLevel(map:GetFrameLevel() + 5)
        e.item = { key = "n:end", frame = e, title = walked and "The road walked" or "The road's end",
            detail = walked and "Every class quest on the road and its side paths is done. A lists every stop."
                or (j.complete == nil and (qs.count .. " class quests; done or not isn't known yet. A lists every stop.")
                or (qs.done .. " of " .. qs.count .. " class quests done. A lists every stop.")),
            scroll = mscroll, stopKey = "end", actionLabel = "Stops", onActivate = function() page:EnterSteps() end }
        e.onClick = function() page:SelectStop("end", true) end
        -- "You": on the first road stop not done, at its last done bead (or beside its node).
        page.you:Hide()
        if j.complete ~= nil then
            for _, r in ipairs(lay.road) do
                if r.state ~= "done" then
                    local p = lay.pos[r.key]
                    local x, y = p[1] + (p[1] < lay.W / 2 and -40 or 40), p[2] - 6
                    local last = 0
                    for k, step in ipairs(r.steps) do if step.state == "done" then last = k end end
                    if last > 0 and lay.segs[r.key] then x, y = bez(lay.segs[r.key], last / (r.count + 1)) end
                    page.you:ClearAllPoints()
                    page.you:SetPoint("CENTER", map, "TOPLEFT", x * s, -y * s)
                    page.you:SetFrameLevel(map:GetFrameLevel() + 7)
                    local cf = ns.character and ns.character.classFile
                    local coords = cf and rawget(_G, "CLASS_ICON_TCOORDS") and CLASS_ICON_TCOORDS[cf]
                    if coords then
                        page.you.icon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
                        page.you.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
                    else
                        tint(page.you.icon, "Alliance")
                    end
                    page.you:Show()
                    break
                end
            end
        end
        -- Focus rows: one per road stop (its side paths left or right of it by position), then
        -- the end. Each row is its own section (LT/RT stop to stop).
        for i, r in ipairs(lay.road) do
            local items = { { item = byKey[r.key].item, x = lay.pos[r.key][1] } }
            for _, sp in ipairs(lay.sides[r.key] or {}) do items[#items + 1] = { item = byKey[sp.key].item, x = lay.pos[sp.key][1] } end
            table.sort(items, function(a, b) return a.x < b.x end)
            local row = { items = {}, section = i }
            for ci, it in ipairs(items) do
                row.items[ci] = it.item
                if it.item.stopKey == r.key then row.home = ci end
            end
            rows[#rows + 1] = row
        end
        rows[#rows + 1] = { items = { e.item }, section = #lay.road + 1 }
        page.byKey = byKey
        return rows
    end

    -- Text in the pane at y; returns the next y.
    local function note(text, y, x, w, color)
        local fs = take("notes", newNote, dc)
        fs:SetPoint("TOPLEFT", dc, "TOPLEFT", x, -y)
        fs:SetWidth(w)
        fs:SetText(text)
        fs:SetTextColor(T.RGB(color or "text"))
        return y + math.ceil(fs:GetStringHeight() or 14) + S.s2
    end
    local function header(text, count, y, x, w)
        local h = take("headers", newHeader, dc)
        h:SetPoint("TOPLEFT", dc, "TOPLEFT", x, -y)
        h:SetWidth(w)
        h.text:SetText(text); h.count:SetText(count or "")
        return y + L.listHeader + S.s2
    end

    -- Fills the right pane for a stop. Returns its focus rows (the steps, then the extras).
    local function fillStop(st, j)
        local rows = {}
        local w = (dscroll:GetWidth() or 0) > 1 and dscroll:GetWidth() or 560
        local x, inner = S.s4, w - S.s4 - S.s6
        local road, roadIndex = 0, nil
        for _, s in ipairs(j.stops) do
            if s.kind ~= "side" then road = road + 1; if s.key == st.key then roadIndex = road end end
        end
        local fromStop = st.from and stopByKey(st.from)
        hero.kicker:SetText(roadIndex and string.format("Stop %d of %d on the road", roadIndex, j.road.count)
            or ("Side path off " .. (fromStop and fromStop.name or "the road")))
        hero.name:SetText(st.name or "")
        hero.name:SetTextColor(T.RGB(st.state == "done" and "classBeadOn" or "gold"))
        hero.sub:SetText("Reward: " .. (st.reward or "not known yet"))
        hero:SetLook(st.state == "done")
        hero.check:SetShown(st.state == "done")
        hero.score:SetShown(st.state ~= "done")
        if st.state == "done" then
            hero.small:SetText("Done")
        elseif st.state == "later" then
            hero.score:SetText(tostring(st.level or "?")); hero.score:SetTextColor(T.RGB("dim"))
            hero.small:SetText("opens at level")
        elseif st.done == nil then
            hero.score:SetText("?"); hero.score:SetTextColor(T.RGB("dim"))
            hero.small:SetText("of " .. st.count .. " quests, not known")
        else
            hero.score:SetText(N(st.done)); hero.score:SetTextColor(T.RGB("classPeach"))
            hero.small:SetText("of " .. st.count .. (st.count == 1 and " quest" or " quests"))
        end
        -- Facts: where it starts, level, state.
        local y = 0
        local lv = charLevel()
        local first = st.steps[1]
        local level = tostring(st.level or "?")
        if st.state == "later" and st.level and lv and st.level > lv then
            level = level .. "  ·  " .. (st.level - lv) .. (st.level - lv == 1 and " level to go" or " levels to go")
        end
        local facts = { { "Where it starts", first and starterText(first.id) or "Not known" }, { "Level", level },
            { "State", STATE_LABEL[st.state or "unknown"] or "Not known yet" } }
        -- (50 / 25 / 25 wrapped "2 levels to go" at minimum size, WoWScrnShot_110926_221345.)
        local c1, c2 = math.floor(inner * CT.factCols[1]), math.floor(inner * CT.factCols[2])
        local colW = { c1, c2, inner - c1 - c2 }
        local fx, fh = x, 0
        for i, f in ipairs(d.facts) do
            f.k:Show(); f.v:Show()
            f.k:ClearAllPoints(); f.v:ClearAllPoints()
            f.k:SetPoint("TOPLEFT", dc, "TOPLEFT", fx, -y)
            f.k:SetText(facts[i][1])
            f.v:SetPoint("TOPLEFT", f.k, "BOTTOMLEFT", 0, -2)
            f.v:SetWidth(colW[i] - S.s3)
            f.v:SetText(facts[i][2])
            f.v:SetTextColor(T.RGB(i == 3 and (st.state == "done" and "complete" or ((st.state == "later" or st.state == "unknown") and "dim" or "classPeach")) or "text"))
            fh = math.max(fh, T.size.xs + 2 + math.ceil(f.v:GetStringHeight() or 14))
            fx = fx + colW[i]
        end
        y = y + fh + S.s4
        -- Notes: the route, an inferred order, unknown completion.
        if st.route then
            y = note("Route: " .. st.route .. ". Any one route finishes this stop; this is the one you're furthest along.", y, x, inner, "classPeach")
        end
        if st.order then
            y = note("Order inferred from quest levels: QuestieDB doesn't link these quests.", y, x, inner, "classPeach")
        end
        if st.done == nil then
            y = note("Done or not isn't known: the game hasn't given Azerfolio your completed quests yet.", y, x, inner, "dim")
        end
        -- Steps.
        local kinds = stepKinds(st)
        local names, seen, total = {}, {}, {}
        for _, step in ipairs(st.steps) do local nm = questName(step.id); names[#names + 1] = nm; total[nm] = (total[nm] or 0) + 1 end
        y = header("Steps", st.done and (st.done .. " of " .. st.count .. " done") or (st.count .. " steps"), y, x - S.s2, inner + S.s2)
        for k, step in ipairs(st.steps) do
            local nm = names[k]
            if total[nm] > 1 then seen[nm] = (seen[nm] or 0) + 1; nm = nm .. "  ·  part " .. seen[nm] .. " of " .. total[nm] end
            local row = take("stepRows", newStepRow, dc)
            row:SetPoint("TOPLEFT", dc, "TOPLEFT", x - S.s2, -y)
            row:SetWidth(inner + S.s2)
            local qlv = questLevel(step.id)
            local where = starterText(step.id) or "Starter not known"
            paintStepRow(row, kinds[k], nm, where, qlv and ("Lv " .. qlv) or "")
            local kind = kinds[k]
            local state = kind == "done" and "Done." or kind == "next" and "Your next step." or kind == "after" and "You can do it now."
                or kind == "later" and ("Later: " .. (whyText(step.reason) or "locked") .. ".")
                or ("Done or not isn't known" .. (step.reason and (" (" .. whyText(step.reason) .. ")") or "") .. ".")
            row.item = { key = "st:" .. k .. ":" .. step.id, frame = row, title = nm,
                detail = state .. " " .. where .. ". " .. (qlv and ("Level " .. qlv .. ". ") or "") .. "Quest " .. step.id .. ".",
                scroll = dscroll, topGap = L.listHeader + S.s2 }
            row:SetSelected(false)
            rows[#rows + 1] = { items = { row.item } }
            y = y + CT.stepRow + 2
        end
        -- Extras: shown, not counted.
        if #st.extra > 0 then
            y = y + S.s2
            y = header("Not counted", "lead-ins and repeatable steps", y, x - S.s2, inner + S.s2)
            for _, ex in ipairs(st.extra) do
                local row = take("stepRows", newStepRow, dc)
                row:SetPoint("TOPLEFT", dc, "TOPLEFT", x - S.s2, -y)
                row:SetWidth(inner + S.s2)
                local nm, qlv = questName(ex.id), questLevel(ex.id)
                local where = starterText(ex.id) or "Starter not known"
                paintStepRow(row, ex.state == "done" and "done" or "extra", nm, where, qlv and ("Lv " .. qlv) or "")
                row.item = { key = "ex:" .. ex.id, frame = row, title = nm,
                    detail = (ex.state == "done" and "Done. " or "") .. "Not counted: a lead-in, or a step the game may never mark done. "
                        .. where .. ". Quest " .. ex.id .. ".", scroll = dscroll, topGap = L.listHeader + S.s2 }
                row:SetSelected(false)
                rows[#rows + 1] = { items = { row.item } }
                y = y + CT.stepRow + 2
            end
        end
        d.bar:Hide()
        y = y + S.s3
        d.foot:ClearAllPoints()
        d.foot:SetPoint("TOPLEFT", dc, "TOPLEFT", x, -y)
        d.foot:SetWidth(inner)
        d.foot:SetText("Steps from the curated journey and QuestieDB; done or not is read from the game.")
        d.foot:Show()
        y = y + math.ceil(d.foot:GetStringHeight() or 14) + S.s4
        dc:SetHeight(math.max(1, y))
        return rows
    end

    -- The road's end: the whole road, every stop with n / m. Rows go to the stop on the road.
    local function fillEnd(j)
        local rows = {}
        local w = (dscroll:GetWidth() or 0) > 1 and dscroll:GetWidth() or 560
        local x, inner = S.s4, w - S.s4 - S.s6
        local c = ns.character or {}
        local walked = j.complete == true
        hero.kicker:SetText((c.className or "") .. ((c.className and c.race) and "  ·  " or "") .. (c.race or ""))
        hero.name:SetText(walked and ((j.title or "The road") .. ", walked") or (j.title or "The road"))
        hero.name:SetTextColor(T.RGB(walked and "classBeadOn" or "gold"))
        hero.sub:SetText(walked and "Every class quest you can do is done" or "Every class quest you can do, stop by stop")
        hero:SetLook(walked)
        hero.check:SetShown(walked)
        hero.score:SetShown(not walked)
        if walked then hero.small:SetText("Done")
        elseif j.complete == nil then
            hero.score:SetText("?"); hero.score:SetTextColor(T.RGB("dim")); hero.small:SetText("of " .. j.quests.count .. " quests, not known")
        else
            hero.score:SetText(N(j.quests.done)); hero.score:SetTextColor(T.RGB("classPeach"))
            hero.small:SetText("of " .. j.quests.count .. " quests")
        end
        for _, f in ipairs(d.facts) do f.k:Hide(); f.v:Hide() end
        local y = 0
        d.bar:ClearAllPoints()
        d.bar:SetPoint("TOPLEFT", dc, "TOPLEFT", x, -y)
        d.bar:SetWidth(inner)
        d.bar:Show()
        d.bar:Set(j.complete ~= nil and j.quests.count > 0 and j.quests.done / j.quests.count or 0, walked and "complete" or nil)
        y = y + CT.bar + S.s4
        if j.complete == nil then
            y = note("Done or not isn't known: the game hasn't given Azerfolio your completed quests yet.", y, x, inner, "dim")
        end
        local function stopRows(kind, title)
            local list = {}
            for _, s in ipairs(j.stops) do if (kind == "side") == (s.kind == "side") then list[#list + 1] = s end end
            if #list == 0 then return end
            local grp = kind == "side" and j.side or j.road
            local count = (j.complete == nil and "?" or grp.done) .. " of " .. grp.count .. (kind == "side" and " · optional, but they count" or " stops")
            y = header(title, count, y, x - S.s2, inner + S.s2)
            for _, s in ipairs(list) do
                local row = take("stepRows", newStepRow, dc)
                row:SetPoint("TOPLEFT", dc, "TOPLEFT", x - S.s2, -y)
                row:SetWidth(inner + S.s2)
                local k = s.state == "done" and "done" or s.state == "progress" and "progress" or s.state == "later" and "later"
                    or s.state == "unknown" and "unknown" or "after"
                paintStepRow(row, k, s.name, "Level " .. tostring(s.level or "?") .. "  ·  " .. (s.reward or "reward not known yet"),
                    (s.done and s.done or "?") .. " / " .. s.count)
                local key = s.key
                row.item = { key = "go:" .. key, frame = row, title = s.name, detail = stopInfo(s, "A goes to it on the road."),
                    scroll = dscroll, topGap = L.listHeader + S.s2, actionLabel = "Go to",
                    onActivate = function() page:FocusStop(key) end }
                row:SetSelected(false)
                rows[#rows + 1] = { items = { row.item } }
                y = y + CT.stopRow + 2
            end
            y = y + S.s2
        end
        stopRows("road", "The road")
        stopRows("side", "Side paths")
        for _, n in ipairs(j.notes or {}) do y = note(n, y, x, inner, "dim") end
        d.foot:ClearAllPoints()
        d.foot:SetPoint("TOPLEFT", dc, "TOPLEFT", x, -y)
        d.foot:SetWidth(inner)
        d.foot:SetText("Raid and dungeon class quests aren't on the road: they belong to a later Dungeons tab. "
            .. "Another race's version of a stop, and repeatable turn-ins, never count.")
        d.foot:Show()
        y = y + math.ceil(d.foot:GetStringHeight() or 14) + S.s4
        dc:SetHeight(math.max(1, y))
        return rows
    end

    -- The right pane for the selected stop.
    local function fillDetail()
        page.used.stepRows, page.used.headers, page.used.notes = 0, 0, 0
        local j = page.journey
        local rows = {}
        if j then
            local st = page.sel ~= "end" and stopByKey(page.sel)
            if st then rows = fillStop(st, j) else rows = fillEnd(j) end
        end
        hideRest("stepRows"); hideRest("headers"); hideRest("notes")
        page.detailRows = rows
        return rows
    end

    -- Redraws everything from ns.ClassJourney.Get(). Keeps the selection and focus.
    function page:Redraw()
        local g = ns.ClassJourney.Get()
        self.status = g.status
        self.used = { dots = 0, beads = 0, cairns = 0, nodes = 0, stepRows = 0, headers = 0, notes = 0 }
        local ready = g.status == "ready" and g.journey and #g.journey.stops > 0
        strip:SetShown(ready); d:SetShown(ready)
        self.emptyTitle:SetShown(not ready); self.emptyText:SetShown(not ready)
        if not ready then
            self.journey, self.roadRows, self.detailRows = nil, {}, {}
            local c = ns.character or {}
            if g.status == "none" or g.status == "ready" then
                self.emptyTitle:SetText("No class road yet")
                self.emptyText:SetText("Azerfolio has no curated class quests for " .. (c.className or "this class")
                    .. " on the " .. tostring(c.faction or "?") .. " side.")
            elseif g.status == "unavailable" then
                self.emptyTitle:SetText("Class quests need QuestieDB")
                self.emptyText:SetText("Azerfolio reads the class quests from the QuestieDB addon"
                    .. (g.reason and (" (" .. g.reason .. ")") or "") .. ". Nothing is shown as done or not done without it.")
            else
                self.emptyTitle:SetText("Reading class quests")
                self.emptyText:SetText("Azerfolio reads them once QuestieDB's quests are in.")
            end
            self.mode = "road"
            self:Refresh()
            return
        end
        local j = g.journey
        self.journey = j
        local c = g.char or {}
        self.layout = layoutFor(j, c.classFile, c.side)
        -- Plaque.
        plaque.title:SetText(j.title or "")
        plaque.title:SetTextColor(T.RGB(j.complete and "complete" or "gold"))
        local known = j.complete ~= nil
        local count = "Road " .. (known and j.road.done or "?") .. " of " .. j.road.count
        if j.side.count > 0 then count = count .. "  ·  Side paths " .. (known and j.side.done or "?") .. " of " .. j.side.count end
        plaque.count:SetText(count)
        self.drawnWidth = mscroll:GetWidth() or 0
        self.roadRows = drawMap(j, self.layout)
        -- Selection: kept if the stop is still there; else your current stop.
        if self.sel ~= "end" and not (self.sel and stopByKey(self.sel)) then
            self.sel = nil
            for _, r in ipairs(self.layout.road) do if r.state ~= "done" then self.sel = r.key; break end end
            self.sel = self.sel or "end"
            if self.pendingFocusKey == nil then self.pendingFocusKey = "n:" .. self.sel end
        end
        fillDetail()
        if self.mode == "steps" and #self.detailRows == 0 then self.mode = "road" end
        self:Paint()
        self:Refresh()
    end

    -- Selected marks on the nodes.
    function page:Paint()
        for key, b in pairs(self.byKey or {}) do b:SetSelected(key == self.sel) end
        self.endNode:SetSelected(self.sel == "end")
    end

    function page:Refresh()
        self.hasSections = self.mode == "road" and #(self.roadRows or {}) > 1
        self.sectionLabel = "Stop"
        self.backLabel = self.mode == "steps" and "Road" or nil
        ns.Focus.Rebuild()
        ns.UI.RefreshHints()
    end

    -- Shows a stop in the right pane (focus following, or a click).
    function page:SelectStop(key, focus)
        if key ~= self.sel then
            self.sel = key
            fillDetail()
            dscroll:SetVerticalScroll(0)
            self:Paint()
        end
        if focus then
            self.mode = "road"
            self.pendingFocusKey = "n:" .. key
            self:Refresh()
        end
    end

    -- To a stop on the road (from the road's end list, or /azf shots).
    function page:FocusStop(key) self:SelectStop(key, true) end

    function page:CurrentStopKey()
        for _, r in ipairs(self.layout and self.layout.road or {}) do if r.state ~= "done" then return r.key end end
        return "end"
    end

    -- A: into the selected stop's steps (your next step first).
    function page:EnterSteps()
        if not self.detailRows or #self.detailRows == 0 then return end
        self.mode = "steps"
        local pick = self.detailRows[1].items[1].key
        for _, r in ipairs(self.detailRows) do
            local it = r.items[1]
            if it.frame and it.frame.dot and it.frame.dot:IsShown() then pick = it.key; break end
        end
        self.pendingFocusKey = pick
        self:Refresh()
    end

    function page:OnFocusChanged(item)
        if self.mode == "road" and item and item.stopKey and item.stopKey ~= self.sel then
            self:SelectStop(item.stopKey, false)
        end
        -- The road's end: all the way down, so its label shows too.
        if item and item.stopKey == "end" then mscroll:SetVerticalScroll(mscroll:GetVerticalScrollRange() or 0) end
    end

    function page:GetFocusRows()
        if self.mode == "steps" then return self.detailRows or {} end
        return self.roadRows or {}
    end

    -- B: from the steps back to the stop on the road.
    function page:Back()
        if self.mode ~= "steps" then return false end
        self.mode = "road"
        self.pendingFocusKey = "n:" .. (self.sel or "end")
        self:Refresh()
        return true
    end

    -- The strip's column for the window (the map redraws when its width changes: onWidth).
    function page:Layout()
        local wide = ns.UI.IsWide()
        if wide == self.wide then return end
        self.wide = wide
        strip:SetWidth(wide and CT.stripWide or CT.strip)
    end

    -- The map is drawn for a width: redraw when it changes.
    mscroll.onWidth = function(w)
        if page.journey and page.drawnWidth and math.abs(page.drawnWidth - (w or 0)) >= 1 then page:Redraw() end
    end
    dscroll.onWidth = function()
        if page.journey and page:IsShown() then fillDetail(); ns.Focus.Rebuild() end
    end

    ns.Events.On("AZF_CLASS_UPDATED", function()
        if not page:IsShown() then page.dirty = true; return end
        local cur = ns.UI.CurrentTab() == "class" and ns.Focus.Current()
        if cur and page.pendingFocusKey == nil then page.pendingFocusKey = cur.key end
        page:Redraw()
    end)
    page:SetScript("OnShow", function(self)
        if self.dirty then self.dirty = false; self:Redraw() end
    end)

    page.wide = ns.UI.IsWide()
    strip:SetWidth(page.wide and CT.stripWide or CT.strip)
    page:Redraw()
    return page
end

ns.UI.RegisterTab({
    id = "class",
    label = "Class",
    icon = ns.Theme.Icon("class", "Interface\\Icons\\INV_Misc_Book_09"),
    order = 4,
    info = "Your class quests: the road, its side paths, and each stop's steps.",
    build = build,
})
