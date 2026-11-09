-- Small UI pieces shared by pages: scroll area, group header, focusable row, toolbar control,
-- pips and level bar. They draw what they're given and never compute progress.
-- Nothing touches the client at load time.
local _, ns = ...

local W = {}
ns.Widgets = W

local WHEEL_STEP = 72

-- A vertical scroll area whose child is as wide as the area. Moving it redraws the focus.
function W.Scroll(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    scroll:SetScript("OnSizeChanged", function(self, w)
        child:SetWidth(w)
        if self.onWidth then self.onWidth(w) end
    end)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local new = self:GetVerticalScroll() - delta * WHEEL_STEP
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange() or 0, new)))
    end)
    scroll:SetScript("OnVerticalScroll", function() ns.Focus.Update(false) end)
    scroll.child = child
    return scroll
end

-- Native group header (common-button-list-collapseExpand): gold title left, count right.
function W.Header(parent)
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

-- The info line while the mouse is over a focusable frame (its item's title and detail).
local function hoverInfo(f)
    f:SetScript("OnEnter", function(self) if self.item then ns.UI.SetInfo(self.item.title, self.item.detail) end end)
    f:SetScript("OnLeave", function() ns.UI.RestoreInfo() end)
end
W.HoverInfo = hoverInfo

-- A focusable row with the native highlight (hover and controller focus). The bar shows while
-- the row is focused or selected (the zone the split view shows).
function W.FocusRow(parent, height)
    local T = ns.Theme
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(height)
    T.RowHighlight(row, "HIGHLIGHT")
    local focusHi = T.RowHighlight(row)
    focusHi:SetShown(false)
    function row:SetFocused(on) self.focused = on; focusHi:SetShown(on or self.selected) end
    function row:SetSelected(on) self.selected = on; focusHi:SetShown(on or self.focused) end
    hoverInfo(row)
    return row
end

-- A 1 px frame of four solid edges; :SetColor(name[, alpha]) and :SetThickness(px).
function W.Edge(frame, layer)
    local e = {}
    for i = 1, 4 do e[i] = frame:CreateTexture(nil, layer or "BORDER") end
    local top, bottom, left, right = e[1], e[2], e[3], e[4]
    top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT")
    bottom:SetPoint("BOTTOMLEFT"); bottom:SetPoint("BOTTOMRIGHT")
    left:SetPoint("TOPLEFT"); left:SetPoint("BOTTOMLEFT")
    right:SetPoint("TOPRIGHT"); right:SetPoint("BOTTOMRIGHT")
    function e:SetColor(name, alpha)
        local r, g, b = ns.Theme.RGB(name)
        for i = 1, 4 do self[i]:SetColorTexture(r, g, b, alpha or 1) end
    end
    function e:SetThickness(px)
        top:SetHeight(px); bottom:SetHeight(px); left:SetWidth(px); right:SetWidth(px)
    end
    e:SetThickness(1)
    return e
end

-- A toolbar control: dark box, text, native highlight on hover and focus. :SetOn(on) marks a
-- selected segment. :SetLabel(text) sizes it to the text.
function W.Control(parent)
    local T, L = ns.Theme, ns.Theme.layout
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(L.controlHeight)
    b.bg = T.Solid(b, "ctlBg", "BACKGROUND")
    b.bg:SetAllPoints()
    b.edge = W.Edge(b, "BORDER")
    b.edge:SetColor("ctlEdge")
    b.text = T.Text(b, "sm", "text")
    b.text:SetPoint("CENTER", 0, 0)
    T.RowHighlight(b, "HIGHLIGHT")
    local focusHi = T.RowHighlight(b, "ARTWORK")
    focusHi:SetShown(false)
    function b:SetFocused(on) self.focused = on; focusHi:SetShown(on) end
    function b:SetOn(on)
        self.on = on
        local r, g, bl = T.RGB(on and "ctlOn" or "ctlBg")
        self.bg:SetColorTexture(r, g, bl, 1)
        self.text:SetTextColor(T.RGB(on and "gold" or "text"))
    end
    function b:SetLabel(text, pad)
        self.text:SetText(text)
        self:SetWidth(math.floor((self.text:GetStringWidth() or 0) + 2 * (pad or L.controlPad) + 0.5))
    end
    hoverInfo(b)
    return b
end

-- One dot per objective: confirmed done (gold) first, then not done (grey), then unknown
-- (faint). :Set(done, todo, unknown, maxWidth) shrinks the dots to fit maxWidth.
-- Returns the width used.
function W.Pips(parent)
    local T, L = ns.Theme, ns.Theme.layout
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(1, L.pip)
    f.dots = {}
    function f:Set(done, todo, unknown, maxWidth)
        done, todo, unknown = done or 0, todo or 0, unknown or 0
        local n = done + todo + unknown
        local size, gap = L.pip, L.pipGap
        if n > 0 and maxWidth and n * (size + gap) - gap > maxWidth then
            size = math.max(4, math.floor((maxWidth + gap) / n - gap))
            if size < 6 then gap = 2 end
        end
        for i = 1, n do
            local d = self.dots[i]
            if not d then
                d = { tex = self:CreateTexture(nil, "ARTWORK") }
                local mask = self:CreateMaskTexture()
                if mask then
                    mask:SetAllPoints(d.tex)
                    mask:SetTexture(T.circleMask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                    pcall(d.tex.AddMaskTexture, d.tex, mask)
                end
                self.dots[i] = d
            end
            d.tex:ClearAllPoints()
            d.tex:SetSize(size, size)
            d.tex:SetPoint("LEFT", self, "LEFT", (i - 1) * (size + gap), 0)
            local color, alpha = "complete", 1
            if i > done + todo then color, alpha = "untouched", 0.35
            elseif i > done then color = "untouched" end
            local r, g, b = T.RGB(color)
            d.tex:SetColorTexture(r, g, b, alpha)
            d.tex:Show()
        end
        for i = n + 1, #self.dots do self.dots[i].tex:Hide() end
        local width = n > 0 and n * (size + gap) - gap or 1
        self:SetSize(width, L.pip)
        return width
    end
    return f
end

-- One thin bar per zone category (spec §7.7) in fixed slots (Theme.categoryOrder), so columns
-- line up; a category that doesn't apply leaves its slot empty, a pending one shows "?".
-- :Set(cats, width, horizontal) with cats = a Zones entry's `cats` (from Progression.Combine).
function W.CatBars(parent)
    local T, L = ns.Theme, ns.Theme.layout
    local f = CreateFrame("Frame", nil, parent)
    f.slots = {}
    for i, key in ipairs(T.categoryOrder) do
        local s = CreateFrame("Frame", nil, f)
        s:SetHeight(L.catSlot)
        s.icon = s:CreateTexture(nil, "ARTWORK")
        s.icon:SetSize(L.catIcon, L.catIcon)
        s.icon:SetPoint("LEFT", 0, 0)
        s.icon:SetTexture(T.category[key].icon)
        s.count = T.Text(s, "xs", "dim")
        s.count:SetPoint("RIGHT", 0, 0)
        s.count:SetWidth(L.catCount); s.count:SetJustifyH("RIGHT"); s.count:SetWordWrap(false)
        s.well = T.Solid(s, "well", "BORDER")
        s.well:SetPoint("LEFT", s.icon, "RIGHT", 6, 0)
        s.well:SetPoint("RIGHT", s.count, "LEFT", -6, 0)
        s.well:SetHeight(L.catBar)
        s.fill = T.Solid(s, "todo", "ARTWORK")
        s.fill:SetPoint("TOPLEFT", s.well, "TOPLEFT")
        s.fill:SetHeight(L.catBar)
        s.key = key
        f.slots[i] = s
    end
    function f:Set(cats, width, horizontal)
        local by = {}
        for _, c in ipairs(cats or {}) do by[c.key] = c end
        local n = #self.slots
        local slotW = horizontal and math.floor((width - (n - 1) * 12) / n) or width
        for i, s in ipairs(self.slots) do
            s:ClearAllPoints()
            if horizontal then
                s:SetPoint("LEFT", self, "LEFT", (i - 1) * (slotW + 12), 0)
            else
                s:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -(i - 1) * (L.catSlot + L.catGap))
            end
            s:SetWidth(slotW)
            -- Side by side (list rows) the count gets just its text's room, so the bar keeps some.
            local countW = horizontal and 50 or L.catCount -- 40 cut "42/68" short in the split view
            s.count:SetWidth(countW)
            local c = by[s.key]
            s:SetShown(c ~= nil)
            if c then
                local wellW = math.max(1, slotW - L.catIcon - 12 - countW)
                s.well:SetShown(wellW >= 16) -- too narrow for a readable bar: the count says it
                if c.pending then
                    s.fill:Hide()
                    s.count:SetText("?")
                    if s.icon.SetDesaturated then s.icon:SetDesaturated(true) end
                    s.icon:SetAlpha(0.5)
                else
                    local frac = c.denominator > 0 and c.completed / c.denominator or 0
                    s.fill:SetWidth(math.max(0.001, wellW * frac))
                    s.fill:SetShown(frac > 0 and wellW >= 16)
                    local gold = T.Chrome("bar-fill")
                    if gold then -- the painted molten gold (round 2), amber while in progress
                        s.fill:SetTexture(gold); s.fill:SetTexCoord(0, math.max(0.001, frac), 0, 1)
                        if c.state == "complete" then s.fill:SetVertexColor(1, 1, 1) else s.fill:SetVertexColor(1, 0.72, 0.42) end
                    else
                        local r, g, b = T.RGB(c.state == "complete" and "complete" or "todo")
                        s.fill:SetColorTexture(r, g, b, 1)
                    end
                    s.count:SetText(c.completed .. "/" .. c.denominator)
                    s.count:SetTextColor(T.RGB(c.state == "complete" and "complete" or "dim"))
                    if s.icon.SetDesaturated then s.icon:SetDesaturated(c.state == "untouched") end
                    s.icon:SetAlpha(c.state == "untouched" and 0.6 or 1)
                end
            end
        end
        local h = horizontal and L.catSlot or (n * L.catSlot + (n - 1) * L.catGap)
        self:SetSize(width, h)
    end
    return f
end

-- "35,500": a whole number with thousands separators.
function W.Number(n)
    if type(n) ~= "number" then return "?" end
    local s = tostring(math.floor(math.abs(n) + 0.5))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return (n < 0 and "-" or "") .. out
end

-- The notched reputation bar (mockups/DESIGN.md "Reputation bar", round 3; replaced the
-- eight-step ladder, owner 2026-11-08): one gilded bar (frame-bar housing) across the whole
-- reaction range, each reaction an equal eighth. The fill runs through each reaction's colour
-- (bar-fill-white tinted) up to your standing; a notch with gold diamond caps marks each
-- reaction change (passed gold, the next one lit, later ones bronze); a bright marker with a
-- glow in the current colour sits at your position. :Set(f, width, height) with f a
-- ns.Reputation faction.
function W.RepBar(parent)
    local T = ns.Theme
    local B = T.layout.rep.bar
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(T.layout.rep.ladder, B.height)
    local file, slice = T.Chrome("frame-bar")
    local fillFile = T.Chrome("bar-fill-white")
    -- The well: inside the housing's drawn border.
    f.inner = CreateFrame("Frame", nil, f)
    f.inner:SetPoint("TOPLEFT", B.edgeX, -B.edgeY)
    f.inner:SetPoint("BOTTOMRIGHT", -B.edgeX, B.edgeY)
    f.well = f:CreateTexture(nil, "BACKGROUND")
    f.well:SetPoint("TOPLEFT", f.inner, "TOPLEFT", -1, 1)
    f.well:SetPoint("BOTTOMRIGHT", f.inner, "BOTTOMRIGHT", 1, -1)
    f.well:SetColorTexture(0.055, 0.027, 0.004, 1)
    f.segs = {}
    for r = 1, 8 do
        local t = f:CreateTexture(nil, "BORDER")
        if fillFile then t:SetTexture(fillFile) else t:SetTexture(T.files.white) end
        f.segs[r] = t
    end
    if file and type(slice) == "table" then
        local sx = slice.x
        local l, m, r = f:CreateTexture(nil, "ARTWORK"), f:CreateTexture(nil, "ARTWORK"), f:CreateTexture(nil, "ARTWORK")
        for _, t in ipairs({ l, m, r }) do t:SetTexture(file) end
        l:SetTexCoord(0, sx, 0, 1); m:SetTexCoord(sx, 1 - sx, 0, 1); r:SetTexCoord(1 - sx, 1, 0, 1)
        l:SetPoint("TOPLEFT"); l:SetPoint("BOTTOMLEFT"); l:SetWidth(B.edgeX)
        r:SetPoint("TOPRIGHT"); r:SetPoint("BOTTOMRIGHT"); r:SetWidth(B.edgeX)
        m:SetPoint("TOPLEFT", l, "TOPRIGHT"); m:SetPoint("BOTTOMRIGHT", r, "BOTTOMLEFT")
    else
        f.edge = W.Edge(f, "ARTWORK")
        f.edge:SetColor("cardEdge")
    end
    -- Notches above the housing: a dark outline, the gold line, a diamond cap at each end.
    -- Diamonds are squares turned 45° (Texture:SetRotation, pcall'd); without it, squares.
    local over = CreateFrame("Frame", nil, f)
    over:SetAllPoints()
    f.notches = {}
    for i = 1, 7 do
        local n = {}
        n.shade = over:CreateTexture(nil, "ARTWORK", nil, 1)
        n.shade:SetColorTexture(0, 0, 0, 0.55)
        n.line = over:CreateTexture(nil, "ARTWORK", nil, 2)
        n.line:SetTexture(T.files.white)
        n.caps = {}
        for c = 1, 2 do
            local cap = over:CreateTexture(nil, "ARTWORK", nil, 3)
            cap:SetTexture(T.files.white)
            cap:SetSize(B.cap, B.cap)
            if cap.SetRotation then pcall(cap.SetRotation, cap, math.pi / 4) end
            n.caps[c] = cap
        end
        f.notches[i] = n
    end
    -- The marker: a dark outline, a white bar, a glow fading out on both sides.
    f.glow = { over:CreateTexture(nil, "ARTWORK", nil, 4), over:CreateTexture(nil, "ARTWORK", nil, 4) }
    for _, g in ipairs(f.glow) do g:SetTexture(T.files.white); g:SetWidth(B.glow) end
    f.markShade = over:CreateTexture(nil, "ARTWORK", nil, 5)
    f.markShade:SetColorTexture(0, 0, 0, 0.7)
    f.mark = over:CreateTexture(nil, "ARTWORK", nil, 6)
    f.mark:SetColorTexture(1, 1, 1, 1)

    function f:Set(fac, width, height)
        width, height = width or T.layout.rep.ladder, height or B.height
        self:SetSize(width, height)
        local innerW = width - 2 * B.edgeX
        local innerH = height - 2 * B.edgeY
        local seg = innerW / 8
        local reaction = fac and fac.reaction or 0
        local into = 0
        if fac and fac.maxed then into = 1
        elseif fac and fac.into and fac.span and fac.span > 0 then into = fac.into / fac.span end
        local alpha = (fac and fac.met == false) and T.reaction.unmetFill or 1
        for r, t in ipairs(self.segs) do
            local frac = r < reaction and 1 or (r == reaction and into or 0)
            local c = T.reaction.fill[r]
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", self.inner, "TOPLEFT", (r - 1) * seg, 0)
            t:SetSize(math.max(0.001, seg * frac), innerH)
            t:SetTexCoord(0, math.max(0.001, frac), 0, 1)
            t:SetVertexColor(c[1], c[2], c[3])
            t:SetAlpha(alpha)
            t:SetShown(frac > 0)
        end
        for i, n in ipairs(self.notches) do
            local x = i * seg -- the boundary into reaction i + 1
            local col = (i + 1 == reaction + 1 and B.notchNext) or (i + 1 <= reaction and B.notchPast) or B.notchAhead
            n.state = (i + 1 == reaction + 1 and "next") or (i + 1 <= reaction and "past") or "ahead"
            n.line:ClearAllPoints()
            n.line:SetPoint("TOP", self.inner, "TOPLEFT", x, B.notchOut)
            n.line:SetSize(B.notch, innerH + 2 * B.notchOut)
            n.line:SetVertexColor(col[1], col[2], col[3])
            n.shade:ClearAllPoints()
            n.shade:SetPoint("TOPLEFT", n.line, "TOPLEFT", -1, 1)
            n.shade:SetPoint("BOTTOMRIGHT", n.line, "BOTTOMRIGHT", 1, -1)
            n.caps[1]:ClearAllPoints(); n.caps[1]:SetPoint("CENTER", n.line, "TOP", 0, 0)
            n.caps[2]:ClearAllPoints(); n.caps[2]:SetPoint("CENTER", n.line, "BOTTOM", 0, 0)
            for _, cap in ipairs(n.caps) do cap:SetVertexColor(col[1], col[2], col[3]) end
        end
        local shown = reaction >= 1
        local pos = shown and ((reaction - 1) + into) * seg or 0
        local c = T.reaction.fill[reaction] or T.color.white
        self.mark:ClearAllPoints()
        self.mark:SetPoint("TOP", self.inner, "TOPLEFT", pos, B.markOut)
        self.mark:SetSize(B.mark, innerH + 2 * B.markOut)
        self.markShade:ClearAllPoints()
        self.markShade:SetPoint("TOPLEFT", self.mark, "TOPLEFT", -1, 1)
        self.markShade:SetPoint("BOTTOMRIGHT", self.mark, "BOTTOMRIGHT", 1, -1)
        local left, right = self.glow[1], self.glow[2]
        left:ClearAllPoints(); right:ClearAllPoints()
        left:SetPoint("TOPRIGHT", self.mark, "TOPLEFT"); left:SetPoint("BOTTOMRIGHT", self.mark, "BOTTOMLEFT")
        right:SetPoint("TOPLEFT", self.mark, "TOPRIGHT"); right:SetPoint("BOTTOMLEFT", self.mark, "BOTTOMRIGHT")
        local a = 0.6 * alpha
        local okL = type(CreateColor) == "function" and pcall(left.SetGradient, left, "HORIZONTAL",
            CreateColor(c[1], c[2], c[3], 0), CreateColor(c[1], c[2], c[3], a))
        local okR = type(CreateColor) == "function" and pcall(right.SetGradient, right, "HORIZONTAL",
            CreateColor(c[1], c[2], c[3], a), CreateColor(c[1], c[2], c[3], 0))
        if not okL then left:SetColorTexture(c[1], c[2], c[3], a * 0.4) end
        if not okR then right:SetColorTexture(c[1], c[2], c[3], a * 0.4) end
        for _, t in ipairs({ self.mark, self.markShade, left, right }) do t:SetShown(shown) end
        self.pos = pos
    end
    return f
end

-- A zone's level range on the 1..maxLevel scale, with the player's level marked; green when
-- it fits. :Set(minLevel, maxLevel, playerLevel, fits) (nil range = empty well).
function W.LevelBar(parent)
    local T, L = ns.Theme, ns.Theme.layout
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(L.levelBarWidth, L.levelBarHeight)
    f.bg = T.Solid(f, "levelBg", "BACKGROUND")
    f.bg:SetAllPoints()
    f.range = T.Solid(f, "levelRange", "BORDER")
    f.me = T.Solid(f, "white", "ARTWORK")
    f.me:SetSize(3, L.levelBarHeight + 6)
    local function x(level) return (level - 1) / (L.maxLevel - 1) * L.levelBarWidth end
    function f:Set(lo, hi, level, fits)
        if type(lo) == "number" and type(hi) == "number" then
            self.range:ClearAllPoints()
            self.range:SetPoint("TOPLEFT", self, "TOPLEFT", x(lo), 0)
            self.range:SetSize(math.max(3, x(hi) - x(lo)), L.levelBarHeight)
            local r, g, b = T.RGB(fits and "fit" or "levelRange")
            self.range:SetColorTexture(r, g, b, 1)
            self.range:Show()
        else
            self.range:Hide()
        end
        if type(level) == "number" then
            self.me:ClearAllPoints()
            self.me:SetPoint("CENTER", self, "LEFT", x(math.min(L.maxLevel, math.max(1, level))), 0)
            self.me:Show()
        else
            self.me:Hide()
        end
    end
    return f
end
