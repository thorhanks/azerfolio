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
    if w.kind == "craft" then
        return "Craft it: " .. w.recipe.name .. (w.recipe.prof and (" (" .. w.recipe.prof .. ")") or "")
            .. (w.recipe.known and "" or " (not known yet)")
    end
    if w.kind == "gather" then return "Gather: " .. w.node.name .. (w.node.skill and (" (from " .. w.node.skill .. ")") or "") end
    if w.kind == "vendor" then
        local v = w.vendor
        local place = v.place or (v.maps and zoneName(v.maps[1]))
        return "Vendor · " .. v.npc .. (place and (", " .. place) or "") .. (w.more > 0 and (" (+" .. w.more .. " more)") or "")
    end
    if w.kind == "drop" then return "Drops from " .. w.n .. " " .. plural(w.n, "creature") end
    return "Where to get it isn't known"
end

-- Recipes view words ------------------------------------------------------------------------

local FILTER_LABEL = { foryou = "For you now", all = "All", known = "Known", now = "Learn now", later = "Later", nosource = "No known source" }
local FILTER_INFO = {
    foryou = "What you can learn now, what still gives you skill, and what opens in the next 25 skill points.",
    all = "Every recipe with a known source (and the ones you know).",
    known = "Recipes you know.",
    now = "Recipes a trainer you've visited teaches at your skill.",
    later = "Recipes with a known source you can't learn yet, or whose skill to learn isn't known.",
    nosource = "Recipes the game lists that no trainer you've visited or recipe item is known to teach (Season of Discovery too). Not counted.",
}
local SOURCE_TAG = { trainer = "Trainer", vendor = "Vendor", drop = "Drop", object = "Container", quest = "Quest", item = "Item" }

-- One source of a recipe, in words.
local function sourceText(s)
    if s.kind == "trainer" then return "Trainer · skill " .. s.skill end
    if s.kind == "vendor" then
        local place = s.place or (s.maps and zoneName(s.maps[1]))
        return "Vendor · " .. tostring(s.npc) .. (place and (", " .. place) or "")
    end
    if s.kind == "drop" then
        local z = zonesText(s.maps, 2)
        return "Drop · " .. s.n .. " " .. plural(s.n, "creature") .. (z ~= "" and (", " .. z) or "")
    end
    if s.kind == "object" then return "Found in " .. (s.n == 1 and "a container" or (s.n .. " containers")) end
    if s.kind == "quest" then return "Quest reward" .. ((s.n or 1) > 1 and (" · " .. s.n .. " quests") or "") end
    return "Recipe item · where it drops isn't known"
end

-- "learn 40" / "until 60" / "grey" / "grey 100", for a list row.
local function recipeSkillText(r, skill)
    if r.known then return r.givesSkill and ("until " .. r.grey) or "grey" end
    if r.learnAt then return "learn " .. r.learnAt end
    return r.grey and ("grey " .. r.grey) or ""
end

local function recipeStateText(r)
    if r.state == "known" then return "Known", "complete" end
    if r.state == "now" then return "You can learn it now", "profGo" end
    if r.state == "later" then
        if r.learnAt then return "Learn at skill " .. r.learnAt, "text" end
        return "Not yet: the skill to learn it isn't known", "dim"
    end
    if r.sod then return "In the game's Season of Discovery list; may not be offered on Forever", "dim" end
    return "No trainer you've visited or recipe item is known to teach it", "dim"
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

-- A recipe row (one line): source tag, name (with Tracked), skill text, state.
local function newRecipeRow(parent)
    local T, PT, W, S = ns.Theme, ns.Theme.layout.profTab, ns.Widgets, ns.Theme.space
    local r = W.FocusRow(parent, PT.recipeRow)
    r.src = T.Text(r, "xs", "dim")
    r.src:SetPoint("LEFT", r, "LEFT", S.s1, 0)
    r.src:SetWidth(PT.recipeSrc); r.src:SetJustifyH("LEFT")
    r.state = T.Text(r, "xs", "profGo")
    r.state:SetPoint("RIGHT", r, "RIGHT", -S.s2, 0)
    r.state:SetWidth(PT.recipeState); r.state:SetJustifyH("RIGHT")
    r.check = r:CreateTexture(nil, "ARTWORK")
    r.check:SetTexture(T.files.checkDone)
    r.check:SetSize(16, 16)
    r.check:SetPoint("RIGHT", r, "RIGHT", -S.s2, 0)
    r.check:SetVertexColor(T.RGB("complete"))
    r.skill = T.Text(r, "xs", "dim")
    r.skill:SetPoint("RIGHT", r.state, "LEFT", -S.s2, 0)
    r.skill:SetWidth(PT.recipeSkill); r.skill:SetJustifyH("RIGHT")
    r.name = T.Text(r, "sm", "white")
    r.name:SetPoint("LEFT", r.src, "RIGHT", S.s1, 0)
    r.name:SetPoint("RIGHT", r.skill, "LEFT", -S.s2, 0)
    r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
    r:SetScript("OnClick", function(self) if self.onClick then self.onClick() end end)
    return r
end

-- A line in the recipe detail: a label column and text (sources, ingredients). Focusable.
local function newDetailLine(parent)
    local T, PT, W, S = ns.Theme, ns.Theme.layout.profTab, ns.Widgets, ns.Theme.space
    local l = W.FocusRow(parent, PT.detailLine)
    l.left = T.Text(l, "xs", "text")
    l.left:SetPoint("LEFT", l, "LEFT", S.s1, 0)
    l.left:SetWidth(PT.detailLeft); l.left:SetJustifyH("LEFT")
    l.text = T.Text(l, "xs", "white")
    l.text:SetPoint("TOPLEFT", l.left, "TOPRIGHT", S.s1, 0)
    l.text:SetPoint("RIGHT", l, "RIGHT", -S.s1, 0)
    l.text:SetJustifyH("LEFT"); l.text:SetWordWrap(false)
    l.sub = T.Text(l, "xs", "dim")
    l.sub:SetPoint("TOPLEFT", l.text, "BOTTOMLEFT", 0, -1)
    l.sub:SetPoint("RIGHT", l, "RIGHT", -S.s1, 0)
    l.sub:SetJustifyH("LEFT"); l.sub:SetWordWrap(false)
    l:SetScript("OnClick", function(self) if self.onClick then self.onClick() end end)
    return l
end

-- A Gather row: name (and zones), "from 65" / "grey", the state.
local function newGatherRow(parent)
    local T, PT, W, S = ns.Theme, ns.Theme.layout.profTab, ns.Widgets, ns.Theme.space
    local r = W.FocusRow(parent, PT.gatherRow)
    r.state = T.Text(r, "xs", "profGo")
    r.state:SetPoint("RIGHT", r, "RIGHT", -S.s2, 0)
    r.state:SetWidth(PT.recipeState + 20); r.state:SetJustifyH("RIGHT")
    r.skill = T.Text(r, "xs", "dim")
    r.skill:SetPoint("RIGHT", r.state, "LEFT", -S.s2, 0)
    -- "from 150" wrapped at the recipe list's width (WoWScrnShot_111426_123336).
    r.skill:SetWidth(PT.recipeSkill + 20); r.skill:SetJustifyH("RIGHT"); r.skill:SetWordWrap(false)
    r.name = T.Text(r, "sm", "white")
    r.name:SetPoint("TOPLEFT", r, "TOPLEFT", S.s2, -4)
    r.name:SetPoint("RIGHT", r.skill, "LEFT", -S.s2, 0)
    r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
    r.zones = T.Text(r, "xs", "dim")
    r.zones:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
    r.zones:SetPoint("RIGHT", r.skill, "LEFT", -S.s2, 0)
    r.zones:SetJustifyH("LEFT"); r.zones:SetWordWrap(false)
    return r
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

    -- Recipes: the toolbar (filter chips with counts, the summary), then the list (left) and
    -- the focused recipe (right, PT.detail wide), like the Class tab's road and stop.
    local recipes = CreateFrame("Frame", nil, body)
    recipes:SetAllPoints()
    local tb = CreateFrame("Frame", nil, recipes)
    tb:SetPoint("TOPLEFT"); tb:SetPoint("TOPRIGHT"); tb:SetHeight(PT.toolbar)
    T.Solid(tb, "black", "BACKGROUND", 0.28):SetAllPoints()
    page.chips = {}
    for _, f in ipairs(ns.ProfessionRules.FILTERS) do
        local b = W.Control(tb)
        b.filter = f
        b:SetScript("OnClick", function() page:SetFilter(f) end)
        page.chips[#page.chips + 1] = b
    end
    page.recSum = T.Text(tb, "xs", "dim")
    page.recSum:SetPoint("RIGHT", tb, "RIGHT", -S.s4, 0)
    local det = CreateFrame("Frame", nil, recipes)
    det:SetPoint("TOPRIGHT", tb, "BOTTOMRIGHT"); det:SetPoint("BOTTOMRIGHT")
    det:SetWidth(PT.detail)
    T.Solid(det, "black", "BACKGROUND", 0.22):SetAllPoints()
    local dedge = T.Solid(det, "divider", "BORDER")
    dedge:SetPoint("TOPLEFT"); dedge:SetPoint("BOTTOMLEFT"); dedge:SetWidth(1)
    det.scroll = W.Scroll(det)
    det.scroll:SetPoint("TOPLEFT", S.s4, -S.s3); det.scroll:SetPoint("BOTTOMRIGHT", -S.s3, S.s2)
    local dc = det.scroll.child
    det.name = T.Text(dc, "lg", "gold")
    det.name:SetPoint("TOPLEFT"); det.name:SetPoint("RIGHT", dc, "RIGHT", -S.s4, 0)
    det.name:SetJustifyH("LEFT")
    det.state = T.Text(dc, "sm", "text")
    det.state:SetPoint("TOPLEFT", det.name, "BOTTOMLEFT", 0, -S.s1); det.state:SetPoint("RIGHT", dc, "RIGHT", -S.s2, 0)
    det.state:SetJustifyH("LEFT")
    det.tracked = T.Text(dc, "xs", "profTracked")
    det.facts = T.Text(dc, "xs", "dim")
    det.facts:SetJustifyH("LEFT")
    det.howH = T.Text(dc, "sm", "gold"); det.howH:SetText("How to get it")
    det.ingH = T.Text(dc, "sm", "gold")
    det.note = T.Text(dc, "xs", "dim"); det.note:SetJustifyH("LEFT")
    det.track = W.Control(dc)
    det.track:SetScript("OnClick", function() page:ToggleTrack(page.recipeSel) end)
    det.lines = {}
    page.det = det
    local rlist = CreateFrame("Frame", nil, recipes)
    rlist:SetPoint("TOPLEFT", tb, "BOTTOMLEFT"); rlist:SetPoint("BOTTOMRIGHT", det, "BOTTOMLEFT")
    rlist.scroll = W.Scroll(rlist)
    rlist.scroll:SetPoint("TOPLEFT", 0, -S.s2); rlist.scroll:SetPoint("BOTTOMRIGHT", -S.s2, S.s2)
    rlist.note = T.Text(rlist.scroll.child, "sm", "dim")
    rlist.note:SetJustifyH("LEFT")
    page.rlist = rlist
    page.recipeRows, page.recHeaders, page.detailLines, page.gatherRows = {}, {}, {}, {}
    page.recipes = recipes

    -- Gather: the hand-curated node table (Mining, Herbalism, Skinning; Fishing's brackets).
    local gather = CreateFrame("Frame", nil, body)
    gather:SetAllPoints()
    gather.scroll = W.Scroll(gather)
    gather.scroll:SetPoint("TOPLEFT", 0, -S.s2); gather.scroll:SetPoint("BOTTOMRIGHT", -S.s2, S.s2)
    gather.head = W.Header(gather.scroll.child)
    gather.foot = T.Text(gather.scroll.child, "xs", "dim")
    gather.foot:SetJustifyH("LEFT")
    page.gather = gather

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

    -- The focused recipe on the right. Returns its focus items (the sources, the ingredients,
    -- the Track button), the "detail" column.
    local function paintDetail(m, r)
        local det = page.det
        local dc = det.scroll.child
        page.used.detailLines = 0
        for _, l in ipairs(page.detailLines) do l:Hide() end
        local items = {}
        det.name:SetShown(r ~= nil); det.state:SetShown(r ~= nil); det.facts:SetShown(r ~= nil)
        det.howH:SetShown(r ~= nil); det.ingH:SetShown(r ~= nil); det.track:SetShown(r ~= nil); det.tracked:SetShown(false)
        det.note:SetShown(r == nil)
        if not r then
            det.note:ClearAllPoints(); det.note:SetPoint("TOPLEFT"); det.note:SetPoint("RIGHT", dc, "RIGHT", -S.s2, 0)
            det.note:SetText("Choose a recipe.")
            dc:SetHeight(40)
            return items
        end
        local width = math.max(1, (dc:GetWidth() or PT.detail) - S.s2)
        det.name:SetText(r.name)
        local st, color = recipeStateText(r)
        det.state:SetText(st); det.state:SetTextColor(T.RGB(color))
        det.tracked:SetShown(r.tracked)
        det.tracked:SetText("Tracked")
        det.tracked:ClearAllPoints(); det.tracked:SetPoint("TOPLEFT", det.state, "BOTTOMLEFT", 0, -S.s1)
        det.facts:ClearAllPoints()
        det.facts:SetPoint("TOPLEFT", r.tracked and det.tracked or det.state, "BOTTOMLEFT", 0, -S.s2)
        det.facts:SetPoint("RIGHT", dc, "RIGHT", -S.s2, 0)
        det.facts:SetText(string.format("Learn at |cffffffff%s|r   ·   Gives skill until |cffffffff%s|r%s   ·   %s",
            r.learnAt and tostring(r.learnAt) or "?", r.grey and tostring(r.grey) or "?",
            (r.grey and m.skill and m.skill >= r.grey) and " (grey)" or "", r.categoryName or "No category"))
        local y = (det.name:GetStringHeight() or 20) + (det.state:GetStringHeight() or 14) + (r.tracked and 18 or 0)
            + (det.facts:GetStringHeight() or 14) + S.s4 + S.s3
        local function line(left, text, sub, item)
            local l = take("detailLines", newDetailLine, dc)
            l:ClearAllPoints(); l:SetPoint("TOPLEFT", dc, "TOPLEFT", 0, -y); l:SetWidth(width)
            l.left:SetText(left or ""); l.text:SetText(text or ""); l.sub:SetText(sub or "")
            l.sub:SetShown(sub ~= nil)
            l:SetHeight(sub and PT.detailLine or 22)
            l.item = item
            item.frame = l; item.scroll = det.scroll; item.group = "detail"
            items[#items + 1] = item
            y = y + (sub and PT.detailLine or 22) + 2
            return l
        end
        det.howH:ClearAllPoints(); det.howH:SetPoint("TOPLEFT", dc, "TOPLEFT", 0, -y)
        y = y + 22
        if #r.sources == 0 then
            line("", r.known and "Known · where it's taught isn't recorded" or (r.sod and "Season of Discovery" or "No known source"), nil,
                { key = "src:none", title = "How to get it", detail = select(1, recipeStateText(r)) .. "." })
        end
        for i, s in ipairs(r.sources) do
            local text = sourceText(s)
            line(SOURCE_TAG[s.kind] or "", text, nil, { key = "src:" .. i, title = r.name, detail = text .. "." })
        end
        y = y + S.s2
        local rg = ns.Professions.Reagents(r.id, m)
        local sum = rg and (rg.ready and "you have everything for one" or (rg.missing > 0 and ("missing " .. rg.missing))
            or (rg.unknown and "counts not known yet") or "") or "not known"
        det.ingH:ClearAllPoints(); det.ingH:SetPoint("TOPLEFT", dc, "TOPLEFT", 0, -y)
        det.ingH:SetText("Ingredients  |cffb5a891" .. sum .. "|r")
        y = y + 22
        for i, it in ipairs(rg and rg.items or {}) do
            local have = it.have == nil and "?" or tostring(it.have)
            local l = line(have .. " / " .. it.need, it.name or ("Item " .. it.itemID), whereText(it.where),
                { key = "ing:" .. i, title = it.name or ("Item " .. it.itemID),
                  detail = string.format("You have %s, it needs %d. %s.", have, it.need, whereText(it.where)) })
            l.left:SetTextColor(T.RGB(it.ok and "profReady" or (it.have ~= nil and "profShort" or "dim")))
        end
        if not rg then
            line("", "The game gives no ingredients for it.", nil, { key = "ing:none", title = "Ingredients", detail = "The game gives no ingredients for this recipe." })
        end
        y = y + S.s3
        det.track:ClearAllPoints(); det.track:SetPoint("TOPLEFT", dc, "TOPLEFT", 0, -y)
        det.track:SetLabel(r.tracked and "X  Stop tracking" or "X  Track in the objective tracker")
        local trackItem = { key = "track", frame = det.track, title = r.tracked and "Stop tracking" or "Track",
            detail = "The game's own recipe tracking: it shows in the objective tracker with what you carry.",
            scroll = det.scroll, group = "detail", actionLabel = r.tracked and "Stop tracking" or "Track",
            onActivate = function() page:ToggleTrack(r.id) end }
        det.track.item = trackItem
        items[#items + 1] = trackItem
        y = y + L.controlHeight + S.s4
        dc:SetHeight(math.max(1, y))
        return items
    end

    -- The list in levelling order, under rank headers ("Apprentice · skill 1-75 · 6 of 22
    -- known"). Returns the focus rows (the chips first, then one per recipe).
    local BANDS = { { 0, 75, "Apprentice", "1-75" }, { 75, 150, "Journeyman", "75-150" }, { 150, 225, "Expert", "150-225" },
        { 225, 1e9, "Artisan", "225-300" } }
    local function paintRecipes(m)
        local rec = m.recipes
        local rows = {}
        -- Chips with counts.
        local x = S.s4
        local chipItems = {}
        for _, b in ipairs(page.chips) do
            local f = b.filter
            local n = rec and (f == "foryou" and rec.counts.foryou or f == "all" and rec.counts.all or rec.counts[f]) or 0
            b:SetLabel(FILTER_LABEL[f] .. "  " .. n, L.controlPadTight)
            b:ClearAllPoints(); b:SetPoint("LEFT", tb, "LEFT", x, 0)
            b:SetOn(page.filter == f)
            x = x + b:GetWidth() + S.s1
            b.item = { key = "chip:" .. f, frame = b, title = FILTER_LABEL[f], detail = FILTER_INFO[f], actionLabel = "Show",
                onActivate = function() page:SetFilter(f) end }
            chipItems[#chipItems + 1] = b.item
        end
        page.recSum:SetText(rec and string.format("|cffffffff%d|r known · |cffffffff%d|r with a known source%s", rec.counts.known, rec.counts.all,
            rec.counts.nosource > 0 and (" · " .. rec.counts.nosource .. " not counted") or "") or "")
        local child = page.rlist.scroll.child
        local width = math.max(1, (child:GetWidth() or 400) - L.listInset - S.s2)
        local y = S.s1
        local note = page.rlist.note
        note:Hide()
        if not rec then
            note:ClearAllPoints(); note:SetPoint("TOPLEFT", child, "TOPLEFT", L.listInset, -S.s6); note:SetWidth(width)
            note:SetText("Open your " .. m.name .. " window once (from your spellbook) and Azerfolio reads every recipe from it, with its ingredients.")
            note:Show()
            child:SetHeight(120)
            page.recipeSel = nil
            return { { items = chipItems, section = 1 } }, nil
        end
        local shown = ns.ProfessionRules.Filter(rec, page.filter, m.skill)
        local first, selRow
        local section = 1
        rows[#rows + 1] = { items = chipItems, section = 1 }
        for _, band in ipairs(BANDS) do
            local list, known = {}, 0
            for _, r in ipairs(shown) do
                local o = r.order == math.huge and 1e8 or r.order
                if o >= band[1] and o < band[2] then list[#list + 1] = r; if r.known then known = known + 1 end end
            end
            if #list > 0 then
                section = section + 1
                local h = take("recHeaders", W.Header, child)
                h:ClearAllPoints()
                h:SetPoint("TOPLEFT", child, "TOPLEFT", L.listInset, -y); h:SetPoint("TOPRIGHT", child, "TOPRIGHT", -S.s2, -y)
                h.text:SetText(band[3]); h.count:SetText("skill " .. band[4] .. " · " .. known .. " of " .. #list .. " known")
                y = y + L.listHeader + S.s1
                for _, r in ipairs(list) do
                    local row = take("recipeRows", newRecipeRow, child)
                    row:ClearAllPoints(); row:SetPoint("TOPLEFT", child, "TOPLEFT", L.listInset, -y); row:SetWidth(width)
                    row.src:SetText(SOURCE_TAG[r.sources[1] and r.sources[1].kind or ""] or "")
                    row.name:SetText(r.name .. (r.tracked and "  |cff6fa8ffTracked|r" or ""))
                    row.name:SetTextColor(T.RGB(r.state == "nosource" and "dim" or "white"))
                    row.skill:SetText(recipeSkillText(r, m.skill))
                    row.check:SetShown(r.state == "known")
                    row.state:SetShown(r.state ~= "known")
                    row.state:SetText(r.state == "now" and "Learn now" or (r.state == "later" and r.learnAt and ("from " .. r.learnAt)) or "")
                    row.state:SetTextColor(T.RGB(r.state == "now" and "profGo" or "dim"))
                    row:SetSelected(r.id == page.recipeSel)
                    local id = r.id
                    local st = recipeStateText(r)
                    row.item = { key = "r:" .. id, frame = row, title = r.name, recipe = r, scroll = page.rlist.scroll,
                        topGap = L.listHeader + S.s2, group = "list", column = 1,
                        detail = st .. ". X " .. (r.tracked and "stops tracking it." or "tracks it in the game's objective tracker."),
                        actionLabel = "Details", onActivate = function() page:EnterDetail() end }
                    row.onClick = function() page:SelectRecipe(id) end
                    rows[#rows + 1] = { items = { row.item }, section = section }
                    if not first then first = r end
                    if r.id == page.recipeSel then selRow = r end
                    y = y + PT.recipeRow
                end
                y = y + S.s2
            end
        end
        if #shown == 0 then
            note:ClearAllPoints(); note:SetPoint("TOPLEFT", child, "TOPLEFT", L.listInset, -S.s6); note:SetWidth(width)
            note:SetText("None here.")
            note:Show()
            y = y + 60
        end
        -- Without a trainer's list, item-taught recipes are all there is to go on: say so.
        if not m.trainerTime and rec.counts.nosource > 0 then
            note:ClearAllPoints(); note:SetPoint("TOPLEFT", child, "TOPLEFT", L.listInset, -y - S.s2); note:SetWidth(width)
            note:SetText("You haven't opened a " .. m.name .. " trainer's list yet: visiting one shows which recipes it teaches and the skill each needs.")
            note:Show()
            y = y + 50
        end
        child:SetHeight(math.max(1, y))
        if not selRow then page.recipeSel = first and first.id or nil; selRow = first end
        for _, row in ipairs(page.recipeRows) do if row:IsShown() then row:SetSelected(row.item and row.item.recipe and row.item.recipe.id == page.recipeSel) end end
        return rows, selRow
    end

    local function paintGather(m)
        local g = m.gatherRows
        local child = page.gather.scroll.child
        local width = math.max(1, (child:GetWidth() or 600) - L.listInset - S.s2)
        local head = page.gather.head
        head:ClearAllPoints(); head:SetPoint("TOPLEFT", child, "TOPLEFT", L.listInset, -S.s1); head:SetPoint("TOPRIGHT", child, "TOPRIGHT", -S.s2, -S.s1)
        head.text:SetText(g and g.fishing and "Where to fish" or "Where to gather")
        head.count:SetText("a guide, not game data · your skill " .. tostring(m.skill or "?"))
        local y = L.listHeader + S.s2
        local rows = {}
        for i, row in ipairs(g and g.rows or {}) do
            local r = take("gatherRows", newGatherRow, child)
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", child, "TOPLEFT", L.listInset, -y); r:SetWidth(width)
            local name = row.name or zoneName(row.mapID) or ("Zone " .. tostring(row.mapID))
            local zones = row.name and zonesText(row.zones, 6) or ""
            if row.name and zones == "" then zones = "Where it grows isn't in the guides" end
            r.name:SetText(name); r.zones:SetText(zones)
            local skillTxt = row.from == nil and "skill ?" or (row.state == "grey" and "grey" or ("from " .. row.from))
            r.skill:SetText(skillTxt)
            local stateTxt = row.state == "gives" and "Gives skill" or row.state == "later" and (row.togo .. " to go")
                or row.state == "current" and "Your skill" or row.state == "unknown" and "Not known" or ""
            r.state:SetText(stateTxt)
            r.state:SetTextColor(T.RGB((row.state == "gives" or row.state == "current") and "profReady" or "dim"))
            r.name:SetTextColor(T.RGB(row.state == "grey" and "dim" or "white"))
            local alt = row.alt and #row.alt > 0 and (" Other guides say " .. table.concat(row.alt, " or ") .. ".") or ""
            local detail
            if g.fishing then detail = "Good places to fish from skill " .. row.from .. ". " .. zonesText(row.zones, 8) .. "."
            elseif row.from == nil then detail = "The skill it needs isn't known yet (Forever-only)." .. alt
            else
                detail = "Needs skill " .. row.from .. (row.greyAt and ("; gives skill until " .. row.greyAt) or "") .. "." .. alt
                    .. (zones ~= "" and (" " .. zones .. ".") or "")
            end
            r.item = { key = "g:" .. i, frame = r, title = name, detail = detail, scroll = page.gather.scroll, topGap = L.listHeader + S.s2 }
            rows[#rows + 1] = { items = { r.item }, section = 1 }
            y = y + PT.gatherRow
        end
        local foot = page.gather.foot
        foot:ClearAllPoints(); foot:SetPoint("TOPLEFT", child, "TOPLEFT", L.listInset, -y - S.s3); foot:SetWidth(width)
        foot:SetText(m.gather == "skinning"
            and "From the zone level guide and a Classic rule (the skill a creature of each level needs); the game doesn't list it."
            or "A hand-curated guide from Classic and Forever profession guides; the game doesn't list where nodes grow or fish bite. Skills in doubt are open check G1.")
        child:SetHeight(y + 70)
        return rows
    end

    local function hideUnused()
        for _, list in ipairs({ "railRows", "nextRows", "cards", "recipeRows", "recHeaders", "gatherRows" }) do
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
        recipes:SetShown(self.view == "recipes")
        gather:SetShown(self.view == "gather")
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
        elseif self.view == "recipes" then
            local rows, sel = paintRecipes(m)
            pageRows = rows
            self.detailFocus = paintDetail(m, sel)
            self.selRecipe = sel
            if self.recipeFocus == "detail" and #self.detailFocus == 0 then self.recipeFocus = "list" end
        else
            pageRows = paintGather(m)
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

    -- In Recipes, focus is in the list or in the focused recipe's detail (A / B).
    function page:GetFocusRows()
        if self.mode ~= "page" then return self.railFocus or {} end
        if self.view == "recipes" and self.recipeFocus == "detail" then
            local rows = {}
            for _, it in ipairs(self.detailFocus or {}) do rows[#rows + 1] = { items = { it }, section = 1 } end
            return rows
        end
        return self.pageFocus or {}
    end

    -- Focus on the rail moves the page with it; focus on a recipe moves the detail with it.
    function page:OnFocusChanged(item)
        if self.mode == "rail" and item and item.prof and item.prof ~= self.sel then
            self.sel = item.prof
            self.followingFocus = true
            local ok, err = pcall(self.Redraw, self)
            self.followingFocus = false
            if not ok then ns.Debug.Error("professions focus", err) end
        elseif self.mode == "page" and self.view == "recipes" and item and item.recipe and item.recipe.id ~= self.recipeSel then
            self.recipeSel = item.recipe.id
            local m = selected()
            if m then self.detailFocus = paintDetail(m, item.recipe); self.selRecipe = item.recipe end
            for _, row in ipairs(self.recipeRows) do
                if row:IsShown() then row:SetSelected(row.item and row.item.recipe and row.item.recipe.id == self.recipeSel) end
            end
            page.det.scroll:SetVerticalScroll(0)
        end
    end

    function page:Select(line)
        if self.sel == line then return end
        self.sel = line
        self:Redraw()
    end

    -- The view's first focus stop: the first recipe in Recipes (the chips are one up), else the first.
    local function firstKey()
        local rows = page.pageFocus or {}
        if page.view == "recipes" and rows[2] then return rows[2].items[1].key end
        return rows[1] and rows[1].items[1] and rows[1].items[1].key
    end

    -- A on a rail entry: into the page.
    function page:EnterPage()
        local key = firstKey()
        if not key then return end
        self.mode = "page"
        self.recipeFocus = "list"
        self.pendingFocusKey = key
        self:Refresh()
    end

    -- Y: the next view this profession has. Focus stays on the rail, or goes to the view's first stop.
    function page:CycleView()
        local views = self.views or { "journey" }
        if #views < 2 then return false end
        local i = 1
        for k, v in ipairs(views) do if v == self.view then i = k end end
        self:SetView(views[i % #views + 1])
        return true
    end

    function page:SetView(v, focusKey)
        self.view = v
        self.recipeFocus = "list"
        if self.mode == "rail" then self.pendingFocusKey = "p:" .. tostring(self.sel) end
        self:Redraw()
        if self.mode == "page" then
            local key = focusKey or firstKey()
            if key then self.pendingFocusKey = key else self.mode = "rail"; self.pendingFocusKey = "p:" .. tostring(self.sel) end
            self:Refresh()
        end
    end

    -- A filter chip (focus stays on it).
    function page:SetFilter(f)
        self.filter = f
        self.recipeFocus = "list"
        if self.mode == "page" then self.pendingFocusKey = "chip:" .. f end
        self:Redraw()
    end

    -- A click on a recipe row.
    function page:SelectRecipe(id)
        self.recipeSel = id
        self.mode, self.recipeFocus = "page", "list"
        self.pendingFocusKey = "r:" .. id
        self:Redraw()
    end

    -- A on a recipe: into its detail (B back to the row).
    function page:EnterDetail()
        local first = self.detailFocus and self.detailFocus[1]
        if not first then return end
        self.recipeFocus = "detail"
        self.pendingFocusKey = first.key
        self:Refresh()
    end

    -- A Next up line: open its view ("recipes:<filter>" or "gather").
    function page:Act(action)
        local view, filter = action:match("^(%a+):?(%a*)$")
        if filter and filter ~= "" then self.filter = filter end
        self.mode = "page"
        self:SetView(view)
    end

    -- A Tracked card: its recipe in Recipes, under a filter that shows it.
    function page:OpenRecipe(id)
        local m = selected()
        local r
        for _, x in ipairs(m and m.recipes and m.recipes.list or {}) do if x.id == id then r = x end end
        self.recipeSel = id
        if r and not ns.ProfessionRules.ForYou(r, m.skill) then self.filter = r.state == "nosource" and "nosource" or "all"
        elseif r then self.filter = "foryou" end
        self.mode = "page"
        self:SetView("recipes", "r:" .. id)
    end

    -- The recipe X acts on: the focused row or Tracked card, else the recipe shown in Recipes.
    local function trackTarget(id)
        if id then return id end
        local item = ns.Focus.Current()
        if item and item.recipeID then return item.recipeID end
        if item and item.recipe then return item.recipe.id end
        if page.mode == "page" and page.view == "recipes" then return page.recipeSel end
    end

    -- X: Track / Untrack through the game's own tracking.
    function page:ToggleTrack(id)
        id = trackTarget(id)
        if not id or not ns.Professions.CanTrack() then return false end
        local name = tostring(id)
        local m = selected()
        for _, x in ipairs(m and m.recipes and m.recipes.list or {}) do if x.id == id then name = x.name end end
        local tracked = ns.Professions.Get().tracked[id]
        local state = ns.Professions.SetTracked(id, not tracked)
        local cur = ns.Focus.Current()
        if cur then self.pendingFocusKey = cur.key end
        self:Redraw()
        if state == nil then
            ns.UI.SetInfo(name, "The game didn't let Azerfolio change its tracking.")
        else
            ns.UI.SetInfo(name, state and "Tracking it in the game's objective tracker." or "No longer tracked.")
        end
        return true
    end

    function page:OnButton(name)
        if name == "y" then return self:CycleView() end
        if name == "x" then return self:ToggleTrack() end
        return false
    end

    function page:GetHints()
        local hints = {}
        local id = trackTarget()
        if id and ns.Professions.CanTrack() then
            hints[#hints + 1] = { "X", ns.Professions.Get().tracked[id] and "Stop tracking" or "Track" }
        end
        if self.views and #self.views > 1 then hints[#hints + 1] = { "Y", "View" } end
        return hints
    end

    -- B: from a recipe's detail back to its row; from the page back to the rail.
    function page:Back()
        if self.mode ~= "page" then return false end
        if self.view == "recipes" and self.recipeFocus == "detail" then
            self.recipeFocus = "list"
            self.pendingFocusKey = "r:" .. tostring(self.recipeSel)
            self:Refresh()
            return true
        end
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
