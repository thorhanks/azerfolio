-- Zone factions (Phase 11, spec §8.9): which factions belong to a zone, derived from the
-- reputation rewards of the zone's quests (QuestieDB's reputationReward, {{factionID, amount},
-- ...}). No hand-curated table (owner, 2026-11-08; docs/research/reputation.md).
--
-- Rule: count, per zone and faction, the quests that RAISE the faction (amount > 0). Leave out
-- home factions (capitals, races, the Alliance/Horde groups) and battleground factions. Keep a
-- faction with at least MIN raising quests in the zone, or at least LOW when the zone holds at
-- least SHARE of the faction's raising quests in all zones. Offline (base rows, every quest in
-- a mapped zone) this gives 21 zones: `luajit tools/qdb.lua reps rule`, checked against this
-- module by `luajit tools/qdb.lua reps check`.
--
-- Rivals: two of a zone's factions where a quest in the zone raises one and lowers the other
-- (Booty Bay and Bloodsail in Stranglethorn, Gelkis and Magram in Desolace).
--
-- Pure: no WoW globals, so tests and tools can load it.
local _, ns = ...
ns = ns or {}

local Rules = {}
ns.ReputationRules = Rules

Rules.MIN = 5      -- raising quests in the zone
Rules.LOW = 3      -- ... or this many when the zone has SHARE of the faction's raising quests
Rules.SHARE = 0.5

-- Home factions: Stormwind 72, Ironforge 47, Gnomeregan Exiles 54, Darnassus 69, Alliance 469,
-- Orgrimmar 76, Thunder Bluff 81, Undercity 68, Darkspear Trolls 530, Horde 67.
-- Battleground factions: 509, 510, 729, 730, 889, 890 [verified-files, QuestieDB faction enum].
Rules.EXCLUDED = {
    [47] = "home", [54] = "home", [69] = "home", [72] = "home", [469] = "home",
    [67] = "home", [68] = "home", [76] = "home", [81] = "home", [530] = "home",
    [509] = "battleground", [510] = "battleground", [729] = "battleground", [730] = "battleground",
    [889] = "battleground", [890] = "battleground",
}

-- Pure: a quest's rewards as { [factionID] = amount } (the first entry per faction wins), from
-- QuestieDB's list. Malformed entries are skipped. nil when there are none.
function Rules.Rewards(list)
    if type(list) ~= "table" then return nil end
    local out, any = {}, false
    for _, r in ipairs(list) do
        if type(r) == "table" and type(r[1]) == "number" and type(r[2]) == "number" and out[r[1]] == nil then
            out[r[1]] = r[2]
            any = true
        end
    end
    return any and out or nil
end

-- Pure: tallies the zones' quests.
--   zones: { [mapID] = { questID, ... } }   (a quest in several lists counts in each)
--   rewardsOf(questID) -> QuestieDB's reputationReward list, or nil
-- Returns:
--   { zones = { [mapID] = { [factionID] = { count = n raising, quests = { { id, amount } ... } } } },
--     totals = { [factionID] = raising quests in all zones },
--     opposed = { [mapID] = { [raised] = { [lowered] = n quests } } } }
function Rules.Tally(zones, rewardsOf)
    local t = { zones = {}, totals = {}, opposed = {} }
    for mapID, ids in pairs(zones or {}) do
        local zt, zo = {}, {}
        for _, id in ipairs(ids) do
            local rewards = Rules.Rewards(rewardsOf(id))
            if rewards then
                for f, amount in pairs(rewards) do
                    if amount > 0 then
                        local e = zt[f]
                        if not e then e = { count = 0, quests = {} }; zt[f] = e end
                        e.count = e.count + 1
                        e.quests[#e.quests + 1] = { id = id, amount = amount }
                        t.totals[f] = (t.totals[f] or 0) + 1
                        for g, other in pairs(rewards) do
                            if other < 0 and g ~= f then
                                zo[f] = zo[f] or {}
                                zo[f][g] = (zo[f][g] or 0) + 1
                            end
                        end
                    end
                end
            end
        end
        t.zones[mapID] = zt
        t.opposed[mapID] = zo
    end
    return t
end

-- Pure: does the rule keep faction f in a zone with `count` raising quests out of `total`?
function Rules.Keeps(f, count, total, opts)
    opts = opts or {}
    if Rules.EXCLUDED[f] then return false end
    local min, low, share = opts.min or Rules.MIN, opts.low or Rules.LOW, opts.share or Rules.SHARE
    if count >= min then return true end
    return count >= low and total > 0 and count / total >= share
end

-- Pure: a zone's factions by the rule, most raising quests first (then by ID):
--   { { factionID, count, share, quests = { { id, amount } ... } (sorted by ID) } ... }
function Rules.Pick(tally, mapID, opts)
    local picks = {}
    for f, e in pairs(tally.zones[mapID] or {}) do
        local total = tally.totals[f] or 0
        if Rules.Keeps(f, e.count, total, opts) then
            local quests = {}
            for i, q in ipairs(e.quests) do quests[i] = q end
            table.sort(quests, function(a, b) return a.id < b.id end)
            picks[#picks + 1] = { factionID = f, count = e.count, share = total > 0 and e.count / total or 0, quests = quests }
        end
    end
    table.sort(picks, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.factionID < b.factionID
    end)
    return picks
end

-- Pure: rival pairs among a zone's picks: { [factionID] = { rivalID, ... } (sorted) }, both ways.
-- A pair needs a quest in the zone that raises one and lowers the other.
function Rules.Rivals(tally, mapID, picks)
    local isPick = {}
    for _, p in ipairs(picks) do isPick[p.factionID] = true end
    local out, seen = {}, {}
    local function add(a, b)
        local key = a .. ">" .. b
        if seen[key] then return end
        seen[key] = true
        out[a] = out[a] or {}
        out[a][#out[a] + 1] = b
    end
    for f, lowered in pairs(tally.opposed[mapID] or {}) do
        if isPick[f] then
            for g in pairs(lowered) do
                if isPick[g] then add(f, g); add(g, f) end
            end
        end
    end
    for _, list in pairs(out) do table.sort(list) end
    return out
end

-- Pure: display order (approved design): most raising quests first, a rival right after its
-- rival. list = picks (or anything with factionID, already in rule order); rivals from Rivals.
function Rules.Order(list, rivals)
    local byID, out, placed = {}, {}, {}
    for _, x in ipairs(list) do byID[x.factionID] = x end
    for _, x in ipairs(list) do
        if not placed[x.factionID] then
            placed[x.factionID] = true
            out[#out + 1] = x
            for _, r in ipairs(rivals and rivals[x.factionID] or {}) do
                if byID[r] and not placed[r] then placed[r] = true; out[#out + 1] = byID[r] end
            end
        end
    end
    return out
end

-- Pure: every zone with at least one faction:
--   { [mapID] = { factions = picks in display order, rivals = { [factionID] = { rivalID ... } } } }
function Rules.Build(zones, rewardsOf, opts)
    local tally = Rules.Tally(zones, rewardsOf)
    local out = {}
    for mapID in pairs(tally.zones) do
        local picks = Rules.Pick(tally, mapID, opts)
        if #picks > 0 then
            local rivals = Rules.Rivals(tally, mapID, picks)
            out[mapID] = { factions = Rules.Order(picks, rivals), rivals = rivals }
        end
    end
    return out, tally
end

---------------------------------------------------------------------------------------------
-- Reputation tab (Phase 12, spec §7.9, §8.10): every faction, where its quests are, the reach.
---------------------------------------------------------------------------------------------

-- Faction IDs worth reading by ID even before QuestieDB is ready (or without it): every faction
-- a quest reward names in the offline survey [verified-files, 2026-11-08; the /azfdiag reps
-- probe list]. At runtime the quest catalogue and the met list add any others.
Rules.SEED_IDS = {
    21, 47, 54, 59, 67, 68, 69, 72, 76, 81, 87, 92, 93, 169, 270, 349, 369, 469, 470, 471, 509, 510,
    529, 530, 576, 577, 589, 609, 729, 730, 749, 809, 889, 890, 909, 910,
    2586, 2587, 2719, 2740, 2747, 2758, 2765, 2778, 2779, 2782, 2787, 2798, 2799, 2819, 2826, 2827,
}

-- Not rows: the Alliance and Horde headers (they carry a standing of their own in the list).
Rules.HEADERS = { [469] = true, [67] = true }
-- Battleground factions of one side. The game returns the other side's at Hated (probe
-- 2026-11-09: The Defilers, Frostwolf Clan, Darkspear Raiders for Gideon) [verified-ingame].
Rules.SIDE_ONLY = {
    [509] = "Alliance", [730] = "Alliance", [890] = "Alliance", [2799] = "Alliance",
    [510] = "Horde", [729] = "Horde", [889] = "Horde", [2798] = "Horde",
}

-- Pure: is the faction a row on this side ("Alliance"/"Horde"; nil = unknown, keep it)?
function Rules.Shown(factionID, side)
    if Rules.HEADERS[factionID] then return false end
    local only = Rules.SIDE_ONLY[factionID]
    return not (only and side and only ~= side)
end

-- QuestieDB quest sorts (negative zoneOrSort) [verified-files, QuestieDB
-- src/corrections/enum/quests.lua sortKeys].
Rules.CLASS_SORTS = {
    [-61] = "WARLOCK", [-81] = "WARRIOR", [-82] = "SHAMAN", [-141] = "PALADIN", [-161] = "MAGE",
    [-162] = "ROGUE", [-261] = "HUNTER", [-262] = "PRIEST", [-263] = "DRUID", [-372] = "DEATHKNIGHT",
    [-395] = "MONK",
}
Rules.PROFESSION_SORTS = {
    [-24] = true, [-101] = true, [-121] = true, [-181] = true, [-182] = true, [-201] = true,
    [-264] = true, [-304] = true, [-324] = true, [-371] = true, [-373] = true, [-377] = true,
}
Rules.EVENT_SORTS = {
    [-21] = true, [-22] = true, [-41] = true, [-364] = true, [-365] = true, [-366] = true,
    [-368] = true, [-369] = true, [-370] = true, [-374] = true, [-375] = true, [-376] = true,
    [-378] = true, [-402] = true, [-404] = true,
}
Rules.BATTLEGROUND_SORT = -25
-- English names for sorts (the client has none for them; English only, decision 2026-11-07).
Rules.SORT_NAMES = {
    [-24] = "Herbalism", [-101] = "Fishing", [-121] = "Blacksmithing", [-181] = "Alchemy",
    [-182] = "Leatherworking", [-201] = "Engineering", [-264] = "Tailoring", [-304] = "Cooking",
    [-324] = "First Aid", [-371] = "Inscription", [-373] = "Jewelcrafting", [-377] = "Archaeology",
    [-21] = "Hallow's End", [-22] = "Seasonal", [-41] = "Day of the Dead", [-364] = "Darkmoon Faire",
    [-365] = "Ahn'Qiraj War", [-366] = "Lunar Festival", [-368] = "Invasion", [-369] = "Midsummer",
    [-370] = "Brewfest", [-374] = "Noblegarden", [-375] = "Pilgrim's Bounty", [-376] = "Love is in the Air",
    [-378] = "Children's Week", [-402] = "Harvest Festival", [-404] = "Winter Veil",
    [-25] = "Battlegrounds", [-284] = "Special", [-344] = "Legendary", [-367] = "Reputation",
    [-221] = "Treasure maps", [-1] = "Epic", [-398] = "Riding",
}
-- Quest areas Data/QuestAreas.lua leaves unmapped that are still a known kind of source:
-- Forever's "Crafting" area, whose quests raise its crafting factions (Azeroth Commerce
-- Authority, Durotar Supply and Logistics) [inferred, docs/research/reputation.md].
Rules.AREA_KINDS = { [16941] = "profession" }

-- Pure: a source kind from a quest's place (Quests.Place kind and key):
--   "zone" (mapID), "dungeon"/"raid"/"battleground" (areaID), "profession" (sort or area),
--   "class" (sort; classFile third), "event" (sort), "other" (any other sort), or "unplaced"
--   (no zone, or an area Azerfolio doesn't map).
function Rules.SourceOf(kind, key)
    if kind == "zone" or kind == "dungeon" or kind == "raid" or kind == "battleground" then return kind, key end
    if kind == "sort" then
        if Rules.CLASS_SORTS[key] then return "class", key, Rules.CLASS_SORTS[key] end
        if Rules.PROFESSION_SORTS[key] then return "profession", key end
        if Rules.EVENT_SORTS[key] then return "event", key end
        if key == Rules.BATTLEGROUND_SORT then return "battleground", key end
        return "other", key
    end
    if kind == "unmapped" and Rules.AREA_KINDS[key] then return Rules.AREA_KINDS[key], key end
    return "unplaced", key
end

-- Groups in display order, and which source kinds count toward each.
-- "unknown": sources not known (no QuestieDB, or still reading), so no group can be derived.
Rules.GROUPS = { "home", "zones", "instances", "bgs", "profs", "other", "none", "unknown" }
Rules.GROUP_OF = { zone = "zones", dungeon = "instances", raid = "instances", battleground = "bgs",
    profession = "profs", class = "other", event = "other", other = "other" }
local KIND_ORDER = { zone = 1, dungeon = 2, raid = 3, battleground = 4, profession = 5, class = 6, event = 7, other = 8 }
local GROUP_RANK = {}
for i, g in ipairs(Rules.GROUPS) do GROUP_RANK[g] = i end

-- Pure: every faction the quests raise, with where.
--   entries = { { id, kind, key, repeatable } }  (Quests.Place kinds; each quest once)
--   rewardsOf(questID) -> QuestieDB's reputationReward list, or nil
-- Returns { [factionID] = { factionID, raising = quests raising it in a known place,
--   unplaced = raising quests in no known place, sources = { [kind:key] = { kind, key,
--   classFile, quests = { { id, amount, repeatable, lowers = { factionID... } } } } } } }.
function Rules.Catalogue(entries, rewardsOf)
    local cat = {}
    for _, e in ipairs(entries or {}) do
        local rewards = Rules.Rewards(rewardsOf(e.id))
        if rewards then
            local kind, key, classFile = Rules.SourceOf(e.kind, e.key)
            local lowered = {}
            for g, amount in pairs(rewards) do if amount < 0 then lowered[#lowered + 1] = g end end
            table.sort(lowered)
            for f, amount in pairs(rewards) do
                if amount > 0 then
                    local fc = cat[f]
                    if not fc then fc = { factionID = f, raising = 0, unplaced = 0, sources = {} }; cat[f] = fc end
                    if kind == "unplaced" then
                        fc.unplaced = fc.unplaced + 1
                    else
                        local sk = kind .. ":" .. tostring(key)
                        local src = fc.sources[sk]
                        if not src then src = { kind = kind, key = key, classFile = classFile, quests = {} }; fc.sources[sk] = src end
                        src.quests[#src.quests + 1] = { id = e.id, amount = amount, repeatable = e.repeatable and true or nil,
                            lowers = #lowered > 0 and lowered or nil }
                        fc.raising = fc.raising + 1
                    end
                end
            end
        end
    end
    return cat
end

-- Pure: a faction's sources as a list, most raising quests first (then by kind, then key);
-- each quest list sorted by ID.
function Rules.SourceList(fc)
    local list = {}
    for _, src in pairs(fc and fc.sources or {}) do
        table.sort(src.quests, function(a, b) return a.id < b.id end)
        list[#list + 1] = src
    end
    table.sort(list, function(a, b)
        if #a.quests ~= #b.quests then return #a.quests > #b.quests end
        if a.kind ~= b.kind then return KIND_ORDER[a.kind] < KIND_ORDER[b.kind] end
        return tostring(a.key) < tostring(b.key)
    end)
    return list
end

-- Pure: the faction's group: Home for the home factions, Battlegrounds for the battleground
-- factions, otherwise the group with most raising quests (ties: the earlier group); "none"
-- without any.
function Rules.GroupOf(factionID, fc)
    local ex = Rules.EXCLUDED[factionID]
    if ex == "home" then return "home" end
    if ex == "battleground" then return "bgs" end
    local n = {}
    for _, src in pairs(fc and fc.sources or {}) do
        local g = Rules.GROUP_OF[src.kind]
        n[g] = (n[g] or 0) + #src.quests
    end
    local best
    for _, g in ipairs(Rules.GROUPS) do
        if (n[g] or 0) > 0 and (not best or n[g] > n[best]) then best = g end
    end
    return best or "none"
end

-- Pure: the source the faction is "raised most in": the first of SourceList in its group (any
-- group for Home and Battlegrounds, whose group isn't a source kind), or nil.
function Rules.Main(list, group)
    for _, src in ipairs(list or {}) do
        if group == "home" or group == "bgs" and src.kind == "battleground" or Rules.GROUP_OF[src.kind] == group then
            return src
        end
    end
    return group == "bgs" and list and list[1] or nil
end

-- Reaction thresholds (start of each reaction, Hated .. Exalted) [verified-ingame for Hated,
-- Hostile, Neutral and Friendly: probe standings and thresholds; the rest the classic table].
Rules.THRESHOLDS = { -42000, -6000, -3000, 0, 3000, 9000, 21000, 42000 }
Rules.MAX_STANDING = 42999 -- the top of Exalted [unverified on Forever; the classic cap]

-- Pure: the reaction (1..8) at an absolute standing.
function Rules.ReactionAt(standing)
    local r = 1
    for i, lo in ipairs(Rules.THRESHOLDS) do if standing >= lo then r = i end end
    return r
end

-- Pure: a faction's sources and reach for this character.
--   fc from Catalogue (or nil); stateOf(questID) -> { completion, eligibility } (Quests'
--   values) or nil; opts = { classFile = the player's, standing = absolute or nil,
--   rivals = { factionID... } }.
-- A quest the rules call "unavailable" (the other side's, another race) is left out. A class
-- source for another class stays listed with forYou = false (dimmed, "not for you") but adds
-- nothing to the reach. One-time quests not done that are eligible or locked (you can do them,
-- now or later) make the reach at their base amounts; repeatables are counted, never added;
-- a quest whose state isn't known is counted as unknown.
-- Returns sources = { { kind, key, classFile, forYou, count, oneTime, repeats, done, left,
--   unknown, amount (base, one-time), amountLeft, quests } } (empty sources dropped, SourceList
--   order) and reach = { gain, count, repeats, unknown, done, target, reaction, into, span,
--   capped, lowersRival } (target nil without a standing; into / span place the target in its
--   reaction).
function Rules.Evaluate(fc, stateOf, opts)
    opts = opts or {}
    local isRival = {}
    for _, r in ipairs(opts.rivals or {}) do isRival[r] = true end
    local reach = { gain = 0, count = 0, repeats = 0, unknown = 0, done = 0, lowersRival = 0 }
    local out = {}
    for _, src in ipairs(Rules.SourceList(fc)) do
        local forYou
        if src.kind == "class" and opts.classFile then forYou = src.classFile == opts.classFile end
        local s = { kind = src.kind, key = src.key, classFile = src.classFile, forYou = forYou, count = 0,
            oneTime = 0, repeats = 0, done = 0, left = 0, unknown = 0, amount = 0, amountLeft = 0, quests = {} }
        for _, q in ipairs(src.quests) do
            local st = stateOf and stateOf(q.id) or {}
            if forYou == false or st.eligibility ~= "unavailable" then
                s.count = s.count + 1
                s.quests[#s.quests + 1] = q
                if q.repeatable then
                    s.repeats = s.repeats + 1
                    if forYou ~= false then reach.repeats = reach.repeats + 1 end
                else
                    s.oneTime = s.oneTime + 1
                    s.amount = s.amount + q.amount
                    if forYou ~= false then
                        if st.completion == "complete" then
                            s.done = s.done + 1
                            reach.done = reach.done + 1
                        elseif (st.eligibility == "eligible" or st.eligibility == "locked") and st.completion == "incomplete" then
                            s.left = s.left + 1
                            s.amountLeft = s.amountLeft + q.amount
                            reach.count = reach.count + 1
                            reach.gain = reach.gain + q.amount
                            for _, g in ipairs(q.lowers or {}) do
                                if isRival[g] then reach.lowersRival = reach.lowersRival + 1; break end
                            end
                        else
                            s.unknown = s.unknown + 1
                            reach.unknown = reach.unknown + 1
                        end
                    end
                end
            end
        end
        if s.count > 0 then out[#out + 1] = s end
    end
    if type(opts.standing) == "number" then
        local raw = opts.standing + reach.gain
        reach.capped = raw > Rules.MAX_STANDING
        reach.target = math.min(raw, Rules.MAX_STANDING)
        reach.reaction = Rules.ReactionAt(reach.target)
        -- Where the target sits in its reaction (the bar's reach mark).
        local lo = Rules.THRESHOLDS[reach.reaction]
        local hi = Rules.THRESHOLDS[reach.reaction + 1] or Rules.MAX_STANDING
        reach.into, reach.span = reach.target - lo, hi - lo
    end
    return out, reach
end

-- Sorts (toolbar; Y cycles) and filters.
Rules.SORTS = { "group", "closest", "name" }
Rules.FILTERS = { "all", "met", "unmet" }

-- Pure: the sort after `mode` (wraps; an unknown mode starts over).
function Rules.NextSort(mode)
    for i, m in ipairs(Rules.SORTS) do
        if m == mode then return Rules.SORTS[i % #Rules.SORTS + 1] end
    end
    return Rules.SORTS[1]
end

local function byName(a, b)
    local na, nb = tostring(a.name), tostring(b.name)
    if na ~= nb then return na < nb end
    return a.factionID < b.factionID
end

-- Pure: a sorted copy. Items: { factionID, name, group, met, maxed, left (to the next
-- reaction), raising }.
--   group:   by group, then most raising quests, then A-Z
--   closest: Exalted last, met first (an unmet faction only sits at its starting standing),
--            then least left to the next reaction (unknown last), then A-Z
--   name:    A-Z
function Rules.Sort(list, mode)
    local out = {}
    for i, f in ipairs(list or {}) do out[i] = f end
    local cmp
    if mode == "closest" then
        cmp = function(a, b)
            if (a.maxed and true or false) ~= (b.maxed and true or false) then return not a.maxed end
            if (a.met == true) ~= (b.met == true) then return a.met == true end
            local la, lb = a.left or math.huge, b.left or math.huge
            if la ~= lb then return la < lb end
            return byName(a, b)
        end
    elseif mode == "name" then
        cmp = byName
    else
        cmp = function(a, b)
            local ga, gb = GROUP_RANK[a.group] or 99, GROUP_RANK[b.group] or 99
            if ga ~= gb then return ga < gb end
            if (a.raising or 0) ~= (b.raising or 0) then return (a.raising or 0) > (b.raising or 0) end
            return byName(a, b)
        end
    end
    table.sort(out, cmp)
    return out
end

-- Pure: the factions a filter shows. "met": met; "unmet": not met yet (met == false); "all":
-- every one. A faction whose met state is unknown shows only under All.
function Rules.Filter(list, which)
    if which ~= "met" and which ~= "unmet" then return list end
    local out = {}
    for _, f in ipairs(list or {}) do
        if (which == "met" and f.met == true) or (which == "unmet" and f.met == false) then out[#out + 1] = f end
    end
    return out
end

-- Pure: the standing strip: factions per reaction (1..8), met and Exalted counts, total.
function Rules.Summary(list)
    local s = { byReaction = { 0, 0, 0, 0, 0, 0, 0, 0 }, met = 0, exalted = 0, total = 0 }
    for _, f in ipairs(list or {}) do
        s.total = s.total + 1
        if s.byReaction[f.reaction] then s.byReaction[f.reaction] = s.byReaction[f.reaction] + 1 end
        if f.met == true then s.met = s.met + 1 end
        if f.reaction == 8 then s.exalted = s.exalted + 1 end
    end
    return s
end

-- Pure: a sorted list in groups (GROUPS order; items keep their order):
--   { { key, items, met, total } } , empty groups left out.
function Rules.Grouped(list)
    local by = {}
    for _, f in ipairs(list or {}) do
        local g = by[f.group]
        if not g then g = { key = f.group, items = {}, met = 0, total = 0 }; by[f.group] = g end
        g.items[#g.items + 1] = f
        g.total = g.total + 1
        if f.met == true then g.met = g.met + 1 end
    end
    local out = {}
    for _, key in ipairs(Rules.GROUPS) do if by[key] then out[#out + 1] = by[key] end end
    return out
end

return Rules
