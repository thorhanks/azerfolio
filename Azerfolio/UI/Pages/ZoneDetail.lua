-- Zone Detail (spec §7, mockups/DESIGN.md "Zone Detail is a dashboard"): the zone's banner
-- header, then either the dashboard (the war banner and one tile per category) or one
-- category's page: Exploration (To discover / Discovered), Quests (Ready now, storylines,
-- finished storylines, the coverage note) or Flight paths. Under Next up, the Reputation
-- ledger (Phase 11; not part of the zone's progress); A on a faction opens its page (the
-- zone's quests that raise it). Used by UI/Pages/Zones.lua, which owns the modes and B.
-- Everything shown comes from ns.Zones / ns.Exploration / ns.Quests / ns.FlightPaths /
-- ns.Reputation; this file only draws it. Frames are pooled and reused.
local _, ns = ...

local Detail = {}
ns.ZoneDetail = Detail

Detail.PAGES = { "explore", "quests", "flights" }
local NODE_W, NODE_H, NODE_DOT = 88, 58, 22
local NODE_W_MAX = 132 -- a storyline node's widest (Phase 15 step 2)
local CHIP_H, CHIP_COLS = 30, 3
local TILE_SQ = 168      -- round 3: square tiles side by side
local NEXT_PLATE = 40    -- the "Next up" header plate's height
local NEXT_ITEM_H = 40
local NEXT_COLS = 3
local ALSO_MAX = 3       -- Phase 15 step 11: "Also for your level" cards
local ALSO_H = 72
local DASH_OVER = 8      -- the right column's scroll frame reaches this far past it (plate ends, card frames)
local STANDARD_W = 236   -- design round 2: narrower, the standard fills it
local DASH_HEADER = 196  -- design round 2: the dashboard's taller header (pages keep bannerHeight)
-- The Exploration page's zone map (Phase 15 step 6): the base map darkened by FOG (the mockup's
-- fog, #1c140c at 78%, over the parchment), the game's explored pieces in full over it.
local FOG = { 0.40, 0.34, 0.27 }
local MAP_LIST_SHARE, MAP_LIST_MIN = 0.4, 300 -- the area list's share of the page, beside the map
local MAP_CAPTION = 18

local DIFF_COLOR = { red = { 1, 0.13, 0.13 }, orange = { 1, 0.5, 0.25 }, yellow = { 1, 1, 0 },
    green = { 0.25, 0.75, 0.25 }, grey = { 0.62, 0.62, 0.62 } }
local DIFF_TEXT = { red = "far above your level", orange = "above your level", yellow = "about your level",
    green = "easy for you", grey = "far below your level" }
local KIND_LABEL = { ready = "Ready now", locked = "Locked", unknown = "Not counted", done = "Done",
    unavailable = "Not for this character", open = "Completion not known" }

local function cap(s) s = tostring(s or ""); return (s:gsub("^%l", string.upper)) end

-- The focus key of a Next up pick on its category's page (an area's check, a Ready now
-- quest, a flight path): Next up and the Overview's suggestions open the page on it.
local FOCUS_KEY = { explore = function(id) return "c" .. tostring(id) end, quests = function(id) return "r:" .. tostring(id) end,
    flights = function(id) return "f" .. tostring(id) end }
function Detail.FocusKey(kind, id) return FOCUS_KEY[kind] and FOCUS_KEY[kind](id) end

-- The difficulty colour of a quest ({ r, g, b }), or nil.
function Detail.DifficultyColor(d) return DIFF_COLOR[d] end

-- "Level 10 (from 7) · Locked: needs Find the Lost Guards"
function Detail.QuestLine(q)
    local lv = q.questLevel and ("Level " .. q.questLevel) or "Level ?"
    if q.reqLevel and q.questLevel and q.reqLevel ~= q.questLevel then lv = lv .. " (from " .. q.reqLevel .. ")" end
    local state = KIND_LABEL[q.kind] or "?"
    if q.kind == "ready" and q.difficulty then
        state = state .. ", " .. DIFF_TEXT[q.difficulty]
    elseif q.kind ~= "ready" and q.kind ~= "done" and q.reason then
        local why = cap(q.reason)
        if q.reason == "prerequisite" and q.prereqs then
            why = (q.prereqAny and #q.prereqs > 1 and "Needs one of " or "Needs ") .. table.concat(q.prereqs, ", ")
        end
        state = state .. ": " .. why
    end
    return lv .. "  ·  " .. state
end

---------------------------------------------------------------------------------------------
-- Building blocks
---------------------------------------------------------------------------------------------

local function cropBanner(banner)
    local w, h = banner:GetWidth(), banner:GetHeight()
    if not (w and h and w > 0) then return end
    local top, bottom = ns.Theme.BannerCrop(banner.mapID, w, h)
    banner.art:SetTexCoord(0, 1, top, bottom)
end

local function circle(parent, layer, size, sub)
    local t = parent:CreateTexture(nil, layer, nil, sub)
    t:SetSize(size, size)
    local m = parent:CreateMaskTexture()
    if m then
        m:SetAllPoints(t)
        m:SetTexture(ns.Theme.circleMask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        pcall(t.AddMaskTexture, t, m)
    end
    return t
end

-- An area or flight path row: check or ring, name.
local function checkRow(parent)
    local T, L, S = ns.Theme, ns.Theme.layout, ns.Theme.space
    local row = ns.Widgets.FocusRow(parent, L.checkRow)
    row.done = row:CreateTexture(nil, "ARTWORK")
    row.done:SetSize(L.checkIcon, L.checkIcon)
    row.done:SetPoint("LEFT", S.s2, 0)
    row.done:SetTexture(T.files.checkDone)
    if row.done.SetDesaturated then row.done:SetDesaturated(true) end
    row.done:SetVertexColor(T.RGB("complete"))
    row.todo = circle(row, "ARTWORK", L.checkIcon - 8)
    row.todo:SetPoint("CENTER", row.done, "CENTER")
    row.todo:SetColorTexture(T.RGB("todo"))
    row.name = T.Text(row, "sm", "white")
    row.name:SetPoint("LEFT", row.done, "RIGHT", S.s2, 0)
    row.name:SetPoint("RIGHT", row, "RIGHT", -S.s2, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    return row
end

-- A Ready now chip: the quest level in its difficulty colour, then the name.
local function newChip(parent)
    local T, S = ns.Theme, ns.Theme.space
    local b = ns.Widgets.FocusRow(parent, CHIP_H)
    b.bg = T.Solid(b, "ctlBg", "BACKGROUND")
    b.bg:SetAllPoints()
    b.edge = ns.Widgets.Edge(b, "BORDER")
    b.edge:SetColor("ctlEdge")
    b.lvbg = T.Solid(b, "black", "ARTWORK")
    b.lvbg:SetSize(26, 20)
    b.lvbg:SetPoint("LEFT", S.s1 + 2, 0)
    b.lv = T.Text(b, "xs", "white")
    b.lv:SetPoint("CENTER", b.lvbg, "CENTER", 0, 0)
    b.name = T.Text(b, "sm", "white")
    b.name:SetPoint("LEFT", b.lvbg, "RIGHT", S.s2, 0)
    b.name:SetPoint("RIGHT", b, "RIGHT", -S.s2, 0)
    b.name:SetJustifyH("LEFT"); b.name:SetWordWrap(false)
    return b
end

-- A storyline node: a dot (state) with the name under it.
local function newNode(parent)
    local T = ns.Theme
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(NODE_W, NODE_H)
    T.RowHighlight(b, "HIGHLIGHT")
    local hi = T.RowHighlight(b)
    hi:SetShown(false)
    function b:SetFocused(on) hi:SetShown(on) end
    ns.Widgets.HoverInfo(b)
    b.ring = circle(b, "ARTWORK", NODE_DOT)
    b.ring:SetPoint("TOP", 0, -3)
    b.dot = circle(b, "ARTWORK", NODE_DOT - 6, 1)
    b.dot:SetPoint("CENTER", b.ring, "CENTER")
    b.mark = b:CreateTexture(nil, "OVERLAY")
    b.mark:SetSize(14, 14); b.mark:SetPoint("CENTER", b.ring, "CENTER")
    b.glyph = T.Text(b, "xs", "white")
    b.glyph:SetPoint("CENTER", b.ring, "CENTER", 0, 0)
    b.name = T.Text(b, "xs", "text")
    b.name:SetPoint("TOP", b.ring, "BOTTOM", 0, -2)
    b.name:SetWidth(NODE_W - 4)
    b.name:SetJustifyH("CENTER")
    if b.name.SetMaxLines then b.name:SetMaxLines(2) end
    return b
end

local function paintNode(b, q)
    local T = ns.Theme
    local k = q.kind
    local ring, dot, alpha = { 0.56, 0.51, 0.44 }, { 0.10, 0.07, 0.04 }, 1
    b.mark:Hide(); b.glyph:SetText("")
    if k == "done" then
        ring, dot = T.color.complete, T.color.complete
        b.mark:SetTexture(T.files.checkDone)
        if b.mark.SetDesaturated then b.mark:SetDesaturated(true) end
        b.mark:SetVertexColor(0.23, 0.14, 0.02); b.mark:Show()
    elseif k == "ready" then
        ring, dot = DIFF_COLOR[q.difficulty] or T.color.todo, T.color.todo
    elseif k == "unknown" or k == "open" then
        b.glyph:SetText("?")
    elseif k == "unavailable" then
        alpha = 0.5
    end
    b.ring:SetColorTexture(ring[1], ring[2], ring[3], 1)
    b.dot:SetColorTexture(dot[1], dot[2], dot[3], 1)
    b.name:SetText(q.name or ("Quest " .. tostring(q.id)))
    b.name:SetTextColor(T.RGB((k == "ready" and "white") or (k == "done" and "dim") or "text"))
    b:SetAlpha(alpha)
end

---------------------------------------------------------------------------------------------
-- Reputation (Phase 11, mockups/DESIGN.md "Zone reputation"): not part of the zone's progress
---------------------------------------------------------------------------------------------

-- The faction page's key ("rep:<factionID>"), and the faction ID back from a page key.
function Detail.RepKey(factionID) return "rep:" .. tostring(factionID) end
function Detail.RepFaction(pageKey)
    local id = type(pageKey) == "string" and pageKey:match("^rep:(%-?%d+)$")
    return id and tonumber(id) or nil
end

local function nextLabel(f)
    return f.reaction and f.reaction < 8 and ns.Theme.ReactionLabel(f.reaction + 1) or nil
end

-- "Not met yet   ⚔ At war   ⇄ Rival of Bloodsail Buccaneers", in their colours.
local function repTags(f)
    local T = ns.Theme
    local function col(name, s)
        local r, g, b = T.RGB(name)
        return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, s)
    end
    local out = {}
    if f.met == false then out[#out + 1] = col("dim", T.repTags.unmet) end
    if f.atWar then out[#out + 1] = col("repWar", T.repTags.war) end
    for _, r in ipairs(f.rivals or {}) do out[#out + 1] = col("repRival", string.format(T.repTags.rival, r.name or "?")) end
    return table.concat(out, "   ")
end

-- One faction line: name and tags, the reaction in its colour, the notched bar, n / m. `plain`:
-- not a focus stop (the faction page's summary).
local function newRepRow(parent, plain)
    local T, W = ns.Theme, ns.Widgets
    local R = T.layout.rep
    local row = plain and CreateFrame("Frame", nil, parent) or W.FocusRow(parent, R.row)
    row:SetHeight(R.row)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(1, 1, 1, 1)
    local top, bottom = T.color.repRowTop, T.color.repRowBottom
    local ok = type(CreateColor) == "function" and pcall(row.bg.SetGradient, row.bg, "VERTICAL",
        CreateColor(bottom[1], bottom[2], bottom[3], 0.9), CreateColor(top[1], top[2], top[3], 0.85))
    if not ok then row.bg:SetColorTexture(top[1], top[2], top[3], 0.88) end
    row.edge = W.Edge(row, "BORDER")
    row.edge:SetColor("repRowEdge")
    row.crest = W.Crest(row) -- Phase 15 step 8: the faction's crest before its name
    row.name = T.Text(row, "sm", "white")
    row.name:SetJustifyH("LEFT"); row.name:SetWordWrap(false)
    row.tags = T.Text(row, "xs", "text")
    row.tags:SetJustifyH("LEFT")
    row.num = T.Text(row, "xs", "text")
    row.num:SetJustifyH("RIGHT"); row.num:SetWordWrap(false)
    row.react = T.Text(row, "sm", "white")
    row.react:SetJustifyH("LEFT"); row.react:SetWordWrap(false)
    row.bar = W.RepBar(row)
    if not plain then
        row:SetScript("OnClick", function(self) if self.item and self.item.onActivate then self.item.onActivate(self.item) end end)
    end
    return row
end

-- Fills a faction line for `width` with column widths `cols` ({ react, ladder, num, colGap,
-- row }); `summary` adds what's left to the next reaction. Returns the line's height (taller
-- when the tags wrap under the name).
local function paintRepRow(row, f, width, cols, summary)
    local T = ns.Theme
    local R = T.layout.rep
    local pad, gap = R.pad, cols.colGap
    T.SetFont(row.name, summary and "md" or "sm")
    row.name:SetText(f.name or ("Faction " .. tostring(f.factionID)))
    row.name:SetTextColor(T.RGB(f.met == false and "text" or "white"))
    row.tags:SetText(repTags(f))
    local c = T.reaction.text[f.reaction] or T.color.text
    row.react:SetText(T.ReactionLabel(f.reaction))
    row.react:SetTextColor(c[1], c[2], c[3])
    local num = ""
    if not f.maxed and f.into and f.span then
        num = ns.Widgets.Number(f.into) .. " / " .. ns.Widgets.Number(f.span)
        local nxt = nextLabel(f)
        if summary and nxt then num = num .. "  ·  " .. ns.Widgets.Number(f.span - f.into) .. " to " .. nxt end
    end
    row.num:SetText(num)
    -- The numbers never cut: the client's font is wider than the mockup's ("35,500 / 3..." in
    -- the wide split, WoWScrnShot_110826_222708), so the column grows to the text.
    local numW = math.max(cols.num, math.ceil(row.num:GetStringWidth() or 0) + 2)
    row.num:ClearAllPoints(); row.num:SetPoint("RIGHT", row, "RIGHT", -pad, 0); row.num:SetWidth(numW)
    row.bar:ClearAllPoints(); row.bar:SetPoint("RIGHT", row, "RIGHT", -(pad + numW + gap), 0)
    row.bar:Set(f, cols.ladder, summary and R.bar.heightSum or R.bar.height)
    row.react:ClearAllPoints(); row.react:SetPoint("LEFT", row, "RIGHT", -(pad + numW + cols.ladder + cols.react + 2 * gap), 0)
    row.react:SetWidth(cols.react)
    -- The crest, then name and tags share what's left; the tags wrap under the name when both don't fit.
    local crest = R.crest
    row.crest:SetPoint("LEFT", row, "LEFT", pad - 4, 0)
    row.crest:Set(f, crest)
    row.crest:SetShown(true)
    local x0 = pad - 4 + crest + gap
    local avail = math.max(40, width - x0 - pad - cols.react - cols.ladder - numW - 3 * gap)
    local nameW = math.min(avail, math.ceil(row.name:GetStringWidth() or 0) + 1)
    row.name:SetWidth(nameW)
    local tags = row.tags:GetText() or ""
    local tagW = tags ~= "" and math.ceil(row.tags:GetStringWidth() or 0) + 1 or 0
    local oneLine = tags == "" or nameW + gap + tagW <= avail
    local h = oneLine and (cols.row or R.row) or R.rowTall
    row.name:ClearAllPoints(); row.tags:ClearAllPoints()
    if oneLine then
        row.name:SetPoint("LEFT", row, "LEFT", x0, 0)
        row.tags:SetPoint("LEFT", row.name, "RIGHT", gap, -1)
        row.tags:SetWidth(math.max(1, tagW))
    else
        row.name:SetPoint("TOPLEFT", row, "TOPLEFT", x0, -6)
        row.tags:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
        row.tags:SetWidth(avail)
        -- Tall enough for the tags however many lines they wrap to (they spilled out of a
        -- fixed-height row at the minimum window).
        local nameH = math.max(ns.Theme.size.sm, row.name:GetStringHeight() or 0)
        local tagsH = math.max(ns.Theme.size.xs, row.tags:GetStringHeight() or 0)
        h = math.max(h, math.ceil(6 + nameH + 3 + tagsH + 6))
    end
    row:SetHeight(h)
    row.tags:SetShown(tags ~= "")
    return h
end
Detail.PaintRepRow = paintRepRow

-- The info line for a faction: "Friendly, 1,800 to Honored. A shows the 40 quests here that raise it."
function Detail.RepInfo(f)
    local s = ns.Theme.ReactionLabel(f.reaction)
    local nxt = nextLabel(f)
    if not f.maxed and f.into and f.span and nxt then
        s = s .. ", " .. ns.Widgets.Number(f.span - f.into) .. " to " .. nxt
    end
    local n = f.count or #(f.quests or {})
    return s .. string.format(". A shows the %d %s here that %s it.", n, n == 1 and "quest" or "quests", n == 1 and "raises" or "raise")
end

-- A quest chip on the faction page: level (or a gold check when done), name, state, "+amount" ("about" in the group header).
local function newRepChip(parent)
    local T, S = ns.Theme, ns.Theme.space
    local b = newChip(parent)
    b.mark = b:CreateTexture(nil, "OVERLAY")
    b.mark:SetSize(16, 16); b.mark:SetPoint("CENTER", b.lvbg, "CENTER")
    b.mark:SetTexture(T.files.checkDone)
    if b.mark.SetDesaturated then b.mark:SetDesaturated(true) end
    b.mark:SetVertexColor(T.RGB("complete"))
    b.amt = T.Text(b, "xs", "dim")
    b.amt:SetPoint("RIGHT", b, "RIGHT", -S.s2, 0)
    b.amt:SetJustifyH("RIGHT"); b.amt:SetWordWrap(false)
    b.state = T.Text(b, "xs", "dim")
    b.state:SetPoint("RIGHT", b.amt, "LEFT", -S.s2, 0)
    b.state:SetWordWrap(false)
    b.name:ClearAllPoints()
    b.name:SetPoint("LEFT", b.lvbg, "RIGHT", S.s2, 0)
    b.name:SetPoint("RIGHT", b.state, "LEFT", -S.s2, 0)
    return b
end

---------------------------------------------------------------------------------------------
-- "Dungeon here" (Phase 16 task 7; DESIGN "Dungeons tab" round 2, the mockup's dunTiles)
---------------------------------------------------------------------------------------------

-- A tile: the instance's painting edge to edge, a dark shade from the left, the name, "Lv 15-23 ·
-- 8 bosses", the quest bar, the kind's icon bottom right, in card frame A. Pieces are the
-- Dungeons tab's (UI/Pages/Dungeons.lua, loaded by the time a dashboard draws).
local function newDunTile(parent)
    local T, W, DT = ns.Theme, ns.Widgets, ns.Theme.layout.dunTile
    local P = ns.DungeonsPage.Pieces
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(DT.h)
    b.bg = T.Solid(b, "cardBg", "BACKGROUND"); b.bg:SetAllPoints()
    b.art = b:CreateTexture(nil, "BORDER"); b.art:SetAllPoints()
    b.shade = b:CreateTexture(nil, "ARTWORK"); b.shade:SetAllPoints()
    b.shade:SetColorTexture(1, 1, 1, 1)
    local ok = type(CreateColor) == "function" and pcall(b.shade.SetGradient, b.shade, "HORIZONTAL",
        CreateColor(0.04, 0.024, 0.008, 0.88), CreateColor(0.04, 0.024, 0.008, 0.1))
    if not ok then b.shade:SetColorTexture(0.04, 0.024, 0.008, 0.55) end
    b.name = T.Text(b, "lg", "gold")
    b.name:SetPoint("TOPLEFT", b, "TOPLEFT", DT.padX, -DT.padY)
    b.name:SetJustifyH("LEFT"); b.name:SetWordWrap(false)
    b.meta = T.Text(b, "xs", "text")
    b.meta:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -3)
    b.meta:SetJustifyH("LEFT"); b.meta:SetWordWrap(false)
    b.quest = P.newQuestBar(b)
    b.quest:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", DT.padX, DT.footY)
    b.pending = T.Text(b, "xs", "dunFaint")
    b.pending:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", DT.padX, DT.footY)
    b.pending:SetJustifyH("LEFT")
    b.frame = T.CardFrame(b, ns.Theme.layout.dunTab.frameCorner, ns.Theme.layout.dunTab.frameOut, "OVERLAY", "card-frame-a")
    -- The state and focus edge, over the frame's band (as the Dungeons cards).
    b.ring = CreateFrame("Frame", nil, b)
    b.ring:SetAllPoints(b)
    if b.ring.SetFrameLevel and b.GetFrameLevel then b.ring:SetFrameLevel(b:GetFrameLevel() + 3) end
    b.edge = W.Edge(b.ring, "OVERLAY")
    function b:SetFocused(on) self.focused = on; self:Paint() end
    function b:Paint()
        local state = self.known and self.entry and self.entry.progress and self.entry.progress.state
        local col = self.focused and "focus" or (state == "complete" and "complete") or (state == "progress" and "todo")
            or (not self.frame and "cardEdge") or nil
        for i = 1, 4 do self.edge[i]:SetShown(col ~= nil) end
        if col then self.edge:SetColor(col); self.edge:SetThickness(self.focused and 2 or 1) end
    end
    W.HoverInfo(b)
    b:SetScript("OnClick", function(self) if self.item and self.item.onActivate then self.item.onActivate(self.item) end end)
    return b
end

-- Fills a tile for `width`: e = a catalogue entry (nil before the quests are read: inst only).
local function paintDunTile(b, inst, e, known, width)
    local T, DT = ns.Theme, ns.Theme.layout.dunTile
    local P, Words = ns.DungeonsPage.Pieces, ns.DungeonsPage.Words
    b:SetWidth(width)
    P.paintArt(b.art, inst, width, DT.h)
    local inner = width - 2 * DT.padX
    b.name:SetWidth(inner)
    b.name:SetText(inst.name)
    T.FitFont(b.name, inst.name, inner, { "lg", "md" }, 1)
    b.meta:SetWidth(inner)
    for drop = 0, 1 do
        local s = Words.TileMeta(inst, drop)
        b.meta:SetText(s)
        if T.MeasureText(s, "xs") <= inner then break end
    end
    b.quest:SetShown(e ~= nil)
    b.pending:SetShown(e == nil)
    if e then b.quest:Set(e.progress, known, math.min(DT.questBar, inner))
    else b.pending:SetText("Reading its quests") end
    b.entry, b.known = e, known
    b:Paint()
end

-- The zone's instances (entrance here), with their entries once the catalogue is read.
-- Returns a list of { inst, entry } (empty when none).
local function dungeonsHere(mapID)
    local Rules = ns.DungeonRules
    if not (Rules and ns.DungeonData and ns.DungeonsPage) then return {} end
    local st = ns.Dungeons and ns.Dungeons.State()
    local all = st and st.status == "ready" and ns.Dungeons.Catalogue("all") or nil
    local out = {}
    if all then
        for _, e in ipairs(Rules.InZone(all, mapID)) do out[#out + 1] = { inst = e.inst, entry = e } end
    else
        for _, inst in ipairs(Rules.InZone(ns.DungeonData.instances, mapID)) do out[#out + 1] = { inst = inst } end
    end
    return out
end

-- The tiles' columns for a width (style.css .duntiles: auto-fill, minmax(260px, 1fr)).
local function dunCols(width)
    local DT = ns.Theme.layout.dunTile
    return math.max(1, math.floor((width + DT.gap) / (DT.min + DT.gap)))
end

-- Puts the tiles' focus items into rows of `cols` (the rows were made one per tile, so any
-- column count fits; empty rows are skipped by FocusGrid).
local function gridDunRows(d, cols)
    d.dunCols = cols
    for _, r in ipairs(d.dunRowList or {}) do r.items = {} end
    for i, b in ipairs(d.dunUsed or {}) do
        local r = d.dunRowList[math.floor((i - 1) / cols) + 1]
        r.items[#r.items + 1] = b.item
    end
end

-- Fills the "Dungeon here" section: appends its focus rows to `rows`. A opens the instance in the
-- Dungeons tab; B there comes back to this zone.
local function fillDungeons(d, zone, rows, width)
    local S = ns.Theme.space
    local here = dungeonsHere(zone.mapID)
    for _, b in ipairs(d.dunTiles) do b:Hide() end
    d.dunUsed, d.dunRowList = {}, {}
    d.dunPlate:SetShown(#here > 0)
    if #here == 0 then d.dunList = nil; return end
    d.dunList = here
    d.dunPlate.title:SetText(ns.DungeonsPage.Words.Here(here))
    local known = ns.Dungeons and ns.Dungeons.CompletionKnown() or false
    local Words = ns.DungeonsPage.Words
    local column = d.dashScroll.child
    for i, x in ipairs(here) do
        local b = d.dunTiles[i]
        if not b then b = newDunTile(column); d.dunTiles[i] = b end
        local key, inst = x.inst.key, x.inst
        local where = Words.Where(inst, ns.DungeonsPage.Pieces.zoneName)
        local detail = x.entry and Words.Info(x.entry, known, where, true)
            or string.format("%s, levels %d-%d (a guide). Its quests are still being read.",
                inst.kind == "raid" and "Raid" or "Dungeon", inst.levels[1], inst.levels[2])
        b.item = { key = "dun:" .. key, frame = b, title = inst.name, detail = detail .. " A opens it in the Dungeons tab.",
            scroll = d.dashScroll, topGap = NEXT_PLATE + S.s2,
            actionLabel = "Open", onActivate = function() ns.DungeonsPage.Open(key, "zones") end }
        b.dunInst, b.dunEntry, b.dunKnown = inst, x.entry, known
        b:Show()
        d.dunUsed[i] = b
        local r = { items = {} }
        d.dunRowList[i] = r
        rows[#rows + 1] = r
    end
    gridDunRows(d, dunCols(width))
end

---------------------------------------------------------------------------------------------
-- Construction
---------------------------------------------------------------------------------------------

function Detail.New(page)
    local T, L, S, W = ns.Theme, ns.Theme.layout, ns.Theme.space, ns.Widgets
    local d = CreateFrame("Frame", nil, page)
    d:SetAllPoints()
    d:Hide()

    -- Banner header ---------------------------------------------------------------------------
    local banner = CreateFrame("Frame", nil, d)
    banner:SetPoint("TOPLEFT"); banner:SetPoint("TOPRIGHT")
    banner:SetHeight(L.bannerHeight)
    banner.art = banner:CreateTexture(nil, "BACKGROUND")
    banner.art:SetAllPoints()
    banner:SetScript("OnSizeChanged", cropBanner)
    local shade = banner:CreateTexture(nil, "BORDER")
    shade:SetAllPoints()
    shade:SetColorTexture(1, 1, 1, 1)
    local ok = type(CreateColor) == "function" and pcall(shade.SetGradient, shade, "HORIZONTAL",
        CreateColor(0, 0, 0, 0.85), CreateColor(0, 0, 0, 0.15))
    if not ok then shade:SetColorTexture(0, 0, 0, 0.5) end
    local rshade = banner:CreateTexture(nil, "BORDER", nil, 1)
    rshade:SetPoint("TOPRIGHT"); rshade:SetPoint("BOTTOMRIGHT")
    rshade:SetWidth(L.bannerRightShade)
    rshade:SetColorTexture(1, 1, 1, 1)
    local rok = type(CreateColor) == "function" and pcall(rshade.SetGradient, rshade, "HORIZONTAL",
        CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, 0.8))
    if not rok then rshade:SetColorTexture(0, 0, 0, 0.45) end
    local rule = T.Solid(banner, "divider", "ARTWORK")
    rule:SetPoint("BOTTOMLEFT"); rule:SetPoint("BOTTOMRIGHT"); rule:SetHeight(2)
    banner.name = T.Text(banner, "xxl", "gold")
    banner.name:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", S.s6, S.s6 + S.s2)
    banner.crumb = T.Text(banner, "lg", "text")
    banner.crumb:SetPoint("BOTTOMLEFT", banner.name, "BOTTOMRIGHT", S.s2, 2)
    banner.sub = T.Text(banner, "sm", "text")
    banner.sub:SetPoint("TOPLEFT", banner.name, "BOTTOMLEFT", 0, -S.s1)
    local back = CreateFrame("Button", nil, banner, "UIPanelButtonTemplate")
    back:SetSize(150, 24)
    back:SetPoint("TOPRIGHT", -S.s4, -S.s3)
    back:SetText("Zones")
    back:SetScript("OnClick", function() page:Back() end)
    d.back = back
    local map = CreateFrame("Button", nil, banner, "UIPanelButtonTemplate")
    map:SetSize(110, 24)
    map:SetText("World map")
    map:SetScript("OnClick", function() page:OpenMap() end)
    d.mapButton = map
    -- A category page's count, right side: "42 of 68" and the percentage.
    banner.pct = T.Text(banner, "xxl", "white")
    banner.pct:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", -S.s6, S.s6 + S.s2)
    banner.count = T.Text(banner, "sm", "text")
    banner.count:SetPoint("RIGHT", banner.pct, "LEFT", -S.s3, 0)
    -- The dashboard's score (round 2): the zone's %, one line per category, what's unchecked.
    banner.zpct = T.Text(banner, "xxl", "white")
    T.SetFont(banner.zpct, "huge")
    banner.znote = T.Text(banner, "xs", "dim")
    banner.znote:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", -S.s6, S.s4)
    banner.zcats = T.Text(banner, "sm", "text")
    banner.zcats:SetPoint("BOTTOMRIGHT", banner.znote, "TOPRIGHT", 0, S.s1)
    banner.zpct:SetPoint("BOTTOMRIGHT", banner.zcats, "TOPRIGHT", 0, S.s1)
    d.banner = banner

    -- Dashboard -------------------------------------------------------------------------------
    local dash = CreateFrame("Frame", nil, d)
    -- Left edge on the zone title's (S.s6); the same visible gap above and below the war banner
    -- panel (owner, 2026-11-09: it was 8 units right of the title, 16 above and about 10 below).
    dash:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", S.s6, -S.s4)
    dash:SetPoint("BOTTOMRIGHT", -S.s6, S.s4 + L.edgeCover)
    d.dash = dash
    local std = CreateFrame("Frame", nil, dash)
    std:SetPoint("TOPLEFT"); std:SetPoint("BOTTOMLEFT")
    std:SetWidth(STANDARD_W)
    std.art = std:CreateTexture(nil, "BACKGROUND")
    std.art:SetAllPoints()
    std.edge = W.Edge(std, "BORDER")
    std.edge:SetColor("cardEdge")
    std.frame = T.CardFrame(std, 24, 0)
    std.edge[1]:SetShown(std.frame == nil); std.edge[2]:SetShown(std.frame == nil)
    std.edge[3]:SetShown(std.frame == nil); std.edge[4]:SetShown(std.frame == nil)
    -- The standard stands on the panel's floor; no text under it (round 2).
    std.banner = ns.ZoneBanner.New(std)
    std.banner:SetPoint("CENTER", std, "CENTER", 0, 0) -- centred in the panel (owner, 2026-11-08)
    d.standard = std
    -- Refit when the panel itself settles (after a resize the dashboard's own size event alone
    -- left the pole poking out once, WoWScrnShot_110826_225122).
    std:SetScript("OnSizeChanged", function() Detail.FitStandard(d) end)
    -- The right column (tiles, Next up, Reputation) scrolls when the window is too short for it
    -- (minimum size, WoWScrnShot_110826_224414); the standard stays. The scroll frame starts
    -- DASH_OVER left of and above the column so the plate's ends and the tiles' frames aren't
    -- clipped: inside it, the column's origin is (DASH_OVER, -DASH_OVER).
    local right = W.Scroll(dash)
    right:SetPoint("TOPLEFT", std, "TOPRIGHT", S.s6 - DASH_OVER, DASH_OVER)
    right:SetPoint("BOTTOMRIGHT", dash, "BOTTOMRIGHT", DASH_OVER, 0)
    d.dashScroll = right
    local col = right.child
    -- Round 3: three square tiles side by side (sized in fillDashboard), no A hints (the owner:
    -- "already obvious"), then "Next up" under them.
    d.tiles = {}
    for i, key in ipairs(T.categoryOrder) do
        local tile = CreateFrame("Button", nil, col)
        tile:SetSize(200, TILE_SQ)
        tile.bg = T.Solid(tile, "cardBg", "BACKGROUND")
        tile.bg:SetAllPoints()
        tile.edge = W.Edge(tile, "BORDER")
        tile.icon = tile:CreateTexture(nil, "ARTWORK")
        tile.icon:SetSize(20, 20)
        tile.icon:SetPoint("TOPLEFT", S.s3, -S.s3)
        T.SetCategoryIcon(tile.icon, key, 20)
        tile.title = T.Text(tile, "md", "gold")
        tile.title:SetPoint("LEFT", tile.icon, "RIGHT", S.s2, 0)
        tile.title:SetText(T.category[key].label)
        tile.pct = T.Text(tile, "lg", "todo")
        tile.pct:SetPoint("TOPRIGHT", -S.s3, -S.s3)
        tile.count = T.Text(tile, "xl", "white")
        tile.count:SetPoint("TOPLEFT", tile.icon, "BOTTOMLEFT", 0, -S.s2)
        -- A gilded bar (painted housing and gold), or the gold pips on Exploration (round 2).
        tile.bar = T.GildedBar(tile, 18)
        tile.bar:SetPoint("TOPLEFT", tile.count, "BOTTOMLEFT", -4, -S.s1)
        tile.bar:SetPoint("RIGHT", tile, "RIGHT", -S.s2, 0)
        tile.pips = W.Pips(tile)
        tile.pips:SetPoint("LEFT", tile.bar, "LEFT", 4, 0)
        tile.line1 = T.Text(tile, "xs", "text")
        tile.line1:SetPoint("TOPLEFT", tile.bar, "BOTTOMLEFT", 4, -S.s1)
        tile.line1:SetPoint("RIGHT", tile, "RIGHT", -S.s3, 0)
        tile.line1:SetJustifyH("LEFT"); tile.line1:SetJustifyV("TOP"); tile.line1:SetWordWrap(true)
        tile.line2 = T.Text(tile, "xs", "dim")
        tile.line2:SetPoint("TOPLEFT", tile.line1, "BOTTOMLEFT", 0, -2)
        tile.line2:SetPoint("RIGHT", tile, "RIGHT", -S.s3, 0)
        tile.line2:SetJustifyH("LEFT"); tile.line2:SetJustifyV("TOP"); tile.line2:SetWordWrap(true)
        T.RowHighlight(tile, "HIGHLIGHT")
        tile.frame = T.CardFrame(tile, 24, 4)
        function tile:SetFocused(on) self.focused = on; self:Paint() end
        -- With the painted frame the plain edge only shows focus; without it, the state too.
        function tile:Paint()
            if self.focused then
                self.edge:SetColor("focus"); self.edge:SetThickness(2)
                for i = 1, 4 do self.edge[i]:Show() end
            elseif self.frame then
                for i = 1, 4 do self.edge[i]:Hide() end
            else
                self.edge:SetColor(self.state == "complete" and "complete" or "cardEdge"); self.edge:SetThickness(1)
            end
        end
        W.HoverInfo(tile)
        tile.key = key
        tile:SetScript("OnClick", function(self) if self.item and self.item.onActivate then self.item.onActivate(self.item) end end)
        d.tiles[i] = tile
    end
    -- "Next up in <zone>": the painted header plate (three-slice), then up to five items.
    local nu = T.Plate(col, NEXT_PLATE)
    nu.empty = T.Text(col, "sm", "dim")
    nu.empty:SetPoint("TOP", nu, "BOTTOM", 0, -S.s3)
    d.nextup = nu
    d.nextItems = {}
    -- The Reputation ledger under Next up (Phase 11): a slim gold title over the painted
    -- divider, the note on the right, one line per faction (placed by LayoutDash).
    local R = L.rep
    local rep = CreateFrame("Frame", nil, col)
    rep:SetHeight(R.head)
    rep.title = T.Text(rep, "md", "gold")
    rep.title:SetPoint("TOPLEFT", rep, "TOPLEFT", S.s1, 0)
    rep.title:SetText("Reputation")
    rep.note = T.Text(rep, "xs", "dim")
    rep.note:SetPoint("TOPRIGHT", rep, "TOPRIGHT", -S.s1, -3)
    rep.note:SetText("Not part of the zone's progress")
    local divFile = T.Chrome("divider")
    if divFile then
        rep.rule = rep:CreateTexture(nil, "ARTWORK")
        rep.rule:SetTexture(divFile)
        rep.rule:SetHeight(R.divider)
        rep.rule:SetPoint("TOPLEFT", rep, "TOPLEFT", 0, -(R.head - R.divider))
        rep.rule:SetPoint("TOPRIGHT", rep, "TOPRIGHT", 0, -(R.head - R.divider))
    else
        rep.rule = T.Solid(rep, "gold", "ARTWORK", 0.28)
        rep.rule:SetHeight(1)
        rep.rule:SetPoint("TOPLEFT", rep, "TOPLEFT", 0, -(R.head - R.divider / 2))
        rep.rule:SetPoint("TOPRIGHT", rep, "TOPRIGHT", 0, -(R.head - R.divider / 2))
    end
    rep:Hide()
    d.rep = rep
    d.repRows = {}
    -- "Also for your level" (Phase 15 step 11; the review's empty area under Next up): where a
    -- zone has no reputation ledger, the plate and up to three cards for other zones that suit
    -- your level (ns.Zones.AlsoForLevel). Each card: the zone's art (greyed while untouched),
    -- name, the guide's range and continent, its %; A opens it. Placed by LayoutDash.
    local also = T.Plate(col, NEXT_PLATE)
    also.title:SetText("Also for your level")
    also:Hide()
    d.also = also
    d.alsoCards = {}
    for i = 1, ALSO_MAX do
        local c = CreateFrame("Button", nil, col)
        c:SetHeight(ALSO_H)
        c.art = c:CreateTexture(nil, "BACKGROUND")
        c.art:SetAllPoints()
        c.shade = c:CreateTexture(nil, "BORDER")
        c.shade:SetAllPoints()
        c.shade:SetColorTexture(1, 1, 1, 1)
        local ok = type(CreateColor) == "function" and pcall(c.shade.SetGradient, c.shade, "VERTICAL",
            CreateColor(0.04, 0.024, 0.008, 0.92), CreateColor(0.04, 0.024, 0.008, 0.1))
        if not ok then c.shade:SetColorTexture(0.04, 0.024, 0.008, 0.6) end
        c.edge = W.Edge(c, "ARTWORK")
        c.edge:SetColor("cardEdge")
        c.name = T.Text(c, "sm", "white")
        c.sub = T.Text(c, "xs", "dim")
        c.sub:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", S.s2, S.s2)
        c.name:SetPoint("BOTTOMLEFT", c.sub, "TOPLEFT", 0, 2)
        c.pct = T.Text(c, "md", "todo")
        c.pct:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -S.s2, S.s2)
        c.name:SetPoint("RIGHT", c.pct, "LEFT", -S.s2, 0)
        c.name:SetJustifyH("LEFT"); c.name:SetWordWrap(false)
        T.RowHighlight(c, "HIGHLIGHT")
        function c:SetFocused(on)
            self.focused = on
            self.edge:SetColor(on and "focus" or "cardEdge"); self.edge:SetThickness(on and 2 or 1)
        end
        W.HoverInfo(c)
        c:SetScript("OnClick", function(self) if self.item and self.item.onActivate then self.item.onActivate(self.item) end end)
        c:Hide()
        d.alsoCards[i] = c
    end
    -- "Dungeon here" (Phase 16 task 7): the plate under Next up, then one framed tile per
    -- instance whose entrance is in the zone (also on capitals with nothing else to track).
    d.dunPlate = T.Plate(col, NEXT_PLATE)
    d.dunPlate:Hide()
    d.dunTiles = {}
    dash:SetScript("OnSizeChanged", function() Detail.LayoutDash(d) end)

    -- Pages (a scroll area) ---------------------------------------------------------------------
    local scroll = W.Scroll(d)
    scroll:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", 0, -S.s3)
    scroll:SetPoint("BOTTOMRIGHT", 0, S.s2)
    d.scroll = scroll
    d.headers, d.checks, d.chips, d.nodes, d.folds, d.lines, d.texts = {}, {}, {}, {}, {}, {}, {}
    d.repChips, d.repSums, d.groupFolds = {}, {}, {}
    d.message = T.Text(scroll.child, "md", "dim")
    d.message:SetPoint("TOPLEFT", L.listInset, -S.s4)
    d.message:SetPoint("RIGHT", scroll.child, "RIGHT", -S.s6, 0)
    d.message:SetJustifyH("LEFT")
    d.toggle = W.FocusRow(scroll.child, L.checkRow)
    d.toggle.text = T.Text(d.toggle, "sm", "text")
    d.toggle.text:SetPoint("LEFT", S.s3, 0)
    d.toggle:SetScript("OnClick", function(self) if self.item then self.item.onActivate(self.item) end end)

    -- Exploration: the area list's column and the zone map beside it (Phase 15 step 6). The
    -- map's tiles live on a holder in map units, scaled to the map's width (LayoutExplore).
    local listCol = CreateFrame("Frame", nil, scroll.child)
    listCol:SetPoint("TOPLEFT"); listCol:SetHeight(1)
    d.listCol = listCol
    local zm = CreateFrame("Frame", nil, scroll.child)
    zm:Hide()
    zm.bg = T.Solid(zm, "black", "BACKGROUND")
    zm.bg:SetAllPoints()
    if zm.SetClipsChildren then pcall(zm.SetClipsChildren, zm, true) end
    zm.holder = CreateFrame("Frame", nil, zm)
    zm.holder:SetPoint("TOPLEFT")
    zm.base, zm.pieces = {}, {}
    -- The painted frame on a frame of its own, above the holder's tiles (inside the clip).
    zm.border = CreateFrame("Frame", nil, zm)
    zm.border:SetAllPoints()
    zm.border:SetFrameLevel(zm.holder:GetFrameLevel() + 2)
    zm.frame = T.CardFrame(zm.border, 24, 0)
    if not zm.frame then zm.edge = W.Edge(zm.border, "OVERLAY"); zm.edge:SetColor("cardEdge") end
    zm.cap = CreateFrame("Frame", nil, scroll.child)
    zm.cap:SetHeight(MAP_CAPTION)
    zm.cap:SetPoint("TOPLEFT", zm, "BOTTOMLEFT", 0, -S.s2)
    zm.cap:SetPoint("TOPRIGHT", zm, "BOTTOMRIGHT", 0, -S.s2)
    local function swatch(after, r, g, b)
        local t = zm.cap:CreateTexture(nil, "ARTWORK")
        t:SetSize(12, 12)
        t:SetColorTexture(r, g, b, 1)
        if after then t:SetPoint("LEFT", after, "RIGHT", S.s4, 0) else t:SetPoint("LEFT", zm.cap, "LEFT", 0, 0) end
        local fs = T.Text(zm.cap, "xs", "text")
        fs:SetPoint("LEFT", t, "RIGHT", S.s1, 0)
        return t, fs
    end
    local _, lit = swatch(nil, 0.79, 0.70, 0.48)
    lit:SetText("Revealed")
    local fogSwatch, fogText = swatch(lit, 0.79 * FOG[1], 0.70 * FOG[2], 0.48 * FOG[3])
    fogText:SetText("Unexplored")
    zm.legend = { fogSwatch, fogText }
    zm.note = T.Text(zm.cap, "xs", "dim")
    zm.note:SetPoint("RIGHT", zm.cap, "RIGHT", 0, 0)
    zm.note:SetText("The game's own map")
    d.zmap = zm
    scroll.onWidth = function() if zm:IsShown() then Detail.LayoutExplore(d) end end
    return d
end

---------------------------------------------------------------------------------------------
-- Pools (one counter per kind, reset on every fill)
---------------------------------------------------------------------------------------------

local function take(d, kind, make)
    d.used[kind] = (d.used[kind] or 0) + 1
    local list = d[kind]
    local f = list[d.used[kind]]
    if not f then f = make(); list[d.used[kind]] = f end
    f:ClearAllPoints()
    f:Show()
    return f
end

local function resetPools(d)
    d.used = {}
    for _, kind in ipairs({ "headers", "checks", "chips", "nodes", "folds", "lines", "texts", "repChips", "repSums", "groupFolds" }) do
        for _, f in ipairs(d[kind]) do f:Hide() end
    end
    d.message:Hide()
    d.toggle:Hide()
    d.zmap:Hide(); d.zmap.cap:Hide()
end

-- A group header from listInset to the page's right margin, or to `right`'s right edge.
local function header(d, y, title, count, right)
    local L, S = ns.Theme.layout, ns.Theme.space
    local h = take(d, "headers", function() return ns.Widgets.Header(d.scroll.child) end)
    h:SetPoint("TOPLEFT", d.scroll.child, "TOPLEFT", L.listInset, -y)
    if right then h:SetPoint("TOPRIGHT", right, "TOPRIGHT", 0, -y)
    else h:SetPoint("TOPRIGHT", d.scroll.child, "TOPRIGHT", -S.s6, -y) end
    h.text:SetText(title)
    h.count:SetText(count or "")
    return y + L.listHeader + S.s2
end

local function text(d, y, s, size, color, x)
    local L, S = ns.Theme.layout, ns.Theme.space
    local fs = take(d, "texts", function()
        local f = CreateFrame("Frame", nil, d.scroll.child)
        f.fs = ns.Theme.Text(f, "sm", "text")
        f.fs:SetPoint("TOPLEFT"); f.fs:SetPoint("TOPRIGHT")
        f.fs:SetJustifyH("LEFT")
        return f
    end)
    ns.Theme.SetFont(fs.fs, size or "sm")
    fs.fs:SetTextColor(ns.Theme.RGB(color or "text"))
    fs:SetPoint("TOPLEFT", d.scroll.child, "TOPLEFT", x or L.listInset, -y)
    fs:SetPoint("RIGHT", d.scroll.child, "RIGHT", -S.s6, 0)
    fs.fs:SetText(s)
    local h = math.max(ns.Theme.size[size or "sm"] + 4, fs.fs.GetStringHeight and fs.fs:GetStringHeight() or 0)
    fs:SetHeight(h)
    return y + h + S.s1
end

---------------------------------------------------------------------------------------------
-- Header (banner)
---------------------------------------------------------------------------------------------

local function bannerSub(zone)
    local parts = { zone.continent }
    local lo, hi = ns.Zones.LevelsFor(ns.ZoneData, zone.mapID)
    if lo then parts[#parts + 1] = lo == hi and ("Level " .. lo) or string.format("Levels %d-%d", lo, hi) end
    local faction = ns.Zones.FactionFor(ns.ZoneData, zone.mapID)
    if faction then parts[#parts + 1] = faction == "Contested" and "Contested" or (faction .. " territory") end
    return table.concat(parts, "  ·  ")
end

local function catOf(entry, key)
    for _, c in ipairs(entry and entry.cats or {}) do if c.key == key then return c end end
end

local function fillBanner(d, zone, entry, pageKey)
    local T = ns.Theme
    local b = d.banner
    local art = T.ZoneArt(zone.mapID)
    if art then b.art:SetTexture(art) else b.art:SetColorTexture(0, 0, 0, 1) end
    b.mapID = zone.mapID
    cropBanner(b)
    -- A faction page: "Booty Bay · Stranglethorn Vale", the reaction on the right.
    local repID = Detail.RepFaction(pageKey)
    local fac = repID and ns.Reputation.Faction(zone, repID)
    local title = pageKey and (T.category[pageKey] and T.category[pageKey].label) or zone.name
    if repID then title = fac and fac.name or "Reputation" end
    b.name:SetText(title)
    b.crumb:SetText(pageKey and ("·  " .. zone.name) or "")
    b.sub:SetText(bannerSub(zone))
    d.back:SetText(pageKey and zone.name or "Zones")
    -- The dashboard's header is taller (round 2), with the zone's score on the right; a page
    -- keeps the usual height with its category's count.
    b:SetHeight(pageKey and T.layout.bannerHeight or DASH_HEADER)
    cropBanner(b)
    T.SetFont(b.pct, repID and "xl" or "xxl")
    local c = pageKey and catOf(entry, pageKey)
    if fac then
        local rc = T.reaction.text[fac.reaction] or T.color.text
        b.pct:SetText(T.ReactionLabel(fac.reaction))
        b.pct:SetTextColor(rc[1], rc[2], rc[3])
        b.count:SetText("")
    elseif c and not c.pending then
        b.pct:SetText(ns.Progression.PercentText(c.progress) or "-")
        b.pct:SetTextColor(T.RGB(c.state == "complete" and "complete" or (c.completed > 0 and "todo" or "white")))
        b.count:SetText(string.format("%d of %d", c.completed, c.denominator))
    else
        b.pct:SetText(""); b.count:SetText("")
    end
    local dash = pageKey == nil and entry.tracked
    b.zpct:SetShown(dash); b.zcats:SetShown(dash); b.znote:SetShown(dash)
    if dash then
        local claimed = entry.state == "complete"
        b.zpct:SetText(claimed and "Claimed" or (entry.combined and ns.Progression.PercentText(entry.combined) or "-"))
        b.zpct:SetTextColor(T.RGB(claimed and "complete" or "white"))
        local parts, notes = {}, {}
        for _, cat in ipairs(entry.cats or {}) do
            local meta = T.category[cat.key]
            local icon = T.CategoryInline(cat.key, 16) .. " "
            if cat.pending then
                parts[#parts + 1] = icon .. "?"
            else
                local col = cat.state == "complete" and "|cffffcc33" or "|cfff0e8d8"
                parts[#parts + 1] = icon .. col .. cat.completed .. "/" .. cat.denominator .. "|r"
                if cat.unchecked and cat.unchecked > 0 and not claimed then
                    notes[#notes + 1] = cat.unchecked .. " " .. meta.unit .. " can't be checked yet"
                end
            end
        end
        b.zcats:SetText(table.concat(parts, "    "))
        b.znote:SetText(table.concat(notes, "  ·  "))
    end
end

---------------------------------------------------------------------------------------------
-- Dashboard
---------------------------------------------------------------------------------------------

local PENDING_TEXT = {
    achievements = "The game isn't returning achievement data right now.",
    building = "Reading quests from QuestieDB...",
    flightmaster = "Talk to any flight master on this continent to check which you know.",
}

-- Fits the standard to its panel: the art cropped to the panel's shape (cover, don't squash:
-- the owner found it squished in game), the banner as large as the panel allows. Runs on
-- every fill and resize (resizing to the minimum left the pole poking out of the panel,
-- WoWScrnShot_110826_224414).
local function fitStandard(d)
    local std = d.standard
    local pw, ph = std:GetWidth() or 0, std:GetHeight() or 0
    if std.hasArt and pw > 0 and ph > 0 then
        local f = math.min(1, (pw / ph) / 2)
        std.art:SetTexCoord(0.5 - f / 2, 0.5 + f / 2, 0, 1)
    end
    local bannerW, bannerH = std.banner:GetWidth() or 0, std.banner:GetHeight() or 0
    if ph > 0 and bannerH > 0 and bannerW > 0 then
        std.banner:SetScale(math.max(0.2, math.min(1.4, (ph - 6) / bannerH, (pw - 4) / bannerW)))
    end
end
Detail.FitStandard = fitStandard

local function fillDashboard(d, zone, entry, page)
    local T, S, W = ns.Theme, ns.Theme.space, ns.Widgets
    local rows = {}
    local std = d.standard
    local art = T.ZoneArt(zone.mapID)
    if art then std.art:SetTexture(art) else std.art:SetColorTexture(0.05, 0.03, 0.02, 1) end
    std.hasArt = art ~= nil
    -- Round 3: the zone comes alive as it fills, grey and dim at 0% to full colour at 100%.
    local p = math.max(0, math.min(100, entry.percent or 0)) / 100
    if std.art.SetDesaturation then std.art:SetDesaturation(1 - (0.12 + 0.88 * p))
    elseif std.art.SetDesaturated then std.art:SetDesaturated(p < 0.5) end
    local v = 0.30 + 0.30 * p
    std.art:SetVertexColor(v, v * 0.96, v * 0.92)
    local faction = (ns.character and ns.character.faction == "Horde") and "Horde" or "Alliance"
    std.banner:Set(entry, faction, page.animateBanner)
    fitStandard(d)
    page.animateBanner = false

    local ex, q, f = ns.Exploration.ForZone(zone), ns.Quests.ForZone(zone.mapID), ns.FlightPaths.ForZone(zone.mapID)
    -- Three square tiles in a row, right of the standard (placed by layoutDash).
    local tileItems, canOpen = {}, false
    for i, key in ipairs(T.categoryOrder) do
        local tile = d.tiles[i]
        tile.pipsData = nil
        local c = catOf(entry, key)
        local line1, line2, open = "", "", nil
        if key == "explore" then
            if ex.status == "tracked" then
                local nextArea, left = nil, 0
                for _, o in ipairs(ex.objectives or {}) do
                    if o.completion == "incomplete" then left = left + 1; nextArea = nextArea or o.name end
                end
                line1 = nextArea and ("Next: |cffffffff" .. nextArea .. "|r" .. (left > 1 and ("  and " .. (left - 1) .. " more") or ""))
                    or "Every area discovered"
                open = "Areas"
            elseif ex.status == "untracked" then
                line1 = "The game has no Explore achievement for " .. zone.name .. "."
            else
                line1 = PENDING_TEXT.achievements
            end
        elseif key == "quests" then
            if q.status == "ready" and c then
                line1 = string.format("|cffe08a3c%d|r ready · |cffffffff%d|r stories · |cffffffff%d|r done",
                    #(q.ready or {}), #(q.stories or {}), #(q.finished or {}))
                local first = q.ready and q.ready[1]
                line2 = first and ("Next: " .. first.name) or ""
                if c.unchecked and c.unchecked > 0 then line2 = line2 .. (line2 ~= "" and "  ·  " or "") .. c.unchecked .. " unchecked" end
                open = "Quests"
            elseif q.status == "ready" then
                line1 = (q.count or 0) > 0 and "None of the quests here are for this character."
                    or ("QuestieDB lists no quests in " .. zone.name .. ".")
                if (q.count or 0) > 0 then open = "Quests" end
            elseif q.status == "unavailable" then
                line1 = "Quests need the QuestieDB addon, which isn't loaded."
            else
                line1 = PENDING_TEXT.building
            end
        else
            if f.status == "ready" then
                local names = {}
                for _, o in ipairs(f.objectives) do
                    names[#names + 1] = (o.completion == "complete" and "|cffffcc33" or "|cffb5a891") .. o.name .. "|r"
                end
                line1 = table.concat(names, "   ")
                open = "Flight paths"
            elseif f.status == "pending" then
                line1 = PENDING_TEXT.flightmaster
                open = "Flight paths"
            else
                line1 = "No flight master for you in " .. zone.name .. "."
            end
        end
        tile.state = c and c.state or nil
        if c and not c.pending then
            tile.count:SetText(string.format("%d of %d", c.completed, c.denominator))
            tile.pct:SetText(ns.Progression.PercentText(c.progress) or "-")
            tile.pct:SetTextColor(T.RGB(c.state == "complete" and "complete" or "todo"))
            local frac = c.denominator > 0 and c.completed / c.denominator or 0
            -- Exploration: the gold pips (round 2); the others: the gilded bar.
            local p = key == "explore" and c.progress
            tile.pips:SetShown(p ~= nil and p ~= false)
            tile.bar:SetShown(not p)
            if p then
                tile.pipsData = { p.complete, p.incomplete, p.completionUnknown }
            else
                tile.bar:Set(frac, c.state)
            end
        else
            tile.count:SetText(""); tile.pct:SetText(c and c.pending and "?" or "")
            tile.pct:SetTextColor(T.RGB("dim"))
            tile.bar:SetShown(c ~= nil); if c then tile.bar:Set(0) end
            tile.pips:Hide()
        end
        tile.line1:SetText(line1)
        tile.line2:SetText(line2)
        tile.icon:SetAlpha(c and 1 or 0.45)
        tile.title:SetTextColor(T.RGB(c and "gold" or "dim"))
        local detail = c and not c.pending and string.format("%d of %d  ·  %s", c.completed, c.denominator, line1:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
            or line1:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        tile.item = { key = "tile:" .. key, frame = tile, title = T.category[key].label, detail = detail,
            scroll = d.dashScroll, topGap = DASH_OVER,
            actionLabel = open and "Open" or nil,
            onActivate = open and function() page:OpenPage(key) end or nil }
        tile:Paint()
        tileItems[#tileItems + 1] = tile.item
        if open then canOpen = true end
    end
    -- Nothing to open (a zone with nothing tracked): no focus stops, so the split view's A
    -- stays in the list; the tiles say why.
    local dashW = d.dash:GetWidth() or 0
    if dashW <= 0 then dashW = 900 end
    local colW = dashW - STANDARD_W - S.s6
    if not canOpen then
        d.nextup:Hide(); d.nextup.empty:Hide(); for _, b in ipairs(d.nextItems) do b:Hide() end
        d.nextCount = 0
        d.repList = nil; d.rep:Hide(); for _, r in ipairs(d.repRows) do r:Hide() end
        d.alsoList = nil; d.also:Hide(); for _, c in ipairs(d.alsoCards) do c:Hide() end
        -- A capital with nothing else to track still shows its dungeon (task 7).
        d.dashScroll:SetVerticalScroll(0)
        local dunRows = {}
        fillDungeons(d, zone, dunRows, colW)
        Detail.LayoutDash(d)
        return dunRows
    end
    rows[#rows + 1] = { items = tileItems }

    -- Next up in <zone> (round 3): Zones.NextUp picks, each opens its page on that item.
    local nu = d.nextup
    nu:ClearAllPoints()
    local column = d.dashScroll.child
    d.dashScroll:SetVerticalScroll(0)
    nu:SetPoint("TOPLEFT", column, "TOPLEFT", 0, -(DASH_OVER + TILE_SQ + S.s6))
    nu:SetPoint("RIGHT", column, "RIGHT", 0, 0)
    nu:Show()
    local picks = ns.Zones.NextUp(ex, q, f)
    local claimed = entry.state == "complete"
    nu.title:SetText(claimed and (zone.name .. " is claimed") or ("Next up in " .. zone.name))
    nu.empty:SetText(#picks == 0 and (claimed and "Every area, quest and flight path you can do here is done."
        or "Nothing to suggest here right now.") or "")
    nu.empty:SetShown(#picks == 0)
    local SUB = { explore = "Area to discover", flights = "Flight path to discover" }
    for _, b in ipairs(d.nextItems) do b:Hide() end
    local row
    for i, it in ipairs(picks) do
        local b = d.nextItems[i]
        if not b then
            b = W.FocusRow(column, NEXT_ITEM_H)
            b.bg = T.Solid(b, "ctlBg", "BACKGROUND", 0.9); b.bg:SetAllPoints()
            b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(22, 22); b.icon:SetPoint("LEFT", S.s2, 0)
            b.name = T.Text(b, "sm", "white"); b.name:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", S.s2, 2)
            b.name:SetPoint("RIGHT", b, "RIGHT", -S.s2, 0); b.name:SetJustifyH("LEFT"); b.name:SetWordWrap(false)
            b.sub = T.Text(b, "xs", "dim"); b.sub:SetPoint("BOTTOMLEFT", b.icon, "BOTTOMRIGHT", S.s2, -2)
            b:SetScript("OnClick", function(self) if self.item then self.item.onActivate(self.item) end end)
            d.nextItems[i] = b
        end
        local col = (i - 1) % NEXT_COLS
        T.SetCategoryIcon(b.icon, it.kind, 22)
        b.name:SetText(it.name or "?")
        local dc = it.difficulty and DIFF_COLOR[it.difficulty]
        if dc then b.name:SetTextColor(dc[1], dc[2], dc[3]) else b.name:SetTextColor(T.RGB("white")) end
        local sub = SUB[it.kind] or ("Quest  ·  level " .. tostring(it.level or "?"))
        b.sub:SetText(sub)
        local kind, id = it.kind, it.id
        b.item = { key = "next:" .. kind .. ":" .. tostring(id), frame = b, title = it.name, detail = sub .. ". A opens it.",
            scroll = d.dashScroll, topGap = NEXT_PLATE + S.s2,
            actionLabel = "Open", onActivate = function()
                page:OpenPage(kind)
                page.pendingFocusKey = Detail.FocusKey(kind, id)
                page.Redraw()
            end }
        b:Show()
        if col == 0 then row = { items = {} }; rows[#rows + 1] = row end
        table.insert(row.items, b.item)
    end
    d.nextCount = #picks

    -- Dungeon here (Phase 16 task 7): under Next up, above the ledger.
    fillDungeons(d, zone, rows, colW)

    -- Reputation (Phase 11): the zone's factions, hidden when there are none. Each line is a
    -- focus stop; A opens the faction's page.
    local factions = ns.Reputation and ns.Reputation.ForZone(zone)
    d.repList = factions
    for _, r in ipairs(d.repRows) do r:Hide() end
    d.rep:SetShown(factions ~= nil)
    for i, fac in ipairs(factions or {}) do
        local r = d.repRows[i]
        if not r then r = newRepRow(column); d.repRows[i] = r end
        local id = fac.factionID
        r.item = { key = Detail.RepKey(id), frame = r, title = fac.name, detail = Detail.RepInfo(fac),
            scroll = d.dashScroll, topGap = ns.Theme.layout.rep.head + S.s2,
            actionLabel = "Open", onActivate = function() page:OpenRep(id) end }
        r.fac = fac
        r:Show()
        rows[#rows + 1] = { items = { r.item } }
    end

    -- Also for your level (Phase 15 step 11): only where there's no ledger.
    local also = nil
    if not factions then
        local all = page.catalogue and page.catalogue.all or ns.Zones.All()
        local c = ns.character or {}
        also = ns.Zones.AlsoForLevel(all, entry, { faction = c.faction, level = c.level })
        if #also == 0 then also = nil end
    end
    d.alsoList = also
    d.also:SetShown(also ~= nil)
    for _, card in ipairs(d.alsoCards) do card:Hide() end
    if also then
        local row = { items = {} }
        for i, z in ipairs(also) do
            local card = d.alsoCards[i]
            local zart = T.ZoneArt(z.mapID)
            if zart then card.art:SetTexture(zart) else card.art:SetColorTexture(0.08, 0.05, 0.03, 1) end
            card.mapID = zart and z.mapID or nil
            local untouched = z.state ~= ns.Zones.PROGRESS
            if card.art.SetDesaturated then card.art:SetDesaturated(untouched) end
            local v = untouched and 0.5 or 0.6
            card.art:SetVertexColor(v, v * 0.94, v * 0.86)
            card.name:SetText(z.name)
            local range = z.minLevel .. "–" .. z.maxLevel
            card.sub:SetText(range .. "  ·  " .. (z.continent or ""))
            local pct = not untouched and z.combined and ns.Progression.PercentText(z.combined) or nil
            card.pct:SetText(pct or "—")
            card.pct:SetTextColor(T.RGB(pct and "todo" or "dim"))
            local target = { mapID = z.mapID, name = z.name, continent = z.continent, minLevel = z.minLevel,
                maxLevel = z.maxLevel, faction = z.faction }
            card.item = { key = "also:" .. z.mapID, frame = card, title = z.name,
                detail = "Levels " .. range .. " (the zone guide's range)  ·  " .. (pct or "untouched") .. ". A opens it.",
                scroll = d.dashScroll, topGap = NEXT_PLATE + S.s2,
                actionLabel = "Open", onActivate = function() page:Open(target) end }
            card:Show()
            row.items[#row.items + 1] = card.item
        end
        rows[#rows + 1] = row
    end
    Detail.LayoutDash(d)
    return rows
end

-- Places the dashboard's tiles and Next up items for its current width. Runs after every fill
-- and whenever the dashboard changes size (the split view's pane settles after the first
-- fill; computing once left the third tile past the edge in game, WoWScrnShot_110826_172435).
function Detail.LayoutDash(d)
    local S = ns.Theme.space
    local dashW = d.dash:GetWidth() or 0
    if dashW <= 0 then dashW = 900 end
    fitStandard(d)
    local tileW = math.floor((dashW - STANDARD_W - S.s6 - 2 * S.s4) / 3)
    for i, tile in ipairs(d.tiles) do
        tile:ClearAllPoints()
        tile:SetSize(tileW, TILE_SQ)
        tile:SetPoint("TOPLEFT", d.dashScroll.child, "TOPLEFT", DASH_OVER + (i - 1) * (tileW + S.s4), -DASH_OVER)
        if tile.pipsData then tile.pips:Set(tile.pipsData[1], tile.pipsData[2], tile.pipsData[3], tileW - 2 * S.s3) end
    end
    local width = dashW - STANDARD_W - S.s6
    local colW = math.floor((width - (NEXT_COLS - 1) * S.s3) / NEXT_COLS)
    for i, b in ipairs(d.nextItems) do
        local col, r = (i - 1) % NEXT_COLS, math.floor((i - 1) / NEXT_COLS)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", d.nextup, "BOTTOMLEFT", 8 + col * (colW + S.s3), -(S.s2 + r * (NEXT_ITEM_H + S.s2)))
        b:SetWidth(colW)
    end
    -- The column's height for its scroll frame: the tiles, Next up and its items (or its
    -- "nothing to suggest" line), then the ledger.
    local n = d.nextCount or 0
    local column = d.dashScroll.child
    local below = n > 0 and (S.s2 + math.ceil(n / NEXT_COLS) * (NEXT_ITEM_H + S.s2))
        or (S.s3 + (d.nextup.empty:GetStringHeight() or 14))
    -- `height` runs down the column: the tiles, then Next up (not on a zone with nothing to open).
    local nextShown = d.nextup:IsShown()
    local height = nextShown and (DASH_OVER + TILE_SQ + S.s6 + NEXT_PLATE + below) or (DASH_OVER + TILE_SQ)
    -- Dungeon here (task 7): the plate, then the tiles in a grid (auto-fill, at least 260 wide).
    if d.dunList then
        local DT = ns.Theme.layout.dunTile
        local top = height + (nextShown and S.s4 or S.s6)
        local plate = d.dunPlate
        plate:ClearAllPoints()
        plate:SetPoint("TOPLEFT", column, "TOPLEFT", 0, -top)
        plate:SetPoint("RIGHT", column, "RIGHT", 0, 0)
        local cols = dunCols(width)
        if cols ~= d.dunCols then
            gridDunRows(d, cols)
            -- The pane settled to another width after the fill: D-pad rows follow the new grid.
            if ns.UI.CurrentTab and ns.UI.CurrentTab() == "zones" and d:IsShown() then ns.Focus.Rebuild() end
        end
        local tw = math.floor((width - (cols - 1) * DT.gap) / cols)
        local y0 = top + NEXT_PLATE + S.s2
        for i, b in ipairs(d.dunUsed) do
            local c, r = (i - 1) % cols, math.floor((i - 1) / cols)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", column, "TOPLEFT", DASH_OVER + c * (tw + DT.gap), -(y0 + r * (DT.h + DT.gap)))
            paintDunTile(b, b.dunInst, b.dunEntry, b.dunKnown, tw)
        end
        height = y0 + math.ceil(#d.dunUsed / cols) * (DT.h + DT.gap) - DT.gap
        below = height - (DASH_OVER + TILE_SQ + S.s6 + NEXT_PLATE)
    end
    -- The Reputation ledger: under Next up's items (or its "nothing to suggest" line).
    if d.repList then
        local R = ns.Theme.layout.rep
        local rep = d.rep
        rep:ClearAllPoints()
        rep:SetPoint("TOPLEFT", d.nextup, "BOTTOMLEFT", 8, -(below + S.s2))
        rep:SetWidth(width)
        -- The compact columns in the wide split, and wherever the ledger is narrow (the minimum
        -- window left the name about 70 px, WoWScrnShot_110826_224828).
        local cols = (d.wide or width < R.compactBelow) and R.wide or R
        local y = R.head + S.s1
        for i, fac in ipairs(d.repList) do
            local row = d.repRows[i]
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", rep, "TOPLEFT", 0, -y)
            row:SetWidth(width)
            y = y + paintRepRow(row, fac, width, cols) + R.gap
        end
        height = height + S.s2 + y
    end
    -- Also for your level: the plate under Next up, then the cards side by side.
    if d.alsoList then
        local also = d.also
        also:ClearAllPoints()
        also:SetPoint("TOPLEFT", d.nextup, "BOTTOMLEFT", 0, -(below + S.s4))
        also:SetPoint("RIGHT", d.nextup, "RIGHT", 0, 0)
        local cw = math.floor((width - 16 - (ALSO_MAX - 1) * S.s3) / ALSO_MAX)
        for i, z in ipairs(d.alsoList) do
            local c = d.alsoCards[i]
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", also, "BOTTOMLEFT", 8 + (i - 1) * (cw + S.s3), -S.s2)
            c:SetWidth(cw)
            if c.mapID then
                local top, bottom = ns.Theme.BannerCrop(c.mapID, cw, ALSO_H)
                c.art:SetTexCoord(0, 1, top, bottom)
            end
        end
        height = height + S.s4 + NEXT_PLATE + S.s2 + ALSO_H
    end
    d.dashScroll.child:SetHeight(math.max(1, height + S.s2))
end

---------------------------------------------------------------------------------------------
-- Exploration page
---------------------------------------------------------------------------------------------

local MESSAGES = {
    untracked = "The game has no Explore achievement for %s, so Azerfolio can't track its exploration.",
    unavailable = "The game isn't returning achievement data right now. Try again in a moment.",
}

-- Draws ns.ZoneMap's tiles on the map's holder: the base tiles under the fog (none once the
-- zone is fully explored: the design's "fully revealed at 100%"), the explored pieces over them.
local function mapTile(holder, pool, i, layer, t)
    local tex = pool[i]
    if not tex then tex = holder:CreateTexture(nil, layer); pool[i] = tex end
    tex:SetTexture(t.fid)
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", holder, "TOPLEFT", t.x, -t.y)
    tex:SetSize(t.w, t.h)
    tex:SetTexCoord(0, t.r, 0, t.b)
    tex:Show()
    return tex
end

local function drawMap(zm, map, revealed)
    zm.mapW, zm.mapH = map.width, map.height
    zm.holder:SetSize(map.width, map.height)
    local f = revealed and { 1, 1, 1 } or FOG
    for i, t in ipairs(map.base) do mapTile(zm.holder, zm.base, i, "BACKGROUND", t):SetVertexColor(f[1], f[2], f[3]) end
    for i = #map.base + 1, #zm.base do zm.base[i]:Hide() end
    for i, t in ipairs(map.pieces) do mapTile(zm.holder, zm.pieces, i, "ARTWORK", t) end
    for i = #map.pieces + 1, #zm.pieces do zm.pieces[i]:Hide() end
    for _, r in ipairs(zm.legend) do r:SetShown(not revealed) end
end

-- Places the list column and the map beside it for the page's width (on fill and on resize):
-- the list takes MAP_LIST_SHARE (at least MAP_LIST_MIN), the map the rest at its own aspect.
function Detail.LayoutExplore(d)
    local zm, child, S = d.zmap, d.scroll.child, ns.Theme.space
    local cw = child:GetWidth() or 0
    if cw <= 0 or not zm.mapW then return end
    local listW = math.max(MAP_LIST_MIN, math.floor((cw - S.s6) * MAP_LIST_SHARE))
    local mapW = math.floor(cw - listW - 2 * S.s6)
    if mapW < 120 then mapW = 120 end
    local mapH = math.floor(mapW * zm.mapH / zm.mapW + 0.5)
    d.listCol:SetWidth(listW)
    zm:ClearAllPoints()
    zm:SetPoint("TOPLEFT", child, "TOPLEFT", listW + S.s6, -((zm.top or 0) + S.s1))
    zm:SetSize(mapW, mapH)
    zm.holder:SetScale(mapW / zm.mapW)
    local bottom = (zm.top or 0) + S.s1 + mapH + S.s2 + MAP_CAPTION + S.s4
    child:SetHeight(math.max(1, d.exploreBottom or 0, bottom))
end

local function fillExplore(d, zone)
    local T, L, S = ns.Theme, ns.Theme.layout, ns.Theme.space
    local ex = ns.Exploration.ForZone(zone)
    local rows, child = {}, d.scroll.child
    if ex.status ~= "tracked" then
        d.message:SetText(string.format(MESSAGES[ex.status] or MESSAGES.unavailable, zone.name))
        d.message:Show()
        child:SetHeight(100)
        return rows
    end
    local p = ex.progress
    local complete = p.trackedComplete
    local y = 0
    local notes = {}
    if complete then notes[#notes + 1] = "|cffffcc33Fully explored:|r every area the game lists for this zone is discovered." end
    if p.completionUnknown > 0 then
        notes[#notes + 1] = string.format("The game didn't say whether %d %s discovered; %s under State unknown and not counted.",
            p.completionUnknown, p.completionUnknown == 1 and "area is" or "areas are",
            p.completionUnknown == 1 and "it's listed" or "they're listed")
    end
    if p.coverage ~= "complete" and p.completionUnknown == 0 and not complete then
        notes[#notes + 1] = "Some areas couldn't be identified, so this zone has no percentage."
    end
    if ex.uncertain then
        notes[#notes + 1] = "The game's list of areas differs from Azerfolio's catalogue (a game update?). Showing the game's list."
    end
    if #notes > 0 then y = text(d, y, table.concat(notes, "\n"), "sm", "text") + S.s2 end

    -- The zone map beside the list (one column), or the list alone in two columns.
    local map = ns.ZoneMap and ns.ZoneMap.ForMap(zone.mapID)
    local right = nil
    if map then
        drawMap(d.zmap, map, complete)
        d.zmap.top = y
        d.zmap:Show(); d.zmap.cap:Show()
        right = d.listCol
    end

    local todo = { title = "To discover", list = {}, count = p.incomplete }
    local found = { title = "Discovered", list = {}, count = p.complete }
    local unsure = { title = "State unknown", list = {}, count = p.completionUnknown }
    for _, c in ipairs(ex.objectives) do
        if c.completion == "complete" then table.insert(found.list, c)
        elseif c.completion == "incomplete" then table.insert(todo.list, c)
        else table.insert(unsure.list, c) end
    end
    local groups = {}
    if not (complete and #todo.list == 0) then groups[#groups + 1] = todo end
    groups[#groups + 1] = found
    if #unsure.list > 0 then groups[#groups + 1] = unsure end
    for gi, g in ipairs(groups) do
        if gi > 1 then y = y + S.s2 end
        y = header(d, y, g.title, g.count == 1 and "1 area" or (g.count .. " areas"), right) - S.s1
        if #g.list == 0 then y = y + S.s2 end
        local cols = right and 1 or 2
        for i = 1, #g.list, cols do
            local items = {}
            for col = 0, cols - 1 do
                local c = g.list[i + col]
                if c then
                    local row = take(d, "checks", function() return checkRow(child) end)
                    if right then
                        row:SetPoint("TOPLEFT", child, "TOPLEFT", L.listInset, -y)
                        row:SetPoint("TOPRIGHT", right, "TOPRIGHT", 0, -y)
                    elseif col == 0 then
                        row:SetPoint("TOPLEFT", child, "TOPLEFT", L.listInset, -y)
                        row:SetPoint("TOPRIGHT", child, "TOP", -S.s2, -y)
                    else
                        row:SetPoint("TOPLEFT", child, "TOP", S.s2 + L.listInset / 2, -y)
                        row:SetPoint("TOPRIGHT", child, "TOPRIGHT", -S.s6, -y)
                    end
                    local done = c.completion == "complete"
                    local unknown = c.completion ~= "complete" and c.completion ~= "incomplete"
                    row.done:SetShown(done)
                    row.todo:SetShown(not done)
                    local tr, tg, tb = T.RGB(unknown and "untouched" or "todo")
                    row.todo:SetColorTexture(tr, tg, tb, 1)
                    row.name:SetText(c.name or "?")
                    row.name:SetTextColor(T.RGB((done or unknown) and "dim" or "white"))
                    row.item = { key = "c" .. tostring(c.id), frame = row, title = c.name,
                        detail = done and "Discovered" or (unknown and "The game didn't say whether this is discovered")
                            or "Not discovered yet", scroll = d.scroll, topGap = L.listHeader + S.s1 + S.s2 }
                    items[#items + 1] = row.item
                end
            end
            rows[#rows + 1] = { items = items, section = gi }
            y = y + L.checkRow + 2
        end
    end
    d.exploreBottom = y
    if map then Detail.LayoutExplore(d) else child:SetHeight(math.max(1, y)) end
    return rows
end

---------------------------------------------------------------------------------------------
-- Quests page
---------------------------------------------------------------------------------------------

local function questItem(d, frame, key, q, topGap)
    return { key = key, frame = frame, title = q.name or ("Quest " .. tostring(q.id)), detail = Detail.QuestLine(q),
        scroll = d.scroll, topGap = topGap }
end

-- A storyline's track at y: columns by depth, branches stacked. Returns new y and focus rows.
local function track(d, y, story, showUnavailable, keyPrefix)
    local T, L, S = ns.Theme, ns.Theme.layout, ns.Theme.space
    local child = d.scroll.child
    local cols = {}
    for _, col in ipairs(story.columns) do
        local keep = {}
        for _, q in ipairs(col) do if showUnavailable or q.kind ~= "unavailable" then keep[#keep + 1] = q end end
        if #keep > 0 then cols[#cols + 1] = keep end
    end
    if #cols == 0 then return y, {} end
    local x0 = L.listInset
    local maxStack = 1
    for _, col in ipairs(cols) do maxStack = math.max(maxStack, #col) end
    -- Nodes widen to the room the page has (up to NODE_W_MAX), so names fit two lines ("Find the
    -- Lost Guar..." at 88, review 2026-11-14; checked in game WoWScrnShot_111426_175336).
    local avail = (child:GetWidth() or 900) - x0 - S.s6
    local nodeW = math.max(NODE_W, math.min(NODE_W_MAX, math.floor(avail / #cols)))
    if #cols > 1 then
        local line = take(d, "lines", function() return T.Solid(child, "divider", "BORDER") end)
        line:SetHeight(2)
        line:SetPoint("TOPLEFT", child, "TOPLEFT", x0 + nodeW / 2, -(y + 3 + NODE_DOT / 2 - 1))
        line:SetWidth((#cols - 1) * nodeW)
    end
    local rows = {}
    for level = 1, maxStack do
        local items = {}
        for ci, col in ipairs(cols) do
            local q = col[level]
            if q then
                local n = take(d, "nodes", function() return newNode(child) end)
                n:SetPoint("TOPLEFT", child, "TOPLEFT", x0 + (ci - 1) * nodeW, -(y + (level - 1) * NODE_H))
                n:SetWidth(nodeW); n.name:SetWidth(nodeW - 4)
                paintNode(n, q)
                n.item = questItem(d, n, keyPrefix .. q.id, q, L.listHeader + S.s6)
                items[#items + 1] = n.item
            end
        end
        rows[#rows + 1] = { items = items }
    end
    return y + maxStack * NODE_H + S.s2, rows
end

-- Phase 15 step 5: a long chip group shows its first row (FOLD_SHOW chips) and a fold row; A
-- shows the rest, A again folds it (page.openFolds, this session). Groups shorter than
-- FOLD_MIN never fold.
local FOLD_SHOW, FOLD_MIN = 3, 7

-- Returns the list to draw and whether it folds (and is open).
local function foldList(list, key, page)
    if #list < FOLD_MIN then return list, false, false end
    local open = page and page.openFolds and page.openFolds[key] and true or false
    if open then return list, true, true end
    local shown = {}
    for i = 1, FOLD_SHOW do shown[i] = list[i] end
    return shown, true, false
end

-- The fold row under a folded group. Returns the new y.
local function foldRow(d, y, key, page, total, open, noun, rows, section)
    local T, L, S = ns.Theme, ns.Theme.layout, ns.Theme.space
    local child = d.scroll.child
    local b = take(d, "groupFolds", function()
        local r = ns.Widgets.FocusRow(child, L.checkRow)
        r.mark = T.Text(r, "sm", "gold"); r.mark:SetPoint("LEFT", S.s2, 0)
        r.name = T.Text(r, "sm", "text"); r.name:SetPoint("LEFT", r.mark, "RIGHT", S.s2, 0)
        r.count = T.Text(r, "xs", "dim"); r.count:SetPoint("RIGHT", -S.s3, 0)
        r:SetScript("OnClick", function(self) if self.item then self.item.onActivate(self.item) end end)
        return r
    end)
    b:SetPoint("TOPLEFT", child, "TOPLEFT", L.listInset, -y)
    b:SetPoint("TOPRIGHT", child, "TOPRIGHT", -S.s6, -y)
    local rest = total - FOLD_SHOW
    b.mark:SetText(open and "-" or "+")
    b.name:SetText(open and string.format("Show the first %d", FOLD_SHOW) or string.format("Show %d more", rest))
    b.count:SetText(total .. " " .. noun .. "s")
    b.item = { key = "gfold:" .. key, frame = b, title = open and "Fold" or "Show all", scroll = d.scroll, topGap = L.listHeader + S.s2,
        detail = open and string.format("Back to the first %d.", FOLD_SHOW) or string.format("%d more %ss, by level.", rest, noun),
        actionLabel = open and "Fold" or "Show",
        onActivate = function() if page and page.ToggleFold then page:ToggleFold(key) end end }
    rows[#rows + 1] = { items = { b.item }, section = section }
    return y + L.checkRow + 2
end

local function fillQuests(d, zone, page)
    local T, L, S = ns.Theme, ns.Theme.layout, ns.Theme.space
    local child = d.scroll.child
    local q = ns.Quests.ForZone(zone.mapID)
    local rows = {}
    if q.status ~= "ready" then
        d.message:SetText(q.status == "unavailable" and "Quests need the QuestieDB addon, which isn't loaded. Exploration and flight paths are unaffected."
            or "Reading quests from QuestieDB...")
        d.message:Show()
        child:SetHeight(100)
        return rows
    end
    if (q.count or 0) == 0 then
        d.message:SetText("QuestieDB lists no quests in " .. zone.name .. ".")
        d.message:Show()
        child:SetHeight(100)
        return rows
    end
    local show = ns.db.zones.showUnavailable
    local y, section = 0, 0
    local p = q.progress
    if p.denominator == 0 then
        y = text(d, y, string.format("None of the %d quests here are for this character, so quests don't count toward %s.",
            p.unavailable, zone.name), "sm", "dim") + S.s2
    end

    -- Ready now: chips, three to a row. Then the ready quests red for you (Phase 15 step 5),
    -- folded when long.
    local groups = {}
    if #(q.ready or {}) > 0 then groups[#groups + 1] = { title = "Ready now", list = q.ready, count = #q.ready .. (#q.ready == 1 and " quest" or " quests") } end
    if #(q.readyRed or {}) > 0 then
        groups[#groups + 1] = { title = "Ready, but red for you", list = q.readyRed, fold = "red",
            count = #q.readyRed .. "  ·  5 or more levels above you" }
    end
    for _, g in ipairs(groups) do
        section = section + 1
        y = header(d, y, g.title, g.count)
        local width = (child:GetWidth() or 900) - L.listInset - S.s6
        local cw = math.floor((width - (CHIP_COLS - 1) * S.s2) / CHIP_COLS)
        local list, folds, open = g.list, false, false
        if g.fold then list, folds, open = foldList(g.list, g.fold, page) end
        for i = 1, #list, CHIP_COLS do
            local items = {}
            for c = 0, CHIP_COLS - 1 do
                local quest = list[i + c]
                if quest then
                    local b = take(d, "chips", function() return newChip(child) end)
                    b:SetPoint("TOPLEFT", child, "TOPLEFT", L.listInset + c * (cw + S.s2), -y)
                    b:SetWidth(cw)
                    local col = DIFF_COLOR[quest.difficulty] or { 1, 1, 1 }
                    b.lv:SetText(quest.questLevel or "?")
                    b.lv:SetTextColor(col[1], col[2], col[3])
                    b.name:SetText(quest.name or "?")
                    b.item = questItem(d, b, "r:" .. quest.id, quest, L.listHeader + S.s2)
                    items[#items + 1] = b.item
                end
            end
            rows[#rows + 1] = { items = items, section = section }
            y = y + CHIP_H + S.s2
        end
        if folds then y = foldRow(d, y, g.fold, page, #g.list, open, "quest", rows, section) end
        y = y + S.s2
    end

    -- Storylines in progress, then single quests not done.
    local singles = {}
    for _, s in ipairs(q.singles or {}) do
        if s.kind ~= "done" and (show or s.kind ~= "unavailable") then singles[#singles + 1] = s end
    end
    local singlesDone = 0
    for _, s in ipairs(q.singles or {}) do if s.kind == "done" then singlesDone = singlesDone + 1 end end
    if #(q.stories or {}) > 0 or #singles > 0 then
        section = section + 1
        y = header(d, y, "Storylines", #q.stories .. " in progress")
        for _, story in ipairs(q.stories) do
            y = text(d, y, string.format("|cffffffff%s|r   |cffb5a891%d of %d done|r%s", story.name or "?", story.done, story.total,
                story.ready > 0 and string.format("  |cffe08a3c%d ready|r", story.ready) or ""), "sm", "text")
            local trows
            y, trows = track(d, y, story, show, "q:")
            for _, r in ipairs(trows) do r.section = section; rows[#rows + 1] = r end
        end
        if #singles > 0 then
            y = text(d, y, string.format("|cffffffffSingle quests|r   |cffb5a891%d done|r", singlesDone), "sm", "text")
            local width = (child:GetWidth() or 900) - L.listInset - S.s6
            local perRow = math.max(1, math.floor(width / NODE_W))
            for i = 1, #singles, perRow do
                local items = {}
                for c = 0, perRow - 1 do
                    local s = singles[i + c]
                    if s then
                        local n = take(d, "nodes", function() return newNode(child) end)
                        n:SetPoint("TOPLEFT", child, "TOPLEFT", L.listInset + c * NODE_W, -y)
                        paintNode(n, s)
                        n.item = questItem(d, n, "q:" .. s.id, s, L.listHeader + S.s6)
                        items[#items + 1] = n.item
                    end
                end
                rows[#rows + 1] = { items = items, section = section }
                y = y + NODE_H
            end
            y = y + S.s2
        end
    end

    -- Finished storylines, folded; A unfolds one.
    if #(q.finished or {}) > 0 then
        section = section + 1
        y = header(d, y, "Finished", string.format("%d storylines  ·  %d single quests", #q.finished, singlesDone))
        for _, story in ipairs(q.finished) do
            local open = page.openStories[story.id]
            local b = take(d, "folds", function()
                local r = ns.Widgets.FocusRow(child, L.checkRow)
                r.done = r:CreateTexture(nil, "ARTWORK")
                r.done:SetSize(L.checkIcon, L.checkIcon); r.done:SetPoint("LEFT", S.s2, 0)
                r.done:SetTexture(T.files.checkDone)
                if r.done.SetDesaturated then r.done:SetDesaturated(true) end
                r.done:SetVertexColor(T.RGB("complete"))
                r.name = T.Text(r, "sm", "dim"); r.name:SetPoint("LEFT", r.done, "RIGHT", S.s2, 0)
                r.count = T.Text(r, "xs", "dim"); r.count:SetPoint("RIGHT", -S.s3, 0)
                r:SetScript("OnClick", function(self) if self.item then self.item.onActivate(self.item) end end)
                return r
            end)
            b:SetPoint("TOPLEFT", child, "TOPLEFT", L.listInset, -y)
            b:SetPoint("TOPRIGHT", child, "TOPRIGHT", -S.s6, -y)
            b.name:SetText(story.name or "?")
            b.count:SetText(story.total .. " quests   " .. (open and "-" or "+"))
            local id = story.id
            b.item = { key = "fold:" .. id, frame = b, title = story.name, scroll = d.scroll, topGap = L.listHeader + S.s2,
                detail = string.format("%d quests, every one you can do is done. A %s the storyline.", story.size,
                    open and "folds" or "shows"),
                actionLabel = open and "Fold" or "Show",
                onActivate = function() page:ToggleStory(id) end }
            rows[#rows + 1] = { items = { b.item }, section = section }
            y = y + L.checkRow + 2
            if open then
                local trows
                y, trows = track(d, y + S.s1, story, show, "fq:")
                for _, r in ipairs(trows) do r.section = section; rows[#rows + 1] = r end
            end
        end
        y = y + S.s2
    end

    -- Footer: what the numbers leave out, and the can't-do toggle.
    local left = {}
    if (q.repeatable or 0) > 0 then left[#left + 1] = q.repeatable .. " repeatable" end
    if p.eligibilityUnknown > 0 then
        local why, n = {}, 0
        for w in pairs(q.unknownReasons or {}) do n = n + 1; why[#why + 1] = w end
        table.sort(why)
        if n > 1 then for i, w in ipairs(why) do why[i] = w .. " " .. q.unknownReasons[w] end end
        left[#left + 1] = string.format("%d we can't check yet (%s)", p.eligibilityUnknown, table.concat(why, ", "))
    end
    y = y + S.s2
    y = text(d, y, "From QuestieDB, which may miss quests." .. (#left > 0 and (" Not counted: " .. table.concat(left, ", ") .. ".") or ""),
        "xs", "dim")
    if p.unavailable > 0 then
        section = section + 1
        local t = d.toggle
        t:SetPoint("TOPLEFT", child, "TOPLEFT", L.listInset, -(y + S.s1))
        t:SetWidth(320)
        t.text:SetText(string.format("%s %d %s you can't do", show and "Hide" or "Show", p.unavailable,
            p.unavailable == 1 and "quest" or "quests"))
        t.item = { key = "toggle", frame = t, title = (show and "Hide" or "Show") .. " quests you can't do",
            detail = "Other faction or class, a finished chain or a choice already made. Never counted.",
            scroll = d.scroll, actionLabel = show and "Hide" or "Show",
            onActivate = function() page:ToggleUnavailable() end }
        t:Show()
        rows[#rows + 1] = { items = { t.item }, section = section }
        y = y + L.checkRow + S.s2
    end
    child:SetHeight(math.max(1, y + S.s4))
    return rows
end

---------------------------------------------------------------------------------------------
-- Flight paths page
---------------------------------------------------------------------------------------------

local function fillFlights(d, zone)
    local T, L, S = ns.Theme, ns.Theme.layout, ns.Theme.space
    local child = d.scroll.child
    local f = ns.FlightPaths.ForZone(zone.mapID)
    local rows, y = {}, 0
    if f.status == "none" or f.status == "unavailable" then
        d.message:SetText("No flight master for you in " .. zone.name .. ".")
        d.message:Show()
        child:SetHeight(100)
        return rows
    end
    if f.status == "pending" then
        y = text(d, y, PENDING_TEXT.flightmaster .. " Until then, Azerfolio can't tell which of these you know.", "sm", "text") + S.s2
    end
    y = header(d, y, "Flight masters", #f.objectives == 1 and "1 flight path" or (#f.objectives .. " flight paths"))
    for i = 1, #f.objectives, 2 do
        local items = {}
        for col = 0, 1 do
            local o = f.objectives[i + col]
            if o then
                local row = take(d, "checks", function() return checkRow(child) end)
                if col == 0 then
                    row:SetPoint("TOPLEFT", child, "TOPLEFT", L.listInset, -y)
                    row:SetPoint("TOPRIGHT", child, "TOP", -S.s2, -y)
                else
                    row:SetPoint("TOPLEFT", child, "TOP", S.s2 + L.listInset / 2, -y)
                    row:SetPoint("TOPRIGHT", child, "TOPRIGHT", -S.s6, -y)
                end
                local known, unknown = o.completion == "complete", o.completion == "unknown"
                row.done:SetShown(known)
                row.todo:SetShown(not known)
                local tr, tg, tb = T.RGB(unknown and "untouched" or "todo")
                row.todo:SetColorTexture(tr, tg, tb, 1)
                row.name:SetText(o.name or "?")
                row.name:SetTextColor(T.RGB(known and "dim" or "white"))
                row.item = { key = "f" .. tostring(o.id), frame = row, title = o.name, scroll = d.scroll,
                    detail = known and "Known: you can fly here" or (unknown and "Not checked yet: talk to a flight master on this continent")
                        or "Not discovered yet: talk to the flight master there" }
                items[#items + 1] = row.item
            end
        end
        rows[#rows + 1] = { items = items, section = 1 }
        y = y + L.checkRow + 2
    end
    child:SetHeight(math.max(1, y))
    return rows
end

---------------------------------------------------------------------------------------------
-- Faction page (Phase 11): the zone's quests that raise one faction
---------------------------------------------------------------------------------------------

local REP_STATE = { locked = "Locked", unavailable = "Not for you", unknown = "Not checked" }

local function fillRep(d, zone, factionID, page)
    local T, L, S = ns.Theme, ns.Theme.layout, ns.Theme.space
    local R = L.rep
    local child = d.scroll.child
    local f = ns.Reputation.Faction(zone, factionID)
    local rows = {}
    if not f then
        d.message:SetText("Azerfolio has no standing for this faction right now.")
        d.message:Show()
        child:SetHeight(100)
        return rows
    end
    local width = (child:GetWidth() or 900) - L.listInset - S.s6
    local y = 0
    -- The summary: the ledger line, larger, with what's left to the next reaction.
    local sum = take(d, "repSums", function() return newRepRow(child, true) end)
    sum:SetPoint("TOPLEFT", child, "TOPLEFT", L.listInset, -y)
    sum:SetWidth(width)
    y = y + paintRepRow(sum, f, width, R.sum, true) + S.s3
    if #(f.rivals or {}) > 0 then
        local names = {}
        for _, r in ipairs(f.rivals) do names[#names + 1] = r.name or "?" end
        y = text(d, y, string.format("Rivals: quests here that raise %s lower %s, and the other way round.",
            f.name or "?", table.concat(names, " and ")), "sm", "repRival") + S.s2
    end
    -- Up to your level, then Later (from level n, names dimmed). LT/RT jump between them.
    local level = ns.character and ns.character.level
    local now, later = {}, {}
    for _, q in ipairs(f.quests or {}) do
        local from = q.reqLevel or q.questLevel
        if type(level) == "number" and type(from) == "number" and from > level then later[#later + 1] = q
        else now[#now + 1] = q end
    end
    local function byLevel(a, b)
        local la, lb = a.questLevel or 0, b.questLevel or 0
        if la ~= lb then return la < lb end
        return (a.name or "") < (b.name or "")
    end
    table.sort(now, byLevel); table.sort(later, byLevel)
    local groups = {}
    if #now > 0 then groups[#groups + 1] = { title = "Up to your level", list = now, count = tostring(#now) } end
    if #later > 0 then
        local from
        for _, q in ipairs(later) do
            local v = q.reqLevel or q.questLevel
            if v and (not from or v < from) then from = v end
        end
        groups[#groups + 1] = { title = "Later", list = later, later = true, fold = "rep:" .. tostring(factionID),
            count = #later .. (from and ("  ·  from level " .. from) or "") }
    end
    local cw = math.floor((width - (CHIP_COLS - 1) * S.s2) / CHIP_COLS)
    for gi, g in ipairs(groups) do
        -- The chips show "+100"; "about" sits in the header once (the game's font drew "~" as a
        -- raised squiggle, review 2026-11-14).
        local anyAmount = false
        for _, q in ipairs(g.list) do if q.amount then anyAmount = true; break end end
        y = header(d, y, g.title, g.count .. (anyAmount and "  ·  rep gains are about" or ""))
        -- Phase 15 step 5: a long Later (67 at level 10) folds to its first row.
        local list, folds, open = g.list, false, false
        if g.fold then list, folds, open = foldList(g.list, g.fold, page) end
        for i = 1, #list, CHIP_COLS do
            local items = {}
            for c = 0, CHIP_COLS - 1 do
                local q = list[i + c]
                if q then
                    local b = take(d, "repChips", function() return newRepChip(child) end)
                    b:SetPoint("TOPLEFT", child, "TOPLEFT", L.listInset + c * (cw + S.s2), -y)
                    b:SetWidth(cw)
                    local kind = q.kind
                    local done = kind == "done"
                    local col = DIFF_COLOR[g.later and "grey" or q.difficulty] or DIFF_COLOR.grey
                    b.lv:SetText(q.questLevel or "?")
                    b.lv:SetTextColor(col[1], col[2], col[3])
                    b.lv:SetShown(not done)
                    b.mark:SetShown(done)
                    b.name:SetText(q.name or ("Quest " .. tostring(q.id)))
                    b.name:SetTextColor(T.RGB((done or g.later) and "dim" or (kind == "ready" and "white" or "text")))
                    -- Under Later, a quest locked only by level says nothing: the header does.
                    local levelOnly = g.later and kind == "locked" and type(q.reason) == "string" and q.reason:find("^level") ~= nil
                    local st = not levelOnly and REP_STATE[kind] or nil
                    local state = q.repeatable and (st and (st .. ", repeatable") or "Repeatable") or st or ""
                    b.state:SetText(state)
                    b.amt:SetText(q.amount and ("+" .. ns.Widgets.Number(q.amount)) or "")
                    b:SetAlpha(kind == "unavailable" and 0.5 or 1)
                    local line = Detail.QuestLine({ questLevel = q.questLevel, reqLevel = q.reqLevel, kind = kind,
                        difficulty = q.difficulty, reason = q.reason, prereqs = q.prereqs, prereqAny = q.prereqAny })
                    if q.repeatable then line = line .. "  ·  Repeatable" end
                    if q.amount then
                        line = line .. string.format(".  About +%s %s (QuestieDB's base value).",
                            ns.Widgets.Number(q.amount), f.name or "")
                    end
                    b.item = { key = "rq:" .. tostring(q.id), frame = b, title = q.name or ("Quest " .. tostring(q.id)),
                        detail = line, scroll = d.scroll, topGap = L.listHeader + S.s2 }
                    items[#items + 1] = b.item
                end
            end
            rows[#rows + 1] = { items = items, section = gi }
            y = y + CHIP_H + S.s2
        end
        if folds then y = foldRow(d, y, g.fold, page, #g.list, open, "quest", rows, gi) end
        y = y + S.s2
    end
    y = text(d, y + S.s2, "From QuestieDB. Amounts are its base values, so approximate; done, locked and not-for-you states are the Quests page's.",
        "xs", "dim")
    child:SetHeight(math.max(1, y + S.s4))
    return rows
end

---------------------------------------------------------------------------------------------
-- Fill
---------------------------------------------------------------------------------------------

-- Fills the detail for `zone` (a { mapID, name, continent } table) on `pageKey` (nil = the
-- dashboard). `entry` is the zone's ns.Zones entry. Returns the focus rows.
function Detail.Fill(d, zone, entry, pageKey, page)
    resetPools(d)
    d.wide = page and page.wide or false
    fillBanner(d, zone, entry, pageKey)
    d.dash:SetShown(pageKey == nil)
    d.scroll:SetShown(pageKey ~= nil)
    d.scroll:SetVerticalScroll(0)
    if pageKey == nil then return fillDashboard(d, zone, entry, page) end
    local repID = Detail.RepFaction(pageKey)
    if repID then return fillRep(d, zone, repID, page) end
    if pageKey == "explore" then return fillExplore(d, zone) end
    if pageKey == "quests" then return fillQuests(d, zone, page) end
    return fillFlights(d, zone)
end
