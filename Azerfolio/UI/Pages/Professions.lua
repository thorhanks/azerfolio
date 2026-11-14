-- The Professions tab (Phase 14; spec §7.11; mockups/DESIGN.md "Professions tab", round 2): a
-- rail of this character's professions on the left and the selected profession's page on the
-- right, split into views that Y cycles: Journey (the banner with the skill road in its foot,
-- Next up beside Tracked), Recipes and Gather (step 7).
-- Everything shown comes from ns.Professions (rules in ns.ProfessionRules); this file only words
-- and draws it. Painted banners and coins don't exist yet: stand-ins (a tinted gradient with the
-- profession's icon faint behind; the icon in a ring for the coin), prompts in art/prompts.md.
local _, ns = ...

local VIEW_LABEL = { journey = "Journey", recipes = "Recipes", gather = "Gather" }
local MILESTONE_ART = { trained = "milestone-rune-gold", now = "milestone-rune-red", later = "milestone" }
local STONE_SUB = { trained = "trained", now = "train now" }

local function plural(n, one, many) return n == 1 and one or (many or (one .. "s")) end

-- Zone names by mapID, from the client (cached).
local zoneNames = {}
local function zoneName(mapID)
    if type(mapID) ~= "number" then return nil end
    if zoneNames[mapID] ~= nil then return zoneNames[mapID] or nil end
    local info = C_Map and type(C_Map.GetMapInfo) == "function" and ns.Debug.Try("GetMapInfo", C_Map.GetMapInfo, mapID)
    zoneNames[mapID] = type(info) == "table" and info.name or false
    return zoneNames[mapID] or nil
end

-- The first n zones' names, your side's territory first (ProfessionRules.OrderZones).
local function zonesText(zones, n)
    local out = {}
    local faction = ns.character and ns.character.faction
    for _, id in ipairs(ns.ProfessionRules.OrderZones(zones, ns.ZoneData and ns.ZoneData.faction, faction)) do
        local name = zoneName(id)
        if name then out[#out + 1] = name end
        if #out >= (n or 3) then break end
    end
    return table.concat(out, ", ")
end

-- "Gelman Stonehand · Stormwind City or Kelsey Fargo · Elwynn Forest" (the first two).
local function trainersText(m)
    if not m.trainers then
        local st = ns.ProfessionSources.State().status
        if st == "building" or st == "idle" then return "trainers: reading QuestieDB" end
        return "where its trainers are isn't known"
    end
    if #m.trainers == 0 then return "no trainer for it known on your side" end
    local out = {}
    for i, t in ipairs(m.trainers) do
        if i > 2 then break end
        out[#out + 1] = t.name .. (t.place and (" · " .. t.place) or (zoneName(t.mapID) and (" · " .. zoneName(t.mapID)) or ""))
    end
    return table.concat(out, " or ")
end

-- The status tag's words and colour (ProfessionRules.Status).
local function statusText(m)
    local s = m.status
    if not s then return nil end
    if s.kind == "mastered" then return "Mastered", "complete" end
    if s.kind == "atcap" then return "At cap · train " .. s.rank.name, "profWarn" end
    if s.kind == "trainnow" then return "Train " .. s.rank.name .. " now", "profGo" end
    if s.kind == "learn" then return s.n .. " " .. plural(s.n, "recipe") .. " to learn", "profGo" end
    if s.kind == "unread" then return "Open your " .. m.name .. " window once", "dim" end
end

local function dotColor(m)
    local s = m.status and m.status.kind
    if s == "mastered" then return "complete" end
    if s == "atcap" then return "profWarn" end
    if s == "trainnow" or s == "learn" then return "profGo" end
end

local function rankTitle(m, rank)
    return ns.ProfessionRules.Title(ns.ProfessionRules.Info(m.skillLine), rank) or rank.name
end

-- Where to get an ingredient (ProfessionRules.ReagentSource), in words.
local function whereText(w)
    if not w then return "Where to get it isn't known" end
    if w.kind == "craft" then return "Craft it: " .. w.recipe.name .. (w.recipe.known and "" or " (not known yet)") end
    if w.kind == "gather" then return "Gather: " .. w.node.name .. (w.node.skill and (" (from " .. w.node.skill .. ")") or "") end
    if w.kind == "vendor" then
        local v = w.vendor
        local place = v.place or (v.maps and zoneName(v.maps[1]))
        return "Vendor · " .. v.npc .. (place and (", " .. place) or "") .. (w.more > 0 and (" (+" .. w.more .. " more)") or "")
    end
    if w.kind == "drop" then return "Drops from " .. w.n .. " " .. plural(w.n, "creature") end
    return "Where to get it isn't known"
end

-- Next up (ProfessionRules.NextUp) in words: title, sub line, colour, action.
local function nextUpText(it, m)
    if it.kind == "mastered" then return m.name .. " mastered", "Skill 300: every rank trained.", "complete" end
    if it.kind == "rank" then
        local r = it.rank
        if it.atCap then return "At your cap: train " .. r.name, "Skill-ups are lost until you train · " .. trainersText(m), "profWarn" end
        if it.now then return "Train " .. r.name .. " now", "Raises your cap to " .. r.cap .. " · " .. trainersText(m), "profGo" end
        return r.name .. " at skill " .. r.at, it.togo .. " skill to go · " .. trainersText(m)
    end
    if it.kind == "learn" then
        local names = {}
        for _, r in ipairs(it.recipes) do names[#names + 1] = r.name end
        return it.n .. " " .. plural(it.n, "recipe") .. " waiting at your trainer", table.concat(names, ", "), "profGo", "recipes:now"
    end
    if it.kind == "skillup" then
        local names = {}
        for _, r in ipairs(it.recipes) do names[#names + 1] = r.name .. " (until " .. r.grey .. ")" end
        return "Still gives skill", table.concat(names, ", "), nil, "recipes:foryou"
    end
    if it.kind == "gather" then
        local row = it.row
        if row.name then
            return "Gather " .. row.name, "Gives skill until " .. row.greyAt .. (row.zones[1] and (" · " .. zonesText(row.zones)) or ""), nil, "gather"
        end
        return "Skin in " .. (zoneName(row.mapID) or "this zone"), "Gives skill until " .. row.greyAt, nil, "gather"
    end
    if it.kind == "gathernext" then
        local row = it.row
        local title = it.fishing and ("Fish from " .. row.from) or row.name and (row.name .. " from " .. row.from)
            or ("Skin in " .. (zoneName(row.mapID) or "the next zone") .. " from " .. row.from)
        local where = it.fishing and zonesText(row.zones) or row.name and zonesText(row.zones) or ""
        return title, (it.togo or 0) .. " skill to go" .. (where ~= "" and (" · " .. where) or ""), nil, "gather"
    end
    if it.kind == "unread" then
        return "Open your " .. m.name .. " window once", "Azerfolio reads its recipes from it, then keeps them up to date.", "dim"
    end
    return it.kind, ""
end

-- The views this profession has (only those it has: Recipes once its window is known or asked
-- for, Gather for the gathering professions).
local function viewsOf(m)
    local v = { "journey" }
    if m.hasRecipes then v[#v + 1] = "recipes" end
    if m.gather then v[#v + 1] = "gather" end
    return v
end

---------------------------------------------------------------------------------------------
-- Small drawing helpers
---------------------------------------------------------------------------------------------

local function circle(parent, layer, size, sub)
    local t = parent:CreateTexture(nil, layer, nil, sub)
    t:SetSize(size, size)
    local m = parent.CreateMaskTexture and parent:CreateMaskTexture()
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

local function piece(parent, name, layer, sub)
    local file = ns.Theme.Chrome(name)
    if not file then return nil end
    local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
    t:SetTexture(file)
    t:SetPoint("CENTER")
    return t
end

local function hexColor(s)
    return tonumber(s:sub(1, 2), 16) / 255, tonumber(s:sub(3, 4), 16) / 255, tonumber(s:sub(5, 6), 16) / 255
end

-- The profession coin (stand-in): the profession's icon in a ring, gold rim when mastered, dull
-- bronze before. :Set(m, size).
local function newCoin(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.rim = circle(f, "BORDER", 10)
    f.rim:SetPoint("CENTER")
    f.icon = circle(f, "ARTWORK", 10)
    f.icon:SetPoint("CENTER")
    function f:Set(m, size)
        self:SetSize(size, size)
        self.rim:SetSize(size, size)
        self.icon:SetSize(size - 6, size - 6)
        tint(self.rim, m.mastered and "complete" or "levelRange")
        if m.icon then self.icon:SetTexture(m.icon) else tint(self.icon, "cardBg") end
        if self.icon.SetDesaturated then self.icon:SetDesaturated(not m.mastered) end
        self.icon:SetVertexColor(1, 1, 1, m.mastered and 1 or 0.8)
    end
    return f
end

-- A row in the rail: coin, name, skill, dot.
local function newRailRow(parent)
    local T, PT, W = ns.Theme, ns.Theme.layout.profTab, ns.Widgets
    local r = W.FocusRow(parent, PT.railRow)
    r.coin = newCoin(r)
    r.coin:SetPoint("TOP", r, "TOP", 0, -6)
    r.name = T.Text(r, "xs", "white")
    r.name:SetPoint("TOP", r.coin, "BOTTOM", 0, -2)
    r.name:SetWordWrap(false)
    r.skill = T.Text(r, "xs", "dim")
    r.skill:SetPoint("TOP", r.name, "BOTTOM", 0, -1)
    r.dot = circle(r, "OVERLAY", 10)
    r.dot:SetPoint("TOPRIGHT", r.coin, "TOPRIGHT", 4, 2)
    r.frame = W.Edge(r, "BORDER")
    r:SetScript("OnClick", function(self) if self.onClick then self.onClick() end end)
    return r
end

-- A Next up line: dot, title, sub line.
local function newNextRow(parent)
    local T, PT, W, S = ns.Theme, ns.Theme.layout.profTab, ns.Widgets, ns.Theme.space
    local r = W.FocusRow(parent, PT.nextRow)
    r.dot = circle(r, "ARTWORK", 8)
    r.dot:SetPoint("TOPLEFT", r, "TOPLEFT", S.s1, -10)
    r.title = T.Text(r, "sm", "white")
    r.title:SetPoint("TOPLEFT", r, "TOPLEFT", S.s4, -5)
    r.title:SetPoint("RIGHT", r, "RIGHT", -S.s2, 0)
    r.title:SetJustifyH("LEFT"); r.title:SetWordWrap(false)
    r.sub = T.Text(r, "xs", "dim")
    r.sub:SetPoint("TOPLEFT", r.title, "BOTTOMLEFT", 0, -3)
    r.sub:SetPoint("RIGHT", r, "RIGHT", -S.s2, 0)
    r.sub:SetJustifyH("LEFT"); r.sub:SetWordWrap(false)
    r:SetScript("OnClick", function(self) if self.onClick then self.onClick() end end)
    return r
end

-- A Tracked card: framed, the recipe's name and summary, one line per ingredient.
local function newTrackCard(parent)
    local T, PT, W, S = ns.Theme, ns.Theme.layout.profTab, ns.Widgets, ns.Theme.space
    local c = W.FocusRow(parent, PT.cardHead)
    c.bg = T.Solid(c, "cardBg", "BACKGROUND", 0.85)
    c.bg:SetAllPoints()
    c.edge = T.CardFrame(c, 16, 3)
    if not c.edge then c.line = W.Edge(c, "BORDER"); c.line:SetColor("cardEdge") end
    c.name = T.Text(c, "sm", "white")
    c.name:SetPoint("TOPLEFT", c, "TOPLEFT", S.s3, -S.s2)
    c.name:SetPoint("RIGHT", c, "RIGHT", -70, 0)
    c.name:SetJustifyH("LEFT"); c.name:SetWordWrap(false)
    c.sum = T.Text(c, "xs", "dim")
    c.sum:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -2)
    c.sum:SetPoint("RIGHT", c, "RIGHT", -S.s3, 0)
    c.sum:SetJustifyH("LEFT"); c.sum:SetWordWrap(false)
    c.tag = T.Text(c, "xs", "profReady")
    c.tag:SetPoint("TOPRIGHT", c, "TOPRIGHT", -S.s3, -S.s2)
    c.lines = {}
    function c:Line(i)
        local l = self.lines[i]
        if not l then
            l = { q = T.Text(self, "xs", "text"), n = T.Text(self, "xs", "white"), w = T.Text(self, "xs", "dim") }
            l.q:SetWidth(52); l.q:SetJustifyH("RIGHT")
            l.n:SetJustifyH("LEFT"); l.n:SetWordWrap(false)
            l.w:SetJustifyH("LEFT"); l.w:SetWordWrap(false)
            self.lines[i] = l
        end
        return l
    end
    c:SetScript("OnClick", function(self) if self.onClick then self.onClick() end end)
    return c
end

---------------------------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------------------------

local function build(parent)
    local T, L, S, W = ns.Theme, ns.Theme.layout, ns.Theme.space, ns.Widgets
    local PT = L.profTab
    local page = CreateFrame("Frame", nil, parent)
    page.mode = "rail"        -- "rail" | "page": where the gamepad's focus is
    page.view = "journey"     -- kept when you change profession
    page.filter = "foryou"    -- the Recipes view's filter (step 7)
    page.railRows, page.nextRows, page.cards = {}, {}, {}

    -- Rail ------------------------------------------------------------------------------------
    local rail = CreateFrame("Frame", nil, page)
    rail:SetPoint("TOPLEFT"); rail:SetPoint("BOTTOMLEFT"); rail:SetWidth(PT.rail)
    T.Solid(rail, "black", "BACKGROUND", 0.28):SetAllPoints()
    local redge = T.Solid(rail, "divider", "BORDER")
    redge:SetPoint("TOPRIGHT"); redge:SetPoint("BOTTOMRIGHT"); redge:SetWidth(1)
    page.groupPrimary = T.Text(rail, "xs", "gold")
    page.groupSecondary = T.Text(rail, "xs", "gold")
    page.rail = rail

    -- The page on the right ------------------------------------------------------------------------
    local right = CreateFrame("Frame", nil, page)
    right:SetPoint("TOPLEFT", rail, "TOPRIGHT"); right:SetPoint("BOTTOMRIGHT")
    local sw = CreateFrame("Frame", nil, right)
    sw:SetPoint("TOPLEFT"); sw:SetPoint("TOPRIGHT"); sw:SetHeight(PT.switch)
    T.Solid(sw, "black", "BACKGROUND", 0.2):SetAllPoints()
    page.viewBtns = {}
    for i, v in ipairs({ "journey", "recipes", "gather" }) do
        local b = W.Control(sw)
        b:SetScript("OnClick", function() page:SetView(v) end)
        b.item = { title = VIEW_LABEL[v], detail = "Y cycles the views." }
        page.viewBtns[v] = b
        b.order = i
    end
    page.viewHint = T.Text(sw, "xs", "dim")
    page.viewHint:SetPoint("RIGHT", sw, "RIGHT", -S.s4, 0)

    local body = CreateFrame("Frame", nil, right)
    body:SetPoint("TOPLEFT", sw, "BOTTOMLEFT"); body:SetPoint("BOTTOMRIGHT")
    page.body = body

    -- Journey: banner + road ----------------------------------------------------------------------
    local journey = CreateFrame("Frame", nil, body)
    journey:SetAllPoints()
    local banner = CreateFrame("Frame", nil, journey)
    banner:SetPoint("TOPLEFT"); banner:SetPoint("TOPRIGHT")
    banner.bg = banner:CreateTexture(nil, "BACKGROUND")
    banner.bg:SetAllPoints()
    banner.bg:SetColorTexture(1, 1, 1, 1)
    banner.emblem = banner:CreateTexture(nil, "BACKGROUND", nil, 2)
    banner.emblem:SetPoint("RIGHT", banner, "RIGHT", -40, 30)
    banner.emblem:SetAlpha(0.12)
    banner.kicker = T.Text(banner, "xs", "dim")
    banner.kicker:SetPoint("TOPLEFT", banner, "TOPLEFT", S.s6, -S.s4)
    banner.name = T.Text(banner, "xxl", "gold")
    banner.name:SetPoint("TOPLEFT", banner.kicker, "BOTTOMLEFT", 0, -S.s1)
    banner.title = T.Text(banner, "sm", "text")
    banner.title:SetPoint("TOPLEFT", banner.name, "BOTTOMLEFT", 0, -S.s1)
    banner.skill = T.Text(banner, "huge", "white")
    banner.skill:SetPoint("TOPRIGHT", banner, "TOPRIGHT", -S.s6, -S.s4)
    banner.of = T.Text(banner, "sm", "dim")
    banner.of:SetPoint("TOPRIGHT", banner.skill, "BOTTOMRIGHT", 0, -2)
    banner.mastered = newCoin(banner)
    banner.mastered:SetPoint("TOPRIGHT", banner, "TOPRIGHT", -S.s6, -S.s4)
    local brule = T.Solid(banner, "divider", "ARTWORK")
    brule:SetPoint("BOTTOMLEFT"); brule:SetPoint("BOTTOMRIGHT"); brule:SetHeight(2)
    page.banner = banner

    -- The skill road on its parchment strip, set into the banner's foot.
    local road = CreateFrame("Frame", nil, banner)
    road:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", S.s3, S.s3)
    road:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", -S.s3, S.s3)
    road:SetHeight(PT.road)
    road.paper = T.Solid(road, "classParchment", "BACKGROUND", 0.92)
    road.paper:SetAllPoints()
    road.edge = W.Edge(road, "BORDER")
    road.edge:SetColor("divider")
    local base = road:GetFrameLevel()
    road.bar = T.GildedBar(road, PT.roadBar)
    road.bar:SetFrameLevel(base + 1)
    -- Past your cap: the road darkened behind a gate (on a frame above the gilded bar).
    road.over = CreateFrame("Frame", nil, road)
    road.over:SetAllPoints()
    road.over:SetFrameLevel(base + 2)
    road.closed = T.Solid(road.over, "black", "ARTWORK", 0.45)
    road.gate = {}
    for i = 1, 4 do road.gate[i] = T.Solid(road.over, "classNotch", "OVERLAY") end -- brass on the darkened road
    road.ticks = {}
    for i, s in ipairs({ 1, 75, 150, 225, 300 }) do
        local tk = { line = T.Solid(road, "classInk", "ARTWORK", 0.7), text = T.Text(road, "xs", "classInk"), skill = s }
        tk.text:SetText(tostring(s))
        road.ticks[i] = tk
    end
    road.stones = {}
    for i = 1, 3 do
        local b = CreateFrame("Button", nil, road)
        b:SetFrameLevel(base + 3)
        b:SetSize(PT.stone[1], PT.stone[2])
        b.stone = b:CreateTexture(nil, "ARTWORK")
        b.stone:SetAllPoints()
        b.disc = circle(b, "ARTWORK", 16, 1)
        b.disc:SetPoint("CENTER")
        b.focusArt = piece(b, "focus-ring-red", "OVERLAY", 6)
        if b.focusArt then b.focusArt:SetSize(PT.stone[2] + 14, PT.stone[2] + 14) end
        b.focusRing = circle(b, "BACKGROUND", PT.stone[2] + 10, 1)
        b.focusRing:SetPoint("CENTER")
        tint(b.focusRing, "classRedInk", 0.6)
        b.label = T.Text(road, "sm", "classInk")
        b.label:SetPoint("LEFT", b, "RIGHT", 4, 6)
        b.sub = T.Text(road, "xs", "classInkFaded")
        b.sub:SetPoint("TOPLEFT", b.label, "BOTTOMLEFT", 0, -1)
        function b:SetFocused(on)
            self.focused = on
            if self.focusArt then self.focusArt:SetShown(on and true or false); self.focusRing:Hide()
            else self.focusRing:SetShown(on and true or false) end
        end
        b:SetFocused(false)
        W.HoverInfo(b)
        road.stones[i] = b
    end
    road.you = CreateFrame("Frame", nil, road)
    road.you:SetSize(PT.you, PT.you)
    road.you:SetFrameLevel(base + 4)
    road.you.ring = circle(road.you, "BORDER", PT.you)
    road.you.ring:SetPoint("CENTER")
    tint(road.you.ring, "classNotch")
    road.you.icon = circle(road.you, "ARTWORK", PT.you - 4)
    road.you.icon:SetPoint("CENTER")
    road.you.brass = piece(road.you, "you-ring", "OVERLAY", 2)
    if road.you.brass then road.you.brass:SetSize((PT.you - 4) / 0.56, (PT.you - 4) / 0.56) end
    road.coinBtn = CreateFrame("Button", nil, road)
    road.coinBtn:SetSize(PT.endCoin, PT.endCoin)
    road.coinBtn:SetFrameLevel(base + 3)
    road.coin = newCoin(road.coinBtn)
    road.coin:SetPoint("CENTER")
    road.coinBtn.focusRing = circle(road.coinBtn, "BACKGROUND", PT.endCoin + 10, 1)
    road.coinBtn.focusRing:SetPoint("CENTER")
    tint(road.coinBtn.focusRing, "classRedInk", 0.6)
    road.coinBtn.focusRing:Hide()
    function road.coinBtn:SetFocused(on) self.focusRing:SetShown(on and true or false) end
    W.HoverInfo(road.coinBtn)
    page.road = road

    -- Next up | Tracked, each scrolling on its own.
    local cols = CreateFrame("Frame", nil, journey)
    cols:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", 0, -S.s2)
    cols:SetPoint("BOTTOMRIGHT", journey, "BOTTOMRIGHT", 0, S.s1)
    local function column(title)
        local c = CreateFrame("Frame", nil, cols)
        c.plate = T.Plate(c, L.plate)
        c.plate:SetPoint("TOPLEFT", c, "TOPLEFT", S.s4, 0)
        c.plate:SetPoint("TOPRIGHT", c, "TOPRIGHT", -S.s4, 0)
        c.plate.title:SetText(title)
        c.note = T.Text(c, "xs", "dim")
        c.scroll = W.Scroll(c)
        c.scroll:SetPoint("TOPLEFT", c.plate, "BOTTOMLEFT", 0, -S.s2)
        c.scroll:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -S.s4, 0)
        c.empty = T.Text(c.scroll.child, "sm", "dim")
        c.empty:SetPoint("TOPLEFT", c.scroll.child, "TOPLEFT", S.s4, -S.s2)
        c.empty:SetPoint("RIGHT", c.scroll.child, "RIGHT", -S.s2, 0)
        c.empty:SetJustifyH("LEFT")
        return c
    end
    page.nextCol, page.trackCol = column("Next up"), column("Tracked")
    page.nextCol:SetPoint("TOPLEFT"); page.nextCol:SetPoint("BOTTOMLEFT")
    page.trackCol:SetPoint("TOPLEFT", page.nextCol, "TOPRIGHT"); page.trackCol:SetPoint("BOTTOMRIGHT")
    cols:SetScript("OnSizeChanged", function(self, w) page.nextCol:SetWidth(math.max(1, (w or 0) / 2)) end)
    page.journey = journey

    -- Recipes and Gather: step 7. Until then, a plain note in their place.
    local other = CreateFrame("Frame", nil, body)
    other:SetAllPoints()
    other.text = T.Text(other, "md", "dim")
    other.text:SetPoint("TOP", 0, -80)
    page.other = other

    -- No professions yet.
    local empty = CreateFrame("Frame", nil, page)
    empty:SetAllPoints()
    empty.title = T.Text(empty, "lg", "gold")
    empty.title:SetPoint("TOP", 0, -120)
    empty.title:SetText("No professions yet")
    empty.text = T.Text(empty, "md", "dim")
    empty.text:SetPoint("TOP", empty.title, "BOTTOM", 0, -S.s3)
    empty.text:SetWidth(520)
    empty.text:SetText("Learn a profession from a trainer and it shows here: its skill, its next rank and the recipes you can collect. "
        .. "Primary professions are taught in the capitals and starting towns; Cooking, First Aid and Fishing are open to everyone.")
    page.empty = empty

    local function take(list, make, parent2)
        page.used[list] = (page.used[list] or 0) + 1
        local pool = page[list]
        local f = pool[page.used[list]]
        if not f then f = make(parent2); pool[page.used[list]] = f end
        f:Show()
        return f
    end

    ---------------------------------------------------------------------------------------------
    -- Painting
    ---------------------------------------------------------------------------------------------

    local function selected()
        for _, m in ipairs(page.data and page.data.professions or {}) do
            if m.skillLine == page.sel then return m end
        end
    end

    local function railInfo(m)
        local st = statusText(m)
        return string.format("%s, %s of %s%s.", m.title or m.name, tostring(m.skill or "?"), tostring(m.cap or "?"), st and (". " .. st) or "")
    end

    local function paintRail(list)
        local y = S.s2
        local rows = {}
        for _, r in ipairs(page.railRows) do r:Hide() end
        page.groupPrimary:Hide(); page.groupSecondary:Hide()
        local lastKind
        for _, m in ipairs(list) do
            if m.kind ~= lastKind then
                local g = m.kind == "primary" and page.groupPrimary or page.groupSecondary
                g:SetText(m.kind == "primary" and "Primary" or "Secondary")
                g:ClearAllPoints(); g:SetPoint("TOP", rail, "TOP", 0, -y - 6)
                g:Show()
                y = y + PT.railGroup
                lastKind = m.kind
            end
            local r = take("railRows", newRailRow, rail)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", rail, "TOPLEFT", 4, -y)
            r:SetPoint("TOPRIGHT", rail, "TOPRIGHT", -4, -y)
            r.coin:Set(m, PT.railCoin)
            r.name:SetText(m.name)
            r.name:SetWidth(PT.rail - 12)
            r.skill:SetText(string.format("|cffffffff%s|r / %s", tostring(m.skill or "?"), tostring(m.cap or "?")))
            local dot = dotColor(m)
            r.dot:SetShown(dot ~= nil)
            if dot then tint(r.dot, dot) end
            r.frame:SetColor(m.skillLine == page.sel and "complete" or "divider", m.skillLine == page.sel and 0.9 or 0)
            r:SetSelected(m.skillLine == page.sel)
            local line = m.skillLine
            r.item = { key = "p:" .. line, frame = r, title = m.name, detail = railInfo(m), prof = line,
                actionLabel = "Open", onActivate = function() page:EnterPage() end }
            r.onClick = function() page:Select(line); page:EnterPage() end
            rows[#rows + 1] = { items = { r.item }, section = 1 }
            y = y + PT.railRow + S.s1
        end
        return rows
    end

    local function paintBanner(m)
        local tone = PT.tones[m.key or ""] or { "3a2a1a", "100804" }
        local tr, tg, tb = hexColor(tone[1])
        local br, bg, bb = hexColor(tone[2])
        local ok = type(CreateColor) == "function" and pcall(banner.bg.SetGradient, banner.bg, "VERTICAL",
            CreateColor(br, bg, bb, 1), CreateColor(tr, tg, tb, 1))
        if not ok then banner.bg:SetColorTexture(tr, tg, tb, 1) end
        if m.icon then banner.emblem:SetTexture(m.icon) end
        local h = banner:GetHeight() or PT.bannerMax
        banner.emblem:SetSize(h * 0.55, h * 0.55)
        banner.kicker:SetText((m.kind == "primary" and "Primary" or "Secondary") .. " profession"
            .. (m.role == "gathering" and " · gathering" or m.role == "both" and " · gathering" or ""))
        banner.name:SetText(m.mastered and (m.name .. ", mastered") or m.name)
        banner.title:SetText(m.mastered and "Every rank trained" or (m.title or ""))
        banner.skill:SetShown(not m.mastered); banner.of:SetShown(not m.mastered)
        banner.mastered:SetShown(m.mastered)
        if m.mastered then banner.mastered:Set(m, 72)
        else
            banner.skill:SetText(tostring(m.skill or "?"))
            banner.of:SetText("of " .. tostring(m.cap or "?"))
        end
    end

    local function stoneInfo(m, st)
        local r = st.rank
        local state = st.state == "trained" and "Trained." or st.state == "now" and "You can train it now."
            or (m.next == r and m.skill and ((r.at - m.skill) .. " skill to go.")) or "Later."
        local where = st.state ~= "trained" and m.next == r and (" Trainers: " .. trainersText(m) .. ".") or ""
        return string.format("Raises your cap to %d. Train from skill %d. %s%s", r.cap, r.at, state, where)
    end

    local function paintRoad(m)
        -- Before the first layout the road has no width yet: draw for a nominal one (the stops
        -- still exist for focus); the next size change redraws at the real width.
        local w = road:GetWidth() or 0
        if w <= 0 then w = 900 end
        local x0, x1 = PT.roadPadL, w - PT.roadPadR
        local max = ns.ProfessionData.maxSkill
        local function X(s) return x0 + (math.max(1, math.min(max, s)) - 1) / (max - 1) * (x1 - x0) end
        local barY = 30 -- from the strip's bottom to the bar's centre
        road.bar:ClearAllPoints()
        road.bar:SetPoint("LEFT", road, "BOTTOMLEFT", x0 - PT.roadBar * 0.45, barY)
        road.bar:SetWidth(x1 - x0 + PT.roadBar * 0.9)
        road.bar:Set((m.skill or 0) / max, m.mastered and "complete" or nil)
        local cap = m.cap or max
        local closed = not m.mastered and cap < max
        road.closed:SetShown(closed)
        for _, g in ipairs(road.gate) do g:SetShown(closed) end
        if closed then
            local xc = X(cap)
            road.closed:ClearAllPoints()
            road.closed:SetPoint("LEFT", road, "BOTTOMLEFT", xc, barY)
            road.closed:SetSize(math.max(1, x1 - xc + 4), PT.roadBar - 6)
            -- The gate: two posts and two bars across the road at your cap.
            road.gate[1]:ClearAllPoints(); road.gate[1]:SetPoint("CENTER", road, "BOTTOMLEFT", xc - 3, barY); road.gate[1]:SetSize(2, PT.roadBar + 10)
            road.gate[2]:ClearAllPoints(); road.gate[2]:SetPoint("CENTER", road, "BOTTOMLEFT", xc + 3, barY); road.gate[2]:SetSize(2, PT.roadBar + 10)
            road.gate[3]:ClearAllPoints(); road.gate[3]:SetPoint("CENTER", road, "BOTTOMLEFT", xc, barY + 5); road.gate[3]:SetSize(12, 2)
            road.gate[4]:ClearAllPoints(); road.gate[4]:SetPoint("CENTER", road, "BOTTOMLEFT", xc, barY - 5); road.gate[4]:SetSize(12, 2)
        end
        for _, tk in ipairs(road.ticks) do
            local x = X(tk.skill)
            tk.line:ClearAllPoints(); tk.line:SetPoint("TOP", road, "BOTTOMLEFT", x, barY - PT.roadBar / 2 - 1); tk.line:SetSize(1, 5)
            tk.text:ClearAllPoints(); tk.text:SetPoint("TOP", tk.line, "BOTTOM", 0, -1)
        end
        local items = {}
        for i, st in ipairs(m.stones or {}) do
            local b = road.stones[i]
            if b then
                local file = T.Chrome(MILESTONE_ART[st.state] or "milestone")
                b.stone:SetShown(file ~= nil); b.disc:SetShown(file == nil)
                if file then b.stone:SetTexture(file) else tint(b.disc, st.state == "trained" and "complete" or st.state == "now" and "classRedInk" or "classInkFaded") end
                b:ClearAllPoints()
                b:SetPoint("BOTTOM", road, "BOTTOMLEFT", X(st.at), barY + PT.roadBar / 2 + 4)
                b.label:SetText(st.rank.name)
                b.label:SetTextColor(T.RGB(st.state == "later" and "classInkFaded" or "classInk"))
                b.sub:SetText(STONE_SUB[st.state] or ("from " .. st.at))
                b.sub:SetTextColor(T.RGB(st.state == "now" and "classRedInk" or "classInkFaded"))
                b.item = { key = "stone:" .. st.rank.name, frame = b, title = rankTitle(m, st.rank), detail = stoneInfo(m, st) }
                b:Show(); b.label:Show(); b.sub:Show()
                items[#items + 1] = b.item
            end
        end
        for i = #(m.stones or {}) + 1, #road.stones do road.stones[i]:Hide(); road.stones[i].label:Hide(); road.stones[i].sub:Hide() end
        road.you:SetShown(not m.mastered and m.skill ~= nil)
        if m.skill and not m.mastered then
            road.you:ClearAllPoints()
            road.you:SetPoint("CENTER", road, "BOTTOMLEFT", X(m.skill), barY)
            local ok = type(SetPortraitTexture) == "function" and pcall(SetPortraitTexture, road.you.icon, "player")
            if not ok then tint(road.you.icon, "classParchment") end
        end
        road.coinBtn:ClearAllPoints()
        road.coinBtn:SetPoint("CENTER", road, "BOTTOMLEFT", x1 + PT.roadPadR / 2 + 2, barY + 6)
        road.coin:Set(m, PT.endCoin)
        road.coinBtn.item = { key = "coin", frame = road.coinBtn, title = m.name .. " mastered",
            detail = m.mastered and string.format("Skill %d of %d.", max, max)
                or string.format("At skill %d. %s to go.", max, m.skill and tostring(max - m.skill) or "?") }
        items[#items + 1] = road.coinBtn.item
        return items
    end

    local function paintNext(m)
        local col = page.nextCol
        local child = col.scroll.child
        local y, items = 0, {}
        for i, it in ipairs(m.nextUp or {}) do
            local title, sub, color, action = nextUpText(it, m)
            local r = take("nextRows", newNextRow, child)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", child, "TOPLEFT", S.s4, -y)
            r:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, -y)
            r.title:SetText(title); r.sub:SetText(sub or "")
            r.title:SetTextColor(T.RGB(color == "dim" and "dim" or "white"))
            tint(r.dot, color and color ~= "dim" and color or "levelRange")
            local act = action and function() page:Act(action) end
            r.item = { key = "next:" .. i .. ":" .. it.kind, frame = r, title = title, detail = (sub or "") .. (act and ". A opens it." or "."),
                scroll = col.scroll, onActivate = act, actionLabel = "Open", group = "next", column = 1 }
            r.onClick = act
            items[#items + 1] = r.item
            y = y + PT.nextRow + S.s1
        end
        col.empty:SetShown(#items == 0)
        col.empty:SetText("Nothing to do here right now.")
        child:SetHeight(math.max(1, y))
        return items
    end

    local function ingredientSummary(rg)
        if not rg then return "Ingredients not known", nil end
        if rg.ready then return "You have everything for one", "Ready" end
        local short = {}
        for _, it in ipairs(rg.items) do if it.have ~= nil and not it.ok then short[#short + 1] = it.name or ("item " .. it.itemID) end end
        if #short > 0 then return "Missing " .. table.concat(short, ", "), nil end
        return "Counts not known yet", nil
    end

    local function paintTracked(m)
        local col = page.trackCol
        local child = col.scroll.child
        local y, items = 0, {}
        local width = (child:GetWidth() or 300) - S.s4
        for _, r in ipairs(m.recipes and m.recipes.list or {}) do
            if r.tracked then
                local rg = ns.Professions.Reagents(r.id, m)
                local c = take("cards", newTrackCard, child)
                c:ClearAllPoints()
                c:SetPoint("TOPLEFT", child, "TOPLEFT", S.s4, -y - 4)
                c:SetWidth(math.max(1, width - 4))
                c.name:SetText(r.name)
                local sum, tag = ingredientSummary(rg)
                c.sum:SetText(sum); c.tag:SetText(tag or "")
                local h = PT.cardHead
                local parts = {}
                for i, it in ipairs(rg and rg.items or {}) do
                    local l = c:Line(i)
                    l.q:ClearAllPoints(); l.q:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -h)
                    l.q:SetText(string.format("%s / %d", it.have == nil and "?" or tostring(it.have), it.need))
                    l.q:SetTextColor(T.RGB(it.ok and "profReady" or (it.have ~= nil and "profShort" or "dim")))
                    l.n:ClearAllPoints(); l.n:SetPoint("TOPLEFT", l.q, "TOPRIGHT", S.s2, 0)
                    l.n:SetText(it.name or ("Item " .. it.itemID))
                    l.w:ClearAllPoints(); l.w:SetPoint("TOPLEFT", l.n, "TOPRIGHT", S.s2, 0); l.w:SetPoint("RIGHT", c, "RIGHT", -S.s3, 0)
                    l.w:SetText(whereText(it.where))
                    l.q:Show(); l.n:Show(); l.w:Show()
                    h = h + PT.ingRow
                    parts[#parts + 1] = string.format("%s %s / %d", it.name or ("item " .. it.itemID), it.have == nil and "?" or tostring(it.have), it.need)
                end
                for i = #(rg and rg.items or {}) + 1, #c.lines do local l = c.lines[i]; l.q:Hide(); l.n:Hide(); l.w:Hide() end
                c:SetHeight(h + S.s2)
                local id = r.id
                c.item = { key = "track:" .. id, frame = c, title = r.name,
                    detail = "Tracked in the game's objective tracker." .. (#parts > 0 and (" Needs " .. table.concat(parts, ", ") .. ".") or "")
                        .. " A opens it in Recipes; X stops tracking it.",
                    scroll = col.scroll, recipeID = id, group = "tracked", column = 2, actionLabel = "Open",
                    onActivate = function() page:OpenRecipe(id) end }
                c.onClick = function() page:OpenRecipe(id) end
                items[#items + 1] = c.item
                y = y + h + S.s2 + S.s3
            end
        end
        col.empty:SetShown(#items == 0)
        col.empty:SetText("Nothing tracked. In Recipes, X tracks a recipe in the game's objective tracker.")
        child:SetHeight(math.max(1, y + 4))
        return items
    end

    local function hideUnused()
        for _, list in ipairs({ "railRows", "nextRows", "cards" }) do
            for i = (page.used[list] or 0) + 1, #page[list] do page[list][i]:Hide() end
        end
    end

    -- Sizes the banner to the window: as tall as the mockup when there's room, shorter at the
    -- minimum size, so Next up and Tracked keep listsMin.
    local function sizeBanner()
        local h = (body:GetHeight() or 0)
        local bh = math.max(PT.bannerMin, math.min(PT.bannerMax, h - PT.listsMin))
        banner:SetHeight(bh)
    end

    function page:Redraw()
        self.data = ns.Professions.Get()
        self.used = {}
        local list = self.data.professions
        local none = #list == 0
        self.empty:SetShown(none)
        rail:SetShown(not none); right:SetShown(not none)
        if none then
            self.mode = "rail"
            self.focusRows = {}
            hideUnused()
            self:Refresh()
            return
        end
        if not selected() then self.sel = list[1].skillLine end
        local m = selected()
        local views = viewsOf(m)
        local has = false
        for _, v in ipairs(views) do if v == self.view then has = true end end
        if not has then self.view = "journey" end
        -- The view switch: only the views this profession has.
        local x = S.s4
        for _, v in ipairs({ "journey", "recipes", "gather" }) do
            local b = self.viewBtns[v]
            local on = false
            for _, vv in ipairs(views) do if vv == v then on = true end end
            b:SetShown(on)
            if on then
                b:SetLabel(v == "gather" and m.gather == "fishing" and "Fish" or VIEW_LABEL[v])
                b:ClearAllPoints(); b:SetPoint("LEFT", sw, "LEFT", x, 0)
                b:SetOn(v == self.view)
                x = x + b:GetWidth() + S.s1
            end
        end
        self.viewHint:SetText(#views > 1 and "Y switches the view" or "")
        self.views = views

        self.railFocus = paintRail(list)
        local pageRows = {}
        journey:SetShown(self.view == "journey")
        other:SetShown(self.view ~= "journey")
        if self.view == "journey" then
            sizeBanner()
            paintBanner(m)
            local roadItems = paintRoad(m)
            pageRows[#pageRows + 1] = { items = roadItems, section = 1 }
            local nexts, tracks = paintNext(m), paintTracked(m)
            -- Next up (left) and Tracked (right) side by side; up/down stay in a column.
            for i = 1, math.max(#nexts, #tracks) do
                local its = {}
                if nexts[i] then its[#its + 1] = nexts[i] end
                if tracks[i] then its[#its + 1] = tracks[i] end
                pageRows[#pageRows + 1] = { items = its, section = 2 }
            end
        else
            other.text:SetText(VIEW_LABEL[self.view] .. " comes in the next step.")
        end
        hideUnused()
        self.pageFocus = pageRows
        self:Refresh()
    end

    function page:Refresh()
        self.hasSections = self.mode == "page" and #(self.pageFocus or {}) > 1
        self.sectionLabel = "Section"
        self.backLabel = self.mode == "page" and "Professions" or nil
        -- While Focus.Update tells us the rail's focus moved, the grid stays as it is (same keys,
        -- same frames); rebuilding it from inside Focus.Update would re-enter it.
        if not self.followingFocus then ns.Focus.Rebuild() end
        ns.UI.RefreshHints()
    end

    function page:GetFocusRows()
        if self.mode == "page" then return self.pageFocus or {} end
        return self.railFocus or {}
    end

    -- Focus on the rail moves the page with it.
    function page:OnFocusChanged(item)
        if self.mode == "rail" and item and item.prof and item.prof ~= self.sel then
            self.sel = item.prof
            self.followingFocus = true
            local ok, err = pcall(self.Redraw, self)
            self.followingFocus = false
            if not ok then ns.Debug.Error("professions focus", err) end
        end
    end

    function page:Select(line)
        if self.sel == line then return end
        self.sel = line
        self:Redraw()
    end

    -- A on a rail entry: into the page (the first focus stop of the view).
    function page:EnterPage()
        local rows = self.pageFocus or {}
        local first = rows[1] and rows[1].items[1]
        if not first then return end
        self.mode = "page"
        self.pendingFocusKey = first.key
        self:Refresh()
    end

    -- Y: the next view this profession has. Focus stays where it was (rail), or goes to the
    -- view's first stop (page).
    function page:CycleView()
        local views = self.views or { "journey" }
        if #views < 2 then return false end
        local i = 1
        for k, v in ipairs(views) do if v == self.view then i = k end end
        self:SetView(views[i % #views + 1])
        return true
    end

    function page:SetView(v)
        self.view = v
        if self.mode == "rail" then self.pendingFocusKey = "p:" .. tostring(self.sel) end
        self:Redraw()
        if self.mode == "page" then
            local first = self.pageFocus and self.pageFocus[1] and self.pageFocus[1].items[1]
            if first then self.pendingFocusKey = first.key; self:Refresh() else self.mode = "rail"; self.pendingFocusKey = "p:" .. tostring(self.sel); self:Refresh() end
        end
    end

    -- A Next up line: open its view ("recipes:<filter>" or "gather").
    function page:Act(action)
        local view, filter = action:match("^(%a+):?(%a*)$")
        if filter and filter ~= "" then self.filter = filter end
        self.mode = "page"
        self:SetView(view)
    end

    -- A Tracked card: its recipe in Recipes (the list comes in step 7).
    function page:OpenRecipe(id)
        self.recipeSel = id
        self.filter = "all"
        self.mode = "page"
        self:SetView("recipes")
    end

    -- X: stop tracking the focused Tracked card's recipe (the game's own tracking).
    function page:ToggleTrack()
        local item = ns.Focus.Current()
        local id = item and item.recipeID
        if not id then return false end
        local tracked = ns.Professions.Get().tracked[id]
        local state = ns.Professions.SetTracked(id, not tracked)
        if state == nil then
            ns.UI.SetInfo(item.title, "The game didn't let Azerfolio change its tracking.")
        else
            ns.UI.SetInfo(item.title, state and "Tracking it in the game's objective tracker." or "No longer tracked.")
        end
        self:Redraw()
        return true
    end

    function page:OnButton(name)
        if name == "y" then return self:CycleView() end
        if name == "x" then return self:ToggleTrack() end
        return false
    end

    function page:GetHints()
        local hints = {}
        local item = ns.Focus.Current()
        if item and item.recipeID then hints[#hints + 1] = { "X", "Stop tracking" } end
        if self.views and #self.views > 1 then hints[#hints + 1] = { "Y", "View" } end
        return hints
    end

    -- B: from the page back to the rail, on the same profession.
    function page:Back()
        if self.mode ~= "page" then return false end
        self.mode = "rail"
        self.pendingFocusKey = "p:" .. tostring(self.sel)
        self:Refresh()
        return true
    end

    function page:Layout()
        if self:IsShown() then self:Redraw() else self.dirty = true end
    end

    -- Profession data changed (a window or trainer read, a skill-up, tracking, sources ready):
    -- redraw, keeping focus.
    local function changed()
        if not page:IsShown() then page.dirty = true; return end
        local cur = ns.UI.CurrentTab() == "professions" and ns.Focus.Current()
        if cur and page.pendingFocusKey == nil then page.pendingFocusKey = cur.key end
        page:Redraw()
    end
    ns.Events.On("AZF_PROFESSIONS_UPDATED", changed)
    -- Bag counts in Tracked.
    ns.Events.Register("BAG_UPDATE_DELAYED", function()
        if page:IsShown() and page.view == "journey" then ns.Events.Debounce("professions:bags", 0.3, changed) end
    end)
    page:SetScript("OnShow", function(self)
        if self.dirty then self.dirty = false; self:Redraw() end
    end)
    body:SetScript("OnSizeChanged", function() if page:IsShown() then page:Redraw() end end)

    page:Redraw()
    if page.data and page.data.professions[1] then page.pendingFocusKey = "p:" .. tostring(page.sel) end
    return page
end

ns.UI.RegisterTab({
    id = "professions",
    label = "Professions",
    icon = ns.Theme.Icon("professions", "Interface\\Icons\\Trade_BlackSmithing"),
    order = 5,
    compactHeader = true,
    info = "Your professions: skill, ranks, recipes and where to gather.",
    build = build,
})
