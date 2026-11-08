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
    function b:SetLabel(text)
        self.text:SetText(text)
        self:SetWidth(math.floor((self.text:GetStringWidth() or 0) + 2 * L.controlPad + 0.5))
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
