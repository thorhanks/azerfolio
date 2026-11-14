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
--   class [name]           class-restricted quests: counts per class by level and side; with a class
--                          name, its quests grouped into chains with starters (run from repo root)
--   class <name> <race>    the same, only quests that race can take (race mask unset or has its bit);
--                          <race> may be alliance or horde (any of that side's races)
--   class check            Azerfolio/Data/ClassJourneys.lua against QuestieDB (IDs, class, side, left out)
--   reps [zone filter]     quest reputation rewards per Azerfolio zone (Data/QuestAreas.lua); run from repo root
--   reps rule [min low share]  draft zone-faction rule (defaults 5 3 0.5)
--   reps check             Azerfolio's Systems/ReputationRules.lua on the same rows must match `reps rule`
--   reps rivals            per zone, faction pairs where a quest raises one and lowers the other
--   reps quests <zone filter> <factionID>  the zone's quests that raise that faction
--   reps tab               the Reputation tab's catalogue: every faction's group and sources (ReputationRules)
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
    if arg[2] == "match" then
        -- The profession windows recorded by /azfdiag profs, matched by name to recipe items
        -- ("Plans: X", "Recipe: X", "Pattern: X", "Schematic: X", "Formula: X", "Manual: X").
        local diag = os.getenv("AZF_DIAG_FILE") or "C:/Program Files (x86)/World of Warcraft/_forever_/WTF/Account/COMPUTERWISPERER/SavedVariables/AzerfolioDiag.lua"
        local chunk = assert(loadfile(diag)); local env = {}; setfenv(chunk, env); chunk()
        local byName = {}
        for id, row in pairs(rows) do
            if row[12] == 9 and type(row[1]) == "string" then
                local n = row[1]:match("^%a+: (.+)$")
                if n then byName[n] = byName[n] or {}; table.insert(byName[n], id) end
            end
        end
        local seen = {}
        for _, run in ipairs(env.AzerfolioDiagDB.profRuns or {}) do
            local w = run.window
            local prof = w and type(w.base) == "table" and w.base.professionName
            if prof and not seen[prof] then
                seen[prof] = true
                local cats = {}
                for _, c in ipairs(w.categories or {}) do if type(c.info) == "table" then cats[c.id] = c.info.name end end
                local n, item, learned, sod, list = 0, 0, 0, 0, {}
                for _, r in ipairs(w.recipes or {}) do
                    n = n + 1
                    if r.learned then learned = learned + 1 end
                    local isSod = cats[r.cat] == "SEASON OF DISCOVERY"
                    if isSod then sod = sod + 1 end
                    local m = byName[r.name]
                    if m then item = item + 1 elseif not r.learned and not isSod then list[#list + 1] = r.name .. " (" .. tostring(r.trivial) .. ")" end
                end
                print(string.format("%-15s %d recipes: learned %d, Season of Discovery category %d, a recipe item by name %d, neither %d",
                    prof, n, learned, sod, item, #list))
                if arg[3] then table.sort(list); print("    " .. table.concat(list, ", ")) end
            end
        end
        return
    end
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
elseif cmd == "profs" then
    -- Profession survey: trainers (NPC subName "<Profession> Trainer" or "...Trainer"), quests with a
    -- requiredSkill ({skillID, rank}), per skill line. Skill IDs per the classic SkillLine table [unverified on Forever].
    local SKILL = { [164] = "Blacksmithing", [165] = "Leatherworking", [171] = "Alchemy", [182] = "Herbalism",
        [185] = "Cooking", [186] = "Mining", [197] = "Tailoring", [202] = "Engineering", [333] = "Enchanting",
        [356] = "Fishing", [393] = "Skinning", [129] = "First Aid", [40] = "Poisons", [633] = "Lockpicking", [762] = "Riding" }
    local filter = arg[2] and arg[2]:lower()
    local npcRows = load(nil, "Npc")
    local trainers, other = {}, {}
    -- Trainer subNames: "<Profession> Trainer" or "<Rank> <noun>" ("Journeyman Blacksmith", "Expert Chef").
    local NOUN = { Blacksmith = "Blacksmithing", Leatherworker = "Leatherworking", Alchemist = "Alchemy",
        Herbalist = "Herbalism", Chef = "Cooking", Cook = "Cooking", Miner = "Mining", Tailor = "Tailoring",
        Engineer = "Engineering", Enchanter = "Enchanting", Fisherman = "Fishing", Skinner = "Skinning",
        Physician = "First Aid", Surgeon = "First Aid", Trauma = "First Aid" }
    local RANKS = { Apprentice = true, Journeyman = true, Expert = true, Artisan = true, Master = true, Grand = true }
    for id, row in pairs(npcRows) do
        local sub = row[14]
        local prof
        if type(sub) == "string" then
            local rank, noun = sub:match("^(%a+) (%a+)$")
            if rank and RANKS[rank] and NOUN[noun] then prof = NOUN[noun] end
        end
        if type(sub) == "string" and (prof or sub:find("Trainer")) then
            if not prof then for _, n in pairs(SKILL) do if sub:find(n, 1, true) then prof = n end end end
            if prof then
                trainers[prof] = trainers[prof] or {}
                table.insert(trainers[prof], { id = id, name = row[1], sub = sub, area = row[9] })
            elseif not sub:find("Trainer$") or sub:find("Profession") then
                other[#other + 1] = id .. " " .. tostring(row[1]) .. " <" .. sub .. ">"
            end
        end
    end
    local qrows, qtabs = load(function(_, f) return f == 18 end)
    local quests = {}
    for id, row in pairs(qrows) do
        local rs = field(row, qtabs[id], 18)
        if type(rs) == "table" and rs[1] then
            local n = SKILL[rs[1]] or ("skill " .. rs[1])
            quests[n] = quests[n] or {}
            table.insert(quests[n], { id = id, name = row[1], rank = rs[2], zone = row[17] })
        end
    end
    local names = {}
    for _, n in pairs(SKILL) do names[#names + 1] = n end
    for n in pairs(quests) do if n:find("^skill ") then names[#names + 1] = n end end
    table.sort(names)
    for _, n in ipairs(names) do
        local t, q = trainers[n] or {}, quests[n] or {}
        if (#t > 0 or #q > 0) and (not filter or n:lower():find(filter, 1, true)) then
            local ranks = {}
            for _, e in ipairs(t) do
                local r = e.sub:match("^(%a+) ") or "-"
                ranks[r] = (ranks[r] or 0) + 1
            end
            local rs = {}
            for r, c in pairs(ranks) do rs[#rs + 1] = r .. " " .. c end
            table.sort(rs)
            print(string.format("%-15s trainers %-3d (%s)  quests needing the skill %d", n, #t, table.concat(rs, ", "), #q))
            if filter then
                table.sort(t, function(a, b) return a.id < b.id end)
                for _, e in ipairs(t) do print(string.format("    T %6d %-28s <%s> area %s", e.id, tostring(e.name), e.sub, tostring(e.area))) end
                table.sort(q, function(a, b) return (a.rank or 0) < (b.rank or 0) end)
                for _, e in ipairs(q) do print(string.format("    Q %6d %-40s rank %-4s zone %s", e.id, tostring(e.name), tostring(e.rank), tostring(e.zone))) end
            end
        end
    end
    if not filter and #other > 0 then
        table.sort(other)
        print("other trainer subNames with 'Profession' or not ending in Trainer: " .. #other)
        for i = 1, math.min(#other, 15) do print("    " .. other[i]) end
    end
elseif cmd == "class" then
    -- Class-restricted quests (requiredClasses set, not every class). Masks are tested with
    -- arithmetic, not bit.band: race masks pass 2^32 on Forever.
    local CLASSES = { "warrior", "paladin", "hunter", "rogue", "priest", "deathknight", "shaman", "mage",
        "warlock", "monk", "druid" }
    local function has(mask, b) return type(mask) == "number" and math.floor(mask / b) % 2 == 1 end
    local ALLIANCE, HORDE = 1 + 4 + 8 + 64, 2 + 16 + 32 + 128 -- human dwarf nightelf gnome / orc undead tauren troll
    local function side(m)
        if type(m) ~= "number" or m == 0 then return "both" end
        local a, h = false, false
        for i = 1, 9 do
            local b = 2 ^ (i - 1)
            if has(m, b) then if has(ALLIANCE, b) then a = true elseif has(HORDE, b) then h = true end end
        end
        if a and not h then return "A" elseif h and not a then return "H" end
        return (a and h and "mixed:" or "other:") .. string.format("%.0f", m)
    end
    local zoneName = {}
    for line in io.lines("Azerfolio/Data/QuestAreas.lua") do
        local a, label = line:match("^%s*%[(%d+)%] = %w+,%s*%-%-%s*(.-)%s*$")
        if a then zoneName[tonumber(a)] = zoneName[tonumber(a)] or label end
    end
    local function place(z)
        if type(z) ~= "number" then return "-" end
        return (zoneName[z] or "") .. "(" .. z .. ")"
    end
    local which = arg[2]
    if which == "check" then
        -- Azerfolio/Data/ClassJourneys.lua against the base rows: every listed quest exists, has the
        -- class (or no class mask) and suits the side; and no one-time quest in the class's quest
        -- sort is left out (raid and dungeon gear sit outside the sort, so they aren't asked for).
        local data = {}
        assert(loadfile("Azerfolio/Data/ClassJourneys.lua"))(nil, data)
        data = data.ClassJourneyData
        local SORT = { WARRIOR = -81, PALADIN = -141, HUNTER = -261, ROGUE = -162, PRIEST = -262, SHAMAN = -82,
            MAGE = -161, WARLOCK = -61, DRUID = -263 }
        local SIDE = { Alliance = { 1, 4, 8, 64, 2 ^ 32 }, Horde = { 2, 16, 32, 128, 2 ^ 33 } }
        local rows = load()
        local function rep(r) return type(r[24]) == "number" and r[24] % 2 == 1 end
        local function suits(m, side)
            if type(m) ~= "number" or m == 0 then return true end
            for _, b in ipairs(SIDE[side]) do if has(m, b) then return true end end
            return false
        end
        local problems = 0
        for ci, token in ipairs({ "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE",
            "WARLOCK", "MONK", "DRUID" }) do
            local b = 2 ^ (ci - 1)
            for _, side in ipairs({ "Alliance", "Horde" }) do
                local j = data[token] and data[token][side]
                if j then
                    local listed, keyOf, counted, roadN, sideN = {}, {}, 0, 0, 0
                    local seenKey, racesOf = {}, {}
                    local ignore = data[token].ignore or {}
                    local function note(msg) problems = problems + 1; print("  ! " .. msg) end
                    print(string.format("%s %s: %s", token, side, j.title or "?"))
                    for _, s in ipairs(j.stops) do
                        if not seenKey[s.key] then
                            seenKey[s.key] = true
                            if s.kind == "road" then roadN = roadN + 1 else sideN = sideN + 1 end
                        end
                        -- The side's races this stop is for: a counted quest suits the race (and the
                        -- stop's raceMask, when it has one).
                        local races = {}
                        local function check(id, isCounted)
                            local r = rows[id]
                            if keyOf[id] and keyOf[id] ~= s.key then note(id .. " is in two stops: " .. keyOf[id] .. ", " .. s.key) end
                            keyOf[id] = s.key; listed[id] = true
                            if ignore[id] then note(id .. " is listed and ignored") end
                            if not r then return note(id .. " (" .. s.name .. ") is not in QuestieDB") end
                            if type(r[7]) == "number" and r[7] > 0 and not has(r[7], b) then note(id .. " " .. tostring(r[1]) .. ": not a " .. token .. " quest") end
                            if not suits(r[6], side) then note(id .. " " .. tostring(r[1]) .. ": race mask " .. string.format("%.0f", r[6]) .. " doesn't suit " .. side) end
                            if isCounted and rep(r) then note(id .. " " .. tostring(r[1]) .. ": counted but repeatable") end
                            if isCounted then
                                for _, rb in ipairs(SIDE[side]) do
                                    local m = r[6]
                                    if (type(m) ~= "number" or m == 0 or has(m, rb)) and (not s.raceMask or has(s.raceMask, rb)) then races[rb] = true end
                                end
                            end
                        end
                        local function list(qs)
                            local n = 0
                            for _, q in ipairs(qs) do
                                if type(q) == "table" then for _, a in ipairs(q) do check(a, true) end
                                else check(q, true) end
                                n = n + 1
                            end
                            return n
                        end
                        if s.routes then
                            local most = 0
                            for _, route in ipairs(s.routes) do most = math.max(most, list(route)) end
                            counted = counted + most
                            if s.quests then note(s.key .. ": has both quests and routes") end
                        else
                            counted = counted + list(s.quests)
                        end
                        for _, q in ipairs(s.extra or {}) do check(q, false) end
                        racesOf[#racesOf + 1] = { key = s.key, name = s.name, races = races }
                    end
                    for _, s in ipairs(j.stops) do
                        if s.kind == "side" and not seenKey[s.from] then note(s.key .. ": side path off unknown stop " .. tostring(s.from)) end
                    end
                    -- Race versions sharing a key must not both suit one race: the addon shows one.
                    for x = 1, #racesOf do for y = x + 1, #racesOf do
                        local a, c = racesOf[x], racesOf[y]
                        if a.key == c.key then
                            for rb in pairs(a.races) do
                                if c.races[rb] then note(string.format("%s: '%s' and '%s' both suit race bit %.0f", a.key, a.name, c.name, rb)) end
                            end
                        end
                    end end
                    print(string.format("  %d road stops, %d side paths, %d counted quests (race versions add up)", roadN, sideN, counted))
                    local missed, core = {}, 0
                    for id, r in pairs(rows) do
                        if r[17] == SORT[token] and has(r[7], b) and not rep(r) and suits(r[6], side) and not ignore[id] then
                            core = core + 1
                            if not listed[id] then missed[#missed + 1] = id end
                        end
                    end
                    print(string.format("  %d one-time quests in the class sort suit this side; %d left out", core, #missed))
                    table.sort(missed, function(x, y) return (rows[x][4] or 0) < (rows[y][4] or 0) or ((rows[x][4] or 0) == (rows[y][4] or 0) and x < y) end)
                    for _, id in ipairs(missed) do note(string.format("missed: %d %s (req %s, races %.0f)", id, tostring(rows[id][1]), tostring(rows[id][4]), rows[id][6] or 0)) end
                end
            end
        end
        print(problems == 0 and "OK" or (problems .. " problems"))
        return
    end
    local wantBit
    if which then
        for i, n in ipairs(CLASSES) do if n == which:lower() then wantBit = 2 ^ (i - 1) end end
        assert(wantBit, "class [warrior|paladin|hunter|rogue|priest|shaman|mage|warlock|druid|...]")
    end
    local RACES = { "human", "orc", "dwarf", "nightelf", "undead", "tauren", "gnome", "troll", "goblin" }
    local raceBit, sideBits
    if arg[3] == "alliance" or arg[3] == "horde" then
        sideBits = arg[3] == "alliance" and { 1, 4, 8, 64, 2 ^ 32 } or { 2, 16, 32, 128, 2 ^ 33 }
    elseif arg[3] then
        for i, n in ipairs(RACES) do if n == arg[3]:lower() then raceBit = 2 ^ (i - 1) end end
        assert(raceBit, "class <name> [human|orc|dwarf|nightelf|undead|tauren|gnome|troll|goblin|alliance|horde]")
    end
    local function sideOk(r)
        if not sideBits or type(r) ~= "number" or r == 0 then return true end
        for _, b in ipairs(sideBits) do if has(r, b) then return true end end
        return false
    end
    local rows = load()
    local all = 0
    for i = 1, #CLASSES do all = all + 2 ^ (i - 1) end
    local ids = {}
    for id, row in pairs(rows) do
        local m = row[7]
        local r = row[6]
        local raceOk = (not raceBit or type(r) ~= "number" or r == 0 or has(r, raceBit)) and sideOk(r)
        if type(m) == "number" and m > 0 and m % (2 ^ 11) ~= all % (2 ^ 11) and (not wantBit or has(m, wantBit)) and raceOk then
            ids[id] = true
        end
    end
    local _, tabs = load(function(id) return ids[id] end)
    local function f(id, i) return field(rows[id], tabs[id], i) end
    local function repeatable(id) local sf = f(id, 24); return type(sf) == "number" and sf % 2 == 1 end
    if not wantBit then
        print("class-restricted quests per class (base rows; corrections not applied); a quest open to several classes counts for each")
        print(string.format("%-12s %5s %5s %5s %5s %5s %5s %5s %5s %5s %5s %5s %5s %5s  %s", "class", "all", "multi", "rep",
            "1-9", "10-19", "20-29", "30-39", "40-49", "50-59", "60+", "sort", "core", "id9x", "A/H/b"))
        for i, n in ipairs(CLASSES) do
            local b = 2 ^ (i - 1)
            local c, multi, rep, lv, sides = 0, 0, 0, { 0, 0, 0, 0, 0, 0, 0 }, { A = 0, H = 0, both = 0, other = 0 }
            -- The class's quest sort: the most common negative zoneOrSort among its quests.
            local sorts, sort, best = {}, nil, 0
            for id in pairs(ids) do
                local z = f(id, 17)
                if has(f(id, 7), b) and type(z) == "number" and z < 0 then sorts[z] = (sorts[z] or 0) + 1 end
            end
            for z, k in pairs(sorts) do if k > best then sort, best = z, k end end
            local core, new = 0, 0
            for id in pairs(ids) do
                local m = f(id, 7)
                if has(m, b) then
                    c = c + 1
                    if f(id, 17) == sort and not repeatable(id) then core = core + 1 end
                    if id >= 90000 or (id >= 78000 and id < 80000) then new = new + 1 end
                    if m ~= b then multi = multi + 1 end
                    if repeatable(id) then rep = rep + 1 end
                    local l = f(id, 4) or f(id, 5) or 0
                    if l <= 0 then l = f(id, 5) or 0 end
                    local k = math.min(7, math.floor(math.max(l, 0) / 10) + 1)
                    lv[k] = lv[k] + 1
                    local s = side(f(id, 6))
                    if s == "A" or s == "H" or s == "both" then sides[s] = sides[s] + 1 else sides.other = sides.other + 1 end
                end
            end
            if c > 0 then
                print(string.format("%-12s %5d %5d %5d %5d %5d %5d %5d %5d %5d %5d %5s %5d %5d  %d/%d/%d+%d", n, c, multi, rep,
                    lv[1], lv[2], lv[3], lv[4], lv[5], lv[6], lv[7], tostring(sort), core, new, sides.A, sides.H, sides.both, sides.other))
            end
        end
        print("level = requiredLevel (questLevel when unset); sort = the class's quest sort; core = one-time quests in that sort;")
        print("id9x = IDs 78000-79999 or >= 90000 (newer than the 1.12 range); A/H/b = Alliance races / Horde races / no race mask + other masks")
        return
    end
    -- One class: quests grouped into chains (pre-quests, next in chain, exclusive alternatives).
    local parent = {}
    local function find(x) while parent[x] and parent[x] ~= x do x = parent[x] end return x end
    local function union(a, b)
        if not (ids[a] and ids[b]) then return end
        parent[a] = parent[a] or a; parent[b] = parent[b] or b
        local ra, rb = find(a), find(b)
        if ra ~= rb then parent[ra] = rb end
    end
    local function each(v, fn)
        if type(v) == "number" and v > 0 then fn(v) elseif type(v) == "table" then for _, x in ipairs(v) do each(x, fn) end end
    end
    for id in pairs(ids) do
        parent[id] = parent[id] or id
        each(f(id, 12), function(p) union(id, p) end)
        each(f(id, 13), function(p) union(id, p) end)
        each(f(id, 22), function(p) union(id, p) end)
        each(f(id, 16), function(p) union(id, p) end)
        each(f(id, 25), function(p) union(id, p) end)
    end
    local npcWant = {}
    for id in pairs(ids) do
        local sb = f(id, 2)
        if type(sb) == "table" and type(sb[1]) == "table" then for _, n in ipairs(sb[1]) do npcWant[n] = true end end
    end
    local npcRows, npcTabs = load(function(id) return npcWant[id] end, "Npc")
    local function starter(id)
        local sb = f(id, 2)
        if type(sb) ~= "table" then return "-" end
        local out = {}
        if type(sb[1]) == "table" then
            for _, n in ipairs(sb[1]) do
                local r = npcRows[n]
                local z = r and r[9]
                local spawns = npcTabs[n] and npcTabs[n][7]
                if type(spawns) == "table" then for a in pairs(spawns) do z = a; break end end
                out[#out + 1] = (r and r[1] or "?") .. "@" .. place(z)
            end
        end
        if type(sb[2]) == "table" and #sb[2] > 0 then out[#out + 1] = "object " .. show(sb[2]) end
        if type(sb[3]) == "table" and #sb[3] > 0 then out[#out + 1] = "item " .. show(sb[3]) end
        return table.concat(out, "; ")
    end
    local chains = {}
    for id in pairs(ids) do
        local r = find(id)
        chains[r] = chains[r] or {}
        table.insert(chains[r], id)
    end
    local list = {}
    for _, c in pairs(chains) do
        table.sort(c, function(a, b)
            local la, lb = f(a, 4) or 0, f(b, 4) or 0
            if la ~= lb then return la < lb end
            return a < b
        end)
        list[#list + 1] = c
    end
    table.sort(list, function(a, b)
        local la, lb = f(a[1], 4) or 0, f(b[1], 4) or 0
        if la ~= lb then return la < lb end
        return a[1] < b[1]
    end)
    local n = 0
    for _ in pairs(ids) do n = n + 1 end
    print(string.format("%s: %d class quests in %d chains (base rows; corrections not applied)", which, n, #list))
    for _, c in ipairs(list) do
        print(string.format("chain of %d, req %s-%s:", #c, tostring(f(c[1], 4)), tostring(f(c[#c], 4))))
        for _, id in ipairs(c) do
            local extra = {}
            if repeatable(id) then extra[#extra + 1] = "repeatable" end
            if f(id, 7) ~= wantBit then extra[#extra + 1] = string.format("classes %.0f", f(id, 7)) end
            local pre = f(id, 13) or f(id, 12)
            if pre then extra[#extra + 1] = "pre " .. show(pre) end
            if f(id, 16) then extra[#extra + 1] = "excl " .. show(f(id, 16)) end
            if f(id, 18) then extra[#extra + 1] = "skill " .. show(f(id, 18)) end
            print(string.format("  %6d %-40s req %-3s lvl %-3s %-8s zone %-22s start %s %s", id, tostring(f(id, 1)),
                tostring(f(id, 4)), tostring(f(id, 5)), side(f(id, 6)), place(f(id, 17)), starter(id), table.concat(extra, " ")))
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
    local check = filter == "check"
    local rule = filter == "rule" or check
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
    if filter == "tab" then
        -- tab: the Reputation tab's catalogue (Azerfolio's ReputationRules.Catalogue, GroupOf,
        -- SourceList) over every quest with a reward, placed like Quests.Place. Base rows, both
        -- sides, repeatables not told apart.
        local rows, tabs = load(function(_, f) return f == 26 end)
        local fakeNs, areaNs = {}, {}
        assert(loadfile("Azerfolio/Systems/ReputationRules.lua"))("Azerfolio", fakeNs)
        assert(loadfile("Azerfolio/Data/QuestAreas.lua"))("Azerfolio", areaNs)
        local R, A = fakeNs.ReputationRules, areaNs.QuestAreaData
        local entries = {}
        for id, row in pairs(rows) do
            local v = row[17]
            local kind, key
            if type(v) ~= "number" or v == 0 then kind = "nozone"
            elseif v < 0 then kind, key = "sort", v
            elseif A.zone[v] then kind, key = "zone", A.zone[v]
            elseif A.dungeon[v] then kind, key = "dungeon", v
            elseif A.raid[v] then kind, key = "raid", v
            elseif A.battleground[v] then kind, key = "battleground", v
            else kind, key = "unmapped", v end
            if not (A.excludedQuests and A.excludedQuests[id]) then entries[#entries + 1] = { id = id, kind = kind, key = key } end
        end
        local cat = R.Catalogue(entries, function(id) return tabs[id] and tabs[id][26] end)
        local byGroup = {}
        for f, fc in pairs(cat) do
            local g = R.GroupOf(f, fc)
            byGroup[g] = byGroup[g] or {}
            table.insert(byGroup[g], { f = f, fc = fc })
        end
        local function label(src)
            local k = src.key
            if src.kind == "zone" then return tostring(zoneName[k] or k) end
            if src.kind == "class" then return src.classFile end
            if type(k) == "number" and k < 0 then return R.SORT_NAMES[k] or ("sort " .. k) end
            local z = zoneOf[k]
            return type(z) == "string" and z:gsub("^%a+:", "") or tostring(k)
        end
        local n = 0
        for _, g in ipairs(R.GROUPS) do
            local list = byGroup[g] or {}
            table.sort(list, function(a, b) return a.fc.raising > b.fc.raising or (a.fc.raising == b.fc.raising and a.f < b.f) end)
            if #list > 0 then print(string.format("== %s (%d)", g, #list)) end
            for _, x in ipairs(list) do
                n = n + 1
                local parts = {}
                for i, src in ipairs(R.SourceList(x.fc)) do
                    if i > 4 then parts[#parts + 1] = "..."; break end
                    parts[#parts + 1] = string.format("%s %s %d", src.kind, label(src), #src.quests)
                end
                print(string.format("%5d %-30s %4d raising, %3d unplaced: %s", x.f, tostring(names[x.f] or "?"), x.fc.raising,
                    x.fc.unplaced, table.concat(parts, "; ")))
            end
        end
        print(string.format("%d factions raised by quests (base rows)", n))
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
        if not check then
            print(string.format("Draft rule: not a home/battleground faction; >= %d raising quests in the zone, or >= %d when the zone has >= %d%% of them", MIN, LOW, SHARE * 100))
        end
        local zs, ref = {}, {}
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
            if #picks > 0 then ref[z] = picks end
            local parts = {}
            for _, x in ipairs(picks) do
                parts[#parts + 1] = string.format("%s(%d) %d, %d%%", names[x.f] or "?", x.f, x.n, math.floor(x.share * 100 + 0.5))
            end
            if not check then
                print(string.format("%-5d %-24s %s", z, tostring(zoneName[z]), #parts > 0 and table.concat(parts, "; ") or "-"))
            end
        end
        if not check then return end
        -- check: Azerfolio's ReputationRules on the same input must give the same zones and
        -- factions (and counts). Then the runtime-like input (repeatables and the curated
        -- excluded quests left out, as in Quests' zone counts) for comparison.
        local fakeNs = {}
        assert(loadfile("Azerfolio/Systems/ReputationRules.lua"))("Azerfolio", fakeNs)
        local areaNs = {}
        assert(loadfile("Azerfolio/Data/QuestAreas.lua"))("Azerfolio", areaNs)
        local excluded = areaNs.QuestAreaData.excludedQuests or {}
        local R = fakeNs.ReputationRules
        local function zonesInput(runtimeLike)
            local zones = {}
            for id, row in pairs(rows) do
                local z = row[17]
                local zk = type(z) == "number" and z > 0 and zoneOf[z]
                if type(zk) == "number" and not (runtimeLike and excluded[id]) then
                    zones[zk] = zones[zk] or {}
                    zones[zk][#zones[zk] + 1] = id
                end
            end
            return zones
        end
        local function rewardsOf(id) return tabs[id] and tabs[id][26] end
        local function describe(entry)
            local parts = {}
            for _, p in ipairs(entry or {}) do parts[#parts + 1] = (names[p.factionID] or p.factionID) .. " " .. p.count end
            return table.concat(parts, "; ")
        end
        local got = R.Build(zonesInput(false), rewardsOf)
        local zonesGot, mismatches = 0, 0
        for _, z in ipairs(zs) do
            local want, have = ref[z] or {}, got[z] and got[z].factions or {}
            if got[z] then zonesGot = zonesGot + 1 end
            local w, h = {}, {}
            for _, p in ipairs(want) do w[p.f] = p.n end
            for _, p in ipairs(have) do h[p.factionID] = p.count end
            local same = #want == #have
            for f, n in pairs(w) do if h[f] ~= n then same = false end end
            if not same then
                mismatches = mismatches + 1
                print(string.format("MISMATCH %d %s: draft rule %d factions, module: %s", z, tostring(zoneName[z]), #want, describe(have)))
            end
        end
        local nref = 0
        for _ in pairs(ref) do nref = nref + 1 end
        print(string.format("ReputationRules vs draft rule: %d zones vs %d, %d mismatches", zonesGot, nref, mismatches))
        local zlist = {}
        for z in pairs(got) do zlist[#zlist + 1] = z end
        table.sort(zlist)
        for _, z in ipairs(zlist) do
            local rv = {}
            for f, list in pairs(got[z].rivals) do
                for _, g in ipairs(list) do if f < g then rv[#rv + 1] = (names[f] or f) .. " <> " .. (names[g] or g) end end
            end
            print(string.format("  %-5d %-22s %s%s", z, tostring(zoneName[z]), describe(got[z].factions),
                #rv > 0 and ("  | rivals: " .. table.concat(rv, ", ")) or ""))
        end
        local rt = R.Build(zonesInput(true), rewardsOf)
        -- Systems/Reputation's input: the zone's counted and repeatable quests, without the
        -- curated excluded quests (corrections still apply only in game).
        print("Runtime input (Data/QuestAreas.lua excluded quests left out), differences:")
        local seen = {}
        for z in pairs(got) do seen[z] = true end
        for z in pairs(rt) do seen[z] = true end
        local all = {}
        for z in pairs(seen) do all[#all + 1] = z end
        table.sort(all)
        local diffs = 0
        for _, z in ipairs(all) do
            local a, b = describe(got[z] and got[z].factions), describe(rt[z] and rt[z].factions)
            if a ~= b then
                diffs = diffs + 1
                print(string.format("  %-5d %-22s all: %s | runtime: %s", z, tostring(zoneName[z]), a, b))
            end
        end
        if diffs == 0 then print("  none") end
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
