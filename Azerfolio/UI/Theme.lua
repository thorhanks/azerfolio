-- Visual constants from the approved design (mockups/DESIGN.md, mockups/style.css).
-- No style constants anywhere else. Data only at load time; the helpers touch the client
-- only when called.
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
    wowGold = hex("ffd100"),     -- GameFontNormal yellow: names, wordmark
    gold = hex("d4af37"),        -- inner frame line
    goldDark = hex("8a6d2f"),    -- frame edges, dividers
    focus = hex("ffe600"),       -- GAMEPAD_SMARTNAV_CURSOR_COLOR_CODE
    stone = hex("17120d"),       -- window background
    leather = hex("3a2416"),
    headerTop = hex("3b2a1a"),
    headerBottom = hex("1a120b"),
    footerTop = hex("1d140c"),
    footerBottom = hex("2a1d12"),
    tabTop = hex("2a1d12"),
    tabBottom = hex("3b2817"),
    tabActiveTop = hex("d6bd88"),
    tabActiveBottom = hex("b99a5e"),
    tabText = hex("cbbd9f"),
    parchment = hex("ead7ae"),
    ink = hex("2b1a0c"),
    inkSoft = hex("5a3f24"),
    white = hex("f3ead6"),
    muted = hex("9a8a70"),
    infoText = hex("e8dcc0"),
    divider = hex("4a3a26"),
    xpBg = hex("1a1030"),
    xpFill = hex("8a64e8"),
    black = { 0, 0, 0 },
    padA = hex("5cb85c"),
    padB = hex("d9534f"),
    padX = hex("3d8bfd"),
    padY = hex("f0ad4e"),
    padShoulder = hex("cfc6b4"),
}

-- Type scale (nothing below 12: couch distance).
Theme.size = { xs = 12, sm = 14, md = 16, lg = 20, xl = 26, xxl = 32 }

-- 4 px spacing grid.
Theme.space = { s1 = 4, s2 = 8, s3 = 12, s4 = 16, s6 = 24 }

Theme.layout = {
    headerHeight = 76,
    headerCompactHeight = 44,
    footerHeight = 60,
    contentInset = 10,   -- parchment inset from the window sides
    parchmentGrain = 0.3, -- alpha of the native parchment texture over the flat colour
    border = 3,          -- outer edge (goldDark)
    innerLine = 1,       -- inner line (gold)
    portrait = 56,
    xpWidth = 300,
    xpHeight = 16,
    closeSize = 28,
    tabPadX = 24,
    tabHeight = 40,
    glyphHeight = 22,
    glyphMinWidth = 24,
}

-- Font files. Titles use the client's engraved display face (closest to the design's Cinzel
-- caps); everything else uses the standard UI face.
Theme.fonts = {
    title = "Fonts\\MORPHEUS.TTF",
    body = "Fonts\\FRIZQT__.TTF",
}

-- Native textures, all [verified-ingame] in Phase 0 except where noted.
Theme.textures = {
    white = "Interface\\Buttons\\WHITE8X8",
    parchment = "Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal",
    portraitMask = "Interface\\CharacterFrame\\TempPortraitAlphaMask", -- [unverified]
    resizeUp = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up",        -- [unverified]
    resizeHighlight = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight",
    resizeDown = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down",
}

-- Gamepad glyph colours by button.
Theme.glyph = {
    A = { bg = "padA", fg = "white" },
    B = { bg = "padB", fg = "white" },
    X = { bg = "padX", fg = "white" },
    Y = { bg = "padY", fg = "ink" },
    LB = { bg = "padShoulder", fg = "ink" },
    RB = { bg = "padShoulder", fg = "ink" },
    LT = { bg = "padShoulder", fg = "ink" },
    RT = { bg = "padShoulder", fg = "ink" },
}

function Theme.RGB(name)
    local c = Theme.color[name] or Theme.color.white
    return c[1], c[2], c[3]
end

-- Applies a font to a FontString. role = "title" or "body"; size = a Theme.size key.
-- Falls back to the client's default font object if the file can't be set.
function Theme.SetFont(fs, role, sizeKey, flags)
    local size = Theme.size[sizeKey] or Theme.size.sm
    local ok = fs:SetFont(Theme.fonts[role] or Theme.fonts.body, size, flags or "")
    if not ok and GameFontNormal then fs:SetFontObject(GameFontNormal) end
end

function Theme.Text(parent, role, sizeKey, colorName, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    Theme.SetFont(fs, role, sizeKey)
    fs:SetTextColor(Theme.RGB(colorName or "white"))
    fs:SetShadowColor(0, 0, 0, 0.8)
    fs:SetShadowOffset(1, -1)
    return fs
end

function Theme.Solid(parent, colorName, layer, alpha)
    local tex = parent:CreateTexture(nil, layer or "BACKGROUND")
    local r, g, b = Theme.RGB(colorName)
    tex:SetColorTexture(r, g, b, alpha or 1)
    return tex
end

-- Vertical gradient from top colour to bottom colour. Falls back to the top colour if this
-- client's SetGradient signature differs.
function Theme.Gradient(parent, topName, bottomName, layer)
    local tex = parent:CreateTexture(nil, layer or "BACKGROUND")
    tex:SetColorTexture(1, 1, 1, 1)
    local tr, tg, tb = Theme.RGB(topName)
    local br, bg, bb = Theme.RGB(bottomName)
    local ok = type(CreateColor) == "function" and pcall(tex.SetGradient, tex, "VERTICAL",
        CreateColor(br, bg, bb, 1), CreateColor(tr, tg, tb, 1))
    if not ok then tex:SetColorTexture(tr, tg, tb, 1) end
    return tex
end

-- A 1-colour edge of `size` around a frame, drawn with four textures (crisp at any scale).
function Theme.Edge(frame, colorName, size, inset, layer)
    inset = inset or 0
    local r, g, b = Theme.RGB(colorName)
    local edges = {}
    for i = 1, 4 do
        local t = frame:CreateTexture(nil, layer or "BORDER")
        t:SetColorTexture(r, g, b, 1)
        edges[i] = t
    end
    edges[1]:SetPoint("TOPLEFT", inset, -inset); edges[1]:SetPoint("TOPRIGHT", -inset, -inset); edges[1]:SetHeight(size)
    edges[2]:SetPoint("BOTTOMLEFT", inset, inset); edges[2]:SetPoint("BOTTOMRIGHT", -inset, inset); edges[2]:SetHeight(size)
    edges[3]:SetPoint("TOPLEFT", inset, -inset); edges[3]:SetPoint("BOTTOMLEFT", inset, inset); edges[3]:SetWidth(size)
    edges[4]:SetPoint("TOPRIGHT", -inset, -inset); edges[4]:SetPoint("BOTTOMRIGHT", -inset, inset); edges[4]:SetWidth(size)
    return edges
end

-- A gamepad button glyph ("A", "B", "LB", ...): a coloured box with the label.
-- Reusable: Theme.SetGlyph changes the button it shows.
function Theme.Glyph(parent, button)
    local f = CreateFrame("Frame", nil, parent)
    f.bg = f:CreateTexture(nil, "ARTWORK")
    f.bg:SetAllPoints()
    Theme.Edge(f, "black", 1, 0, "OVERLAY")
    f.label = Theme.Text(f, "body", "xs", "ink")
    f.label:SetShadowOffset(0, 0)
    f.label:SetPoint("CENTER", 0, 0)
    Theme.SetGlyph(f, button)
    return f
end

function Theme.SetGlyph(f, button)
    local spec = Theme.glyph[button] or Theme.glyph.LB
    local L = Theme.layout
    local r, g, b = Theme.RGB(spec.bg)
    f.bg:SetColorTexture(r, g, b, 1)
    f.label:SetTextColor(Theme.RGB(spec.fg))
    f.label:SetText(button)
    f:SetSize(math.max(L.glyphMinWidth, (f.label:GetStringWidth() or 0) + 10), L.glyphHeight)
end
