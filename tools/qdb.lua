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
            if f == "S" or (wantTables and wantTables(id)) then
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
else
    print("usage: luajit tools/qdb.lua quest <id>... | area <areaID> | name <text> | stats | npc <id>... | rares [areaID|all] | objects <text> [areaID]")
    os.exit(cmd and 1 or 0)
end
