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

return Rules
