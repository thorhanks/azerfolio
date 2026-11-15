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
--   * Road (task 6): every instance in level order on the adventurer's road (see paintRoad).
-- The instance page (task 5; rounds 3-6, docs/reviews/2026-11-15-dungeon-page-review.md option A;
-- the mockup's renderDungeonInto): A opens it (wide List: it sits beside the list, A moves in).
--   * the banner: painting, name (the place for wings), blurb, meta, tags, the wing tabs of Scarlet
--     Monastery and Dire Maul (red panel buttons, the selected one pressed in), the quest score
--     and the gold quests seal once every quest is done;
--   * the body: the painting blurred and dimmed behind it; the view switch (Y): Overview ·
--     Bosses & loot · Quests, kept between instances;
--   * Overview: Before you go (level fit, keys, pickups by place: at most 5, 4 with keys, then
--     "+n More places"; A opens Quests there), The run (numbered painted seals; A opens Bosses &
--     loot on that boss), Rewards (the quest bar, up to 4 factions; A opens Reputation);
--   * Bosses & loot: the compact boss list | the focused boss's loot tiles (For you / All), each
--     scrolling; the game's item tooltip on focus; "Kills aren't counted";
--   * Quests: To do / Done / All, grouped by where you pick them up, in chain order;
--   * X: the world map at the entrance zone. Item details and bag counts repaint the page.
-- Honest data: progress is quests only (DungeonRules.Progress); while the client doesn't say
-- which quests are done (Dungeons.CompletionKnown() false) done is unknown, shown as "?", never 0.
-- Everything shown comes from ns.Dungeons / ns.DungeonRules; this file words and draws it.
local _, ns = ...

local FILTERS = { { "all", "All" }, { "foryou", "For your level" }, { "dungeon", "Dungeons" }, { "raid", "Raids" },
    { "forever", "New in Forever" } }
local FILTER_INFO = { all = "Every dungeon and raid.", foryou = "Instances whose level range suits yours (the zone guide's rule).",
    dungeon = "Only dungeons.", raid = "Only raids.", forever = "The nine dungeons new in Forever." }
-- The views Y cycles: Cards · List · Road (task 6).
local VIEWS = { { "cards", "Cards" }, { "list", "List" }, { "road", "Road" } }
-- B's label when an instance was opened from another tab (task 7).
local RETURN_LABEL = { zones = "Zone", reputation = "Reputation" }

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

-- The view shown for a saved view (Cards for anything else).
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

-- Zone Detail (task 7; DESIGN round 2 "Zone Detail's dungeon tile"): the header plate over the
-- zone's instances: "Dungeon here", "Raid here" or "n dungeons here". Takes instances or entries.
function Words.Here(list)
    local n = #(list or {})
    if n == 0 then return nil end
    if n > 1 then return n .. " dungeons here" end
    local inst = list[1].inst or list[1]
    return inst.kind == "raid" and "Raid here" or "Dungeon here"
end

-- A Zone Detail tile's line: "Lv 15-23  ·  8 bosses  ·  New in Forever"; `drop` 1 leaves out
-- "New in Forever" (its tag is the catalogue's), for a narrow tile.
function Words.TileMeta(inst, drop)
    local n = #(inst.bosses or {})
    local s = Words.Levels(inst) .. "  ·  " .. n .. " " .. plural(n, "boss", "bosses")
    if inst.forever and (drop or 0) < 1 then s = s .. "  ·  New in Forever" end
    return s
end

-- The adventurer's road (task 6; DESIGN rounds 2-8; the mockup's dunTrail) -----------------------
-- Pure: positions in the design's units (the mockup's px; the page scales the strip to fit).

local Road = {}

-- The road's order: dungeons by level range, then raids; ties keep data order.
function Road.Order(entries)
    local tmp = {}
    for i, e in ipairs(entries or {}) do tmp[i] = { e = e, i = i } end
    table.sort(tmp, function(a, b)
        local ia, ib = a.e.inst, b.e.inst
        local ra, rb = ia.kind == "raid", ib.kind == "raid"
        if ra ~= rb then return rb end
        if ia.levels[1] ~= ib.levels[1] then return ia.levels[1] < ib.levels[1] end
        if ia.levels[2] ~= ib.levels[2] then return ia.levels[2] < ib.levels[2] end
        return a.i < b.i
    end)
    local out = {}
    for i, x in ipairs(tmp) do out[i] = x.e end
    return out
end

-- The painted region behind an instance (round 6): 1-5 by the first level's bracket, 6 the raids.
function Road.Region(inst)
    if inst.kind == "raid" then return 6 end
    local l = inst.levels[1]
    if l < 20 then return 1 elseif l < 30 then return 2 elseif l < 40 then return 3 elseif l < 50 then return 4 end
    return 5
end

-- A bracket sign's words: "Levels 13-19", "Raids · level 60".
function Road.Sign(inst)
    if inst.kind == "raid" then return "Raids · level 60" end
    local b = ns.DungeonRules and ns.DungeonRules.Bracket(inst)
    return "Levels " .. ((b and b.key) or tostring(inst.levels[1]))
end

-- The road laid out (the mockup's dunTrail). o: { H, level, step, pad, fade, top, bottom, zig,
-- signMin, tex = { w, h }, flat (the road's height share without painted lanes), art = {
-- road1 = true, ... }, lanes = { road1 = { ... } } }. Returns { W, regions = { x0, w, core0,
-- core1, key }, painted, roadY(x), pts = { x, roadY, y, above }, youX, youY, signs = { x, text,
-- raid }, stones = { x, y, level }, citadel (x where the raids begin, or nil) }.
function Road.Layout(items, o)
    local n = #items
    local H, step, pad = o.H, o.step, o.pad
    local W = pad * 2 + step * math.max(0, n - 1)
    local out = { W = W, regions = {}, pts = {}, signs = {}, stones = {} }
    -- One region per bracket, behind its stretch of road, cross-faded into the next.
    local start = 1
    for i, e in ipairs(items) do
        local r = Road.Region(e.inst)
        local nxt = items[i + 1]
        if not nxt or Road.Region(nxt.inst) ~= r then
            local x0 = start == 1 and 0 or (pad + (start - 1) * step - step / 2)
            local x1 = nxt and (pad + (i - 1) * step + step / 2) or W
            local key = "road" .. r
            if o.art and o.art[key] then
                out.regions[#out.regions + 1] = { x0 = x0 - o.fade / 2, w = x1 - x0 + o.fade, core0 = x0, core1 = x1, key = key,
                    lane = o.lanes and o.lanes[key] }
            end
            start = i + 1
        end
    end
    local painted = #out.regions > 0
    for _, r in ipairs(out.regions) do if type(r.lane) ~= "table" or #r.lane < 2 then painted = false end end
    out.painted = painted
    local tw, th = o.tex[1], o.tex[2]
    -- Round 7: the painted road's height at x through the region's cover crop.
    local function laneIn(r, x)
        local s = math.max(r.w / tw, H / th)
        local offX, offY = (r.w - tw * s) / 2, (H - th * s) / 2
        local u = math.max(0, math.min(1, (x - r.x0 - offX) / (tw * s)))
        local L = r.lane
        local f = u * (#L - 1)
        local i = math.floor(f)
        local t = f - i
        local a, b = L[i + 1], L[math.min(#L, i + 2)]
        return offY + (a * (1 - t) + b * t) * th * s
    end
    local flat = H * (o.flat or 0.556)
    local function roadY(x)
        if not painted then return flat end
        local here, near, nd = {}, nil, nil
        for _, r in ipairs(out.regions) do
            if x >= r.x0 and x <= r.x0 + r.w then here[#here + 1] = r end
            local d = math.min(math.abs(x - r.x0), math.abs(x - r.x0 - r.w))
            if not nd or d < nd then near, nd = r, d end
        end
        if #here == 0 then return laneIn(near, x) end
        if #here == 1 then return laneIn(here[1], x) end
        local a, b = here[1], here[2]
        local t = math.max(0, math.min(1, (x - b.x0) / math.max(1, a.x0 + a.w - b.x0)))
        return laneIn(a, x) * (1 - t) + laneIn(b, x) * t
    end
    out.roadY = roadY
    -- Medallions zigzag above and below the road, kept clear of the signs and the bottom (round 8).
    for i = 1, n do
        local x = pad + (i - 1) * step
        local ry = roadY(x)
        local above = i % 2 == 1
        out.pts[i] = { x = x, roadY = ry, above = above,
            y = math.max(o.top, math.min(H - o.bottom, ry + (above and -o.zig or o.zig))) }
    end
    -- You: on the road past the last dungeon whose range starts at or below your level.
    local yi = 0
    for i, e in ipairs(items) do
        if e.inst.kind ~= "raid" and e.inst.levels[1] <= o.level then yi = i end
    end
    out.youIndex = yi
    if n == 0 or yi == 0 then out.youX = pad - 70
    elseif yi >= n then out.youX = out.pts[yi].x + 70
    else out.youX = (out.pts[yi].x + out.pts[yi + 1].x) / 2 end
    out.youY = roadY(out.youX)
    -- Bracket signs (the first far enough in that its plate isn't cut, round 7) and level stones
    -- where a new starting level begins.
    local lastSign, lastL
    for i, e in ipairs(items) do
        local text = Road.Sign(e.inst)
        if text ~= lastSign then
            out.signs[#out.signs + 1] = { x = math.max(o.signMin, pad + (i - 1) * step - step / 2), text = text,
                raid = e.inst.kind == "raid" }
            lastSign = text
        end
        if e.inst.kind ~= "raid" and e.inst.levels[1] ~= lastL then
            out.stones[#out.stones + 1] = { x = out.pts[i].x, y = out.pts[i].roadY, level = e.inst.levels[1] }
            lastL = e.inst.levels[1]
        end
        if e.inst.kind == "raid" and not out.citadel and i > 1 then out.citadel = pad + (i - 1) * step - step / 2 end
    end
    return out
end

-- Where the road opens: the your-level instance nearest You (the latest that suits you and
-- starts at or below your level, else the first that suits you), else the one beside You, else
-- the first. Returns an index (nil when the road is empty).
function Road.Start(items, level)
    local best, first, beside
    for i, e in ipairs(items) do
        if e.fit then
            first = first or i
            if e.inst.levels[1] <= level then best = i end
        end
        if e.inst.kind ~= "raid" and e.inst.levels[1] <= level then beside = i end
    end
    if #items == 0 then return nil end
    return best or first or beside or 1
end

-- The horizontal scroll that keeps x (a medallion's centre, px) at least `margin` inside a
-- `view` px window onto a `total` px road; the current scroll when it already is.
function Road.Scroll(x, cur, view, total, margin)
    local max = math.max(0, total - view)
    margin = math.min(margin, view / 2)
    local new = cur
    if x < cur + margin then new = x - margin
    elseif x > cur + view - margin then new = x - view + margin end
    return math.max(0, math.min(max, new))
end

-- The preview card's meta line: "Dungeon · 5 players · Westfall · Lv 15-23". `drop` 1 shortens
-- the kind ("Dungeon", "Raid · 40"), 2 leaves out the zone too.
function Road.Meta(inst, where, drop)
    drop = drop or 0
    local parts = {}
    if drop >= 1 then parts[1] = Words.Kind(inst)
    elseif inst.kind == "raid" then parts[1] = "Raid · " .. tostring(inst.size) .. " players"
    else parts[1] = "Dungeon · " .. tostring(inst.size or 5) .. " players" end
    if drop < 2 and where and where ~= "" then parts[#parts + 1] = where end
    parts[#parts + 1] = Words.Levels(inst)
    return table.concat(parts, "  ·  ")
end

-- The preview's boss chips: the non-rare bosses' names; `fits(name)` says whether the next chip
-- fits. Returns the names shown and the number of bosses not shown ("+n more", rares included),
-- at most `max` chips.
function Road.Chips(bosses, max, fits)
    local names, full = {}, false
    for _, b in ipairs(bosses or {}) do
        if not b.rare and not full then
            if #names < max and (not fits or fits(b.name, #names + 1)) then names[#names + 1] = b.name
            else full = true end
        end
    end
    return names, #(bosses or {}) - #names
end

-- "27 items in its loot" (nil before the build says).
function Road.LootWords(n)
    if type(n) ~= "number" then return nil end
    return string.format("%d %s in its loot", n, plural(n, "item"))
end

Words.Road = Road

-- The instance page (task 5) ------------------------------------------------------------------

local READY = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t"
Words.READY = READY

-- The page's views, Y cycles them (round 5): kept between instances.
local PAGE_VIEWS = { { "overview", "Overview" }, { "bosses", "Bosses & loot" }, { "quests", "Quests" } }
Words.PAGE_VIEWS = PAGE_VIEWS
local PAGE_VIEW_INFO = { overview = "Before you go, the run and the rewards.", bosses = "Every boss and what it drops, for you or all.",
    quests = "Every quest, by where you pick it up." }
Words.PAGE_VIEW_INFO = PAGE_VIEW_INFO

function Words.PageView(v)
    for _, x in ipairs(PAGE_VIEWS) do if x[1] == v then return v end end
    return "overview"
end

function Words.NextPageView(v)
    v = Words.PageView(v)
    for i, x in ipairs(PAGE_VIEWS) do if x[1] == v then return PAGE_VIEWS[i % #PAGE_VIEWS + 1][1] end end
    return "overview"
end

-- The wing tabs of a place whose instances are its wings ("Scarlet Monastery: Library"): { { inst,
-- label = "Library" }, ... } in data order; nil for an instance that isn't one of several wings
-- (Lower and Upper Blackrock Spire share a group but are two instances, not wings: plan task 5).
function Words.WingTabs(inst, data)
    if not inst.group then return nil end
    local prefix = inst.group .. ": "
    local out = {}
    for _, w in ipairs(ns.DungeonRules.Wings(inst, data)) do
        if w.name:sub(1, #prefix) ~= prefix then return nil end
        out[#out + 1] = { inst = w, label = w.name:sub(#prefix + 1) }
    end
    return #out > 1 and out or nil
end

-- Your level against the range (round 5): "5 levels to go", "Right for your level", "Below you now".
function Words.Fit(levels, level)
    if type(level) ~= "number" then return "" end
    local s, n = ns.DungeonRules.FitState(levels, level)
    if s == "togo" then return string.format("%d %s to go", n, plural(n, "level")) end
    if s == "below" then return "Below you now" end
    return "Right for your level"
end

-- An item's type for its tile (mockup itemType): weapons by subclass, armour by type, jewellery
-- and cloaks by slot once the client knows it.
local WEAPON_SUB = { [0] = "Axe", "Two-Hand Axe", "Bow", "Gun", "Mace", "Two-Hand Mace", "Polearm", "Sword", "Two-Hand Sword",
    [10] = "Staff", [13] = "Fist Weapon", [15] = "Dagger", [16] = "Thrown", [18] = "Crossbow", [19] = "Wand", [20] = "Fishing Pole" }
local ARMOR_SUB = { [0] = "Jewellery or cloak", "Cloth", "Leather", "Mail", "Plate", [6] = "Shield", [7] = "Libram", [8] = "Idol", [9] = "Totem" }
local SLOT = { INVTYPE_FINGER = "Ring", INVTYPE_NECK = "Neck", INVTYPE_TRINKET = "Trinket", INVTYPE_CLOAK = "Cloak",
    INVTYPE_HOLDABLE = "Held in off-hand" }
function Words.ItemType(it)
    if type(it) ~= "table" then return "Item" end
    if it.class == 2 then return WEAPON_SUB[it.subclass] or "Weapon" end
    if it.class == 4 then return (it.equipLoc and SLOT[it.equipLoc]) or ARMOR_SUB[it.subclass] or "Armour" end
    return "Item"
end

-- Where a group of quests starts (DungeonRules.Place / QuestGroups): the zone's name, "Inside
-- <instance>", "Starts from an item", "Starts at an object", the client's name for an area
-- Azerfolio doesn't map, else "Elsewhere". nameOf(mapID), areaName(areaID) -> name | nil.
function Words.PlaceName(g, inst, nameOf, areaName)
    local k = g.kind
    if k == "zone" then return (nameOf and nameOf(g.mapID)) or "Elsewhere" end
    if k == "inside" then return "Inside " .. (inst.group or inst.name) end
    if k == "instance" then return "Inside " .. (g.instance.group or g.instance.name) end
    if k == "item" then return "Starts from an item" end
    if k == "object" then return "Starts at an object" end
    if k == "area" then return (areaName and areaName(g.area)) or "Elsewhere" end
    return "Where they start isn't known"
end

-- How many of a place's quests need an earlier quest (QuestieDB's prerequisites).
local function needEarlier(g)
    local n = 0
    for _, v in ipairs(g.quests) do if #(v.pre or {}) > 0 then n = n + 1 end end
    return n
end

-- A pickup row's second line: up to three givers (else up to two quest names), then "n need an
-- earlier quest".
-- `max` (default 3) givers: the page lowers it until the line fits rather than cutting it.
function Words.PickupWho(g, max)
    local who = {}
    for i = 1, math.min(max or 3, #(g.givers or {})) do who[i] = g.givers[i] end
    if #who == 0 then
        for i = 1, math.min(math.min(max or 2, 2), #g.quests) do who[i] = g.quests[i].quest.name or "?" end
    end
    local s = table.concat(who, ", ")
    local n = needEarlier(g)
    if n > 0 then
        s = s .. (s ~= "" and "  ·  " or "") .. string.format("%d %s an earlier quest", n, n == 1 and "needs" or "need")
    end
    return s
end

-- The run's count: "8 bosses · 27 items · 16 for you" (items nil before QuestieDB is read).
function Words.RunCount(bosses, items, forYou)
    local s = string.format("%d %s", bosses, plural(bosses, "boss", "bosses"))
    if items then s = s .. string.format("  ·  %d %s  ·  %d for you", items, plural(items, "item"), forYou or 0) end
    return s
end

-- The loot header's count: "3 items · 2 for you · 1 in your bags" (owned now, not a completion).
function Words.LootCount(n, forYou, have)
    if n == 0 then return "" end
    local s = string.format("%d %s  ·  %d for you", n, plural(n, "item"), forYou)
    if have and have > 0 then s = s .. string.format("  ·  %d in your bags", have) end
    return s
end

-- A key's tag: text, style ("have" | "req" | "plain"). count nil = the client didn't say.
function Words.KeyTag(k, count)
    if type(count) == "number" and count > 0 then return READY .. " Have", "have" end
    if k.need == "required" then return "Required", "req" end
    return "Optional", "plain"
end

-- A boss's tags: Rare, Optional, "One of: Ring of Law".
function Words.BossTags(b)
    local out = {}
    if b.rare then out[#out + 1] = { text = "Rare", style = "rare" } end
    if b.optional then out[#out + 1] = { text = "Optional", style = "plain" } end
    if b.oneOf then out[#out + 1] = { text = "One of: " .. b.oneOf, style = "plain" } end
    return out
end

-- The seal a boss wears: "boss-seal-rare" (rares), "boss-seal-opt" (optional and one-of), else "boss-seal".
function Words.SealKind(b)
    if b.optional or b.oneOf then return "boss-seal-opt" end
    if b.rare then return "boss-seal-rare" end
    return "boss-seal"
end

-- A quest row's state: "ready", "red", "from 14", or the ready check when done.
function Words.QuestState(v)
    if v.state == "done" then return READY end
    if v.state == "later" then return "from " .. tostring(v.quest.reqLevel) end
    return v.state
end

-- The earlier quests a quest needs, by name: a chain that reuses its name says "the earlier
-- step"; a quest whose name isn't known, "an earlier quest" (once). nameOf(questID) -> name | nil.
function Words.PreNames(v, nameOf)
    local out, seen = {}, {}
    for _, id in ipairs(v.pre or {}) do
        local n = nameOf and nameOf(id)
        if n == v.quest.name then n = "the earlier step" end
        n = n or "an earlier quest"
        if not seen[n] then seen[n] = true; out[#out + 1] = n end
    end
    return out
end

-- "More places": names, as many as `max` (default all), then "and n more".
function Words.MorePlaces(names, max)
    max = max or #names
    if #names <= max then return table.concat(names, ", ") end
    local out = {}
    for i = 1, max do out[i] = names[i] end
    return (max > 0 and (table.concat(out, ", ") .. " and ") or "") .. string.format("%d more", #names - max)
end

-- A quest row's second line: "from Gryan Stoutmantle · needs Red Silk Bandanas · turn in to
-- Wilder Thistlenettle, Stormwind City". placeName(place) -> its words. The turn-in's place is
-- said only for a place you travel to (not "Starts at an object"), "inside" in lower case.
-- `drop` 1 leaves out the turn-in's place, 2 the turn-in, for a line too narrow for all of it.
function Words.QuestMeta(v, nameOf, placeName, drop)
    drop = drop or 0
    local parts = {}
    local g = v.quest.giver
    if type(g) == "table" and g.name then parts[#parts + 1] = "from " .. g.name end
    local pre = Words.PreNames(v, nameOf)
    if #pre > 0 then parts[#parts + 1] = "needs " .. table.concat(pre, ", ") end
    local t = v.quest.turnin
    if drop < 2 and v.turnin and type(t) == "table" and t.name then
        local s = "turn in to " .. t.name
        local k = v.turnin.kind
        if drop < 1 and v.turninPlace and placeName and k ~= "object" and k ~= "item" and k ~= "unknown" then
            local pn = placeName(v.turnin)
            if k == "inside" or k == "instance" then pn = pn:gsub("^Inside", "inside") end
            s = s .. ", " .. pn
        end
        parts[#parts + 1] = s
    end
    return table.concat(parts, "  ·  ")
end

-- The Quests view's filters: { value, label with its count } (counts nil while the game doesn't
-- say which quests are done: only All is offered then).
function Words.QuestFilters(p, known)
    if not known then return { { "all", string.format("All  %d", p.total) } } end
    return { { "open", string.format("To do  %d", p.total - p.done) }, { "done", string.format("Done  %d", p.done) },
        { "all", string.format("All  %d", p.total) } }
end

-- A faction's gain: "+1,250".
function Words.Gain(n)
    local s = tostring(math.floor(math.abs(n) + 0.5)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return "+" .. s
end

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
        elseif tag.style == "lvl" then bg, edge, ink, alpha = "fit", "fit", "white", 1
        elseif tag.style == "rare" then bg, edge, ink, alpha = "dunTagRareBg", "dunTagRareEdge", "dunTagRare", 0.9
        elseif tag.style == "req" then bg, edge, ink, alpha = "dunTagReqBg", "dunTagReqEdge", "dunTagReq", 0.9
        elseif tag.style == "have" then bg, edge, ink, alpha = "dunTagBg", "complete", "complete", 0.75
        elseif tag.style == "rec" then bg, edge, ink, alpha = "dunTagRecBg", "dunTagRecEdge", "white", 1
        elseif tag.style == "fac" then
            local key = "fac" .. tostring(tag.faction)
            if not T.color[key] then key = "facContested" end
            bg, edge, ink, alpha = key, key, "white", 1
        end
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
-- The instance page's pieces (task 5)
---------------------------------------------------------------------------------------------

-- A framed panel (style.css .dpanel): dark ground in card frame A, a gold title and a dim count.
local function newPanel(parent)
    local T, P = ns.Theme, ns.Theme.layout.dunPage
    local f = CreateFrame("Frame", nil, parent)
    f.bg = T.Solid(f, "dunPanel", "BACKGROUND", 0.72)
    f.bg:SetAllPoints()
    f.frame = T.CardFrame(f, P.frameCorner, 0, "BORDER", "card-frame-a")
    if not f.frame then f.edge = ns.Widgets.Edge(f, "BORDER"); f.edge:SetColor("cardEdge") end
    f.title = T.Text(f, "md", "gold")
    -- Clear of the frame's band (in game the title touched it at panelPad - 4).
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", P.panelPad, -P.panelPad + 1)
    f.title:SetJustifyH("LEFT")
    f.sub = T.Text(f, "xs", "dim")
    f.sub:SetPoint("BOTTOMLEFT", f.title, "BOTTOMRIGHT", ns.Theme.space.s3, 1)
    f.sub:SetJustifyH("LEFT"); f.sub:SetWordWrap(false)
    return f
end

-- A painted boss seal (boss-seal, -rare, -opt) with its number; a drawn disc without the art.
local function newSeal(parent, layer)
    local T = ns.Theme
    local s = {}
    s.tex = parent:CreateTexture(nil, layer or "ARTWORK")
    s.num = T.Text(parent, "sm", "dunSealInk")
    s.num:SetPoint("CENTER", s.tex, "CENTER", 0, 0)
    function s:SetPoint(...) self.tex:ClearAllPoints(); self.tex:SetPoint(...) end
    function s:Set(boss, n, size)
        local kind = Words.SealKind(boss)
        self.tex:SetSize(size, size)
        local file = T.Chrome(kind)
        if file then self.tex:SetTexture(file); self.tex:SetTexCoord(0, 1, 0, 1); self.tex:SetVertexColor(1, 1, 1)
        else
            local r, g, b = T.RGB(kind == "boss-seal-rare" and "dunSealInkOpt" or "todo")
            self.tex:SetColorTexture(r, g, b, kind == "boss-seal-opt" and 0.25 or 0.9)
        end
        self.num:SetText(tostring(n))
        self.num:SetTextColor(T.RGB(kind == "boss-seal-rare" and "dunSealInkRare" or kind == "boss-seal-opt" and "dunSealInkOpt" or "dunSealInk"))
    end
    return s
end

-- A focus edge any button can wear: yellow while focused (or selected).
local function focusEdge(b)
    b.ring = ns.Widgets.Edge(b, "OVERLAY")
    function b:PaintEdge()
        local on = self.focused or self.selected
        self.ring:SetColor(on and "focus" or (self.edgeColor or "dunTagEdge"), on and 1 or (self.edgeAlpha or 0.8))
    end
    function b:SetFocused(on) self.focused = on; self:PaintEdge(); if self.OnFocus then self:OnFocus(on) end end
    function b:SetSelected(on) self.selected = on; self:PaintEdge() end
    ns.Widgets.HoverInfo(b)
end

-- The run's boss: a pill with its seal and name (style.css .dseal-b); compact: the seal only.
local function newPill(parent)
    local T, P = ns.Theme, ns.Theme.layout.dunPage
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(P.pill)
    b.bg = T.Solid(b, "black", "BACKGROUND", 0.3)
    b.bg:SetAllPoints()
    b.seal = newSeal(b)
    b.seal:SetPoint("LEFT", b, "LEFT", 2, 0)
    b.name = T.Text(b, "xs", "white")
    b.name:SetPoint("LEFT", b, "LEFT", 2 + P.seal + 6, 0)
    b.name:SetJustifyH("LEFT"); b.name:SetWordWrap(false)
    focusEdge(b)
    b.edgeColor = "dunTagEdge"
    b:PaintEdge()
    -- :Set(boss, n, compact) -> width
    function b:Set(boss, n, compact)
        self.seal:Set(boss, n, P.seal)
        self.name:SetShown(not compact)
        self.name:SetText(boss.name)
        local w = compact and (P.seal + 4) or math.ceil(2 + P.seal + 6 + (self.name:GetStringWidth() or 0) + 10)
        self:SetWidth(w)
        return w
    end
    return b
end

-- A boss in Bosses & loot (style.css .dboss.compact): seal, name and tags, "for you / all".
local function newBossRow(parent)
    local T, S, P = ns.Theme, ns.Theme.space, ns.Theme.layout.dunPage
    local r = ns.Widgets.FocusRow(parent, P.bossRow)
    r.bg = T.Solid(r, "dunPanel", "BACKGROUND", 0.6)
    r.bg:SetAllPoints()
    r.seal = newSeal(r)
    r.seal:SetPoint("LEFT", r, "LEFT", S.s2, 0)
    r.name = T.Text(r, "sm", "white")
    r.name:SetPoint("LEFT", r, "LEFT", S.s2 + P.seal + S.s2, 0)
    r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
    r.count = T.Text(r, "xs", "dim")
    r.count:SetPoint("RIGHT", r, "RIGHT", -S.s2, 0)
    r.count:SetJustifyH("RIGHT")
    r.tagHolder = CreateFrame("Frame", nil, r)
    r.tagHolder:SetHeight(ns.Theme.layout.dunTab.tag)
    return r
end

-- A loot tile (style.css .ditem.tile): the icon in its quality border, the name in the quality
-- colour, type and level, the ready check when it's in your bags or bank. The game's item
-- tooltip shows on focus and hover.
local tipOwner
local function hideTip(owner)
    if tipOwner == owner and GameTooltip and GameTooltip.Hide then GameTooltip:Hide(); tipOwner = nil end
end
local function showTip(owner, itemID)
    if not (GameTooltip and GameTooltip.SetOwner and type(itemID) == "number") then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local ok = type(GameTooltip.SetItemByID) == "function" and pcall(GameTooltip.SetItemByID, GameTooltip, itemID)
    if ok then GameTooltip:Show(); tipOwner = owner else GameTooltip:Hide() end
end
local function newTile(parent)
    local T, S, P = ns.Theme, ns.Theme.space, ns.Theme.layout.dunPage
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(P.tile)
    b.bg = T.Solid(b, "black", "BACKGROUND", 0.55)
    b.bg:SetAllPoints()
    b.iconFrame = CreateFrame("Frame", nil, b)
    b.iconFrame:SetSize(P.icon, P.icon)
    b.iconFrame:SetPoint("LEFT", b, "LEFT", S.s2, 0)
    b.icon = b.iconFrame:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 2, -2); b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.qEdge = ns.Widgets.Edge(b.iconFrame, "OVERLAY")
    b.qEdge:SetThickness(2)
    b.have = b:CreateTexture(nil, "OVERLAY")
    b.have:SetSize(16, 16)
    b.have:SetPoint("RIGHT", b, "RIGHT", -S.s2, 0)
    b.have:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    b.name = T.Text(b, "sm", "white")
    b.name:SetPoint("BOTTOMLEFT", b.iconFrame, "RIGHT", S.s2, 1)
    b.name:SetJustifyH("LEFT"); b.name:SetWordWrap(false)
    b.kind = T.Text(b, "xs", "dim")
    b.kind:SetPoint("TOPLEFT", b.iconFrame, "RIGHT", S.s2, -2)
    b.kind:SetJustifyH("LEFT"); b.kind:SetWordWrap(false)
    focusEdge(b)
    b.edgeColor = "dunTagEdge"
    b:PaintEdge()
    function b:OnFocus(on) if on then showTip(self, self.itemID) else hideTip(self) end end
    b:HookScript("OnEnter", function(self) showTip(self, self.itemID) end)
    b:HookScript("OnLeave", function(self) if not self.focused then hideTip(self) end end)
    b:HookScript("OnHide", function(self) hideTip(self) end)
    return b
end

-- A pickup place (style.css .dpick): the count in a ring, the place, givers and earlier quests.
local function newPick(parent)
    local T, S, P = ns.Theme, ns.Theme.space, ns.Theme.layout.dunPage
    local r = ns.Widgets.FocusRow(parent, P.pick)
    r.bg = T.Solid(r, "black", "BACKGROUND", 0.3)
    r.bg:SetAllPoints()
    r.badge = CreateFrame("Frame", nil, r)
    r.badge:SetSize(26, 26)
    r.badge:SetPoint("LEFT", r, "LEFT", S.s2, 0)
    T.Solid(r.badge, "well", "BACKGROUND"):SetAllPoints()
    ns.Widgets.Edge(r.badge, "BORDER"):SetColor("todo")
    r.n = T.Text(r.badge, "sm", "gold")
    r.n:SetPoint("CENTER", 0, 0)
    r.place = T.Text(r, "sm", "white")
    r.place:SetPoint("BOTTOMLEFT", r, "LEFT", S.s2 + 26 + S.s2, 1)
    r.place:SetJustifyH("LEFT"); r.place:SetWordWrap(false)
    r.who = T.Text(r, "xs", "dim")
    r.who:SetPoint("TOPLEFT", r, "LEFT", S.s2 + 26 + S.s2, -2)
    r.who:SetJustifyH("LEFT"); r.who:SetWordWrap(false)
    return r
end

-- A key or attunement (style.css .dkey): its icon, name and tag.
local function newKey(parent)
    local T, S, P = ns.Theme, ns.Theme.space, ns.Theme.layout.dunPage
    local r = ns.Widgets.FocusRow(parent, P.key)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(P.key - 6, P.key - 6)
    r.icon:SetPoint("LEFT", r, "LEFT", S.s1, 0)
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    r.name = T.Text(r, "sm", "white")
    r.name:SetPoint("LEFT", r.icon, "RIGHT", S.s2, 0)
    r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
    r.tagHolder = CreateFrame("Frame", nil, r)
    r.tagHolder:SetHeight(ns.Theme.layout.dunTab.tag)
    return r
end

-- A faction raised here (style.css .dfac): crest, name, "+amount".
local function newFaction(parent)
    local T, S, P = ns.Theme, ns.Theme.space, ns.Theme.layout.dunPage
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(P.facTile)
    b.bg = T.Solid(b, "black", "BACKGROUND", 0.35)
    b.bg:SetAllPoints()
    b.crest = ns.Widgets.Crest(b)
    b.crest:SetPoint("LEFT", b, "LEFT", S.s1, 0)
    b.name = T.Text(b, "sm", "white")
    b.name:SetPoint("LEFT", b, "LEFT", S.s1 + P.crest + S.s2, 0)
    b.name:SetJustifyH("LEFT"); b.name:SetWordWrap(false)
    b.gain = T.Text(b, "xs", "dunGain")
    b.gain:SetPoint("RIGHT", b, "RIGHT", -S.s2, 0)
    focusEdge(b)
    b:PaintEdge()
    return b
end

-- A quest (style.css .dqrow): the level chip in the difficulty colour, the name, the meta line
-- and the state.
local function newQuestRow(parent)
    local T, S, P = ns.Theme, ns.Theme.space, ns.Theme.layout.dunPage
    local r = ns.Widgets.FocusRow(parent, P.questRow)
    r.chip = CreateFrame("Frame", nil, r)
    r.chip:SetSize(P.chip, 22)
    r.chip:SetPoint("LEFT", r, "LEFT", S.s2, 0)
    T.Solid(r.chip, "well", "BACKGROUND"):SetAllPoints()
    r.chipEdge = ns.Widgets.Edge(r.chip, "BORDER")
    r.lvl = T.Text(r.chip, "xs", "white")
    r.lvl:SetPoint("CENTER", 0, 0)
    r.state = T.Text(r, "xs", "dim")
    r.state:SetPoint("RIGHT", r, "RIGHT", -S.s2, 0)
    r.state:SetJustifyH("RIGHT")
    r.name = T.Text(r, "sm", "white")
    r.name:SetPoint("BOTTOMLEFT", r, "LEFT", S.s2 + P.chip + S.s2, 1)
    r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
    r.meta = T.Text(r, "xs", "dim")
    r.meta:SetPoint("TOPLEFT", r, "LEFT", S.s2 + P.chip + S.s2, -2)
    r.meta:SetJustifyH("LEFT"); r.meta:SetWordWrap(false)
    return r
end

---------------------------------------------------------------------------------------------
-- Page
---------------------------------------------------------------------------------------------

-- The road's pieces (task 6) -------------------------------------------------------------------

local function maskCircle(owner, tex)
    local m = owner.CreateMaskTexture and owner:CreateMaskTexture()
    if not m then return end
    m:SetAllPoints(tex)
    m:SetTexture(ns.Theme.circleMask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    pcall(tex.AddMaskTexture, tex, m)
end

-- A one-line name plate: the cartouche sliced at its parchment band (round 8: rows 39-87 of
-- 128, the curled ends 64 px of 512 each side, drawn 24 px), the name centred in dark ink.
-- :SetText(name) sizes it.
local function newPlate(parent)
    local T, R6 = ns.Theme, ns.Theme.layout.dunRoad
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(R6.plate)
    local file = T.Chrome("cartouche")
    if file then
        local v0, v1 = R6.plateRows[1] / R6.plateTex[2], R6.plateRows[2] / R6.plateTex[2]
        local cap = R6.plateCapPx / R6.plateTex[1]
        local function part(u0, u1)
            local t = f:CreateTexture(nil, "BACKGROUND")
            t:SetTexture(file); t:SetTexCoord(u0, u1, v0, v1)
            return t
        end
        local l, m, r = part(0, cap), part(cap, 1 - cap), part(1 - cap, 1)
        l:SetPoint("TOPLEFT"); l:SetPoint("BOTTOMLEFT"); l:SetWidth(R6.plateCap)
        r:SetPoint("TOPRIGHT"); r:SetPoint("BOTTOMRIGHT"); r:SetWidth(R6.plateCap)
        m:SetPoint("TOPLEFT", l, "TOPRIGHT"); m:SetPoint("BOTTOMRIGHT", r, "BOTTOMLEFT")
    else
        T.Solid(f, "classParchment", "BACKGROUND", 0.92):SetAllPoints()
    end
    f.text = T.Text(f, "sm", "dunRoadInk")
    f.text:SetShadowOffset(0, 0)
    f.text:SetWordWrap(false)
    f.text:SetPoint("CENTER", f, "CENTER", 0, 1)
    function f:SetText(s)
        self.text:SetText(s)
        self:SetWidth(math.ceil((self.text:GetStringWidth() or 0) + 2 * R6.platePad))
    end
    return f
end

-- A medallion: the painting in a circle inside the painted ring (bronze, blood-red for raids,
-- gold with laurels when every quest is done), a soft glow for progress, your level and focus,
-- ✓, the New tag, and its plate above or below.
local RING = { complete = "medallion-ring-gold", raid = "medallion-ring-raid" }
local GLOW = { focus = { 1, 0.92, 0.45, 1 }, complete = { 1, 0.82, 0, 0.8 }, fit = { 1, 0.86, 0.47, 0.75 },
    progress = { 0.88, 0.54, 0.24, 0.8 } }
local function newMedallion(parent)
    local T, R6, W = ns.Theme, ns.Theme.layout.dunRoad, ns.Widgets
    local m = CreateFrame("Button", nil, parent)
    m.glow = m:CreateTexture(nil, "BACKGROUND")
    m.glow:SetPoint("CENTER")
    local glow = T.Chrome("glow-soft")
    if glow then m.glow:SetTexture(glow) else m.glow:SetColorTexture(1, 1, 1, 0.25) end
    if m.glow.SetBlendMode then m.glow:SetBlendMode("ADD") end
    m.disc = m:CreateTexture(nil, "BORDER", nil, 0)
    m.disc:SetPoint("CENTER")
    m.disc:SetColorTexture(0.07, 0.047, 0.024, 1)
    maskCircle(m, m.disc)
    m.art = m:CreateTexture(nil, "BORDER", nil, 1)
    m.art:SetPoint("CENTER")
    maskCircle(m, m.art)
    m.ring = m:CreateTexture(nil, "ARTWORK")
    m.ring:SetPoint("CENTER")
    m.check = m:CreateTexture(nil, "OVERLAY")
    m.check:SetSize(R6.check, R6.check)
    m.check:SetTexture(T.files.checkDone)
    if m.check.SetDesaturated then m.check:SetDesaturated(true) end
    m.check:SetVertexColor(T.RGB("complete"))
    m.tagHolder = CreateFrame("Frame", nil, m)
    m.tagHolder:SetAllPoints()
    m.plate = newPlate(parent)
    -- Size and look from the entry: size (104 or 118), ring, glow, sepia.
    function m:Paint()
        local e, size = self.entry, self.size or R6.med
        local state = self.known and e.progress.state or nil
        local ring = T.Chrome(RING[state == "complete" and "complete" or (e.inst.kind == "raid" and "raid" or "")] or "medallion-ring")
        self.ring:SetSize(size, size)
        self.ring:SetShown(ring ~= nil)
        if ring then self.ring:SetTexture(ring) end
        local inner = math.floor(size * R6.artShare + 0.5)
        self.art:SetSize(inner, inner); self.disc:SetSize(inner, inner)
        local g = self.focused and "focus" or (state == "complete" and "complete") or (e.fit and "fit")
            or (state == "progress" and "progress") or nil
        self.glow:SetShown(g ~= nil)
        if g then
            local c = GLOW[g]
            local gs = size * R6.glow * (g == "focus" and 1.12 or 1)
            self.glow:SetSize(gs, gs)
            self.glow:SetVertexColor(c[1], c[2], c[3], c[4])
        end
        self.check:ClearAllPoints()
        self.check:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 4)
        self.check:SetShown(state == "complete")
    end
    function m:SetFocused(on)
        self.focused = on and true or false
        local sc = self.focused and R6.focusScale or 1
        if self.SetScale then self:SetScale(sc) end
        if self.at then
            self:ClearAllPoints()
            self:SetPoint("CENTER", parent, "TOPLEFT", self.at[1] / sc, -self.at[2] / sc)
        end
        if self.SetFrameLevel and self.baseLevel then self:SetFrameLevel(self.baseLevel + (self.focused and 2 or 0)) end
        self:Paint()
    end
    W.HoverInfo(m)
    return m
end

-- A bracket sign on the painted header plate on a post.
local function newSign(parent)
    local T, R6 = ns.Theme, ns.Theme.layout.dunRoad
    local f = T.Plate(parent, R6.sign)
    T.SetFont(f.title, "sm")
    f.post = f:CreateTexture(nil, "BACKGROUND")
    f.post:SetSize(R6.post[1], R6.post[2])
    f.post:SetPoint("TOP", f, "BOTTOM", 0, 0)
    f.post:SetColorTexture(1, 1, 1, 1)
    local r, g, b = T.RGB("dunRoadPost")
    local ok = type(CreateColor) == "function" and pcall(f.post.SetGradient, f.post, "VERTICAL",
        CreateColor(r, g, b, 0), CreateColor(r, g, b, 1))
    if not ok then f.post:SetColorTexture(r, g, b, 0.6) end
    return f
end

-- A level stone on the road (milestone art), the level on its face.
local function newStone(parent)
    local T, R6 = ns.Theme, ns.Theme.layout.dunRoad
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(R6.stone, R6.stone)
    f.art = f:CreateTexture(nil, "ARTWORK")
    f.art:SetAllPoints()
    local file = T.Chrome("milestone")
    if file then f.art:SetTexture(file) else f.art:SetColorTexture(0.55, 0.48, 0.38, 1) end
    f.text = T.Text(f, "xs", "dunRoadInk")
    f.text:SetShadowOffset(0, 0)
    f.text:SetPoint("CENTER", f, "CENTER", 0, -R6.stoneDrop)
    return f
end

local function build(parent)
    local T, L, S, W = ns.Theme, ns.Theme.layout, ns.Theme.space, ns.Widgets
    local D, P = L.dunTab, L.dunPage
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

    -- The instance page: the banner, the body and its three views ---------------------------------
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
    -- The wing tabs (round 4: the toolbar's red panel buttons, the selected one pressed in).
    banner.wingBar = CreateFrame("Frame", nil, banner)
    banner.wingBar:SetHeight(L.panelButton)
    banner.wingBar:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", S.s6, S.s3)
    banner.wingBar:SetPoint("RIGHT", banner, "RIGHT", -200, 0)
    banner.wings = {}
    -- The score (round 3): "0 / 6" over "quests done"; the gold quests seal beside it once every
    -- quest is done (and the game said so).
    banner.scoreSub = T.Text(banner, "sm", "text")
    banner.scoreSub:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", -S.s6, S.s4)
    banner.scoreSub:SetJustifyH("RIGHT")
    banner.score = T.Text(banner, "xxl", "white")
    banner.score:SetPoint("BOTTOMRIGHT", banner.scoreSub, "TOPRIGHT", 0, 0)
    banner.score:SetJustifyH("RIGHT")
    banner.seal = banner:CreateTexture(nil, "ARTWORK", nil, 3)
    banner.seal:SetSize(P.sealBig, P.sealBig)
    banner.seal:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", -(S.s6 + 120), S.s2)
    if banner.seal.SetRotation then banner.seal:SetRotation(-8 * math.pi / 180) end
    banner.seal:Hide()
    local back = CreateFrame("Button", nil, banner, "UIPanelButtonTemplate")
    back:SetSize(150, 24)
    back:SetPoint("TOPRIGHT", -S.s4, -S.s3)
    back:SetText("Dungeons")
    back:SetScript("OnClick", function() page:Back() end)
    banner.back = back -- its label follows B's (Refresh: "Zone" or "Reputation" when opened from there)
    banner:SetScript("OnSizeChanged", function(self)
        if self.inst then paintArt(self.art, self.inst, self:GetWidth(), self:GetHeight()) end
    end)

    -- The body: the painting blurred and dimmed behind it (round 5; soft offset copies of a
    -- magnified crop, as a texture can't be blurred), the view switch, the views.
    local body = CreateFrame("Frame", nil, d)
    body:SetPoint("TOPLEFT", banner, "BOTTOMLEFT"); body:SetPoint("BOTTOMRIGHT")
    if body.SetClipsChildren then body:SetClipsChildren(true) end
    body.blur = {}
    local OFFS = { { 0, 0 }, { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
    for i, o in ipairs(OFFS) do
        local t = body:CreateTexture(nil, "BACKGROUND", nil, i)
        t:SetPoint("TOPLEFT", body, "TOPLEFT", o[1] * P.blur - 24, o[2] * P.blur + 24)
        t:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", o[1] * P.blur + 24, o[2] * P.blur - 24)
        t:SetAlpha(i == 1 and 0.4 or 0.18)
        t:SetVertexColor(0.5, 0.45, 0.4)
        body.blur[i] = t
    end
    local bshade = body:CreateTexture(nil, "BORDER")
    bshade:SetAllPoints()
    gradient(bshade, "VERTICAL", 0.85, 0.4)
    local sw = CreateFrame("Frame", nil, body)
    sw:SetPoint("TOPLEFT"); sw:SetPoint("TOPRIGHT"); sw:SetHeight(P.switch)
    T.Solid(sw, "black", "BACKGROUND", 0.25):SetAllPoints()
    local swRule = T.Solid(sw, "divider", "BORDER")
    swRule:SetPoint("BOTTOMLEFT"); swRule:SetPoint("BOTTOMRIGHT"); swRule:SetHeight(1)
    page.pvButtons = {}
    for i, v in ipairs(Words.PAGE_VIEWS) do
        local b = W.PanelButton(sw)
        b:SetScript("OnClick", function() page:SetPageView(v[1]) end)
        b.item = { title = v[2], detail = Words.PAGE_VIEW_INFO[v[1]] .. " Y switches the view." }
        b.value = v[1]
        page.pvButtons[i] = b
    end
    sw.note = T.Text(sw, "xs", "dim")
    sw.note:SetPoint("RIGHT", sw, "RIGHT", -S.s4, 0)
    sw.note:SetJustifyH("RIGHT"); sw.note:SetWordWrap(false)
    sw.note:SetText("Y switches the view  ·  sources: Warcraft Wiki (curated), QuestieDB")
    local function viewFrame()
        local f = CreateFrame("Frame", nil, body)
        f:SetPoint("TOPLEFT", sw, "BOTTOMLEFT"); f:SetPoint("BOTTOMRIGHT")
        f:Hide()
        return f
    end
    -- Overview: Before you go (left), The run and Rewards (right).
    local ov = viewFrame()
    ov.left, ov.run, ov.rew = newPanel(ov), newPanel(ov), newPanel(ov)
    ov.left.title:SetText("Before you go")
    ov.run.title:SetText("The run")
    ov.rew.title:SetText("Rewards")
    for _, pnl in ipairs({ ov.left, ov.run }) do
        pnl.scroll = W.Scroll(pnl)
        pnl.scroll:SetPoint("TOPLEFT", pnl, "TOPLEFT", P.panelPad, -(P.panelHead + 6))
        pnl.scroll:SetPoint("BOTTOMRIGHT", pnl, "BOTTOMRIGHT", -P.panelPad + 4, P.panelPad - 6)
    end
    local lc = ov.left.scroll.child
    ov.lvText = T.Text(lc, "sm", "text")
    ov.lvText:SetJustifyH("LEFT"); ov.lvText:SetWordWrap(false)
    ov.lvBar = W.LevelBar(lc)
    ov.fit = T.Text(lc, "sm", "dim")
    ov.fit:SetJustifyH("RIGHT"); ov.fit:SetWordWrap(false)
    ov.sub = T.Text(lc, "sm", "text")
    ov.sub:SetJustifyH("LEFT")
    ov.note = T.Text(lc, "sm", "dunFaint")
    ov.note:SetJustifyH("LEFT"); ov.note:SetWordWrap(true)
    ov.quest = newQuestBar(ov.rew)
    ov.quest:SetPoint("TOPLEFT", ov.rew, "TOPLEFT", P.panelPad, -(P.panelHead + 8))
    ov.rewNote = T.Text(ov.rew, "sm", "dunFaint")
    ov.rewNote:SetJustifyH("LEFT"); ov.rewNote:SetWordWrap(true)
    -- Bosses & loot: the compact boss list (340) | the focused boss's loot, each scrolling.
    local bv = viewFrame()
    bv.list = CreateFrame("Frame", nil, bv)
    bv.list:SetPoint("TOPLEFT"); bv.list:SetPoint("BOTTOMLEFT"); bv.list:SetWidth(P.bossList)
    local bvEdge = T.Solid(bv.list, "divider", "BORDER")
    bvEdge:SetPoint("TOPRIGHT"); bvEdge:SetPoint("BOTTOMRIGHT"); bvEdge:SetWidth(1)
    bv.scroll = W.Scroll(bv.list)
    bv.scroll:SetPoint("TOPLEFT", bv.list, "TOPLEFT", P.padX, -P.padY)
    bv.scroll:SetPoint("BOTTOMRIGHT", bv.list, "BOTTOMRIGHT", -S.s3, P.padY)
    bv.loot = CreateFrame("Frame", nil, bv)
    bv.loot:SetPoint("TOPLEFT", bv.list, "TOPRIGHT"); bv.loot:SetPoint("BOTTOMRIGHT")
    bv.name = T.Text(bv.loot, "lg", "gold")
    bv.name:SetPoint("TOPLEFT", bv.loot, "TOPLEFT", S.s4, -P.padY)
    bv.name:SetJustifyH("LEFT"); bv.name:SetWordWrap(false)
    bv.count = T.Text(bv.loot, "xs", "text")
    bv.count:SetPoint("TOPLEFT", bv.name, "BOTTOMLEFT", 0, -S.s1)
    bv.count:SetJustifyH("LEFT"); bv.count:SetWordWrap(false)
    bv.kills = T.Text(bv.loot, "xs", "dim")
    bv.kills:SetPoint("TOPLEFT", bv.count, "BOTTOMLEFT", 0, -2)
    bv.kills:SetJustifyH("LEFT"); bv.kills:SetWordWrap(false)
    bv.kills:SetText("Kills aren't counted: the game keeps no record of past kills.")
    bv.lootFilters = {}
    for i, v in ipairs({ { "foryou", "For you" }, { "all", "All" } }) do
        local b = W.PanelButton(bv.loot)
        b.minWidth = 0
        b:SetScript("OnClick", function() page:SetLootFilter(v[1]) end)
        b.value, b.label = v[1], v[2]
        bv.lootFilters[i] = b
    end
    bv.lootScroll = W.Scroll(bv.loot)
    bv.lootScroll:SetPoint("TOPLEFT", bv.loot, "TOPLEFT", S.s4, -(P.padY + P.lootHead))
    bv.lootScroll:SetPoint("BOTTOMRIGHT", bv.loot, "BOTTOMRIGHT", -P.padX, P.padY)
    bv.note = T.Text(bv.lootScroll.child, "sm", "dunFaint")
    bv.note:SetPoint("TOPLEFT", 0, -S.s2)
    bv.note:SetJustifyH("LEFT"); bv.note:SetWordWrap(true)
    -- Quests: To do / Done / All, groups by where you pick them up (sticky headers).
    local qv = viewFrame()
    qv.bar = CreateFrame("Frame", nil, qv)
    qv.bar:SetPoint("TOPLEFT", qv, "TOPLEFT", P.padX, -S.s2); qv.bar:SetPoint("TOPRIGHT", qv, "TOPRIGHT", -P.padX, -S.s2)
    qv.bar:SetHeight(P.filterRow)
    qv.barNote = T.Text(qv.bar, "xs", "dim")
    qv.barNote:SetPoint("RIGHT", qv.bar, "RIGHT", 0, 0)
    qv.barNote:SetJustifyH("RIGHT"); qv.barNote:SetWordWrap(false)
    qv.filters = {}
    for i = 1, 3 do
        local b = W.PanelButton(qv.bar)
        b.minWidth = 0
        b:SetScript("OnClick", function() page:SetQuestFilter(b.value) end)
        qv.filters[i] = b
    end
    qv.scroll = W.Scroll(qv)
    qv.scroll:SetPoint("TOPLEFT", qv.bar, "BOTTOMLEFT", 0, -S.s2)
    qv.scroll:SetPoint("BOTTOMRIGHT", qv, "BOTTOMRIGHT", -P.padX, P.padY)
    qv.note = T.Text(qv.scroll.child, "md", "dunFaint")
    qv.note:SetPoint("TOPLEFT", 0, -S.s4)
    qv.note:SetJustifyH("LEFT"); qv.note:SetWordWrap(true)
    qv.sticky = W.Header(qv)
    qv.sticky:SetPoint("TOPLEFT", qv.scroll, "TOPLEFT"); qv.sticky:SetPoint("TOPRIGHT", qv.scroll, "TOPRIGHT")
    qv.sticky:SetFrameLevel(qv.scroll:GetFrameLevel() + 10)
    qv.sticky:Hide()
    qv.scroll:HookScript("OnVerticalScroll", function(self)
        local off, pick = self:GetVerticalScroll() or 0, nil
        if off > 0 then
            for _, h in ipairs(qv.headerYs or {}) do if h.y < off + L.listHeader then pick = h end end
        end
        qv.sticky:SetShown(pick ~= nil)
        if pick then qv.sticky.text:SetText(pick.text); qv.sticky.count:SetText(pick.count) end
    end)
    d:Hide()
    d.banner, d.back, d.body, d.switch = banner, back, body, sw
    d.ov, d.bv, d.qv = ov, bv, qv
    page.detail = d

    -- The Road (task 6): the strip scrolls sideways (its canvas laid out in the design's px and
    -- scaled to fit), the preview card under it.
    local R6 = L.dunRoad
    local rd = CreateFrame("Frame", nil, page)
    rd:Hide()
    rd.sf = CreateFrame("ScrollFrame", nil, rd)
    rd.sf:SetPoint("TOPLEFT"); rd.sf:SetPoint("TOPRIGHT")
    if rd.sf.SetClipsChildren then rd.sf:SetClipsChildren(true) end
    rd.child = CreateFrame("Frame", nil, rd.sf)
    rd.child:SetSize(1, 1)
    rd.sf:SetScrollChild(rd.child)
    rd.canvas = CreateFrame("Frame", nil, rd.child)
    rd.canvas:SetPoint("TOPLEFT")
    rd.ground = T.Solid(rd.canvas, "dunRoadGround", "BACKGROUND", 1)
    rd.ground:SetAllPoints()
    -- The dusk (round 6, painted): the top and the bottom darken a little.
    rd.duskTop = rd.canvas:CreateTexture(nil, "BORDER", nil, 0)
    rd.duskTop:SetPoint("TOPLEFT"); rd.duskTop:SetPoint("TOPRIGHT")
    gradient(rd.duskTop, "VERTICAL", 0, 0.25)
    rd.duskBottom = rd.canvas:CreateTexture(nil, "BORDER", nil, 0)
    rd.duskBottom:SetPoint("BOTTOMLEFT"); rd.duskBottom:SetPoint("BOTTOMRIGHT")
    gradient(rd.duskBottom, "VERTICAL", 0.35, 0)
    -- The raids' citadel band darkens toward the end (.trcitadel).
    rd.citadel = rd.canvas:CreateTexture(nil, "BORDER", nil, 1)
    rd.citadel:SetPoint("TOPRIGHT"); rd.citadel:SetPoint("BOTTOMRIGHT")
    rd.citadel:SetColorTexture(1, 1, 1, 1)
    if not (type(CreateColor) == "function" and pcall(rd.citadel.SetGradient, rd.citadel, "HORIZONTAL",
        CreateColor(0.24, 0.055, 0.024, 0), CreateColor(0.12, 0.024, 0.016, 0.5))) then
        rd.citadel:SetColorTexture(0.12, 0.024, 0.016, 0.3)
    end
    rd.layer = {} -- frames above the painting: signs, stones, medallions, You
    for i, name in ipairs({ "signs", "stones", "meds", "you" }) do
        local f = CreateFrame("Frame", nil, rd.canvas)
        f:SetAllPoints()
        if f.SetFrameLevel then f:SetFrameLevel(rd.canvas:GetFrameLevel() + i * 3) end
        rd.layer[name] = f
    end
    -- You: your portrait in the brass ring, "You · 10" under it.
    local you = CreateFrame("Frame", nil, rd.layer.you)
    you:SetSize(R6.you, R6.you)
    you.icon = you:CreateTexture(nil, "ARTWORK")
    you.icon:SetSize(R6.you - 4, R6.you - 4); you.icon:SetPoint("CENTER")
    maskCircle(you, you.icon)
    you.brass = you:CreateTexture(nil, "OVERLAY")
    local brass = T.Chrome("you-ring")
    if brass then
        you.brass:SetTexture(brass); you.brass:SetPoint("CENTER")
        you.brass:SetSize((R6.you - 4) / 0.56, (R6.you - 4) / 0.56)
    else you.brass:Hide() end
    you.tag = CreateFrame("Frame", nil, you)
    you.tag:SetHeight(R6.youTag)
    you.tag:SetPoint("TOP", you, "BOTTOM", 0, -4)
    you.tag.bg = T.Solid(you.tag, "dunRoadTag", "BACKGROUND", 0.85)
    you.tag.bg:SetAllPoints()
    you.tag.text = T.Text(you.tag, "xs", "dunRoadInk")
    you.tag.text:SetShadowOffset(0, 0)
    you.tag.text:SetPoint("CENTER", 0, 0)
    rd.you = you
    rd.edge = T.Solid(rd, "divider", "BORDER")
    rd.edge:SetPoint("TOPLEFT", rd.sf, "BOTTOMLEFT"); rd.edge:SetPoint("TOPRIGHT", rd.sf, "BOTTOMRIGHT")
    rd.edge:SetHeight(2)
    -- The preview card: the painting in frame A, then name and tags, blurb, meta, bosses, the foot.
    local pv = CreateFrame("Frame", nil, rd)
    pv:SetPoint("TOPLEFT", rd.sf, "BOTTOMLEFT", 0, -2); pv:SetPoint("BOTTOMRIGHT")
    pv.artBox = CreateFrame("Frame", nil, pv)
    pv.artBox:SetPoint("TOPLEFT", pv, "TOPLEFT", R6.previewPadX, -R6.previewPadY)
    pv.artBox:SetPoint("BOTTOMLEFT", pv, "BOTTOMLEFT", R6.previewPadX, R6.previewPadY)
    pv.artBox:SetWidth(R6.previewArt)
    pv.art = pv.artBox:CreateTexture(nil, "BORDER")
    pv.art:SetAllPoints()
    pv.frame = T.CardFrame(pv.artBox, L.dunTab.frameCorner, L.dunTab.frameOut, "OVERLAY", "card-frame-a")
    pv.body = CreateFrame("Frame", nil, pv)
    pv.body:SetPoint("TOPLEFT", pv.artBox, "TOPRIGHT", R6.previewGap, 0)
    pv.body:SetPoint("BOTTOMRIGHT", pv, "BOTTOMRIGHT", -R6.previewPadX, R6.previewPadY)
    pv.name = T.Text(pv.body, "xl", "gold")
    pv.name:SetJustifyH("LEFT"); pv.name:SetWordWrap(false)
    pv.tagHolder = CreateFrame("Frame", nil, pv.body)
    pv.tagHolder:SetSize(1, D.tag)
    pv.blurb = T.Text(pv.body, "sm", "text")
    pv.blurb:SetJustifyH("LEFT"); pv.blurb:SetJustifyV("TOP")
    pv.meta = T.Text(pv.body, "sm", "text")
    pv.meta:SetJustifyH("LEFT"); pv.meta:SetWordWrap(false)
    pv.chips = {}
    pv.quest = newQuestBar(pv.body)
    pv.keys = T.Text(pv.body, "xs", "dunRoadKey")
    pv.keys:SetJustifyH("LEFT"); pv.keys:SetWordWrap(false)
    pv.loot = T.Text(pv.body, "xs", "dim")
    pv.loot:SetJustifyH("LEFT"); pv.loot:SetWordWrap(false)
    pv.goText = T.Text(pv.body, "sm", "gold")
    pv.goText:SetPoint("BOTTOMRIGHT", pv.body, "BOTTOMRIGHT", 0, 2)
    pv.goText:SetText("Open")
    pv.go = T.Glyph(pv.body, "A")
    T.SetGlyph(pv.go, "A")
    pv.go:SetPoint("RIGHT", pv.goText, "LEFT", -4, 0)
    rd.pv = pv
    rd.sf:EnableMouseWheel(true)
    rd.sf:SetScript("OnMouseWheel", function(self, delta)
        local range = math.max(0, (rd.child:GetWidth() or 0) - (self:GetWidth() or 0))
        local new = (self:GetHorizontalScroll() or 0) - delta * R6.step * (rd.scale or 1)
        self:SetHorizontalScroll(math.max(0, math.min(range, new)))
        page.roadScroll = self:GetHorizontalScroll()
    end)
    page.road = rd

    -- Pools of the page's pieces, reset on each paint.
    local pools = {}
    local function pool(name, make, parentFrame) pools[name] = { list = {}, used = 0, make = make, parent = parentFrame } end
    pool("wings", function(p) local b = W.PanelButton(p); b.minWidth = 0; return b end, banner.wingBar)
    pool("keys", newKey, lc)
    pool("picks", newPick, lc)
    pool("pills", newPill, ov.run.scroll.child)
    pool("facs", newFaction, ov.rew)
    pool("bosses", newBossRow, bv.scroll.child)
    pool("wingLabels", function(p) local t = T.Text(p, "xs", "gold"); t:SetJustifyH("LEFT"); return t end, bv.scroll.child)
    pool("tiles", newTile, bv.lootScroll.child)
    pool("qheaders", W.Header, qv.scroll.child)
    pool("qrows", newQuestRow, qv.scroll.child)
    pool("rregions", function(p) return p:CreateTexture(nil, "BACKGROUND", nil, 2) end, rd.canvas)
    pool("rbands", function(p) return p:CreateTexture(nil, "ARTWORK", nil, 1) end, rd.canvas)
    pool("rsigns", newSign, rd.layer.signs)
    pool("rstones", newStone, rd.layer.stones)
    pool("rmeds", function(p)
        local m = newMedallion(p)
        m:HookScript("OnHide", function(self) self.plate:Hide() end)
        return m
    end, rd.layer.meds)
    pool("rchips", function(p)
        local c = CreateFrame("Frame", nil, p)
        c:SetHeight(R6.chip)
        T.Solid(c, "black", "BACKGROUND", 0.35):SetAllPoints()
        c.edge = W.Edge(c, "BORDER")
        c.edge:SetColor("dunRoadChip")
        c.text = T.Text(c, "xs", "white")
        c.text:SetPoint("CENTER", 0, 0)
        c.text:SetWordWrap(false)
        return c
    end, pv.body)
    local function get(name)
        local p = pools[name]
        p.used = p.used + 1
        local f = p.list[p.used]
        if not f then f = p.make(p.parent); p.list[p.used] = f end
        f:ClearAllPoints()
        f:Show()
        return f
    end
    local function reset(...) for _, n in ipairs({ ... }) do pools[n].used = 0 end end
    local function hideRest(...)
        for _, n in ipairs({ ... }) do
            local p = pools[n]
            for i = p.used + 1, #p.list do p.list[i]:Hide() end
        end
    end
    page.pools = pools

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
        rd:ClearAllPoints()
        rd:SetPoint("TOPLEFT", tb, "BOTTOMLEFT"); rd:SetPoint("BOTTOMRIGHT")
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

    -- The toolbar's row; on the road, up from it lands on the Road button.
    local function toolbarRow(home)
        local items = {}
        for i, b in ipairs(controls) do
            items[#items + 1] = b.item
            if home and b.item.key == home then home = i end
        end
        return { items = items, section = 0, home = type(home) == "number" and home or nil }
    end

    local function entryFor(key)
        for _, e in ipairs(page.all or {}) do if e.inst.key == key then return e end end
    end

    -- The page's size: d's, or before the first layout the window's less the list (split).
    local function pageSize()
        local w = d:GetWidth() or 0
        if w <= 1 then w = width(page, nil) - (page:Split() and D.splitList or 0) end
        local h = d:GetHeight() or 0
        if h <= 1 then
            local f = ns.UI.GetFrame()
            h = (f and f:GetHeight() or 740) - 140
        end
        return w, math.max(1, h - D.banner - P.switch)
    end

    local function className() return (ns.character or {}).className or "your class" end
    local function myLevel() return (ns.character or {}).level or 1 end

    -- The blurred painting behind the body: a magnified middle of the painting (or of the
    -- entrance zone's art until there is one), soft copies offset around it.
    local function paintBackdrop(inst, w, h)
        local art = ns.Art and ns.Art.dungeons
        local file, l, r, t, b
        if art and art[inst.key] then
            file = T.mediaDir .. "Dungeons\\" .. inst.key .. ".blp"
            l, r, t, b = T.CoverCoords(w + 48, h + 48, 1024, 512)
        else
            local mapID = inst.zones and inst.zones[1]
            file = mapID and T.ZoneArt(mapID)
            l, r, t, b = T.CoverCoords(w + 48, h + 48, 1024, 512)
        end
        local cx, cy = (l + r) / 2, (t + b) / 2
        local hw, hh = (r - l) / 2 * P.blurZoom, (b - t) / 2 * P.blurZoom
        for _, tex in ipairs(body.blur) do
            tex:SetShown(file ~= nil)
            if file then
                tex:SetTexture(file)
                tex:SetTexCoord(cx - hw, cx + hw, cy - hh, cy + hh)
                if tex.SetDesaturation then tex:SetDesaturation(0.3) end
            end
        end
    end

    -- The banner: painting, name (the place for wings), blurb, meta, tags, wing tabs, the score
    -- and the quests seal.
    local function fillBanner(e, pw)
        local inst = e.inst
        banner.inst = inst
        paintArt(banner.art, inst, pw, D.banner)
        local wings = Words.WingTabs(inst)
        banner.name:SetText(wings and inst.group or inst.name)
        banner.blurb:SetText(inst.blurb or "")
        local where = Words.Where(inst, zoneName)
        local kind = inst.kind == "raid" and "Raid" or "Dungeon"
        local parts = { kind, inst.size .. " players" }
        if where ~= "" then parts[#parts + 1] = where end
        parts[#parts + 1] = Words.Levels(inst)
        banner.meta:SetText(table.concat(parts, "  ·  "))
        placeTags(banner.tagHolder, Words.Tags(e), S.s6, -S.s4)
        reset("wings")
        local items = {}
        local x, home = 0, 1
        for i, w in ipairs(wings or {}) do
            local b = get("wings")
            b:SetLabel(w.label, L.panelButtonPadTight, 0)
            b:SetOn(w.inst.key == inst.key)
            b:SetPoint("LEFT", banner.wingBar, "LEFT", x, 0)
            x = x + b:GetWidth() + S.s2
            local we = entryFor(w.inst.key)
            local qt = we and Words.QuestText(we.progress, page.known) or ""
            local key = w.inst.key
            b.item = { key = "w:" .. key, frame = b, title = w.inst.name, free = true, actionLabel = "Open",
                detail = string.format("%s, levels %d-%d, %d %s. %s.", w.label, w.inst.levels[1], w.inst.levels[2],
                    #w.inst.bosses, plural(#w.inst.bosses, "boss", "bosses"), qt),
                onActivate = function() page:OpenWing(key) end }
            b:SetScript("OnClick", function() page:OpenWing(key) end)
            if w.inst.key == inst.key then home = i end
            items[#items + 1] = b.item
        end
        hideRest("wings")
        banner.wingBar:SetShown(wings ~= nil)
        banner.meta:ClearAllPoints()
        if wings then banner.meta:SetPoint("BOTTOMLEFT", banner.wingBar, "TOPLEFT", 0, S.s2)
        else banner.meta:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", S.s6, S.s4) end
        -- The score: quests only; "?" while the game doesn't say which are done.
        local p = e.progress
        local text, qkind = Words.QuestText(p, page.known)
        local complete = page.known and p.state == "complete"
        if qkind == "none" then
            T.SetFont(banner.score, "md")
            banner.score:SetText(text)
            banner.score:SetTextColor(T.RGB("dunFaint"))
            banner.scoreSub:SetText("")
        else
            T.SetFont(banner.score, "xxl")
            banner.score:SetText(string.format("%s / %d", page.known and tostring(p.done) or "?", p.total))
            banner.score:SetTextColor(T.RGB(complete and "complete" or (page.known and p.done > 0) and "classPeach" or "white"))
            banner.scoreSub:SetText(plural(p.total, "quest") .. " done")
        end
        local seal = complete and T.Chrome("cel-seal-quests")
        banner.seal:SetShown(seal and true or false)
        if seal then
            banner.seal:SetTexture(seal)
            banner.seal:ClearAllPoints()
            local sw2 = math.max(banner.score:GetStringWidth() or 0, banner.scoreSub:GetStringWidth() or 0)
            banner.seal:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", -(S.s6 + sw2 + S.s3), S.s2)
        end
        return items, home
    end

    -- Each boss's gear (item IDs), how much is for you, and how much is in your bags.
    local function bossLoot(inst)
        local out = {}
        local Dn = ns.Dungeons
        for i, b in ipairs(inst.bosses or {}) do
            local ids = Dn.BossGear(inst, b)
            local o = { ids = ids, forYou = 0, have = 0, mine = {} }
            for _, id in ipairs(ids or {}) do
                if Dn.ForYou(id) then o.forYou = o.forYou + 1; o.mine[id] = true end
                local n = Dn.Count(id)
                if n and n > 0 then o.have = o.have + 1 end
            end
            out[i] = o
        end
        return out
    end

    local function noQuestsText(p, long)
        if p.none == "unmapped" then
            return long and "This dungeon's quests aren't mapped to it yet: QuestieDB files them under their zones." or "Its quests aren't mapped to it yet."
        end
        if p.none == "side" then return "None for your side." end
        return "No quests here."
    end

    local function placeOf(g, inst) return Words.PlaceName(g, inst, zoneName, ns.Dungeons.AreaName) end

    -- The quest names for "needs ...": this instance's records, else the quest index's.
    local function questNamer(p)
        local names = {}
        for _, q in ipairs(p.quests) do names[q.id] = q.name end
        return function(id)
            if names[id] then return names[id] end
            local info = ns.Quests.Info and ns.Quests.Info(id)
            return type(info) == "table" and info.name or nil
        end
    end

    -- Overview ----------------------------------------------------------------------------------
    local function paintOverview(e, w, h)
        local inst, p = e.inst, e.progress
        local R, Dn = ns.DungeonRules, ns.Dungeons
        local char, ctx = Dn.Character(), Dn.PlaceContext() or R.PlaceContext(nil)
        local level = myLevel()
        local innerW = w - 2 * P.padX
        local leftW = math.floor((innerW - P.colGap) * P.leftShare)
        local rightW = innerW - P.colGap - leftW
        local ph = h - 2 * P.padY
        reset("keys", "picks", "pills", "facs")
        local rows = {}
        -- Before you go.
        ov.left:ClearAllPoints()
        ov.left:SetPoint("TOPLEFT", ov, "TOPLEFT", P.padX, -P.padY)
        ov.left:SetSize(leftW, ph)
        local cw = leftW - 2 * P.panelPad
        local y = 0
        ov.lvText:SetText(string.format("%s  ·  you're %d", Words.Levels(inst), level))
        ov.lvText:ClearAllPoints(); ov.lvText:SetPoint("LEFT", lc, "TOPLEFT", 0, -P.lvl / 2)
        ov.fit:SetText(Words.Fit(inst.levels, level))
        ov.fit:SetTextColor(T.RGB(e.fit and "fit" or "dim"))
        ov.fit:ClearAllPoints(); ov.fit:SetPoint("RIGHT", lc, "TOPLEFT", cw, -P.lvl / 2)
        local lw, fw = ov.lvText:GetStringWidth() or 0, ov.fit:GetStringWidth() or 0
        local barRoom = cw - lw - fw - 2 * S.s3
        ov.lvBar:SetShown(barRoom >= L.levelBarWidth)
        ov.lvBar:ClearAllPoints()
        ov.lvBar:SetPoint("LEFT", lc, "TOPLEFT", lw + S.s3 + math.floor((barRoom - L.levelBarWidth) / 2), -P.lvl / 2)
        ov.lvBar:Set(inst.levels[1], inst.levels[2], level, e.fit)
        y = y + P.lvl + S.s2
        local leftItems = {}
        local function leftItem(item)
            item.group, item.column, item.scroll = "left", 1, ov.left.scroll
            leftItems[#leftItems + 1] = item
            rows[#rows + 1] = { items = { item }, section = 1 }
            return item
        end
        for i, k in ipairs(Dn.Keys(inst)) do
            local r = get("keys")
            r:SetPoint("TOPLEFT", lc, "TOPLEFT", 0, -y)
            r:SetWidth(cw)
            r.icon:SetTexture((k.item and k.item.icon) or "Interface\\Icons\\INV_Misc_Key_04")
            r.name:SetText(k.key.name)
            local tagText, style = Words.KeyTag(k.key, k.count)
            r.name:SetWidth(math.min(cw - 140, math.ceil(r.name:GetStringWidth() or 0) + 1))
            r.tagHolder:ClearAllPoints(); r.tagHolder:SetPoint("LEFT", r.name, "RIGHT", S.s2, 0)
            r.tagHolder:SetWidth(math.max(1, placeTags(r.tagHolder, { { text = tagText, style = style } }, 0, 0, "LEFT")))
            local have = k.count and k.count > 0
            r.item = leftItem({ key = "k:" .. i, frame = r, title = k.key.name,
                detail = string.format("%s. %s.%s", k.key.note or "", k.key.need == "required" and "Required" or "Optional, handy to have",
                    have and " You have it (bags or bank)." or "") })
            y = y + P.key + 2
        end
        ov.sub:ClearAllPoints(); ov.sub:SetPoint("TOPLEFT", lc, "TOPLEFT", 0, -(y + S.s2))
        ov.sub:SetText(page.known and "Pick up the quests" or "Where the quests start")
        y = y + P.sub + S.s1
        ov.note:Hide()
        local function note(text)
            ov.note:SetText(text); ov.note:SetWidth(cw)
            ov.note:ClearAllPoints(); ov.note:SetPoint("TOPLEFT", lc, "TOPLEFT", 0, -y)
            ov.note:Show()
            y = y + (ov.note:GetStringHeight() or 14) + S.s2
        end
        if p.total == 0 then
            note(noQuestsText(p))
        else
            local shown, more = R.Pickups(p, inst, char, ctx)
            if #shown == 0 then
                note("Every quest here is done.")
            else
                -- who(k): the second line with k parts; the most that fits whole is shown
                -- (in game "3 need an earlier qu..." was cut, WoWScrnShot_111526_135639).
                local function pick(n, place, who, maxParts, item)
                    local r = get("picks")
                    r:SetPoint("TOPLEFT", lc, "TOPLEFT", 0, -y)
                    r:SetWidth(cw)
                    r.n:SetText(n)
                    local tw = cw - 26 - 3 * S.s2
                    r.place:SetText(place); r.place:SetWidth(tw)
                    for k = maxParts, 0, -1 do
                        r.who:SetText(who(k))
                        if (r.who:GetStringWidth() or 0) <= tw then break end
                    end
                    r.who:SetWidth(tw)
                    local two = (r.who:GetText() or "") ~= ""
                    r.place:ClearAllPoints(); r.who:SetShown(two)
                    if two then r.place:SetPoint("BOTTOMLEFT", r, "LEFT", S.s2 + 26 + S.s2, 1)
                    else r.place:SetPoint("LEFT", r, "LEFT", S.s2 + 26 + S.s2, 0) end
                    item.frame = r
                    r.item = leftItem(item)
                    y = y + P.pick + 4
                end
                for _, g in ipairs(shown) do
                    local name = placeOf(g, inst)
                    local qn = {}
                    for _, v in ipairs(g.quests) do qn[#qn + 1] = v.quest.name or "?" end
                    local key = g.key
                    pick(tostring(#g.quests), name, function(k) return Words.PickupWho(g, k) end, 3,
                        { key = "p:" .. key, title = name, actionLabel = "Quests",
                        detail = string.format("%d %s to pick up: %s.", #g.quests, plural(#g.quests, "quest"), table.concat(qn, ", ")),
                        onActivate = function() page:SetPageView("quests", { place = key }) end })
                end
                if more then
                    local names = {}
                    for _, g in ipairs(more) do names[#names + 1] = placeOf(g, inst) end
                    pick("+" .. #more, "More places", function(k) return Words.MorePlaces(names, k) end, #names,
                        { key = "p:more", title = #more .. " more places",
                        detail = table.concat(names, ", ") .. ".", actionLabel = "Quests",
                        onActivate = function() page:SetPageView("quests") end })
                end
            end
        end
        lc:SetHeight(math.max(1, y))
        -- The right column: The run (top) and Rewards (bottom). The run gets the height its
        -- seals need first: Rewards drops to one row of factions, then the seals show numbers
        -- only, before anything is clipped (at the minimum window Blackrock Depths' third row
        -- of seals was cut, WoWScrnShot_111526_135702).
        local rx = P.padX + leftW + P.colGap
        local rcw = rightW - 2 * P.panelPad
        local facs = p.total > 0 and R.Factions(p.quests) or {}
        local nf = math.min(#facs, P.facMax)
        local qh = 0
        ov.quest:SetShown(p.total > 0)
        if p.total > 0 then qh = ov.quest:Set(p, page.known, math.min(P.questBar, rcw)) + S.s3 end
        local function rewHeight(n)
            local rowsN = math.ceil(n / P.facCols)
            local b2 = n > 0 and (rowsN * (P.facTile + 6) - 6) or (T.size.sm + 4)
            return P.panelHead + 8 + qh + b2 + P.panelPad
        end
        local loot = bossLoot(inst)
        local items, forYou, known = 0, 0, ns.Dungeons.BuildResult() ~= nil
        for _, o in ipairs(loot) do items = items + #(o.ids or {}); forYou = forYou + o.forYou end
        local bosses = inst.bosses or {}
        ov.run.sub:SetText(Words.RunCount(#bosses, known and items or nil, forYou))
        local rc = ov.run.scroll.child
        local runRows
        -- Lays out the seals; returns the run panel's height they need.
        local function layoutRun(compact)
            reset("pills")
            runRows = {}
            local x, ry, line = 0, 0, {}
            local function flush()
                if #line > 0 then runRows[#runRows + 1] = { items = line, section = 2 } end
                line = {}
            end
            for i, b in ipairs(bosses) do
                local pill = get("pills")
                local pw = pill:Set(b, i, compact)
                if x > 0 and x + pw > rcw then x = 0; ry = ry + P.pill + P.pillGap; flush() end
                pill:SetPoint("TOPLEFT", rc, "TOPLEFT", x, -ry)
                x = x + pw + P.pillGap
                local o = loot[i]
                local tagWords = {}
                for _, tg in ipairs(Words.BossTags(b)) do tagWords[#tagWords + 1] = tg.text end
                local gear = not known and "" or (#(o.ids or {}) > 0 and string.format("%d %s, %d for you.", #o.ids, plural(#o.ids, "item"), o.forYou) or "No gear known.")
                local bi = i
                pill.item = { key = "s:" .. i, frame = pill, title = i .. ". " .. b.name, group = "right", column = 2, scroll = ov.run.scroll,
                    actionLabel = "Loot",
                    detail = (#tagWords > 0 and (table.concat(tagWords, ", ") .. ". ") or "") .. gear,
                    onActivate = function() page:SetPageView("bosses", { boss = bi }) end }
                pill:SetScript("OnClick", function() page:SetPageView("bosses", { boss = bi }) end)
                line[#line + 1] = pill.item
            end
            flush()
            rc:SetHeight(math.max(1, ry + P.pill))
            return P.panelHead + 6 + ry + P.pill + P.panelPad
        end
        local compact = #bosses > P.compactAfter
        local need = layoutRun(compact)
        if need > ph - rewHeight(nf) - P.colGap and nf > P.facCols then nf = P.facCols end
        if need > ph - rewHeight(nf) - P.colGap and not compact then compact = true; layoutRun(true) end
        local rewH = rewHeight(nf)
        local facRows = math.ceil(nf / P.facCols)
        ov.run:ClearAllPoints()
        ov.run:SetPoint("TOPLEFT", ov, "TOPLEFT", rx, -P.padY)
        ov.run:SetSize(rightW, math.max(60, ph - rewH - P.colGap))
        -- Rewards: the quest bar and up to four factions (A opens Reputation).
        ov.rewNote:ClearAllPoints()
        ov.rewNote:SetPoint("TOPLEFT", ov.rew, "TOPLEFT", P.panelPad, -(P.panelHead + 8 + qh))
        ov.rewNote:SetWidth(rcw)
        ov.rewNote:SetShown(nf == 0)
        ov.rewNote:SetText(p.total == 0 and noQuestsText(p) or "No reputation from quests here.")
        ov.rew:ClearAllPoints()
        ov.rew:SetPoint("BOTTOMLEFT", ov, "BOTTOMLEFT", rx, P.padY)
        ov.rew:SetSize(rightW, rewH)
        local facItems = {}
        local tileW = math.floor((rcw - 6) / P.facCols)
        for i = 1, nf do
            local f = facs[i]
            local fac = ns.Reputation and ns.Reputation.Get and ns.Reputation.Get(f.factionID)
            local name = fac and fac.name or ("Faction " .. f.factionID)
            local b = get("facs")
            local col, row = (i - 1) % P.facCols, math.floor((i - 1) / P.facCols)
            b:SetPoint("TOPLEFT", ov.rew, "TOPLEFT", P.panelPad + col * (tileW + 6), -(P.panelHead + 8 + qh + row * (P.facTile + 6)))
            b:SetSize(tileW, P.facTile)
            b.crest:Set(fac or { factionID = f.factionID, name = name }, P.crest)
            b.name:SetText(name)
            b.gain:SetText(Words.Gain(f.amount))
            -- The name stays whole: when it doesn't fit beside the gain, the gain goes under it
            -- (the minimum window cut "Gnomeregan Exi...", WoWScrnShot_111526_135657).
            local textX = S.s1 + P.crest + S.s2
            local room = tileW - textX - S.s2
            local gw, nw = b.gain:GetStringWidth() or 40, b.name:GetStringWidth() or 0
            b.name:ClearAllPoints(); b.gain:ClearAllPoints()
            if nw + S.s2 + gw <= room then
                b.name:SetPoint("LEFT", b, "LEFT", textX, 0)
                b.gain:SetPoint("RIGHT", b, "RIGHT", -S.s2, 0)
                b.name:SetWidth(room - gw - S.s2)
            else
                b.name:SetPoint("BOTTOMLEFT", b, "LEFT", textX, 0)
                b.gain:SetPoint("TOPLEFT", b, "LEFT", textX, -1)
                b.name:SetWidth(room)
            end
            local id = f.factionID
            local reaction = fac and fac.reaction and T.reaction.labels[fac.reaction]
            b.item = { key = "f:" .. id, frame = b, title = name, group = "right", column = 2, actionLabel = "Reputation",
                detail = string.format("%sAbout %s from %d %s here (QuestieDB's base values).", reaction and (reaction .. ". ") or "",
                    Words.Gain(f.amount), f.quests, plural(f.quests, "quest")),
                onActivate = function() page:OpenFaction(id) end }
            b:SetScript("OnClick", function() page:OpenFaction(id) end)
            local ri = math.floor((i - 1) / P.facCols) + 1
            facItems[ri] = facItems[ri] or {}
            facItems[ri][#facItems[ri] + 1] = b.item
        end
        for _, r in ipairs(runRows) do rows[#rows + 1] = r end
        for i = 1, facRows do rows[#rows + 1] = { items = facItems[i], section = 3 } end
        hideRest("keys", "picks", "pills", "facs")
        return rows
    end

    -- Bosses & loot -------------------------------------------------------------------------------
    local function paintLoot(e, loot)
        local inst = e.inst
        local i = page.selBoss or 1
        local b = (inst.bosses or {})[i]
        reset("tiles")
        local rows = {}
        local lw = math.max(100, (pageSize()) - P.bossList - S.s4 - P.padX)
        bv.note:Hide()
        for _, fb in ipairs(bv.lootFilters) do fb:Hide() end
        if not b then hideRest("tiles"); bv.name:SetText(""); bv.count:SetText(""); return rows end
        local o = loot[i] or { ids = {}, forYou = 0, have = 0, mine = {} }
        bv.name:SetText(i .. ". " .. b.name)
        local ids = o.ids or {}
        bv.count:SetText(Words.LootCount(#ids, o.forYou, o.have))
        local all = page.lootFilter == "all"
        local function lootNote(text)
            bv.note:SetWidth(lw); bv.note:SetText(text); bv.note:Show()
        end
        if not o.ids then
            lootNote("Reading QuestieDB's loot.")
        elseif #ids == 0 then
            lootNote(inst.kind == "raid"
                and "No loot known for this boss. QuestieDB lists no gear for most raid bosses."
                or "No gear known for this boss. Some bosses drop only trade goods or quest items, or their loot sits in a chest.")
        end
        if #ids > 0 then
            -- For you / All, right of the header.
            local fx = S.s4 + lw
            local fItems = {}
            for k = #bv.lootFilters, 1, -1 do
                local fb = bv.lootFilters[k]
                fb:SetLabel(fb.label, L.panelButtonPadTight, 0)
                fb:SetOn((all and "all" or "foryou") == fb.value)
                fb:ClearAllPoints(); fb:SetPoint("TOPRIGHT", bv.loot, "TOPLEFT", fx, -P.padY)
                fx = fx - fb:GetWidth() - S.s2
                fb:Show()
                fb.item = { key = "lf:" .. fb.value, frame = fb, title = fb.label, group = "loot", column = 2, actionLabel = "Show",
                    detail = fb.value == "all" and "Every item this boss drops." or
                        string.format("Armour and weapons a %s uses, the armour type for your level, shields and its relic slot.", className()),
                    onActivate = function() page:SetLootFilter(fb.value) end }
                table.insert(fItems, 1, fb.item)
            end
            rows[#rows + 1] = { items = fItems, section = 2 }
        end
        local shown = {}
        for _, id in ipairs(ids) do if all or o.mine[id] then shown[#shown + 1] = id end end
        if #ids > 0 and #shown == 0 then
            lootNote(string.format("Nothing here for a %s. \"All\" shows every item.", className()))
        end
        local tileW = math.floor((lw - P.tileGap) / 2)
        local lc2 = bv.lootScroll.child
        local level = myLevel()
        local line
        for n, id in ipairs(shown) do
            local it = ns.Dungeons.Item(id) or { id = id }
            local t = get("tiles")
            local col, row = (n - 1) % 2, math.floor((n - 1) / 2)
            t:SetPoint("TOPLEFT", lc2, "TOPLEFT", col * (tileW + P.tileGap), -(row * (P.tile + P.tileGap)))
            t:SetSize(tileW, P.tile)
            t.itemID = id
            t.icon:SetTexture(it.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            local qr, qg, qb = T.QualityRGB(it.quality)
            if qr then t.qEdge:SetColor("white"); for k = 1, 4 do t.qEdge[k]:SetColorTexture(qr, qg, qb, 1) end
            else t.qEdge:SetColor("dunTagEdge") end
            t.name:SetText(it.name or "Loading...")
            if qr then t.name:SetTextColor(qr, qg, qb) else t.name:SetTextColor(T.RGB("dim")) end
            local req = it.reqLevel
            local lvWord = type(req) == "number" and req > 0 and ("  ·  Lv " .. (req > level and ("|cff8c8c8c" .. req .. "|r") or tostring(req))) or ""
            t.kind:SetText(Words.ItemType(it) .. lvWord)
            local count = ns.Dungeons.Count(id)
            local have = count ~= nil and count > 0
            t.have:SetShown(have)
            local wTxt = tileW - P.icon - 3 * S.s2 - (have and 20 or 0)
            t.name:SetWidth(wTxt); t.kind:SetWidth(wTxt)
            local QUAL = { [0] = "Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary" }
            t.item = { key = "i:" .. id, frame = t, title = it.name or ("Item " .. id), group = "loot", column = 2, scroll = bv.lootScroll,
                detail = string.format("%s%s%s.%s%s", it.quality and QUAL[it.quality] and (QUAL[it.quality] .. " ") or "",
                    Words.ItemType(it):lower(), type(req) == "number" and req > 0 and (", requires level " .. req) or "",
                    o.mine[id] and "" or string.format(" Not what a %s wears.", className()), have and " You have one (bags or bank)." or "") }
            if col == 0 then line = { items = {}, section = 2 }; rows[#rows + 1] = line end
            line.items[#line.items + 1] = t.item
        end
        lc2:SetHeight(math.max(1, math.ceil(#shown / 2) * (P.tile + P.tileGap)))
        hideRest("tiles")
        return rows
    end

    local function paintBosses(e)
        local inst = e.inst
        local loot = bossLoot(inst)
        page.loot = loot
        reset("bosses", "wingLabels")
        local rows = {}
        local bc = bv.scroll.child
        local listW = P.bossList - P.padX - S.s3
        local y, lastWing = 0, nil
        local known = ns.Dungeons.BuildResult() ~= nil
        for i, b in ipairs(inst.bosses or {}) do
            if b.wing and b.wing ~= lastWing then
                local wl = get("wingLabels")
                wl:SetPoint("TOPLEFT", bc, "TOPLEFT", S.s1, -(y + S.s2))
                wl:SetText(b.wing)
                y = y + 24
                lastWing = b.wing
            end
            local r = get("bosses")
            r:SetPoint("TOPLEFT", bc, "TOPLEFT", 0, -y)
            r:SetWidth(listW)
            r.seal:Set(b, i, P.seal)
            r.name:SetText(b.name)
            local o = loot[i]
            r.count:SetText(not known and "" or (#(o.ids or {}) > 0 and string.format("%d / %d", o.forYou, #o.ids) or "–"))
            local nameMax = listW - P.seal - 3 * S.s2 - 44
            local tags = Words.BossTags(b)
            local tw = placeTags(r.tagHolder, tags, 0, 0, "LEFT")
            -- The name stays whole; tags that don't fit beside it are left out (the info line
            -- says them; in game "Watchman Doo..." was cut, WoWScrnShot_111526_135648).
            local full = math.ceil(r.name:GetStringWidth() or 0) + 1
            local nw = math.min(full, nameMax)
            r.tagHolder:SetShown(tw > 0 and full + S.s2 + tw <= nameMax)
            r.name:SetWidth(nw)
            r.tagHolder:ClearAllPoints(); r.tagHolder:SetPoint("LEFT", r.name, "RIGHT", S.s2, 0); r.tagHolder:SetWidth(math.max(1, tw))
            r:SetSelected(i == page.selBoss)
            local tagWords = {}
            for _, tg in ipairs(tags) do tagWords[#tagWords + 1] = tg.text end
            local bi = i
            r.item = { key = "b:" .. i, frame = r, title = i .. ". " .. b.name, group = "boss", column = 1, scroll = bv.scroll,
                bossIndex = i, actionLabel = "Loot",
                detail = (#tagWords > 0 and (table.concat(tagWords, ", ") .. ". ") or "") .. (not known and "" or
                    (#(o.ids or {}) > 0 and string.format("%d %s, %d for you; right to browse them.", #o.ids, plural(#o.ids, "item"), o.forYou) or "No gear known.")),
                onActivate = function() page:EnterLoot(bi) end }
            r:SetScript("OnClick", function() page:SelectBoss(bi) end)
            rows[#rows + 1] = { items = { r.item }, section = 1 }
            y = y + P.bossRow + 2
        end
        bc:SetHeight(math.max(1, y))
        hideRest("bosses", "wingLabels")
        return rows, paintLoot(e, loot)
    end

    -- Quests ----------------------------------------------------------------------------------------
    local function paintQuests(e)
        local inst, p = e.inst, e.progress
        local R, Dn = ns.DungeonRules, ns.Dungeons
        local char, ctx = Dn.Character(), Dn.PlaceContext() or R.PlaceContext(nil)
        reset("qheaders", "qrows")
        local rows = {}
        qv.note:Hide()
        local filters = Words.QuestFilters(p, page.known)
        local f = page.questFilter
        local ok = false
        for _, x in ipairs(filters) do if x[1] == f then ok = true end end
        if not ok then f = filters[1][1] end
        page.shownQuestFilter = f
        local fItems = {}
        local x = 0
        for i, b in ipairs(qv.filters) do
            local fl = filters[i]
            b:SetShown(fl ~= nil and p.total > 0)
            if fl and p.total > 0 then
                b.value = fl[1]
                b:SetLabel(fl[2], L.panelButtonPadTight, 0)
                b:SetOn(fl[1] == f)
                b:ClearAllPoints(); b:SetPoint("LEFT", qv.bar, "LEFT", x, 0)
                x = x + b:GetWidth() + S.s2
                local v = fl[1]
                b.item = { key = "qf:" .. v, frame = b, title = fl[2], actionLabel = "Show",
                    detail = v == "open" and "Quests you haven't done, by where you pick them up." or v == "done" and "Quests you've done here."
                        or "Every quest for your side and class.",
                    onActivate = function() page:SetQuestFilter(v) end }
                fItems[#fItems + 1] = b.item
            end
        end
        qv.barNote:SetText(p.total == 0 and "" or ("Grouped by where you pick them up  ·  your side and class" ..
            (page.known and "" or "  ·  the game hasn't said which are done")))
        if #fItems > 0 then rows[#rows + 1] = { items = fItems, section = 0 } end
        local qc = qv.scroll.child
        local qw = (pageSize()) - 2 * P.padX
        local y, headerYs = 0, {}
        local name = questNamer(p)
        local function placeWords(pl) return placeOf(pl, inst) end
        if p.total == 0 then
            qv.note:SetWidth(qw); qv.note:SetText(noQuestsText(p, true)); qv.note:Show()
        else
            local groups = R.QuestGroups(p, inst, char, ctx, f)
            if #groups == 0 then
                qv.note:SetWidth(qw); qv.note:SetText(f == "done" and "None done yet." or "Every quest here is done."); qv.note:Show()
            end
            local level = myLevel()
            for gi, g in ipairs(groups) do
                if gi > 1 then y = y + S.s3 end
                local hdr = get("qheaders")
                hdr:SetPoint("TOPLEFT", qc, "TOPLEFT", 0, -y); hdr:SetPoint("TOPRIGHT", qc, "TOPRIGHT", 0, -y)
                local title = placeWords(g)
                hdr.text:SetText(title); hdr.count:SetText(tostring(#g.quests))
                headerYs[#headerYs + 1] = { y = y, text = title, count = tostring(#g.quests) }
                y = y + L.listHeader + S.s1
                for qi, v in ipairs(g.quests) do
                    local q = v.quest
                    local r = get("qrows")
                    r:SetPoint("TOPLEFT", qc, "TOPLEFT", 0, -y)
                    r:SetWidth(qw)
                    local diff = R.Difficulty(q.level, level)
                    local c = ns.ZoneDetail and ns.ZoneDetail.DifficultyColor(diff) or { 1, 1, 1 }
                    r.lvl:SetText(tostring(q.level or "?")); r.lvl:SetTextColor(c[1], c[2], c[3])
                    for k = 1, 4 do r.chipEdge[k]:SetColorTexture(c[1], c[2], c[3], 1) end
                    r.name:SetText(q.name or ("Quest " .. q.id))
                    r.name:SetTextColor(T.RGB(v.state == "done" and "dim" or "white"))
                    r.state:SetText(Words.QuestState(v))
                    r.state:SetTextColor(T.RGB(v.state == "red" and "diffRed" or v.state == "done" and "complete" or "dim"))
                    local tw = qw - P.chip - 3 * S.s2 - P.stateCol
                    -- The meta line drops the turn-in's place, then the turn-in, before it's cut.
                    for drop = 0, 2 do
                        r.meta:SetText(Words.QuestMeta(v, name, placeWords, drop))
                        if (r.meta:GetStringWidth() or 0) <= tw then break end
                    end
                    r.name:SetWidth(tw); r.meta:SetWidth(tw)
                    local two = (r.meta:GetText() or "") ~= ""
                    r.meta:SetShown(two)
                    r.name:ClearAllPoints()
                    if two then r.name:SetPoint("BOTTOMLEFT", r, "LEFT", S.s2 + P.chip + S.s2, 1)
                    else r.name:SetPoint("LEFT", r, "LEFT", S.s2 + P.chip + S.s2, 0) end
                    local pre = Words.PreNames(v, name)
                    local stateWords = v.state == "done" and "Done." or v.state == "later" and string.format("Opens at level %d.", q.reqLevel)
                        or v.state == "red" and "Ready, but red for you." or "Ready for you."
                    r.item = { key = "q:" .. q.id, frame = r, title = q.name, scroll = qv.scroll, quest = q, place = g.key,
                        topGap = qi == 1 and (L.listHeader + S.s2) or nil,
                        detail = string.format("Level %s%s. %s%s", tostring(q.level), (q.reqLevel and q.reqLevel > 0) and (", from level " .. q.reqLevel) or "",
                            stateWords, #pre > 0 and (" Needs " .. table.concat(pre, ", ") .. " first.") or "") }
                    rows[#rows + 1] = { items = { r.item }, section = gi }
                    y = y + P.questRow + 2
                end
            end
        end
        qc:SetHeight(math.max(1, y))
        qv.headerYs = headerYs
        qv.sticky:Hide()
        hideRest("qheaders", "qrows")
        return rows
    end

    -- Paints the instance page for entry e (nil: nothing) and rebuilds its focus rows:
    -- page.pageRows = the wing tabs, then the view's rows.
    local function fillPage(e)
        local pw, ph = pageSize()
        page.pageWidth, page.pageHeight = pw, ph
        page.pageEntry = e
        if not e then banner.inst = nil; page.pageRows = {}; return end
        if page.pageKey ~= e.inst.key then
            page.pageKey = e.inst.key
            page.selBoss = nil
        end
        local inst = e.inst
        if not page.selBoss or not (inst.bosses or {})[page.selBoss] then
            page.selBoss = 1
            if ns.Dungeons.BuildResult() then
                for i, b in ipairs(inst.bosses or {}) do
                    if #(ns.Dungeons.BossGear(inst, b) or {}) > 0 then page.selBoss = i; break end
                end
            end
        end
        local wingItems, home = fillBanner(e, pw)
        paintBackdrop(inst, pw, ph)
        local v = Words.PageView(page.pv)
        local x = S.s4
        for _, b in ipairs(page.pvButtons) do
            b:SetLabel(b.item.title, L.panelButtonPadTight, 0)
            b:SetOn(b.value == v)
            b:ClearAllPoints(); b:SetPoint("LEFT", sw, "LEFT", x, 0)
            x = x + b:GetWidth() + S.s2
        end
        sw.note:SetShown(pw - x >= (sw.note:GetStringWidth() or 0) + S.s6)
        ov:SetShown(v == "overview"); bv:SetShown(v == "bosses"); qv:SetShown(v == "quests")
        local rows = {}
        if #wingItems > 0 then rows[1] = { items = wingItems, home = home, section = 0 } end
        local main, loot
        if v == "overview" then main = paintOverview(e, pw, ph)
        elseif v == "bosses" then main, loot = paintBosses(e)
        else main = paintQuests(e) end
        page.rowParts = { wings = rows[1], main = main, loot = loot or {} }
        for _, r in ipairs(main) do rows[#rows + 1] = r end
        for _, r in ipairs(loot or {}) do rows[#rows + 1] = r end
        page.pageRows = rows
    end
    page.FillPage = fillPage

    -- Bosses & loot: the focused boss's loot follows focus (keeps the boss list's rows).
    local function repaintLoot()
        local e = page.pageEntry
        if not (e and page.rowParts and page.loot) then return end
        for _, r in ipairs(page.pools.bosses.list) do
            if r:IsShown() and r.item then r:SetSelected(r.item.bossIndex == page.selBoss) end
        end
        bv.lootScroll:SetVerticalScroll(0)
        local loot = paintLoot(e, page.loot)
        page.rowParts.loot = loot
        local rows = {}
        if page.rowParts.wings then rows[1] = page.rowParts.wings end
        for _, r in ipairs(page.rowParts.main) do rows[#rows + 1] = r end
        for _, r in ipairs(loot) do rows[#rows + 1] = r end
        page.pageRows = rows
    end

    -- Opens the world map at the entrance zone (X). The map needs the controller: Azerfolio hides
    -- while it's open and comes back when it closes (as Zone Detail's World map).
    local function openMap(mapID)
        if not mapID then return false end
        if type(InCombatLockdown) == "function" and InCombatLockdown() then
            ns.Print("The world map can't be opened from Azerfolio during combat.")
            return false
        end
        local ok, how = false, nil
        if type(OpenWorldMap) == "function" then ok = pcall(OpenWorldMap, mapID); how = "OpenWorldMap" end
        if not ok and C_Map and type(C_Map.OpenWorldMap) == "function" then ok = pcall(C_Map.OpenWorldMap, mapID); how = "C_Map.OpenWorldMap" end
        local wm = WorldMapFrame
        local shown = ok and wm ~= nil and wm.IsShown ~= nil and wm:IsShown() and true or false
        ns.Debug.Trace("worldmap", { mapID = mapID, ok = ok, how = how, shown = shown, from = "dungeons",
            mapShown = shown and wm.GetMapID and ns.Debug.Try("GetMapID", wm.GetMapID, wm) or nil })
        if not shown then ns.Print("Couldn't open the world map."); return false end
        if wm.HookScript and not page.mapHooked then
            page.mapHooked = true
            wm:HookScript("OnHide", function()
                if page.reopenAfterMap then page.reopenAfterMap = false; ns.UI.Show() end
            end)
        end
        page.reopenAfterMap = page.mapHooked == true
        ns.UI.Hide()
        return true
    end
    page.OpenMapAt = openMap

    -- The Road (task 6) -------------------------------------------------------------------------

    -- Text on the scaled strip keeps its own size (px / scale), so names stay readable when the
    -- strip shrinks for a short window.
    local function setPx(fs, px)
        local ok = fs:SetFont(T.fonts.body, px, "")
        if not ok and GameFontNormal then fs:SetFontObject(GameFontNormal) end
    end

    -- The strip's scale and height and the preview's height for the road's frame: the strip at
    -- full size when the preview still gets its height, else smaller (the preview at its least).
    local function roadSizes()
        local h = rd:GetHeight() or 0
        if h <= 1 then
            local f = ns.UI.GetFrame()
            h = (f and f:GetHeight() or 740) - 140 - L.toolbarHeight
        end
        local sc = math.min(1, (h - R6.preview) / R6.H)
        if sc < 0.9 then sc = math.max(R6.minScale, math.min(1, (h - R6.previewMin) / R6.H)) end
        local stripH = math.floor(R6.H * sc + 0.5)
        return sc, stripH, math.max(R6.previewMin, h - stripH - 2)
    end

    local function roadViewWidth()
        local w = rd.sf:GetWidth() or 0
        if w <= 1 then w = width(page) end
        return w
    end

    -- Keeps the medallion at design x inside the view (D-pad walks, focus follows).
    local function roadScrollTo(x, fresh)
        local lay, sc = rd.layout, rd.scale or 1
        if not lay then return end
        local view = roadViewWidth()
        local cur = fresh or rd.sf:GetHorizontalScroll() or 0
        local new = Road.Scroll(x * sc, cur, view, lay.W * sc, R6.margin * sc)
        rd.sf:SetHorizontalScroll(new)
        page.roadScroll = new
    end

    -- The preview card for an instance (follows focus): painting, name and tags, blurb, meta,
    -- the non-rare bosses, the quest bar, keys, the loot count, A Open. Parts that don't fit
    -- are left out (the tags, the blurb, then the bosses), never cut.
    local function fillPreview(e)
        reset("rchips")
        if not e then pv:Hide(); hideRest("rchips"); return end
        pv:Show()
        local inst = e.inst
        local pw = pv:GetWidth() or 0
        if pw <= 1 then pw = roadViewWidth() end
        local ph = rd.pvH or R6.preview
        local innerH = math.max(60, math.min(ph, R6.previewMax) - 2 * R6.previewPadY)
        local artW = math.min(R6.previewArt, math.floor(innerH * 2.2))
        pv.artBox:ClearAllPoints()
        pv.artBox:SetPoint("TOPLEFT", pv, "TOPLEFT", R6.previewPadX, -R6.previewPadY)
        pv.artBox:SetSize(artW, innerH)
        paintArt(pv.art, inst, artW, innerH)
        local bw = math.max(100, pw - 2 * R6.previewPadX - artW - R6.previewGap)
        pv.body:ClearAllPoints()
        pv.body:SetPoint("TOPLEFT", pv.artBox, "TOPRIGHT", R6.previewGap, 0)
        pv.body:SetSize(bw, innerH)
        -- Name and tags (the tags go when they don't fit beside the name).
        pv.name:ClearAllPoints(); pv.name:SetPoint("TOPLEFT", pv.body, "TOPLEFT", 0, 0)
        pv.name:SetWidth(bw)
        pv.name:SetText(inst.name)
        local nw = math.min(bw, math.ceil(pv.name:GetStringWidth() or 0))
        pv.name:SetWidth(math.max(1, nw + 1))
        pv.tagHolder:ClearAllPoints()
        pv.tagHolder:SetPoint("LEFT", pv.name, "RIGHT", S.s3, 0)
        local tags = Words.Tags(e)
        local tw = placeTags(pv.tagHolder, tags, 0, 0, "LEFT")
        if nw + S.s3 + tw > bw then placeTags(pv.tagHolder, {}, 0, 0, "LEFT") end
        local y = T.size.xl + 6
        -- The foot first (it stays): the quest bar, keys and the loot count, A Open.
        local qbW = math.min(D.questBarMax, math.floor(bw * 0.4))
        local qh = pv.quest:Set(e.progress, page.known, qbW)
        pv.quest:ClearAllPoints(); pv.quest:SetPoint("BOTTOMLEFT", pv.body, "BOTTOMLEFT", 0, 0)
        local goW = (pv.goText:GetStringWidth() or 30) + L.glyphSize + 8
        local fx = qbW + S.s6
        local room = bw - fx - goW - S.s4
        local keyNames = {}
        for _, k in ipairs(ns.Dungeons.Keys and ns.Dungeons.Keys(inst) or {}) do keyNames[#keyNames + 1] = k.key.name end
        local keyText = #keyNames > 0 and ("|TInterface\\Icons\\INV_Misc_Key_04:14|t " .. table.concat(keyNames, ", ")) or ""
        local lootN
        if ns.Dungeons.BuildResult() ~= nil then
            lootN = 0
            for _, o in ipairs(bossLoot(inst)) do lootN = lootN + #(o.ids or {}) end
        end
        local lootText = Road.LootWords(lootN) or ""
        pv.keys:SetText(keyText); pv.loot:SetText(lootText)
        local kw, lw = (keyText ~= "" and pv.keys:GetStringWidth() or 0), (lootText ~= "" and pv.loot:GetStringWidth() or 0)
        local showKeys = keyText ~= "" and kw <= room
        local showLoot = lootText ~= "" and lw + (showKeys and kw + S.s6 or 0) <= room
        pv.keys:ClearAllPoints(); pv.keys:SetPoint("BOTTOMLEFT", pv.body, "BOTTOMLEFT", fx, 2)
        pv.loot:ClearAllPoints()
        pv.loot:SetPoint("BOTTOMLEFT", pv.body, "BOTTOMLEFT", fx + (showKeys and kw + S.s6 or 0), 2)
        pv.keys:SetShown(showKeys); pv.loot:SetShown(showLoot)
        local footTop = innerH - math.max(qh, T.size.sm + 4) - S.s2
        -- The meta line (drops the players, then the zone).
        local where = Words.Where(inst, zoneName)
        pv.meta:SetWidth(bw)
        for drop = 0, 2 do
            pv.meta:SetText(Road.Meta(inst, where, drop))
            if (pv.meta:GetStringWidth() or 0) <= bw then break end
        end
        -- The blurb (up to two lines) and the bosses, while they fit above the foot.
        local metaH, chipsH = T.size.sm + 4, R6.chip + S.s2
        local blurb = inst.blurb or ""
        pv.blurb:SetWidth(bw); pv.blurb:SetWordWrap(true)
        pv.blurb:SetText(blurb)
        local lines = blurb ~= "" and math.ceil((pv.blurb:GetStringWidth() or 0) / bw) or 0
        local blurbH = lines * (T.size.sm + 3)
        local withChips = y + metaH + chipsH <= footTop
        local withBlurb = lines > 0 and lines <= 2 and y + blurbH + metaH + (withChips and chipsH or 0) <= footTop
        pv.blurb:SetShown(withBlurb)
        if withBlurb then
            pv.blurb:ClearAllPoints(); pv.blurb:SetPoint("TOPLEFT", pv.body, "TOPLEFT", 0, -y)
            pv.blurb:SetHeight(blurbH)
            y = y + blurbH + 2
        end
        pv.meta:ClearAllPoints(); pv.meta:SetPoint("TOPLEFT", pv.body, "TOPLEFT", 0, -y)
        y = y + metaH + 2
        if withChips then
            -- A chip per non-rare boss while it fits (room kept for "+n more").
            local x = 0
            local _, more = Road.Chips(inst.bosses, R6.chips, function(name)
                local c = get("rchips")
                c.text:SetText(name)
                c.text:SetTextColor(T.RGB("white"))
                local cw = math.ceil((c.text:GetStringWidth() or 0) + 2 * R6.chipPad)
                if x + cw > bw - 80 then pools.rchips.used = pools.rchips.used - 1; c:Hide(); return false end
                c:SetWidth(cw)
                c:SetPoint("TOPLEFT", pv.body, "TOPLEFT", x, -y)
                x = x + cw + R6.chipGap
                return true
            end)
            if more > 0 then
                local c = get("rchips")
                c.text:SetText(string.format("+%d more", more))
                c.text:SetTextColor(T.RGB("dim"))
                c:SetWidth(math.ceil((c.text:GetStringWidth() or 0) + 2 * R6.chipPad))
                c:SetPoint("TOPLEFT", pv.body, "TOPLEFT", x, -y)
            end
        end
        hideRest("rchips")
        page.previewKey = inst.key
    end

    -- Paints the road for the shown entries. Returns the focus row's items and byKey.
    local function paintRoad(shown, known)
        reset("rregions", "rbands", "rsigns", "rstones", "rmeds")
        local level = myLevel()
        local items = Road.Order(shown)
        local sc, stripH, pvH = roadSizes()
        rd.scale, rd.pvH = sc, pvH
        local ts = 1 / sc
        rd.sf:SetHeight(stripH)
        local lay = Road.Layout(items, { H = R6.H, level = level, step = R6.step, pad = R6.pad, fade = R6.fade,
            top = R6.top, bottom = R6.bottom, zig = R6.zig, signMin = R6.signMin, tex = R6.tex, flat = R6.flat,
            art = ns.Art and ns.Art.dungeons, lanes = ns.DungeonRoad and ns.DungeonRoad.lanes })
        rd.layout, rd.items = lay, items
        local cv = rd.canvas
        cv:SetSize(lay.W, R6.H)
        if cv.SetScale then cv:SetScale(sc) end
        rd.child:SetSize(math.ceil(lay.W * sc), stripH)
        rd.duskTop:SetHeight(R6.H * 0.3); rd.duskBottom:SetHeight(R6.H * 0.3)
        rd.duskTop:SetShown(lay.painted); rd.duskBottom:SetShown(lay.painted)
        rd.citadel:SetShown(lay.citadel ~= nil)
        if lay.citadel then rd.citadel:SetWidth(math.max(1, lay.W - lay.citadel)) end
        -- The six painted regions, each behind its stretch, fading into the next.
        local hasGradient = type(CreateColor) == "function"
        for _, r in ipairs(lay.regions) do
            local file = T.mediaDir .. "Dungeons\\" .. r.key .. ".blp"
            local l, rr, t, b = T.CoverCoords(r.w, R6.H, R6.tex[1], R6.tex[2])
            local function u(x) return l + (x - r.x0) / r.w * (rr - l) end
            local f = math.min(R6.fade, r.w / 2)
            for _, seg in ipairs({ { r.x0, r.x0 + f, 0, 1 }, { r.x0 + f, r.x0 + r.w - f, 1, 1 }, { r.x0 + r.w - f, r.x0 + r.w, 1, 0 } }) do
                if seg[2] - seg[1] >= 0.5 then
                    local tex = get("rregions")
                    tex:SetTexture(file)
                    tex:SetTexCoord(u(seg[1]), u(seg[2]), t, b)
                    tex:SetSize(seg[2] - seg[1], R6.H)
                    tex:SetPoint("TOPLEFT", cv, "TOPLEFT", seg[1], 0)
                    local ok = hasGradient and pcall(tex.SetGradient, tex, "HORIZONTAL",
                        CreateColor(1, 1, 1, seg[3]), CreateColor(1, 1, 1, seg[4]))
                    if not ok then tex:SetVertexColor(1, 1, 1, (seg[3] + seg[4]) / 2) end
                end
            end
        end
        -- The gold progress (7 px) along the painted road up to You, in short stamps of the gilded
        -- band turned to follow it; without painted lanes an earth band runs on past You.
        local CT = L.classTab
        local k = R6.gold / CT.bandRows
        local win = R6.goldStep / k
        local n = 0
        local function band(xa, xb, file, colour)
            local x = xa
            while x < xb - 0.01 do
                local x2 = math.min(xb, x + R6.goldStep)
                local y1, y2 = lay.roadY(x), lay.roadY(x2)
                local dx, dy = x2 - x, y2 - y1
                local len = math.sqrt(dx * dx + dy * dy)
                local tex = get("rbands")
                if file then
                    tex:SetTexture(file)
                    local uu = (n * win) % (CT.bandTexW - win)
                    tex:SetTexCoord(uu / CT.bandTexW, (uu + win) / CT.bandTexW, 0, 1)
                    tex:SetSize(len + 0.8, CT.bandPx * k)
                    tex:SetVertexColor(1, 1, 1, 0.95)
                else
                    tex:SetTexCoord(0, 1, 0, 1)
                    local r, g, b = T.RGB(colour)
                    tex:SetColorTexture(r, g, b, 0.9)
                    tex:SetSize(len + 0.8, R6.gold)
                end
                if tex.SetRotation then tex:SetRotation(-math.atan2(dy, dx)) end
                tex:SetPoint("CENTER", cv, "TOPLEFT", (x + x2) / 2, -(y1 + y2) / 2)
                x, n = x2, n + 1
            end
        end
        local youX = math.max(0, math.min(lay.W, lay.youX))
        if #items > 0 then
            band(0, youX, T.Chrome("road-band-gold"), "complete")
            if not lay.painted then band(youX, lay.W, T.Chrome("road-band"), "classRoad") end
        end
        -- Bracket signs on posts, level stones on the road.
        for _, s in ipairs(lay.signs) do
            local f = get("rsigns")
            setPx(f.title, T.size.sm * ts)
            f.title:SetText(s.text)
            f.title:SetTextColor(T.RGB(s.raid and "dunRoadRaid" or "gold"))
            f:SetHeight(R6.sign * ts)
            f:SetWidth(math.max(R6.signMinW * ts, math.ceil((f.title:GetStringWidth() or 0) + 2 * R6.signPad * ts)))
            f:SetPoint("TOP", cv, "TOPLEFT", s.x, -R6.signTop)
        end
        for _, st in ipairs(lay.stones) do
            local f = get("rstones")
            f:SetSize(R6.stone * ts, R6.stone * ts)
            setPx(f.text, 13 * ts)
            f.text:SetPoint("CENTER", f, "CENTER", 0, -R6.stoneDrop * ts)
            f.text:SetText(tostring(st.level))
            f:SetPoint("CENTER", cv, "TOPLEFT", st.x, -st.y)
        end
        -- The medallions.
        local its, byKey = {}, {}
        local base = rd.layer.meds.GetFrameLevel and rd.layer.meds:GetFrameLevel() or 1
        for i, e in ipairs(items) do
            local p = lay.pts[i]
            local m = get("rmeds")
            local key = e.inst.key
            m.entry, m.known = e, known
            m.size = e.fit and R6.medFit or R6.med
            m:SetSize(m.size, m.size)
            m.at, m.baseLevel = { p.x, p.y }, base + 1
            local inner = math.floor(m.size * R6.artShare + 0.5)
            paintArt(m.art, e.inst, inner, inner)
            local state = known and e.progress.state or nil
            local far = e.inst.kind ~= "raid" and e.inst.levels[1] > level + 8 and (state == nil or state == "untouched")
            local desat = state == "complete" and 0 or (far and R6.sepiaFar or R6.sepia)
            if m.art.SetDesaturation then m.art:SetDesaturation(desat)
            elseif m.art.SetDesaturated then m.art:SetDesaturated(desat >= 0.5) end
            if state == "complete" then m.art:SetVertexColor(1, 1, 1)
            elseif far then m.art:SetVertexColor(0.8, 0.72, 0.6)
            else m.art:SetVertexColor(1, 0.95, 0.86) end
            placeTags(m.tagHolder, e.inst.forever and { { text = "New", style = "new" } } or {}, -6, -4)
            for _, t in ipairs(m.tagHolder.tags or {}) do
                setPx(t.text, T.size.xs * ts); t:SetHeight(D.tag * ts)
                if t:IsShown() then t:Set({ text = "New", style = "new" }) end
            end
            m.plate:ClearAllPoints()
            m.plate:SetHeight(R6.plate * ts)
            setPx(m.plate.text, R6.plateFont * ts)
            m.plate:SetText(e.inst.name)
            m.plate:SetWidth(math.ceil((m.plate.text:GetStringWidth() or 0) + 2 * R6.platePad * ts))
            if p.above then m.plate:SetPoint("BOTTOM", cv, "TOPLEFT", p.x, -(p.y - m.size / 2))
            else m.plate:SetPoint("TOP", cv, "TOPLEFT", p.x, -(p.y + m.size / 2)) end
            m.plate:Show()
            m:SetFocused(false)
            m:SetScript("OnClick", function() page:OpenInstance(key) end)
            if not m.previewHooked then
                m.previewHooked = true
                m:HookScript("OnEnter", function(self)
                    local driving = ns.Gamepad and ns.Gamepad.PadDriving and ns.Gamepad.PadDriving()
                    if self.entry and not driving then page.roadSel = self.entry.inst.key; fillPreview(self.entry) end
                end)
            end
            local where = Words.Where(e.inst, zoneName)
            m.item = { key = "d:" .. key, frame = m, title = e.inst.name, detail = Words.Info(e, known, where, false),
                entry = e, road = i, actionLabel = "Open", onActivate = function() page:OpenInstance(key) end }
            byKey[key] = m
            its[i] = m.item
        end
        hideRest("rregions", "rbands", "rsigns", "rstones", "rmeds")
        -- You, on the road with the gold up to you.
        you:ClearAllPoints()
        you:SetShown(#items > 0)
        you:SetSize(R6.you * ts, R6.you * ts)
        you.icon:SetSize((R6.you - 4) * ts, (R6.you - 4) * ts)
        if brass then you.brass:SetSize((R6.you - 4) * ts / 0.56, (R6.you - 4) * ts / 0.56) end
        you:SetPoint("CENTER", cv, "TOPLEFT", youX, -lay.youY)
        local ok = type(SetPortraitTexture) == "function" and pcall(SetPortraitTexture, you.icon, "player")
        if not ok then you.icon:SetColorTexture(T.RGB("classParchment")) end
        setPx(you.tag.text, T.size.xs * ts)
        you.tag.text:SetText("You · " .. level)
        you.tag:SetHeight(R6.youTag * ts)
        you.tag:SetWidth(math.ceil((you.tag.text:GetStringWidth() or 0) + 12 * ts))
        return its, byKey
    end
    page.FillPreview = fillPreview

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
        -- The Road takes the page while there's something on it; else the list's empty state shows.
        local roadOn = view == "road" and shown ~= nil and #shown > 0
        self.roadOn = roadOn
        local rows, byKey, headerYs = { toolbarRow(roadOn and "tb:view:road" or nil) }, {}, {}
        local title, text = emptyState(st, shown)
        self.emptyTitle:SetShown(title ~= nil); self.emptyText:SetShown(title ~= nil)
        if title then self.emptyTitle:SetText(title); self.emptyText:SetText(text) end
        local groups = (not roadOn) and shown and #shown > 0 and ns.DungeonRules.Groups(shown) or {}
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
        if roadOn then
            local its, rk = paintRoad(shown, known)
            byKey = rk
            -- Opening the road (from another view, or the first time): on the your-level
            -- instance nearest You, scrolled so You sits a third of the way in.
            local items = rd.items
            local fresh = self.roadFresh or not (self.roadSel and rk[self.roadSel])
            if fresh then
                local si = Road.Start(items, myLevel())
                self.roadSel = si and items[si].inst.key or nil
                local pend = self.pendingFocusKey
                if self.roadSel and (pend == nil or pend:sub(1, 2) == "d:") then self.pendingFocusKey = "d:" .. self.roadSel end
            end
            local si = 1
            for i, e in ipairs(items) do if e.inst.key == self.roadSel then si = i end end
            local view = roadViewWidth()
            local start = fresh and (rd.layout.youX * rd.scale - view * R6.openAt) or (self.roadScroll or 0)
            roadScrollTo(rd.layout.pts[si].x, math.max(0, start))
            self.roadFresh = false
            rows[#rows + 1] = { items = its, section = 1, home = si }
            self.roadRow = rows[#rows]
            fillPreview(items[si])
        else
            self.roadRow = nil
        end
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
        for key, f in pairs(byKey) do if f.SetSelected then f:SetSelected(split and key == self.selKey) end end
        self:Refresh()
        updateSticky()
    end

    -- Shows the right frames for the mode, then rebuilds focus and hints.
    function page:Refresh()
        local inPage, split = self.mode == "page", self:Split()
        tb:SetShown(split or not inPage)
        list:SetShown((split or not inPage) and not self.roadOn)
        rd:SetShown(not inPage and self.roadOn == true)
        d:SetShown(inPage or (split and self.selKey ~= nil))
        if inPage and not split then sticky:Hide() end
        local pageSections, seen = 0, {}
        for _, r in ipairs(self.pageRows or {}) do
            if r.section ~= 0 and not seen[r.section] then seen[r.section] = true; pageSections = pageSections + 1 end
        end
        if inPage then self.hasSections = pageSections > 1
        else self.hasSections = (self.sectionCount or 0) > 1 end
        self.sectionLabel = "Section"
        -- Opened from another tab (Zone Detail's tile, a Reputation source): B goes back there.
        self.backLabel = (self.returnTo and RETURN_LABEL[self.returnTo]) or (inPage and "Dungeons" or nil)
        if d.banner and d.banner.back then d.banner.back:SetText(self.returnTo and RETURN_LABEL[self.returnTo] or "Dungeons") end
        ns.Focus.Rebuild()
        ns.UI.RefreshHints()
    end

    -- The page's first focus stop: the view's first (past the wing tabs and filters), else any.
    local function firstPageKey()
        local rows = page.pageRows or {}
        for _, r in ipairs(rows) do
            if r.section ~= 0 and r.items[1] then return r.items[1].key end
        end
        return rows[1] and rows[1].items[1] and rows[1].items[1].key or nil
    end

    -- A on an instance: its page (full size), or into it (the wide List).
    function page:OpenInstance(key)
        self.selKey = key
        local e = entryFor(key)
        if not e then return end
        fillPage(e)
        if self:Split() and #(self.pageRows or {}) == 0 then
            self.mode = "list"; self.pendingFocusKey = "d:" .. key
        else
            self.mode = "page"
            self.pendingFocusKey = firstPageKey()
        end
        for k, f in pairs(self.byKey or {}) do if f.SetSelected then f:SetSelected(self:Split() and k == key) end end
        self:Refresh()
    end

    -- A wing tab: that wing's page, same view, focus on its tab.
    function page:OpenWing(key)
        local e = entryFor(key)
        if not e then return end
        self.selKey = key
        fillPage(e)
        self.pendingFocusKey = self.mode == "page" and ("w:" .. key) or (self.byKey and self.byKey[key] and ("d:" .. key)) or nil
        for k, f in pairs(self.byKey or {}) do if f.SetSelected then f:SetSelected(self:Split() and k == key) end end
        self:Refresh()
    end

    -- Y on the page (or a click on the switch): a view, kept between instances. opts.boss opens
    -- Bosses & loot on that boss; opts.place opens Quests (To do) at that place.
    function page:SetPageView(v, opts)
        opts = opts or {}
        self.pv = Words.PageView(v)
        if opts.boss then self.selBoss = opts.boss end
        if opts.place and self.known then self.questFilter = "open" end
        local e = self.pageEntry
        if not e then return end
        local cur = ns.Focus.Current()
        fillPage(e)
        if self.mode == "page" then
            if opts.boss then self.pendingFocusKey = "b:" .. opts.boss
            elseif opts.place then
                for _, r in ipairs(self.pageRows) do
                    local it = r.items[1]
                    if it and it.place == opts.place then self.pendingFocusKey = it.key; break end
                end
            elseif cur and cur.key and cur.key:sub(1, 2) == "w:" then self.pendingFocusKey = cur.key
            else self.pendingFocusKey = firstPageKey() end
        end
        self:Refresh()
        if self.mode == "page" and (opts.place or opts.boss) then ns.Focus.Update("top") end
    end

    function page:CyclePageView()
        self:SetPageView(Words.NextPageView(self.pv))
        return true
    end

    -- Bosses & loot: a click on a boss selects it; A moves into its loot.
    function page:SelectBoss(i)
        if self.selBoss == i then return end
        self.selBoss = i
        repaintLoot()
        if self.mode == "page" then self.pendingFocusKey = "b:" .. i end
        self:Refresh()
    end

    function page:EnterLoot(i)
        if self.selBoss ~= i then self.selBoss = i; repaintLoot() end
        local loot = self.rowParts and self.rowParts.loot or {}
        local target
        for _, r in ipairs(loot) do
            for _, it in ipairs(r.items) do if it.key:sub(1, 2) == "i:" then target = it.key; break end end
            if target then break end
        end
        target = target or (loot[1] and loot[1].items[1] and loot[1].items[1].key)
        if target then self.pendingFocusKey = target; self:Refresh() end
    end

    function page:SetLootFilter(v)
        self.lootFilter = v
        repaintLoot()
        if self.mode == "page" then self.pendingFocusKey = "lf:" .. v end
        self:Refresh()
    end

    function page:SetQuestFilter(v)
        self.questFilter = v
        local e = self.pageEntry
        if not e then return end
        fillPage(e)
        if self.mode == "page" then self.pendingFocusKey = "qf:" .. v end
        self:Refresh()
    end

    -- A on a faction raised here: its page in the Reputation tab.
    function page:OpenFaction(id)
        ns.UI.SelectTab("reputation")
        local frame = ns.UI.GetFrame()
        local rp = frame and frame.pages and frame.pages.reputation
        if rp and rp.OpenFaction and ns.Reputation and ns.Reputation.Get and ns.Reputation.Get(id) then rp:OpenFaction(id) end
    end

    -- A click: in the split it selects the instance and keeps focus in the list.
    function page:ClickInstance(key)
        if not self:Split() then return self:OpenInstance(key) end
        self.mode = "list"
        self.selKey = key
        self.pendingFocusKey = "d:" .. key
        self:Redraw()
    end

    -- Split: the page follows the focused instance. Bosses & loot: the loot follows the boss.
    function page:OnFocusChanged(item)
        -- The road: the preview follows focus, the strip keeps it in view, and up/down come back to it.
        if item and item.road and self.roadOn and self.mode == "list" then
            self.roadSel = item.entry.inst.key
            if self.roadRow then self.roadRow.home = item.road end
            if rd.layout and rd.layout.pts[item.road] then roadScrollTo(rd.layout.pts[item.road].x) end
            fillPreview(item.entry)
            return
        end
        if self:Split() and self.mode == "list" and item and item.entry and item.entry.inst.key ~= self.selKey then
            self.selKey = item.entry.inst.key
            fillPage(item.entry)
            for k, f in pairs(self.byKey or {}) do if f.SetSelected then f:SetSelected(k == self.selKey) end end
        elseif self.mode == "page" and item and item.bossIndex and item.bossIndex ~= self.selBoss and not self.following then
            self.selBoss = item.bossIndex
            repaintLoot()
            self.following = true
            local ok, err = pcall(ns.Focus.Rebuild)
            self.following = false
            if not ok then ns.Debug.Error("dungeons focus", err) end
        end
    end

    function page:SetFilter(value)
        settings().filter = value
        self.pendingFocusKey = "tb:filter:" .. value
        self:Redraw()
    end

    -- A view, keeping focus on the focused instance (or the toolbar button that chose it).
    function page:SetView(value, keepFocus)
        if Words.View(value) == "road" and self:View() ~= "road" then self.roadFresh = true end
        settings().view = value
        local cur = ns.Focus.Current()
        self.pendingFocusKey = (keepFocus and cur and cur.key) or ("tb:view:" .. Words.View(value))
        self:Redraw()
    end

    -- Y: Cards -> List -> Road -> Cards.
    function page:CycleView()
        if self.mode ~= "list" then return false end
        self:SetView(Words.NextView(settings().view), true)
        return true
    end

    -- Y: the catalogue's views in the list, the page's views on the page. X: the world map at
    -- the entrance zone (on the page).
    function page:OnButton(name)
        if name == "y" then
            if self.mode == "page" then return self:CyclePageView() end
            return self:CycleView()
        end
        if name == "x" and self.mode == "page" then
            local inst = self.pageEntry and self.pageEntry.inst
            return openMap(inst and inst.zones and inst.zones[1]) or true
        end
        return false
    end

    function page:GetHints()
        if self.mode == "list" then return { { "Y", "View" } } end
        local hints = { { "Y", "View" } }
        local inst = self.pageEntry and self.pageEntry.inst
        if inst and inst.zones and inst.zones[1] then hints[#hints + 1] = { "X", "World map" } end
        return hints
    end

    function page:GetFocusRows()
        if self.mode == "page" then return self.pageRows or {} end
        return self.focusRows or {}
    end

    -- Opens an instance's page from another tab (task 7): Zone Detail's "Dungeon here" tiles and
    -- the Reputation tab's dungeon and raid sources. B returns to `returnTo` ("zones" |
    -- "reputation"). The caller selects the Dungeons tab first. False when the catalogue isn't
    -- read yet (the tab then shows why).
    function page:OpenFrom(key, returnTo)
        if self.dirty then self.dirty = false; self:Redraw() end
        if self.mode == "page" then self.mode = "list" end
        self:OpenInstance(key)
        local opened = self.mode == "page" or (self:Split() and self.selKey == key)
        self.returnTo = returnTo
        self:Refresh()
        return opened
    end

    -- B: from the page back to the catalogue, on the same instance; opened from another tab,
    -- back to that tab (the instance stays selected here).
    function page:Back()
        local back = self.returnTo
        if back then
            self.returnTo = nil
            if self.mode == "page" then
                self.mode = "list"
                self.pendingFocusKey = self.selKey and ("d:" .. self.selKey)
                self:Refresh()
            end
            ns.UI.SelectTab(back)
            return true
        end
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

    -- The catalogue changed (the build, quests done, a level-up): redraw, keeping focus.
    local function changed()
        if not page:IsShown() then page.dirty = true; return end
        local cur = ns.UI.CurrentTab() == "dungeons" and ns.Focus.Current()
        if cur and page.pendingFocusKey == nil then page.pendingFocusKey = cur.key end
        page:Redraw()
    end
    -- Item details and bag counts only change the instance page (loot names, icons, quality,
    -- "in your bags", keys): repaint it where it shows, keeping focus and the scroll.
    local function pageChanged()
        if not (page:IsShown() and d:IsShown() and page.pageEntry) then return end
        local cur = ns.UI.CurrentTab() == "dungeons" and ns.Focus.Current()
        local keep = { bv.scroll:GetVerticalScroll(), bv.lootScroll:GetVerticalScroll(), qv.scroll:GetVerticalScroll(),
            ov.left.scroll:GetVerticalScroll() }
        fillPage(page.pageEntry)
        bv.scroll:SetVerticalScroll(keep[1]); bv.lootScroll:SetVerticalScroll(keep[2]); qv.scroll:SetVerticalScroll(keep[3])
        ov.left.scroll:SetVerticalScroll(keep[4])
        if cur and page.pendingFocusKey == nil then page.pendingFocusKey = cur.key end
        ns.Focus.Rebuild()
    end
    ns.Events.On("AZF_DUNGEONS_UPDATED", function(reason)
        if reason == "items" or reason == "bags" then return pageChanged() end
        changed()
    end)
    -- A new size (the window resized): the page lays out again.
    d:SetScript("OnSizeChanged", function(self, w, h)
        if not page.pageEntry or not self:IsShown() then return end
        if math.abs((page.pageWidth or 0) - (w or 0)) < 1 and math.abs((page.pageHeight or 0) + D.banner + P.switch - (h or 0)) < 1 then return end
        pageChanged()
    end)
    ns.Events.On("AZF_LEVEL_CHANGED", changed) -- "Your level", the level bars, quest states
    page:SetScript("OnShow", function(self)
        if self.dirty then self.dirty = false; self:Redraw() end
    end)
    -- Leaving the tab another way (LB/RB) forgets where B would have returned to.
    page:SetScript("OnHide", function(self) self.returnTo = nil end)

    -- The road at a new size: the strip scales to the new height; a new width keeps the scroll.
    rd:SetScript("OnSizeChanged", function(self, w, h)
        if not (page.roadOn and page:IsShown() and self:IsShown()) then return end
        if math.abs((page.roadDrawnH or 0) - (h or 0)) < 1 and math.abs((page.roadDrawnW or 0) - (w or 0)) < 1 then return end
        page.roadDrawnW, page.roadDrawnH = w, h
        changed()
    end)

    page.wide = ns.UI.IsWide()
    page:Redraw()
    local first = page.focusRows and page.focusRows[2] and page.focusRows[2].items[1]
    if page.roadOn and page.roadSel then page.pendingFocusKey = "d:" .. page.roadSel
    elseif first then page.pendingFocusKey = first.key end
    return page
end

-- Opens an instance's page from another tab; B comes back to `returnTo` (task 7). Returns true
-- when its page opened (false before the catalogue is read: the tab says why).
local function openFrom(key, returnTo)
    if not (key and ns.UI and ns.UI.SelectTab) then return false end
    ns.UI.SelectTab("dungeons")
    local frame = ns.UI.GetFrame()
    local dp = frame and frame.pages and frame.pages.dungeons
    if not (dp and dp.OpenFrom) then return false end
    return dp:OpenFrom(key, returnTo)
end

ns.DungeonsPage = { Words = Words, Open = openFrom,
    -- Shared with Zone Detail's tiles and the Zones cards (task 7).
    Pieces = { paintArt = paintArt, gradient = gradient, newTag = newTag, placeTags = placeTags,
        newQuestBar = newQuestBar, zoneName = zoneName } }

ns.UI.RegisterTab({
    id = "dungeons",
    label = "Dungeons",
    icon = ns.Theme.Icon("dungeons", "Interface\\Icons\\INV_Misc_Key_03"),
    order = 6,
    compactHeader = true,
    info = "Every dungeon and raid: its quests, bosses and levels.",
    build = build,
})
