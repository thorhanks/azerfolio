-- The Dungeons tab (Phase 16 task 4; spec §7.12; mockups/DESIGN.md "Dungeons tab", rounds 1-8;
-- the mockup's renderDungeons in mockups/app.js): every dungeon and raid from Data/Dungeons.lua.
--   * the toolbar: filters All / For your level / Dungeons / Raids / New in Forever, the count
--     ("41 of 41 · levels are a guide") and the view toggle (Y cycles it);
--   * Cards (default): three across, 16:10, the instance's painting edge to edge in the thin
--     bronze frame (card-frame-a), tags top left, the name, the meta line and the quest bar at the
--     foot; every quest done: a gold edge and ✓; some done: an orange edge;
--   * List: rows (the entrance zone's art, name and tags, where, levels with the level bar, bosses,
--     the quest bar); in the wide window the list sits beside the instance's page and the page
--     follows focus;
--   * level-bracket groups with sticky headers (LT/RT), "every quest done in n of m".
-- The Road view is task 6: until it's built, Y cycles Cards · List only.
-- The instance page is task 5: A opens its banner (painting, name, blurb, levels, the quest
-- score) and a note that the rest of the page comes next.
-- Honest data: progress is quests only (DungeonRules.Progress); while the client doesn't say
-- which quests are done (Dungeons.CompletionKnown() false) done is unknown, shown as "?", never 0.
-- Everything shown comes from ns.Dungeons / ns.DungeonRules; this file words and draws it.
local _, ns = ...

local FILTERS = { { "all", "All" }, { "foryou", "For your level" }, { "dungeon", "Dungeons" }, { "raid", "Raids" },
    { "forever", "New in Forever" } }
local FILTER_INFO = { all = "Every dungeon and raid.", foryou = "Instances whose level range suits yours (the zone guide's rule).",
    dungeon = "Only dungeons.", raid = "Only raids.", forever = "The nine dungeons new in Forever." }
-- The views Y cycles. The Road (task 6) joins once it's built.
local VIEWS = { { "cards", "Cards" }, { "list", "List" } }

local function settings() return ns.db.dungeons end
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

---------------------------------------------------------------------------------------------
-- Words (pure: from an entry { inst, fit, bracket, progress } and whether done is known)
---------------------------------------------------------------------------------------------

local Words = {}

-- The view shown for a saved view (the Road isn't built yet: Cards).
function Words.View(v)
    for _, x in ipairs(VIEWS) do if x[1] == v then return v end end
    return "cards"
end

-- Y: the next view.
function Words.NextView(v)
    v = Words.View(v)
    for i, x in ipairs(VIEWS) do if x[1] == v then return VIEWS[i % #VIEWS + 1][1] end end
    return "cards"
end

-- The entrance zones' names: "Westfall", "Searing Gorge / Burning Steppes"; nameOf(mapID) -> name.
function Words.Where(inst, nameOf)
    local out = {}
    for _, id in ipairs(inst.zones or {}) do
        local n = nameOf and nameOf(id)
        if n then out[#out + 1] = n end
    end
    return table.concat(out, " / ")
end

function Words.Levels(inst) return string.format("Lv %d-%d", inst.levels[1], inst.levels[2]) end

-- "Dungeon", "Raid · 40".
function Words.Kind(inst)
    if inst.kind == "raid" then return "Raid · " .. tostring(inst.size) end
    return "Dungeon"
end

-- The card's meta line: "Dungeon · Lv 15-23 · Westfall · 8 bosses". `drop` 1 leaves out the kind
-- (a raid's tag says it), 2 the bosses too, for a card too narrow for all of it (in game the
-- minimum window cut it to "Westfall · 8...", WoWScrnShot_111526_132942).
function Words.Meta(inst, where, drop)
    drop = drop or 0
    local parts = {}
    if drop < 1 then parts[#parts + 1] = Words.Kind(inst) end
    parts[#parts + 1] = Words.Levels(inst)
    if where and where ~= "" then parts[#parts + 1] = where end
    local n = #(inst.bosses or {})
    if drop < 2 then parts[#parts + 1] = n .. " " .. plural(n, "boss", "bosses") end
    return table.concat(parts, "  ·  ")
end

-- The tags: { { text, style = "new" | "lvl" | "plain" }, ... } (New in Forever, Your level,
-- Raid · 40 or n players).
function Words.Tags(e)
    local out = {}
    if e.inst.forever then out[#out + 1] = { text = "New in Forever", style = "new" } end
    if e.fit then out[#out + 1] = { text = "Your level", style = "lvl" } end
    if e.inst.kind == "raid" then out[#out + 1] = { text = "Raid · " .. tostring(e.inst.size), style = "plain" }
    elseif e.inst.size and e.inst.size ~= 5 then out[#out + 1] = { text = e.inst.size .. " players", style = "plain" } end
    return out
end

local NONE = { unmapped = "Quests not mapped", side = "None for your side", none = "No quests" }

-- The quest cell: text, kind ("none" | "unknown" | "count"), fraction (nil unless counted).
function Words.QuestText(p, known)
    if p.total == 0 then return NONE[p.none] or NONE.none, "none" end
    if not known then return string.format("? / %d %s", p.total, plural(p.total, "quest")), "unknown" end
    return string.format("%d / %d %s", p.done, p.total, plural(p.total, "quest")), "count", p.done / p.total
end

-- The info line for an instance.
function Words.Info(e, known, where, wide)
    local inst, p = e.inst, e.progress
    local kind = inst.kind == "raid" and ("Raid, " .. tostring(inst.size) .. " players") or "Dungeon"
    local n = #(inst.bosses or {})
    local s = string.format("%s%s, levels %d-%d (a guide). %d %s.", kind, (where and where ~= "") and (" in " .. where) or "",
        inst.levels[1], inst.levels[2], n, plural(n, "boss", "bosses"))
    if p.total > 0 then
        if known then s = s .. string.format(" %d of %d %s done.", p.done, p.total, plural(p.total, "quest"))
        else s = s .. string.format(" %d %s; the game hasn't said which are done.", p.total, plural(p.total, "quest")) end
    elseif p.none == "unmapped" then s = s .. " Its quests aren't mapped to it yet."
    elseif p.none == "side" then s = s .. " Its quests aren't for your side or class."
    else s = s .. " No quests here." end
    return s .. (wide and "" or " A opens it.")
end

-- A bracket group's header: title and count.
function Words.GroupTitle(g)
    if g.bracket.raid then return "Raids" end
    return "Levels " .. g.bracket.key
end

function Words.GroupCount(g, known)
    if g.withQuests > 0 and known then return string.format("every quest done in %d of %d", g.complete, g.withQuests) end
    return tostring(#g.entries)
end

-- The toolbar's count.
function Words.Count(shown, total) return string.format("%d of %d  ·  levels are a guide", shown, total) end

---------------------------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------------------------

-- The instance's painting, or the entrance zone's art until it has one.
local function paintArt(tex, inst, w, h)
    local T = ns.Theme
    local art = ns.Art and ns.Art.dungeons
    if art and art[inst.key] then
        tex:SetTexture(T.mediaDir .. "Dungeons\\" .. inst.key .. ".blp")
        tex:SetTexCoord(T.CoverCoords(w, h, 1024, 512))
        return
    end
    local mapID = inst.zones and inst.zones[1]
    local file = mapID and T.ZoneArt(mapID)
    if file then
        tex:SetTexture(file)
        local top, bottom = T.BannerCrop(mapID, w, h)
        tex:SetTexCoord(0, 1, top, bottom)
    else
        tex:SetColorTexture(0.1, 0.063, 0.031, 1)
    end
end

local function gradient(tex, dir, from, to)
    tex:SetColorTexture(1, 1, 1, 1)
    local ok = type(CreateColor) == "function" and pcall(tex.SetGradient, tex, dir,
        CreateColor(0, 0, 0, from), CreateColor(0, 0, 0, to))
    if not ok then tex:SetColorTexture(0, 0, 0, (from + to) / 2) end
end

-- A tag pill (style.css .tag): :Set(tag) sizes it to its text; returns the width.
local function newTag(parent)
    local T, W, D = ns.Theme, ns.Widgets, ns.Theme.layout.dunTab
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(D.tag)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.edge = W.Edge(f, "BORDER")
    f.text = T.Text(f, "xs", "text")
    f.text:SetPoint("CENTER", 0, 0)
    f.text:SetWordWrap(false)
    function f:Set(tag)
        local bg, edge, ink, alpha = "dunTagBg", "dunTagEdge", "text", 0.75
        if tag.style == "new" then bg, edge, ink, alpha = "dunTagNewBg", "dunTagNewEdge", "dunTagNew", 0.92
        elseif tag.style == "lvl" then bg, edge, ink, alpha = "fit", "fit", "white", 1 end
        local r, g, b = T.RGB(bg)
        self.bg:SetColorTexture(r, g, b, alpha)
        self.edge:SetColor(edge)
        self.text:SetText(tag.text)
        self.text:SetTextColor(T.RGB(ink))
        local w = math.ceil((self.text:GetStringWidth() or (#tag.text * 6)) + 2 * D.tagPad)
        self:SetWidth(w)
        return w
    end
    return f
end

-- Lays out tags left to right from `anchor`'s point; returns the width used. pool = holder.tags.
local function placeTags(holder, tags, x0, y0, point)
    local D = ns.Theme.layout.dunTab
    holder.tags = holder.tags or {}
    local x = x0
    for i, tag in ipairs(tags) do
        local t = holder.tags[i]
        if not t then t = newTag(holder); holder.tags[i] = t end
        t:ClearAllPoints()
        t:SetPoint(point or "TOPLEFT", holder, point or "TOPLEFT", x, y0)
        x = x + t:Set(tag) + D.tagGap
        t:Show()
    end
    for i = #tags + 1, #holder.tags do holder.tags[i]:Hide() end
    return #tags > 0 and (x - x0 - D.tagGap) or 0
end

-- The quest bar: a well, the painted gold fill (amber while in progress) and its words under it.
-- :Set(progress, known, width) -> height.
local function newQuestBar(parent)
    local T, D = ns.Theme, ns.Theme.layout.dunTab
    local f = CreateFrame("Frame", nil, parent)
    f.well = T.Solid(f, "well", "BORDER")
    f.well:SetPoint("TOPLEFT"); f.well:SetHeight(D.questBar)
    f.fill = f:CreateTexture(nil, "ARTWORK")
    f.fill:SetPoint("TOPLEFT", f.well, "TOPLEFT"); f.fill:SetHeight(D.questBar)
    f.text = T.Text(f, "xs", "text")
    f.text:SetJustifyH("LEFT"); f.text:SetWordWrap(false)
    function f:Set(p, known, width)
        local text, kind, frac = Words.QuestText(p, known)
        local bar = kind ~= "none"
        self.well:SetShown(bar)
        self.well:SetWidth(math.max(1, width))
        self.fill:SetShown(bar and (frac or 0) > 0)
        if frac and frac > 0 then
            self.fill:SetWidth(math.max(0.001, width * frac))
            local gold = T.Chrome("bar-fill")
            if gold then
                self.fill:SetTexture(gold); self.fill:SetTexCoord(0, math.max(0.001, frac), 0, 1)
                if frac >= 1 then self.fill:SetVertexColor(1, 1, 1) else self.fill:SetVertexColor(1, 0.72, 0.42) end
            else
                local r, g, b = T.RGB(frac >= 1 and "complete" or "todo")
                self.fill:SetColorTexture(r, g, b, 1)
            end
        end
        self.text:ClearAllPoints()
        if bar then self.text:SetPoint("TOPLEFT", self.well, "BOTTOMLEFT", 0, -3)
        else self.text:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0) end
        self.text:SetWidth(math.max(1, width))
        local complete = frac ~= nil and frac >= 1
        self.text:SetText((complete and "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t " or "") .. text)
        self.text:SetTextColor(T.RGB(kind == "none" and "dunFaint" or (complete and "complete" or "text")))
        local h = (bar and (D.questBar + 3) or 0) + T.size.xs + 2
        self:SetSize(math.max(1, width), h)
        return h
    end
    return f
end

-- A card: the painting edge to edge, the foot's shade, tags, ✓, name, meta and the quest bar,
-- in frame A. Focus: a yellow edge; the state's edge otherwise.
local STATE_EDGE = { complete = "complete", progress = "todo" }
local function newCard(parent)
    local T, D, W = ns.Theme, ns.Theme.layout.dunTab, ns.Widgets
    local c = CreateFrame("Button", nil, parent)
    c.bg = T.Solid(c, "cardBg", "BACKGROUND")
    c.bg:SetAllPoints()
    c.art = c:CreateTexture(nil, "BORDER")
    c.art:SetAllPoints()
    c.shade = c:CreateTexture(nil, "ARTWORK")
    c.shade:SetPoint("BOTTOMLEFT"); c.shade:SetPoint("BOTTOMRIGHT")
    gradient(c.shade, "VERTICAL", 0.95, 0)
    c.check = c:CreateTexture(nil, "OVERLAY")
    c.check:SetSize(D.check, D.check)
    c.check:SetPoint("TOPRIGHT", c, "TOPRIGHT", -D.pad + 4, -D.pad + 6)
    c.check:SetTexture(T.files.checkDone)
    if c.check.SetDesaturated then c.check:SetDesaturated(true) end
    c.check:SetVertexColor(T.RGB("complete"))
    c.tagHolder = CreateFrame("Frame", nil, c)
    c.tagHolder:SetAllPoints()
    c.quest = newQuestBar(c)
    c.quest:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", D.pad, D.pad - 3)
    c.meta = T.Text(c, "xs", "text")
    c.meta:SetJustifyH("LEFT"); c.meta:SetWordWrap(false)
    c.meta:SetPoint("BOTTOMLEFT", c.quest, "TOPLEFT", 0, 4)
    c.name = T.Text(c, "xl", "gold")
    c.name:SetJustifyH("LEFT"); c.name:SetJustifyV("BOTTOM")
    if c.name.SetMaxLines then c.name:SetMaxLines(2) end
    c.name:SetPoint("BOTTOMLEFT", c.meta, "TOPLEFT", 0, 4)
    c.frame = T.CardFrame(c, D.frameCorner, D.frameOut, "OVERLAY", "card-frame-a")
    -- The state and focus edge, over the frame's band.
    c.ring = CreateFrame("Frame", nil, c)
    c.ring:SetPoint("TOPLEFT", c, "TOPLEFT", -1, 1); c.ring:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 1, -1)
    if c.ring.SetFrameLevel and c.GetFrameLevel then c.ring:SetFrameLevel(c:GetFrameLevel() + 3) end
    c.edge = W.Edge(c.ring, "OVERLAY")
    function c:SetFocused(on) self.focused = on; self:Paint() end
    function c:Paint()
        local state = self.entry and self.entry.progress.state
        local col = self.focused and "focus" or (self.known and STATE_EDGE[state]) or (not self.frame and "cardEdge") or nil
        for i = 1, 4 do self.edge[i]:SetShown(col ~= nil) end
        if col then self.edge:SetColor(col); self.edge:SetThickness(self.focused and 2 or 1) end
    end
    W.HoverInfo(c)
    return c
end

local function fillCard(c, e, width, known)
    local D = ns.Theme.layout.dunTab
    local h = math.floor(width * D.cardAspect + 0.5)
    c:SetSize(width, h)
    paintArt(c.art, e.inst, width, h)
    c.shade:SetHeight(math.floor(h * D.shade + 0.5))
    placeTags(c.tagHolder, Words.Tags(e), D.pad - 2, -(D.pad - 4))
    c.check:SetShown(known and e.progress.state == "complete")
    local inner = width - 2 * D.pad
    c.quest:Set(e.progress, known, math.min(D.questBarMax, inner))
    c.meta:SetWidth(inner)
    local where = Words.Where(e.inst, zoneName)
    for drop = 0, 2 do
        c.meta:SetText(Words.Meta(e.inst, where, drop))
        if (c.meta:GetStringWidth() or 0) <= inner then break end
    end
    c.name:SetWidth(inner)
    c.name:SetText(e.inst.name)
    c.entry, c.known = e, known
    c:Paint()
    return h
end

-- A list row (style.css .drow): thumbnail, name and tags over where, levels with the bar,
-- bosses, the quest bar. `wide` (the split's list) drops the bosses column.
local function newRow(parent)
    local T, L, S, W, D = ns.Theme, ns.Theme.layout, ns.Theme.space, ns.Widgets, ns.Theme.layout.dunTab
    local r = W.FocusRow(parent, D.row)
    r.mark = T.Solid(r, "complete", "ARTWORK")
    r.mark:SetPoint("TOPLEFT"); r.mark:SetPoint("BOTTOMLEFT"); r.mark:SetWidth(3)
    r.thumb = r:CreateTexture(nil, "ARTWORK")
    r.thumb:SetPoint("LEFT", S.s2, 0)
    r.glyph = r:CreateTexture(nil, "OVERLAY")
    r.glyph:SetSize(D.glyph, D.glyph)
    r.glyph:SetPoint("BOTTOMRIGHT", r.thumb, "BOTTOMRIGHT", -1, 1)
    r.glyph:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.quest = newQuestBar(r)
    r.bosses = T.Text(r, "xs", "dim")
    r.bosses:SetJustifyH("LEFT"); r.bosses:SetWordWrap(false)
    r.lv = T.Text(r, "xs", "dim")
    r.lv:SetJustifyH("LEFT"); r.lv:SetWordWrap(false)
    r.lvbar = W.LevelBar(r)
    r.name = T.Text(r, "md", "white")
    r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
    r.where = T.Text(r, "xs", "dim")
    r.where:SetJustifyH("LEFT"); r.where:SetWordWrap(false)
    r.tagHolder = CreateFrame("Frame", nil, r)
    r.tagHolder:SetHeight(D.tag)
    return r
end

local function fillRow(r, e, width, known, wide)
    local T, S, D = ns.Theme, ns.Theme.space, ns.Theme.layout.dunTab
    local inst, p = e.inst, e.progress
    local tw, th = (wide and D.thumbWide or D.thumb)[1], (wide and D.thumbWide or D.thumb)[2]
    r.thumb:SetSize(tw, th)
    local mapID = inst.zones and inst.zones[1]
    local file = mapID and T.ZoneArt(mapID)
    if file then
        r.thumb:SetTexture(file)
        local top, bottom = T.BannerCrop(mapID, tw, th)
        r.thumb:SetTexCoord(0, 1, top, bottom)
    else
        r.thumb:SetColorTexture(0.1, 0.063, 0.031, 1)
    end
    -- Part sepia (style.css .drow .thumb: sepia(.45) brightness(.8)); fully desaturated, every
    -- thumbnail read as the same brown smudge in game (WoWScrnShot_111526_132939).
    if r.thumb.SetDesaturation then r.thumb:SetDesaturation(D.thumbSepia)
    elseif r.thumb.SetDesaturated then r.thumb:SetDesaturated(false) end
    r.thumb:SetVertexColor(0.88, 0.8, 0.68)
    r.glyph:SetTexture(D.kindIcon[inst.kind] or D.kindIcon.dungeon)
    local edge = known and STATE_EDGE[p.state]
    r.mark:SetShown(edge ~= nil and edge ~= false)
    if edge then local cr, cg, cb = T.RGB(edge); r.mark:SetColorTexture(cr, cg, cb, 1) end
    -- Right to left: quests, bosses, levels.
    local qw = wide and D.questColWide or D.questCol
    local qh = r.quest:Set(p, known, qw - S.s3)
    r.quest:ClearAllPoints()
    r.quest:SetPoint("TOPLEFT", r, "TOPRIGHT", -(qw + S.s2), -math.floor((D.row - qh) / 2))
    local x = qw + S.s2 + S.s3
    r.bosses:SetShown(not wide)
    if not wide then
        local n = #(inst.bosses or {})
        r.bosses:SetText(n .. " " .. plural(n, "boss", "bosses"))
        r.bosses:ClearAllPoints(); r.bosses:SetPoint("LEFT", r, "RIGHT", -(x + D.bossCol), 0)
        r.bosses:SetWidth(D.bossCol)
        x = x + D.bossCol + S.s3
    end
    r.lv:SetText(Words.Levels(inst))
    r.lv:ClearAllPoints(); r.lv:SetPoint("BOTTOMLEFT", r, "RIGHT", -(x + D.lvCol), 2)
    r.lv:SetWidth(D.lvCol)
    r.lvbar:ClearAllPoints(); r.lvbar:SetPoint("TOPLEFT", r, "RIGHT", -(x + D.lvCol), -3)
    r.lvbar:Set(inst.levels[1], inst.levels[2], (ns.character or {}).level, e.fit)
    x = x + D.lvCol + S.s3
    -- Name and tags on one line, where under them.
    local left = S.s2 + tw + S.s3
    local avail = math.max(60, width - left - x)
    local tags = Words.Tags(e)
    local tagsW = placeTags(r.tagHolder, tags, 0, 0, "LEFT")
    -- The name stays whole; tags that don't fit beside it go beside "where" under it (the split's
    -- list cut "Hall of Thanes" to "Hall o...", WoWScrnShot_111526_132948), or are left out.
    r.name:SetText(inst.name)
    local nameW = math.min(math.ceil(r.name:GetStringWidth() or 0) + 1, avail)
    r.name:SetWidth(nameW)
    r.name:ClearAllPoints(); r.name:SetPoint("BOTTOMLEFT", r, "LEFT", left, 1)
    r.where:SetText(Words.Where(inst, zoneName))
    r.where:ClearAllPoints(); r.where:SetPoint("TOPLEFT", r, "LEFT", left, -3)
    r.tagHolder:ClearAllPoints()
    r.tagHolder:SetWidth(math.max(1, tagsW))
    local beside = nameW + S.s2 + tagsW <= avail
    local whereW = math.min(math.ceil(r.where:GetStringWidth() or 0) + 1, avail)
    if tagsW > 0 and not beside and whereW + S.s2 + tagsW <= avail then
        r.where:SetWidth(whereW)
        r.tagHolder:SetPoint("LEFT", r.where, "RIGHT", S.s2, 0)
        r.tagHolder:Show()
    else
        r.where:SetWidth(avail)
        r.tagHolder:SetPoint("LEFT", r.name, "RIGHT", S.s2, 0)
        r.tagHolder:SetShown(tagsW > 0 and beside)
    end
    r.entry = e
end

---------------------------------------------------------------------------------------------
-- Page
---------------------------------------------------------------------------------------------

local function build(parent)
    local T, L, S, W = ns.Theme, ns.Theme.layout, ns.Theme.space, ns.Widgets
    local D = L.dunTab
    local page = CreateFrame("Frame", nil, parent)
    page.mode = "list"            -- "list" | "page" (the instance page full size; wide List: focus in it)
    page.cards, page.rows, page.headers = {}, {}, {}

    -- Toolbar -------------------------------------------------------------------------------------
    local tb = CreateFrame("Frame", nil, page)
    tb:SetHeight(L.toolbarHeight)
    T.Solid(tb, "black", "BACKGROUND", 0.28):SetAllPoints()
    local tbRule = T.Solid(tb, "divider", "BORDER")
    tbRule:SetPoint("BOTTOMLEFT"); tbRule:SetPoint("BOTTOMRIGHT"); tbRule:SetHeight(1)
    local controls = {}
    local function control(key, title, detail, onActivate, actionLabel)
        local b = W.PanelButton(tb) -- the game's red panel buttons (owner, 2026-11-14), sized to their text
        b.minWidth = 0
        b.item = { key = key, frame = b, title = title, detail = detail, onActivate = onActivate, actionLabel = actionLabel }
        b:SetScript("OnClick", function() onActivate(b.item) end)
        controls[#controls + 1] = b
        return b
    end
    page.filters = {}
    for _, fl in ipairs(FILTERS) do
        local value = fl[1]
        local b = control("tb:filter:" .. value, fl[2], FILTER_INFO[value], function() page:SetFilter(value) end, "Show")
        b.value = value
        page.filters[#page.filters + 1] = b
    end
    page.views = {}
    for _, v in ipairs(VIEWS) do
        local value = v[1]
        local b = control("tb:view:" .. value, v[2] .. " view", "Y cycles the views.", function() page:SetView(value) end, "Switch")
        b.value = value
        page.views[#page.views + 1] = b
    end
    page.count = T.Text(tb, "xs", "dim")
    page.toolbar = tb

    -- List ---------------------------------------------------------------------------------------
    local list = CreateFrame("Frame", nil, page)
    local scroll = W.Scroll(list)
    scroll:SetPoint("TOPLEFT", 0, -S.s2)
    scroll:SetPoint("BOTTOMRIGHT", 0, S.s2)
    list.edge = T.Solid(list, "divider", "BORDER")
    list.edge:SetPoint("TOPRIGHT"); list.edge:SetPoint("BOTTOMRIGHT"); list.edge:SetWidth(1)
    page.list, page.scroll = list, scroll
    page.emptyTitle = T.Text(scroll.child, "lg", "gold")
    page.emptyTitle:SetPoint("TOP", 0, -60)
    page.emptyText = T.Text(scroll.child, "md", "dim")
    page.emptyText:SetPoint("TOP", page.emptyTitle, "BOTTOM", 0, -S.s2)
    page.emptyText:SetWidth(560); page.emptyText:SetWordWrap(true)
    -- The sticky header: the bracket you're scrolled into stays on top.
    local sticky = W.Header(list)
    sticky:SetPoint("TOPLEFT", scroll, "TOPLEFT", L.listInset, 0)
    sticky:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", -S.s6, 0)
    sticky:SetFrameLevel(scroll:GetFrameLevel() + 10)
    sticky:Hide()
    page.sticky = sticky
    local function updateSticky()
        local off = scroll:GetVerticalScroll() or 0
        local pick
        if off > 0 then
            for _, h in ipairs(page.headerYs or {}) do if h.y < off + L.listHeader then pick = h end end
        end
        sticky:SetShown(pick ~= nil and page.list:IsShown())
        if pick then sticky.text:SetText(pick.text); sticky.count:SetText(pick.count) end
    end
    scroll:HookScript("OnVerticalScroll", updateSticky)
    page.UpdateSticky = updateSticky
    scroll.onWidth = function(w)
        if page.drawnWidth and math.abs(page.drawnWidth - (w or 0)) >= 1 and page.all then page:Redraw() end
    end

    -- The instance page (task 5 fills it; for now its banner and a note) -----------------------------
    local d = CreateFrame("Frame", nil, page)
    local banner = CreateFrame("Frame", nil, d)
    banner:SetPoint("TOPLEFT"); banner:SetPoint("TOPRIGHT"); banner:SetHeight(D.banner)
    banner.art = banner:CreateTexture(nil, "BACKGROUND")
    banner.art:SetAllPoints()
    local shade = banner:CreateTexture(nil, "BORDER")
    shade:SetAllPoints()
    gradient(shade, "HORIZONTAL", 0.85, 0.2)
    local foot = banner:CreateTexture(nil, "BORDER", nil, 1)
    foot:SetPoint("BOTTOMLEFT"); foot:SetPoint("BOTTOMRIGHT"); foot:SetHeight(math.floor(D.banner * 0.6))
    gradient(foot, "VERTICAL", 0.7, 0)
    local brule = T.Solid(banner, "divider", "ARTWORK")
    brule:SetPoint("BOTTOMLEFT"); brule:SetPoint("BOTTOMRIGHT"); brule:SetHeight(2)
    banner.meta = T.Text(banner, "sm", "text")
    banner.meta:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", S.s6, S.s4)
    banner.meta:SetJustifyH("LEFT"); banner.meta:SetWordWrap(false)
    banner.blurb = T.Text(banner, "sm", "dim")
    banner.blurb:SetPoint("BOTTOMLEFT", banner.meta, "TOPLEFT", 0, S.s1)
    banner.blurb:SetJustifyH("LEFT"); banner.blurb:SetWordWrap(false)
    banner.name = T.Text(banner, "xxl", "gold")
    banner.name:SetPoint("BOTTOMLEFT", banner.blurb, "TOPLEFT", 0, S.s1)
    banner.name:SetJustifyH("LEFT"); banner.name:SetWordWrap(false)
    banner.tagHolder = CreateFrame("Frame", nil, banner)
    banner.tagHolder:SetAllPoints()
    banner.score = T.Text(banner, "lg", "white")
    banner.score:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", -S.s6, S.s4)
    banner.score:SetJustifyH("RIGHT")
    local back = CreateFrame("Button", nil, banner, "UIPanelButtonTemplate")
    back:SetSize(150, 24)
    back:SetPoint("TOPRIGHT", -S.s4, -S.s3)
    back:SetText("Dungeons")
    back:SetScript("OnClick", function() page:Back() end)
    banner:SetScript("OnSizeChanged", function(self)
        if self.inst then paintArt(self.art, self.inst, self:GetWidth(), self:GetHeight()) end
    end)
    d.note = T.Text(d, "md", "dim")
    d.note:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", S.s6, -S.s6)
    d.note:SetPoint("RIGHT", d, "RIGHT", -S.s6, 0)
    d.note:SetJustifyH("LEFT"); d.note:SetWordWrap(true)
    d.note:SetText("The rest of this page (the run, bosses and loot, and where to pick up each quest) is the next step of the build.")
    d:Hide()
    d.banner, d.back = banner, back
    page.detail = d

    ---------------------------------------------------------------------------------------------

    local function width(frame, fallback)
        local w = frame:GetWidth() or 0
        if w <= 1 then
            local f = ns.UI.GetFrame()
            w = fallback or ((f and f:GetWidth() or 1160) - 2 * L.edgeInset)
        end
        return w
    end

    function page:View() return Words.View(settings().view) end
    -- Only List splits, and only in the wide window (round 2).
    function page:Split() return self.wide and self:View() == "list" end

    local function arrange()
        tb:ClearAllPoints(); list:ClearAllPoints(); d:ClearAllPoints()
        tb:SetPoint("TOPLEFT"); tb:SetPoint("TOPRIGHT")
        if page:Split() then
            list:SetPoint("TOPLEFT", tb, "BOTTOMLEFT"); list:SetPoint("BOTTOMLEFT")
            list:SetWidth(D.splitList)
            d:SetPoint("TOPLEFT", list, "TOPRIGHT"); d:SetPoint("BOTTOMRIGHT")
        else
            list:SetPoint("TOPLEFT", tb, "BOTTOMLEFT"); list:SetPoint("BOTTOMRIGHT")
            d:SetAllPoints()
        end
        list.edge:SetShown(page:Split())
        back:SetShown(not page:Split())
    end

    local function layoutToolbar()
        local s = settings()
        local x = L.listInset
        for _, b in ipairs(page.filters) do
            b:SetLabel(b.item.title)
            b:SetOn(s.filter == b.value)
            b:ClearAllPoints(); b:SetPoint("LEFT", tb, "LEFT", x, 0)
            x = x + b:GetWidth() + S.s2
        end
        local right = S.s4
        for i = #page.views, 1, -1 do
            local b = page.views[i]
            b:SetLabel(VIEWS[i][2])
            b:SetOn(page:View() == b.value)
            b:ClearAllPoints(); b:SetPoint("RIGHT", tb, "RIGHT", -right, 0)
            right = right + b:GetWidth() + (i == 1 and S.s3 or S.s2)
        end
        page.count:ClearAllPoints()
        page.count:SetPoint("RIGHT", tb, "RIGHT", -right, 0)
        -- No room between the filters and the views: the count goes (the info line keeps the filter's words).
        local room = width(tb) - right - x
        page.count:SetShown(room >= (page.count:GetStringWidth() or 0) + S.s3)
    end
    tb:SetScript("OnSizeChanged", function() layoutToolbar() end)

    local function take(pool, make, parentFrame)
        page.used[pool] = (page.used[pool] or 0) + 1
        local f = page[pool][page.used[pool]]
        if not f then f = make(parentFrame); page[pool][page.used[pool]] = f end
        f:ClearAllPoints()
        f:Show()
        return f
    end

    local function toolbarRow()
        local items = {}
        for _, b in ipairs(controls) do items[#items + 1] = b.item end
        return { items = items, section = 0 }
    end

    local function entryFor(key)
        for _, e in ipairs(page.all or {}) do if e.inst.key == key then return e end end
    end

    -- Fills the instance page's banner for entry e (nil: nothing to show).
    local function fillPage(e)
        page.pageWidth = d:GetWidth() or 0
        if not e then banner.inst = nil; d.note:Hide(); return end
        local inst = e.inst
        banner.inst = inst
        paintArt(banner.art, inst, width(banner, page:Split() and (width(page) - D.splitList) or nil), D.banner)
        banner.name:SetText(inst.name)
        banner.blurb:SetText(inst.blurb or "")
        local where = Words.Where(inst, zoneName)
        local kind = inst.kind == "raid" and "Raid" or "Dungeon"
        local parts = { kind, inst.size .. " players" }
        if where ~= "" then parts[#parts + 1] = where end
        parts[#parts + 1] = Words.Levels(inst)
        banner.meta:SetText(table.concat(parts, "  ·  "))
        placeTags(banner.tagHolder, Words.Tags(e), S.s6, -S.s4)
        local text, kind2 = Words.QuestText(e.progress, page.known)
        banner.score:SetText(kind2 == "none" and text or (text .. " done"))
        banner.score:SetTextColor(T.RGB(kind2 == "none" and "dunFaint" or
            (page.known and e.progress.state == "complete" and "complete" or "white")))
        d.note:Show()
    end
    page.FillPage = fillPage

    -- The empty states: building, unavailable (with the reason), nothing for this filter.
    local function emptyState(st, shown)
        if st.status == "unavailable" then
            return "Dungeons need QuestieDB", "Azerfolio reads each instance's quests and loot from QuestieDB" ..
                (st.reason and (" (" .. st.reason .. ")") or "") .. "."
        end
        if not shown then
            return "Reading dungeons", "Azerfolio reads QuestieDB's dungeon quests and loot once, a few seconds after login."
        end
        if #shown == 0 then return "Nothing here", "Try another filter." end
    end

    -- Redraws everything from ns.Dungeons.Catalogue. Keeps focus on the same key.
    function page:Redraw()
        local s = settings()
        local st = ns.Dungeons.State()
        local all, shown
        if st.status == "ready" then all, shown = ns.Dungeons.Catalogue(s.filter) end
        self.all, self.known = all, ns.Dungeons.CompletionKnown()
        local known = self.known
        self.used = { cards = 0, rows = 0, headers = 0 }
        for _, c in ipairs(self.cards) do c:Hide() end
        for _, r in ipairs(self.rows) do r:Hide() end
        for _, h in ipairs(self.headers) do h:Hide() end
        arrange()
        self.count:SetText(all and Words.Count(#shown, #all) or "")
        layoutToolbar()
        local view = self:View()
        local split = self:Split()
        local child = scroll.child
        local wList = width(scroll, split and D.splitList or nil)
        self.drawnWidth = scroll:GetWidth() or 0
        local inner = wList - L.listInset - S.s6
        local rows, byKey, headerYs = { toolbarRow() }, {}, {}
        local title, text = emptyState(st, shown)
        self.emptyTitle:SetShown(title ~= nil); self.emptyText:SetShown(title ~= nil)
        if title then self.emptyTitle:SetText(title); self.emptyText:SetText(text) end
        local groups = shown and #shown > 0 and ns.DungeonRules.Groups(shown) or {}
        local cols = D.cols
        local cardW = math.floor((inner - (cols - 1) * D.cardGap) / cols)
        local gap = cols > 1 and (inner - cols * cardW) / (cols - 1) or D.cardGap
        local out = view == "cards" and D.frameOut or 0
        local y = 0
        for gi, g in ipairs(groups) do
            if gi > 1 then y = y + S.s3 end
            local h = take("headers", W.Header, child)
            h:SetPoint("TOPLEFT", child, "TOPLEFT", L.listInset - out, -y)
            h:SetPoint("TOPRIGHT", child, "TOPRIGHT", -S.s6 + out, -y)
            local gt, gc = Words.GroupTitle(g), Words.GroupCount(g, known)
            h.text:SetText(gt); h.count:SetText(gc)
            headerYs[#headerYs + 1] = { y = y, text = gt, count = gc }
            y = y + L.listHeader + S.s2 + out
            local function item(frame, e)
                local key = e.inst.key
                local where = Words.Where(e.inst, zoneName)
                frame.item = { key = "d:" .. key, frame = frame, title = e.inst.name,
                    detail = Words.Info(e, known, where, split), scroll = scroll,
                    topGap = L.listHeader + S.s1 + S.s2 + out, entry = e,
                    actionLabel = split and "Details" or "Open",
                    onActivate = function() page:OpenInstance(key) end,
                    canActivate = function() return not page:Split() or (page.pageRows ~= nil and #page.pageRows > 0) end }
                frame:SetScript("OnClick", function() page:ClickInstance(key) end)
                byKey[key] = frame
                return frame.item
            end
            if view == "cards" then
                for i = 1, #g.entries, cols do
                    local its, rowH = {}, 0
                    for col = 0, cols - 1 do
                        local e = g.entries[i + col]
                        if e then
                            local c = take("cards", newCard, child)
                            rowH = fillCard(c, e, cardW, known)
                            c:SetPoint("TOPLEFT", child, "TOPLEFT", math.floor(L.listInset + col * (cardW + gap) + 0.5), -y)
                            its[#its + 1] = item(c, e)
                        end
                    end
                    rows[#rows + 1] = { items = its, section = gi }
                    y = y + rowH + D.cardGap
                end
                y = y - D.cardGap + out + S.s2
            else
                for _, e in ipairs(g.entries) do
                    local r = take("rows", newRow, child)
                    r:SetPoint("TOPLEFT", child, "TOPLEFT", L.listInset, -y)
                    r:SetWidth(inner)
                    fillRow(r, e, inner, known, split)
                    rows[#rows + 1] = { items = { item(r, e) }, section = gi }
                    y = y + D.row + 2
                end
            end
        end
        child:SetHeight(math.max(1, y))
        self.focusRows, self.byKey, self.headerYs = rows, byKey, headerYs
        self.sectionCount = #groups
        -- The page: the one open (a filter may hide it in the list, but its page stays), or in
        -- the split the selected one, else the first shown.
        if self.selKey and not entryFor(self.selKey) then self.selKey = nil end
        if split and self.mode == "list" then
            local first = groups[1] and groups[1].entries[1]
            self.selKey = (self.selKey and byKey[self.selKey] and self.selKey) or (first and first.inst.key) or nil
        end
        if self.mode == "page" and not self.selKey then self.mode = "list" end
        fillPage(self.selKey and entryFor(self.selKey) or nil)
        self.pageRows = {} -- the instance page's focus stops (task 5)
        for key, f in pairs(byKey) do if f.SetSelected then f:SetSelected(split and key == self.selKey) end end
        self:Refresh()
        updateSticky()
    end

    -- Shows the right frames for the mode, then rebuilds focus and hints.
    function page:Refresh()
        local inPage, split = self.mode == "page", self:Split()
        tb:SetShown(split or not inPage)
        list:SetShown(split or not inPage)
        d:SetShown(inPage or (split and self.selKey ~= nil))
        if inPage and not split then sticky:Hide() end
        self.hasSections = not inPage and (self.sectionCount or 0) > 1
        self.sectionLabel = "Section"
        self.backLabel = inPage and "Dungeons" or nil
        ns.Focus.Rebuild()
        ns.UI.RefreshHints()
    end

    -- A on an instance: its page (full size), or into it (the wide List; nothing to move into yet).
    function page:OpenInstance(key)
        self.selKey = key
        local e = entryFor(key)
        if not e then return end
        if self:Split() and #(self.pageRows or {}) == 0 then
            self.mode = "list"; self.pendingFocusKey = "d:" .. key
        else
            self.mode = "page"
            self.pendingFocusKey = self.pageRows and self.pageRows[1] and self.pageRows[1].items[1].key or nil
        end
        fillPage(e)
        for k, f in pairs(self.byKey or {}) do if f.SetSelected then f:SetSelected(self:Split() and k == key) end end
        self:Refresh()
    end

    -- A click: in the split it selects the instance and keeps focus in the list.
    function page:ClickInstance(key)
        if not self:Split() then return self:OpenInstance(key) end
        self.mode = "list"
        self.selKey = key
        self.pendingFocusKey = "d:" .. key
        self:Redraw()
    end

    -- Split: the page follows the focused instance.
    function page:OnFocusChanged(item)
        if self:Split() and self.mode == "list" and item and item.entry and item.entry.inst.key ~= self.selKey then
            self.selKey = item.entry.inst.key
            fillPage(item.entry)
            for k, f in pairs(self.byKey or {}) do if f.SetSelected then f:SetSelected(k == self.selKey) end end
        end
    end

    function page:SetFilter(value)
        settings().filter = value
        self.pendingFocusKey = "tb:filter:" .. value
        self:Redraw()
    end

    -- A view, keeping focus on the focused instance (or the toolbar button that chose it).
    function page:SetView(value, keepFocus)
        settings().view = value
        local cur = ns.Focus.Current()
        self.pendingFocusKey = (keepFocus and cur and cur.key) or ("tb:view:" .. Words.View(value))
        self:Redraw()
    end

    -- Y: Cards -> List -> Cards (the Road joins in task 6).
    function page:CycleView()
        if self.mode ~= "list" then return false end
        self:SetView(Words.NextView(settings().view), true)
        return true
    end

    function page:OnButton(name)
        if name == "y" then return self:CycleView() end
        return false
    end

    function page:GetHints()
        if self.mode == "list" then return { { "Y", "View" } } end
        return {}
    end

    function page:GetFocusRows()
        if self.mode == "page" then return self.pageRows or {} end
        return self.focusRows or {}
    end

    -- B: from the page back to the catalogue, on the same instance.
    function page:Back()
        if self.mode ~= "page" then return false end
        self.mode = "list"
        self.pendingFocusKey = self.selKey and ("d:" .. self.selKey)
        self:Refresh()
        return true
    end

    function page:Layout()
        local wide = ns.UI.IsWide()
        if wide == self.wide then return end
        self.wide = wide
        if self:IsShown() then self:Redraw() else self.dirty = true end
    end

    -- The catalogue changed (the build, quests done, a level-up): redraw, keeping focus. Item
    -- details and bag counts only matter to the instance page's loot (task 5).
    local function changed()
        if not page:IsShown() then page.dirty = true; return end
        local cur = ns.UI.CurrentTab() == "dungeons" and ns.Focus.Current()
        if cur and page.pendingFocusKey == nil then page.pendingFocusKey = cur.key end
        page:Redraw()
    end
    ns.Events.On("AZF_DUNGEONS_UPDATED", function(reason)
        if reason == "items" or reason == "bags" then return end
        changed()
    end)
    ns.Events.On("AZF_LEVEL_CHANGED", changed) -- "Your level", the level bars, quest states
    page:SetScript("OnShow", function(self)
        if self.dirty then self.dirty = false; self:Redraw() end
    end)

    page.wide = ns.UI.IsWide()
    page:Redraw()
    local first = page.focusRows and page.focusRows[2] and page.focusRows[2].items[1]
    if first then page.pendingFocusKey = first.key end
    return page
end

ns.DungeonsPage = { Words = Words }

ns.UI.RegisterTab({
    id = "dungeons",
    label = "Dungeons",
    icon = ns.Theme.Icon("dungeons", "Interface\\Icons\\INV_Misc_Key_03"),
    order = 6,
    compactHeader = true,
    info = "Every dungeon and raid: its quests, bosses and levels.",
    build = build,
})
