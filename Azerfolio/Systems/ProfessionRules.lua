-- Profession rules (Professions tab, Phase 14; spec §7.11, §8.12; mockups/DESIGN.md
-- "Professions tab"). Everything the tab and the Overview panel decide: a profession's rank,
-- next rank and status, the skill road's stones, each recipe's state and sources, the honest
-- counts, the filters, levelling order, ingredients (have / need, where to get each), where to
-- gather, and Next up. Returns structured data; the UI words it.
--
-- Honest data: a recipe is counted only when it's known or has a known source (seen at a
-- trainer, or a QuestieDB recipe item); the rest, Season of Discovery included, is "nosource"
-- and never counted. A learn-at skill is only what a trainer said (or a recipe item's tooltip,
-- when recorded); otherwise it stays nil. Recipes never count toward Mastered.
--
-- Pure: no WoW globals. Data tables (ns.ProfessionData, ns.GatheringData, ns.ZoneData) are read
-- when a function runs, never at load, so tests and tools can load this file alone.
local _, ns = ...
ns = ns or {}

local Rules = {}
ns.ProfessionRules = Rules

local function pdata() return ns.ProfessionData or { maxSkill = 300, ranks = {}, skills = {}, seasonCategories = {} } end
local function gdata() return ns.GatheringData or {} end

-- "For you now" also shows what opens in the next this many skill points (DESIGN round 2).
Rules.SOON = 25
-- Next up holds at most this many lines.
Rules.NEXT_UP = 5

-- The profession's facts by skill line (nil for a line we don't know).
function Rules.Info(skillLine) return pdata().skills[skillLine] end

-- Pure: the rank a cap belongs to: the highest rank whose cap is at most `cap`. Returns rank,
-- index; nil when the cap is unknown or below every rank.
function Rules.RankFor(cap)
    if type(cap) ~= "number" then return nil end
    local found, idx
    for i, r in ipairs(pdata().ranks) do
        if r.cap <= cap then found, idx = r, i end
    end
    return found, idx
end

-- Pure: the next rank above `cap` (nil at the top, or when the cap is unknown).
function Rules.NextRank(cap)
    if type(cap) ~= "number" then return nil end
    for _, r in ipairs(pdata().ranks) do
        if r.cap > cap then return r end
    end
    return nil
end

-- Pure: "Apprentice Blacksmith"; First Aid reads "Apprentice in First Aid" (the mockup's title).
function Rules.Title(info, rank)
    if not rank or not info then return nil end
    if info.key == "firstaid" then return rank.name .. " in First Aid" end
    return rank.name .. " " .. info.noun
end

-- Pure: a profession from GetProfessionInfo's values.
--   entry = { skillLine, name, skill, cap, icon }
-- Returns { skillLine, key, name, kind, role, gather, hasRecipes, icon, skill, cap, rank, title,
--   next, mastered, atCap, trainNow, togo } (togo: skill to the next rank's training; 0 when you
--   can train it). Unknown skill or cap leaves the derived fields nil/false.
function Rules.Profession(entry)
    local P = pdata()
    local info = Rules.Info(entry.skillLine) or {}
    local skill = type(entry.skill) == "number" and entry.skill or nil
    local cap = type(entry.cap) == "number" and entry.cap > 0 and entry.cap or nil
    local rank = Rules.RankFor(cap)
    local nxt = Rules.NextRank(cap)
    local m = {
        skillLine = entry.skillLine, key = info.key, name = entry.name or info.name, kind = info.kind or "primary",
        role = info.role, gather = info.gather, icon = entry.icon, skill = skill, cap = cap, rank = rank,
        title = Rules.Title(info, rank), next = nxt, mastered = false, atCap = false, trainNow = false,
        hasRecipes = info.role == "crafting" or info.role == "both",
    }
    if skill and skill >= P.maxSkill then
        m.mastered = true
        m.next = nil
    elseif skill and cap and nxt then
        m.atCap = skill >= cap
        m.trainNow = skill >= nxt.at
        m.togo = math.max(0, nxt.at - skill)
    end
    return m
end

-- Pure: the skill road's stones, one per rank you train (every rank after the first):
--   { { rank, at, cap, state = "trained" | "now" | "later" } ... }
-- trained: your cap is at least its cap; now: it's the next rank and your skill reaches it.
function Rules.Stones(skill, cap)
    local out = {}
    local nxt = Rules.NextRank(cap)
    for i, r in ipairs(pdata().ranks) do
        if i > 1 then
            local state = "later"
            if type(cap) == "number" and cap >= r.cap then state = "trained"
            elseif nxt == r and type(skill) == "number" and skill >= r.at then state = "now" end
            out[#out + 1] = { rank = r, at = r.at, cap = r.cap, state = state }
        end
    end
    return out
end

-- Pure: a recipe item's recipe name: "Plans: Copper Chain Belt" -> "Copper Chain Belt" (any
-- one word before the colon; qdb.lua gather check). nil for a name without one.
function Rules.RecipeNameOfItem(itemName)
    if type(itemName) ~= "string" then return nil end
    return itemName:match("^[%a']+: (.+)$")
end

-- Pure: a recipe item's sources (QuestieDB fields, already read):
--   item = { vendors = { { npc, maps } ... }, drops = { { npc?, maps } ... } or n, objects = n,
--            quests = n, learnAt = n? }
-- Returns source entries { kind = "vendor"|"drop"|"object"|"quest"|"item", ... } in that
-- order; "item" alone when the recipe item exists but QuestieDB names no place.
function Rules.ItemSources(item)
    local out = {}
    if type(item) ~= "table" then return out end
    for _, v in ipairs(item.vendors or {}) do
        out[#out + 1] = { kind = "vendor", npc = v.npc, maps = v.maps or {} }
    end
    local drops = item.drops
    if type(drops) == "table" and #drops > 0 then
        local maps, seen = {}, {}
        for _, d in ipairs(drops) do
            for _, m in ipairs(d.maps or {}) do if not seen[m] then seen[m] = true; maps[#maps + 1] = m end end
        end
        out[#out + 1] = { kind = "drop", n = #drops, maps = maps }
    elseif type(drops) == "number" and drops > 0 then
        out[#out + 1] = { kind = "drop", n = drops, maps = item.dropMaps or {} }
    end
    if type(item.objects) == "number" and item.objects > 0 then out[#out + 1] = { kind = "object", n = item.objects } end
    if type(item.quests) == "number" and item.quests > 0 then out[#out + 1] = { kind = "quest", n = item.quests } end
    if #out == 0 then out[1] = { kind = "item" } end
    return out
end

local function byOrder(a, b)
    if a.order ~= b.order then return a.order < b.order end
    if a.name ~= b.name then return (a.name or "") < (b.name or "") end
    return (a.id or 0) < (b.id or 0)
end

-- Pure: the recipe collection of one profession.
--   rows = the recorded window list { { id, name, learned, grey, category } ... }
--   opts = {
--     skill = your skill now,
--     trainer = { [recipe name] = skill to learn } from recorded trainer lists,
--     items = { [recipe name] = item (see ItemSources) } matched recipe items,
--     known = function(id) -> true/false/nil: live learned state (IsPlayerSpell); nil = use `learned`,
--     tracked = { [id] = true } the game's tracked recipes,
--   }
-- Returns { list = { recipe ... } in levelling order, counts = { known, now, later, nosource, sod,
--   all (= counted: everything but nosource), total, foryou } }.
-- A recipe: { id, name, category, known, grey, sod, sources, learnAt, state, order, givesSkill,
--   tracked } with state "known" | "now" | "later" | "nosource".
-- Levelling order (owner, 2026-11-13): by the skill to learn it where a trainer says, else the
-- skill where it greys; unknown last; then by name.
function Rules.Recipes(rows, opts)
    opts = opts or {}
    local sodCats = pdata().seasonCategories or {}
    local skill = opts.skill
    local trainer, items, tracked = opts.trainer or {}, opts.items or {}, opts.tracked or {}
    local list = {}
    local counts = { known = 0, now = 0, later = 0, nosource = 0, sod = 0, all = 0, total = 0, foryou = 0 }
    for _, row in ipairs(rows or {}) do
        local known = row.learned and true or false
        if opts.known then
            local live = opts.known(row.id)
            if live ~= nil then known = live and true or false end
        end
        local grey = type(row.grey) == "number" and row.grey > 0 and row.grey or nil
        local sod = sodCats[row.category] and true or false
        local sources = {}
        local tSkill = trainer[row.name]
        if type(tSkill) == "number" then sources[1] = { kind = "trainer", skill = tSkill } end
        local item = items[row.name]
        if item and not sod then
            for _, s in ipairs(Rules.ItemSources(item)) do sources[#sources + 1] = s end
        end
        local learnAt = type(tSkill) == "number" and tSkill or (item and type(item.learnAt) == "number" and item.learnAt) or nil
        local state
        if known then state = "known"
        elseif sod or #sources == 0 then state = "nosource"
        elseif learnAt and type(skill) == "number" and skill >= learnAt then state = "now"
        else state = "later" end
        local r = {
            id = row.id, name = row.name, category = row.category, categoryName = row.categoryName, known = known,
            grey = grey, sod = sod, sources = sources, learnAt = learnAt, state = state,
            order = learnAt or grey or math.huge, tracked = tracked[row.id] and true or false,
            givesSkill = known and grey ~= nil and type(skill) == "number" and skill < grey or false,
        }
        list[#list + 1] = r
        counts.total = counts.total + 1
        counts[state] = counts[state] + 1
        if sod then counts.sod = counts.sod + 1 end
        if state ~= "nosource" then counts.all = counts.all + 1 end
    end
    table.sort(list, byOrder)
    for _, r in ipairs(list) do
        if Rules.ForYou(r, skill) then counts.foryou = counts.foryou + 1 end
    end
    return { list = list, counts = counts }
end

-- Pure: is a recipe "For you now"? Learn now, known and still giving skill, or opening within
-- the next SOON points. Only a known learn-at skill can say "opens soon" (the mockup also used
-- the grey-at skill when the learn-at was unknown; that would claim a skill the game never gave).
function Rules.ForYou(r, skill)
    if r.state == "now" or r.givesSkill then return true end
    return r.state == "later" and r.learnAt ~= nil and type(skill) == "number" and r.learnAt <= skill + Rules.SOON
end

Rules.FILTERS = { "foryou", "all", "known", "now", "later", "nosource" }

-- Pure: the recipes under one filter, still in levelling order.
function Rules.Filter(recipes, filter, skill)
    local out = {}
    for _, r in ipairs(recipes.list or {}) do
        local keep
        if filter == "foryou" then keep = Rules.ForYou(r, skill)
        elseif filter == "all" then keep = r.state ~= "nosource"
        else keep = r.state == filter end
        if keep then out[#out + 1] = r end
    end
    return out
end

-- Pure: the one status tag, most urgent first:
--   mastered > atcap > trainnow > learn (n recipes) > unread (window not read yet) > nil.
-- recipes: Rules.Recipes' result, or nil when the profession's window hasn't been read.
function Rules.Status(m, recipes)
    if m.mastered then return { kind = "mastered" } end
    if m.atCap and m.next then return { kind = "atcap", rank = m.next } end
    if m.trainNow and m.next then return { kind = "trainnow", rank = m.next } end
    if recipes and recipes.counts.now > 0 then return { kind = "learn", n = recipes.counts.now } end
    if m.hasRecipes and not recipes then return { kind = "unread" } end
    return nil
end

-- Pure: the rail and Overview order: primary first, then secondary; by name in each.
function Rules.Order(models)
    local out = {}
    for i, m in ipairs(models or {}) do out[i] = m end
    table.sort(out, function(a, b)
        if a.kind ~= b.kind then return a.kind == "primary" end
        return (a.name or "") < (b.name or "")
    end)
    return out
end

-- Pure: "n of m mastered" for the Overview.
function Rules.Summary(models)
    local n = 0
    for _, m in ipairs(models or {}) do if m.mastered then n = n + 1 end end
    return { mastered = n, total = #(models or {}) }
end

-- Pure: item ID -> the gathering node that gives it (the lowest-skill node), from
-- Data/Gathering.lua's mining and herbalism tables.
function Rules.NodesByItem()
    local G, out = gdata(), {}
    for _, kind in ipairs({ "mining", "herbalism" }) do
        for _, node in ipairs(G[kind] or {}) do
            for _, id in ipairs(node.items or {}) do
                local cur = out[id]
                if not cur or (node.skill or math.huge) < (cur.skill or math.huge) then out[id] = node end
            end
        end
    end
    return out
end

-- Pure: where to get one reagent, first match wins:
--   craft (another recipe of this profession makes it), gather (a node gives it), vendor,
--   drop, unknown.
-- ctx = { craftedBy = { [itemID] = recipe }, nodes = Rules.NodesByItem(),
--         sources = { [itemID] = { vendors = { { npc, maps } ... }, drops = n } } }
function Rules.ReagentSource(itemID, ctx)
    ctx = ctx or {}
    local craft = ctx.craftedBy and ctx.craftedBy[itemID]
    if craft then return { kind = "craft", recipe = craft } end
    local node = ctx.nodes and ctx.nodes[itemID]
    if node then return { kind = "gather", node = node } end
    local s = ctx.sources and ctx.sources[itemID]
    if s and s.vendors and #s.vendors > 0 then
        return { kind = "vendor", vendor = s.vendors[1], more = #s.vendors - 1 }
    end
    if s and type(s.drops) == "number" and s.drops > 0 then return { kind = "drop", n = s.drops } end
    return { kind = "unknown" }
end

-- Pure: a recipe's ingredients with have / need.
--   reagents = { { itemID, need, name? } ... } (GetRecipeSchematic)
--   ctx = ReagentSource's ctx plus have = { [itemID] = n } (C_Item.GetItemCount; missing = unknown)
-- Returns { items = { { itemID, name, need, have, ok, where } ... }, missing = n (known short),
--   unknown = any count unknown, ready = you carry enough of everything for one }.
function Rules.Reagents(reagents, ctx)
    ctx = ctx or {}
    local have = ctx.have or {}
    local out = { items = {}, missing = 0, unknown = false, ready = false }
    for _, g in ipairs(reagents or {}) do
        local h = have[g.itemID]
        h = type(h) == "number" and h or nil
        local ok = h ~= nil and h >= (g.need or 1)
        if h == nil then out.unknown = true elseif not ok then out.missing = out.missing + 1 end
        out.items[#out.items + 1] = { itemID = g.itemID, name = g.name, need = g.need or 1, have = h, ok = ok,
            where = Rules.ReagentSource(g.itemID, ctx) }
    end
    out.ready = #out.items > 0 and out.missing == 0 and not out.unknown
    return out
end

-- Pure: the skill a mob of `level` needs for skinning (the inverse of Data/Gathering.lua's
-- rule: up to skill 100 you skin up to skill / 10 + 10, then skill / 5). At least 1.
function Rules.SkinningSkill(level)
    local s = gdata().skinning or { lowUntil = 100, lowDiv = 10, lowAdd = 10, highDiv = 5 }
    local seamLevel = s.lowUntil / s.lowDiv + s.lowAdd
    local need
    if level <= seamLevel then need = (level - s.lowAdd) * s.lowDiv else need = level * s.highDiv end
    return math.max(1, need)
end

local function nodeState(from, skill, greyAfter, to)
    if from == nil then return "unknown" end
    if type(skill) ~= "number" then return "unknown" end
    if skill < from then return "later" end
    if skill >= (to or from) + greyAfter then return "grey" end
    return "gives"
end

-- Pure: the Gather view's rows and the node you're on and the next.
--   kind = "mining" | "herbalism" | "skinning" | "fishing"
--   zoneLevels = Data/Zones.lua's levels (skinning only)
-- Returns { rows = { { name?, mapID?, from, to?, zones, state, togo?, greyAt?, alt?, src? } ... },
--   current = row or nil, nextRow = row or nil, fishing = bool }.
-- States: gives / later / grey / unknown; fishing brackets: current / later / earlier (no grey:
-- the brackets are good places, not requirements).
function Rules.Gather(kind, skill, zoneLevels)
    local G = gdata()
    local greyAfter = G.greyAfter or 100
    local rows, current, nextRow = {}, nil, nil
    if kind == "fishing" then
        for _, b in ipairs(G.fishing or {}) do
            rows[#rows + 1] = { name = b.name, from = b.skill, zones = b.zones, state = "later" }
        end
        for i, r in ipairs(rows) do
            if type(skill) == "number" and r.from <= skill then current = r; current.index = i
            elseif not nextRow then nextRow = r end
        end
        for _, r in ipairs(rows) do
            if r == current then r.state = "current"
            elseif type(skill) == "number" and r.from <= skill then r.state = "earlier"
            elseif type(skill) == "number" then r.togo = r.from - skill end
            if type(skill) ~= "number" then r.state = "unknown" end
        end
        return { rows = rows, current = current, nextRow = nextRow, fishing = true }
    end
    if kind == "skinning" then
        for mapID, lv in pairs(zoneLevels or {}) do
            local from, to = Rules.SkinningSkill(lv[1]), Rules.SkinningSkill(lv[2])
            rows[#rows + 1] = { mapID = mapID, from = from, to = to, zones = { mapID }, greyAt = to + greyAfter }
        end
        table.sort(rows, function(a, b)
            if a.from ~= b.from then return a.from < b.from end
            if a.to ~= b.to then return a.to < b.to end
            return a.mapID < b.mapID
        end)
    else
        for _, node in ipairs(G[kind] or {}) do
            rows[#rows + 1] = { name = node.name, from = node.skill, zones = node.zones or {}, alt = node.alt, src = node.src,
                greyAt = node.skill and node.skill + greyAfter or nil }
        end
    end
    for _, r in ipairs(rows) do
        r.state = nodeState(r.from, skill, greyAfter, r.to)
        if r.state == "later" then r.togo = r.from - skill end
        if r.from and type(skill) == "number" then
            if r.from <= skill and r.state == "gives" then current = r end -- the highest one still giving skill
            if r.from > skill and not nextRow then nextRow = r end
        end
    end
    return { rows = rows, current = current, nextRow = nextRow, fishing = false }
end

-- Pure: Next up (up to NEXT_UP lines), in this order:
--   { kind = "mastered" }
--   { kind = "rank", rank, togo, now = bool, atCap = bool }
--   { kind = "learn", n, recipes = up to 3 }                        -> Recipes, Learn now
--   { kind = "skillup", recipes = up to 2 (highest grey first) }    -> Recipes, For you now
--   { kind = "gather", row } (not fishing)                          -> Gather
--   { kind = "gathernext", row, togo, fishing = bool }              -> Gather
--   { kind = "unread" }
-- m = Rules.Profession; recipes = Rules.Recipes or nil (not read); gather = Rules.Gather or nil.
function Rules.NextUp(m, recipes, gather)
    local items = {}
    if m.mastered then
        items[#items + 1] = { kind = "mastered" }
    elseif m.next and m.skill then
        items[#items + 1] = { kind = "rank", rank = m.next, togo = m.togo or 0, now = m.trainNow, atCap = m.atCap }
    end
    if recipes then
        local now, ups = {}, {}
        for _, r in ipairs(recipes.list) do
            if r.state == "now" and #now < 3 then now[#now + 1] = r end
            if r.givesSkill then ups[#ups + 1] = r end
        end
        if recipes.counts.now > 0 then items[#items + 1] = { kind = "learn", n = recipes.counts.now, recipes = now } end
        table.sort(ups, function(a, b) if a.grey ~= b.grey then return a.grey > b.grey end return a.name < b.name end)
        if #ups > 0 then items[#items + 1] = { kind = "skillup", recipes = { ups[1], ups[2] } } end
    end
    if gather then
        if gather.current and not gather.fishing then items[#items + 1] = { kind = "gather", row = gather.current } end
        if gather.nextRow then
            items[#items + 1] = { kind = "gathernext", row = gather.nextRow, togo = gather.nextRow.togo, fishing = gather.fishing }
        end
    end
    if m.hasRecipes and not recipes then items[#items + 1] = { kind = "unread" } end
    while #items > Rules.NEXT_UP do table.remove(items) end
    return items
end

return Rules
