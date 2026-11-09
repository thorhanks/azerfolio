-- Offline lookup in the installed QuestieDB's baked data (TOC metadata: base64 CBOR rows).
-- Read-only; decodes the data, runs none of QuestieDB's code. These are the BASE rows:
-- QuestieDB's Forever corrections are applied only in game (43 quests change zone), so
-- in-game checks (/azf debug quests) stay the evidence for what the addon sees.
-- Usage: luajit tools/qdb.lua <command> [args]
--   quest <id> [id...]     every field of the quests (scalar row and table fields)
--   area <areaID>          quests whose zoneOrSort is that area (or a negative sort ID)
--   name <text>            quests whose name contains text (case-insensitive)
--   stats                  rows, areas and sorts, repeatables
--   npc <id> [id...]       every field of the NPCs
--   rares [areaID|all]     rare, rare elite and boss NPCs (rank 4, 2, 3; cmangos ranks), by spawn area
--   objects <text|*> [areaID] game objects whose name contains text (* = all), spawn points per area
--   recipes [areaID]       recipe items (class 9) by source; vendor recipes by the vendor's spawn area
--   reps [zone filter]     quest reputation rewards per Azerfolio zone (Data/QuestAreas.lua); run from repo root
--   reps rule [min low share]  draft zone-faction rule (defaults 5 3 0.5)
--   reps rivals            per zone, faction pairs where a quest raises one and lowers the other
--   reps quests <zone filter> <factionID>  the zone's quests that raise that faction
-- Set AZF_QDB_TOC to read a different TOC.
local bit = require("bit")
local DEFAULT = "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/QuestieDB/QuestieDB_Forever.toc"
local path = os.getenv("AZF_QDB_TOC") or DEFAULT

-- Field names by index (QuestieDB src/meta/questMeta.lua) [verified-files].
local FIELDS = { "name", "startedBy", "finishedBy", "requiredLevel", "questLevel", "requiredRaces",
    "requiredClasses", "objectivesText", "triggerEnd", "objectives", "sourceItemId", "preQuestGroup",
    "preQuestSingle", "childQuests", "inGroupWith", "exclusiveTo", "zoneOrSort", "requiredSkill",
    "requiredMinRep", "requiredMaxRep", "requiredSourceItems", "nextQuestInChain", "questFlags",
    "specialFlags", "parentQuest", "reputationReward", "breadcrumbForQuestId", "breadcrumbs",
    "extraObjectives", "requiredSpell", "requiredSpecialization", "requiredMaxLevel",
    "availableUntilCompleted", "availableStartingWith", "requiredRanks", "disabledByQuest" }

-- NPC field names by index (QuestieDB src/meta/npcMeta.lua) [verified-files].
local NPC_FIELDS = { "name", "minLevelHealth", "maxLevelHealth", "minLevel", "maxLevel", "rank", "spawns",
    "waypoints", "zoneID", "questStarts", "questEnds", "factionID", "friendlyToFaction", "subName", "npcFlags" }

local B64 = {}
do
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    for i = 1, 64 do B64[chars:byte(i)] = i - 1 end
end

local function unbase64(s)
    local out, n, acc, bits = {}, 0, 0, 0
    for i = 1, #s do
        local v = B64[s:byte(i)]
        if v then
            acc = bit.band(bit.bor(bit.lshift(acc, 6), v), 0xFFFFFF)
            bits = bits + 6
            if bits >= 8 then
                bits = bits - 8
                n = n + 1
                out[n] = string.char(bit.band(bit.rshift(acc, bits), 255))
            end
        end
    end
    return table.concat(out)
end

-- Minimal CBOR decoder: integers, strings, arrays, maps, floats, booleans, null.
local decode
local function float(b, pos, n)
    if n == 8 then
        local sign = b:byte(pos) >= 128 and -1 or 1
        local e = bit.band(b:byte(pos), 127) * 16 + bit.rshift(b:byte(pos + 1), 4)
        local m = bit.band(b:byte(pos + 1), 15)
        for i = 2, 7 do m = m * 256 + b:byte(pos + i) end
        if e == 0 and m == 0 then return 0 end
        return sign * (1 + m / 2 ^ 52) * 2 ^ (e - 1023)
    end
    local sign = b:byte(pos) >= 128 and -1 or 1
    local e = bit.band(b:byte(pos), 127) * 2 + bit.rshift(b:byte(pos + 1), 7)
    local m = bit.band(b:byte(pos + 1), 127) * 65536 + b:byte(pos + 2) * 256 + b:byte(pos + 3)
    if e == 0 and m == 0 then return 0 end
    return sign * (1 + m / 2 ^ 23) * 2 ^ (e - 127)
end

function decode(s, pos)
    local ib = s:byte(pos); pos = pos + 1
    local major, info = bit.rshift(ib, 5), bit.band(ib, 31)
    if major == 7 then
        if info == 20 then return false, pos end
        if info == 21 then return true, pos end
        if info == 22 or info == 23 then return nil, pos end
        if info == 26 then return float(s, pos, 4), pos + 4 end
        if info == 27 then return float(s, pos, 8), pos + 8 end
        error("unsupported simple value " .. info)
    end
    local v = info
    if info >= 24 then
        local n = ({ [24] = 1, [25] = 2, [26] = 4, [27] = 8 })[info]
        assert(n, "bad length " .. info)
        v = 0
        for i = 0, n - 1 do v = v * 256 + s:byte(pos + i) end
        pos = pos + n
    end
    if major == 0 then return v, pos end
    if major == 1 then return -1 - v, pos end
    if major == 2 or major == 3 then return s:sub(pos, pos + v - 1), pos + v end
    if major == 4 then
        local t = {}
        for i = 1, v do t[i], pos = decode(s, pos) end
        return t, pos
    end
    if major == 5 then
        local t = {}
        for _ = 1, v do
            local k, val
            k, pos = decode(s, pos)
            val, pos = decode(s, pos)
            t[k] = val
        end
        return t, pos
    end
    error("unsupported major type " .. major)
end

-- Reads quest (or NPC) rows. want(id) filters which table-field lines get decoded (nil = none).
local function load(wantTables, entity)
    local rows, tabs, errors = {}, {}, 0
    local pattern = "^## X%-" .. (entity or "Quest") .. "%-(%d+)%-(%w+): (.+)$"
    for line in io.lines(path) do
        local id, f, payload = line:match(pattern)
        if id then
            id = tonumber(id)
            if f == "S" or (wantTables and wantTables(id, tonumber(f))) then
                local ok, v = pcall(decode, unbase64(payload), 1)
                if not ok then errors = errors + 1
                elseif f == "S" then rows[id] = v
                else tabs[id] = tabs[id] or {}; tabs[id][tonumber(f)] = v end
            end
        end
    end
    return rows, tabs, errors
end

local function show(v)
    if type(v) ~= "table" then return tostring(v) end
    local o = {}
    if #v > 0 then
        for i, x in ipairs(v) do o[i] = show(x) end
        return "{" .. table.concat(o, ",") .. "}"
    end
    for k, x in pairs(v) do o[#o + 1] = tostring(k) .. ":" .. show(x) end
    table.sort(o)
    return "{" .. table.concat(o, ",") .. "}"
end

-- A row's field value: scalar rows are CBOR maps keyed by field index ("p" = presence mask).
local function field(row, tab, i)
    local v = row and row[i]
    if v == nil and tab then v = tab[i] end
    return v
end

local function oneLine(id, row)
    return string.format("%6d %-42s lvl %-3s req %-3s races %-11s classes %-5s zone %-6s sf %s", id,
        tostring(row[1]), tostring(row[5]), tostring(row[4]), tostring(row[6] or "-"), tostring(row[7] or "-"),
        tostring(row[17]), tostring(row[24] or "-"))
end

local cmd = arg[1]
if cmd == "quest" then
    local ids = {}
    for i = 2, #arg do ids[tonumber(arg[i])] = true end
    local rows, tabs = load(function(id) return ids[id] end)
    for id in pairs(ids) do
        local row, tab = rows[id], tabs[id]
        if not row then
            print(id .. ": not in QuestieDB")
        else
            print(id .. ":")
            for i, name in ipairs(FIELDS) do
                local v = field(row, tab, i)
                if v ~= nil then print(string.format("  %2d %-24s %s", i, name, show(v))) end
            end
        end
    end
elseif cmd == "area" then
    local want = assert(tonumber(arg[2]), "area <areaID>")
    local rows = load()
    local ids = {}
    for id, row in pairs(rows) do if row[17] == want then ids[#ids + 1] = id end end
    table.sort(ids)
    print(string.format("%d quests with zoneOrSort %d (base rows; corrections not applied)", #ids, want))
    for _, id in ipairs(ids) do print(oneLine(id, rows[id])) end
elseif cmd == "name" then
    local q = assert(arg[2], "name <text>"):lower()
    local rows = load()
    local ids = {}
    for id, row in pairs(rows) do
        if type(row[1]) == "string" and row[1]:lower():find(q, 1, true) then ids[#ids + 1] = id end
    end
    table.sort(ids)
    for _, id in ipairs(ids) do print(oneLine(id, rows[id])) end
elseif cmd == "stats" then
    local rows, _, errors = load()
    local n, areas, sorts, rep, none = 0, 0, 0, 0, 0
    local seenA, seenS = {}, {}
    for _, row in pairs(rows) do
        n = n + 1
        local z = row[17]
        if type(z) == "number" and z > 0 then areas = areas + 1; seenA[z] = true
        elseif type(z) == "number" and z < 0 then sorts = sorts + 1; seenS[z] = true
        else none = none + 1 end
        if type(row[24]) == "number" and row[24] % 2 == 1 then rep = rep + 1 end
    end
    local na, ns = 0, 0
    for _ in pairs(seenA) do na = na + 1 end
    for _ in pairs(seenS) do ns = ns + 1 end
    print(string.format("%d quests (%d decode errors): %d in %d areas, %d in %d sorts, %d without; %d repeatable (specialFlags)",
        n, errors, areas, na, sorts, ns, none, rep))
elseif cmd == "npc" then
    local ids = {}
    for i = 2, #arg do ids[tonumber(arg[i])] = true end
    local rows, tabs = load(function(id) return ids[id] end, "Npc")
    for id in pairs(ids) do
        local row, tab = rows[id], tabs[id]
        if not row then
            print(id .. ": not in QuestieDB")
        else
            print(id .. ":")
            for i, name in ipairs(NPC_FIELDS) do
                local v = field(row, tab, i)
                if v ~= nil then print(string.format("  %2d %-18s %s", i, name, show(v))) end
            end
        end
    end
elseif cmd == "rares" then
    local only = tonumber(arg[2])
    local RANKS = { [2] = "rare elite", [3] = "boss", [4] = "rare" }
    local rows, tabs, errors = load(nil, "Npc")
    local want = {}
    for id, row in pairs(rows) do if RANKS[row[6]] then want[id] = true end end
    rows, tabs = load(function(id) return want[id] end, "Npc")
    local byArea, counts, noSpawn, total = {}, {}, 0, 0
    for id in pairs(want) do
        local row, tab = rows[id], tabs[id] or {}
        total = total + 1
        counts[row[6]] = (counts[row[6]] or 0) + 1
        local spawns = tab[7]
        if type(spawns) ~= "table" or next(spawns) == nil then
            noSpawn = noSpawn + 1
            spawns = { [row[9] or 0] = {} }
        end
        for area, points in pairs(spawns) do
            byArea[area] = byArea[area] or {}
            table.insert(byArea[area], { id = id, row = row, points = #points, paths = tab[8] and tab[8][area] and #tab[8][area] or 0 })
        end
    end
    print(string.format("%d NPCs ranked rare/rare elite/boss (rare %d, rare elite %d, boss %d), %d without spawns, %d decode errors (base rows)",
        total, counts[4] or 0, counts[2] or 0, counts[3] or 0, noSpawn, errors))
    local areas = {}
    for a in pairs(byArea) do areas[#areas + 1] = a end
    table.sort(areas, function(a, b) return #byArea[a] > #byArea[b] end)
    for _, a in ipairs(areas) do
        if not only or a == only then
            print(string.format("area %-6s %d", tostring(a), #byArea[a]))
            if only or arg[2] == "all" then
                table.sort(byArea[a], function(x, y) return x.id < y.id end)
                for _, e in ipairs(byArea[a]) do
                    print(string.format("  %6d %-34s %-10s lvl %s-%s  spawn points %d  paths %d  friendly %s",
                        e.id, tostring(e.row[1]), RANKS[e.row[6]], tostring(e.row[4]), tostring(e.row[5]),
                        e.points, e.paths, tostring(e.row[13] or "-")))
                end
            end
        end
    end
elseif cmd == "objects" then
    local q = assert(arg[2], "objects <text|*> [areaID]"):lower()
    if q == "*" then q = "" end
    local only = tonumber(arg[3])
    local rows = load(nil, "Object")
    local want = {}
    for id, row in pairs(rows) do
        if type(row[1]) == "string" and row[1]:lower():find(q, 1, true) then want[id] = true end
    end
    local _, tabs = load(function(id) return want[id] end, "Object")
    local ids = {}
    for id in pairs(want) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local row, tab = rows[id], tabs[id] or {}
        local spawns, parts, total = tab[4], {}, 0
        if type(spawns) == "table" then
            for area, points in pairs(spawns) do
                if not only or area == only then parts[#parts + 1] = area .. ":" .. #points end
                total = total + #points
            end
        end
        table.sort(parts)
        if not only or #parts > 0 then
            print(string.format("%6d %-36s quests %s/%s  spawn points %d  %s", id, tostring(row[1]),
                tab[2] and #tab[2] or 0, tab[3] and #tab[3] or 0, total, table.concat(parts, " ")))
        end
    end
elseif cmd == "recipes" then
    -- Item class 9 (Recipe); subclasses per the classic ItemSubClass table [unverified on Forever].
    local SUB = { [0] = "book", "leatherworking", "tailoring", "engineering", "blacksmithing", "cooking",
        "alchemy", "first aid", "enchanting", "fishing", "jewelcrafting" }
    local only = tonumber(arg[2])
    local rows = load(nil, "Item")
    local want = {}
    for id, row in pairs(rows) do if row[12] == 9 then want[id] = true end end
    local _, tabs = load(function(id) return want[id] end, "Item")
    local vendorIds = {}
    for id in pairs(want) do
        local t = tabs[id] or {}
        if t[14] then for _, v in ipairs(t[14]) do vendorIds[v] = true end end
    end
    local npcRows, npcTabs = load(function(id) return vendorIds[id] end, "Npc")
    local total, bySource, bySub, byArea = 0, { vendor = 0, drop = 0, object = 0, quest = 0, none = 0, teaches = 0 }, {}, {}
    for id in pairs(want) do
        local row, t = rows[id], tabs[id] or {}
        total = total + 1
        local sub = SUB[row[13] or 0] or tostring(row[13])
        bySub[sub] = (bySub[sub] or 0) + 1
        if row[16] or t[16] then bySource.teaches = bySource.teaches + 1 end
        local any = false
        if t[14] then
            any = true; bySource.vendor = bySource.vendor + 1
            local areas = {}
            for _, v in ipairs(t[14]) do
                local spawns = npcTabs[v] and npcTabs[v][7]
                if type(spawns) == "table" then for a in pairs(spawns) do areas[a] = v end
                elseif npcRows[v] and npcRows[v][9] then areas[npcRows[v][9]] = v end
            end
            for a, v in pairs(areas) do
                byArea[a] = byArea[a] or {}
                table.insert(byArea[a], { id = id, name = row[1], sub = sub, vendor = (npcRows[v] and npcRows[v][1] or "?") .. " (" .. v .. ")" })
            end
        end
        if t[2] then any = true; bySource.drop = bySource.drop + 1 end
        if t[3] then any = true; bySource.object = bySource.object + 1 end
        if t[6] then any = true; bySource.quest = bySource.quest + 1 end
        if not any then bySource.none = bySource.none + 1 end
    end
    print(string.format("%d recipe items (base rows): sold by vendors %d, NPC drops %d, object drops %d, quest rewards %d, no source %d; teachesSpell set on %d",
        total, bySource.vendor, bySource.drop, bySource.object, bySource.quest, bySource.none, bySource.teaches))
    local subs = {}
    for s, n in pairs(bySub) do subs[#subs + 1] = s .. " " .. n end
    table.sort(subs)
    print("by profession: " .. table.concat(subs, ", "))
    local areas = {}
    for a in pairs(byArea) do areas[#areas + 1] = a end
    table.sort(areas, function(a, b) return #byArea[a] > #byArea[b] end)
    for _, a in ipairs(areas) do
        if not only or a == only then
            print(string.format("area %-6s %d vendor recipes", tostring(a), #byArea[a]))
            if only then
                table.sort(byArea[a], function(x, y) return x.id < y.id end)
                for _, e in ipairs(byArea[a]) do
                    print(string.format("  %6d %-44s %-15s %s", e.id, tostring(e.name), e.sub, tostring(e.vendor)))
                end
            end
        end
    end
elseif cmd == "reps" then
    -- Faction names from QuestieDB's correction enum; zones from Azerfolio's own Data/QuestAreas.lua.
    local dir = path:match("^(.*)[/\\]")
    local names = {}
    local ef = io.open(dir .. "/src/corrections/enum/factions.lua")
    if ef then
        for n, id in ef:read("*a"):gmatch("([%u_]+) = (%d+)") do names[tonumber(id)] = n end
        ef:close()
    end
    local zoneOf, zoneName, kind = {}, {}, nil
    for line in io.lines("Azerfolio/Data/QuestAreas.lua") do
        local k = line:match("^%s*(%a+) = {")
        if k then kind = k end
        local a, v, label = line:match("^%s*%[(%d+)%] = (%w+),%s*%-%-%s*(.-)%s*$")
        if a and kind == "zone" then
            zoneOf[tonumber(a)] = tonumber(v)
            zoneName[tonumber(v)] = zoneName[tonumber(v)] or label
        elseif a and kind then
            zoneOf[tonumber(a)] = kind .. ":" .. (label or a)
        end
    end
    local filter = arg[2]
    local rule = filter == "rule"
    if rule then filter = nil end
    local rivals = filter == "rivals"
    local questsFor = filter == "quests" and { zone = (arg[3] or ""):lower(), faction = tonumber(arg[4]) }
    if rivals or questsFor then filter = nil end
    if rivals or questsFor then
        -- rivals: per zone, faction pairs where a quest here raises one and lowers the other.
        -- quests <zone filter> <factionID>: the zone's quests that raise that faction.
        local rows, tabs = load(function(_, f) return f == 26 end)
        local pairsByZone, list = {}, {}
        for id, row in pairs(rows) do
            local rewards = tabs[id] and tabs[id][26]
            local z = row[17]
            local zk = type(z) == "number" and z > 0 and zoneOf[z]
            if type(rewards) == "table" and type(zk) == "number" then
                local up, down = {}, {}
                for _, r in ipairs(rewards) do
                    local a = r[2] or 0
                    if a > 0 then up[#up + 1] = r[1] elseif a < 0 then down[#down + 1] = r[1] end
                    if questsFor and r[1] == questsFor.faction and a > 0 and tostring(zoneName[zk]):lower():find(questsFor.zone, 1, true) then
                        list[#list + 1] = { id = id, name = row[1], lvl = row[5], req = row[4], amount = a }
                    end
                end
                for _, u in ipairs(up) do for _, d in ipairs(down) do
                    local key = u .. ">" .. d
                    pairsByZone[zk] = pairsByZone[zk] or {}
                    pairsByZone[zk][key] = (pairsByZone[zk][key] or 0) + 1
                end end
            end
        end
        if questsFor then
            table.sort(list, function(a, b) return (a.lvl or 0) < (b.lvl or 0) or ((a.lvl or 0) == (b.lvl or 0) and a.id < b.id) end)
            print(string.format("%d quests raise %s (%s) in zones matching '%s' (base rows; amounts are raw values)", #list,
                names[questsFor.faction] or "?", tostring(questsFor.faction), questsFor.zone))
            for _, q in ipairs(list) do print(string.format("%6d %-44s lvl %-3s req %-3s +%d", q.id, tostring(q.name), tostring(q.lvl), tostring(q.req), q.amount)) end
            return
        end
        print("Raises > lowers: quests in the zone that raise the first faction and lower the second (base rows)")
        local zs = {}
        for z in pairs(pairsByZone) do zs[#zs + 1] = z end
        table.sort(zs)
        for _, z in ipairs(zs) do
            local parts = {}
            for key, n in pairs(pairsByZone[z]) do
                local u, d = key:match("(%d+)>(%d+)")
                parts[#parts + 1] = string.format("%s>%s %d", names[tonumber(u)] or u, names[tonumber(d)] or d, n)
            end
            table.sort(parts)
            print(string.format("%-5d %-22s %s", z, tostring(zoneName[z]), table.concat(parts, "; ")))
        end
        return
    end
    local rows, tabs = load(function(_, f) return f == 26 end)
    local byZone = {}
    for id, row in pairs(rows) do
        local rewards = tabs[id] and tabs[id][26]
        local z = row[17]
        if type(rewards) == "table" and type(z) == "number" then
            local key = z > 0 and (zoneOf[z] or ("unmapped area " .. z)) or ("sort " .. z)
            byZone[key] = byZone[key] or {}
            for _, r in ipairs(rewards) do
                local f, amount = r[1], r[2] or 0
                local e = byZone[key][f] or { quests = 0, total = 0, positive = 0 }
                e.quests = e.quests + 1
                if type(amount) == "number" and amount > 0 then e.total = e.total + amount; e.positive = e.positive + 1 end
                byZone[key][f] = e
            end
        end
    end
    if rule then
        -- Draft zone-faction rule: per zone (numeric keys only), factions that aren't home
        -- factions (capitals, races, Alliance/Horde) or battleground factions, with at least
        -- MIN quests here that raise them, or at least LOW quests when this zone has at least
        -- SHARE of the faction's raising quests in all zones.
        local MIN, LOW, SHARE = tonumber(arg[3]) or 5, tonumber(arg[4]) or 3, tonumber(arg[5]) or 0.5
        local HOME = { [47] = 1, [54] = 1, [69] = 1, [72] = 1, [469] = 1, [67] = 1, [68] = 1, [76] = 1, [81] = 1,
            [530] = 1, [509] = 1, [510] = 1, [729] = 1, [730] = 1, [889] = 1, [890] = 1 }
        local perFaction = {}
        for k, fs in pairs(byZone) do
            if type(k) == "number" then
                for f, e in pairs(fs) do perFaction[f] = (perFaction[f] or 0) + e.positive end
            end
        end
        print(string.format("Draft rule: not a home/battleground faction; >= %d raising quests in the zone, or >= %d when the zone has >= %d%% of them", MIN, LOW, SHARE * 100))
        local zs = {}
        for k in pairs(byZone) do if type(k) == "number" then zs[#zs + 1] = k end end
        table.sort(zs)
        for _, z in ipairs(zs) do
            local picks = {}
            for f, e in pairs(byZone[z]) do
                local share = perFaction[f] > 0 and e.positive / perFaction[f] or 0
                if not HOME[f] and (e.positive >= MIN or (e.positive >= LOW and share >= SHARE)) then
                    picks[#picks + 1] = { f = f, n = e.positive, share = share }
                end
            end
            table.sort(picks, function(a, b) return a.n > b.n end)
            local parts = {}
            for _, x in ipairs(picks) do
                parts[#parts + 1] = string.format("%s(%d) %d, %d%%", names[x.f] or "?", x.f, x.n, math.floor(x.share * 100 + 0.5))
            end
            print(string.format("%-5d %-24s %s", z, tostring(zoneName[z]), #parts > 0 and table.concat(parts, "; ") or "-"))
        end
        return
    end
    local keys = {}
    for k in pairs(byZone) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    print("Quest reputation rewards by zone (base rows; amounts are QuestieDB's raw values, positive only summed)")
    for _, k in ipairs(keys) do
        local label = type(k) == "number" and (k .. " " .. tostring(zoneName[k])) or k
        if not filter or label:lower():find(filter:lower(), 1, true) then
            local fs = {}
            for f, e in pairs(byZone[k]) do fs[#fs + 1] = { f = f, e = e } end
            table.sort(fs, function(a, b) return a.e.quests > b.e.quests end)
            local parts = {}
            for _, x in ipairs(fs) do
                parts[#parts + 1] = string.format("%s(%d) %dq/%d", names[x.f] or "?", x.f, x.e.quests, x.e.total)
            end
            print(string.format("%-34s %s", label, table.concat(parts, ", ")))
        end
    end
else
    print("usage: luajit tools/qdb.lua quest <id>... | area <areaID> | name <text> | stats | npc <id>... | rares [areaID|all] | objects <text> [areaID] | recipes [areaID] | reps [zone filter]")
    os.exit(cmd and 1 or 0)
end
