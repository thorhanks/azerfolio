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
Theme.size = { xxs = 10, xs = 12, sm = 14, md = 16, lg = 20, xl = 26, xxl = 32, huge = 42 } -- huge: the zone's % in the dashboard header

-- 4 px spacing grid.
Theme.space = { s1 = 4, s2 = 8, s3 = 12, s4 = 16, s6 = 24 }

Theme.layout = {
    titleHeight = 21,          -- PortraitFrameTemplate title band
    headerHeight = 52,         -- character strip
    headerCompactHeight = 40,  -- one-line strip (clears the portrait ring)
    portraitClear = 66,        -- strip text starts right of the ring
    edgeInset = 2,             -- content inset from the frame edge (the metal edge overlays it)
    edgeCover = 2,             -- how far the frame's bottom metal edge still covers the content
                               -- (measured on WoWScrnShot_110926_202003: 12 units left about 10 visible)
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
    legendHeightTall = 58,     -- two info lines (Phase 15 step 2); Theme.outside.bottom covers it
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
    panelButton = 24, panelButtonPad = 16, panelButtonMin = 90, panelButtonPadTight = 10, -- the red panel buttons (W.PanelButton)
    panelButtonCompactSize = 11, -- a compact red button's label size (narrow toolbars; reached by scaling the label from size.sm)
    searchWidth = 150,
    searchMinWidth = 100,
    popupRow = 30,
    popupWidth = 200,
    -- The Zones cards use layout.dunTab's (Phase 16 task 7: three across, 16:10) and zoneCard.
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
    statBar = 12,              -- stacked / progress bar height in the panels
    -- Overview round 3 (owner, 2026-11-13): the window onto your class road (the Class tab's strip at
    -- its own scale, cropped around You) and its caption lines.
    classMini = 190,
    classMiniLine = 16,
    -- Phase 9 step 6 (mockups/DESIGN.md "Step 6"): plates, Tracked completion rows.
    plate = 34,                -- section header plate
    trackHead = 44,            -- Tracked completion: title and headline
    trackRow = 30,             -- one category row
    trackLabel = 104,          -- the category name's column
    trackCount = 92,           -- "done / counted"
    trackBar = 16,             -- gilded bar height in a row
    panelPad = 12,             -- inside a framed panel
    atlasPanel = 240,          -- the Overview's Atlas panel height (Phase 10)
    profTag = 180,             -- the Overview's Professions panel: "At cap · train Journeyman" (Phase 14; 150 cut "Train Journeyman now")
    profHead = 36,             -- its title line
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

-- A living Atlas (Phase 15 step 7, mockups/DESIGN.md "A living Atlas"): an untouched zone is a
-- sepia wash on the chart (its art desaturated, tinted warm, at half strength, the tile's base
-- clear); its colour fades in over the wash with the zone's % (colourMin + (1 - colourMin) * %);
-- a claimed tile gets the painted standard (Theme.Pennant) in its top-right corner.
Theme.atlasLiving = {
    washTint = { 1, 0.84, 0.6 },   -- vertex colour on the desaturated art (sepia)
    washAlpha = 0.5,
    colourMin = 0.18,              -- a touched zone's colour at 0%
    edge = { 0.16, 0.09, 0.03, 0.65 }, -- a thin dark-brown edge on unclaimed tiles
    shade = 0.5,                   -- the name's shade under a wash (0.8 over full colour)
    pennant = { 16, 32 },          -- the standard on an Atlas tile (1:2 canvas)
    pennantMini = { 9, 18 },       -- on the Overview's thumbnail
}

-- The painted standard's cloth for a side (Media\Banner\banner-<side>, listed in Data/Art.lua),
-- or nil without the art.
function Theme.Pennant(faction)
    local key = faction == "Horde" and "horde" or "alliance"
    local art = ns.Art and ns.Art.banner
    if art and art["banner-" .. key] then return Theme.mediaDir .. "Banner\\banner-" .. key .. ".blp" end
    return nil
end

-- Faction crests (Phase 15 step 8, mockups/DESIGN.md "Faction crests"): a painted heraldic
-- shield for twelve majors (Media\Chrome\crest-<key>; the Steamwheedle Cartel's shared by its
-- towns), else the blank shield with the faction's initial on it (Theme.CrestInitial).
Theme.crests = {
    [72] = "stormwind", [47] = "ironforge", [69] = "darnassus", [54] = "gnomeregan",
    [76] = "orgrimmar", [81] = "thunderbluff", [68] = "undercity", [530] = "darkspear",
    [169] = "steamwheedle", [21] = "steamwheedle", [369] = "steamwheedle", [470] = "steamwheedle", [577] = "steamwheedle",
    [529] = "argentdawn", [609] = "cenarion", [576] = "timbermaw",
}
Theme.crestTint = { unmet = 0.72 }   -- not met yet: desaturated and darkened, like the zone thumbnails were

-- The crest's file and whether it's the blank (which wants the initial on it); file nil when
-- not even the blank is painted (the caller draws a dark box with the initial).
function Theme.Crest(factionID)
    local key = factionID and Theme.crests[factionID]
    local file = key and Theme.Chrome("crest-" .. key)
    if file then return file, false end
    return Theme.Chrome("crest-blank"), true
end

-- The letter on a blank crest: the name's first character, a leading "The " left out.
function Theme.CrestInitial(name)
    local s = (tostring(name or ""):gsub("^[Tt]he%s+", ""))
    local c = s:match("^[%z\1-\127\194-\244][\128-\191]*") or ""
    return c ~= "" and c:upper() or "?"
end

-- The game's own sounds on celebrations (Phase 15 step 9, owner's pick in the mockup): sound kit
-- IDs for PlaySound, each plays in Forever [verified-ingame, /azfdiag sounds 2026-11-14]. 878 is
-- SOUNDKIT.IG_QUEST_LIST_COMPLETE (the quest-complete chime), 888 the level-up fanfare, 12197
-- the reputation level-up chime. A sound plays once, when the thing happens (with the alert when
-- the window is closed), not again when a waiting celebration plays.
Theme.sound = {
    cat = 878, stop = 878, rank = 878,
    claim = 888, road = 888, mastered = 888, exalted = 888,
    rep = 12197,
}

-- Zone completion categories (spec §7.7), in display order: label, unit, icon. Icons: the
-- owner's painted set when present (design round 2), else client icons (the map is the Zones
-- tab's [verified-ingame]; the quest "!" and gryphon loaded in game, 2026-11-08).
Theme.categoryOrder = { "explore", "quests", "flights" }
Theme.category = {
    explore = { label = "Exploration", unit = "areas", icon = Theme.Icon("explore", "Interface\\Icons\\INV_Misc_Map_01") },
    quests = { label = "Quests", unit = "quests", icon = Theme.Icon("quests", "Interface\\GossipFrame\\AvailableQuestIcon") },
    flights = { label = "Flight paths", unit = "flight paths", icon = Theme.Icon("flights", "Interface\\Icons\\Ability_Mount_Gryphon_01") },
}

-- Small category icons (Phase 15 step 3, review 2026-11-14): painted icons blur below 24 px, so
-- smaller places draw the flat glyph (Media\Chrome\glyph-<key>.blp, a white mask) tinted in the
-- body-text cream (owner's pick in the mockup, small-art.html G1). 24 px and up keep the painting.
Theme.glyphBelow = 24
Theme.glyphTint = "text"
function Theme.CategoryGlyph(key, size)
    if size and size >= Theme.glyphBelow then return nil end
    return (Theme.Chrome("glyph-" .. key))
end
-- Sets `tex` to category `key`'s icon for `size` (its drawn size): the glyph, tinted, below 24 px.
function Theme.SetCategoryIcon(tex, key, size)
    local meta = Theme.category[key]
    local glyph = Theme.CategoryGlyph(key, size)
    if glyph then
        tex:SetTexture(glyph)
        tex:SetVertexColor(Theme.RGB(Theme.glyphTint))
    else
        tex:SetTexture(meta and meta.icon)
        tex:SetVertexColor(1, 1, 1)
    end
    return glyph ~= nil
end
-- The same icon as an inline |T...|t escape for text, `size` px (the glyph carries its tint).
function Theme.CategoryInline(key, size)
    local glyph = Theme.CategoryGlyph(key, size)
    if glyph then
        local r, g, b = Theme.RGB(Theme.glyphTint)
        local c = function(v) return math.floor(v * 255 + 0.5) end
        return "|T" .. glyph .. ":" .. size .. ":" .. size .. ":0:0:64:64:0:64:0:64:" .. c(r) .. ":" .. c(g) .. ":" .. c(b) .. "|t"
    end
    local meta = Theme.category[key]
    return "|T" .. tostring(meta and meta.icon) .. ":" .. size .. ":" .. size .. "|t"
end

-- The painted card frame (frame-card, nine-slice; or the chrome piece `name`, e.g. the
-- Dungeons cards' card-frame-a) drawn over `frame`'s edge, `out` units outside it, corners
-- `corner` units square. The centre stays empty. Returns a handle with SetShown(on) and
-- SetVertexColor(r, g, b), or nil without the art.
-- A chrome piece's transparent margin outside its painted edge (share of the image), cropped
-- away so the edge sits on the frame's own edge (card-frame-a: the bar runs 10-27 of 1024).
Theme.chromeMargin = { ["card-frame-a"] = 10 / 1024 }
function Theme.CardFrame(frame, corner, out, layer, name)
    local file, slice = Theme.Chrome(name or "frame-card")
    if not file or type(slice) ~= "table" then return nil end
    corner, out = corner or 24, out or 4
    local sx, sy = slice.x, slice.y
    local m = Theme.chromeMargin[name or "frame-card"] or 0
    local pieces = {}
    local function piece(l, r, t, b)
        local tex = frame:CreateTexture(nil, layer or "OVERLAY", nil, 6)
        tex:SetTexture(file)
        tex:SetTexCoord(l, r, t, b)
        pieces[#pieces + 1] = tex
        return tex
    end
    local tl, tr = piece(m, sx, m, sy), piece(1 - sx, 1 - m, m, sy)
    local bl, br = piece(m, sx, 1 - sy, 1 - m), piece(1 - sx, 1 - m, 1 - sy, 1 - m)
    for _, c in ipairs({ tl, tr, bl, br }) do c:SetSize(corner, corner) end
    tl:SetPoint("TOPLEFT", frame, "TOPLEFT", -out, out)
    tr:SetPoint("TOPRIGHT", frame, "TOPRIGHT", out, out)
    bl:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -out, -out)
    br:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", out, -out)
    local top, bottom = piece(sx, 1 - sx, m, sy), piece(sx, 1 - sx, 1 - sy, 1 - m)
    top:SetPoint("TOPLEFT", tl, "TOPRIGHT"); top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
    bottom:SetPoint("TOPLEFT", bl, "TOPRIGHT"); bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
    local left, right = piece(m, sx, sy, 1 - sy), piece(1 - sx, 1 - m, sy, 1 - sy)
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
    -- Drawn before the first layout, the bar has no width yet and the fill came out empty
    -- (the Overview's Professions bars, WoWScrnShot_111426_125515): redo it when it's sized.
    -- f.onSized(f), if set, runs after (marks placed along the bar).
    f:SetScript("OnSizeChanged", function(self)
        if self.lastStack then self:SetStack(self.lastStack, self.lastTotal)
        elseif self.lastFrac then self:Set(self.lastFrac, self.lastState) end
        if self.onSized then self.onSized(self) end
    end)
    -- A stacked fill (the Overview's Zones row, Phase 15 step 2): parts { { n, kind }, ... } over
    -- total, left to right; kind "complete" (gold fill), "progress" (amber fill), "unknown"
    -- (grey) or nil (left as the dark well). 1 px of well between drawn parts.
    f.segs = {}
    function f:SetStack(parts, total)
        self.lastStack, self.lastTotal, self.lastFrac = parts, total, nil
        self.fill:Hide()
        local w = self.well:GetWidth() or 0
        if w <= 0 then w = (self:GetWidth() or 0) - endW end
        local x, i = 0, 0
        for _, p in ipairs(parts) do
            local n = p[1] or 0
            if n > 0 and (total or 0) > 0 then
                local sw = w * n / total
                if p[2] then
                    i = i + 1
                    local s = self.segs[i]
                    if not s then s = self:CreateTexture(nil, "BORDER"); self.segs[i] = s end
                    s:ClearAllPoints()
                    s:SetPoint("TOPLEFT", self.well, "TOPLEFT", x, 0)
                    s:SetPoint("BOTTOMLEFT", self.well, "BOTTOMLEFT", x, 0)
                    local last = x + sw >= w - 0.5
                    s:SetWidth(math.max(1, sw - (last and 0 or 1)))
                    if p[2] == "unknown" or not fill then
                        local r, g, b = Theme.RGB(p[2] == "complete" and "complete" or (p[2] == "progress" and "todo" or "dim"))
                        s:SetVertexColor(1, 1, 1)
                        s:SetColorTexture(r, g, b, p[2] == "unknown" and 0.35 or 1)
                    else
                        s:SetTexture(fill)
                        s:SetTexCoord(w > 0 and x / w or 0, w > 0 and math.min(1, (x + sw) / w) or 1, 0, 1)
                        if p[2] == "complete" then s:SetVertexColor(1, 1, 1) else s:SetVertexColor(1, 0.72, 0.42) end
                    end
                    s:Show()
                end
                x = x + sw
            end
        end
        for j = i + 1, #self.segs do self.segs[j]:Hide() end
    end
    function f:Set(frac, state)
        frac = math.max(0, math.min(1, frac or 0))
        self.lastFrac, self.lastState, self.lastStack = frac, state, nil
        for j = 1, #self.segs do self.segs[j]:Hide() end
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

-- Zone reputation (Phase 11, mockups/DESIGN.md "Zone reputation", style.css .repsec/.frep/
-- .repbar). Not a completion category: no state colours, the client's reaction colours.
Theme.reaction = {
    -- Reaction label text, 1..8 (Hated/Hostile red, Unfriendly orange, Neutral yellow, Friendly
    -- to Revered green, Exalted gold: owner 2026-11-09, mockups/DESIGN.md "Gold beyond completion").
    text = { hex("ff7a5c"), hex("ff7a5c"), hex("ff8a3d"), hex("ffd24d"), hex("4cd964"), hex("4cd964"), hex("4cd964"), hex("ffd24d") },
    -- The painted fill's tints (brighter than FACTION_BAR_COLORS: the pale fill isn't pure white).
    fill = { hex("f0644a"), hex("f0644a"), hex("f07018"), hex("ffd21e"), hex("22d046"), hex("22d046"), hex("22d046"), hex("ffc933") },
    -- The standing strip's plaque tints (style.css .repdist .dcell --c), and the emblem names.
    strip = { hex("f0644a"), hex("f0644a"), hex("f07018"), hex("ffd21e"), hex("22d046"), hex("22d046"), hex("22d046"), hex("ffc933") },
    emblem = { "rep-hated", "rep-hostile", "rep-unfriendly", "rep-neutral", "rep-friendly", "rep-honored", "rep-revered", "rep-exalted" },
    -- Fallback labels when the client's FACTION_STANDING_LABEL1..8 are missing.
    labels = { "Hated", "Hostile", "Unfriendly", "Neutral", "Friendly", "Honored", "Revered", "Exalted" },
    unmetFill = 0.55,          -- the bar's fill alpha for a faction not met yet
}
Theme.color.repWar = hex("ff5a4a")    -- "At war" tag
Theme.color.repRival = hex("d9b77a")  -- "Rival of" tag
Theme.color.repRowTop = hex("241a11") -- ledger row gradient (rgba(36,26,17,.85) to rgba(16,10,5,.9))
Theme.color.repRowBottom = hex("100a05")
Theme.color.repRowEdge = hex("3a2e22")
-- No ⚔ / ⇄ glyphs: the client's font draws them as boxes (WoWScrnShot_110826_222704).
Theme.repTags = { war = "At war", rival = "Rival of %s", unmet = "Not met yet" }
Theme.layout.rep = {
    head = 30,                 -- "Reputation" title, the divider under it
    divider = 12,              -- the painted divider's drawn height
    row = 32, rowTall = 44,    -- one faction; taller when the tags wrap under the name
    gap = 4,                   -- between rows
    pad = 12,                  -- inside a row, left and right
    crest = 24,                -- the faction's crest before the name (Phase 15 step 8)
    react = 76, ladder = 216, num = 120, colGap = 12,                 -- 740 px window
    wide = { react = 64, ladder = 148, num = 92, colGap = 8 },       -- the wide split's pane
    compactBelow = 640,        -- a narrower ledger (the minimum window) uses the wide split's columns
    sum = { react = 76, ladder = 260, num = 220, colGap = 12, row = 40 }, -- the faction page's summary
    -- The notched bar (round 3, style.css .repbar): frame-bar housing drawn 14 px at the ends
    -- and 6 px top and bottom; notches and the marker stick out past the well.
    bar = {
        height = 22, heightSum = 24, edgeX = 14, edgeY = 6,
        notch = 2, notchOut = 4, cap = 5,
        mark = 3, markOut = 3, glow = 6,
        notchPast = hex("c9a24a"), notchNext = hex("ffe08a"), notchAhead = hex("8a6a1c"),
    },
}

-- Reputation tab (Phase 12, mockups/DESIGN.md "Reputation tab", style.css .repdist/.tabrow/
-- .srow/.reach/.seesaw).
Theme.color.repGain = hex("7ee08a")   -- "+n today"
Theme.color.repWatch = { 1, 0.82, 0 } -- "Watched"
Theme.color.repFaint = hex("7a6e5c")  -- a "not for you" source
Theme.layout.repTab = {
    strip = 72,                -- the standing strip's height (cells 56 + padding; 56 and 68 put the text on the frame, owner 2026-11-09)
    cellText = 1,              -- gap between the count and the reaction label
    cellGap = 4, emblem = 32, emblemSmall = 24,
    cellPad = 4,               -- room between the plaque's frame and the cell's content; cells too narrow
                               -- for the emblem, the widest label and this stack the label under
    emblemStacked = 22,        -- the emblem beside the count when the label sits under both (Phase 15
                               -- step 2: names at every width; was only in the wide window)
    sum = 170,                 -- "Met n of m · Exalted n of m" column
    plaqueCorner = 10,         -- frame-plaque's drawn corner (12 px of its 256x128)
    clothTint = 0.62, clothEmpty = 0.18, -- the cloth fill's tint strength, full and empty cells
    row = 40, rowGap = 3,
    thumb = { 56, 30 }, thumbWide = { 44, 26 },   -- "Where to raise it" rows' zone art
    crest = 36, crestWide = 30, crestHero = 72,     -- the faction's crest: list row, wide split, page banner
    cols ={ react = 76, ladder = 260, num = 128, colGap = 12, row = 40 },
    wideCols = { react = 64, ladder = 148, num = 96, colGap = 8, row = 40 },
    splitList = 640,           -- the wide split's list column (style.css .repsplit)
    pageSum = { react = 76, ladder = 260, num = 220, colGap = 12, row = 40 },
    pageSumWide = { react = 70, ladder = 220, num = 170, colGap = 10, row = 40 },
    srcRow = 40, srcCount = 90, srcAmt = 80,
    seesawRow = 32,
    hatch = 6,                 -- the reach ghost's stripe spacing
    -- Glyphs for places that have no zone art [unverified: classic icon paths, checked by shots].
    kindIcon = {
        dungeon = "Interface\\Icons\\INV_Misc_Key_03", raid = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
        battleground = "Interface\\Icons\\INV_BannerPVP_02", profession = "Interface\\Icons\\Trade_BlackSmithing",
        class = "Interface\\Icons\\INV_Misc_Book_09", event = "Interface\\Icons\\INV_Misc_Ticket_Darkmoon_01",
        other = "Interface\\Icons\\INV_Misc_Note_01", none = "Interface\\Icons\\INV_Misc_QuestionMark",
    },
}
-- Dungeons tab (Phase 16 task 4; mockups/DESIGN.md "Dungeons tab", style.css .dcard/.drow/.tag).
Theme.color.dunTagNew = hex("ffe9a8")       -- "New in Forever" (style.css .tag.new)
Theme.color.dunTagNewBg = hex("5a3f12")     -- rgba(160,110,20,.35) over the card's dark foot
Theme.color.dunTagNewEdge = hex("9b7a3c")
Theme.color.dunTagBg = hex("0a0602")        -- a plain tag on the art (.dcard .dctags .tag)
Theme.color.dunTagEdge = hex("4a4038")
Theme.color.dunFaint = hex("857a68")        -- "No quests" and the like (.dq.none)
Theme.layout.dunTab = {
    cols = 3,                  -- cards across (owner, round 2: "three across")
    cardAspect = 10 / 16,      -- card height / width (16:10)
    cardGap = 24,              -- .dcards gap var(--s6)
    frameCorner = 6,           -- card-frame-a's corner, margin cropped (Theme.chromeMargin): the bar about 5 px, as the mockup's 7px border-image (owner: at 14 it read as an inner frame)
    frameOut = 0,              -- the bar on the card's own edge
    shade = 0.65,              -- share of the card the foot's dark gradient covers (.dcshade)
    pad = 14,                  -- the foot's and the tags' inset (.dcfoot left 14, .dctags 12)
    tag = 18, tagPad = 6, tagGap = 6, -- .tag line-height 18, padding 0 6px
    questBar = 6, questBarMax = 220, -- .dcq max-width 220
    check = 28,                -- the ✓ on a card with every quest done
    row = 52, thumb = { 64, 36 }, thumbWide = { 52, 30 },
    thumbSepia = 0.45,         -- the row thumbnail's desaturation (with a warm tint)
    lvCol = 132, bossCol = 84, questCol = 170, questColWide = 150, -- .drow grid columns
    splitList = 720,           -- the wide split's list column (.dunsplit)
    banner = 216,              -- the instance page's banner (round 3, idea 1)
}
-- Task 7: the Zones tab's cards are the Dungeons cards (DESIGN round 3 "Zones cards", style.css
-- .zcard2): the zone's art in the living Atlas's look, tags (.tag.rec, .fac), the painted standard
-- top right when claimed, the name and %, "Lv 10-20 · Eastern Kingdoms" and the category bars.
Theme.color.dunTagRecBg = hex("9c2a1a")     -- .tag.rec
Theme.color.dunTagRecEdge = hex("d0603c")
Theme.color.facAlliance = hex("3d6fd1")     -- .fac.Alliance (a tag's ground)
Theme.color.facHorde = hex("c0392b")
Theme.color.facContested = hex("b08a2e")
Theme.color.zoneCardPct = hex("ffd9a8")     -- .zcard2.progress .dcpct
Theme.layout.zoneCard = {
    sepia = 0.75,              -- the wash's desaturation (filter: sepia(.75) saturate(.55))
    washTint = { 0.92, 0.8, 0.62 }, -- warm and a little darker (brightness(.85))
    standard = { 24, 48 },     -- the painted standard top right when claimed (.zcstd, 1:2 cloth)
}
-- Task 7: Zone Detail's "Dungeon here" tiles (DESIGN round 2, style.css .duntile).
Theme.layout.dunTile = {
    h = 112, min = 260, gap = 12, -- .duntiles minmax(260px, 1fr), gap var(--s3)
    padX = 14, padY = 10, questBar = 220,
    footY = 14,                -- the quest line's lift off the bottom (at 10 it sat on frame A's band in game, WoWScrnShot_111526_145020)
}
-- The instance page (Phase 16 task 5; DESIGN round 5-6, style.css .dpbody/.dpanel/.dseals/.dbv/.dqv).
Theme.color.dunPanel = hex("0c0703")        -- .dpanel rgba(12,7,3,.62)
Theme.color.dunGain = hex("9fe39f")         -- a faction's "+amount" (.dfac .dfa)
Theme.color.dunNeed = hex("e0b070")         -- "needs an earlier quest" (.dqmeta i)
Theme.color.dunSealInk = hex("2a1608")      -- a seal's number on bronze
Theme.color.dunSealInkRare = hex("0a1430")  -- on the blue rare seal
Theme.color.dunSealInkOpt = hex("e8d4a4")   -- on the hollow seal
Theme.color.dunTagRare = hex("c8d8ff")      -- the Rare tag (.tag.rare)
Theme.color.dunTagRareBg = hex("1a2440")
Theme.color.dunTagRareEdge = hex("6c86c0")
Theme.color.dunTagReq = hex("ffb0a0")       -- a key's Required tag (.tag.req)
Theme.color.dunTagReqBg = hex("4a1410")
Theme.color.dunTagReqEdge = hex("a8352a")
Theme.layout.dunPage = {
    switch = 36,               -- the view switch bar (.dpvswitch)
    padX = 24, padY = 12,      -- .dov padding var(--s3) var(--s6)
    colGap = 16,               -- between the Overview's columns (.dov gap var(--s4))
    leftShare = 0.49,          -- Before you go's share (.dov 1fr / 1.05fr)
    panelPad = 14, panelHead = 30, frameCorner = 6,
    lvl = 24,                  -- the level line (.dlvl)
    key = 28, pick = 42, sub = 24, -- keys, a pickup row, "Pick up the quests"
    seal = 26, pill = 30, pillGap = 6, compactAfter = 12, -- The run (.dseal-b, .dseals.compact past 12)
    sealBig = 84,              -- the gold quests seal in the banner (.dseal)
    facTile = 36, facCols = 2, facMax = 4, crest = 28,
    questBar = 220,
    bossList = 340, bossRow = 34, -- .dbv 340px | loot; .dboss.compact
    lootHead = 64, tile = 50, tileGap = 6, icon = 36, -- .dloot.grid two columns, .dicon 36
    filterRow = 34, questRow = 38, chip = 26, stateCol = 64, -- .dqrow
    blur = 7, blurZoom = 0.55, -- the backdrop's soft copies (px apart) and how much of the painting it shows
}
-- The adventurer's road (Phase 16 task 6; DESIGN rounds 3-8, style.css .trail*/.trmed/.trpv;
-- the mockup's dunTrail). The strip is laid out in the mockup's px (H 410) and scaled down to
-- fit a shorter window, the preview card under it.
Theme.color.dunRoadGround = hex("1e140b")    -- under the painted regions (.trground)
Theme.color.dunRoadInk = hex("2a1608")       -- a plate's name, a stone's level (.trcart, .trlv)
Theme.color.dunRoadTag = hex("fff0c8")       -- You's tag (.tryou b rgba(255,240,200,.85))
Theme.color.dunRoadPost = hex("5a3f24")      -- a sign's post (.trsign::after)
Theme.color.dunRoadRaid = hex("ffb0a0")      -- the raids' sign (.trsign.raid)
Theme.color.dunRoadKey = hex("e2b84a")       -- a key in the preview (.trpvkey)
Theme.color.dunRoadChip = hex("4a3622")      -- a boss chip's edge (.trpvbosses span)
Theme.layout.dunRoad = {
    H = 410, step = 156, pad = 130,       -- the strip's height, between medallions, the ends (design px)
    fade = 80,                             -- a region's cross-fade into the next (.trregion mask 80px)
    top = 132, bottom = 86, zig = 80,      -- medallions: clear of the signs and the bottom; off the road (round 8)
    signMin = 110,                         -- the first sign's middle at least this far in (round 7)
    tex = { 1024, 512 },                   -- a region panel (road1..6)
    flat = 0.556,                          -- the road's height share without painted lanes (ROAD 228 of 410)
    minScale = 0.62,                       -- the strip's smallest scale (the minimum window)
    med = 104, medFit = 118,               -- a medallion; your-level ones larger (.trmed.fit)
    artShare = 0.78,                       -- the painting inside the painted ring (round 8: 78%)
    glow = 1.55,                           -- the soft glow (glow-soft) per medallion size
    focusScale = 1.12,                     -- .focused.trmed scale(1.12)
    sepia = 0.3, sepiaFar = 0.78,          -- partial sepia; far above you and untouched (.trmed.far)
    plate = 28, plateCap = 24, platePad = 28, plateFont = 14, -- one-line name plates (round 8)
    plateRows = { 39, 88 }, plateCapPx = 64, plateTex = { 512, 128 }, -- the cartouche's band and curled ends
    stone = 44, stoneDrop = 4,             -- level stones (round 8: two digits fit the face)
    you = 34,                              -- your portrait coin (no tag: owner 2026-11-15)
    sign = 28, signMinW = 150, signPad = 40, signTop = 8, post = { 3, 30 },
    gold = 7, goldStep = 6,                -- the gold progress up to You (round 7: 7 px)
    check = 24, newTag = 18,
    preview = 170, previewMin = 132, previewMax = 230, -- the preview card under the strip
    previewArt = 320, previewPadY = 12, previewPadX = 24, previewGap = 16,
    chips = 7, chip = 22, chipPad = 8, chipGap = 6,
    margin = 190,                          -- keep the focused medallion this far inside the view (px, scaled)
    openAt = 0.35,                         -- the road opens with You this far across the view
}

Theme.repGroups = { home = "Home", zones = "Zones", instances = "Dungeons & raids", bgs = "Battlegrounds",
    profs = "Professions", other = "Class and events", none = "No known quests", unknown = "Sources not known" }
Theme.repKinds = { zone = "Zone", dungeon = "Dungeon", raid = "Raid", battleground = "Battleground",
    profession = "Profession", class = "Class quests", event = "Event", other = "Other quests" }

-- Class tab (Phase 13, mockups/DESIGN.md "Class tab", style.css .cjourney/.cmapart/.cnode/
-- .chero/.cstep). The strip is a stand-in drawn from the curated stops until the painted strip
-- (one per class and side) exists.
Theme.color.classRoad = hex("d8c08a")      -- the road (unlit)
Theme.color.classBead = hex("5b4a32")      -- a quest not done yet
Theme.color.classBeadOn = hex("fff1b0")    -- a quest done
Theme.color.classPeach = hex("ffd9a8")     -- open now / your next step / in progress text
Theme.color.classCairn = hex("8c826f")     -- a side path's dead end
Theme.color.classLabel = hex("140c06")     -- the You tag's plate
Theme.color.className = hex("fff3d6")      -- a stop's name on the map (round 3: outlined text, no plate)
Theme.color.classNameDim = hex("d8ccb0")   -- a later stop's name
-- Round 4, the antique map: ink on parchment.
Theme.color.classInk = hex("2e2014")       -- a stop's name, the level numeral, the You tag
Theme.color.classInkGold = hex("8a5d08")   -- a finished stop's name
Theme.color.classInkFaded = hex("6b5a44")  -- a later stop's name
Theme.color.classInkFocus = hex("000000")  -- the focused stop's name
Theme.color.classParchment = hex("efe1bd") -- the paper halo behind ink text, the uncharted wash, the rail
Theme.color.classRedInk = hex("a8352a")    -- the cartographer's red ring around a stop open now
Theme.color.classRedInkLight = hex("ff8a70") -- "8 to train" on the dark plaque
Theme.color.classNotch = hex("c9a24a")     -- brass: your portrait's ring
Theme.layout.classTab = {
    strip = 430, stripWide = 560,          -- the journey strip's column
    plaque = 84,                           -- "The Paladin's Road", the counts and the Next line (round 2; two
                                           -- lines: one cut it off at 430 px, WoWScrnShot_110926_224436)
    mapW = 420,                            -- logical width of node positions (Theme.classStrip)
    node = 46, sideNode = 34, endNode = 52, ring = 3,
    endLabel = 64,                         -- room under the road's end for its label
    factCols = { 0.40, 0.14 },             -- Where it starts, Level (a number since round 2); Travels to
                                           -- takes the rest (22% wrapped it over five lines, WoWScrnShot_110926_224439)
    glow = 18,                             -- the open-now glow past the seal
    road = 13, roadStep = 4, roadEdge = 2, -- road band: square size, spacing and its dark edge (logical)
    sideDot = 5, sideStep = 11,            -- a side path's dotted track
    bead = 9, sideBead = 7,
    label = 240, labelGap = 10, labelPad = 6, -- (200 cut "Summon Charger · 11 quests", WoWScrnShot_110926_224440)
    you = 46,                              -- your portrait token (round 5: a road stop's size, no tag)
    coin = 52, sideCoin = 40, heroCoin = 80, -- the class coin on finished stops (round 3, owner 2026-11-10)
    pip = 7, sidePip = 6,                  -- quest pips (round 5: a row under the name, px)
    pipGap = 2, pipsGap = 3,               -- between pips; between the cartouche and the pips row (px)
    pipRing = 31, sidePipRing = 23,        -- the room kept around a node (logical; You and the milestones keep clear)
    redDots = 28, redDot = 2,              -- round 4: the red cartographer's ring (dots, px)
    -- Round 5: the road band, stamped along the curve from road-band / road-band-gold (256x64, the
    -- band in 18 rows). Each stamp shows the next window of the texture, so the band runs on
    -- without seams. Thickness and stamp spacing in logical units.
    bandRoad = 10, bandSide = 6, bandStep = 6, bandSideStep = 5,
    bandRows = 18, bandPx = 64, bandTexW = 256,
    -- Round 5: the cartouche behind a stop's name (cartouche.png 512x128: the ribbon in rows
    -- 33-94, its notched ends within 48 px of each side), px.
    cartH = 22, cartCap = 13, cartPad = 2,
    cartRows = { 33, 95 }, cartCapPx = 48, cartTex = { 512, 128 },
    -- Round 5: abilities as rune milestones (px) at the road's edge; the spots a stone tries
    -- (logical, across the road); stones closer than mileMerge (logical) merge into one.
    mile = 26, mileOffsets = { 17, -17, 37, -37, 54, -54 }, mileMerge = 40,
    focusRingPad = 7,                      -- round 5: the painted red focus ring past the coin (px each side)
    stepsWide = 560,                       -- wide pane: the steps column; the facts go beside it
    wideFacts = 860,                       -- pane width from which the facts go beside the steps
    labelPush = 4,                         -- gap kept between node labels pushed apart
    inkFocusDots = 72, inkFocusDot = 2, inkFocusGap = 3, -- round 5: the red-ink focus circle on the map
    dullCoin = { open = { 0.86, 0.66, 0.44, 1 }, later = { 0.62, 0.5, 0.36, 0.75 } }, -- round 5 test: unfinished coins (bronze tint)
    scrollBar = 6,                         -- round 5: the map's slim scrollbar (the rail is gone)
    hero = 132, heroScore = 140,
    facts = 46, stepRow = 40, stepIcon = 22, stopRow = 40,
    bar = 18,
}
-- The stand-in strip's sky, top to bottom (style.css #csky): dawn over the start, gloom at the end.
Theme.classSky = { { 0, hex("f7dc9a") }, { 0.12, hex("d9b46a") }, { 0.3, hex("7f9a63") }, { 0.62, hex("4d5a3c") },
    { 0.82, hex("2c2e27") }, { 1, hex("15130f") } }
-- Hand-placed node positions per class and side, by stop key, on a mapW-wide strip H tall. With
-- a painted strip (Media\Strips\<class>-<side>.blp, 1:4, so H = 4 * mapW) they sit in its corridor
-- beside their landmarks, measured on the art. A road without its own table is laid out by the page.
Theme.classStrip = {
    WARRIOR = {
        -- Round 5 strip (2026-11-12, made with Codex from art/prompts.md): the training yard, the
        -- city tavern, the cave in red hills; the forge, the dwarven gate and the elven arbour
        -- (the three armourers' side paths); the fighting pit, the windswept stone circle, the
        -- broken standard at the red canyon pass, the star.
        Alliance = { H = 1680, ["end"] = { 210, 1640 }, intro = { 210, 95 }, stance = { 240, 213 }, shieldsmith = { 100, 484 },
            grimand = { 70, 690 }, klockmort = { 330, 655 }, mathiel = { 300, 750 },
            berserker = { 170, 900 }, whirlwind = { 130, 1010 }, kinship = { 175, 1484 } },
        -- The spiked-hut camp, the watch tower, the tents and giant bones; the troll village, the
        -- mesa and the crypt stairs (side paths); the fighting pit, the snowy stone circle, the
        -- broken standard below the dark gate.
        Horde = { H = 1680, ["end"] = { 210, 1640 }, intro = { 211, 75 }, stance = { 184, 150 }, giants = { 110, 270 },
            gauntlets = { 70, 700 }, helm = { 320, 600 }, legguards = { 335, 770 },
            berserker = { 180, 910 }, whirlwind = { 100, 980 }, kinship = { 200, 1440 } },
    },
    -- Round 5 strips (2026-11-12, Codex from art/prompts.md): stops measured on each strip's
    -- landmarks (art/review/<class>-<side>-path.png); road stops snap onto the traced lane.
    HUNTER = {
        -- The lodge, the beast's den under the roots, the hermit's camp on the crimson coast.
        Alliance = { H = 1680, ["end"] = { 210, 1640 }, intro = { 215, 100 }, pet = { 250, 200 }, charm = { 270, 1400 } },
        -- The hut camp, the tent village with its water pump, the hermit's camp.
        Horde = { H = 1680, ["end"] = { 210, 1640 }, intro = { 210, 95 }, pet = { 200, 200 }, charm = { 280, 1400 } },
    },
    MAGE = {
        -- The abbey, the violet lake, the violet-roofed towers, the haunted tower, the stilt hut
        -- in the swamp (two stops), the arcane tower on the cliffs, the sunken temple.
        Alliance = { H = 1680, ["end"] = { 210, 1640 }, intro = { 215, 95 }, ten = { 130, 240 }, robe15 = { 230, 280 },
            robe26 = { 110, 730 }, wand = { 150, 950 }, orb = { 160, 1030 }, morphaz = { 250, 1310 }, krellian = { 150, 1540 } },
        -- The chapel camp, the snapdragon farm, the green-lit crypt, the violet satyr pools, the
        -- stilt hut, the arcane tower, the sunken temple.
        Horde = { H = 1680, ["end"] = { 210, 1640 }, intro = { 200, 100 }, ten = { 130, 160 }, robe15 = { 110, 250 },
            robe26 = { 110, 770 }, wand = { 107, 961 }, orb = { 147, 1078 }, morphaz = { 230, 1310 }, krellian = { 150, 1540 } },
    },
    PRIEST = {
        -- The abbey, the village well, the cathedral, the white shrine, the mountain gate, the
        -- sunken temple, the chapel in a shaft of light. The first four are spread 60-85 units apart
        -- along the lane (Garments and Desperate Prayer snapped onto one spot, owner 2026-11-12).
        Alliance = { H = 1680, ["end"] = { 210, 1640 }, intro = { 175, 85 }, garments = { 210, 145 }, spell10 = { 138, 215 },
            grace = { 192, 305 }, spell20 = { 240, 660 }, morphaz = { 150, 1200 }, eris = { 250, 1420 } },
        -- The hut camp, the spiked fort town, the troll shrine, the canyon city, the sunken temple,
        -- the chapel in the light.
        Horde = { H = 1680, ["end"] = { 210, 1640 }, intro = { 205, 95 }, garments = { 150, 165 }, spell10 = { 220, 230 },
            spell20 = { 60, 670 }, morphaz = { 150, 1220 }, eris = { 240, 1430 } },
    },
    ROGUE = {
        -- The abbey, the harbour, the windmill farm and the lakeside bridge (the lane passes the farm first,
        -- so the two stops sit in road order between them), the hidden manor, the
        -- ruined keep, the crimson monastery (side path), the totem huts on the coast.
        Alliance = { H = 1680, ["end"] = { 210, 1640 }, intro = { 215, 95 }, ten = { 240, 235 }, sixteen = { 241, 342 },
            zanzil = { 122, 416 }, ravenholdt = { 130, 600 }, syndicate = { 230, 700 }, bhossca = { 60, 725 }, azure = { 230, 1460 } },
        -- The hut camp, the lantern-lit cleft, the violet dome, the mill village, the manor, the
        -- keep, the monastery (side path), the totem huts.
        Horde = { H = 1680, ["end"] = { 210, 1640 }, intro = { 210, 95 }, ten = { 260, 200 }, sixteen = { 250, 320 },
            zanzil = { 150, 420 }, ravenholdt = { 130, 590 }, syndicate = { 230, 700 }, bhossca = { 60, 720 }, azure = { 200, 1450 } },
    },
    SHAMAN = {
        -- The mountain hall, the stone totem, the dam and brazier, the spring, the stone circle,
        -- the bramble warren.
        Alliance = { H = 1680, ["end"] = { 210, 1640 }, intro = { 224, 74 }, earth = { 201, 147 }, fire = { 170, 250 },
            water = { 140, 750 }, air = { 200, 900 }, tempest = { 120, 960 } },
        -- The hut camp, the earth totem, the brazier spires, the oasis, the rock needles, the
        -- brambles, the snowy stone circle, the academy on its island.
        Horde = { H = 1680, ["end"] = { 210, 1640 }, intro = { 205, 95 }, earth = { 150, 140 }, fire = { 250, 180 },
            water = { 120, 660 }, air = { 230, 760 }, tempest = { 120, 870 }, mastery = { 180, 1170 }, darkreaver = { 150, 1430 } },
    },
    DRUID = {
        -- The hollow tree, the moonlit stone ring, the walled garden (side path), the poison bog,
        -- the cove shrine, the cat statue, the hermit's camp in the crater jungle.
        Alliance = { H = 1680, ["end"] = { 210, 1640 }, intro = { 230, 90 }, bear = { 260, 215 }, nature = { 75, 160 },
            poison = { 140, 360 }, aquatic = { 240, 640 }, cat = { 150, 740 }, torwa = { 230, 1480 } },
        -- The tents on the mesa, the moonlit lake, the totem mesa (side path), the savanna outpost
        -- (panel 1 v2, Phase 15 step 10: the Horde's poison quests are in the Barrens, not a bog),
        -- the cove shrine, the cat statue, the crater camp.
        Horde = { H = 1680, ["end"] = { 210, 1640 }, intro = { 210, 95 }, bear = { 200, 215 }, nature = { 60, 130 },
            poison = { 180, 370 }, aquatic = { 230, 690 }, cat = { 130, 740 }, torwa = { 230, 1480 } },
    },
    WARLOCK = {
        -- The abbey, the cottage, the violet-cellared tavern, the seer's hut, the broken well
        -- (side), the carved hall, the rune tent and the cliff tower (sides), the port, the green
        -- forest, the crater (side), the demonic shrine, the ruined elven city (side).
        Alliance = { H = 1680, ["end"] = { 210, 1640 }, intro = { 210, 95 }, imp = { 180, 160 }, void = { 240, 220 },
            succubus = { 150, 390 }, soranruk = { 330, 410 }, felhunter = { 230, 630 }, robe = { 75, 790 }, orahil = { 360, 760 },
            felsteed = { 220, 940 }, imps = { 180, 1150 }, kroshius = { 60, 1280 }, dreadsteed = { 260, 1400 }, suppression = { 70, 1450 } },
        -- The starting camp, the graveyard, the crypt temple, the seer's hut, the well (side), the
        -- crypt stairs, the tent and the tower (sides), the port, the forest, the crater (side),
        -- the shrine, the ruins (side).
        Horde = { H = 1680, ["end"] = { 210, 1640 }, intro = { 210, 95 }, imp = { 160, 160 }, void = { 240, 220 },
            succubus = { 150, 410 }, soranruk = { 330, 420 }, felhunter = { 230, 620 }, robe = { 80, 735 }, orahil = { 355, 770 },
            felsteed = { 220, 940 }, imps = { 180, 1150 }, kroshius = { 60, 1280 }, dreadsteed = { 260, 1410 }, suppression = { 70, 1455 } },
    },
    PALADIN = {
        -- The round 5 strip (2026-11-10: the zone art's painting in antique colours, a narrow lane
        -- traced into Data/StripPaths.lua): the abbey, the cathedral city, the farm, the autumn
        -- wood's glowing glade, the open hills below the wood, the camp, the ossuary and ruined gate,
        -- the star at the bottom. Road stops snap onto the lane. Nobility (40) sits well below Valor
        -- (20) so twenty levels of milestones get room (WoWScrnShot_111026_200757).
        Alliance = { H = 1680, ["end"] = { 210, 1640 }, intro = { 210, 100 }, divinity = { 250, 215 }, valor = { 190, 680 },
            artifact = { 107, 905 }, nobility = { 200, 1065 }, mightstone = { 300, 1262 }, charger = { 190, 1400 } },
        -- The chapel among dead pines, the palisade camp, the lakeside fortress and its walled
        -- garden (side path), the crypt stairs, the shrine and the mausoleum (the lane passes the shrine
        -- first; the two stops sit in road order between them); open
        -- country after level 20.
        Horde = { H = 1680, ["end"] = { 210, 1640 }, intro = { 215, 102 }, light = { 184, 154 }, keep = { 243, 250 },
            home = { 70, 250 }, divinity = { 240, 630 }, incident = { 250, 735 }, moonsilver = { 130, 810 } },
    },
}

-- The painted profession banners: where each scene's subject sits in the 2:1 image (0 top .. 1
-- bottom). The page centres it in the part of the banner above the road strip. Default 0.62:
-- the Codex banners (2026-11-14) put the forge, the mine mouth, the hearth a little below the
-- middle. Tune per banner after looking at it in game.
Theme.profBannerFocus = {}

-- Professions tab (Phase 14; mockups/DESIGN.md "Professions tab", round 2: rail and views).
Theme.color.profWarn = hex("e0503c")   -- "At cap": skill-ups are lost until you train (the rail's red dot)
Theme.color.profGo = hex("e08a3c")     -- train now / recipes to learn (orange)
Theme.color.profReady = hex("7cc46a")  -- a tracked recipe you have everything for; have >= need
Theme.color.profShort = hex("d79a7a")  -- have < need (red-tan)
Theme.color.profTracked = hex("6fa8ff") -- the Tracked tag (blue)
-- Phase 15 step 4 (R9): the game's skill-up colours (its TradeSkillTypeColor), by
-- Enum.TradeskillRelativeDifficulty name; "red" for a gathering node you can't gather yet.
Theme.color.diffOptimal = { 1.00, 0.50, 0.25 }
Theme.color.diffMedium = { 1.00, 1.00, 0.00 }
Theme.color.diffEasy = { 0.25, 0.75, 0.25 }
Theme.color.diffTrivial = { 0.50, 0.50, 0.50 }
Theme.color.diffRed = { 1.00, 0.13, 0.13 }
Theme.diffColor = { optimal = "diffOptimal", medium = "diffMedium", easy = "diffEasy", trivial = "diffTrivial", red = "diffRed" }
Theme.diffWord = { optimal = "orange", medium = "yellow", easy = "green", trivial = "grey", red = "red" }
Theme.diffSays = { optimal = "always gives skill", medium = "usually gives skill", easy = "rarely gives skill", trivial = "no skill", red = "can't be gathered yet" }

-- (R10) An item quality's colour (0 poor .. 4 epic and up) from the game (C_Item.GetItemQualityColor
-- [verified-ingame]), else the classic values; nil for an unknown quality.
local QUALITY_FALLBACK = { [0] = { 0.62, 0.62, 0.62 }, [1] = { 1, 1, 1 }, [2] = { 0.12, 1, 0 }, [3] = { 0, 0.44, 0.87 }, [4] = { 0.64, 0.21, 0.93 }, [5] = { 1, 0.5, 0 } }
function Theme.QualityRGB(q)
    if type(q) ~= "number" then return nil end
    if C_Item and type(C_Item.GetItemQualityColor) == "function" then
        local ok, r, g, b = pcall(C_Item.GetItemQualityColor, q)
        if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then return r, g, b end
    end
    local c = QUALITY_FALLBACK[q]
    if c then return c[1], c[2], c[3] end
    return nil
end
Theme.layout.profTab = {
    rail = 116,          -- the rail's width (mockup 116 px)
    railRow = 84,        -- coin, name, skill (74 let "33 / 75" spill past the row, owner 2026-11-14)
    railGlow = { 84, 0.85 }, -- the selected trade's warm glow behind its coin (glow-soft, added): size, alpha
    railHalo = { { 66, 0.10 }, { 56, 0.16 }, { 48, 0.24 } }, -- its stand-in without glow-soft: circle size, alpha
    railCoin = 40,
    railGap = 14,        -- between rail entries when there's room (owner, 2026-11-14); shrinks to space.s1 in a short window
    railGroup = 26,      -- "Primary" / "Secondary"
    switch = 38,         -- the view switch (Journey · Recipes · Gather)
    bannerMax = 220,     -- the banner (the road strip sits below it since 2026-11-14; mockup 220 px)
    bannerMin = 130,     -- at the window's minimum size
    listsMin = 200,      -- Next up | Tracked keep at least this much
    -- Phase 15 step 4 (R7, owner: "Band 142, uncut"): the strip is as tall as the painting can be
    -- shown without cutting a landmark (roadArtSpan stays in view), between road and roadMax:
    -- 138 at the 1160 window, 115 at the minimum width, 190 in the wide window.
    road = 112,          -- the strip's least height
    roadMax = 190,
    roadArtSpan = { 20, 1815 }, -- the painting's columns that must show (first village .. last forge)
    roadBand = 16,       -- the road band's thickness (px; the Class tab's road-band, 18 of 64 rows)
    roadShut = 0.55,    -- the band past your cap, behind the gate (alpha, desaturated)
    roadFrame = 18, roadFrameOut = 5, -- its gilded card frame: corner size, how far outside the strip
    roadGap = 14,        -- between Next up / Tracked and the road strip under them (owner, 2026-11-14)
    roadFoot = 20,       -- from the page's bottom edge to the road strip (pinned to the foot; 12 read tight, owner 2026-11-14)
    roadArt = { 2048, 256 }, -- the painted skill road (Media\ProfRoads), shown cover-fit
    roadArtLane = 150,   -- the art's lane row (process-art.ps1 $RoadLaneRow puts it there)
    roadPadL = 30,       -- 1 sits here
    roadPadR = 80,       -- room for the coin after 300
    stone = { 30, 34 },  -- a rank stone (milestone art)
    you = 30,            -- your portrait on the road
    endCoin = 52,        -- the profession coin at 300
    nextRow = 46,        -- a Next up line (title and sub line)
    ingRow = 20,         -- an ingredient line in a Tracked card
    cardHead = 44,       -- a Tracked card's head (name and summary)
    -- Recipes view (round 2: toolbar, the list on the left, the focused recipe on the right)
    toolbar = 40,
    detail = 380,        -- the focused recipe's column (mockup 380 px)
    recipeRow = 28,
    recipeIcon = 22,     -- the crafted item's icon on a row (Phase 15 step 4)
    detailIcon = 40,     -- and in the recipe detail
    ingIcon = 16,        -- on an ingredient line
    recipeSrc = 64,      -- "Trainer" / "Vendor" / "Drop"
    recipeSkill = 92,    -- "learn 40" / "grey at 110" / "grey" (76 wrapped "grey at 100", WoWScrnShot_111426_195940)
    recipeState = 72,    -- "Learn now" / ✓ / "from 55"
    detailLine = 34,     -- a source or an ingredient line (text and a sub line)
    detailLinePad = 4,   -- such a line's text from its top edge
    detailLeft = 64,     -- "4 / 1" or the source tag
    gatherRow = 40,
    tones = {            -- banner stand-in tints (top, bottom) until the painted banners exist
        alchemy = { "3a2a4a", "120a18" }, blacksmithing = { "4a2a14", "140804" }, enchanting = { "34224e", "0e0816" },
        engineering = { "3a3424", "100e08" }, herbalism = { "26402a", "08120a" }, leatherworking = { "4a3420", "140c06" },
        mining = { "38343a", "0e0c10" }, skinning = { "463420", "120c06" }, tailoring = { "402a3a", "120810" },
        cooking = { "4a3418", "140c04" }, firstaid = { "4a2424", "140606" }, fishing = { "203a4a", "060e14" },
    },
}

-- A painted nine-slice (a chrome piece with { x, y } border fractions) around `frame`, corners
-- `corner` units, `out` units outside it. Returns a handle with SetShown / SetVertexColor /
-- SetAlpha, or nil without the art.
-- (Not Theme.NineSlice: that one draws an atlas family, below.)
function Theme.ChromeNineSlice(frame, name, corner, out, layer, sub)
    local file, slice = Theme.Chrome(name)
    if not file or type(slice) ~= "table" then return nil end
    out = out or 0
    local sx, sy = slice.x, slice.y
    local pieces = {}
    local function piece(l, r, t, b)
        local tex = frame:CreateTexture(nil, layer or "BORDER", nil, sub or 0)
        tex:SetTexture(file); tex:SetTexCoord(l, r, t, b)
        pieces[#pieces + 1] = tex
        return tex
    end
    local tl, tr = piece(0, sx, 0, sy), piece(1 - sx, 1, 0, sy)
    local bl, br = piece(0, sx, 1 - sy, 1), piece(1 - sx, 1, 1 - sy, 1)
    for _, c in ipairs({ tl, tr, bl, br }) do c:SetSize(corner, corner) end
    tl:SetPoint("TOPLEFT", frame, "TOPLEFT", -out, out); tr:SetPoint("TOPRIGHT", frame, "TOPRIGHT", out, out)
    bl:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -out, -out); br:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", out, -out)
    local top, bottom = piece(sx, 1 - sx, 0, sy), piece(sx, 1 - sx, 1 - sy, 1)
    top:SetPoint("TOPLEFT", tl, "TOPRIGHT"); top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
    bottom:SetPoint("TOPLEFT", bl, "TOPRIGHT"); bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
    local left, right = piece(0, sx, sy, 1 - sy), piece(1 - sx, 1, sy, 1 - sy)
    left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT"); left:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
    right:SetPoint("TOPLEFT", tr, "BOTTOMLEFT"); right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
    local h = { pieces = pieces }
    function h:SetShown(on) for _, p in ipairs(pieces) do p:SetShown(on) end end
    function h:SetVertexColor(r, g, b) for _, p in ipairs(pieces) do p:SetVertexColor(r, g, b) end end
    function h:SetAlpha(a) for _, p in ipairs(pieces) do p:SetAlpha(a) end end
    return h
end

-- A colour as a |c escape for FontString text.
function Theme.Hex(name, s)
    local c = type(name) == "table" and name or Theme.color[name] or Theme.color.text
    return string.format("|cff%02x%02x%02x%s|r", c[1] * 255, c[2] * 255, c[3] * 255, s)
end

-- The client's reaction label (FACTION_STANDING_LABEL1..8), or the English fallback.
function Theme.ReactionLabel(r)
    local s = type(r) == "number" and rawget(_G, "FACTION_STANDING_LABEL" .. r)
    if type(s) == "string" and s ~= "" then return s end
    return Theme.reaction.labels[r] or "?"
end

-- Space the window's outside parts take (tabs right, legend below, portrait ring and glow).
Theme.outside = { left = 8, right = 64, top = 8, bottom = 64 } -- bottom: legendGap + legendHeightTall

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

-- Mouse-hover highlights (RowHighlight with layer "HIGHLIGHT"), so they can be hidden while the
-- gamepad drives the window (owner, 2026-11-09, review item 16). Weak: frames are pooled.
local hoverHighlights = setmetatable({}, { __mode = "k" })
local hoverShown = true
function Theme.SetHoverShown(on)
    on = on and true or false
    if on == hoverShown then return end
    hoverShown = on
    for h in pairs(hoverHighlights) do
        local a = on and Theme.rowHighlightAlpha.hover or 0
        for i = 1, 3 do h[i]:SetAlpha(a) end
    end
end

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
    if layer == "HIGHLIGHT" then
        hoverHighlights[h] = true
        if not hoverShown then alpha = 0 end
    end
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
    -- D-pad left/right (the Class tab's side-path hint). From InputIconTexture.lua [external].
    D = { "gamepad-xbox1-dpadleftright-normal" },
}
Theme.circleMask = 130924 -- PortraitFrameTemplate's CircleMask file [verified-ingame]
Theme.glyphFallback = {
    A = "padA", B = "padB", X = "padX", Y = "padY",
    LB = "padShoulder", RB = "padShoulder", LT = "padShoulder", RT = "padShoulder", D = "padShoulder",
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

-- The first size in `keys` (largest first) at which `text` fits `width`, set on fs with the text
-- (Phase 15 step 2: a smaller type before a cut, review "Text cut with ..."). lines > 1: a wrapping
-- string; its longest word must fit one line and the whole about `lines` lines. The last size is
-- kept when none fits. Returns the size key used.
-- Measured on a string of its own with no width (on a string with a width, the measure came
-- back bounded by it, so a cut word measured as fitting: WoWScrnShot_111426_174503). A shown
-- frame at full alpha with see-through text, and GetStringWidth (used and proven elsewhere):
-- with alpha 0 and GetUnboundedStringWidth nothing measured as too wide (WoWScrnShot_111426_175311).
local ruler
function Theme.MeasureText(text, sizeKey)
    if not ruler then
        local host = CreateFrame("Frame", nil, UIParent)
        host:SetSize(1, 1); host:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
        ruler = host:CreateFontString(nil, "BACKGROUND")
        ruler:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 0, 0)
        if ruler.SetWordWrap then ruler:SetWordWrap(false) end
    end
    Theme.SetFont(ruler, sizeKey)
    ruler:SetTextColor(0, 0, 0, 0)
    ruler:SetShadowColor(0, 0, 0, 0)
    ruler:SetText(text or "")
    local w = ruler:GetStringWidth() or 0
    local ok, ub = false, nil
    if ruler.GetUnboundedStringWidth then ok, ub = pcall(ruler.GetUnboundedStringWidth, ruler) end
    if ok and type(ub) == "number" and ub > w then w = ub end
    return w
end
-- How many lines `text` takes wrapped at `width` (greedy, by words measured on the ruler; a
-- word wider than the line takes a line of its own). For rows that grow to fit their text
-- (Phase 15 step 5: class steps lead with the quest's objective, never cut).
function Theme.WrapLines(text, sizeKey, width)
    text = (text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    if text == "" or not width or width <= 0 then return 1 end
    local space = Theme.MeasureText("a a", sizeKey) - Theme.MeasureText("aa", sizeKey)
    local lines, used = 1, 0
    for word in text:gmatch("%S+") do
        local w = Theme.MeasureText(word, sizeKey)
        if used == 0 then used = w
        elseif used + space + w <= width then used = used + space + w
        else lines = lines + 1; used = w end
    end
    return lines
end

-- Sizes under 12 don't take on this client: a ruler at 10 measured exactly as at 12 ("Riverglades"
-- 81.67 both, trace 2026-11-14 17:57), as the button labels before. A string made by
-- Theme.ScaledText reaches them by scaling its own frame instead (the W.PanelButton way).
local MIN_FONT = 12
function Theme.FitFont(fs, text, width, keys, lines)
    text = text or ""
    local plain = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    for i, k in ipairs(keys) do
        local size = Theme.size[k] or Theme.size.sm
        local scaled = size < MIN_FONT
        local mk = scaled and "xs" or k
        local s = scaled and (size / MIN_FONT) or 1
        local fits
        if (lines or 1) > 1 then
            local widest = 0
            for word in plain:gmatch("%S+") do widest = math.max(widest, Theme.MeasureText(word, mk) * s) end
            fits = widest <= width and Theme.MeasureText(plain, mk) * s <= width * (lines - 0.25)
        else
            fits = Theme.MeasureText(plain, mk) * s <= width
        end
        if (scaled and not fs.scaleFrame) then fits = false end
        if fits or i == #keys then
            Theme.SetFont(fs, mk)
            if fs.scaleFrame then
                fs.scaleFrame:SetScale(s)
                if fs.fitWidth then fs:SetWidth(width / s) end
                if fs.placeArgs then fs.Place(fs.placeArgs[1], fs.placeArgs[2], fs.placeArgs[3]) end
            end
            fs:SetText(text)
            return k
        end
    end
end

-- A font string in a frame of its own covering `parent`, so Theme.FitFont can shrink it past
-- the client's 12 by scale. Anchor it with fs.Place(point, x, y) (offsets in parent units).
function Theme.ScaledText(parent, sizeKey, colorName, layer)
    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints(parent)
    local fs = Theme.Text(f, sizeKey, colorName, layer)
    fs.scaleFrame, fs.fitWidth = f, true
    function fs.Place(point, x, y)
        local s = f:GetScale() or 1
        fs.placeArgs = { point, x, y }
        fs:ClearAllPoints()
        fs:SetPoint(point, f, point, x / s, y / s)
    end
    return fs
end

function Theme.Text(parent, sizeKey, colorName, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    Theme.SetFont(fs, sizeKey)
    fs:SetTextColor(Theme.RGB(colorName or "text"))
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(1, -1)
    return fs
end

-- Texture coordinates that fill a w x h frame with a tw x th image without squashing it
-- (cover, centred): returns left, right, top, bottom.
function Theme.CoverCoords(w, h, tw, th)
    if not (w and h and tw and th) or w <= 0 or h <= 0 or tw <= 0 or th <= 0 then return 0, 1, 0, 1 end
    local frame, image = w / h, tw / th
    if frame >= image then
        local f = image / frame -- share of the image's height that shows
        return 0, 1, 0.5 - f / 2, 0.5 + f / 2
    end
    local f = frame / image -- share of the image's width that shows
    return 0.5 - f / 2, 0.5 + f / 2, 0, 1
end

-- A painted cartouche (chrome "cartouche": two notched end caps and a stretched middle, the Class
-- tab's ribbon) holding one line of dark ink, sized to its text by :SetText. Without the art, a
-- parchment tag with a sepia edge stands in.
function Theme.Cartouche(parent, sizeKey)
    local CT = Theme.layout.classTab
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(CT.cartH)
    local file = Theme.Chrome("cartouche")
    if file then
        local tw, th = CT.cartTex[1], CT.cartTex[2]
        local v0, v1 = CT.cartRows[1] / th, CT.cartRows[2] / th
        local capU = CT.cartCapPx / tw
        local function part(u0, u1)
            local t = f:CreateTexture(nil, "BACKGROUND")
            t:SetTexture(file); t:SetTexCoord(u0, u1, v0, v1)
            return t
        end
        local l, m, r = part(0, capU), part(capU, 1 - capU), part(1 - capU, 1)
        l:SetPoint("TOPLEFT"); l:SetPoint("BOTTOMLEFT"); l:SetWidth(CT.cartCap)
        r:SetPoint("TOPRIGHT"); r:SetPoint("BOTTOMRIGHT"); r:SetWidth(CT.cartCap)
        m:SetPoint("TOPLEFT", l, "TOPRIGHT"); m:SetPoint("BOTTOMRIGHT", r, "BOTTOMLEFT")
    else
        local edge = Theme.Solid(f, "classInkFaded", "BACKGROUND", 0.9)
        edge:SetAllPoints()
        local fill = Theme.Solid(f, "classParchment", "BORDER", 0.92)
        fill:SetPoint("TOPLEFT", 1, -1); fill:SetPoint("BOTTOMRIGHT", -1, 1)
    end
    f.text = Theme.Text(f, sizeKey or "sm", "classInk")
    f.text:SetShadowOffset(0, 0)
    f.text:SetWordWrap(false)
    f.text:SetPoint("CENTER", f, "CENTER", 0, 0)
    function f:SetText(s)
        self.text:SetText(s)
        self:SetWidth(math.max(CT.cartH, (self.text:GetStringWidth() or 0) + 2 * CT.cartCap + CT.cartPad * 2))
    end
    return f
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
