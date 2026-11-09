-- Visual constants for the native Forever look (mockups/DESIGN.md § Native look). The window is
-- the client's PortraitFrameTemplate; everything else uses the client's own atlases, identified
-- with /azfdiag skin (docs/research/client-capabilities.md § Native frame style).
-- No style constants anywhere else. Data only at load time; helpers touch the client when called.
local _, ns = ...

local Theme = {}
ns.Theme = Theme

local function hex(s)
    return {
        tonumber(s:sub(1, 2), 16) / 255,
        tonumber(s:sub(3, 4), 16) / 255,
        tonumber(s:sub(5, 6), 16) / 255,
    }
end

Theme.color = {
    gold = { 1, 0.82, 0 },        -- native gold text (titles, headings, legend labels)
    white = { 1, 1, 1 },          -- names
    text = hex("f0e8d8"),         -- body text
    dim = hex("b5a891"),          -- secondary text
    divider = hex("5a4128"),      -- horizontal rules
    xpFill = hex("8a64e8"),
    todo = hex("e08a3c"),         -- state language: in progress / not yet discovered
    complete = hex("ffcc33"),     -- state language: complete / discovered
    untouched = hex("5b5246"),    -- state language: untouched (empty pips)
    fit = hex("5aa548"),          -- "Your level" tag and a fitting level range
    Alliance = hex("6fa8ff"),     -- faction territory text
    Horde = hex("ff6b5b"),
    Contested = hex("b5a891"),
    levelBg = hex("2e261e"),      -- level bar well
    levelRange = hex("8a7348"),   -- a zone's level range that doesn't fit
    ctlBg = hex("1c140d"),        -- toolbar controls (mockups/style.css .seg, .select)
    ctlOn = hex("5a3d1c"),        -- selected segment
    ctlEdge = hex("5f5141"),
    cardBg = hex("1a120b"),
    cardEdge = hex("5a4128"),
    well = hex("3d342a"),         -- empty part of bars and the activity strip (style.css .stack .u)
    focus = { 1, 0.902, 0 },      -- GAMEPAD_SMARTNAV_CURSOR_COLOR [verified-ingame]
    black = { 0, 0, 0 },
    ink = hex("2b1a0c"),
    -- Fallback glyph discs, only if a face-button atlas can't be found
    padA = hex("5cb85c"), padB = hex("d9534f"), padX = hex("3d8bfd"), padY = hex("f0ad4e"),
    padShoulder = hex("cfc6b4"),
}

-- Type scale (nothing below 12: couch distance).
Theme.size = { xs = 12, sm = 14, md = 16, lg = 20, xl = 26, xxl = 32, huge = 42 } -- huge: the zone's % in the dashboard header

-- 4 px spacing grid.
Theme.space = { s1 = 4, s2 = 8, s3 = 12, s4 = 16, s6 = 24 }

Theme.layout = {
    titleHeight = 21,          -- PortraitFrameTemplate title band
    headerHeight = 52,         -- character strip
    headerCompactHeight = 40,  -- one-line strip (clears the portrait ring)
    portraitClear = 66,        -- strip text starts right of the ring
    edgeInset = 2,             -- content inset from the frame edge (the metal edge overlays it)
    xpWidth = 300,
    xpHeight = 29,             -- common-stat-bar art height (the well is 15 tall)
    xpFillInset = 6,
    xpFillHeight = 15,
    tabSize = 55,              -- common-sidetab button
    tabArt = { 55, 60 },       -- common-sidetab texture size
    tabIcon = 50,
    tabGap = 4,
    tabsTop = 40,
    legendHeight = 44,
    legendGap = 6,
    legendEdge = 7,            -- diamond-metal border thickness over the background
    glyphSize = 24,            -- frame
    glyphArt = 34,             -- atlas drawn larger than the frame, like the client's legend
    pointer = { 21, 35 },      -- focus chevron (half the 42x70 atlas) [unverified size]
    listHeader = 30,           -- group header row
    listRow = 36,              -- zone row
    listInset = 32,            -- list rows start here (room for the chevron)
    thumb = { 56, 28 },        -- zone art thumbnail (2:1)
    rowHiSide = 6,             -- row highlight end caps
    checkRow = 32,             -- Zone Detail area row
    checkIcon = 20,
    bannerHeight = 124,        -- Zone Detail banner
    bannerRightShade = 420,    -- dark band behind the banner's progress
    wideMinWidth = 1440,       -- window width from which Zones becomes a split view
    splitListWidth = 560,      -- the split view's list column
    -- Zones catalogue (mockups/style.css .toolbar, .zcard, .zrow)
    toolbarHeight = 44,
    controlHeight = 28,
    controlPad = 10,           -- text padding inside a toolbar control
    controlPadTight = 6,       -- the same in a narrow window's short toolbar
    searchWidth = 150,
    searchMinWidth = 100,
    popupRow = 30,
    popupWidth = 200,
    cardMinWidth = 240,        -- cards are at least this wide; the grid adds columns as it can
    cardGap = 16,
    cardArtAspect = 5 / 16,    -- art band height / width
    cardBody = 122,            -- name line, three category bars, meta line (108 overlapped in game)
    zoneRow = 48,              -- list view row
    zoneThumb = { 64, 32 },
    levelBarWidth = 120,
    levelTextWidth = 76,       -- "Lv 10-20" left of the bar (60 wrapped it in game)
    levelBarMinRow = 700,      -- rows narrower than this (the split view's list) drop the bar
    levelBarHeight = 8,
    pctWidth = 56,
    pip = 10,
    pipGap = 3,
    maxLevel = 60,             -- the level bar's scale
    -- Overview (mockups/style.css .overview, .hero, .goal, .zonegroup, .counter, .activity)
    overviewLeft = 0.6,        -- left column's share (grid 1.5fr 1fr)
    heroHeight = 164,
    heroArt = 190,
    heroScore = 180,           -- right part of the Continue card (big percentage and the mini standard)
    goalHeight = 40,
    groupHead = 24,            -- suggestion group's name line
    statBar = 12,              -- stacked / progress bar height in the panels
    recentRow = 40,
    recentThumb = { 56, 28 },
    -- Phase 9 step 6 (mockups/DESIGN.md "Step 6"): plates, Tracked completion rows, suggestions.
    plate = 34,                -- section header plate
    trackHead = 44,            -- Tracked completion: title and headline
    trackRow = 30,             -- one category row
    trackLabel = 104,          -- the category name's column
    trackCount = 92,           -- "done / counted"
    trackBar = 16,             -- gilded bar height in a row
    sugItem = 30,              -- one suggestion pick
    sugCols = 2,
    panelPad = 12,             -- inside a framed panel
}

-- Painted art from tools/process-art.ps1 (Data/Art.lua lists what exists; the client can't
-- test whether a file exists). Icons: Media\Icons\icon-<name>.blp; chrome: Media\Chrome.
Theme.mediaDir = "Interface\\AddOns\\Azerfolio\\Media\\"
function Theme.Icon(name, fallback)
    local art = ns.Art and ns.Art.icons
    if art and art[name] then return Theme.mediaDir .. "Icons\\icon-" .. name .. ".blp" end
    return fallback
end
-- The chrome piece's file and its nine-slice border ({ x, y } fractions, or true), or nil.
function Theme.Chrome(name)
    local c = ns.Art and ns.Art.chrome and ns.Art.chrome[name]
    if not c then return nil end
    return Theme.mediaDir .. "Chrome\\" .. name .. ".blp", c
end

-- Zone completion categories (spec §7.7), in display order: label, unit, icon. Icons: the
-- owner's painted set when present (design round 2), else client icons (the map is the Zones
-- tab's [verified-ingame]; the quest "!" and gryphon loaded in game, 2026-11-08).
Theme.categoryOrder = { "explore", "quests", "flights" }
Theme.category = {
    explore = { label = "Exploration", unit = "areas", icon = Theme.Icon("explore", "Interface\\Icons\\INV_Misc_Map_01") },
    quests = { label = "Quests", unit = "quests", icon = Theme.Icon("quests", "Interface\\GossipFrame\\AvailableQuestIcon") },
    flights = { label = "Flight paths", unit = "flight paths", icon = Theme.Icon("flights", "Interface\\Icons\\Ability_Mount_Gryphon_01") },
}

-- The painted card frame (frame-card, nine-slice) drawn over `frame`'s edge, `out` units
-- outside it, corners `corner` units square. The centre stays empty. Returns a handle with
-- SetShown(on) and SetVertexColor(r, g, b), or nil without the art.
function Theme.CardFrame(frame, corner, out, layer)
    local file, slice = Theme.Chrome("frame-card")
    if not file or type(slice) ~= "table" then return nil end
    corner, out = corner or 24, out or 4
    local sx, sy = slice.x, slice.y
    local pieces = {}
    local function piece(l, r, t, b)
        local tex = frame:CreateTexture(nil, layer or "OVERLAY", nil, 6)
        tex:SetTexture(file)
        tex:SetTexCoord(l, r, t, b)
        pieces[#pieces + 1] = tex
        return tex
    end
    local tl, tr = piece(0, sx, 0, sy), piece(1 - sx, 1, 0, sy)
    local bl, br = piece(0, sx, 1 - sy, 1), piece(1 - sx, 1, 1 - sy, 1)
    for _, c in ipairs({ tl, tr, bl, br }) do c:SetSize(corner, corner) end
    tl:SetPoint("TOPLEFT", frame, "TOPLEFT", -out, out)
    tr:SetPoint("TOPRIGHT", frame, "TOPRIGHT", out, out)
    bl:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -out, -out)
    br:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", out, -out)
    local top, bottom = piece(sx, 1 - sx, 0, sy), piece(sx, 1 - sx, 1 - sy, 1)
    top:SetPoint("TOPLEFT", tl, "TOPRIGHT"); top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
    bottom:SetPoint("TOPLEFT", bl, "TOPRIGHT"); bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
    local left, right = piece(0, sx, sy, 1 - sy), piece(1 - sx, 1, sy, 1 - sy)
    left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT"); left:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
    right:SetPoint("TOPLEFT", tr, "BOTTOMLEFT"); right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
    local h = {}
    function h:SetShown(on) for _, p in ipairs(pieces) do p:SetShown(on) end end
    function h:SetVertexColor(r, g, b) for _, p in ipairs(pieces) do p:SetVertexColor(r, g, b) end end
    return h
end

-- The painted header plate (plate-header, three-slice) with a centred gold title: Zone
-- Detail's "Next up" and the Overview's section headers. Without the art, a dark band.
-- Returns the frame; f.title is its FontString.
function Theme.Plate(parent, height)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(height)
    local file, slice = Theme.Chrome("plate-header")
    if file and type(slice) == "table" then
        local sx = slice.x
        local l, m, r = f:CreateTexture(nil, "BORDER"), f:CreateTexture(nil, "BORDER"), f:CreateTexture(nil, "BORDER")
        for _, t in ipairs({ l, m, r }) do t:SetTexture(file) end
        l:SetTexCoord(0, sx, 0, 1); m:SetTexCoord(sx, 1 - sx, 0, 1); r:SetTexCoord(1 - sx, 1, 0, 1)
        local endW = math.floor(height * 512 / 128 * sx + 0.5) -- the piece is 512x128
        l:SetPoint("TOPLEFT"); l:SetPoint("BOTTOMLEFT"); l:SetWidth(endW)
        r:SetPoint("TOPRIGHT"); r:SetPoint("BOTTOMRIGHT"); r:SetWidth(endW)
        m:SetPoint("TOPLEFT", l, "TOPRIGHT"); m:SetPoint("BOTTOMRIGHT", r, "BOTTOMLEFT")
    else
        local band = f:CreateTexture(nil, "BORDER")
        band:SetAllPoints(); band:SetColorTexture(0.12, 0.06, 0.02, 1)
    end
    f.title = Theme.Text(f, "md", "gold")
    f.title:SetPoint("CENTER", 0, 0)
    return f
end

-- A gilded progress bar (frame-bar housing, three-slice, over a dark well, with the bar-fill
-- gold): :Set(fraction, state) (state "complete" = gold, otherwise amber). Falls back to a
-- plain well and fill without the art. height in UI units.
function Theme.GildedBar(parent, height)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(height or 20)
    local file, slice = Theme.Chrome("frame-bar")
    local fill = Theme.Chrome("bar-fill")
    local inset = file and math.floor((height or 20) * 0.3 + 0.5) or 0
    local endW = file and math.floor((height or 20) * 0.9 + 0.5) or 0
    f.well = f:CreateTexture(nil, "BACKGROUND")
    f.well:SetPoint("TOPLEFT", endW * 0.5, -inset); f.well:SetPoint("BOTTOMRIGHT", -endW * 0.5, inset)
    f.well:SetColorTexture(0.055, 0.027, 0.004, 1)
    f.fill = f:CreateTexture(nil, "BORDER")
    f.fill:SetPoint("TOPLEFT", f.well, "TOPLEFT"); f.fill:SetPoint("BOTTOMLEFT", f.well, "BOTTOMLEFT")
    if fill then f.fill:SetTexture(fill) end
    if file and type(slice) == "table" then
        local sx = slice.x
        local l, m, r = f:CreateTexture(nil, "ARTWORK"), f:CreateTexture(nil, "ARTWORK"), f:CreateTexture(nil, "ARTWORK")
        for _, t in ipairs({ l, m, r }) do t:SetTexture(file) end
        l:SetTexCoord(0, sx, 0, 1); m:SetTexCoord(sx, 1 - sx, 0, 1); r:SetTexCoord(1 - sx, 1, 0, 1)
        l:SetPoint("TOPLEFT"); l:SetPoint("BOTTOMLEFT"); l:SetWidth(endW)
        r:SetPoint("TOPRIGHT"); r:SetPoint("BOTTOMRIGHT"); r:SetWidth(endW)
        m:SetPoint("TOPLEFT", l, "TOPRIGHT"); m:SetPoint("BOTTOMRIGHT", r, "BOTTOMLEFT")
    end
    function f:Set(frac, state)
        frac = math.max(0, math.min(1, frac or 0))
        local w = self.well:GetWidth() or 0
        if w <= 0 then w = (self:GetWidth() or 0) - endW end
        self.fill:SetWidth(math.max(0.001, w * frac))
        self.fill:SetShown(frac > 0)
        if fill then
            self.fill:SetTexCoord(0, math.max(0.001, frac), 0, 1)
            if state == "complete" then self.fill:SetVertexColor(1, 1, 1) else self.fill:SetVertexColor(1, 0.72, 0.42) end
        else
            local r, g, b = Theme.RGB(state == "complete" and "complete" or "todo")
            self.fill:SetColorTexture(r, g, b, 1)
        end
    end
    return f
end
Theme.layout.catBar = 6          -- category bar height (cards, rows)
Theme.layout.catIcon = 14
Theme.layout.catSlot = 14        -- one category's line on a card
Theme.layout.catGap = 4
Theme.layout.catCount = 58       -- "125/125" right of a bar (44 wrapped "42/68" in game)

-- Space the window's outside parts take (tabs right, legend below, portrait ring and glow).
Theme.outside = { left = 8, right = 64, top = 8, bottom = 50 }

Theme.fonts = { body = "Fonts\\FRIZQT__.TTF" }

-- Atlases and files, [verified-ingame] with /azfdiag skin unless noted.
Theme.atlas = {
    pane = "UI-Character-Info-General-BG",
    statBarBg = "common-stat-bar-BG",
    statBarFill = "common-stat-bar-white",
    statBarMask = "common-stat-bar-Mask",
    sideTab = "common-sidetab",
    sideTabHover = "common-sidetab-hover",
    sideTabSelected = "common-sidetab-selected",
    sideTabMask = "common-sidetab-mask",
    diamond = "UI-Frame-DiamondMetal", -- -CornerTopLeft, _..-EdgeTop, !..-EdgeLeft, ...
    pointer = "gamepad-largecursor-white",
    listHeader = "common-button-list-collapseExpand",
    rowHiSide = "charactercreate-customize-dropdown-linemouseover-side",
    rowHiMiddle = "charactercreate-customize-dropdown-linemouseover-middle",
}

Theme.zoneArtDir = "Interface\\AddOns\\Azerfolio\\Media\\Zones\\"

-- The zone's illustration (or the fallback), or nil if neither exists.
function Theme.ZoneArt(mapID)
    local art = ns.Art
    if art and art.zones and art.zones[mapID] then return Theme.zoneArtDir .. mapID .. ".blp" end
    if art and art.hasFallback then return Theme.zoneArtDir .. "fallback.blp" end
end

-- Where the Zone Detail banner's thin crop is centred, as a fraction of the art's height
-- (0 = top, 0.5 = middle, the default). For art whose landmark sits high; picked by eye from
-- the art, check with /azf shots banners.
Theme.bannerFocus = {
    -- Second pass after the in-game shots (WoWScrnShot_110726_193026-193036), which cut the tops.
    [1436] = 0.29, -- Westfall: lighthouse
    [1421] = 0.26, -- Silverpine Forest: Shadowfang Keep
    [1438] = 0.36, -- Teldrassil: the tree's palace
    [2482] = 0.22, -- Mount Hyjal: Nordrassil's crown
    [1430] = 0.27, -- Deadwind Pass: Karazhan
    [1442] = 0.24, -- Stonetalon Mountains: the peak
    [2521] = 0.28, -- Zephras Isle: the tower
}

-- Pure: the vertical texture coordinates that crop 2:1 zone art to a w×h banner, centred on
-- the zone's banner focus and kept inside the art. Returns top, bottom.
function Theme.BannerCrop(mapID, w, h)
    local f = 1
    if w and h and w > 0 then f = math.min(1, (h / w) * 2) end
    local centre = Theme.bannerFocus[mapID] or 0.5
    local top = math.max(0, math.min(1 - f, centre - f / 2))
    return top, top + f
end

-- The highlight atlas is plain white; the client dims it. Measured from the Reputation frame
-- (WoWScrnShot_110726_165420): a selected row is #5f5d5a over a #120a07 pane, about 0.32 white.
Theme.rowHighlightAlpha = { focus = 0.32, hover = 0.18 }

-- The native list-row highlight (rounded light bar) on a frame. Returns a handle with
-- SetShown(on). layer "HIGHLIGHT" makes it a mouse-hover highlight (dimmer).
function Theme.RowHighlight(frame, layer)
    local alpha = layer == "HIGHLIGHT" and Theme.rowHighlightAlpha.hover or Theme.rowHighlightAlpha.focus
    local L, A = Theme.layout, Theme.atlas
    local left = frame:CreateTexture(nil, layer or "BACKGROUND", nil, 1)
    local right = frame:CreateTexture(nil, layer or "BACKGROUND", nil, 1)
    local mid = frame:CreateTexture(nil, layer or "BACKGROUND", nil, 1)
    Theme.SetAtlas(left, A.rowHiSide); Theme.SetAtlas(right, A.rowHiSide); Theme.SetAtlas(mid, A.rowHiMiddle)
    right:SetTexCoord(1, 0, 0, 1)
    left:SetPoint("TOPLEFT"); left:SetPoint("BOTTOMLEFT"); left:SetWidth(L.rowHiSide)
    right:SetPoint("TOPRIGHT"); right:SetPoint("BOTTOMRIGHT"); right:SetWidth(L.rowHiSide)
    mid:SetPoint("TOPLEFT", left, "TOPRIGHT"); mid:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
    local h = { left, right, mid }
    for i = 1, 3 do h[i]:SetAlpha(alpha) end
    function h:SetShown(on) for i = 1, 3 do self[i]:SetShown(on) end end
    return h
end
Theme.files = {
    legendBg = 131071, -- background under the client's input legend
    resizeUp = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up",
    resizeHighlight = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight",
    resizeDown = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down",
    white = "Interface\\Buttons\\WHITE8X8",
    checkDone = "Interface\\RaidFrame\\ReadyCheck-Ready", -- green check, tinted gold [verified-ingame]
}

-- Gamepad glyph atlases (atlas names are case-insensitive). Shoulder/trigger names are
-- [verified-ingame]. Face-button names are from the client's InputIconTexture.lua
-- (wow-ui-source, forever branch) [external]; a drawn disc is the fallback.
Theme.glyphAtlas = {
    LB = { "Gamepad-Xbox1-Trigger-LB-Normal" },
    RB = { "Gamepad-Xbox1-Trigger-RB-Normal" },
    LT = { "Gamepad-Xbox1-Trigger-LT-Normal" },
    RT = { "Gamepad-Xbox1-Trigger-RT-Normal" },
    A = { "gamepad-xbox1-buttona-normal" },
    B = { "gamepad-xbox1-buttonb-normal" },
    X = { "gamepad-xbox1-buttonx-normal" },
    Y = { "gamepad-xbox1-buttony-normal" },
}
Theme.circleMask = 130924 -- PortraitFrameTemplate's CircleMask file [verified-ingame]
Theme.glyphFallback = {
    A = "padA", B = "padB", X = "padX", Y = "padY",
    LB = "padShoulder", RB = "padShoulder", LT = "padShoulder", RT = "padShoulder",
}

function Theme.RGB(name)
    local c = Theme.color[name] or Theme.color.white
    return c[1], c[2], c[3]
end

function Theme.SetFont(fs, sizeKey, flags)
    local size = Theme.size[sizeKey] or Theme.size.sm
    local ok = fs:SetFont(Theme.fonts.body, size, flags or "")
    if not ok and GameFontNormal then fs:SetFontObject(GameFontNormal) end
end

function Theme.Text(parent, sizeKey, colorName, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    Theme.SetFont(fs, sizeKey)
    fs:SetTextColor(Theme.RGB(colorName or "text"))
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(1, -1)
    return fs
end

function Theme.Solid(parent, colorName, layer, alpha)
    local tex = parent:CreateTexture(nil, layer or "BACKGROUND")
    local r, g, b = Theme.RGB(colorName)
    tex:SetColorTexture(r, g, b, alpha or 1)
    return tex
end

-- Does this client have the atlas? (nil when it can't be checked)
function Theme.HasAtlas(name)
    if not (C_Texture and type(C_Texture.GetAtlasInfo) == "function") then return nil end
    local ok, info = pcall(C_Texture.GetAtlasInfo, name)
    return ok and info ~= nil
end

-- Sets an atlas, returning true on success.
function Theme.SetAtlas(tex, name, useAtlasSize)
    if not tex.SetAtlas then return false end
    local ok, ret = pcall(tex.SetAtlas, tex, name, useAtlasSize)
    return ok and ret ~= false
end

local glyphCache = {}
-- The atlas for a gamepad button, or false if none of the candidates exists.
function Theme.GlyphAtlas(button)
    if glyphCache[button] ~= nil then return glyphCache[button] end
    local found = false
    for _, name in ipairs(Theme.glyphAtlas[button] or {}) do
        if Theme.HasAtlas(name) then found = name break end
    end
    glyphCache[button] = found
    return found
end

-- A gamepad button glyph. Uses the client's glyph atlas, or a drawn disc with the letter.
-- Reusable: Theme.SetGlyph changes the button it shows.
function Theme.Glyph(parent, button)
    local L = Theme.layout
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(L.glyphSize, L.glyphSize)
    f.art = f:CreateTexture(nil, "ARTWORK")
    f.art:SetSize(L.glyphArt, L.glyphArt)
    f.art:SetPoint("CENTER", 0, 0)
    f.disc = f:CreateTexture(nil, "ARTWORK")
    f.disc:SetAllPoints()
    local mask = f:CreateMaskTexture()
    if mask then -- round, like the client's face glyphs
        mask:SetAllPoints(f.disc)
        mask:SetTexture(Theme.circleMask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        pcall(f.disc.AddMaskTexture, f.disc, mask)
    end
    f.label = Theme.Text(f, "xs", "white")
    f.label:SetShadowOffset(0, 0)
    f.label:SetPoint("CENTER", 0, 0)
    Theme.SetGlyph(f, button)
    return f
end

function Theme.SetGlyph(f, button)
    local atlas = Theme.GlyphAtlas(button)
    if atlas and Theme.SetAtlas(f.art, atlas) then
        f.art:Show(); f.disc:Hide(); f.label:Hide()
        return
    end
    f.art:Hide()
    local r, g, b = Theme.RGB(Theme.glyphFallback[button] or "padShoulder")
    f.disc:SetColorTexture(r, g, b, 1)
    f.disc:Show()
    f.label:SetText(button)
    f.label:SetTextColor(Theme.RGB((button == "Y" or #button == 2) and "ink" or "white"))
    f.label:Show()
end

-- A nine-slice border from an atlas family ("UI-Frame-DiamondMetal": -CornerTopLeft,
-- _-EdgeTop, !-EdgeLeft, ...), corners at atlas size, edges stretched between them.
function Theme.NineSlice(frame, family, layer)
    local function piece(suffix)
        local t = frame:CreateTexture(nil, layer or "BORDER")
        local prefix = (suffix:find("Edge") and (suffix:find("Top") or suffix:find("Bottom")) and "_")
            or (suffix:find("Edge") and "!") or ""
        Theme.SetAtlas(t, prefix .. family .. "-" .. suffix, true)
        return t
    end
    local tl, tr = piece("CornerTopLeft"), piece("CornerTopRight")
    local bl, br = piece("CornerBottomLeft"), piece("CornerBottomRight")
    tl:SetPoint("TOPLEFT"); tr:SetPoint("TOPRIGHT"); bl:SetPoint("BOTTOMLEFT"); br:SetPoint("BOTTOMRIGHT")
    local top, bottom = piece("EdgeTop"), piece("EdgeBottom")
    top:SetPoint("TOPLEFT", tl, "TOPRIGHT"); top:SetPoint("TOPRIGHT", tr, "TOPLEFT")
    bottom:SetPoint("BOTTOMLEFT", bl, "BOTTOMRIGHT"); bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
    local left, right = piece("EdgeLeft"), piece("EdgeRight")
    left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT"); left:SetPoint("BOTTOMLEFT", bl, "TOPLEFT")
    right:SetPoint("TOPRIGHT", tr, "BOTTOMRIGHT"); right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
end
