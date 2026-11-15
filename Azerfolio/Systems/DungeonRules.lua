-- Dungeon rules (Dungeons tab, Phase 16 task 2; spec §7.12, §8.13; mockups/DESIGN.md "Dungeons
-- tab", rounds 1-8; the mockup's logic in mockups/app.js "Dungeons tab"). Everything the tab
-- decides: the instance catalogue (filters, level fit, level brackets, wings), each instance's
-- quests for this character (side and class), honest progress and its state, each quest's state
-- (ready, red, later, done), quest pickups grouped by place in chain order, each boss's own gear,
-- "For you" from Data/ClassGear.lua, and the factions the quests raise. Returns structured data;
-- the UI words it.
--
-- Honest data: an instance's progress is its quests only (done / counted for this character).
-- Boss kills have no history in the game and loot is a collection: neither is ever counted.
--
-- Pure: no WoW globals. Inputs are plain tables (Systems/Dungeons reads the game and QuestieDB);
-- data tables (ns.DungeonData, ns.QuestAreaData, ns.ClassGearData) are read when a function runs,
-- never at load, so tests and tools can load this file alone.
--
-- A quest, as Systems/Dungeons passes it (QuestieDB base fields, completion from Quests):
--   { id, name, level, reqLevel, side = "A" | "H" | nil (both), classMask = 0 | nil (any class),
--     reps = { { factionID, amount }, ... }, giver = place source, turnin = place source,
--     pre = { questID, ... } (the quests it needs first), done = true | nil }
-- A place source: { name, kind = "npc" | "object" | "item", area = areaID | areas = { areaID, ... } }
-- (an NPC's spawn areas; nil when where it starts isn't known).
-- A character: { level, faction = "Alliance" | "Horde", classFile = "PALADIN", classBit = 2^(classID - 1) }.
local _, ns = ...
ns = ns or {}

local Rules = {}
ns.DungeonRules = Rules

local function ddata() return ns.DungeonData or { instances = {} } end
local function qadata() return ns.QuestAreaData or { zone = {}, dungeon = {}, raid = {} } end
local function gdata() return ns.ClassGearData or { classes = {} } end

-- Is bit (a power of two) set in mask? Arithmetic: masks pass 2^32 (QuestRules.HasBit).
local function hasBit(mask, bit) return math.floor(mask / bit) % 2 == 1 end

-- ---------------------------------------------------------------------------------------------
-- Catalogue
-- ---------------------------------------------------------------------------------------------

-- The toolbar's filters, in order (DESIGN round 1).
Rules.FILTERS = { "all", "foryou", "dungeon", "raid", "forever" }

-- Level brackets: dungeons by the start of their range, then raids (DESIGN round 1).
Rules.BRACKETS = {
    { key = "13-19", from = 1, to = 19 },
    { key = "20-29", from = 20, to = 29 },
    { key = "30-39", from = 30, to = 39 },
    { key = "40-49", from = 40, to = 49 },
    { key = "50-60", from = 50, to = 62 },
    { key = "raids", raid = true },
}

-- A quest this many levels above you is red (the zone guide's colours).
Rules.RED = 5
-- A boss's item needs at least this many levels below the instance's range start (else it's an
-- old world item the NPC also drops).
Rules.GEAR_REACH = 12
-- An item more than this many NPCs drop is a world or trash drop: not the boss's own gear.
Rules.WORLD_DROP = 8
-- The Overview's "Pick up the quests" rows: at most this many (one fewer with keys), the last
-- one "More places" when there are more.
Rules.MAX_PLACES = 5

-- The zone guide's "For my level" rule (Zones, the Professions gather list): a range suits you
-- when it starts at most 3 above your level and ends at or above it.
function Rules.Fits(levels, level)
    if type(levels) ~= "table" or type(level) ~= "number" then return false end
    return levels[1] <= level + 3 and levels[2] >= level
end

-- Where your level sits against a range: "togo", n (levels to its start) | "below" (past its end) | "fit".
function Rules.FitState(levels, level)
    if level < levels[1] then return "togo", levels[1] - level end
    if level > levels[2] then return "below" end
    return "fit"
end

-- Does an instance pass a toolbar filter at this level?
function Rules.Matches(inst, filter, level)
    if filter == nil or filter == "all" then return true end
    if filter == "foryou" then return Rules.Fits(inst.levels, level) end
    if filter == "forever" then return inst.forever == true end
    return inst.kind == filter
end

-- The bracket an instance belongs to (an entry of Rules.BRACKETS).
function Rules.Bracket(inst)
    if inst.kind == "raid" then return Rules.BRACKETS[#Rules.BRACKETS] end
    for _, b in ipairs(Rules.BRACKETS) do
        if not b.raid and inst.levels[1] >= b.from and inst.levels[1] <= b.to then return b end
    end
    return Rules.BRACKETS[#Rules.BRACKETS - 1]
end

-- The wings of an instance's group in data order (Scarlet Monastery, Dire Maul, Blackrock
-- Spire); just the instance when it has no group.
function Rules.Wings(inst, data)
    if not inst.group then return { inst } end
    local out = {}
    for _, i in ipairs((data or ddata()).instances) do
        if i.group == inst.group then out[#out + 1] = i end
    end
    return out
end

-- ---------------------------------------------------------------------------------------------
-- Quests and progress
-- ---------------------------------------------------------------------------------------------

local function sideOf(char)
    local f = char and char.faction
    if f == "Alliance" or f == "A" then return "A" end
    if f == "Horde" or f == "H" then return "H" end
    return nil
end

-- Is a quest for this character's side and class? (Race masks are per side here: QuestieDB's
-- dungeon quests are faction-wide; Systems/Dungeons reduces the race mask to a side.)
function Rules.ForCharacter(q, char)
    local side = sideOf(char)
    if q.side and q.side ~= "" and q.side ~= side then return false end
    local mask = q.classMask
    if type(mask) == "number" and mask > 0 then
        if not (char and char.classBit) or not hasBit(mask, char.classBit) then return false end
    end
    return true
end

-- The guide's colour for a quest level against yours: red / orange / yellow / green / grey.
function Rules.Difficulty(questLevel, level)
    local d = (questLevel or 0) - level
    if d >= Rules.RED then return "red" end
    if d >= 3 then return "orange" end
    if d >= -2 then return "yellow" end
    if d >= -5 then return "green" end
    return "grey"
end

-- A quest's state for you: "done" | "later" (opens at a higher level) | "red" (ready, but 5 or
-- more levels above you) | "ready".
function Rules.QuestState(q, level)
    if q.done then return "done" end
    if (q.reqLevel or 0) > level then return "later" end
    if Rules.Difficulty(q.level, level) == "red" then return "red" end
    return "ready"
end

-- An instance's progress for this character, from its quests (all sides; nil when the quest
-- index isn't built). Returns
--   { quests (this character's), total, done, state, none, counts = { ready, red, later, done } }
-- state: "untracked" (no quests for you) | "untouched" | "progress" | "complete";
-- none, when total is 0: "unmapped" (the instance has no quest area) | "side" (quests, none for
-- your side and class) | "none" (no quests).
function Rules.Progress(inst, quests, char)
    local mine, done = {}, 0
    local counts = { ready = 0, red = 0, later = 0, done = 0 }
    for _, q in ipairs(quests or {}) do
        if Rules.ForCharacter(q, char) then
            mine[#mine + 1] = q
            local s = Rules.QuestState(q, char.level)
            counts[s] = counts[s] + 1
            if q.done then done = done + 1 end
        end
    end
    local total = #mine
    local p = { quests = mine, total = total, done = done, counts = counts }
    if total == 0 then
        p.state = "untracked"
        p.none = not inst.questArea and "unmapped" or (quests and #quests > 0) and "side" or "none"
    elseif done == total then p.state = "complete"
    elseif done > 0 then p.state = "progress"
    else p.state = "untouched" end
    return p
end

-- One catalogue entry: { inst, fit, bracket, progress }.
function Rules.Entry(inst, quests, char)
    return { inst = inst, fit = Rules.Fits(inst.levels, char.level), bracket = Rules.Bracket(inst),
        progress = Rules.Progress(inst, quests, char) }
end

-- The catalogue: every instance in data order with its entry; questsByArea[questArea] is the
-- instance's quest list (wings share their area's quests). Returns all, shown (the filter's).
function Rules.Catalogue(char, questsByArea, filter, data)
    local all, shown = {}, {}
    for _, inst in ipairs((data or ddata()).instances) do
        local e = Rules.Entry(inst, inst.questArea and questsByArea and questsByArea[inst.questArea], char)
        all[#all + 1] = e
        if Rules.Matches(inst, filter, char.level) then shown[#shown + 1] = e end
    end
    return all, shown
end

-- Entries under their bracket headers, empty brackets left out. Each group:
-- { bracket, entries, withQuests (entries with quests for you), complete (of those, every quest done) }.
function Rules.Groups(entries)
    local out = {}
    for _, b in ipairs(Rules.BRACKETS) do
        local g = { bracket = b, entries = {}, withQuests = 0, complete = 0 }
        for _, e in ipairs(entries) do
            if e.bracket == b then
                g.entries[#g.entries + 1] = e
                if e.progress.total > 0 then g.withQuests = g.withQuests + 1 end
                if e.progress.state == "complete" then g.complete = g.complete + 1 end
            end
        end
        if #g.entries > 0 then out[#out + 1] = g end
    end
    return out
end

-- ---------------------------------------------------------------------------------------------
-- Places: where a quest starts (or ends)
-- ---------------------------------------------------------------------------------------------

-- A context for places: which areas belong to which instance (its quest area and its bosses'
-- spawn areas; NPC spawn areas differ from quest areas: Dire Maul 10022-10027, Blackrock
-- Depths 1585). spawnAreas[npcID] = { areaID, ... } (nil when QuestieDB isn't there).
function Rules.PlaceContext(spawnAreas, data, questAreas)
    local owner = {}
    for _, inst in ipairs((data or ddata()).instances) do
        if inst.questArea and not owner[inst.questArea] then owner[inst.questArea] = inst end
        for _, b in ipairs(inst.bosses or {}) do
            for _, n in ipairs(b.npcs or {}) do
                for _, a in ipairs(spawnAreas and spawnAreas[n] or {}) do
                    if not owner[a] then owner[a] = inst end
                end
            end
        end
    end
    return { owner = owner, qa = questAreas or qadata() }
end

local function sameGroup(a, b)
    return a == b or (a.group ~= nil and a.group == b.group)
end

local function sourceArea(src)
    if type(src.area) == "number" then return src.area end
    if type(src.areas) == "table" then
        local best
        for _, a in ipairs(src.areas) do if not best or a < best then best = a end end
        return best
    end
    return nil
end

-- Where a place source is, for an instance. Returns
--   { key, kind, mapID?, area?, instance? }
-- kind: "zone" (mapID, via Data/QuestAreas.lua) | "inside" (this instance or a wing of it) |
-- "instance" (inside another instance: `instance`) | "object" | "item" |
-- "area" (an area Azerfolio doesn't map: the client names it, C_Map.GetAreaInfo) | "unknown".
function Rules.Place(src, inst, ctx)
    if type(src) ~= "table" then return { key = "unknown", kind = "unknown" } end
    if src.kind == "object" or src.kind == "item" then return { key = src.kind, kind = src.kind } end
    local a = sourceArea(src)
    if not a or a == 0 then return { key = "unknown", kind = "unknown" } end
    local qa = ctx.qa
    local o = ctx.owner[a]
    if o then
        if sameGroup(o, inst) then return { key = "inside", kind = "inside", area = a } end
        return { key = "i:" .. o.key, kind = "instance", instance = o, area = a }
    end
    if (qa.dungeon and qa.dungeon[a]) or (qa.raid and qa.raid[a]) then
        return { key = "inside", kind = "inside", area = a }
    end
    local mapID = qa.zone and qa.zone[a]
    if mapID then return { key = "z:" .. mapID, kind = "zone", mapID = mapID, area = a } end
    return { key = "a:" .. a, kind = "area", area = a }
end

-- ---------------------------------------------------------------------------------------------
-- Quest views and pickups
-- ---------------------------------------------------------------------------------------------

-- Quests in chain order: by level (then ID), each placed after any quest of the list it needs.
function Rules.ChainOrder(quests)
    local list = {}
    for i, q in ipairs(quests) do list[i] = q end
    table.sort(list, function(a, b)
        if (a.level or 0) ~= (b.level or 0) then return (a.level or 0) < (b.level or 0) end
        return a.id < b.id
    end)
    local inList, placed, out = {}, {}, {}
    for _, q in ipairs(list) do inList[q.id] = true end
    while #out < #list do
        local pick
        for _, q in ipairs(list) do
            if not placed[q.id] then
                local ready = true
                for _, p in ipairs(q.pre or {}) do
                    if inList[p] and not placed[p] and p ~= q.id then ready = false; break end
                end
                if ready then pick = q; break end
            end
        end
        if not pick then -- a loop in the data: take the first left
            for _, q in ipairs(list) do if not placed[q.id] then pick = q; break end end
        end
        placed[pick.id] = true
        out[#out + 1] = pick
    end
    return out
end

-- One quest for the page: { quest, state, place, pre (IDs it needs), preHere (of those, the
-- ones in this instance's list), turnin (place, when the turn-in is someone else), turninPlace
-- (true when it's turned in at another place) }.
function Rules.QuestView(q, inst, char, ctx, here)
    local v = { quest = q, state = Rules.QuestState(q, char.level), place = Rules.Place(q.giver, inst, ctx),
        pre = q.pre or {}, preHere = {} }
    for _, p in ipairs(v.pre) do if here and here[p] then v.preHere[#v.preHere + 1] = p end end
    local g, t = q.giver, q.turnin
    if type(t) == "table" and type(g) == "table" and t.name ~= g.name then
        v.turnin = Rules.Place(t, inst, ctx)
        v.turninPlace = v.turnin.key ~= v.place.key
    end
    return v
end

local FILTER_QUEST = {
    open = function(q) return not q.done end,
    done = function(q) return q.done == true end,
    all = function() return true end,
}

-- This character's quests grouped by where you pick them up (the Quests view): filter "open"
-- (To do) | "done" | "all". Groups in order of their lowest quest; quests in chain order.
-- Each group: { key, kind, mapID?, area?, instance?, quests = { view, ... }, givers = { name, ... } }.
function Rules.QuestGroups(progress, inst, char, ctx, filter)
    local keep = FILTER_QUEST[filter or "open"] or FILTER_QUEST.open
    local here = {}
    for _, q in ipairs(progress.quests) do here[q.id] = true end
    local groups, byKey = {}, {}
    for _, q in ipairs(Rules.ChainOrder(progress.quests)) do
        if keep(q) then
            local v = Rules.QuestView(q, inst, char, ctx, here)
            local p = v.place
            local g = byKey[p.key]
            if not g then
                g = { key = p.key, kind = p.kind, mapID = p.mapID, area = p.area, instance = p.instance,
                    quests = {}, givers = {}, seen = {} }
                byKey[p.key] = g
                groups[#groups + 1] = g
            end
            g.quests[#g.quests + 1] = v
            local giver = q.giver
            if type(giver) == "table" and giver.kind == "npc" and giver.name and not g.seen[giver.name] then
                g.seen[giver.name] = true
                g.givers[#g.givers + 1] = giver.name
            end
        end
    end
    for _, g in ipairs(groups) do g.seen = nil end
    return groups
end

-- The Overview's "Pick up the quests": the open quests' places, the most quests first (ties
-- keep the Quests view's order). At most MAX_PLACES rows (one fewer when the instance has keys);
-- with more, the last row is "More places". Returns shown, more (the places behind "More
-- places", or nil), all.
function Rules.Pickups(progress, inst, char, ctx)
    local groups = Rules.QuestGroups(progress, inst, char, ctx, "open")
    local order = {}
    for i, g in ipairs(groups) do order[g] = i end
    table.sort(groups, function(a, b)
        if #a.quests ~= #b.quests then return #a.quests > #b.quests end
        return order[a] < order[b]
    end)
    local max = Rules.MAX_PLACES - ((inst.keys and #inst.keys > 0) and 1 or 0)
    if #groups <= max then return groups, nil, groups end
    local shown, more = {}, {}
    for i, g in ipairs(groups) do
        if i < max then shown[#shown + 1] = g else more[#more + 1] = g end
    end
    return shown, more, groups
end

-- ---------------------------------------------------------------------------------------------
-- Loot
-- ---------------------------------------------------------------------------------------------

-- Is an item gear (weapon or armour)? items[itemID] = { class, subclass, reqLevel, ... }.
local function isGear(info) return info and (info.class == 2 or info.class == 4) end

-- Each NPC's own gear: npcDrops[itemID] = { npcID, ... } (QuestieDB's npcDrops). Weapons and
-- armour only; an item more than WORLD_DROP NPCs drop is left out (a world drop). Returns
-- byNpc[npcID] = { itemID, ... } (ascending).
function Rules.DropsByNpc(npcDrops, items)
    local byNpc = {}
    for itemID, npcList in pairs(npcDrops or {}) do
        if type(npcList) == "table" and #npcList <= Rules.WORLD_DROP and isGear(items[itemID]) then
            for _, n in ipairs(npcList) do
                byNpc[n] = byNpc[n] or {}
                byNpc[n][#byNpc[n] + 1] = itemID
            end
        end
    end
    for _, l in pairs(byNpc) do table.sort(l) end
    return byNpc
end

-- A boss's own gear: its NPCs' drops (byNpc from DropsByNpc), each item once, required level at
-- least the instance's range start minus GEAR_REACH. Returns { itemID, ... } (ascending).
function Rules.BossGear(inst, boss, byNpc, items)
    local out, seen = {}, {}
    local floor = inst.levels[1] - Rules.GEAR_REACH
    for _, n in ipairs(boss.npcs or {}) do
        for _, id in ipairs(byNpc[n] or {}) do
            local info = items[id]
            if not seen[id] and isGear(info) and (info.reqLevel or 0) >= floor then
                seen[id] = true
                out[#out + 1] = id
            end
        end
    end
    table.sort(out)
    return out
end

-- The armour type a class wants at a level (Data/ClassGear.lua), or nil for a class we don't know.
function Rules.ArmorFor(classFile, level, gear)
    local c = (gear or gdata()).classes[classFile]
    if not c then return nil end
    local sub
    for _, a in ipairs(c.armor) do if a.from <= level then sub = a.sub end end
    return sub
end

-- "For you": armour the class wants (its best type at the item's level or yours, whichever is
-- higher), jewellery and cloaks, shields and its relic; weapons it can learn. A class the table
-- doesn't know sees everything (true). Cloaks are cloth (subclass 1) in the item data: they're
-- told apart by the slot, info.equipLoc = "INVTYPE_CLOAK" (C_Item, read by Systems/Dungeons);
-- until the slot is known a cloak counts as cloth.
function Rules.ForYou(info, classFile, level, gear)
    local c = (gear or gdata()).classes[classFile]
    if not c then return true end
    if not isGear(info) then return false end
    local sub = info.subclass
    if info.class == 2 then
        for _, w in ipairs(c.weapons) do if w == sub then return true end end
        return false
    end
    if sub == 0 or info.equipLoc == "INVTYPE_CLOAK" then return true end
    if sub == 6 then return c.shield == true end
    if sub == 7 or sub == 8 or sub == 9 then return c.relic == sub end
    return sub == Rules.ArmorFor(classFile, math.max(level, info.reqLevel or 0), gear)
end

-- ---------------------------------------------------------------------------------------------
-- Rewards
-- ---------------------------------------------------------------------------------------------

-- The factions this character's quests here raise: positive rewards summed per faction, the most
-- first (ties by faction ID). Returns { { factionID, amount, quests }, ... } (QuestieDB base values).
function Rules.Factions(quests)
    local by, out = {}, {}
    for _, q in ipairs(quests or {}) do
        for _, r in ipairs(q.reps or {}) do
            local fid, amt = r[1], r[2]
            if type(fid) == "number" and type(amt) == "number" and amt > 0 then
                local e = by[fid]
                if not e then e = { factionID = fid, amount = 0, quests = 0 }; by[fid] = e; out[#out + 1] = e end
                e.amount = e.amount + amt
                e.quests = e.quests + 1
            end
        end
    end
    table.sort(out, function(a, b)
        if a.amount ~= b.amount then return a.amount > b.amount end
        return a.factionID < b.factionID
    end)
    return out
end

return Rules
