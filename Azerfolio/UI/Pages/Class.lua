-- Class tab (Phase 13, mockups/DESIGN.md "Class tab", design round 2): this character's class
-- quests as a journey. Left: a plaque (title, counts, the Next line) over the journey strip, one
-- node per stop with a bead per quest, side paths that end at a cairn, the road's end with the
-- class crest. Until the painted strip exists the strip is a stand-in drawn from the curated stops
-- (Theme.classStrip, or laid out here). Right: the selected stop (or the road's end): its zone's
-- art behind the header, the facts, Start here (lead-ins), the numbered steps.
-- Data only from ns.ClassJourney.Get() (ClassJourneyRules: states, counts, next); quest names,
-- levels and starters from ns.Quests (QuestieDB). The page draws what it's given; it never
-- decides what is done.
-- Gamepad: up/down along the road, left/right onto a side path, LT/RT stop to stop, A into the
-- steps (LT/RT: Start here / Steps), B back to the road.
local _, ns = ...

local STATE_LABEL = { done = "Done", progress = "In progress", ready = "You can start it", later = "Later",
    unknown = "Not known yet" }
local WHY = { prerequisite = "needs the step before it", ["parent quest"] = "comes inside the step before it",
    ["completed quests not known"] = "your completed quests aren't known yet" }

local function cap(s) s = tostring(s or ""); return (s:gsub("^%l", string.upper)) end
local function plural(n, word)
    if n == 1 then return n .. " " .. word end
    return n .. " " .. (word:match("[^aeiou]y$") and (word:sub(1, -2) .. "ies") or (word .. "s")) -- ability -> abilities
end

-- "level 12" -> "opens at level 12"; known reasons in words; others as given.
local function whyText(reason)
    if type(reason) ~= "string" then return nil end
    local lv = reason:match("^level (%d+)")
    if lv then return "opens at level " .. lv end
    return WHY[reason] or reason
end

local function info(id) return ns.Quests.Info(id) end
local function questName(id)
    local r = info(id)
    return r and r.name or ("Quest " .. tostring(id))
end
local function starter(id) return ns.Quests.Starter and ns.Quests.Starter(id) or nil end

-- "Duthorian Rall · Stormwind City", "A Strange Artifact (object) · Ashenvale", nil.
local function starterText(s)
    if not s then return nil end
    local name = s.name or "Someone"
    if s.kind == "object" then name = name .. " (object)" elseif s.kind == "item" then name = name .. " (item)" end
    return s.place and (name .. "  ·  " .. s.place) or name
end

local function charLevel() return ns.character and ns.character.level end
local function debugIds() return ns.Debug and ns.Debug.IsEnabled and ns.Debug.IsEnabled() end

-- The stop's extras split (design round 2): sub-quests whose parent is one of its steps go in
-- place after that step; the rest (lead-ins, repeatable-flagged starts, other turn-ins) go under
-- Start here. Returns leadins = { step... }, subs = { [stepIndex] = { step... } }.
local function splitExtras(stop)
    local at = {}
    for i, st in ipairs(stop.steps) do
        for _, id in ipairs(st.ids or { st.id }) do at[id] = i end
    end
    local leadins, subs = {}, {}
    for _, ex in ipairs(stop.extra or {}) do
        local r = info(ex.id)
        local i = r and r.parent and at[r.parent]
        if i then subs[i] = subs[i] or {}; table.insert(subs[i], ex)
        else leadins[#leadins + 1] = ex end
    end
    return leadins, subs
end

-- Where the stop starts (round 2): the first step's starter, unless that's an item; then the
-- lead-in that leads into the first step (its next quest), the chain's own start before the
-- breadcrumbs (The Tome of Divinity: 1641 Duthorian Rall, not 2998 Brother Wilhelm, both lead
-- into 1642; WoWScrnShot_110926_224436); then any lead-in a person or object gives.
-- Returns the starter record (or nil).
local function stopStarter(stop, leadins)
    local first = stop.steps[1]
    local s = first and starter(first.id)
    if s and s.kind ~= "item" then return s end
    local firstIds = {}
    for _, id in ipairs(first and (first.ids or { first.id }) or {}) do firstIds[id] = true end
    for _, crumbs in ipairs({ false, true }) do
        for _, ex in ipairs(leadins) do
            local r = info(ex.id)
            local ls = starter(ex.id)
            if r and r.next and firstIds[r.next] and ((r.breadcrumbFor ~= nil) == crumbs) and ls and ls.kind ~= "item" then
                return ls
            end
        end
    end
    for _, ex in ipairs(leadins) do
        local ls = starter(ex.id)
        if ls and ls.kind ~= "item" then return ls end
    end
    return s
end

-- The zones a stop's steps take you to, in order (from their starters).
local function travels(stop, subs)
    local seen, out = {}, {}
    local function add(id)
        local s = starter(id)
        if s and s.place and not seen[s.place] then seen[s.place] = true; out[#out + 1] = s.place end
    end
    for i, st in ipairs(stop.steps) do
        add(st.id)
        for _, ex in ipairs(subs[i] or {}) do add(ex.id) end
    end
    return out
end

-- The info line for a stop (title is its name).
local function stopInfo(s, action)
    local parts = {}
    if s.kind == "side" then parts[#parts + 1] = "Side path." end
    parts[#parts + 1] = "Level " .. tostring(s.level or "?") .. "."
    if s.state == "done" then parts[#parts + 1] = "Done."
    elseif s.done then parts[#parts + 1] = s.done .. " of " .. plural(s.count, "quest") .. " done."
    else parts[#parts + 1] = plural(s.count, "quest") .. "; done or not isn't known yet." end
    parts[#parts + 1] = "Reward: " .. (s.reward or "not known yet") .. "."
    local lv = charLevel()
    if s.state == "later" and s.level and lv and s.level > lv then
        parts[#parts + 1] = "Opens at level " .. s.level .. " (" .. (s.level - lv) .. " to go)."
    end
    if action then parts[#parts + 1] = action end
    return table.concat(parts, " ")
end

-- The plaque's Next line from ClassJourneyRules.Next, and its colour.
local function nextLine(j)
    local n = j.next or {}
    if n.kind == "unknown" then return "Next: not known until the game gives Azerfolio your completed quests", "dim" end
    if n.kind == "walked" then return "Every stop walked", "complete" end
    if n.kind == "level" then
        local lv = charLevel()
        local where = starterText(stopStarter(n.stop, (splitExtras(n.stop))))
        return "Next: reach level " .. n.level .. (lv and (" (" .. (n.level - lv) .. " to go)") or "")
            .. (where and (", then " .. where) or ""), "classPeach"
    end
    if n.kind == "step" and n.step then
        local where = starterText(starter(n.step.id))
        return "Next: " .. questName(n.step.id) .. (where and ("  ·  " .. where) or ""), "classPeach"
    end
    return "", "dim"
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

-- The traced road corridor of a painted strip (Data/StripPaths.lua, from tools/trace-strip.ps1):
-- a polyline with cumulative lengths. Round 4: the road follows the painting's cleared path
-- (it cut straight across the art, owner 2026-11-10).
local function newPath(raw)
    if type(raw) ~= "table" or #raw < 2 then return nil end
    local pts, acc = {}, { 0 }
    for i, p in ipairs(raw) do
        pts[i] = { p[1], p[2] }
        if i > 1 then acc[i] = acc[i - 1] + math.sqrt((p[1] - pts[i - 1][1]) ^ 2 + (p[2] - pts[i - 1][2]) ^ 2) end
    end
    return { pts = pts, acc = acc, len = acc[#acc] }
end

-- The point at distance s along a path.
local function pathPoint(P, s)
    s = math.max(0, math.min(P.len, s))
    local i = 1
    while i < #P.pts - 1 and P.acc[i + 1] < s do i = i + 1 end
    local span = P.acc[i + 1] - P.acc[i]
    local f = span > 0 and (s - P.acc[i]) / span or 0
    local a, b = P.pts[i], P.pts[i + 1]
    return a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f
end

-- The distance along a path of its point nearest (x, y).
local function pathProject(P, x, y)
    local bestS, bestD = 0, math.huge
    for i = 1, #P.pts - 1 do
        local a, b = P.pts[i], P.pts[i + 1]
        local dx, dy = b[1] - a[1], b[2] - a[2]
        local l2 = dx * dx + dy * dy
        local f = l2 > 0 and math.max(0, math.min(1, ((x - a[1]) * dx + (y - a[2]) * dy) / l2)) or 0
        local px, py = a[1] + dx * f, a[2] + dy * f
        local d = (px - x) ^ 2 + (py - y) ^ 2
        if d < bestD then bestD, bestS = d, P.acc[i] + f * (P.acc[i + 1] - P.acc[i]) end
    end
    return bestS
end

-- A point on a segment at t (0..1): a cubic curve { p1, p2, p3, p4 }, or a stretch of a traced
-- path { path, s0, s1 }.
local function bez(p, t)
    if p.path then return pathPoint(p.path, p.s0 + (p.s1 - p.s0) * t) end
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
    -- A painted strip with a traced corridor: road stops (and the end) snap onto it, and each
    -- road segment is the stretch between them. Otherwise curves between the stops.
    local key = classFile and side and (classFile:lower() .. "-" .. side:lower())
    local P = key and ns.Art and ns.Art.strips and ns.Art.strips[key] and ns.StripPaths and newPath(ns.StripPaths[key])
    local at = {}
    if P then
        for _, r in ipairs(road) do
            at[r.key] = pathProject(P, pos[r.key][1], pos[r.key][2])
            pos[r.key] = { pathPoint(P, at[r.key]) }
        end
        at["end"] = pathProject(P, endPos[1], endPos[2])
        endPos = { pathPoint(P, at["end"]) }
    end
    local segs = {}
    for i, r in ipairs(road) do
        local nk = road[i + 1] and road[i + 1].key or "end"
        local nxt = road[i + 1] and pos[nk] or endPos
        if P and at[nk] and at[nk] > at[r.key] then
            segs[r.key] = { path = P, s0 = at[r.key], s1 = at[nk] }
        else
            segs[r.key] = roadSeg(pos[r.key], nxt)
        end
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

-- Pure: pushes label rects apart. rects = { { x0, x1, y0, y1 } ... } in map pixels (y down).
-- Each rect, in top-to-bottom order, moves down past any earlier one it overlaps.
-- Returns { [index] = shift }.
local function pushApart(rects, gap)
    local order = {}
    for i in ipairs(rects) do order[#order + 1] = i end
    table.sort(order, function(a, b) return rects[a][3] < rects[b][3] end)
    local shift, placed = {}, {}
    for _, i in ipairs(order) do
        local r = rects[i]
        local dy = 0
        local moved = true
        while moved do
            moved = false
            for _, o in ipairs(placed) do
                if r[1] < o[2] and o[1] < r[2] and r[3] + dy < o[4] + gap and o[3] < r[4] + dy + gap then
                    dy = o[4] + gap - r[3]
                    moved = true
                end
            end
        end
        shift[i] = dy
        placed[#placed + 1] = { r[1], r[2], r[3] + dy, r[4] + dy }
    end
    return shift
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

-- The class coin (round 3, owner 2026-11-10): a gold coin struck with the class emblem
-- (Media\Chrome\coin-<class>.blp), a finished stop's mark on the map and in its header.
-- Returns a texture handle (sized by the caller), or nil without this class's coin.
local function newCoin(parent, layer)
    local cf = ns.character and ns.character.classFile
    local file = cf and ns.Theme.Chrome("coin-" .. cf:lower())
    if not file then return nil end
    local t = parent:CreateTexture(nil, layer or "OVERLAY", nil, 4)
    t:SetTexture(file)
    t:SetPoint("CENTER")
    return t
end

-- A painted chrome piece as a texture (round 4: the sketch, the ring, road stamps), or nil.
local function piece(parent, name, layer, sub)
    local file = ns.Theme.Chrome(name)
    if not file then return nil end
    local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
    t:SetTexture(file)
    t:SetPoint("CENTER")
    return t
end

-- The class crest (the client's class circle icon), or false.
local function setClassIcon(tex)
    local cf = ns.character and ns.character.classFile
    local coords = cf and rawget(_G, "CLASS_ICON_TCOORDS") and CLASS_ICON_TCOORDS[cf]
    if not coords then return false end
    tex:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
    tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    return true
end

-- A node: the seal (ring, fill, level, ? or check), the medal when done, the open-now glow, the
-- focus ring, and its label plate (level line, name, what it asks). Clicking either selects it.
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
    b.crest = circle(b, "ARTWORK", 10, 1)
    b.crest:SetPoint("CENTER")
    b.crest:Hide()
    b.check = b:CreateTexture(nil, "OVERLAY")
    b.check:SetTexture(T.files.checkDone)
    b.check:SetPoint("CENTER")
    b.coin = newCoin(b)
    -- Round 4: a stop not done yet is the coin sketched in ink; open now, a red cartographer's
    -- ring of small dots around it (the sketch is see-through, so no solid disc behind it).
    local cf = ns.character and ns.character.classFile
    b.sketch = cf and piece(b, "sketch-" .. cf:lower(), "ARTWORK", 2)
    b.redDots = {}
    for i = 1, CT.redDots do
        local d = b:CreateTexture(nil, "ARTWORK", nil, 3)
        d:SetColorTexture(ns.Theme.RGB("classRedInk"))
        d:Hide()
        b.redDots[i] = d
    end
    b.lvl = T.Text(b, "xs", "classInk")
    b.lvl:SetPoint("TOP", b, "BOTTOM", 0, -1)
    b.lvl:SetShadowColor(ns.Theme.RGB("classParchment")); b.lvl:SetShadowOffset(1, -1)
    b.lvl:Hide()
    b.text = T.Text(b, "md", "white")
    b.text:SetPoint("CENTER", 0, 0)

    -- Round 3: the stop's name written on the map like the world map's place names (outlined
    -- text, no plate: the boxes hid the road). The level stays in the seal.
    local lab = CreateFrame("Button", nil, b)
    lab.name = T.Text(lab, "sm", "white")
    T.SetFont(lab.name, "sm", "OUTLINE")
    lab.name:SetShadowOffset(1, -1)
    lab.name:SetWordWrap(false)
    lab.name:SetPoint("CENTER")
    b.label = lab
    -- A left-hand name is the focus target itself, so the chevron points at the name, not into it.
    function lab:SetFocused(on) b:SetFocused(on) end

    function b:Paint()
        local c
        if self.ink then c = self.focused and "classInkFocus" or (self.selected and "classInk" or self.nameColor or "classInk")
        else c = self.focused and "focus" or (self.selected and "white" or self.nameColor or "white") end
        lab.name:SetTextColor(ns.Theme.RGB(c))
        self.focusRing:SetShown(self.focused == true)
    end
    function b:SetFocused(on) self.focused = on; self:Paint() end
    function b:SetSelected(on) self.selected = on; self:Paint() end
    W.HoverInfo(b)
    -- The label hovers as its node does (same gamepad rule: W.HoverInfo).
    lab:SetScript("OnEnter", function() local f = b:GetScript("OnEnter"); if f then f(b) end end)
    lab:SetScript("OnLeave", function() local f = b:GetScript("OnLeave"); if f then f(b) end end)
    b:SetScript("OnClick", function(self) if self.onClick then self.onClick() end end)
    lab:SetScript("OnClick", function() if b.onClick then b.onClick() end end)
    return b
end

-- An ability mark on the road (round 4): the level's first new ability's icon in a ring coloured
-- by its state, "+n" when the level brings more than one. A focus stop; its abilities show on
-- the right.
local function newAbilityMark(parent)
    local T, CT, W = ns.Theme, ns.Theme.layout.classTab, ns.Widgets
    local b = CreateFrame("Button", nil, parent)
    b.focusRing = circle(b, "BACKGROUND", 10, 1)
    b.focusRing:SetPoint("CENTER")
    tint(b.focusRing, "focus", 0.6)
    b.focusRing:Hide()
    b.ring = circle(b, "BORDER", 10)
    b.ring:SetPoint("CENTER")
    b.icon = circle(b, "ARTWORK", 10)
    b.icon:SetPoint("CENTER")
    b.more = T.Text(b, "xs", "classInk")
    b.more:SetPoint("LEFT", b, "RIGHT", 1, -4)
    b.more:SetShadowColor(T.RGB("classParchment")); b.more:SetShadowOffset(1, -1)
    function b:SetFocused(on) self.focused = on; self.focusRing:SetShown(on or self.selected) end
    function b:SetSelected(on) self.selected = on; self.focusRing:SetShown(on or self.focused) end
    W.HoverInfo(b)
    b:SetScript("OnClick", function(self) if self.onClick then self.onClick() end end)
    return b
end

local ABILITY_RING = { learned = "complete", available = "classRedInk", later = "classInkFaded", unknown = "classInkFaded" }
local ABILITY_STATE = { learned = "Learned", available = "You can train it now", later = "Later", unknown = "Not known" }

-- Seal colours per state: ring, fill, text.
local SEAL = {
    done = { "classBeadOn", "complete", "ink" },
    progress = { "classPeach", "todo", "white" },
    ready = { "classPeach", "ctlOn", "white" },
    later = { "untouched", "cardBg", "dim" },
    unknown = { "untouched", "cardBg", "dim" },
}

-- Anchors a node's label beside it (or below), `shift` units further down (pushed apart).
local function anchorLabel(b, shift)
    local CT = ns.Theme.layout.classTab
    local lab = b.label
    lab:ClearAllPoints()
    shift = shift or 0
    -- A coin is wider than the seal: names keep clear of it.
    local extra = b.coin and b.coin:IsShown() and math.max(0, ((b.coin:GetWidth() or 0) - (b:GetWidth() or 0)) / 2) or 0
    if b.labelSide == "left" then lab:SetPoint("RIGHT", b, "LEFT", -CT.labelGap - extra, -shift)
    elseif b.labelSide == "below" then lab:SetPoint("TOP", b, "BOTTOM", 0, -4 - shift)
    else lab:SetPoint("LEFT", b, "RIGHT", CT.labelGap + extra, -shift) end
end

-- Paints a node: size, state, seal text, its name, the name's side ("left"|"right"|"below").
-- coinSize: the class coin's size when done (nil = no coin).
local function paintNode(b, size, state, text, name, labelSide, coinSize, ink)
    local T, CT = ns.Theme, ns.Theme.layout.classTab
    b:SetSize(size, size)
    b.ink = ink and true or false
    local c = SEAL[state] or SEAL.unknown
    local coin = state == "done" and coinSize and b.coin ~= nil
    -- Round 4 on the antique map: an unfinished stop is the coin sketched in ink.
    local sketch = ink and not coin and state ~= "done" and b.sketch ~= nil and coinSize ~= nil
    b.ring:SetSize(size, size); tint(b.ring, c[1], state == "unknown" and 0.5 or 1)
    b.fill:SetSize(size - 2 * CT.ring, size - 2 * CT.ring); tint(b.fill, c[2])
    b.ring:SetShown(not coin and not sketch); b.fill:SetShown(not coin and not sketch)
    b.crest:Hide()
    local ringSize = coin and coinSize or size
    b.focusRing:SetSize(ringSize + 8, ringSize + 8)
    tint(b.focusRing, "focus", ink and 0.35 or 1)
    b.glow:SetSize(size + CT.glow, size + CT.glow); tint(b.glow, "classPeach", 0.55)
    local glow = state == "ready" and not ink
    b.glowFrame:SetShown(glow)
    if b.glowFrame.anim then
        if glow then b.glowFrame.anim:Play() else b.glowFrame.anim:Stop() end
    end
    if b.sketch then
        b.sketch:SetShown(sketch)
        if sketch then
            b.sketch:SetSize(size + 2, size + 2)
            local faint = state == "later" or state == "unknown"
            b.sketch:SetAlpha(faint and 0.45 or 1)
            if b.sketch.SetDesaturated then b.sketch:SetDesaturated(faint) end
        end
    end
    local red = sketch and (state == "ready" or state == "progress")
    local r = size / 2 + 4
    for i, d in ipairs(b.redDots) do
        d:SetShown(red)
        if red then
            local a = (i - 1) / #b.redDots * math.pi * 2
            d:SetSize(CT.redDot, CT.redDot)
            d:ClearAllPoints()
            d:SetPoint("CENTER", b, "CENTER", r * math.cos(a), r * math.sin(a))
        end
    end
    b.lvl:SetShown(sketch)
    b.lvl:SetText(state == "unknown" and "?" or (text or ""))
    if b.coin then b.coin:SetShown(coin); if coin then b.coin:SetSize(coinSize, coinSize) end end
    b.check:SetSize(size * 0.55, size * 0.55)
    b.check:SetShown(state == "done" and not coin)
    if state == "done" then b.check:SetVertexColor(0.35, 0.22, 0.02) end
    b.text:SetShown(state ~= "done" and not sketch)
    b.text:SetText(state == "unknown" and "?" or (text or ""))
    T.SetFont(b.text, size >= CT.node and "md" or "xs")
    b.text:SetTextColor(T.RGB(c[3]))
    -- The name (round 3): gold when done, parchment while later or not known. Round 4 on the
    -- antique map: ink, deep gold when done, faded when later, a soft paper halo, no outline.
    local lab = b.label
    lab.name:SetText(name or "")
    if ink then
        T.SetFont(lab.name, "sm")
        lab.name:SetShadowColor(T.RGB("classParchment")); lab.name:SetShadowOffset(1, -1)
        b.nameColor = state == "done" and "classInkGold" or ((state == "later" or state == "unknown") and "classInkFaded" or "classInk")
    else
        T.SetFont(lab.name, "sm", "OUTLINE")
        lab.name:SetShadowColor(0, 0, 0, 1); lab.name:SetShadowOffset(1, -1)
        b.nameColor = state == "done" and "complete" or ((state == "later" or state == "unknown") and "classNameDim" or "className")
    end
    lab.name:SetJustifyH(labelSide == "left" and "RIGHT" or (labelSide == "below" and "CENTER" or "LEFT"))
    local w = math.ceil(lab.name:GetStringWidth() or 0) + 4
    local h = T.size.sm + 6
    lab:SetSize(w, h)
    b.labelSide = labelSide
    b.labelW, b.labelH = w, h
    anchorLabel(b, 0)
    b:Paint()
end

-- A step row (right pane): a numbered ring, the main line with a second line below, a right column.
local function newStepRow(parent)
    local T, CT, W = ns.Theme, ns.Theme.layout.classTab, ns.Widgets
    local row = W.FocusRow(parent, CT.stepRow)
    row.ring = circle(row, "BORDER", CT.stepIcon)
    row.ring:SetPoint("LEFT", ns.Theme.space.s2, 0)
    row.fill = circle(row, "ARTWORK", CT.stepIcon - 2)
    row.fill:SetPoint("CENTER", row.ring, "CENTER")
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
        self.ring:SetAlpha((self.faint and not lit) and 0.6 or 1)
    end
    return row
end

-- kind: done | next | after | later | unknown | sub (in place, not counted) | lead (Start here) |
-- progress (a stop row). glyph: the ring's text (the step's number, "?").
local function paintStepRow(row, kind, glyph, name, sub, right)
    local ringC = ({ done = "classBeadOn", next = "classPeach", progress = "classPeach" })[kind] or "levelRange"
    local fillC = ({ done = "complete", progress = "todo", next = "ctlOn" })[kind] or "cardBg"
    tint(row.ring, ringC); tint(row.fill, fillC)
    row.check:SetShown(kind == "done")
    row.glyph:SetShown(kind ~= "done" and glyph ~= nil)
    row.glyph:SetText(glyph or "")
    row.glyph:SetTextColor(ns.Theme.RGB(kind == "next" and "classPeach" or "text"))
    row.name:SetText(name or "")
    row.nameColor = kind == "done" and "complete" or ((kind == "later" or kind == "sub" or kind == "lead" or kind == "unknown") and "dim" or "white")
    row.sub:SetText(sub or "")
    row.lv:SetText(right or "")
    row.faint = kind == "later" or kind == "sub" or kind == "lead" or kind == "unknown"
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
    page.nodes, page.dots, page.edges, page.beads, page.cairns, page.abilities = {}, {}, {}, {}, {}, {}
    page.stepRows, page.headers, page.notes = {}, {}, {}

    -- Left: the plaque and the map --------------------------------------------------------------
    local strip = CreateFrame("Frame", nil, page)
    strip:SetPoint("TOPLEFT"); strip:SetPoint("BOTTOMLEFT")
    local plaque = CreateFrame("Frame", nil, strip)
    plaque:SetPoint("TOPLEFT"); plaque:SetPoint("TOPRIGHT"); plaque:SetHeight(CT.plaque)
    T.Solid(plaque, "black", "BACKGROUND", 0.45):SetAllPoints()
    local prule = T.Solid(plaque, "divider", "BORDER")
    prule:SetPoint("BOTTOMLEFT"); prule:SetPoint("BOTTOMRIGHT"); prule:SetHeight(1)
    plaque.title = T.Text(plaque, "lg", "gold")
    plaque.title:SetPoint("TOP", 0, -S.s2)
    plaque.count = T.Text(plaque, "xs", "dim")
    plaque.count:SetPoint("TOP", plaque.title, "BOTTOM", 0, -S.s1)
    plaque.next = T.Text(plaque, "xs", "classPeach")
    plaque.next:SetPoint("TOP", plaque.count, "BOTTOM", 0, -S.s1)
    plaque.next:SetPoint("LEFT", plaque, "LEFT", S.s2, 0)
    plaque.next:SetPoint("RIGHT", plaque, "RIGHT", -S.s2, 0)
    plaque.next:SetWordWrap(true)
    if plaque.next.SetMaxLines then plaque.next:SetMaxLines(2) end
    page.plaque = plaque
    -- The road overview rail (review item 13): the whole road at a glance at the strip's right
    -- edge, fixed while the map scrolls. Dots per stop, your ring, the road's end, the view.
    local rail = CreateFrame("Frame", nil, strip)
    rail:SetPoint("TOPRIGHT", plaque, "BOTTOMRIGHT", 0, 0)
    rail:SetPoint("BOTTOMRIGHT", strip, "BOTTOMRIGHT", -1, 0)
    rail:SetWidth(CT.rail)
    rail.bg = T.Solid(rail, "black", "BACKGROUND", 0.5)
    rail.bg:SetAllPoints()
    local redge = T.Solid(rail, "divider", "BORDER")
    redge:SetPoint("TOPLEFT"); redge:SetPoint("BOTTOMLEFT"); redge:SetWidth(1)
    rail.track = CreateFrame("Frame", nil, rail)
    rail.track:SetPoint("TOPLEFT", 0, -CT.railPad); rail.track:SetPoint("BOTTOMRIGHT", 0, CT.railPad)
    -- Round 4: the map's scale bar. The line sits right of centre; level numbers to its left.
    rail.line = T.Solid(rail.track, "classRailLine", "BORDER")
    rail.line:SetPoint("TOP", CT.railLineX, 0); rail.line:SetPoint("BOTTOM", CT.railLineX, 0); rail.line:SetWidth(CT.railLine)
    -- Round 3: the road you've levelled through is gold down to your mark.
    rail.fill = T.Solid(rail.track, "complete", "BORDER", 1)
    rail.fill:SetWidth(CT.railLine)
    rail.fill:Hide()
    rail.ticks = {}
    for i, lv in ipairs(CT.railTicks) do
        local tick = T.Solid(rail.track, "classRailLine", "ARTWORK")
        tick:SetSize(CT.railTick, 1)
        local label = T.Text(rail.track, "xs", "dim")
        label:SetJustifyH("RIGHT"); label:SetWidth(CT.railLabel); label:SetWordWrap(false)
        label:SetText(tostring(lv))
        rail.ticks[i] = { level = lv, tick = tick, label = label }
    end
    -- Round 3 (no box): the part in view glows on the line, a brass notch at each end.
    rail.view = CreateFrame("Frame", nil, rail.track)
    rail.view:SetWidth(CT.railView)
    -- Bright on the line, fading to each side: two halves with mirrored gradients.
    for _, half in ipairs({ "LEFT", "RIGHT" }) do
        local g = rail.view:CreateTexture(nil, "ARTWORK")
        g:SetPoint("TOP"); g:SetPoint("BOTTOM"); g:SetPoint(half)
        g:SetWidth(CT.railView / 2)
        g:SetColorTexture(1, 1, 1, 1)
        local edge, mid = CreateColor and CreateColor(1, 0.92, 0.67, 0), CreateColor and CreateColor(1, 0.92, 0.67, 0.6)
        local ok = edge and pcall(g.SetGradient, g, "HORIZONTAL", half == "LEFT" and edge or mid, half == "LEFT" and mid or edge)
        if not ok then g:SetColorTexture(1, 0.92, 0.67, 0.35) end
    end
    rail.view.notchTop = T.Solid(rail.view, "classNotch", "OVERLAY")
    rail.view.notchTop:SetSize(CT.railNotch[1], CT.railNotch[2]); rail.view.notchTop:SetPoint("CENTER", rail.view, "TOP", 0, 0)
    rail.view.notchBottom = T.Solid(rail.view, "classNotch", "OVERLAY")
    rail.view.notchBottom:SetSize(CT.railNotch[1], CT.railNotch[2]); rail.view.notchBottom:SetPoint("CENTER", rail.view, "BOTTOM", 0, 0)
    rail.view:SetFrameLevel(rail.track:GetFrameLevel() + 3)
    rail.dots = {}
    page.rail = rail
    local mscroll = W.Scroll(strip)
    mscroll:SetPoint("TOPLEFT", plaque, "BOTTOMLEFT", S.s2, -S.s2)
    mscroll:SetPoint("BOTTOMRIGHT", rail, "BOTTOMLEFT", -S.s2, S.s2)
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
    local you = CreateFrame("Frame", nil, map)
    you:SetSize(CT.you, CT.you)
    you.ring = circle(you, "BORDER", CT.you)
    you.ring:SetPoint("CENTER")
    you.icon = circle(you, "ARTWORK", CT.you - 4)
    you.icon:SetPoint("CENTER")
    you.tag = CreateFrame("Frame", nil, you)
    you.tag:SetSize(CT.youTag[1], CT.youTag[2])
    you.tag:SetPoint("TOP", you, "BOTTOM", 0, -2)
    you.tagBg = T.Solid(you.tag, "classLabel", "BACKGROUND", 0.9)
    you.tagBg:SetAllPoints()
    -- Round 4: the brass ring (you-ring) around your portrait; its inside is about 56% of the
    -- piece, its centre a little below the middle (the pin is on top).
    you.brass = piece(you, "you-ring", "OVERLAY", 2)
    if you.brass then
        you.brass:SetSize((CT.you - 4) / 0.56, (CT.you - 4) / 0.56)
        you.brass:ClearAllPoints(); you.brass:SetPoint("CENTER", you, "CENTER", 0, 2)
        you.brass:Hide()
    end
    you.tagEdge = W.Edge(you.tag, "BORDER")
    you.tagText = T.Text(you.tag, "xs", "white")
    you.tagText:SetPoint("CENTER", 0, 0)
    you.tagText:SetText("You")
    page.you = you

    -- Right: the stop -----------------------------------------------------------------------------
    local d = CreateFrame("Frame", nil, page)
    d:SetPoint("TOPLEFT", strip, "TOPRIGHT"); d:SetPoint("BOTTOMRIGHT")
    local hero = CreateFrame("Frame", nil, d)
    hero:SetPoint("TOPLEFT"); hero:SetPoint("TOPRIGHT"); hero:SetHeight(CT.hero)
    hero.bg = hero:CreateTexture(nil, "BACKGROUND")
    hero.bg:SetAllPoints()
    hero.bg:SetColorTexture(1, 1, 1, 1)
    -- The stop's zone art (round 2), darkened toward the text by the shade.
    hero.art = hero:CreateTexture(nil, "BACKGROUND", nil, 1)
    hero.art:SetAllPoints()
    hero.art:Hide()
    hero.shade = hero:CreateTexture(nil, "BORDER")
    hero.shade:SetAllPoints()
    hero.shade:SetColorTexture(1, 1, 1, 1)
    local okShade = type(CreateColor) == "function" and pcall(hero.shade.SetGradient, hero.shade, "HORIZONTAL",
        CreateColor(0.04, 0.024, 0.008, 0.92), CreateColor(0.04, 0.024, 0.008, 0.55))
    if not okShade then hero.shade:SetColorTexture(0.04, 0.024, 0.008, 0.7) end
    function hero:SetLook(gold, mapID, grey)
        local a, b = gold and { 0.54, 0.39, 0.13 } or { 0.24, 0.16, 0.08 }, gold and { 0.23, 0.15, 0.05 } or { 0.08, 0.05, 0.02 }
        local ok = type(CreateColor) == "function" and pcall(self.bg.SetGradient, self.bg, "HORIZONTAL",
            CreateColor(b[1], b[2], b[3], 1), CreateColor(a[1], a[2], a[3], 1))
        if not ok then self.bg:SetColorTexture(a[1], a[2], a[3], 1) end
        local art = mapID and T.ZoneArt(mapID)
        self.mapID = art and mapID or nil
        self.art:SetShown(art ~= nil)
        self.shade:SetShown(art ~= nil)
        if art then
            self.art:SetTexture(art)
            local top, bottom = T.BannerCrop(mapID, self:GetWidth(), self:GetHeight())
            self.art:SetTexCoord(0, 1, top, bottom)
            if self.art.SetDesaturated then self.art:SetDesaturated(grey and true or false) end
            self.art:SetAlpha(grey and 0.7 or 1)
        end
    end
    hero:SetScript("OnSizeChanged", function(self)
        if self.mapID then
            local top, bottom = T.BannerCrop(self.mapID, self:GetWidth(), self:GetHeight())
            self.art:SetTexCoord(0, 1, top, bottom)
        end
    end)
    local hrule = T.Solid(hero, "divider", "ARTWORK")
    hrule:SetPoint("BOTTOMLEFT"); hrule:SetPoint("BOTTOMRIGHT"); hrule:SetHeight(2)
    hero.score = T.Text(hero, "huge", "classPeach")
    hero.score:SetPoint("BOTTOMRIGHT", hero, "BOTTOMRIGHT", -S.s6, S.s6 + S.s2)
    hero.medal = newCoin(hero, "OVERLAY")
    if hero.medal then
        hero.medal:SetSize(CT.heroCoin, CT.heroCoin)
        hero.medal:ClearAllPoints()
        hero.medal:SetPoint("RIGHT", hero, "RIGHT", -S.s4, 0)
    end
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
    -- The score: a number with a line under it, the medal when done (the check without the art).
    function hero:SetScore(kind, big, small, color)
        local medal = kind == "done" and self.medal ~= nil
        if self.medal then self.medal:SetShown(medal) end
        self.check:SetShown(kind == "done" and not medal)
        self.score:SetShown(kind ~= "done")
        self.small:SetShown(kind ~= "done" or not medal)
        self.score:SetText(big or "")
        self.score:SetTextColor(T.RGB(color or "classPeach"))
        self.small:SetText(kind == "done" and "Done" or (small or ""))
    end
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
        local mapW = math.max(1, (mscroll:GetWidth() or 0) > 1 and mscroll:GetWidth()
            or ((page.wide and CT.stripWide or CT.strip) - 2 * S.s2 - CT.rail))
        local s = mapW / lay.W
        page.scale = s
        -- Room under the road's end for its label (it was cut off, WoWScrnShot_110926_221342).
        local endBottom = lay.endPos[2] * s + CT.endNode / 2 + CT.endLabel
        map:SetHeight(math.floor(math.max(lay.H * s, endBottom) + 0.5))
        local H = lay.H * s
        -- The painted strip when this class and side has one (Media\Strips, 1:4), else the sky.
        local c = ns.character or {}
        local stripKey = c.classFile and c.faction and (c.classFile:lower() .. "-" .. c.faction:lower())
        local strip = stripKey and ns.Art and ns.Art.strips and ns.Art.strips[stripKey]
            and (T.mediaDir .. "Strips\\" .. stripKey .. ".blp")
        if not page.stripArt then page.stripArt = map:CreateTexture(nil, "BACKGROUND", nil, 2) end
        page.stripArt:ClearAllPoints()
        page.stripArt:SetPoint("TOPLEFT", map, "TOPLEFT", 0, 0)
        page.stripArt:SetSize(mapW, H)
        page.stripArt:SetShown(strip ~= nil)
        if strip then page.stripArt:SetTexture(strip) end
        page.painted = strip ~= nil
        for i, t in ipairs(page.sky) do
            t:SetShown(not strip)
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", map, "TOPLEFT", 0, -T.classSky[i][1] * H)
            t:SetPoint("TOPRIGHT", map, "TOPRIGHT", 0, -T.classSky[i][1] * H)
            t:SetHeight(math.max(1, (T.classSky[i + 1][1] - T.classSky[i][1]) * H))
        end
        local function at(tex, x, y) tex:SetPoint("CENTER", map, "TOPLEFT", x * s, -y * s) end
        -- Round 3: the road means levels. It fills gold from the start to your level (XP
        -- included; ClassJourneyRules.LevelPos); a side path's dotted track fills when it's done.
        -- Round 4: the road from painted stamps when the map is painted and the pieces exist.
        local stamps = page.painted and T.Chrome("road-dash-ink-1") and T.Chrome("road-dash-ink-2")
            and T.Chrome("road-dash-gold-1") and T.Chrome("road-dash-gold-2") and T.Chrome("road-dot") and true or false
        local roadIndex, levels = {}, {}
        for i, r in ipairs(lay.road) do roadIndex[r.key] = i; levels[i] = r.level end
        local li, lt = ns.ClassJourneyRules.LevelPos(levels, page:LevelNow(), 60)
        page.levelSeg, page.levelT = li, lt
        for _, st in ipairs(j.stops) do
            local seg = lay.segs[st.key]
            if seg then
                local side = st.kind == "side" or lay.from[st.key] ~= nil
                local ri = roadIndex[st.key]
                local lit
                if side then lit = st.done and st.count > 0 and st.done / st.count or 0
                else lit = not li and 0 or (ri < li and 1 or (ri == li and lt or 0)) end
                if stamps then
                    -- Round 4: painted stamps along the curve, turned to follow it: gold-leaf
                    -- dashes as far as your level, ink after (two variants each, alternated);
                    -- a side path's ink dots, gilded once it's done.
                    for k, p in ipairs(along(seg, side and CT.dotStep or CT.stampStep)) do
                        local tex = take("dots", newTex("BORDER", 1), map)
                        local on = lit > 0 and p[4] <= lit
                        tex:SetVertexColor(1, 1, 1)
                        if side then
                            tex:SetTexture(on and T.Chrome("road-dash-gold-1") or T.Chrome("road-dot"))
                            if on then tex:SetTexCoord(0.42, 0.58, 0.3, 0.7) else tex:SetTexCoord(0, 1, 0, 1) end
                            tex:SetSize(CT.dotSize * s, CT.dotSize * s)
                            if tex.SetRotation then tex:SetRotation(0) end
                        else
                            tex:SetTexture(T.Chrome("road-dash-" .. (on and "gold" or "ink") .. "-" .. ((k % 2) + 1)))
                            tex:SetTexCoord(0, 1, 0, 1)
                            tex:SetSize(CT.stampLen * s, CT.stampW * s)
                            if tex.SetRotation then tex:SetRotation(p[3]) end
                        end
                        at(tex, p[1], p[2])
                    end
                end
                local pts = stamps and {} or along(seg, side and CT.sideStep or CT.roadStep)
                -- A dark edge under the road, so it reads on a busy painting (round 3:
                -- a plain line got lost, WoWScrnShot_111026_184819).
                if not side then
                    for _, p in ipairs(pts) do
                        local edge = take("edges", newTex("BORDER", 0), map)
                        local size = (CT.road + CT.roadEdge * 2) * s
                        edge:SetSize(size, size)
                        tint(edge, "ink", 0.7)
                        if edge.SetRotation then edge:SetRotation(p[3]) end
                        at(edge, p[1], p[2])
                    end
                end
                for _, p in ipairs(pts) do
                    local tex = take("dots", newTex("BORDER", 1), map)
                    local size = (side and CT.sideDot or CT.road) * s
                    tex:SetSize(size, size)
                    tex:SetTexCoord(0, 1, 0, 1)
                    local on = lit > 0 and p[4] <= lit
                    tint(tex, on and "complete" or "classRoad", on and 1 or 0.95)
                    if tex.SetRotation then tex:SetRotation(side and 0 or p[3]) end
                    at(tex, p[1], p[2])
                end
            end
        end
        -- Quest pips ring each node (round 3: completion lives on the node, not the road).
        for _, st in ipairs(j.stops) do
            local side = lay.from[st.key] ~= nil
            local p = lay.pos[st.key]
            local r, size = side and CT.sidePipRing or CT.pipRing, side and CT.sidePip or CT.pip
            local n = #st.steps
            for k, step in ipairs(st.steps) do
                local a = -math.pi / 2 + (k - 1) / n * math.pi * 2
                local px, py = p[1] + r * math.cos(a), p[2] + r * math.sin(a)
                local ring = take("beads", function() return circle(map, "ARTWORK", size, 1) end, map)
                ring:SetSize(size + 2, size + 2); tint(ring, page.painted and "classInk" or "ink", page.painted and 0.8 or 1)
                at(ring, px, py)
                local dot = take("beads", function() return circle(map, "ARTWORK", size, 2) end, map)
                dot:SetSize(size, size)
                -- Round 4 on the antique map: ink dots on paper, gold when done.
                local todo = page.painted and "classParchment" or "classBead"
                tint(dot, step.state == "done" and "complete" or todo, step.state == "unknown" and 0.45 or 1)
                at(dot, px, py)
            end
        end
        -- Cairns under side paths: three stones.
        for _, st in ipairs(j.stops) do
            if lay.from[st.key] then
                local p = lay.pos[st.key]
                for _, sz in ipairs({ { 22, 9, 8 }, { 16, 8, 1 }, { 10, 6, -5 } }) do
                    local c = take("cairns", function() return circle(map, "ARTWORK", 10, 3) end, map)
                    c:SetSize(sz[1], sz[2]); tint(c, page.painted and "classInkFaded" or "classCairn", page.painted and 0.45 or 1)
                    c:SetPoint("CENTER", map, "TOPLEFT", p[1] * s, -(p[2] + 30 + sz[3]) * s)
                end
            end
        end
        -- Nodes.
        local byKey, rows = {}, {}
        local sideOf = {} -- stops that have a side path, or are one: the legend's side-path hint
        for rk in pairs(lay.sides) do sideOf[rk] = true end
        for sk in pairs(lay.from) do sideOf[sk] = true end
        local placed = {} -- { node, x, y, size } for pushing labels apart
        for _, st in ipairs(j.stops) do
            local b = take("nodes", newNode, map)
            local p = lay.pos[st.key]
            local side = lay.from[st.key] ~= nil
            local size = side and CT.sideNode or CT.node
            local state = st.state or "unknown"
            local labelSide = p[1] > lay.W * 0.58 and "left" or "right"
            paintNode(b, size, state, tostring(st.level or "?"), st.name, labelSide, side and CT.sideCoin or CT.coin, page.painted)
            -- The name goes where it fits: past the strip's edge on one side, the other side
            -- ("The Tome of Divinity" ran off the right edge once it sat on the traced path,
            -- WoWScrnShot_111026_201546).
            local half, room = size / 2 + CT.labelGap, (b.labelW or 0)
            local rightEnd, leftStart = p[1] * s + half + room, p[1] * s - half - room
            if labelSide == "right" and rightEnd > mapW - 4 and leftStart > 4 then labelSide = "left"
            elseif labelSide == "left" and leftStart < 4 and rightEnd < mapW - 4 then labelSide = "right" end
            if labelSide ~= b.labelSide then
                b.labelSide = labelSide
                b.label.name:SetJustifyH(labelSide == "left" and "RIGHT" or "LEFT")
                anchorLabel(b, 0)
            end
            b:SetPoint("CENTER", map, "TOPLEFT", p[1] * s, -p[2] * s)
            b:SetFrameLevel(map:GetFrameLevel() + 5)
            byKey[st.key] = b
            local key = st.key
            -- A left-hand name is the focus frame, so the chevron points at the name (round 3).
            b.item = { key = "n:" .. key, frame = labelSide == "left" and b.label or b, title = st.name,
                detail = stopInfo(st, "A shows the steps."), scroll = mscroll, stopKey = key, actionLabel = "Steps",
                sidePath = sideOf[key], onActivate = function() page:EnterSteps() end }
            b.label.item = b.item
            b.onClick = function() page:SelectStop(key, true) end
            placed[#placed + 1] = { b, p[1] * s, p[2] * s, size }
        end
        hideRest("dots"); hideRest("edges"); hideRest("beads"); hideRest("cairns"); hideRest("nodes")
        -- The road's end: the class crest, greyed until the road is walked (round 2: it was an
        -- empty circle in game).
        local e = page.endNode
        local qs = j.quests
        local walked = j.complete == true
        local endState = walked and "done" or (j.complete == nil and "unknown" or "later")
        paintNode(e, CT.endNode, endState, "", walked and "The road walked" or "The road's end", "below", nil, page.painted)
        e.text:Hide(); e.check:Hide(); e.lvl:Hide()
        if e.sketch then e.sketch:Hide() end
        for _, d in ipairs(e.redDots) do d:Hide() end
        if page.painted then
            -- Round 4: the painted map has its own star at the road's end; the node only glows
            -- gold when the road is walked.
            e.ring:Hide(); e.fill:Hide(); e.crest:Hide()
        else
            tint(e.ring, walked and "complete" or "levelRange"); e.ring:Show()
            tint(e.fill, "ink"); e.fill:Show()
            e.crest:SetSize(CT.endNode - 2 * CT.ring - 2, CT.endNode - 2 * CT.ring - 2)
            if setClassIcon(e.crest) then
                e.crest:Show()
                if e.crest.SetDesaturated then e.crest:SetDesaturated(not walked) end
                e.crest:SetAlpha(walked and 1 or 0.55)
            end
        end
        e.ink = page.painted
        e.nameColor = page.painted and (walked and "classInkGold" or "classInk") or e.nameColor
        e:Paint()
        e.glowFrame:SetShown(walked)
        tint(e.glow, "complete", 0.5)
        if e.glowFrame.anim then if walked then e.glowFrame.anim:Play() else e.glowFrame.anim:Stop() end end
        e:SetPoint("CENTER", map, "TOPLEFT", lay.endPos[1] * s, -lay.endPos[2] * s)
        e:SetFrameLevel(map:GetFrameLevel() + 5)
        e.item = { key = "n:end", frame = e, title = walked and "The road walked" or "The road's end",
            detail = walked and "Every class quest on the road and its side paths is done. A lists every stop."
                or (j.complete == nil and (qs.count .. " class quests; done or not isn't known yet. A lists every stop.")
                or (qs.done .. " of " .. qs.count .. " class quests done. A lists every stop.")),
            scroll = mscroll, stopKey = "end", actionLabel = "Stops", onActivate = function() page:EnterSteps() end }
        e.onClick = function() page:SelectStop("end", true) end
        placed[#placed + 1] = { e, lay.endPos[1] * s, lay.endPos[2] * s, CT.endNode }
        -- Labels never overlap (round 2): push them apart top to bottom.
        local rects = {}
        for i, pl in ipairs(placed) do
            local b, x, y, size = pl[1], pl[2], pl[3], pl[4]
            local w, h = b.labelW or 0, b.labelH or 0
            if b.labelSide == "left" then rects[i] = { x - size / 2 - CT.labelGap - w, x - size / 2 - CT.labelGap, y - h / 2, y + h / 2 }
            elseif b.labelSide == "below" then rects[i] = { x - w / 2, x + w / 2, y + size / 2 + 4, y + size / 2 + 4 + h }
            else rects[i] = { x + size / 2 + CT.labelGap, x + size / 2 + CT.labelGap + w, y - h / 2, y + h / 2 } end
        end
        local shift = pushApart(rects, CT.labelPush)
        for i, pl in ipairs(placed) do anchorLabel(pl[1], shift[i]) end
        page.labelShift = shift
        -- The names where they ended up (map pixels), for ability marks to keep clear of.
        local nameRects = {}
        for i, r in ipairs(rects) do nameRects[i] = { r[1], r[2], r[3] + shift[i], r[4] + shift[i] } end
        -- "You" (round 3): on the road at your level, riding the front of the fill, with
        -- "You · 10" beside it. Your level is always known, so it shows even when completion isn't.
        you:Hide()
        page.youX, page.youY = nil, nil
        local youSeg = li and lay.road[li] and lay.segs[lay.road[li].key]
        if youSeg then
            -- Near a stop, You waits just outside its pips instead of covering its seal
            -- (it sat on Divinity's "12" at 87% of the way, WoWScrnShot_111026_184819).
            local a = lay.pos[lay.road[li].key]
            local b2 = lay.road[li + 1] and lay.pos[lay.road[li + 1].key] or lay.endPos
            local clear = CT.pipRing + CT.you / 2 / s
            local t0 = lt
            local function near(t, p) local x, y = bez(youSeg, t); return math.sqrt((x - p[1]) ^ 2 + (y - p[2]) ^ 2) < clear end
            while t0 > 0 and near(t0, b2) do t0 = t0 - 0.01 end
            while t0 < 1 and near(t0, a) do t0 = t0 + 0.01 end
            local x, y = bez(youSeg, math.max(0, math.min(1, t0)))
            page.youX, page.youY = x, y
            you:ClearAllPoints()
            you:SetPoint("CENTER", map, "TOPLEFT", x * s, -y * s)
            you:SetFrameLevel(map:GetFrameLevel() + 7)
            you.tag:SetFrameLevel(map:GetFrameLevel() + 8)
            you.tag:ClearAllPoints()
            -- The tag on the side away from the nearer stop's name (it covered "The Tome of
            -- Divinity", WoWScrnShot_111026_184819).
            local nearKey = lt >= 0.5 and lay.road[li + 1] and lay.road[li + 1].key or lay.road[li].key
            local nearNode = byKey[nearKey]
            local nameLeft = nearNode and nearNode.labelSide == "left"
            if nearNode == nil then nameLeft = x >= lay.W / 2 end
            if nameLeft then you.tag:SetPoint("LEFT", you, "RIGHT", 3, 0) else you.tag:SetPoint("RIGHT", you, "LEFT", -3, 0) end
            you.tag:SetWidth(CT.youTagW)
            you.tagText:SetText("You  ·  " .. tostring(c.level or "?"))
            -- Round 4: your portrait in the brass ring (a token pinned to the map), an ink tag on
            -- parchment. No class colour (the pink was the Paladin's).
            local portrait = type(SetPortraitTexture) == "function" and pcall(SetPortraitTexture, you.icon, "player")
            if not portrait and not setClassIcon(you.icon) then tint(you.icon, "classParchment") end
            if you.brass then
                you.brass:Show(); you.ring:Hide()
            else
                you.ring:Show(); tint(you.ring, "classNotch")
            end
            tint(you.tagBg, page.painted and "classParchment" or "classLabel", 0.92)
            you.tagEdge:SetColor(page.painted and "classInk" or "classNotch")
            you.tagText:SetTextColor(T.RGB(page.painted and "classInk" or "white"))
            you.tagText:SetShadowOffset(page.painted and 0 or 1, page.painted and 0 or -1)
            you:Show()
        end
        -- Abilities along the road (round 4, the owner's idea): a mark beside the road at each level
        -- that grants a new ability, from your class trainer's recorded list (Systems/ClassTrainer).
        local tr = ns.ClassTrainer and ns.ClassTrainer.Get() or { status = "none" }
        page.trainer = tr
        local abilityRows = {}
        page.abilityMarks = {}
        -- What a mark must keep clear of (logical units): stops with their pips, the road's end,
        -- You, and the marks placed before it (levels 1-12 crowd the letter and Divinity,
        -- WoWScrnShot_111026_200313).
        local blockers = {}
        for key, pos in pairs(lay.pos) do
            blockers[#blockers + 1] = { pos[1], pos[2], (lay.from[key] and CT.sidePipRing or CT.pipRing) + 6 }
        end
        blockers[#blockers + 1] = { lay.endPos[1], lay.endPos[2], CT.endNode / 2 / s }
        if page.youX then blockers[#blockers + 1] = { page.youX, page.youY, CT.you / 2 / s + 3 } end
        local markR = CT.abilityMark / 2 / s + 2
        local function clear(px, py)
            for _, b in ipairs(blockers) do
                if math.sqrt((px - b[1]) ^ 2 + (py - b[2]) ^ 2) < b[3] + markR then return false end
            end
            -- Stop names too (a mark sat across "A Strange Artifact", WoWScrnShot_111026_200942).
            local x, y, r = px * s, py * s, markR * s
            for _, n in ipairs(nameRects) do
                if x + r > n[1] and x - r < n[2] and y + r > n[3] and y - r < n[4] then return false end
            end
            return px > markR and px < lay.W - markR
        end
        if tr.status == "recorded" then
            for _, mk in ipairs(tr.abilities.marks) do
                local i, t = ns.ClassJourneyRules.LevelPos(levels, mk.level, 60)
                local seg = i and lay.road[i] and lay.segs[lay.road[i].key]
                if seg then
                    local x, y = bez(seg, t)
                    local x1, y1 = bez(seg, math.max(0, t - 0.01))
                    local x2, y2 = bez(seg, math.min(1, t + 0.01))
                    local len = math.max(1e-6, math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2))
                    -- Beside the road (perpendicular to it): the first spot that's clear, right
                    -- side, left side, then further out.
                    local nx, ny = -(y2 - y1) / len, (x2 - x1) / len
                    local mx, my
                    for _, off in ipairs(CT.abilityOffsets) do
                        mx, my = x + nx * off, y + ny * off
                        if clear(mx, my) then break end
                    end
                    blockers[#blockers + 1] = { mx, my, markR, mark = true }
                    local m = take("abilities", newAbilityMark, map)
                    local first
                    for _, ab in ipairs(mk.abilities) do if ab.new then first = first or ab end end
                    m:SetSize(CT.abilityMark, CT.abilityMark)
                    m.ring:SetSize(CT.abilityMark, CT.abilityMark); tint(m.ring, ABILITY_RING[mk.state] or "classInkFaded")
                    m.icon:SetSize(CT.abilityMark - 4, CT.abilityMark - 4)
                    if first and first.icon then m.icon:SetTexture(first.icon) else tint(m.icon, "classParchment") end
                    if m.icon.SetDesaturated then m.icon:SetDesaturated(mk.state == "later") end
                    m.icon:SetAlpha(mk.state == "later" and 0.6 or 1)
                    m.focusRing:SetSize(CT.abilityMark + 6, CT.abilityMark + 6)
                    m.more:SetText(mk.new > 1 and ("+" .. (mk.new - 1)) or "")
                    m:ClearAllPoints()
                    m:SetPoint("CENTER", map, "TOPLEFT", mx * s, -my * s)
                    m:SetFrameLevel(map:GetFrameLevel() + 6)
                    local names = {}
                    for _, ab in ipairs(mk.abilities) do if ab.new then names[#names + 1] = ab.name end end
                    local level = mk.level
                    m.item = { key = "a:" .. level, frame = m, title = "Level " .. level .. ": " .. table.concat(names, ", "),
                        detail = (ABILITY_STATE[mk.state] or "") .. ". From your class trainer. A lists the level's abilities.",
                        scroll = mscroll, abilityLevel = level, stopKey = "a:" .. level, actionLabel = "Abilities",
                        onActivate = function() page:EnterSteps() end }
                    m.onClick = function() page:SelectStop("a:" .. level, true) end
                    abilityRows[#abilityRows + 1] = { y = my, row = { items = { m.item } } }
                    page.abilityMarks[level] = m
                end
            end
        end
        hideRest("abilities")
        -- Focus rows: one per road stop (its side paths left or right of it by position), then
        -- the end. Each row is its own section (LT/RT stop to stop). Ability marks are rows of
        -- their own in road order between the stops, in the section of the stop before them, so
        -- up/down walks through them and LT/RT skips them.
        local stopRows = {}
        for i, r in ipairs(lay.road) do
            local items = { { item = byKey[r.key].item, x = lay.pos[r.key][1] } }
            for _, sp in ipairs(lay.sides[r.key] or {}) do items[#items + 1] = { item = byKey[sp.key].item, x = lay.pos[sp.key][1] } end
            table.sort(items, function(a, b) return a.x < b.x end)
            local row = { items = {}, section = i }
            for ci, it in ipairs(items) do
                row.items[ci] = it.item
                if it.item.stopKey == r.key then row.home = ci end
            end
            stopRows[#stopRows + 1] = { y = lay.pos[r.key][2], row = row }
        end
        local all = {}
        for _, x in ipairs(stopRows) do all[#all + 1] = x end
        for _, x in ipairs(abilityRows) do all[#all + 1] = x end
        table.sort(all, function(a, b) return a.y < b.y end)
        local section = 1
        for _, x in ipairs(all) do
            if x.row.section then section = x.row.section else x.row.section = section end
            rows[#rows + 1] = x.row
        end
        rows[#rows + 1] = { items = { e.item }, section = #lay.road + 1 }
        page.byKey = byKey
        return rows
    end

    -- The rail ---------------------------------------------------------------------------------
    local RAIL = { -- ring, fill, alpha per state (style.css .crail .rdot)
        done = { "classBeadOn", "complete", 1 }, progress = { "classPeach", "todo", 1 },
        ready = { "classPeach", "cardBg", 1 }, later = { "levelRange", "cardBg", 0.75 },
        unknown = { "untouched", "cardBg", 0.6 },
    }
    local function newMark()
        local f = CreateFrame("Frame", nil, rail.track)
        f.ring = circle(f, "BORDER", 10); f.ring:SetPoint("CENTER")
        f.fill = circle(f, "ARTWORK", 8); f.fill:SetPoint("CENTER")
        return f
    end
    -- Places the marks and the view window for the track's current height.
    local function placeRail()
        local h = rail.track:GetHeight() or 0
        local mapH = map:GetHeight() or 0
        if h <= 1 or mapH <= 1 then return end
        local x0 = CT.railLineX
        for _, m in ipairs(page.railMarks or {}) do
            m.frame:ClearAllPoints()
            m.frame:SetPoint("CENTER", rail.track, "TOP", x0 + (m.dx or 0), -m.frac * h)
        end
        -- The scale bar's level ticks at their places on the road.
        for _, tk in ipairs(rail.ticks) do
            local f = page.tickFracs and page.tickFracs[tk.level]
            tk.tick:SetShown(f ~= nil); tk.label:SetShown(f ~= nil)
            if f then
                tk.tick:ClearAllPoints(); tk.tick:SetPoint("CENTER", rail.track, "TOP", x0, -f * h)
                tk.label:ClearAllPoints(); tk.label:SetPoint("RIGHT", tk.tick, "LEFT", -1, 0)
            end
        end
        local viewH = mscroll:GetHeight() or 0
        local off = mscroll:GetVerticalScroll() or 0
        local from = math.max(0, off / mapH)
        local to = math.min(1, (off + viewH) / mapH)
        rail.view:ClearAllPoints()
        rail.view:SetPoint("TOP", rail.track, "TOP", x0, -from * h)
        rail.view:SetHeight(math.max(6, (to - from) * h))
        -- The gold down to your mark.
        local yf = page.youFrac
        rail.fill:SetShown(yf ~= nil and yf > 0)
        if yf then
            rail.fill:ClearAllPoints()
            rail.fill:SetPoint("TOP", rail.track, "TOP", x0, 0)
            rail.fill:SetHeight(math.max(1, yf * h))
        end
    end
    page.PlaceRail = placeRail
    -- One mark per stop (side paths smaller, set off the line), the road's end, your ring.
    local function drawRail(j, lay)
        local s, mapH = page.scale or 1, map:GetHeight() or 1
        local marks, used = {}, 0
        local function mark(size, ringC, fillC, alpha, frac, dx, level)
            used = used + 1
            local f = rail.dots[used]
            if not f then f = newMark(); rail.dots[used] = f end
            f:SetSize(size, size)
            f.ring:SetSize(size, size); f.fill:SetSize(math.max(2, size - 4), math.max(2, size - 4))
            if ringC then tint(f.ring, ringC) end
            tint(f.fill, fillC)
            f:SetAlpha(alpha or 1)
            f:SetFrameLevel(rail.track:GetFrameLevel() + (level or 2))
            f:Show()
            marks[#marks + 1] = { frame = f, frac = frac, dx = dx }
            return f
        end
        local function frac(y) return math.max(0, math.min(1, y * s / math.max(1, mapH))) end
        -- The scale bar (round 4): its colours on the parchment, and its level ticks.
        tint(rail.bg, page.painted and "classParchment" or "black", page.painted and 0.92 or 0.5)
        tint(rail.line, page.painted and "classInk" or "classRailLine")
        local levels = {}
        for i, r in ipairs(lay.road) do levels[i] = r.level end
        page.tickFracs = {}
        for _, tk in ipairs(rail.ticks) do
            local i, t = ns.ClassJourneyRules.LevelPos(levels, tk.level, 60)
            local seg = i and lay.road[i] and lay.segs[lay.road[i].key]
            if seg then local _, y = bez(seg, t); page.tickFracs[tk.level] = frac(y) end
            tint(tk.tick, page.painted and "classInk" or "classRailLine")
            tk.label:SetTextColor(T.RGB(page.painted and "classInk" or "dim"))
        end
        -- Your mark at your level on the road (as on the map): a brass dot (round 4: no class colour).
        page.youFrac = page.youY and frac(page.youY) or nil
        if page.youY then
            local f = mark(CT.railYou, "classInk", "classNotch", 1, page.youFrac, 0, 1)
            f.fill:SetSize(CT.railYou - 4, CT.railYou - 4)
        end
        for _, st in ipairs(j.stops) do
            local side = lay.from[st.key] ~= nil
            local c = RAIL[st.state or "unknown"] or RAIL.unknown
            local p = lay.pos[st.key]
            mark(side and CT.railSide or CT.railDot, c[1], c[2], c[3], frac(p[2]), side and CT.railSideOff or 0, 2)
        end
        for i = used + 1, #rail.dots do rail.dots[i]:Hide() end
        -- The road's end: a diamond (two unmasked squares turned 45 degrees; Texture:SetRotation
        -- works in this client), gold when walked.
        local walked = j.complete == true
        local e = rail.endMark
        if not e then
            e = CreateFrame("Frame", nil, rail.track)
            e.outer = e:CreateTexture(nil, "BORDER"); e.outer:SetPoint("CENTER")
            e.inner = e:CreateTexture(nil, "ARTWORK"); e.inner:SetPoint("CENTER")
            rail.endMark = e
        end
        local side = CT.railEnd / math.sqrt(2)
        e:SetSize(CT.railEnd, CT.railEnd)
        e.outer:SetSize(side, side); e.inner:SetSize(side - 3, side - 3)
        tint(e.outer, walked and "classBeadOn" or "levelRange"); tint(e.inner, walked and "complete" or "cardBg")
        for _, tex in ipairs({ e.outer, e.inner }) do if tex.SetRotation then tex:SetRotation(math.pi / 4) end end
        e:SetFrameLevel(rail.track:GetFrameLevel() + 2)
        marks[#marks + 1] = { frame = e, frac = frac(lay.endPos[2]) }
        page.railMarks = marks
        placeRail()
    end
    rail:SetScript("OnSizeChanged", function() placeRail() end)
    mscroll:HookScript("OnVerticalScroll", function() placeRail() end)
    -- A click on the rail scrolls the map there.
    rail:EnableMouse(true)
    rail:SetScript("OnMouseDown", function()
        if type(GetCursorPosition) ~= "function" then return end
        local top, h = rail.track:GetTop(), rail.track:GetHeight() or 0
        if not top or h <= 1 then return end
        local _, cy = GetCursorPosition()
        cy = cy / (rail:GetEffectiveScale() or 1)
        local f = math.max(0, math.min(1, (top - cy) / h))
        local mapH, viewH = map:GetHeight() or 0, mscroll:GetHeight() or 0
        local range = mscroll:GetVerticalScrollRange() or 0
        mscroll:SetVerticalScroll(math.max(0, math.min(range, f * mapH - viewH / 2)))
    end)

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
    local function stepRow(y, x, w)
        local row = take("stepRows", newStepRow, dc)
        row:SetPoint("TOPLEFT", dc, "TOPLEFT", x, -y)
        row:SetWidth(w)
        row:SetSelected(false)
        return row
    end
    local function idNote() return "" end
    if debugIds then idNote = function(id) return debugIds() and (" Quest " .. id .. ".") or "" end end

    -- The facts: Where it starts, Level, Travels to. Side by side above the steps, or stacked in
    -- a column beside them in a wide pane. Returns the height they take in the flow (0 stacked).
    local function paintFacts(list, x, y, w, stacked)
        if stacked then
            local fy = y
            for i, f in ipairs(d.facts) do
                f.k:Show(); f.v:Show(); f.k:ClearAllPoints(); f.v:ClearAllPoints()
                f.k:SetPoint("TOPLEFT", dc, "TOPLEFT", x, -fy); f.k:SetText(list[i][1])
                f.v:SetPoint("TOPLEFT", f.k, "BOTTOMLEFT", 0, -2); f.v:SetWidth(w); f.v:SetText(list[i][2])
                f.v:SetTextColor(T.RGB("text"))
                fy = fy + T.size.xs + 2 + math.ceil(f.v:GetStringHeight() or 14) + S.s3
            end
            return 0, fy
        end
        -- (50 / 25 / 25 wrapped "2 levels to go" at minimum size, WoWScrnShot_110926_221345.)
        local c1, c2 = math.floor(w * CT.factCols[1]), math.floor(w * CT.factCols[2])
        local colW = { c1, c2, w - c1 - c2 }
        local fx, fh = x, 0
        for i, f in ipairs(d.facts) do
            f.k:Show(); f.v:Show(); f.k:ClearAllPoints(); f.v:ClearAllPoints()
            f.k:SetPoint("TOPLEFT", dc, "TOPLEFT", fx, -y); f.k:SetText(list[i][1])
            f.v:SetPoint("TOPLEFT", f.k, "BOTTOMLEFT", 0, -2); f.v:SetWidth(colW[i] - S.s3); f.v:SetText(list[i][2])
            f.v:SetTextColor(T.RGB("text"))
            fh = math.max(fh, T.size.xs + 2 + math.ceil(f.v:GetStringHeight() or 14))
            fx = fx + colW[i]
        end
        return fh + S.s4
    end

    -- Fills the right pane for a stop. Returns its focus rows (Start here, then the steps).
    local function fillStop(st, j)
        local rows = {}
        local w = (dscroll:GetWidth() or 0) > 1 and dscroll:GetWidth() or 560
        local x, inner = S.s4, w - S.s4 - S.s6
        local stacked = inner >= CT.wideFacts
        local colW = stacked and CT.stepsWide or inner
        local roadIndex, road = nil, 0
        for _, s in ipairs(j.stops) do
            if s.kind ~= "side" then road = road + 1; if s.key == st.key then roadIndex = road end end
        end
        local fromStop = st.from and stopByKey(st.from)
        local leadins, subs = splitExtras(st)
        local start = stopStarter(st, leadins)
        hero.kicker:SetText(roadIndex and string.format("Stop %d of %d on the road", roadIndex, j.road.count)
            or ("Side path off " .. (fromStop and fromStop.name or "the road")))
        hero.name:SetText(st.name or "")
        hero.name:SetTextColor(T.RGB(st.state == "done" and "classBeadOn" or "gold"))
        hero.sub:SetText("Reward: " .. (st.reward or "not known yet"))
        hero:SetLook(st.state == "done", start and start.mapID, st.state == "later" or st.state == "unknown")
        local lv = charLevel()
        if st.state == "done" then
            hero:SetScore("done")
        elseif st.state == "later" and st.level and lv and st.level > lv then
            hero:SetScore("later", tostring(st.level - lv), st.level - lv == 1 and "level to go" or "levels to go", "dim")
        elseif st.state == "later" and st.level and lv and st.level <= lv then
            -- Level reached, locked by something else (a step before it): say so, not a level
            -- (Simple Parchment read "1 · opens at level" at level 1, WoWScrnShot_111026_173511).
            hero:SetScore("later", tostring(st.done or 0), "of " .. plural(st.count, "quest") .. "  ·  locked", "dim")
        elseif st.state == "later" then
            hero:SetScore("later", tostring(st.level or "?"), "opens at level", "dim")
        elseif st.done == nil then
            hero:SetScore("unknown", "?", "of " .. plural(st.count, "quest") .. ", not known", "dim")
        else
            hero:SetScore("count", tostring(st.done), "of " .. plural(st.count, "quest"))
        end
        -- Facts.
        local y = 0
        local route = travels(st, subs)
        local facts = { { "Where it starts", starterText(start) or "Not known" }, { "Level", tostring(st.level or "?") },
            { "Travels to", #route > 0 and table.concat(route, "  >  ") or "Not known" } }
        if stacked then
            local _, fyEnd = paintFacts(facts, x + colW + S.s6, 0, inner - colW - S.s6, true)
            page.factsBottom = fyEnd
        else
            y = y + paintFacts(facts, x, y, inner, false)
            page.factsBottom = nil
        end
        -- Notes: the route, an inferred order, unknown completion.
        if st.route then
            y = note("Route: " .. st.route .. ". Any one route finishes this stop; this is the one you're furthest along.", y, x, colW, "classPeach")
        end
        if st.order then
            y = note("Order inferred from quest levels: QuestieDB doesn't link these quests.", y, x, colW, "classPeach")
        end
        if st.done == nil then
            y = note("Done or not isn't known: the game hasn't given Azerfolio your completed quests yet.", y, x, colW, "dim")
        end
        local function lvText(id, sub)
            if sub then return "not counted" end
            local r = info(id)
            local req = r and r.reqLevel
            return (req and st.level and req > st.level) and ("from " .. req) or ""
        end
        -- Start here: lead-ins and repeatable-flagged starts (optional, not counted).
        if #leadins > 0 then
            y = header("Start here", "optional  ·  not counted", y, x - S.s2, colW + S.s2)
            for _, ex in ipairs(leadins) do
                local row = stepRow(y, x - S.s2, colW + S.s2)
                local nm = questName(ex.id)
                local where = starterText(starter(ex.id)) or "Starter not known"
                paintStepRow(row, ex.state == "done" and "done" or "lead", nil, nm, where, "not counted")
                row.item = { key = "ex:" .. ex.id, frame = row, title = nm,
                    detail = (ex.state == "done" and "Done. " or "") .. "Optional, not counted: a lead-in or the chain's start. " .. where .. "." .. idNote(ex.id),
                    scroll = dscroll, topGap = L.listHeader + S.s2 }
                rows[#rows + 1] = { items = { row.item }, section = 1 }
                y = y + CT.stepRow + 2
            end
            y = y + S.s2
        end
        -- Steps: numbered; quests sharing a name lead with who and where; sub-quests in place.
        local kinds = stepKinds(st)
        local names, total = {}, {}
        for k, step in ipairs(st.steps) do local nm = questName(step.id); names[k] = nm; total[nm] = (total[nm] or 0) + 1 end
        y = header("Steps", st.done and (st.done .. " of " .. st.count .. " done") or (st.count .. " steps"), y, x - S.s2, colW + S.s2)
        for k, step in ipairs(st.steps) do
            local nm = names[k]
            local sw = starter(step.id)
            local where = starterText(sw) or "Starter not known"
            local main, second = nm, where
            if total[nm] > 1 then main, second = cap(where), nm end
            local row = stepRow(y, x - S.s2, colW + S.s2)
            local kind = kinds[k]
            paintStepRow(row, kind, kind == "unknown" and "?" or tostring(k), main, second, lvText(step.id))
            local state = kind == "done" and "Done." or kind == "next" and "Your next step." or kind == "after" and "You can do it now."
                or kind == "later" and ("Later: " .. (whyText(step.reason) or "locked") .. ".")
                or ("Done or not isn't known" .. (step.reason and (" (" .. whyText(step.reason) .. ")") or "") .. ".")
            row.item = { key = "st:" .. k .. ":" .. step.id, frame = row, title = string.format("%d. %s", k, nm),
                detail = state .. " " .. where .. "." .. idNote(step.id), scroll = dscroll, topGap = L.listHeader + S.s2,
                next = kind == "next" }
            rows[#rows + 1] = { items = { row.item }, section = 2 }
            y = y + CT.stepRow + 2
            for _, ex in ipairs(subs[k] or {}) do
                local srow = stepRow(y, x - S.s2, colW + S.s2)
                local snm = questName(ex.id)
                local swhere = starterText(starter(ex.id)) or "Starter not known"
                paintStepRow(srow, ex.state == "done" and "done" or "sub", nil, snm, swhere, lvText(ex.id, true))
                srow.item = { key = "sub:" .. ex.id, frame = srow, title = snm,
                    detail = (ex.state == "done" and "Done. " or "") .. "Part of step " .. k .. "; not counted (QuestieDB flags it repeatable). "
                        .. swhere .. "." .. idNote(ex.id), scroll = dscroll, topGap = L.listHeader + S.s2 }
                rows[#rows + 1] = { items = { srow.item }, section = 2 }
                y = y + CT.stepRow + 2
            end
        end
        d.bar:Hide()
        y = y + S.s3
        d.foot:ClearAllPoints()
        d.foot:SetPoint("TOPLEFT", dc, "TOPLEFT", x, -y)
        d.foot:SetWidth(colW)
        d.foot:SetText("Steps from the curated journey and QuestieDB; done or not is read from the game.")
        d.foot:Show()
        y = y + math.ceil(d.foot:GetStringHeight() or 14) + S.s4
        dc:SetHeight(math.max(1, y, page.factsBottom or 0))
        page.hasLeadins = #leadins > 0
        return rows
    end

    -- The road's end: the whole road, every stop with n / m. Rows go to the stop on the road.
    local function fillEnd(j)
        local rows = {}
        local w = (dscroll:GetWidth() or 0) > 1 and dscroll:GetWidth() or 560
        local x, inner = S.s4, w - S.s4 - S.s6
        local colW = inner >= CT.wideFacts and CT.stepsWide or inner
        local c = ns.character or {}
        local walked = j.complete == true
        hero.kicker:SetText((c.className or "") .. ((c.className and c.race) and "  ·  " or "") .. (c.race or ""))
        hero.name:SetText(walked and ((j.title or "The road") .. ", walked") or (j.title or "The road"))
        hero.name:SetTextColor(T.RGB(walked and "classBeadOn" or "gold"))
        hero.sub:SetText(walked and "Every class quest you can do is done" or "Every class quest you can do, stop by stop")
        local first = j.stops[1]
        local fs = first and stopStarter(first, (splitExtras(first)))
        hero:SetLook(walked, fs and fs.mapID, false)
        if walked then hero:SetScore("done")
        elseif j.complete == nil then hero:SetScore("unknown", "?", "of " .. j.quests.count .. " quests, not known", "dim")
        else hero:SetScore("count", tostring(j.quests.done), "of " .. j.quests.count .. " quests") end
        for _, f in ipairs(d.facts) do f.k:Hide(); f.v:Hide() end
        page.factsBottom = nil
        local y = 0
        d.bar:ClearAllPoints()
        d.bar:SetPoint("TOPLEFT", dc, "TOPLEFT", x, -y)
        d.bar:SetWidth(colW)
        d.bar:Show()
        d.bar:Set(j.complete ~= nil and j.quests.count > 0 and j.quests.done / j.quests.count or 0, walked and "complete" or nil)
        y = y + CT.bar + S.s4
        if j.complete == nil then
            y = note("Done or not isn't known: the game hasn't given Azerfolio your completed quests yet.", y, x, colW, "dim")
        end
        local here = j.next and j.next.stop and j.next.stop.key
        local function stopRows(kind, title)
            local list = {}
            for _, s in ipairs(j.stops) do if (kind == "side") == (s.kind == "side") then list[#list + 1] = s end end
            if #list == 0 then return end
            local grp = kind == "side" and j.side or j.road
            local count = (j.complete == nil and "?" or grp.done) .. " of " .. grp.count .. (kind == "side" and "  ·  optional, but they count" or " stops")
            y = header(title, count, y, x - S.s2, colW + S.s2)
            for _, s in ipairs(list) do
                local row = stepRow(y, x - S.s2, colW + S.s2)
                local k = s.state == "done" and "done" or s.state == "progress" and "progress" or s.state == "later" and "later"
                    or s.state == "unknown" and "unknown" or "after"
                local name = s.name .. (s.key == here and ("  " .. T.Hex("classPeach", "· You are here")) or "")
                paintStepRow(row, k, k == "unknown" and "?" or nil, name, "Level " .. tostring(s.level or "?") .. "  ·  " .. (s.reward or "reward not known yet"),
                    (s.done and s.done or "?") .. " / " .. s.count)
                local key = s.key
                row.item = { key = "go:" .. key, frame = row, title = s.name, detail = stopInfo(s, "A goes to it on the road."),
                    scroll = dscroll, topGap = L.listHeader + S.s2, actionLabel = "Go to",
                    onActivate = function() page:FocusStop(key) end }
                rows[#rows + 1] = { items = { row.item } }
                y = y + CT.stopRow + 2
            end
            y = y + S.s2
        end
        stopRows("road", "The road")
        stopRows("side", "Side paths")
        -- Round 4: your abilities, from your class trainer's list (or why they're missing).
        local tr = page.trainer or { status = "none" }
        if tr.status == "recorded" then
            local cn = tr.abilities.counts
            y = note(string.format("Abilities from your class trainer: %d learned, %d to train now, %d later. They're marked along the road.",
                cn.learned, cn.available, cn.later), y, x, colW, cn.available > 0 and "classPeach" or "text")
        else
            y = note("Abilities: open your class trainer once and Azerfolio adds them along the road.", y, x, colW, "dim")
        end
        for _, n in ipairs(j.notes or {}) do y = note(n, y, x, colW, "dim") end
        d.foot:ClearAllPoints()
        d.foot:SetPoint("TOPLEFT", dc, "TOPLEFT", x, -y)
        d.foot:SetWidth(colW)
        d.foot:SetText("Raid and dungeon class quests aren't on the road: they belong to a later Dungeons tab. "
            .. "Another race's version of a stop, and repeatable turn-ins, never count.")
        d.foot:Show()
        y = y + math.ceil(d.foot:GetStringHeight() or 14) + S.s4
        dc:SetHeight(math.max(1, y))
        page.hasLeadins = false
        return rows
    end

    -- A level's abilities (round 4): what your class trainer lists at that level, new ones first.
    local function money(c)
        if type(c) ~= "number" or c <= 0 then return nil end
        local g, sv, cu = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
        local parts = {}
        if g > 0 then parts[#parts + 1] = g .. "g" end
        if sv > 0 then parts[#parts + 1] = sv .. "s" end
        if cu > 0 then parts[#parts + 1] = cu .. "c" end
        return table.concat(parts, " ")
    end
    local function fillAbilities(level)
        local rows = {}
        local w = (dscroll:GetWidth() or 0) > 1 and dscroll:GetWidth() or 560
        local x, inner = S.s4, w - S.s4 - S.s6
        local colW = inner >= CT.wideFacts and CT.stepsWide or inner
        local tr = page.trainer or {}
        local L
        for _, lv in ipairs(tr.abilities and tr.abilities.levels or {}) do if lv.level == level then L = lv end end
        for _, f in ipairs(d.facts) do f.k:Hide(); f.v:Hide() end
        d.bar:Hide()
        page.factsBottom = nil
        local nNew, nRank, nAvail = 0, 0, 0
        for _, ab in ipairs(L and L.abilities or {}) do
            if ab.new then nNew = nNew + 1 else nRank = nRank + 1 end
            if ab.state == "available" then nAvail = nAvail + 1 end
        end
        hero.kicker:SetText("Your class trainer")
        hero.name:SetText("Level " .. level)
        hero.name:SetTextColor(T.RGB("gold"))
        hero.sub:SetText(plural(nNew, "new ability") .. (nRank > 0 and ("  ·  " .. plural(nRank, "new rank")) or ""))
        hero:SetLook(false, nil, false)
        local lv = charLevel()
        if nAvail > 0 then hero:SetScore("count", tostring(nAvail), "to train now")
        elseif lv and level > lv then hero:SetScore("later", tostring(level - lv), level - lv == 1 and "level to go" or "levels to go", "dim")
        else hero:SetScore("count", tostring(#(L and L.abilities or {})), "learned", "dim") end
        local y = 0
        y = header("Abilities", plural(#(L and L.abilities or {}), "ability"), y, x - S.s2, colW + S.s2)
        for k, ab in ipairs(L and L.abilities or {}) do
            local row = stepRow(y, x - S.s2, colW + S.s2)
            local kind = ab.state == "learned" and "done" or ab.state == "available" and "next" or "later"
            local sub = (ab.rank or "") .. (ab.new and ((ab.rank and "  ·  " or "") .. "new") or "")
            local cost = money(ab.cost)
            if cost then sub = sub .. (sub ~= "" and "  ·  " or "") .. cost end
            paintStepRow(row, kind, nil, ab.name, sub, "Lv " .. level)
            row.item = { key = "ab:" .. level .. ":" .. k, frame = row, title = ab.name .. (ab.rank and ("  ·  " .. ab.rank) or ""),
                detail = (ABILITY_STATE[ab.state] or "") .. ". " .. (ab.new and "A new ability." or "A new rank.")
                    .. (cost and (" Costs " .. cost .. ".") or ""), scroll = dscroll, topGap = L and L.level and (S.s2 + 30) or 30 }
            rows[#rows + 1] = { items = { row.item } }
            y = y + CT.stepRow + 2
        end
        y = y + S.s3
        d.foot:ClearAllPoints()
        d.foot:SetPoint("TOPLEFT", dc, "TOPLEFT", x, -y)
        d.foot:SetWidth(colW)
        local when = tr.time and type(date) == "function" and date("%d %b", tr.time)
        d.foot:SetText("From your class trainer's list" .. (when and (", read " .. when) or "") .. "; open your trainer again to update it. "
            .. "Abilities a quest teaches (Redemption, the warhorse) aren't on it: they're stops on the road.")
        d.foot:Show()
        y = y + math.ceil(d.foot:GetStringHeight() or 14) + S.s4
        dc:SetHeight(math.max(1, y))
        page.hasLeadins = false
        return rows
    end

    -- The right pane for the selected stop.
    local function fillDetail()
        page.used.stepRows, page.used.headers, page.used.notes = 0, 0, 0
        local j = page.journey
        local rows = {}
        if j then
            local abLevel = type(page.sel) == "string" and tonumber(page.sel:match("^a:(%d+)$"))
            local st = not abLevel and page.sel ~= "end" and stopByKey(page.sel)
            if abLevel then rows = fillAbilities(abLevel)
            elseif st then rows = fillStop(st, j) else rows = fillEnd(j) end
        end
        hideRest("stepRows"); hideRest("headers"); hideRest("notes")
        page.detailRows = rows
        return rows
    end

    -- Redraws everything from ns.ClassJourney.Get(). Keeps the selection and focus.
    function page:Redraw()
        local g = ns.ClassJourney.Get()
        self.status = g.status
        self.used = { dots = 0, edges = 0, beads = 0, cairns = 0, nodes = 0, abilities = 0, stepRows = 0, headers = 0, notes = 0 }
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
        -- Round 4: abilities waiting at your trainer (from its recorded list).
        local tr = ns.ClassTrainer and ns.ClassTrainer.Get() or { status = "none" }
        if tr.status == "recorded" and tr.abilities.counts.available > 0 then
            count = count .. "  ·  " .. T.Hex("classRedInkLight", tr.abilities.counts.available .. " to train")
        end
        plaque.count:SetText(count)
        local nt, nc = nextLine(j)
        plaque.next:SetText(nt)
        plaque.next:SetTextColor(T.RGB(nc))
        self.drawnWidth = mscroll:GetWidth() or 0
        self.roadRows = drawMap(j, self.layout)
        drawRail(j, self.layout)
        -- Selection: kept if the stop (or ability mark) is still there; else your current stop.
        local abSel = type(self.sel) == "string" and tonumber(self.sel:match("^a:(%d+)$")) or nil
        if abSel and not (self.abilityMarks and self.abilityMarks[abSel]) then self.sel, abSel = nil, nil end
        local valid = self.sel == "end" or abSel ~= nil or (self.sel ~= nil and stopByKey(self.sel) ~= nil)
        if not valid then
            self.sel = (j.next and j.next.stop and j.next.stop.key) or "end"
            if self.pendingFocusKey == nil then self.pendingFocusKey = "n:" .. self.sel end
        end
        -- Redrawn while another tab shows (a level or XP change): focus the selected stop when
        -- this tab opens, not the first item.
        if self.pendingFocusKey == nil and ns.UI.CurrentTab() ~= "class" then
            self.pendingFocusKey = (self.sel and self.sel:match("^a:")) and self.sel or ("n:" .. (self.sel or "end"))
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
        for level, m in pairs(self.abilityMarks or {}) do m:SetSelected(self.sel == "a:" .. level) end
    end

    function page:Refresh()
        if self.mode == "steps" then
            -- LT/RT between Start here and Steps (round 2).
            self.hasSections = self.hasLeadins == true
            self.sectionLabel = "Section"
        else
            self.hasSections = #(self.roadRows or {}) > 1
            self.sectionLabel = "Stop"
        end
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
            self.pendingFocusKey = key:match("^a:") and key or ("n:" .. key)
            self:Refresh()
        end
    end

    -- To a stop on the road (from the road's end list, or /azf shots).
    function page:FocusStop(key) self:SelectStop(key, true) end

    -- Your level with the XP fraction (10.04), from the game; nil when the level isn't known.
    function page:LevelNow()
        local c = ns.character or {}
        if type(c.level) ~= "number" then return nil end
        local frac = 0
        if type(c.xp) == "number" and type(c.xpMax) == "number" and c.xpMax > 0 then frac = math.min(0.999, c.xp / c.xpMax) end
        return c.level + frac
    end

    function page:CurrentStopKey()
        local n = self.journey and self.journey.next
        return n and n.stop and n.stop.key or "end"
    end

    -- A: into the selected stop's steps (your next step first, else the first step).
    function page:EnterSteps()
        if not self.detailRows or #self.detailRows == 0 then return end
        self.mode = "steps"
        local pick
        for _, r in ipairs(self.detailRows) do
            local it = r.items[1]
            if it.next then pick = it.key; break end
            if not pick and r.section == 2 then pick = it.key end
        end
        self.pendingFocusKey = pick or self.detailRows[1].items[1].key
        self:Refresh()
    end

    function page:OnFocusChanged(item)
        if self.mode == "road" and item and item.stopKey and item.stopKey ~= self.sel then
            self:SelectStop(item.stopKey, false)
        end
        -- The road's end: all the way down, so its label shows too.
        if item and item.stopKey == "end" then mscroll:SetVerticalScroll(mscroll:GetVerticalScrollRange() or 0) end
    end

    -- The legend: "Side path" while the focused stop has one (or is one), round 2.
    function page:GetHints()
        local item = ns.Focus.Current()
        if self.mode == "road" and item and item.sidePath then return { { "D", "Side path" } } end
        return {}
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

    -- Your level and XP move You and the fill (round 4: also which abilities are trainable).
    ns.Events.On("AZF_CHARACTER_UPDATED", function()
        if not page:IsShown() then page.dirty = true; return end
        local cur = ns.UI.CurrentTab() == "class" and ns.Focus.Current()
        if cur and page.pendingFocusKey == nil then page.pendingFocusKey = cur.key end
        page:Redraw()
    end)
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

ns.ClassPage = { PushApart = pushApart } -- for tests

ns.UI.RegisterTab({
    id = "class",
    label = "Class",
    icon = ns.Theme.Icon("class", "Interface\\Icons\\INV_Misc_Book_09"),
    order = 4,
    info = "Your class quests: the road, its side paths, and each stop's steps.",
    build = build,
})
