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
    focus = { 1, 0.902, 0 },      -- GAMEPAD_SMARTNAV_CURSOR_COLOR [verified-ingame]
    black = { 0, 0, 0 },
    ink = hex("2b1a0c"),
    -- Fallback glyph discs, only if a face-button atlas can't be found
    padA = hex("5cb85c"), padB = hex("d9534f"), padX = hex("3d8bfd"), padY = hex("f0ad4e"),
    padShoulder = hex("cfc6b4"),
}

-- Type scale (nothing below 12: couch distance).
Theme.size = { xs = 12, sm = 14, md = 16, lg = 20, xl = 26, xxl = 32 }

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
}

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
}
Theme.files = {
    legendBg = 131071, -- background under the client's input legend
    resizeUp = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up",
    resizeHighlight = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight",
    resizeDown = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down",
    white = "Interface\\Buttons\\WHITE8X8",
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
