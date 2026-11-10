-- Reputation tab (Phase 12, spec §7.9, mockups/DESIGN.md "Reputation tab"): every faction the
-- game returns data for, and a page per faction on how to raise it. Not completion language:
-- no %, no claims, no celebrations; Exalted is gold (owner, 2026-11-09).
--   * list: toolbar (All / Met / Not met yet, Sort; Y cycles it), the standing strip (a painted
--     plaque per reaction with its emblem and count, "Met n of m · Exalted n of m"), then the
--     factions in groups with sticky headers (LT/RT), each row a zone-art thumbnail, name and
--     tags, reaction, the notched bar, n / m;
--   * faction page (A): the main zone's art in the banner, the bar with the reach ghost, the
--     reach in words, the game's description, the rival seesaw, Where to raise it (A on a zone
--     opens that zone's faction page on the Zones tab, B comes back here), the footer note.
-- X watches the focused or shown faction (C_Reputation.SetWatchedFactionByID, through
-- ns.Reputation). In a wide window the page sits beside the list and follows focus; A moves
-- into it. Everything shown comes from ns.Reputation / ns.ReputationRules; this file draws it.
local _, ns = ...

local FILTERS = { { "all", "All" }, { "met", "Met" }, { "unmet", "Not met yet" } }
local FILTER_INFO = { all = "Show every faction.", met = "Show the factions you've met.",
    unmet = "Show the factions you haven't met yet." }
local SORT_LABEL = { group = "By group", closest = "Closest to next", name = "A-Z" }

local function settings() return ns.db.reputation end
local function N(n) return ns.Widgets.Number(n) end

---------------------------------------------------------------------------------------------
-- Words (from the systems' values; nothing counted here)
---------------------------------------------------------------------------------------------

local function nextLabel(f)
    return f.reaction and f.reaction < 8 and ns.Theme.ReactionLabel(f.reaction + 1) or nil
end

-- Tags in their colours: Not met yet, At war, Rival of, +n today, Watched. `noRival`: the
-- wide list leaves the rival out (the page has it).
local function tags(f, noRival)
    local T = ns.Theme
    local out = {}
    if f.met == false then out[#out + 1] = T.Hex("dim", T.repTags.unmet) end
    if f.atWar then out[#out + 1] = T.Hex("repWar", T.repTags.war) end
    if not noRival then
        for _, r in ipairs(f.rivals or {}) do out[#out + 1] = T.Hex("repRival", string.format(T.repTags.rival, r.name or "?")) end
    end
    if f.gain and f.gain > 0 then out[#out + 1] = T.Hex("repGain", "+" .. N(f.gain) .. " today") end
    if f.watched then out[#out + 1] = T.Hex("repWatch", "Watched") end
    return table.concat(out, "   ")
end

-- "4,200 / 6,000", or "1,800 to Honored" (Closest sort), "" at Exalted.
local function numText(f, closest)
    if f.maxed or not (f.into and f.span) then return "" end
    if closest and f.left and nextLabel(f) then return N(f.left) .. " to " .. nextLabel(f) end
    return N(f.into) .. " / " .. N(f.span)
end

local function infoLine(f)
    local T = ns.Theme
    local s = T.ReactionLabel(f.reaction)
    if not f.maxed and f.left and nextLabel(f) then s = s .. ", " .. N(f.left) .. " to " .. nextLabel(f) end
    if f.met == false then s = s .. " (not met yet)" end
    if f.group == "none" then return s .. ". No quests are known to raise it." end
    if f.sourcesStatus ~= "ready" then return s .. ". Where to raise it needs QuestieDB." end
    return s .. ". A shows where to raise it."
end

local function placeName(s)
    return s.name or (s.kind == "zone" and ("Zone " .. tostring(s.key))) or ns.Theme.repKinds[s.kind] or "?"
end

-- The reach in words (spec §7.9): what the quests you haven't done could bring.
local function reachText(f, reason)
    local T = ns.Theme
    if f.maxed then return nil end
    if f.sourcesStatus ~= "ready" then
        return T.Hex("gold", "Where to raise it") .. "  Needs QuestieDB" ..
            (reason and (" (" .. reason .. ")") or "") .. ", which lists the quests that raise each faction."
    end
    if f.group == "none" then
        return T.Hex("gold", "No quests") .. "  QuestieDB has no quest that raises " .. (f.name or "it") ..
            ", so Azerfolio can't say how to raise it."
    end
    local r = f.reach or {}
    local mine = false
    for _, s in ipairs(f.sources or {}) do if s.forYou ~= false then mine = true end end
    if not mine and #(f.sources or {}) > 0 then
        local names = {}
        for _, s in ipairs(f.sources) do names[#names + 1] = placeName(s) end
        return T.Hex("gold", "Not for you") .. "  Only " .. table.concat(names, ", ") .. " raise it."
    end
    local s
    if (r.count or 0) > 0 then
        local c = T.reaction.text[r.reaction] or T.color.text
        local enough
        if r.reaction == 8 then enough = "enough for " .. T.Hex(c, T.ReactionLabel(8))
        elseif r.reaction and f.reaction and r.reaction > f.reaction then enough = "enough for about " .. T.Hex(c, T.ReactionLabel(r.reaction))
        else enough = "not quite enough for " .. (nextLabel(f) or "the next reaction") end
        s = string.format("about %s from %d %s, %s", T.Hex("white", "+" .. N(r.gain)), r.count,
            r.count == 1 and "quest" or "quests", enough)
    else
        s = "none left that you can do"
    end
    if (r.repeats or 0) > 0 then s = s .. string.format("; %d repeatable turn-in%s on top", r.repeats, r.repeats == 1 and "" or "s") end
    s = s .. "."
    if (r.unknown or 0) > 0 then s = s .. string.format(" %d more can't be checked yet.", r.unknown) end
    local rival = f.rivals and f.rivals[1]
    if rival and (r.lowersRival or 0) * 2 > (r.count or 0) and (r.count or 0) > 0 then
        s = s .. " Most of them lower " .. (rival.name or "its rival") .. "."
    end
    return T.Hex("gold", "Quests you haven't done") .. "  " .. s
end

local function sourceInfo(f, s)
    local T = ns.Theme
    local kind = T.repKinds[s.kind] or "Quests"
    local n = string.format("%d %s", s.count, s.count == 1 and "quest" or "quests")
    if s.repeats > 0 then n = n .. string.format(" (%d repeatable)", s.repeats) end
    local line = kind .. ". " .. n .. (s.oneTime > 0 and (", about +" .. N(s.amount) .. " (QuestieDB's base values)") or "") .. "."
    if s.forYou == false then return line .. " Not for your class." end
    if s.oneTime > 0 then line = line .. string.format(" %d done, %d left you can do.", s.done, s.left) end
    if s.kind == "zone" then
        return line .. (s.zoneFaction and (" A opens " .. (f.name or "it") .. " in " .. placeName(s) .. ".")
            or (" A opens " .. placeName(s) .. "."))
    end
    if s.kind == "dungeon" or s.kind == "raid" then return line .. " The Dungeons tab will show it (later)." end
    return line
end

---------------------------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------------------------

-- A thumbnail: the zone's art (greyed while not met), or an icon for other kinds of place.
local function paintThumb(tex, mapID, kind, grey)
    local T = ns.Theme
    local art = mapID and T.ZoneArt(mapID)
    if art then
        tex:SetTexture(art)
        local w, h = tex:GetWidth(), tex:GetHeight()
        local top, bottom = T.BannerCrop(mapID, w, h)
        tex:SetTexCoord(0, 1, top, bottom)
    else
        tex:SetTexture(T.layout.repTab.kindIcon[kind or "none"] or T.layout.repTab.kindIcon.none)
        tex:SetTexCoord(0.08, 0.92, 0.3, 0.7)
    end
    if tex.SetDesaturated then tex:SetDesaturated(grey and true or false) end
    local v = grey and 0.7 or 1
    tex:SetVertexColor(v, v, v)
end

-- The ledger's row background (gradient, edge).
local function rowBackground(row)
    local T, W = ns.Theme, ns.Widgets
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(1, 1, 1, 1)
    local top, bottom = T.color.repRowTop, T.color.repRowBottom
    local ok = type(CreateColor) == "function" and pcall(row.bg.SetGradient, row.bg, "VERTICAL",
        CreateColor(bottom[1], bottom[2], bottom[3], 0.9), CreateColor(top[1], top[2], top[3], 0.85))
    if not ok then row.bg:SetColorTexture(top[1], top[2], top[3], 0.88) end
    row.edge = W.Edge(row, "BORDER")
    row.edge:SetColor("repRowEdge")
end

-- A faction line: optional thumbnail, name and tags, reaction, the notched bar, numbers.
-- `plain`: not a focus stop (the page's summary and the seesaw).
local function newFactionRow(parent, plain, withThumb)
    local T, W = ns.Theme, ns.Widgets
    local row = plain and CreateFrame("Frame", nil, parent) or W.FocusRow(parent, T.layout.repTab.row)
    rowBackground(row)
    if withThumb then
        row.thumb = row:CreateTexture(nil, "ARTWORK")
        row.thumbEdge = row:CreateTexture(nil, "BORDER", nil, 1)
        row.thumbEdge:SetColorTexture(0, 0, 0, 1)
        row.thumbEdge:SetPoint("TOPLEFT", row.thumb, "TOPLEFT", -1, 1)
        row.thumbEdge:SetPoint("BOTTOMRIGHT", row.thumb, "BOTTOMRIGHT", 1, -1)
    end
    row.name = T.Text(row, "sm", "white")
    row.name:SetJustifyH("LEFT"); row.name:SetWordWrap(false)
    row.tags = T.Text(row, "xs", "text")
    row.tags:SetJustifyH("LEFT")
    row.react = T.Text(row, "sm", "white")
    row.react:SetJustifyH("LEFT"); row.react:SetWordWrap(false)
    row.num = T.Text(row, "xs", "text")
    row.num:SetJustifyH("RIGHT"); row.num:SetWordWrap(false)
    row.bar = W.RepBar(row)
    if not plain then
        row:SetScript("OnClick", function(self) if self.onClick then self.onClick() end end)
    end
    return row
end

-- Fills a faction line for `width`: cols = { react, ladder, num, colGap, row }; opts = { name
-- (instead of the faction's), tags (string), num (string), thumb = { w, h } or nil, reach,
-- big (md name), noNum }. Returns the height (taller when the tags wrap under the name).
local function paintFactionRow(row, f, width, cols, opts)
    local T = ns.Theme
    local RT, R = T.layout.repTab, T.layout.rep
    local pad, gap = R.pad, cols.colGap
    local x0 = pad
    if row.thumb then
        local th = opts.thumb
        row.thumb:SetShown(th ~= nil); row.thumbEdge:SetShown(th ~= nil)
        if th then
            row.thumb:ClearAllPoints()
            row.thumb:SetSize(th[1], th[2])
            row.thumb:SetPoint("LEFT", row, "LEFT", 4, 0)
            paintThumb(row.thumb, f.artMap, f.main and f.main.kind or (f.group == "none" and "none") or "other", f.met == false)
            x0 = 4 + th[1] + gap
        end
    end
    T.SetFont(row.name, opts.big and "md" or "sm")
    row.name:SetText(opts.name or f.name or ("Faction " .. tostring(f.factionID)))
    row.name:SetTextColor(T.RGB(f.met == false and not opts.name and "text" or "white"))
    row.tags:SetText(opts.tags or "")
    local c = T.reaction.text[f.reaction] or T.color.text
    row.react:SetText(T.ReactionLabel(f.reaction))
    row.react:SetTextColor(c[1], c[2], c[3])
    row.num:SetText(opts.num or "")
    local numW = opts.noNum and 0 or math.max(cols.num, math.ceil(row.num:GetStringWidth() or 0) + 2)
    row.num:SetShown(not opts.noNum)
    row.num:ClearAllPoints(); row.num:SetPoint("RIGHT", row, "RIGHT", -pad, 0); row.num:SetWidth(math.max(1, numW))
    local numGap = opts.noNum and 0 or gap
    row.bar:ClearAllPoints(); row.bar:SetPoint("RIGHT", row, "RIGHT", -(pad + numW + numGap), 0)
    row.bar:Set(f, cols.ladder, opts.big and R.bar.heightSum or R.bar.height, opts.reach)
    row.react:ClearAllPoints()
    row.react:SetPoint("LEFT", row, "RIGHT", -(pad + numW + numGap + cols.ladder + cols.react + gap), 0)
    row.react:SetWidth(cols.react)
    local avail = math.max(40, width - x0 - pad - cols.react - cols.ladder - numW - numGap - 2 * gap)
    local nameW = math.min(avail, math.ceil(row.name:GetStringWidth() or 0) + 1)
    row.name:SetWidth(nameW)
    local t = opts.tags or ""
    local tagW = t ~= "" and math.ceil(row.tags:GetStringWidth() or 0) + 1 or 0
    local oneLine = t == "" or nameW + gap + tagW <= avail
    local h = cols.row or RT.row
    row.name:ClearAllPoints(); row.tags:ClearAllPoints()
    if oneLine then
        row.name:SetPoint("LEFT", row, "LEFT", x0, 0)
        row.tags:SetPoint("LEFT", row.name, "RIGHT", gap, -1)
        row.tags:SetWidth(math.max(1, tagW))
    else
        row.name:SetPoint("TOPLEFT", row, "TOPLEFT", x0, -6)
        row.tags:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
        row.tags:SetWidth(avail)
        local nameH = math.max(T.size.sm, row.name:GetStringHeight() or 0)
        local tagsH = math.max(T.size.xs, row.tags:GetStringHeight() or 0)
        h = math.max(h, math.ceil(6 + nameH + 3 + tagsH + 6))
    end
    row:SetHeight(h)
    row.tags:SetShown(t ~= "")
    return h
end

-- One cell of the standing strip: the painted plaque (frame-plaque) around the tinted cloth
-- (plaque-fill-cloth), darkened at the edges, the reaction's emblem and its count.
local function newCell(parent, r)
    local T = ns.Theme
    local RT = T.layout.repTab
    local c = CreateFrame("Frame", nil, parent)
    local inset = math.floor(RT.plaqueCorner * 0.45)
    c.cloth = c:CreateTexture(nil, "BACKGROUND")
    c.cloth:SetPoint("TOPLEFT", inset, -inset); c.cloth:SetPoint("BOTTOMRIGHT", -inset, inset)
    local cloth = T.Chrome("plaque-fill-cloth")
    if cloth then c.cloth:SetTexture(cloth) else c.cloth:SetTexture(T.files.white) end
    -- Darker toward the edges, so the count stays readable (style.css radial shade).
    c.shades = {}
    local function shade(p1, p2, dir, from, to)
        local s = c:CreateTexture(nil, "BACKGROUND", nil, 1)
        s:SetTexture(T.files.white)
        s:SetPoint(p1, c.cloth, p1); s:SetPoint(p2, c.cloth, p2)
        local ok = type(CreateColor) == "function" and pcall(s.SetGradient, s, dir, CreateColor(0, 0, 0, from), CreateColor(0, 0, 0, to))
        if not ok then s:SetColorTexture(0, 0, 0, 0.2) end
        c.shades[#c.shades + 1] = s
        return s
    end
    shade("TOPLEFT", "BOTTOMLEFT", "HORIZONTAL", 0.55, 0):SetWidth(28)
    shade("TOPRIGHT", "BOTTOMRIGHT", "HORIZONTAL", 0, 0.55):SetWidth(28)
    shade("BOTTOMLEFT", "BOTTOMRIGHT", "VERTICAL", 0.45, 0):SetHeight(12)
    shade("TOPLEFT", "TOPRIGHT", "VERTICAL", 0, 0.35):SetHeight(10)
    c.plaque = T.NineSlice(c, "frame-plaque", RT.plaqueCorner, 0, "ARTWORK")
    if not c.plaque then
        c.edge = ns.Widgets.Edge(c, "ARTWORK"); c.edge:SetColor("cardEdge")
    end
    c.holder = CreateFrame("Frame", nil, c)
    c.holder:SetHeight(RT.emblem)
    c.emblem = c.holder:CreateTexture(nil, "OVERLAY")
    c.emblem:SetPoint("LEFT")
    local file = T.Chrome(T.reaction.emblem[r])
    if file then c.emblem:SetTexture(file) end
    c.count = T.Text(c.holder, "lg", "white", "OVERLAY")
    c.label = T.Text(c.holder, "xs", "text", "OVERLAY")
    c.label:SetText(T.ReactionLabel(r))
    c.reaction = r
    return c
end

local function paintCell(c, n, width, height)
    local T = ns.Theme
    local RT = T.layout.repTab
    c:SetSize(width, height)
    local col = T.reaction.strip[c.reaction]
    local k = n > 0 and RT.clothTint or RT.clothEmpty
    local base = 0.09
    c.cloth:SetVertexColor(col[1] * k + base * (1 - k), col[2] * k + base * (1 - k), col[3] * k + base * (1 - k))
    local showLabel = width >= RT.cellLabelMin
    local em = showLabel and RT.emblem or RT.emblemSmall
    c.emblem:SetSize(em, em)
    c.emblem:SetShown(c.emblem:GetTexture() ~= nil)
    if c.emblem.SetDesaturated then c.emblem:SetDesaturated(n == 0) end
    c.emblem:SetAlpha(n > 0 and 1 or 0.38)
    c.count:SetText(tostring(n))
    c.count:SetAlpha(n > 0 and 1 or 0.38)
    c.label:SetShown(showLabel)
    c.label:SetAlpha(n > 0 and 1 or 0.38)
    c.count:ClearAllPoints(); c.label:ClearAllPoints()
    local tx = em + 6
    if showLabel then
        c.count:SetPoint("TOPLEFT", c.holder, "TOPLEFT", tx, 2)
        c.label:SetPoint("TOPLEFT", c.count, "BOTTOMLEFT", 0, -1)
    else
        c.count:SetPoint("LEFT", c.holder, "LEFT", tx, 0)
    end
    local textW = math.max(c.count:GetStringWidth() or 0, showLabel and (c.label:GetStringWidth() or 0) or 0)
    c.holder:SetWidth(tx + textW)
    c.holder:ClearAllPoints(); c.holder:SetPoint("CENTER", c, "CENTER", 0, 0)
end

-- A "Where to raise it" row: thumbnail, place and kind, quests, ~amount.
local function newSourceRow(parent)
    local T, W, S = ns.Theme, ns.Widgets, ns.Theme.space
    local RT = T.layout.repTab
    local row = W.FocusRow(parent, RT.srcRow)
    rowBackground(row)
    row.thumb = row:CreateTexture(nil, "ARTWORK")
    row.thumb:SetSize(RT.thumb[1], RT.thumb[2])
    row.thumb:SetPoint("LEFT", 4, 0)
    row.amt = T.Text(row, "xs", "text")
    row.amt:SetPoint("RIGHT", -S.s3, 0); row.amt:SetWidth(RT.srcAmt); row.amt:SetJustifyH("RIGHT")
    row.q = T.Text(row, "xs", "text")
    row.q:SetPoint("RIGHT", row.amt, "LEFT", -S.s3, 0); row.q:SetWidth(RT.srcCount); row.q:SetJustifyH("RIGHT")
    row.name = T.Text(row, "sm", "white")
    row.name:SetPoint("TOPLEFT", row.thumb, "TOPRIGHT", S.s3, 1)
    row.name:SetPoint("RIGHT", row.q, "LEFT", -S.s3, 0)
    row.name:SetJustifyH("LEFT"); row.name:SetWordWrap(false)
    row.kind = T.Text(row, "xs", "dim")
    row.kind:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
    row.kind:SetPoint("RIGHT", row.q, "LEFT", -S.s3, 0)
    row.kind:SetJustifyH("LEFT"); row.kind:SetWordWrap(false)
    row:SetScript("OnClick", function(self) if self.item and self.item.onActivate then self.item.onActivate(self.item) end end)
    return row
end

---------------------------------------------------------------------------------------------
-- Page
---------------------------------------------------------------------------------------------

local function build(parent)
    local T, L, S, W = ns.Theme, ns.Theme.layout, ns.Theme.space, ns.Widgets
    local RT = L.repTab
    local page = CreateFrame("Frame", nil, parent)
    page.mode = "list"            -- "list" | "detail" (narrow: the faction page; wide: focus in it)
    page.rows, page.headers, page.cells, page.srcRows = {}, {}, {}, {}

    -- Header: toolbar and the standing strip ---------------------------------------------------
    local head = CreateFrame("Frame", nil, page)
    head:SetHeight(L.toolbarHeight + RT.strip)
    local tb = CreateFrame("Frame", nil, head)
    tb:SetPoint("TOPLEFT"); tb:SetPoint("TOPRIGHT"); tb:SetHeight(L.toolbarHeight)
    T.Solid(tb, "black", "BACKGROUND", 0.28):SetAllPoints()
    local controls = {}
    local function control(key, title, detail, onActivate, actionLabel)
        local b = W.Control(tb)
        b.item = { key = key, frame = b, title = title, detail = detail, onActivate = onActivate, actionLabel = actionLabel }
        b:SetScript("OnClick", function() onActivate(b.item) end)
        controls[#controls + 1] = b
        return b
    end
    page.filters = {}
    for _, fl in ipairs(FILTERS) do
        local value = fl[1]
        local b = control("tb:filter:" .. value, fl[2], FILTER_INFO[value], function()
            settings().filter = value; page:Redraw()
        end, "Show")
        b.value = value
        page.filters[#page.filters + 1] = b
    end
    page.sortBtn = control("tb:sort", "Sort", "Y cycles it.", function() page:CycleSort() end, "Next sort")
    page.count = T.Text(tb, "xs", "dim")
    page.count:SetPoint("RIGHT", tb, "RIGHT", -S.s6, 0)

    local strip = CreateFrame("Frame", nil, head)
    strip:SetPoint("TOPLEFT", tb, "BOTTOMLEFT"); strip:SetPoint("TOPRIGHT", tb, "BOTTOMRIGHT")
    strip:SetHeight(RT.strip)
    T.Solid(strip, "black", "BACKGROUND", 0.18):SetAllPoints()
    local rule = T.Solid(strip, "divider", "BORDER")
    rule:SetPoint("BOTTOMLEFT"); rule:SetPoint("BOTTOMRIGHT"); rule:SetHeight(1)
    for r = 1, 8 do page.cells[r] = newCell(strip, r) end
    page.sumMet = T.Text(strip, "sm", "text")
    page.sumEx = T.Text(strip, "sm", "text")
    page.head, page.toolbar, page.strip = head, tb, strip

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
    -- The sticky header: the group you're scrolled into stays on top (style.css .group-h).
    local sticky = W.Header(list)
    sticky:SetPoint("TOPLEFT", scroll, "TOPLEFT", L.listInset, 0)
    sticky:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", -S.s6, 0)
    sticky:SetFrameLevel(scroll:GetFrameLevel() + 10)
    sticky:Hide()
    page.sticky = sticky
    local function updateSticky()
        local off = scroll:GetVerticalScroll() or 0
        local pick
        for _, h in ipairs(page.headerYs or {}) do if h.y < off then pick = h end end
        sticky:SetShown(pick ~= nil and page.list:IsShown())
        if pick then sticky.text:SetText(pick.text); sticky.count:SetText(pick.count) end
    end
    scroll:HookScript("OnVerticalScroll", updateSticky)
    page.UpdateSticky = updateSticky

    -- Faction page ---------------------------------------------------------------------------------
    local d = CreateFrame("Frame", nil, page)
    local banner = CreateFrame("Frame", nil, d)
    banner:SetPoint("TOPLEFT"); banner:SetPoint("TOPRIGHT"); banner:SetHeight(L.bannerHeight)
    banner.art = banner:CreateTexture(nil, "BACKGROUND")
    banner.art:SetAllPoints()
    banner.plain = banner:CreateTexture(nil, "BACKGROUND", nil, 1)
    banner.plain:SetAllPoints()
    banner.plain:SetColorTexture(0.1, 0.063, 0.031, 1)
    local shade = banner:CreateTexture(nil, "BORDER")
    shade:SetAllPoints(); shade:SetColorTexture(1, 1, 1, 1)
    local ok = type(CreateColor) == "function" and pcall(shade.SetGradient, shade, "HORIZONTAL",
        CreateColor(0, 0, 0, 0.85), CreateColor(0, 0, 0, 0.25))
    if not ok then shade:SetColorTexture(0, 0, 0, 0.5) end
    local brule = T.Solid(banner, "divider", "ARTWORK")
    brule:SetPoint("BOTTOMLEFT"); brule:SetPoint("BOTTOMRIGHT"); brule:SetHeight(2)
    banner.name = T.Text(banner, "xxl", "gold")
    banner.name:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", S.s6, S.s6 + S.s2)
    banner.sub = T.Text(banner, "sm", "text")
    banner.sub:SetPoint("TOPLEFT", banner.name, "BOTTOMLEFT", 0, -S.s1)
    banner.react = T.Text(banner, "xxl", "white")
    banner.react:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", -S.s6, S.s6 + S.s2)
    banner:SetScript("OnSizeChanged", function(self)
        if self.mapID then
            local top, bottom = T.BannerCrop(self.mapID, self:GetWidth(), self:GetHeight())
            self.art:SetTexCoord(0, 1, top, bottom)
        end
    end)
    local back = CreateFrame("Button", nil, banner, "UIPanelButtonTemplate")
    back:SetSize(150, 24)
    back:SetPoint("TOPRIGHT", -S.s4, -S.s3)
    back:SetText("Reputation")
    back:SetScript("OnClick", function() page:Back() end)
    d.banner, d.back = banner, back
    local dscroll = W.Scroll(d)
    dscroll:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", 0, -S.s3)
    dscroll:SetPoint("BOTTOMRIGHT", 0, S.s2)
    d.scroll = dscroll
    local dc = dscroll.child
    d.sum = newFactionRow(dc, true, false)
    d.reach = T.Text(dc, "sm", "text"); d.reach:SetJustifyH("LEFT"); d.reach:SetWordWrap(true)
    d.desc = T.Text(dc, "sm", "dim"); d.desc:SetJustifyH("LEFT"); d.desc:SetWordWrap(true)
    d.seesaw = CreateFrame("Frame", nil, dc)
    T.Solid(d.seesaw, "black", "BACKGROUND", 0.25):SetAllPoints()
    d.seesaw.edge = W.Edge(d.seesaw, "BORDER"); d.seesaw.edge:SetColor("cardEdge")
    d.seesaw.title = T.Text(d.seesaw, "sm", "repRival")
    d.seesaw.title:SetPoint("TOPLEFT", S.s3, -S.s2)
    d.seesaw.title:SetText("Rivals: raising one lowers the other")
    d.seesaw.rows = { newFactionRow(d.seesaw, true, false), newFactionRow(d.seesaw, true, false) }
    d.srcHead = W.Header(dc)
    d.foot = T.Text(dc, "xs", "dim"); d.foot:SetJustifyH("LEFT"); d.foot:SetWordWrap(true)
    d.foot:SetText("From QuestieDB's quest rewards: amounts are base values, so approximate (bonuses like the Human " ..
        "racial aren't in them). Killing and other ways to gain reputation aren't known to the addon.")
    d.empty = T.Text(dc, "md", "dim")
    d:Hide()
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

    local function arrange()
        head:ClearAllPoints(); list:ClearAllPoints(); d:ClearAllPoints()
        head:SetPoint("TOPLEFT"); head:SetPoint("TOPRIGHT")
        if page.wide then
            list:SetPoint("TOPLEFT", head, "BOTTOMLEFT"); list:SetPoint("BOTTOMLEFT")
            list:SetWidth(RT.splitList)
            d:SetPoint("TOPLEFT", list, "TOPRIGHT"); d:SetPoint("BOTTOMRIGHT")
        else
            list:SetPoint("TOPLEFT", head, "BOTTOMLEFT"); list:SetPoint("BOTTOMRIGHT")
            d:SetAllPoints()
        end
        list.edge:SetShown(page.wide)
        back:SetShown(not page.wide)
    end

    -- The toolbar and the strip from the list's summary.
    local function paintHead(data)
        local s = settings()
        local x = L.listInset
        for _, b in ipairs(page.filters) do
            b:SetLabel(b.item.title)
            b:SetOn(s.filter == b.value)
            b:ClearAllPoints(); b:SetPoint("LEFT", tb, "LEFT", x, 0)
            x = x + b:GetWidth() + S.s2
        end
        x = x + S.s2
        page.sortBtn:SetLabel("Sort: |cffffd100" .. SORT_LABEL[s.sort] .. "|r")
        page.sortBtn.item.detail = SORT_LABEL[s.sort] .. ". Y cycles it."
        page.sortBtn:ClearAllPoints(); page.sortBtn:SetPoint("LEFT", tb, "LEFT", x, 0)
        local sum = data and data.summary
        page.count:SetText(data and (#data.factions == data.total and (data.total .. " factions")
            or string.format("%d of %d factions", #data.factions, data.total)) or "")
        -- The strip: eight cells and the summary column.
        local w = width(strip) - 2 * S.s6 - RT.sum
        local cw = math.floor((w - 7 * RT.cellGap) / 8)
        local ch = RT.strip - 2 * S.s2
        for r = 1, 8 do
            local c = page.cells[r]
            paintCell(c, sum and sum.byReaction[r] or 0, cw, ch)
            c:ClearAllPoints()
            c:SetPoint("LEFT", strip, "LEFT", S.s6 + (r - 1) * (cw + RT.cellGap), 0)
        end
        page.sumMet:ClearAllPoints(); page.sumEx:ClearAllPoints()
        page.sumMet:SetPoint("BOTTOMLEFT", strip, "LEFT", S.s6 + 8 * cw + 7 * RT.cellGap + S.s4, 1)
        page.sumEx:SetPoint("TOPLEFT", page.sumMet, "BOTTOMLEFT", 0, -2)
        local gold = "|cffffd100%d|r"
        page.sumMet:SetText(sum and string.format("Met " .. gold .. " of %d", sum.met, sum.total) or "")
        page.sumEx:SetText(sum and string.format("Exalted " .. gold .. " of %d", sum.exalted, sum.total) or "")
    end

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

    -- Fills the faction page for f. Returns its focus rows (the places to raise it).
    local function fillDetail(f)
        local rows = {}
        for _, r in ipairs(page.srcRows) do r:Hide() end
        page.used = page.used or {}
        page.used.srcRows = 0
        d.sum:Hide(); d.reach:Hide(); d.desc:Hide(); d.seesaw:Hide(); d.srcHead:Hide(); d.foot:Hide(); d.empty:Hide()
        if not f then
            banner.name:SetText(""); banner.sub:SetText(""); banner.react:SetText("")
            banner.art:Hide(); banner.plain:Show()
            d.empty:ClearAllPoints(); d.empty:SetPoint("TOP", dc, "TOP", 0, -60)
            d.empty:SetText("Select a faction"); d.empty:Show()
            dc:SetHeight(120)
            return rows
        end
        local art = f.artMap and T.ZoneArt(f.artMap)
        banner.mapID = art and f.artMap or nil
        banner.art:SetShown(art ~= nil); banner.plain:SetShown(art == nil)
        if art then
            banner.art:SetTexture(art)
            local top, bottom = T.BannerCrop(f.artMap, banner:GetWidth(), banner:GetHeight())
            banner.art:SetTexCoord(0, 1, top, bottom)
        end
        banner.name:SetText(f.name or "")
        local sub = T.repGroups[f.group] or ""
        if f.main and f.main.kind == "zone" then sub = sub .. "  ·  Raised most in " .. placeName(f.main) end
        banner.sub:SetText(sub)
        local c = T.reaction.text[f.reaction] or T.color.text
        banner.react:SetText(T.ReactionLabel(f.reaction))
        banner.react:SetTextColor(c[1], c[2], c[3])

        local w = width(dscroll, page.wide and (width(page) - RT.splitList) or nil)
        local inner = w - L.listInset - S.s6
        local x = L.listInset
        local y = 0
        local cols = page.wide and RT.pageSumWide or RT.pageSum
        local num = ""
        if not f.maxed and f.into and f.span then
            num = N(f.into) .. " / " .. N(f.span)
            if f.left and nextLabel(f) then num = num .. "  ·  " .. N(f.left) .. " to " .. nextLabel(f) end
        end
        d.sum:SetPoint("TOPLEFT", dc, "TOPLEFT", x, -y)
        d.sum:SetWidth(inner)
        local h = paintFactionRow(d.sum, f, inner, cols, { name = "Your standing", tags = tags(f), num = num,
            reach = f.reach, big = true })
        d.sum:Show()
        y = y + h + S.s2
        local rt = reachText(f, page.data and page.data.reason)
        if rt then
            d.reach:SetPoint("TOPLEFT", dc, "TOPLEFT", x + S.s3, -y)
            d.reach:SetWidth(inner - 2 * S.s3)
            d.reach:SetText(rt)
            d.reach:Show()
            y = y + math.ceil(d.reach:GetStringHeight() or 14) + S.s3
        end
        if f.description then
            d.desc:SetPoint("TOPLEFT", dc, "TOPLEFT", x + S.s3, -y)
            d.desc:SetWidth(inner - 2 * S.s3)
            d.desc:SetText(f.description)
            d.desc:Show()
            y = y + math.ceil(d.desc:GetStringHeight() or 14) + S.s4
        end
        local rival = f.rivals and f.rivals[1] and ns.Reputation.Get(f.rivals[1].factionID)
        if rival then
            local ss = d.seesaw
            ss:SetPoint("TOPLEFT", dc, "TOPLEFT", x, -y)
            ss:SetWidth(inner)
            local sy = S.s2 + T.size.sm + S.s2
            local mini = { react = cols.react, ladder = cols.ladder, num = 0, colGap = cols.colGap, row = RT.seesawRow }
            for i, fac in ipairs({ f, rival }) do
                local r = ss.rows[i]
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", ss, "TOPLEFT", S.s2, -sy)
                r:SetWidth(inner - 2 * S.s2)
                sy = sy + paintFactionRow(r, fac, inner - 2 * S.s2, mini, { tags = fac.met == false and T.Hex("dim", T.repTags.unmet) or "", noNum = true }) + 4
            end
            ss:SetHeight(sy + S.s1)
            ss:Show()
            y = y + sy + S.s1 + S.s4
        end
        local srcs = f.sources or {}
        if #srcs > 0 then
            d.srcHead:SetPoint("TOPLEFT", dc, "TOPLEFT", x, -y)
            d.srcHead:SetPoint("RIGHT", dc, "RIGHT", -S.s6, 0)
            d.srcHead.text:SetText("Where to raise it")
            d.srcHead.count:SetText(#srcs == 1 and "1 place" or (#srcs .. " places"))
            d.srcHead:Show()
            y = y + L.listHeader + S.s2
            for _, s in ipairs(srcs) do
                local r = take("srcRows", newSourceRow, dc)
                r:SetPoint("TOPLEFT", dc, "TOPLEFT", x, -y)
                r:SetWidth(inner)
                local notYou = s.forYou == false
                paintThumb(r.thumb, s.kind == "zone" and s.key or nil, s.kind, notYou)
                r.thumb:SetAlpha(notYou and 0.45 or 1)
                r.name:SetText(placeName(s))
                r.name:SetTextColor(T.RGB(notYou and "repFaint" or "white"))
                r.kind:SetText((T.repKinds[s.kind] or "") .. (notYou and "  ·  not for you" or "")
                    .. (s.kind == "zone" and s.zoneFaction and "  ·  zone faction" or ""))
                r.q:SetText(s.count == 1 and "1 quest" or (s.count .. " quests"))
                r.amt:SetText(s.oneTime > 0 and ("~+" .. N(s.amount)) or "")
                local mapID, fid = s.key, f.factionID
                local item = { key = "s:" .. s.kind .. ":" .. tostring(s.key), frame = r, title = placeName(s),
                    detail = sourceInfo(f, s), scroll = dscroll, topGap = L.listHeader + S.s2 }
                if s.kind == "zone" and not notYou then
                    item.actionLabel = "Open"
                    item.onActivate = function() page:OpenZone(mapID, fid) end
                end
                r.item = item
                rows[#rows + 1] = { items = { item }, section = 1 }
                y = y + RT.srcRow + RT.rowGap
            end
            y = y + S.s3
        end
        d.foot:SetPoint("TOPLEFT", dc, "TOPLEFT", x + S.s3, -y)
        d.foot:SetWidth(inner - 2 * S.s3)
        d.foot:Show()
        y = y + math.ceil(d.foot:GetStringHeight() or 24) + S.s4
        dc:SetHeight(math.max(1, y))
        return rows
    end

    -- Redraws everything from ns.Reputation.List. Keeps focus on the same key.
    function page:Redraw()
        local s = settings()
        local data = ns.Reputation.List(s.filter, s.sort)
        self.data = data
        self.used = { rows = 0, headers = 0, srcRows = self.used and self.used.srcRows or 0 }
        for _, r in ipairs(self.rows) do r:Hide() end
        for _, h in ipairs(self.headers) do h:Hide() end
        paintHead(data)
        local child = scroll.child
        local wList = width(scroll, self.wide and RT.splitList or nil)
        local inner = wList - L.listInset - S.s6
        local cols = self.wide and RT.wideCols or RT.cols
        local thumb = self.wide and RT.thumbWide or RT.thumb
        local closest = s.sort == "closest"
        local rows, byID, headerYs = { toolbarRow() }, {}, {}
        local y = 0
        local groups
        if data then
            groups = data.groups or { { key = s.sort, items = data.factions, met = 0, total = #data.factions } }
        end
        local empty = not data or #data.factions == 0
        self.emptyTitle:SetShown(empty); self.emptyText:SetShown(empty)
        if not data then
            self.emptyTitle:SetText("Reading factions")
            self.emptyText:SetText("Azerfolio reads them once QuestieDB's quests are in.")
        elseif #data.factions == 0 then
            self.emptyTitle:SetText("No factions here")
            self.emptyText:SetText("Try another filter.")
        end
        for gi, g in ipairs(groups or {}) do
            if #g.items > 0 then
                if gi > 1 then y = y + S.s3 end
                local h = take("headers", W.Header, child)
                h:SetPoint("TOPLEFT", child, "TOPLEFT", L.listInset, -y)
                h:SetPoint("TOPRIGHT", child, "TOPRIGHT", -S.s6, -y)
                local title = data.groups and (T.repGroups[g.key] or g.key)
                    or (closest and "Closest to the next reaction" or "A-Z")
                local count = data.groups and string.format("%d of %d met", g.met, g.total) or tostring(g.total)
                h.text:SetText(title); h.count:SetText(count)
                headerYs[#headerYs + 1] = { y = y, text = title, count = count }
                y = y + L.listHeader + S.s2
                for _, f in ipairs(g.items) do
                    local r = take("rows", function(p) return newFactionRow(p, false, true) end, child)
                    r:SetPoint("TOPLEFT", child, "TOPLEFT", L.listInset, -y)
                    r:SetWidth(inner)
                    local rh = paintFactionRow(r, f, inner, cols, { tags = tags(f, self.wide), num = numText(f, closest), thumb = thumb })
                    local id = f.factionID
                    r.item = { key = "f:" .. id, frame = r, title = f.name, detail = infoLine(f), scroll = scroll,
                        topGap = L.listHeader + S.s1 + S.s2, faction = f,
                        actionLabel = self.wide and "Details" or "Open",
                        onActivate = function() page:OpenFaction(id) end,
                        canActivate = function() return not page.wide or (page.detailRows ~= nil and #page.detailRows > 0) end }
                    r.onClick = function() page:ClickFaction(id) end
                    rows[#rows + 1] = { items = { r.item }, section = gi }
                    byID[id] = r
                    y = y + rh + RT.rowGap
                end
            end
        end
        child:SetHeight(math.max(1, y))
        self.focusRows, self.byID, self.headerYs = rows, byID, headerYs
        self.sectionCount = groups and #groups or 0
        -- The faction page: the one shown, if it's still there (a filter may hide it in the list,
        -- but its page stays while you're on it).
        if self.selID then
            local f = ns.Reputation.Get(self.selID)
            if not f then self.selID = nil end
        end
        if self.wide and self.mode == "list" then
            local keep = self.selID and byID[self.selID] and self.selID
            local first = data and data.factions[1] and data.factions[1].factionID
            self.selID = keep or first
        end
        self.detailRows = fillDetail(self.selID and ns.Reputation.Get(self.selID) or nil)
        for id, r in pairs(byID) do r:SetSelected(self.wide and id == self.selID) end
        self:Refresh()
        updateSticky()
    end

    -- Shows the right frames for the mode, then rebuilds focus and hints.
    function page:Refresh()
        local inDetail = self.mode == "detail"
        head:SetShown(self.wide or not inDetail)
        list:SetShown(self.wide or not inDetail)
        d:SetShown(inDetail or (self.wide and true or false))
        if inDetail and not self.wide then sticky:Hide() end
        self.hasSections = not inDetail and (self.sectionCount or 0) > 1
        self.sectionLabel = "Section"
        self.backLabel = inDetail and "Reputation" or nil
        ns.Focus.Rebuild()
        ns.UI.RefreshHints()
    end

    -- A on a faction: its page (narrow), or into it (wide).
    function page:OpenFaction(id)
        self.selID = id
        self.mode = "detail"
        self.detailRows = fillDetail(ns.Reputation.Get(id))
        local first = self.detailRows[1] and self.detailRows[1].items[1]
        if self.wide and not first then self.mode = "list"; self.pendingFocusKey = "f:" .. id
        else self.pendingFocusKey = first and first.key end
        dscroll:SetVerticalScroll(0)
        for fid, r in pairs(self.byID or {}) do r:SetSelected(self.wide and fid == id) end
        self:Refresh()
    end

    -- A click: in the split view it selects the faction and keeps focus in the list.
    function page:ClickFaction(id)
        if not self.wide then return self:OpenFaction(id) end
        self.mode = "list"
        self.selID = id
        self.pendingFocusKey = "f:" .. id
        self:Redraw()
    end

    -- A on a zone in Where to raise it: that zone's faction page on the Zones tab; B returns.
    function page:OpenZone(mapID, factionID)
        ns.UI.SelectTab("zones")
        local frame = ns.UI.GetFrame()
        local zp = frame and frame.pages.zones
        if not (zp and zp.ShowZoneRep and zp:ShowZoneRep(mapID, factionID, "reputation")) then
            ns.UI.SelectTab("reputation")
        end
    end

    -- Split view: the page follows the focused faction.
    function page:OnFocusChanged(item)
        if self.wide and self.mode == "list" and item and item.faction and item.faction.factionID ~= self.selID then
            self.selID = item.faction.factionID
            self.detailRows = fillDetail(item.faction)
            dscroll:SetVerticalScroll(0)
            for id, r in pairs(self.byID or {}) do r:SetSelected(id == self.selID) end
        end
    end

    function page:CycleSort()
        settings().sort = ns.ReputationRules.NextSort(settings().sort)
        self.pendingFocusKey = "tb:sort"
        local cur = ns.Focus.Current()
        if cur and cur.faction then self.pendingFocusKey = cur.key end
        self:Redraw()
        return true
    end

    -- The faction X acts on: the focused row's, or the shown page's.
    local function target()
        if page.mode == "detail" then return page.selID and ns.Reputation.Get(page.selID) end
        local item = ns.Focus.Current()
        return item and item.faction and ns.Reputation.Get(item.faction.factionID)
    end

    function page:ToggleWatch()
        local f = target()
        if not (f and ns.Reputation.CanWatch(f)) then return false end
        local on = not f.watched
        local ok = ns.Reputation.SetWatched(f.factionID, on)
        if ok then
            ns.UI.SetInfo(f.name, on and "Watching it on the experience bar." or "No longer watched.")
        else
            ns.UI.SetInfo(f.name, "The game didn't let Azerfolio change the watched faction.")
        end
        return true
    end

    function page:OnButton(name)
        if name == "x" then return self:ToggleWatch() end
        if name == "y" and self.mode == "list" then return self:CycleSort() end
        return false
    end

    function page:GetHints()
        local hints = {}
        local f = target()
        if f and ns.Reputation.CanWatch(f) then hints[#hints + 1] = { "X", f.watched and "Stop watching" or "Watch" } end
        if self.mode == "list" then hints[#hints + 1] = { "Y", "Sort" } end
        return hints
    end

    function page:GetFocusRows()
        if self.mode == "detail" then return self.detailRows or {} end
        return self.focusRows or {}
    end

    -- B: from the page back to the list, on the same faction.
    function page:Back()
        if self.mode ~= "detail" then return false end
        self.mode = "list"
        self.pendingFocusKey = self.selID and ("f:" .. self.selID)
        self:Refresh()
        return true
    end

    function page:Layout()
        local wide = ns.UI.IsWide()
        if wide == self.wide then
            if self:IsShown() then paintHead(self.data) end
            return
        end
        self.wide = wide
        arrange()
        self:Redraw()
    end

    -- Standing, quests or sources changed: redraw, keeping focus.
    for _, msg in ipairs({ "AZF_REPUTATION_UPDATED", "AZF_QUESTS_UPDATED" }) do
        ns.Events.On(msg, function()
            if not page:IsShown() then page.dirty = true; return end
            local cur = ns.UI.CurrentTab() == "reputation" and ns.Focus.Current()
            if cur and page.pendingFocusKey == nil then page.pendingFocusKey = cur.key end
            page:Redraw()
        end)
    end
    page:SetScript("OnShow", function(self)
        if self.dirty then self.dirty = false; self:Redraw() end
    end)

    page:Layout()
    if page.pendingFocusKey == nil and page.data and page.data.factions[1] then
        page.pendingFocusKey = "f:" .. page.data.factions[1].factionID
    end
    return page
end

ns.UI.RegisterTab({
    id = "reputation",
    label = "Reputation",
    icon = ns.Theme.Icon("reputation", "Interface\\Icons\\INV_Misc_Note_02"),
    order = 3,
    compactHeader = true,
    info = "Every faction: your standing and where to raise it.",
    build = build,
})
