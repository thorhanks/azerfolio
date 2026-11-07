-- The main window: header (character, zone, wordmark, close), parchment content area, and the
-- footer (tabs | info line | button hints). Built lazily on first open; nothing touches the
-- client at load time. Layout follows mockups/DESIGN.md "Window chrome".
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
-- centre. Returns x, y, w, h so the whole window is on screen (off-screen recovery).
function UI.ClampGeometry(x, y, w, h, parentW, parentH, minW, minH)
    local maxW = math.max(1, parentW - 2 * SCREEN_MARGIN)
    local maxH = math.max(1, parentH - 2 * SCREEN_MARGIN)
    w = math.min(math.max(w, minW), maxW)
    h = math.min(math.max(h, minH), maxH)
    local limX = math.max(0, (maxW - w) / 2)
    local limY = math.max(0, (maxH - h) / 2)
    x = math.min(math.max(x, -limX), limX)
    y = math.min(math.max(y, -limY), limY)
    return math.floor(x + 0.5), math.floor(y + 0.5), math.floor(w + 0.5), math.floor(h + 0.5)
end

-- Registers a tab. def = { id, label, order, info, compactHeader, hints, build(parent) }.
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
        UIParent:GetWidth(), UIParent:GetHeight(), minW, minH)
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
    applyGeometry() -- re-anchor to CENTER (moving and sizing leave other anchors behind)
end

---------------------------------------------------------------------------------------------
-- Header
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

local function refreshHeader()
    if not window then return end
    local h = window.header
    local c = ns.character or {}
    local compact = h.compact
    h.name:SetText(c.name or "")
    h.line:SetText(characterLine(c, compact))

    local xpKnown = not c.isMaxLevel and type(c.xp) == "number" and type(c.xpMax) == "number" and c.xpMax > 0
    h.xp:SetShown(xpKnown and not compact)
    if xpKnown then
        h.xp:SetMinMaxValues(0, c.xpMax)
        h.xp:SetValue(c.xp)
        h.xp.text:SetText(string.format("%d / %d XP", c.xp, c.xpMax))
    end

    local zone = ns.Debug.Try("GetZoneText", GetZoneText) or ""
    local sub = ns.Debug.Try("GetSubZoneText", GetSubZoneText) or ""
    if sub ~= "" and sub ~= zone then
        h.subzone:SetText(sub)
        h.zone:SetText(zone)
    else
        h.subzone:SetText(zone)
        h.zone:SetText("")
    end

    if not compact and type(SetPortraitTexture) == "function" then
        pcall(SetPortraitTexture, h.portrait, "player")
    end
end

-- Full header (76) on most tabs; compact (44) where the tab asks for it.
local function setHeaderMode(compact)
    local L, T = ns.Theme.layout, ns.Theme
    local h = window.header
    h.compact = compact and true or false
    h:SetHeight(compact and L.headerCompactHeight or L.headerHeight)
    h.portrait:SetShown(not compact)
    h.name:SetShown(not compact)
    h.line:ClearAllPoints()
    if compact then
        h.line:SetPoint("LEFT", h, "LEFT", T.space.s6, 0)
        T.SetFont(h.wordmark, "title", "md")
    else
        h.line:SetPoint("TOPLEFT", h.name, "BOTTOMLEFT", 0, -2)
        T.SetFont(h.wordmark, "title", "lg")
    end
    refreshHeader()
end

local function buildHeader(f)
    local T, L, S = ns.Theme, ns.Theme.layout, ns.Theme.space
    local inset = L.border + L.innerLine
    local h = CreateFrame("Frame", nil, f)
    h:SetPoint("TOPLEFT", inset, -inset)
    h:SetPoint("TOPRIGHT", -inset, -inset)
    h:SetHeight(L.headerHeight)
    local bg = T.Gradient(h, "headerTop", "headerBottom", "BACKGROUND")
    bg:SetAllPoints()
    local rule = T.Solid(h, "goldDark", "BORDER")
    rule:SetPoint("BOTTOMLEFT"); rule:SetPoint("BOTTOMRIGHT"); rule:SetHeight(2)

    -- The header is the drag handle (there is no separate title bar).
    h:EnableMouse(true)
    h:RegisterForDrag("LeftButton")
    h:SetScript("OnDragStart", function() f:StartMoving() end)
    h:SetScript("OnDragStop", function() f:StopMovingOrSizing(); saveGeometry() end)

    h.portrait = h:CreateTexture(nil, "ARTWORK")
    h.portrait:SetSize(L.portrait, L.portrait)
    h.portrait:SetPoint("LEFT", S.s6, 0)
    local mask = h:CreateMaskTexture()
    if mask then
        mask:SetAllPoints(h.portrait)
        mask:SetTexture(T.textures.portraitMask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        pcall(h.portrait.AddMaskTexture, h.portrait, mask)
    end

    h.name = T.Text(h, "title", "lg", "wowGold")
    h.name:SetPoint("TOPLEFT", h.portrait, "TOPRIGHT", S.s4, -2)
    h.line = T.Text(h, "body", "sm", "white")

    h.xp = CreateFrame("StatusBar", nil, h)
    h.xp:SetSize(L.xpWidth, L.xpHeight)
    h.xp:SetPoint("TOPLEFT", h.line, "BOTTOMLEFT", 0, -S.s1)
    h.xp:SetStatusBarTexture(T.textures.white)
    h.xp:SetStatusBarColor(T.RGB("xpFill"))
    local xbg = T.Solid(h.xp, "xpBg", "BACKGROUND")
    xbg:SetAllPoints()
    T.Edge(h.xp, "black", 1, 0, "OVERLAY")
    h.xp.text = T.Text(h.xp, "body", "xs", "white")
    h.xp.text:SetPoint("CENTER", 0, 0)

    h.close = CreateFrame("Button", nil, h, "UIPanelCloseButton")
    h.close:SetPoint("RIGHT", -S.s3, 0)
    h.close:SetScript("OnClick", function() UI.Hide() end)

    h.wordmark = T.Text(h, "title", "lg", "wowGold")
    h.wordmark:SetText("AZERFOLIO")
    h.wordmark:SetPoint("RIGHT", h.close, "LEFT", -S.s4, 0)
    local div = T.Solid(h, "goldDark", "ARTWORK")
    div:SetWidth(1)
    div:SetPoint("RIGHT", h.wordmark, "LEFT", -S.s4, 0)
    div:SetPoint("TOP", 0, -S.s3)
    div:SetPoint("BOTTOM", 0, S.s3)

    h.zone = T.Text(h, "body", "sm", "muted")
    h.zone:SetPoint("RIGHT", div, "LEFT", -S.s4, 0)
    h.zone:SetJustifyH("RIGHT")
    h.subzone = T.Text(h, "title", "sm", "white")
    h.subzone:SetPoint("RIGHT", h.zone, "LEFT", -S.s2, 0)
    h.subzone:SetJustifyH("RIGHT")

    f.header = h
end

---------------------------------------------------------------------------------------------
-- Footer: tabs | info line | hints
---------------------------------------------------------------------------------------------

local function styleTab(btn, active)
    local T = ns.Theme
    if active then
        btn.bgTop:SetShown(false); btn.bgActive:SetShown(true)
        btn.text:SetTextColor(T.RGB("ink")); btn.text:SetShadowOffset(0, 0)
        btn:SetHeight(T.layout.tabHeight + 4)
    else
        btn.bgTop:SetShown(true); btn.bgActive:SetShown(false)
        btn.text:SetTextColor(T.RGB("tabText")); btn.text:SetShadowOffset(1, -1)
        btn:SetHeight(T.layout.tabHeight)
    end
end

local function buildTabs(footer)
    local T, S = ns.Theme, ns.Theme.space
    footer.lb = T.Glyph(footer, "LB")
    footer.lb:SetPoint("LEFT", S.s4, 0)
    local x = S.s4 + footer.lb:GetWidth() + S.s1
    footer.tabButtons = {}
    for _, def in ipairs(UI.tabs) do
        local btn = CreateFrame("Button", nil, footer)
        btn.bgTop = T.Gradient(btn, "tabTop", "tabBottom", "BACKGROUND")
        btn.bgTop:SetAllPoints()
        btn.bgActive = T.Gradient(btn, "tabActiveTop", "tabActiveBottom", "BACKGROUND")
        btn.bgActive:SetAllPoints()
        T.Edge(btn, "goldDark", 2, 0, "BORDER")
        btn.text = T.Text(btn, "title", "sm", "tabText")
        btn.text:SetPoint("CENTER", 0, 0)
        btn.text:SetText(string.upper(def.label or def.id))
        local width = math.floor((btn.text:GetStringWidth() or 60) + 2 * T.layout.tabPadX + 0.5)
        btn:SetWidth(width)
        -- Tabs hang from the footer's top edge, like the mockup.
        btn:SetPoint("TOPLEFT", footer, "TOPLEFT", x, 2)
        btn:SetScript("OnClick", function() UI.SelectTab(def.id) end)
        btn:SetScript("OnEnter", function() UI.SetInfo(def.label, def.info) end)
        btn:SetScript("OnLeave", function() UI.RestoreInfo() end)
        styleTab(btn, false)
        footer.tabButtons[def.id] = btn
        x = x + width + S.s1
    end
    footer.rb = T.Glyph(footer, "RB")
    footer.rb:SetPoint("LEFT", footer, "LEFT", x, 0)
end

local function buildFooter(f)
    local T, L, S = ns.Theme, ns.Theme.layout, ns.Theme.space
    local inset = L.border + L.innerLine
    local footer = CreateFrame("Frame", nil, f)
    footer:SetPoint("BOTTOMLEFT", inset, inset)
    footer:SetPoint("BOTTOMRIGHT", -inset, inset)
    footer:SetHeight(L.footerHeight)
    local bg = T.Gradient(footer, "footerTop", "footerBottom", "BACKGROUND")
    bg:SetAllPoints()
    local rule = T.Solid(footer, "goldDark", "BORDER")
    rule:SetPoint("TOPLEFT"); rule:SetPoint("TOPRIGHT"); rule:SetHeight(2)

    buildTabs(footer)

    footer.hints = CreateFrame("Frame", nil, footer)
    footer.hints:SetPoint("RIGHT", -S.s4, 0)
    footer.hints:SetSize(1, L.glyphHeight)

    local div = T.Solid(footer, "divider", "ARTWORK")
    div:SetWidth(1)
    div:SetPoint("LEFT", footer.rb, "RIGHT", S.s4, 0)
    div:SetPoint("TOP", 0, -S.s3)
    div:SetPoint("BOTTOM", 0, S.s3)
    footer.info = T.Text(footer, "body", "sm", "infoText")
    footer.info:SetPoint("LEFT", div, "RIGHT", S.s4, 0)
    footer.info:SetPoint("RIGHT", footer.hints, "LEFT", -S.s4, 0)
    footer.info:SetJustifyH("LEFT")
    footer.info:SetWordWrap(false)

    f.footer = footer
end

-- Info line: "<b>Title</b> detail". Describes the focused control (gamepad users' tooltip).
function UI.SetInfo(title, detail)
    if not window then return end
    local text = ""
    if title and title ~= "" then text = "|cffffd100" .. title .. "|r" end
    if detail and detail ~= "" then text = text .. (text ~= "" and "   " or "") .. detail end
    window.footer.info:SetText(text)
end

-- Back to the current tab's own description.
function UI.RestoreInfo()
    local def = UI.tabs[tabIndex(current) or 0]
    if def then UI.SetInfo(def.label, def.info) else UI.SetInfo() end
end

-- hints = { { "A", "Select" }, { "B", "Close" }, ... }, drawn right to left from the edge.
-- Hidden when the controller isn't driving the window (mouse users, or in combat).
function UI.SetHints(hints)
    if not window then return end
    local T, S = ns.Theme, ns.Theme.space
    local row = window.footer.hints
    local show = ns.Gamepad and ns.Gamepad.IsActive()
    hints = show and hints or {}
    local x = 0
    for i = #hints, 1, -1 do
        local slot = #hints - i + 1
        local e = hintPool[slot]
        if not e then
            e = { glyph = T.Glyph(row, "A"), text = T.Text(row, "body", "sm", "infoText") }
            hintPool[slot] = e
        end
        T.SetGlyph(e.glyph, hints[i][1])
        e.text:SetText(hints[i][2])
        e.text:ClearAllPoints()
        e.text:SetPoint("RIGHT", row, "RIGHT", -x, 0)
        e.glyph:ClearAllPoints()
        e.glyph:SetPoint("RIGHT", e.text, "LEFT", -S.s1, 0)
        e.glyph:Show(); e.text:Show()
        x = x + (e.text:GetStringWidth() or 0) + S.s1 + e.glyph:GetWidth() + S.s3
    end
    for slot = #hints + 1, #hintPool do
        hintPool[slot].glyph:Hide(); hintPool[slot].text:Hide()
    end
    row:SetWidth(math.max(1, x - S.s3))
    window.footer.lb:SetShown(show)
    window.footer.rb:SetShown(show)
end

-- The current tab's hints, then the window's own (B closes).
local function currentHints()
    local def = UI.tabs[tabIndex(current) or 0]
    local list = {}
    for _, h in ipairs((def and def.hints) or {}) do list[#list + 1] = h end
    list[#list + 1] = { "B", "Close" }
    return list
end

function UI.RefreshHints()
    UI.SetHints(currentHints())
end

---------------------------------------------------------------------------------------------
-- Build, show, hide, tabs
---------------------------------------------------------------------------------------------

local function buildWindow()
    local T, L = ns.Theme, ns.Theme.layout
    local f = CreateFrame("Frame", FRAME_NAME, UIParent)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
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

    local bg = T.Solid(f, "stone", "BACKGROUND")
    bg:SetAllPoints()
    T.Edge(f, "goldDark", L.border, 0, "BORDER")
    T.Edge(f, "gold", L.innerLine, L.border, "BORDER")

    buildHeader(f)
    buildFooter(f)

    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", L.contentInset, 0)
    content:SetPoint("BOTTOMRIGHT", f.footer, "TOPRIGHT", -L.contentInset, 0)
    content:SetClipsChildren(true)
    -- Light, even parchment colour (design), with the native texture only as faint grain:
    -- at full strength its dark blotches hid ink text (shot 2026-11-07 16:37:11).
    local base = content:CreateTexture(nil, "BACKGROUND", nil, -8)
    base:SetAllPoints()
    base:SetColorTexture(T.RGB("parchment"))
    local grain = content:CreateTexture(nil, "BACKGROUND", nil, -7)
    grain:SetAllPoints()
    grain:SetTexture(T.textures.parchment)
    grain:SetAlpha(T.layout.parchmentGrain)
    T.Edge(content, "inkSoft", 1, 0, "BORDER")
    f.content = content
    f.pages = {}

    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -L.border - 2, L.border + 2)
    grip:SetFrameLevel(f.footer:GetFrameLevel() + 5)
    grip:SetNormalTexture(T.textures.resizeUp)
    grip:SetHighlightTexture(T.textures.resizeHighlight)
    grip:SetPushedTexture(T.textures.resizeDown)
    grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing(); saveGeometry() end)
    f.grip = grip

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

    window = f
    if ns.Gamepad then ns.Gamepad.Attach(f) end
    applyGeometry()
    UI.SelectTab(ns.db.lastTab)
end

function UI.SelectTab(id)
    if not tabIndex(id) then id = UI.tabs[1] and UI.tabs[1].id end
    if not id or not window then return end
    local def = UI.tabs[tabIndex(id)]
    local page = window.pages[id]
    if not page then
        page = def.build(window.content)
        page:SetAllPoints(window.content)
        window.pages[id] = page
    end
    for pid, p in pairs(window.pages) do p:SetShown(pid == id) end
    for tid, btn in pairs(window.footer.tabButtons) do styleTab(btn, tid == id) end
    current = id
    ns.db.lastTab = id
    setHeaderMode(def.compactHeader)
    UI.RestoreInfo()
    UI.RefreshHints()
end

function UI.CurrentTab() return current end

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
    if not window then buildWindow() end
    applyGeometry()
    window:Show()
    playSound("IG_CHARACTER_INFO_OPEN")
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
