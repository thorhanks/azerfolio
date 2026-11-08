-- The main window, in the native Forever look (mockups/DESIGN.md § Native look):
--   * the client's PortraitFrameTemplate: gold metal frame, portrait ring, title band, close,
--     and its FrameGlow while the controller drives the window;
--   * a character strip and the content area on the native pane background;
--   * native side tabs on the right edge (LB above, RB below);
--   * a legend box below the frame: info line (what the focused control is) and button hints.
-- Built lazily on first open; nothing touches the client at load time.
local _, ns = ...

local UI = {}
ns.UI = UI

local FRAME_NAME = "AzerfolioMainFrame"
local SCREEN_MARGIN = 8 -- keep this much of the screen free around a restored window

UI.tabs = {}  -- registered tab definitions, sorted by order
local window   -- the built frame (nil until first open)
local current  -- id of the selected tab
local hintPool = {}

---------------------------------------------------------------------------------------------
-- Pure helpers (tested without the client)
---------------------------------------------------------------------------------------------

-- Fits a saved window into the parent. x/y are the window centre's offset from the parent
-- centre. `outside` = { left, right, top, bottom }: space the window's parts take beyond its
-- edges (side tabs, legend box). Returns x, y, w, h with everything on screen.
function UI.ClampGeometry(x, y, w, h, parentW, parentH, minW, minH, outside)
    local o = outside or {}
    local L, R, T, B = o.left or 0, o.right or 0, o.top or 0, o.bottom or 0
    local maxW = math.max(1, parentW - 2 * SCREEN_MARGIN - L - R)
    local maxH = math.max(1, parentH - 2 * SCREEN_MARGIN - T - B)
    local function round(v) return math.floor(v + 0.5) end
    w = math.floor(math.min(math.max(w, minW), maxW))
    h = math.floor(math.min(math.max(h, minH), maxH))
    -- Whole-unit bounds, rounded inward so nothing ends half a unit off screen.
    local loX = math.ceil(-parentW / 2 + SCREEN_MARGIN + w / 2 + L)
    local hiX = math.floor(parentW / 2 - SCREEN_MARGIN - w / 2 - R)
    local loY = math.ceil(-parentH / 2 + SCREEN_MARGIN + h / 2 + B)
    local hiY = math.floor(parentH / 2 - SCREEN_MARGIN - h / 2 - T)
    x = math.min(math.max(round(x), loX), math.max(loX, hiX))
    y = math.min(math.max(round(y), loY), math.max(loY, hiY))
    return x, y, w, h
end

-- Registers a tab. def = { id, label, icon, order, info, compactHeader, hints, build(parent) }.
-- Adding a tab is this one call; the window picks it up when it's built.
function UI.RegisterTab(def)
    assert(type(def.id) == "string" and type(def.build) == "function", "tab needs id and build")
    UI.tabs[#UI.tabs + 1] = def
    table.sort(UI.tabs, function(a, b) return (a.order or 0) < (b.order or 0) end)
end

local function tabIndex(id)
    for i, def in ipairs(UI.tabs) do if def.id == id then return i end end
end

-- The tab `delta` steps from `id`, wrapping around.
function UI.TabAfter(id, delta)
    local n = #UI.tabs
    if n == 0 then return nil end
    local i = tabIndex(id) or 1
    return UI.tabs[((i - 1 + delta) % n) + 1].id
end

---------------------------------------------------------------------------------------------
-- Geometry persistence
---------------------------------------------------------------------------------------------

local function minSize()
    local r = ns.Config.RANGES
    return r["window.width"][1], r["window.height"][1]
end

local function applyGeometry()
    local w = ns.db.window
    local minW, minH = minSize()
    local x, y, width, height = UI.ClampGeometry(w.x, w.y, w.width, w.height,
        UIParent:GetWidth(), UIParent:GetHeight(), minW, minH, ns.Theme.outside)
    window:ClearAllPoints()
    window:SetPoint("CENTER", UIParent, "CENTER", x, y)
    window:SetSize(width, height)
end

-- Reads the window's current place and size back into the settings, as a CENTER offset.
local function saveGeometry()
    local cx, cy = window:GetCenter()
    local px, py = UIParent:GetCenter()
    if not (cx and px) then return end
    local w = ns.db.window
    w.point, w.relativePoint = "CENTER", "CENTER"
    w.x, w.y = math.floor(cx - px + 0.5), math.floor(cy - py + 0.5)
    w.width, w.height = math.floor(window:GetWidth() + 0.5), math.floor(window:GetHeight() + 0.5)
    applyGeometry() -- re-anchor to CENTER and pull the tabs and legend back on screen
end

---------------------------------------------------------------------------------------------
-- Character strip
---------------------------------------------------------------------------------------------

local function classColorCode(classFile)
    local c
    if C_ClassColor and C_ClassColor.GetClassColor then
        c = ns.Debug.Try("GetClassColor", C_ClassColor.GetClassColor, classFile)
    end
    c = c or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile])
    if c and c.r then
        return string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
    end
end

local function characterLine(c, withName)
    local parts = {}
    if type(c.level) == "number" then parts[#parts + 1] = "Level " .. c.level end
    if c.race then parts[#parts + 1] = c.race end
    if c.className then
        local code = c.classFile and classColorCode(c.classFile)
        parts[#parts + 1] = code and (code .. c.className .. "|r") or c.className
    end
    local line = table.concat(parts, " ")
    if c.factionLocalized or c.faction then line = line .. "  ·  " .. (c.factionLocalized or c.faction) end
    if withName and c.name then
        line = "|cffffd100" .. c.name .. "|r  ·  " .. line
    end
    return line
end

-- Native stat bar (common-stat-bar): dark well, tinted fill, rounded mask.
local function setXP(xp, value, max)
    local L = ns.Theme.layout
    local inner = L.xpWidth - 2 * L.xpFillInset
    local width = math.floor(inner * math.min(1, math.max(0, value / max)) + 0.5)
    xp.fill:SetShown(width >= 1)
    xp.fill:SetWidth(math.max(1, width))
    xp.text:SetText(string.format("%d / %d XP", value, max))
end

local function refreshHeader()
    if not window then return end
    local h = window.header
    local c = ns.character or {}
    local compact = h.compact
    h.name:SetText(c.name or "")
    h.line:SetText(characterLine(c, compact))

    local xpKnown = not c.isMaxLevel and type(c.xp) == "number" and type(c.xpMax) == "number" and c.xpMax > 0
    h.xp:SetShown(xpKnown and not compact)
    if xpKnown then setXP(h.xp, c.xp, c.xpMax) end

    local zone = ns.Debug.Try("GetZoneText", GetZoneText) or ""
    local sub = ns.Debug.Try("GetSubZoneText", GetSubZoneText) or ""
    if sub ~= "" and sub ~= zone then
        h.subzone:SetText(sub)
        h.zone:SetText(zone)
    else
        h.subzone:SetText(zone)
        h.zone:SetText("")
    end

    if window.portrait and type(SetPortraitTexture) == "function" then
        pcall(SetPortraitTexture, window.portrait, "player")
    end
end

-- Full strip (52) on most tabs; one line (40) where the tab asks for it.
local function setHeaderMode(compact)
    local L = ns.Theme.layout
    local h = window.header
    h.compact = compact and true or false
    h:SetHeight(compact and L.headerCompactHeight or L.headerHeight)
    h.name:SetShown(not compact)
    h.line:ClearAllPoints()
    if compact then
        h.line:SetPoint("LEFT", h, "LEFT", L.portraitClear, 0)
    else
        h.line:SetPoint("TOPLEFT", h.name, "BOTTOMLEFT", 0, -2)
    end
    refreshHeader()
end

local function buildHeader(f)
    local T, L, S = ns.Theme, ns.Theme.layout, ns.Theme.space
    local h = CreateFrame("Frame", nil, f.content)
    h:SetPoint("TOPLEFT")
    h:SetPoint("TOPRIGHT")
    h:SetHeight(L.headerHeight)
    local rule = T.Solid(h, "divider", "BORDER")
    rule:SetPoint("BOTTOMLEFT"); rule:SetPoint("BOTTOMRIGHT"); rule:SetHeight(1)

    -- The strip is the drag handle (with the title band, see buildWindow).
    h:EnableMouse(true)
    h:RegisterForDrag("LeftButton")
    h:SetScript("OnDragStart", function() f:StartMoving() end)
    h:SetScript("OnDragStop", function() f:StopMovingOrSizing(); saveGeometry() end)

    h.name = T.Text(h, "lg", "gold")
    h.name:SetPoint("TOPLEFT", h, "TOPLEFT", L.portraitClear, -S.s2)
    h.line = T.Text(h, "sm", "text")

    local xp = CreateFrame("Frame", nil, h)
    xp:SetSize(L.xpWidth, L.xpHeight)
    xp:SetPoint("CENTER", h, "CENTER", 0, 0)
    xp.bg = xp:CreateTexture(nil, "BACKGROUND")
    xp.bg:SetAllPoints()
    T.SetAtlas(xp.bg, T.atlas.statBarBg)
    xp.fill = xp:CreateTexture(nil, "BORDER")
    T.SetAtlas(xp.fill, T.atlas.statBarFill)
    xp.fill:SetVertexColor(T.RGB("xpFill"))
    xp.fill:SetPoint("LEFT", xp, "LEFT", L.xpFillInset, 0)
    xp.fill:SetHeight(L.xpFillHeight)
    local mask = xp:CreateMaskTexture()
    if mask then
        mask:SetAllPoints()
        T.SetAtlas(mask, T.atlas.statBarMask)
        pcall(xp.fill.AddMaskTexture, xp.fill, mask)
    end
    xp.text = T.Text(xp, "xs", "white", "ARTWORK")
    xp.text:SetPoint("CENTER", 0, 0)
    h.xp = xp

    h.zone = T.Text(h, "sm", "dim")
    h.zone:SetPoint("RIGHT", h, "RIGHT", -S.s4, 0)
    h.zone:SetJustifyH("RIGHT")
    h.subzone = T.Text(h, "sm", "white")
    h.subzone:SetPoint("RIGHT", h.zone, "LEFT", -S.s2, 0)
    h.subzone:SetJustifyH("RIGHT")

    f.header = h
end

---------------------------------------------------------------------------------------------
-- Side tabs (common-sidetab), LB above and RB below
---------------------------------------------------------------------------------------------

local function styleTab(btn, active)
    btn.selected:SetShown(active)
    btn.icon:SetDesaturated(not active)
    btn.icon:SetAlpha(active and 1 or 0.8)
end

local function buildTabs(f)
    local T, L = ns.Theme, ns.Theme.layout
    local tabs = CreateFrame("Frame", nil, f)
    tabs:SetPoint("TOPLEFT", f, "TOPRIGHT", 0, -L.tabsTop)
    tabs:SetSize(L.tabSize, 1)

    tabs.lb = T.Glyph(tabs, "LB")
    tabs.lb:SetPoint("TOP", tabs, "TOP", 0, 0)
    local y = -(L.glyphSize + L.tabGap)
    tabs.buttons = {}
    for _, def in ipairs(UI.tabs) do
        local btn = CreateFrame("Button", nil, tabs)
        btn:SetSize(L.tabSize, L.tabSize)
        btn:SetPoint("TOP", tabs, "TOP", 0, y)
        local function art(layer, atlas)
            local t = btn:CreateTexture(nil, layer)
            t:SetSize(L.tabArt[1], L.tabArt[2])
            t:SetPoint("CENTER")
            T.SetAtlas(t, atlas)
            return t
        end
        btn.bg = art("BACKGROUND", T.atlas.sideTab)
        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetSize(L.tabIcon, L.tabIcon)
        btn.icon:SetPoint("CENTER")
        btn.icon:SetTexture(def.icon)
        local mask = btn:CreateMaskTexture()
        if mask then
            mask:SetSize(L.tabArt[1], L.tabArt[2])
            mask:SetPoint("CENTER")
            T.SetAtlas(mask, T.atlas.sideTabMask)
            pcall(btn.icon.AddMaskTexture, btn.icon, mask)
        end
        btn.selected = art("OVERLAY", T.atlas.sideTabSelected)
        btn.hover = art("HIGHLIGHT", T.atlas.sideTabHover)
        btn:SetScript("OnClick", function() UI.SelectTab(def.id) end)
        btn:SetScript("OnEnter", function() UI.SetInfo(def.label, def.info) end)
        btn:SetScript("OnLeave", function() UI.RestoreInfo() end)
        styleTab(btn, false)
        tabs.buttons[def.id] = btn
        y = y - L.tabSize - L.tabGap
    end
    tabs.rb = T.Glyph(tabs, "RB")
    tabs.rb:SetPoint("TOP", tabs, "TOP", 0, y)
    f.tabs = tabs
end

---------------------------------------------------------------------------------------------
-- Legend box: info line | hints
---------------------------------------------------------------------------------------------

local function buildLegend(f)
    local T, L, S = ns.Theme, ns.Theme.layout, ns.Theme.space
    local lg = CreateFrame("Frame", nil, f)
    lg:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -L.legendGap)
    lg:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, -L.legendGap)
    lg:SetHeight(L.legendHeight)
    lg:EnableMouse(true)
    local bg = lg:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", L.legendEdge, -L.legendEdge)
    bg:SetPoint("BOTTOMRIGHT", -L.legendEdge, L.legendEdge)
    bg:SetTexture(T.files.legendBg)
    T.NineSlice(lg, T.atlas.diamond, "BORDER")

    lg.hints = CreateFrame("Frame", nil, lg)
    lg.hints:SetPoint("RIGHT", -S.s4, 0)
    lg.hints:SetSize(1, L.glyphSize)
    lg.info = T.Text(lg, "sm", "text")
    lg.info:SetPoint("LEFT", lg, "LEFT", S.s4, 0)
    lg.info:SetPoint("RIGHT", lg.hints, "LEFT", -S.s4, 0)
    lg.info:SetJustifyH("LEFT")
    lg.info:SetWordWrap(false)
    f.legend = lg
end

-- Info line: "<gold>Title</gold> detail". Describes the focused control (gamepad users' tooltip).
function UI.SetInfo(title, detail)
    if not window then return end
    local text = ""
    if title and title ~= "" then text = "|cffffd100" .. title .. "|r" end
    if detail and detail ~= "" then text = text .. (text ~= "" and "   " or "") .. detail end
    window.legend.info:SetText(text)
end

-- The current tab's own description.
function UI.ShowTabInfo()
    local def = UI.tabs[tabIndex(current) or 0]
    if def then UI.SetInfo(def.label, def.info) else UI.SetInfo() end
end

-- Back to what the info line should say now: the focused control, or the tab.
function UI.RestoreInfo()
    if ns.Focus then ns.Focus.RestoreInfo() else UI.ShowTabInfo() end
end

-- hints = { { "A", "Select" }, { { "LT", "RT" }, "Continent" }, ... }: one or two glyphs and a
-- label each, drawn right to left from the edge. Shown only while the controller drives
-- the window.
function UI.SetHints(hints)
    if not window then return end
    local T, S = ns.Theme, ns.Theme.space
    local row = window.legend.hints
    hints = (ns.Gamepad and ns.Gamepad.IsActive()) and hints or {}
    local x = 0
    for i = #hints, 1, -1 do
        local slot = #hints - i + 1
        local e = hintPool[slot]
        if not e then
            e = { glyph = T.Glyph(row, "A"), glyph2 = T.Glyph(row, "A"), text = T.Text(row, "sm", "gold") }
            hintPool[slot] = e
        end
        local buttons = hints[i][1]
        if type(buttons) ~= "table" then buttons = { buttons } end
        e.text:SetText(hints[i][2])
        e.text:ClearAllPoints()
        e.text:SetPoint("RIGHT", row, "RIGHT", -x, 0)
        x = x + (e.text:GetStringWidth() or 0) + S.s1
        local anchor = e.text
        for gi, g in ipairs({ e.glyph2, e.glyph }) do
            local b = buttons[#buttons - gi + 1]
            g:SetShown(b ~= nil)
            if b then
                T.SetGlyph(g, b)
                g:ClearAllPoints()
                g:SetPoint("RIGHT", anchor, "LEFT", gi == 1 and -S.s1 or 0, 0)
                anchor = g
                x = x + g:GetWidth()
            end
        end
        e.text:Show()
        x = x + S.s4
    end
    for slot = #hints + 1, #hintPool do
        local e = hintPool[slot]
        e.glyph:Hide(); e.glyph2:Hide(); e.text:Hide()
    end
    row:SetWidth(math.max(1, x - S.s4))
end

-- The focused control's action, the current tab's hints, sections, then B to close.
local function currentHints()
    local def = UI.tabs[tabIndex(current) or 0]
    local list = {}
    local item = ns.Focus and ns.Focus.Current()
    if item and item.onActivate and not (item.canActivate and not item.canActivate(item)) then
        list[#list + 1] = { "A", item.actionLabel or "Select" }
    end
    local page = window and window.pages[current]
    for _, h in ipairs((def and def.hints) or {}) do list[#list + 1] = h end
    if page and page.GetHints then
        for _, h in ipairs(page:GetHints() or {}) do list[#list + 1] = h end
    end
    if ns.Focus and ns.Focus.HasSections() then
        list[#list + 1] = { { "LT", "RT" }, (page and page.sectionLabel) or (def and def.sectionLabel) or "Section" }
    end
    list[#list + 1] = { "B", (page and page.backLabel) or "Close" }
    return list
end

-- X / Y: handed to the current page (page:OnButton(name) returns true if it used it).
function UI.PageButton(name)
    local page = window and window.pages[current]
    if page and page.OnButton and page:OnButton(name) then UI.RefreshHints() end
end

-- B: the page goes back a level if it can (Zone Detail -> list); otherwise the window closes.
function UI.Back()
    local page = window and window.pages[current]
    if page and page.Back and page:Back() then return end
    UI.Hide()
end

-- Everything that depends on whether the controller drives the window: the frame's focus
-- glow, the LB/RB glyphs on the tabs, the focus chevron and the button hints.
function UI.RefreshHints()
    if not window then return end
    local active = ns.Gamepad and ns.Gamepad.IsActive() or false
    if window.FrameGlow then window.FrameGlow:SetShown(active) end
    window.tabs.lb:SetShown(active)
    window.tabs.rb:SetShown(active)
    if ns.Focus then ns.Focus.Update(false) end
    UI.SetHints(currentHints())
end

---------------------------------------------------------------------------------------------
-- Build, show, hide, tabs
---------------------------------------------------------------------------------------------

local function buildWindow()
    local T, L = ns.Theme, ns.Theme.layout
    local f = CreateFrame("Frame", FRAME_NAME, UIParent, "PortraitFrameTemplate")
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:SetResizable(true)
    local minW, minH = minSize()
    local r = ns.Config.RANGES
    if f.SetResizeBounds then
        f:SetResizeBounds(minW, minH, r["window.width"][2], r["window.height"][2])
    elseif f.SetMinResize then
        f:SetMinResize(minW, minH)
        f:SetMaxResize(r["window.width"][2], r["window.height"][2])
    end
    f:EnableMouse(true) -- clicks on the window don't fall through to the world
    f:Hide()

    if f.SetTitle then
        pcall(f.SetTitle, f, "Azerfolio")
    elseif f.TitleContainer and f.TitleContainer.TitleText then
        f.TitleContainer.TitleText:SetText("Azerfolio")
    end
    window = f
    f.portrait = f.PortraitContainer and f.PortraitContainer.portrait
    if f.CloseButton then f.CloseButton:SetScript("OnClick", function() UI.Hide() end) end

    -- Content: the native pane background between the title band and the frame edge.
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", f, "TOPLEFT", L.edgeInset, -L.titleHeight)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -L.edgeInset, L.edgeInset)
    local pane = content:CreateTexture(nil, "BACKGROUND")
    pane:SetAllPoints()
    T.SetAtlas(pane, T.atlas.pane)
    f.content = content

    buildHeader(f)
    local body = CreateFrame("Frame", nil, content)
    body:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT")
    body:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT")
    body:SetClipsChildren(true)
    f.body = body
    f.pages = {}

    -- The template's frame art draws over the content (its metal edge overlaps the pane).
    local top = content:GetFrameLevel() + 5
    for _, key in ipairs({ "NineSlice", "PortraitContainer", "TitleContainer", "CloseButton" }) do
        if f[key] and f[key].SetFrameLevel then f[key]:SetFrameLevel(top) end
    end

    -- Drag by the title band too.
    local drag = CreateFrame("Frame", nil, f)
    drag:SetPoint("TOPLEFT", f, "TOPLEFT", L.portraitClear, 0)
    drag:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -32, -L.titleHeight)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() f:StartMoving() end)
    drag:SetScript("OnDragStop", function() f:StopMovingOrSizing(); saveGeometry() end)

    buildTabs(f)
    buildLegend(f)

    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -4, 4)
    grip:SetFrameLevel(top + 1)
    grip:SetNormalTexture(T.files.resizeUp)
    grip:SetHighlightTexture(T.files.resizeHighlight)
    grip:SetPushedTexture(T.files.resizeDown)
    grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing(); saveGeometry() end)
    f.grip = grip

    f:SetScript("OnSizeChanged", function() UI.Relayout() end)
    f:SetScript("OnShow", function()
        refreshHeader()
        if ns.Gamepad then ns.Gamepad.Update() end
        UI.RefreshHints()
        ns.Events.Send("AZF_WINDOW_SHOWN")
    end)
    f:SetScript("OnHide", function()
        if f.grip:GetButtonState() == "PUSHED" then f:StopMovingOrSizing() end
        if ns.Gamepad then ns.Gamepad.Update() end
        ns.Events.Send("AZF_WINDOW_HIDDEN")
    end)

    -- Escape closes it (the client hides UISpecialFrames on Escape).
    if type(UISpecialFrames) == "table" then table.insert(UISpecialFrames, FRAME_NAME) end

    local function onChange() if f:IsShown() then refreshHeader() end end
    ns.Events.On("AZF_CHARACTER_UPDATED", onChange)
    for _, e in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA" }) do
        ns.Events.Register(e, onChange)
    end

    if ns.Gamepad then ns.Gamepad.Attach(f) end
    if ns.Focus then ns.Focus.Attach(f) end
    applyGeometry()
    UI.SelectTab(ns.db.lastTab)
end

function UI.SelectTab(id)
    if not tabIndex(id) then id = UI.tabs[1] and UI.tabs[1].id end
    if not id or not window then return end
    local t = ns.Events.StartTiming()
    local def = UI.tabs[tabIndex(id)]
    local page = window.pages[id]
    local built = not page
    if not page then
        page = def.build(window.body)
        page:SetAllPoints(window.body)
        window.pages[id] = page
    end
    for pid, p in pairs(window.pages) do p:SetShown(pid == id) end
    for tid, btn in pairs(window.tabs.buttons) do styleTab(btn, tid == id) end
    current = id
    ns.db.lastTab = id
    setHeaderMode(def.compactHeader)
    if ns.Focus then ns.Focus.SetPage(id, page) end
    UI.RefreshHints()
    ns.Events.StopTiming("ui:tab " .. id .. (built and " (first, builds the page)" or ""), t)
end

function UI.CurrentTab() return current end

-- Is the window wide enough for split views (ultrawide; Zones list + detail side by side)?
function UI.IsWide()
    return window ~= nil and (window:GetWidth() or 0) >= ns.Theme.layout.wideMinWidth
end

-- Lets built pages adapt to the window's size (page:Layout()). Called on every resize.
function UI.Relayout()
    if not window then return end
    local t = ns.Events.StartTiming()
    for _, page in pairs(window.pages) do
        if page.Layout then page:Layout() end
    end
    ns.Events.StopTiming("ui:relayout", t)
end

function UI.NextTab(delta)
    if window then UI.SelectTab(UI.TabAfter(current, delta)) end
end

function UI.IsShown() return window ~= nil and window:IsShown() end

local function playSound(kit)
    if type(PlaySound) == "function" and SOUNDKIT and SOUNDKIT[kit] then pcall(PlaySound, SOUNDKIT[kit]) end
end

function UI.Show()
    if not ns.ready then
        ns.Print("Still loading, try again in a moment.")
        return
    end
    local t = ns.Events.StartTiming()
    local first = not window
    if not window then buildWindow() end
    applyGeometry()
    window:Show()
    playSound("IG_CHARACTER_INFO_OPEN")
    ns.Events.StopTiming(first and "ui:open (first, builds the window)" or "ui:open", t)
end

function UI.Hide()
    if window and window:IsShown() then
        window:Hide()
        playSound("IG_CHARACTER_INFO_CLOSE")
    end
end

function UI.Toggle()
    if UI.IsShown() then UI.Hide() else UI.Show() end
end

-- For /azf shots and tests.
function UI.GetFrame() return window end
function UI.ApplyGeometry() if window then applyGeometry() end end

-- Resizes the window for a moment (shots), moved so it stays on screen. Not saved.
function UI.FitSize(width, height)
    if not window then return end
    local w = ns.db.window
    local minW, minH = minSize()
    local x, y, fw, fh = UI.ClampGeometry(w.x, w.y, width, height,
        UIParent:GetWidth(), UIParent:GetHeight(), minW, minH, ns.Theme.outside)
    window:ClearAllPoints()
    window:SetPoint("CENTER", UIParent, "CENTER", x, y)
    window:SetSize(fw, fh)
    UI.Relayout()
end
