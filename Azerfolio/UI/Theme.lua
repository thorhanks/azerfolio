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
    atlasPanel = 240,          -- the Overview's Atlas panel height (Phase 10)
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
                               -- for the emblem, the widest label and this drop the labels
    sum = 170,                 -- "Met n of m · Exalted n of m" column
    plaqueCorner = 10,         -- frame-plaque's drawn corner (12 px of its 256x128)
    clothTint = 0.62, clothEmpty = 0.18, -- the cloth fill's tint strength, full and empty cells
    row = 40, rowGap = 3,
    thumb = { 56, 30 }, thumbWide = { 44, 26 },
    cols = { react = 76, ladder = 260, num = 128, colGap = 12, row = 40 },
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
    PALADIN = {
        -- The round 5 strip (2026-11-10: the zone art's painting in antique colours, a narrow lane
        -- traced into Data/StripPaths.lua): the abbey, the cathedral city, the farm, the autumn
        -- wood's glowing glade, the open hills below the wood, the camp, the ossuary and ruined gate,
        -- the star at the bottom. Road stops snap onto the lane. Nobility (40) sits well below Valor
        -- (20) so twenty levels of milestones get room (WoWScrnShot_111026_200757).
        Alliance = { H = 1680, ["end"] = { 210, 1640 }, intro = { 210, 100 }, divinity = { 250, 215 }, valor = { 190, 680 },
            artifact = { 107, 905 }, nobility = { 200, 1065 }, mightstone = { 300, 1262 }, charger = { 190, 1400 } },
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
