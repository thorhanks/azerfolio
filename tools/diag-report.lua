-- Summarizes the AzerfolioDiag SavedVariables dump.
-- Usage: luajit tools/diag-report.lua [section] [param]
-- Sections: summary (default), env, ach, explore, maps, quests, questdb [areas], taxi [nodes], zone, zones, events, art, errors,
--           criteria <achID>, ns <filter>, log [n], skin [tree [filter]], reps, spells, profs [run]
-- Set AZF_DIAG_FILE to read a different dump.
local DEFAULT = "C:/Program Files (x86)/World of Warcraft/_forever_/WTF/Account/COMPUTERWISPERER/SavedVariables/AzerfolioDiag.lua"

local section, arg2 = arg[1] or "summary", arg[2]
local path = os.getenv("AZF_DIAG_FILE") or DEFAULT

-- Load the file in an empty environment: it only assigns a table.
local chunk = assert(loadfile(path))
local env = {}
setfenv(chunk, env)
chunk()
local DB = assert(env.AzerfolioDiagDB, "AzerfolioDiagDB missing")

local function p(...) print(string.format(...)) end
local function keys(t) local k = {} for x in pairs(t or {}) do k[#k + 1] = x end table.sort(k, function(a, b) return tostring(a) < tostring(b) end) return k end
local function count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end
local function s(v) if type(v) == "table" then local o = {} for i, x in ipairs(v) do o[i] = tostring(x) end return "{" .. table.concat(o, ",") .. "}" end return tostring(v) end

local R = {}

-- /azfdiag profs: one block per run (profession window, trainer, vendor, bags). arg2 = run number
-- for every recipe and service line instead of the summary.
function R.profs()
    local runs = DB.profRuns
    if not runs or #runs == 0 then p("no profession probe; run /azfdiag profs, then /reload"); return end
    local only = tonumber(arg2)
    for n, r in ipairs(runs) do
        if not only or only == n then
            p("== run %d at %s, level %s", n, os.date("%m-%d %H:%M:%S", r.t), tostring(r.level))
            local missing = {}
            for _, k in ipairs(keys(r.has)) do if r.has[k] ~= "function" and r.has[k] ~= "table" then missing[#missing + 1] = k end end
            p("  missing: %s", #missing > 0 and table.concat(missing, ", ") or "none")
            p("  GetProfessions: %s", s(r.slots))
            for _, pr in ipairs(r.profs or {}) do
                local i, b = pr.info or {}, pr.bySkillLine
                p("  slot %s: %s rank %s/%s line %s spells %s offset %s spec %s | bySkillLine %s", tostring(pr.slot), tostring(i[1]),
                    tostring(i[3]), tostring(i[4]), tostring(i[7]), tostring(i[5]), tostring(i[6]), tostring(i[9]),
                    type(b) == "table" and string.format("%s %s/%s parent %s", tostring(b.professionName), tostring(b.skillLevel), tostring(b.maxSkillLevel), tostring(b.parentProfessionID)) or tostring(b))
            end
            for _, sk in ipairs(r.skills or {}) do
                if type(sk) == "table" then
                    p("  skill %s%-22s %s/%s id %s cat %s parent %s", sk.isHeader and "# " or "  ", tostring(sk.name), tostring(sk.rank), tostring(sk.maxRank),
                        tostring(sk.skillID), tostring(sk.skillLineCategoryID), tostring(sk.parentSkillLineID))
                end
            end
            for _, l in ipairs(r.lines or {}) do
                local b = l.info
                p("  trade line %s: %s", tostring(l.id), type(b) == "table" and string.format("%s %s/%s parent %s", tostring(b.professionName), tostring(b.skillLevel), tostring(b.maxSkillLevel), tostring(b.parentProfessionID)) or tostring(b))
            end
            for _, c in ipairs(r.spellCheck or {}) do
                p("  spell %-6d %-30s IsPlayerSpell %-5s C_SpellBook.IsSpellKnown %s", c.id, tostring(c.name), tostring(c.player), tostring(c.known))
            end
            local function schem(label, e)
                if not e then return end
                if not e.slots then p("    %s %-7s no schematic (%s)", label, tostring(e.id), tostring(e.none)); return end
                local parts = {}
                for _, c in ipairs(e.slots) do
                    parts[#parts + 1] = string.format("%sx%s %s (%s/%s)%s", tostring(c.q), tostring(c.name or c.items[1]), c.kind and ("t" .. tostring(c.kind)) or "",
                        tostring(c.bags), tostring(c.bank), #c.items > 1 and (" +" .. (#c.items - 1) .. " alt") or "")
                end
                p("    %s %-7s %-28s -> item %s x%s-%s: %s", label, tostring(e.id), tostring(e.name), tostring(e.out), tostring(e.qmin), tostring(e.qmax),
                    #parts > 0 and table.concat(parts, ", ") or "no reagents")
            end
            if r.shutSchematics then
                p("  ingredients (window %s): GetRecipeSchematic %s", r.windowOpen and "open" or "shut", tostring(r.has.GetRecipeSchematic))
                for _, e in ipairs(r.shutSchematics) do schem("shut", e) end
                if r.schematicSample and type(r.schematicSample) == "table" then p("  schematic fields: %s", table.concat(keys(r.schematicSample), " ")) end
                p("  tracking: GetRecipesTracked %s, SetRecipeTracked %s, ObjectiveTrackerFrame %s, ProfessionsRecipeTracker %s; tracked now %s",
                    tostring(r.has.GetRecipesTracked), tostring(r.has.SetRecipeTracked), tostring(r.has.ObjectiveTrackerFrame), tostring(r.has.ProfessionsRecipeTracker),
                    r.tracked and s(r.tracked.normal) or "?")
                for _, e in ipairs(r.trackedSchematics or {}) do schem("tracked", e) end
            end
            local w = r.window
            if w then
                local okS = 0
                for _, e in ipairs(w.schematics or {}) do if e.slots and #e.slots > 0 then okS = okS + 1 end end
                p("  window ingredients: %d of %d recipes have reagents", okS, #(w.schematics or {}))
                for k, e in ipairs(w.schematics or {}) do if only or k <= 6 then schem("win", e) end end
                local b = type(w.base) == "table" and w.base or {}
                local c = type(w.child) == "table" and w.child or {}
                p("  window: %s / %s %s/%s; showLearned %s showUnlearned %s; all %s->%s filtered %s->%s; learned %d unlearned %d; IsPlayerSpell agrees %d, differs %d",
                    tostring(b.professionName), tostring(c.professionName), tostring(c.skillLevel), tostring(c.maxSkillLevel),
                    tostring(w.showLearned), tostring(w.showUnlearned), tostring(w.allBefore), tostring(w.all), tostring(w.filteredBefore), tostring(w.filtered),
                    w.learned or 0, w.unlearned or 0, w.playerAgree or 0, w.playerDisagree or 0)
                if w.sample and w.sample[1] then p("  recipe fields: %s", table.concat(keys(w.sample[1]), " ")) end
                local srcs = {}
                for _, e in ipairs(w.recipes or {}) do srcs[tostring(e.src)] = (srcs[tostring(e.src)] or 0) + 1 end
                local o = {} for k, v in pairs(srcs) do o[#o + 1] = k .. "=" .. v end
                p("  sourceType counts: %s; categories %d", table.concat(o, " "), #(w.categories or {}))
                for _, c in ipairs(w.categories or {}) do
                    local i = type(c) == "table" and type(c.info) == "table" and c.info or {}
                    p("    category %s: %s parent %s", tostring(c.id), tostring(i.name), tostring(i.parentCategoryID))
                end
                for k, e in ipairs(w.recipes or {}) do
                    if only or k <= 8 then
                        p("    %7d %-36s learned %-5s player %-5s src %s cat %s diff %s trivial %s item %s", e.id, tostring(e.name), tostring(e.learned),
                            tostring(e.player), tostring(e.src), tostring(e.cat), tostring(e.diff), tostring(e.trivial), tostring(e.item))
                    end
                end
                for k, e in ipairs(w.sources or {}) do
                    if only or k <= 6 then p("    source %7d %s", e.id, tostring(e.text):gsub("\n", " | ")) end
                end
            end
            local t = r.trainer
            if t then
                p("  trainer: %d services", t.count or 0)
                for k, sv in ipairs(t.services or {}) do
                    if only or k <= 8 then
                        local i, sk = sv.info or {}, sv.skill or {}
                        p("    %-34s %-10s skill %s %s level %s cost %s line %s", tostring(i[1]), tostring(i[3]), tostring(sk[1]), tostring(sk[2]),
                            tostring(sv.level), tostring(sv.cost), tostring(sv.line))
                    end
                end
            end
            for label, list in pairs({ vendor = r.vendor and r.vendor.items, bags = r.bags }) do
                for _, e in ipairs(list or {}) do
                    p("  %s %6d %-34s sub %s spell %s | %s", label, e.id, tostring(e.name), tostring(e.sub), s(e.spell), table.concat(e.tip or {}, " / "))
                    if e.byID then p("      by ID: %s", table.concat(e.byID, " / ")) end
                end
            end
        end
    end
end

-- /azfdiag spells: the spellbook APIs, item types (does the client list spells not learned yet?),
-- the level each is learned at, and the trainer's list when its window was open.
function R.spells()
    local r = DB.spells
    if not r then p("no spell probe; run /azfdiag spells, then /reload"); return end
    p("spell probe at %s: %s level %s", os.date("%H:%M:%S", r.t), tostring(r.class), tostring(r.level))
    local present, missing = {}, {}
    for _, k in ipairs(keys(r.has)) do
        if r.has[k] == "function" or r.has[k] == "table" then present[#present + 1] = k else missing[#missing + 1] = k end
    end
    p("APIs present (%d): %s", #present, table.concat(present, ", "))
    p("missing: %s", table.concat(missing, ", "))
    for name, e in pairs(r.enum or {}) do
        local parts = {}
        for _, k in ipairs(keys(e)) do parts[#parts + 1] = k .. "=" .. tostring(e[k]) end
        p("Enum.%s: %s", name, table.concat(parts, " "))
    end
    local types = {}
    for _, k in ipairs(keys(r.byType)) do types[#types + 1] = k .. "=" .. r.byType[k] end
    p("spellbook: %d lines, %d items; by itemType: %s", #(r.lines or {}), #(r.items or {}), table.concat(types, " "))
    for i, l in ipairs(r.lines or {}) do
        p("  line %d: %s offset=%s items=%s hide=%s", i, tostring(l.name), tostring(l.itemIndexOffset), tostring(l.numSpellBookItems), tostring(l.shouldHide))
    end
    for _, it in ipairs(r.items or {}) do
        p("  #%s %-28s %-10s type=%s id=%s passive=%s learned@%s/%s known=%s", tostring(it.index), tostring(it.name), tostring(it.subName),
            tostring(it.itemType), tostring(it.spellID), tostring(it.isPassive), tostring(it.levelLearned), tostring(it.spellLevelLearned), tostring(it.known))
    end
    if r.levelSpells then
        local total = 0
        for lv = 1, 60 do
            local ls = r.levelSpells[lv]
            if ls and #ls.list > 0 then
                local parts = {}
                for _, e in ipairs(ls.list) do
                    parts[#parts + 1] = string.format("%s%s (%s, @%s%s)", tostring(e.name), e.sub and e.sub ~= "" and (" " .. e.sub) or "",
                        tostring(e.id), tostring(e.learnedAt), e.known and ", known" or "")
                end
                total = total + #ls.list
                p("  level %2d: %s", lv, table.concat(parts, "; "))
            end
        end
        p("GetCurrentLevelSpells: %d spells over levels 1-60 (type at level 1: %s)", total, tostring(r.levelSpells[1] and r.levelSpells[1].type))
    else
        p("GetCurrentLevelSpells: not probed (probe v1, or the function is missing)")
    end
    if r.trainer then
        -- Every field GetTrainerServiceInfo returned, for the first services (which is the rank?).
        for i = 1, math.min(3, #r.trainer.services) do
            local sv, parts = r.trainer.services[i], {}
            for k = 1, sv.info.n or #sv.info do parts[#parts + 1] = k .. "=" .. tostring(sv.info[k]) end
            p("  service %d fields: %s | cost %s", i, table.concat(parts, " "), sv.cost and s(sv.cost) or "?")
        end
        p("trainer: %d services", r.trainer.count)
        for i, sv in ipairs(r.trainer.services) do
            p("  %d %s | %s | %s | level %s", i, tostring(sv.info[1]), tostring(sv.info[2]), tostring(sv.info[3]), tostring(sv.level))
        end
    else
        p("trainer: window not open (open a class trainer and run /azfdiag spells again)")
    end
end

-- /azfdiag reps. GetFactionInfo returns (classic order): name, description, standingID, barMin,
-- barMax, barValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID.
function R.reps()
    local r = DB.reps
    if not r then p("no reputation probe; run /azfdiag reps, then /reload"); return end
    p("reputation probe at %s, map %s", os.date("%H:%M:%S", r.t), tostring(r.map))
    p("APIs:")
    for _, k in ipairs(keys(r.has)) do p("  %-48s %s", k, tostring(r.has[k])) end
    local labels = {}
    for i = 0, 9 do if r.labels[i] then labels[#labels + 1] = i .. "=" .. r.labels[i] end end
    p("standing labels: %s", table.concat(labels, ", "))
    p("factions: %s listed; before %s, after %s; expanded and restored: %s", tostring(r.count), tostring(r.countBefore),
        tostring(r.countAfter), table.concat(r.expandedHeaders or {}, ", "))
    for i, v in ipairs(r.list or {}) do
        local indent = v[9] and "" or "  "
        p("  %3d %s%-34s id %-5s st %-2s %s/%s..%s hdr %s rep %s child %s war %s%s", i, indent, tostring(v[1]), tostring(v[14]),
            tostring(v[3]), tostring(v[6]), tostring(v[4]), tostring(v[5]), tostring(v[9]), tostring(v[11]), tostring(v[13]),
            tostring(v[7]), v.inactive and " inactive" or "")
    end
    if r.cCount then p("C_Reputation list: %s entries (first: %s)", tostring(r.cCount), s(r.cList[1] and keys(r.cList[1]))) end
    p("by ID (GetFactionInfoByID):")
    for _, id in ipairs(keys(r.byID)) do
        local v = r.byID[id]
        p("  %-5s %-34s st %-2s %s/%s..%s  hasRep %s", tostring(id), tostring(v[1]), tostring(v[3]), tostring(v[6]),
            tostring(v[4]), tostring(v[5]), tostring(v[11]))
    end
    local function fd(v)
        return string.format("%-34s id %-5s reaction %-2s standing %s (%s..%s) hdr %s child %s collapsed %s acct %s war %s",
            tostring(v.name), tostring(v.factionID), tostring(v.reaction), tostring(v.currentStanding),
            tostring(v.currentReactionThreshold), tostring(v.nextReactionThreshold), tostring(v.isHeader),
            tostring(v.isChild), tostring(v.isCollapsed), tostring(v.isAccountWide), tostring(v.atWarWith))
    end
    for i, v in ipairs(r.cList or {}) do if type(v) == "table" then p("  %3d %s", i, fd(v)) end end
    if next(r.cByID or {}) then
        local n, missing = 0, {}
        for _, id in ipairs(keys(r.cByID)) do
            local v = r.cByID[id]
            if type(v) == "table" and next(v) then n = n + 1; p("  byID %s", fd(v)) else missing[#missing + 1] = tostring(id) end
        end
        p("C_Reputation.GetFactionDataByID: data for %d IDs; none for %s", n, table.concat(missing, ", "))
    end
    p("watched: %s", s(r.watched))
end

function R.errors()
    p("errors: %d", #(DB.errors or {}))
    for _, e in ipairs(DB.errors or {}) do p("  [%s] %s", e.label, e.err) end
end

function R.env()
    local e = DB.env or {}
    p("build: %s", s(e.build)); p("lua: %s  locale: %s  projectID: %s", tostring(e.lua), tostring(e.locale), tostring(e.projectID))
    for _, k in ipairs(keys(e.projectConstants)) do p("  %s = %s", k, tostring(e.projectConstants[k])) end
    local pl = e.player or {}
    p("player: %s-%s lvl %s race %s class %s faction %s xp %s/%s max %s", tostring(pl.name), tostring(pl.realm), tostring(pl.level),
        s(pl.race), s(pl.class), s(pl.faction), tostring(pl.xp), tostring(pl.xpMax), tostring(pl.maxLevel))
    p("C_ namespaces: %d", count(e.namespaces))
    p("globals:"); for _, k in ipairs(keys(e.globals)) do p("  %-34s %s", k, e.globals[k]) end
    p("templates:"); for _, k in ipairs(keys(e.templates)) do p("  %-34s %s", k, tostring(e.templates[k])) end
    p("matching globals (legacy/forever/explor): %d", count(e.matchingGlobals))
    for _, k in ipairs(keys(e.matchingGlobals)) do p("  %s (%s)", k, e.matchingGlobals[k]) end
    p("uiMapType: "); for _, k in ipairs(keys(e.uiMapType)) do p("  %s=%s", k, tostring(e.uiMapType[k])) end
end

function R.ns(filter)
    local e = DB.env or {}
    for _, k in ipairs(keys(e.namespaces)) do
        if not filter or k:lower():find(filter:lower(), 1, true) then
            p("%s: %s", k, table.concat(e.namespaces[k], ", "))
        end
    end
end

function R.ach()
    local a = DB.achievements or {}
    p("categories: %d, achievements: %d", #(a.categories or {}), #(a.all or {}))
    for _, c in ipairs(a.categories or {}) do
        p("  cat %-6s %-32s parent %-6s %-24s %s/%s", tostring(c.id), tostring(c.name), tostring(c.parent), tostring(c.parentName), tostring(c.completed), tostring(c.total))
    end
end

function R.explore()
    local a = DB.achievements or {}
    local list = {}
    for id, x in pairs(a.explore or {}) do list[#list + 1] = x end
    table.sort(list, function(x, y) return tostring(x.name) < tostring(y.name) end)
    p("explore achievements: %d", #list)
    for _, x in ipairs(list) do
        local done, assetAreas, withCID = 0, 0, 0
        local types = {}
        for _, c in ipairs(x.criteria or {}) do
            if c.done then done = done + 1 end
            if c.assetAreaName then assetAreas = assetAreas + 1 end
            if c.criteriaID and c.criteriaID ~= 0 then withCID = withCID + 1 end
            types[tostring(c.type)] = true
        end
        p("  %-6s %-40s cat %-6s %2d/%-2d done=%-5s areaAssets=%d critIDs=%d types=%s maps=%s",
            tostring(x.id), tostring(x.name), tostring(x.category), done, #(x.criteria or {}), tostring(x.done), assetAreas, withCID,
            table.concat(keys(types), "/"), s(x.matchedMapIDs))
    end
end

function R.criteria(id)
    local x = DB.achievements and DB.achievements.explore and DB.achievements.explore[tonumber(id)]
    if not x then p("no explore achievement %s", tostring(id)) return end
    p("%s %s desc=%s flags=%s", tostring(x.id), tostring(x.name), tostring(x.desc), tostring(x.flags))
    for _, c in ipairs(x.criteria or {}) do
        p("  %2d %-30s type=%s done=%s asset=%s (%s) critID=%s flags=%s qty=%s/%s elig=%s",
            c.index, tostring(c.name), tostring(c.type), tostring(c.done), tostring(c.assetID), tostring(c.assetAreaName),
            tostring(c.criteriaID), tostring(c.flags), tostring(c.qty), tostring(c.reqQty), tostring(c.eligible))
    end
end

function R.maps()
    local m = DB.maps or {}
    p("maps: %s", tostring(m.count))
    local byType = {}
    for _, x in pairs(m.byID or {}) do byType[x.mapType or -1] = (byType[x.mapType or -1] or 0) + 1 end
    for _, k in ipairs(keys(byType)) do p("  mapType %s: %d", tostring(k), byType[k]) end
    local zones = {}
    for id, x in pairs(m.byID or {}) do if x.mapType == 3 then zones[#zones + 1] = x end end
    table.sort(zones, function(a, b) return a.id < b.id end)
    p("zone maps (type 3): %d", #zones)
    for _, z in ipairs(zones) do
        local parent = m.byID[z.parent]
        p("  %-5d %-34s parent %-5s %-20s explored textures %s", z.id, tostring(z.name), tostring(z.parent), parent and tostring(parent.name) or "?", tostring(z.exploredTextureCount))
    end
end

function R.quests()
    local q = DB.quests or {}
    for _, k in ipairs(keys(q.has)) do p("  %-40s %s", k, tostring(q.has[k])) end
    p("allCompletedCount %s legacyCompletedCount %s logEntries %s", tostring(q.allCompletedCount), tostring(q.legacyCompletedCount), tostring(q.logEntries))
    for _, x in ipairs(q.samples or {}) do p("  quest %s done=%s title=%s", tostring(x.id), tostring(x.done), tostring(x.title)) end
end

-- taxi: the flight path probe (/azfdiag taxi, and automatically at a flight master).
-- `taxi nodes` prints every node with all its fields.
local function fields(t)
    local o = {}
    for _, k in ipairs(keys(t)) do
        local v = t[k]
        if type(v) == "table" then
            local inner = {}
            for _, k2 in ipairs(keys(v)) do inner[#inner + 1] = k2 .. "=" .. tostring(v[k2]) end
            v = "{" .. table.concat(inner, ",") .. "}"
        end
        o[#o + 1] = k .. "=" .. tostring(v)
    end
    return table.concat(o, " ")
end
function R.taxi()
    local all = DB.taxi
    if not all then p("no flight path probe recorded (/azfdiag taxi, or open a flight master's map)") return end
    for _, which in ipairs({ "probe", "master" }) do
        local r = all[which]
        if r then
            p("%s (%s) at %s, map %s, faction %s", which, tostring(r.reason), os.date("%H:%M:%S", r.t), tostring(r.map), s(r.faction))
            for _, k in ipairs(keys(r.has)) do p("  has %-24s %s", k, tostring(r.has[k])) end
            p("  GetTaxiNodesForMap: %s maps with nodes, %s nodes", tostring(r.zoneCount), tostring(r.nodeCount))
            for _, id in ipairs(keys(r.zones)) do
                local z = r.zones[id]
                p("  %d %s (type %s, show %s): %d nodes", id, tostring(z.name), tostring(z.mapType), tostring(z.show), #(z.nodes or {}))
                if arg2 == "nodes" or id == r.map then
                    for _, n in ipairs(z.nodes or {}) do p("      %s", fields(n)) end
                end
            end
            for _, id in ipairs(keys(r.all)) do
                local a = r.all[id]
                p("  GetAllTaxiNodes(%s): %d", tostring(id), a.count or 0)
                if arg2 == "nodes" then for _, n in ipairs(a.nodes or {}) do p("      %s", fields(n)) end end
            end
            local m = r.master or {}
            p("  flight master list: %s", tostring(m.count))
            for i, n in ipairs(m.nodes or {}) do p("    %d %s %s %s", i, tostring(n.type), tostring(n.name), s(n.pos)) end
        end
    end
end

-- questdb: the QuestieDB probe (/azfdiag questdb). `questdb areas` lists every quest area.
function R.questdb()
    local r = DB.questdb
    if not r then p("no QuestieDB probe recorded (/azfdiag questdb)") return end
    p("recorded %s: loaded %s (Questie %s), version %s, flavor %s, mode %s, usable %s", tostring(r.t), tostring(r.loaded),
        tostring(r.questieLoaded), tostring(r.version), tostring(r.flavorMeta), tostring(r.readMode or r.modeMeta), tostring(r.usable))
    for _, k in ipairs(keys(r.has)) do p("  has %-18s %s", k, tostring(r.has[k])) end
    p("contract %s (min %s); RequireContract(4) = %s", tostring(r.contractVersion), tostring(r.minSupportedContract), s(r.require4))
    for _, st in ipairs(r.stages or {}) do p("  stage %-14s %s %s", st.name, st.ok and "ok" or "FAILED", st.err or "") end
    local pl = r.player or {}
    p("player race %s class %s faction %s level %s map %s", tostring(pl.raceID), tostring(pl.classID), tostring(pl.faction), tostring(pl.level), tostring(pl.map))
    local function mem(m) return m and string.format("lua %s KB, QuestieDB %s KB", tostring(m.lua), tostring(m.questiedb)) or "-" end
    p("quests %s (GetAllIds %.2f ms)", tostring(r.idCount), r.idsMs or -1)
    local sp, sc, tp = r.scalarPass or {}, r.scalarPassCached or {}, r.tablePass or {}
    p("scalar pass: %d fields, %s reads, %.1f ms (%s), %s errors; again %.1f ms", sp.fields or 0, tostring(sp.reads), sp.ms or -1, tostring(sp.clock), tostring(sp.errors), sc.ms or -1)
    p("table pass: %d fields, %s reads, %.1f ms, %s errors; present %s", tp.fields or 0, tostring(tp.reads), tp.ms or -1, tostring(tp.errors),
        (function() local o = {} for _, k in ipairs(keys(tp.present)) do o[#o + 1] = k .. "=" .. tp.present[k] end return table.concat(o, " ") end)())
    p("memory before: %s", mem(r.memBefore)); p("after scalars: %s", mem(r.memAfterScalars)); p("after tables: %s", mem(r.memAfterTables))
    p("zoneOrSort: %d areas, %d sorts, %s missing; repeatable %s", count(r.areas), count(r.sorts), tostring(r.missingZone), tostring(r.repeatable))
    local c = r.compare or {}
    p("composed vs base (%.1f ms): %s", c.ms or -1,
        (function() local o = {} for _, k in ipairs(keys(c.changed)) do o[#o + 1] = k .. "=" .. c.changed[k] end return #o > 0 and table.concat(o, " ") or "no changes" end)())
    for _, d in ipairs(c.samples or {}) do p("  quest %-6s %-16s base %s -> %s", tostring(d.id), d.field, tostring(d.base), tostring(d.composed)) end
    local done = r.completed or {}
    p("completed %s, known to QuestieDB %s; unknown sample %s", tostring(done.count), tostring(done.known), s(done.missing))
    local function kv(t) local o = {} for _, k in ipairs(keys(t)) do o[#o + 1] = tostring(k) .. "=" .. tostring(t[k]) end return table.concat(o, " ") end
    p("race masks: %s", kv(r.factionRaceMasks)); p("class keys: %s", kv(r.classKeys)); p("race keys: %s", kv(r.raceKeys))
    p("client races:"); for _, i in ipairs(keys(r.clientRaces)) do local x = r.clientRaces[i] p("  %2s %-14s %-12s id %s", tostring(i), tostring(x.name), tostring(x.file), tostring(x.id)) end
    p("client classes:"); for _, i in ipairs(keys(r.clientClasses)) do local x = r.clientClasses[i] p("  %2s %-12s %-10s id %s", tostring(i), tostring(x.name), tostring(x.file), tostring(x.id)) end
    local zones, other = 0, 0
    for _, e in pairs(r.areaMap or {}) do if e.isZone then zones = zones + 1 else other = other + 1 end end
    p("area table: base %s override %s; quest areas on a zone map %d, elsewhere or unmapped %d", tostring(r.areaTable and r.areaTable.base),
        tostring(r.areaTable and r.areaTable.override), zones, other)
    if arg2 == "areas" then
        local ids = keys(r.areaMap); table.sort(ids, function(a, b) return a < b end)
        for _, a in ipairs(ids) do
            local e = r.areaMap[a]
            p("  area %-6d %-26s quests %-4d -> map %-5s %-26s type %s parent %s", a, tostring(e.areaName), e.quests or 0,
                tostring(e.uiMap), tostring(e.mapName), tostring(e.mapType), tostring(e.parent))
        end
        p("sorts:"); for _, k in ipairs(keys(r.sorts)) do p("  %s: %s", tostring(k), tostring(r.sorts[k])) end
    end
    p("samples (area %s):", tostring(r.sampleArea))
    for _, q in ipairs(r.samples or {}) do
        p("  %s %s lvl %s req %s races %s classes %s flags %s/%s next %s excl %s pre %s/%s start %s", tostring(q.id), tostring(q.name),
            tostring(q.questLevel), tostring(q.requiredLevel), tostring(q.requiredRaces), tostring(q.requiredClasses), tostring(q.specialFlags),
            tostring(q.questFlags), tostring(q.nextQuestInChain), s(q.exclusiveTo), s(q.preQuestSingle), s(q.preQuestGroup),
            type(q.startedBy) == "table" and s(q.startedBy[1]) or tostring(q.startedBy))
    end
end

function R.zone()
    for i, z in ipairs(DB.zoneSnapshots or {}) do
        local w = z.where or {}
        p("snapshot %d: map %s zone %s sub %s pos %s,%s", i, tostring(w.map), tostring(w.zone), tostring(w.subzone), tostring(w.x), tostring(w.y))
        for _, a in ipairs(w.areas or {}) do p("  area here: %s %s", tostring(a.id), tostring(a.name)) end
        for _, c in ipairs(z.mapChain or {}) do p("  chain: %s %s type %s", tostring(c.id), tostring(c.name), tostring(c.mapType)) end
        p("  explored textures: %d", #(z.exploredTextures or {}))
        local t1 = z.exploredTextures and z.exploredTextures[1]
        if t1 then for _, k in ipairs(keys(t1)) do p("    tex[1].%s = %s", k, s(t1[k])) end end
        if z.exploreAchievement then p("  achievement %s %s", tostring(z.exploreAchievement.id), tostring(z.exploreAchievement.name)) end
    end
end

-- zones: the raw zone metadata probe (/azfdiag zones), one line per zone map.
function R.zones()
    local z = DB.zoneMeta
    if not z then p("no zone metadata recorded (/azfdiag zones)") return end
    local pl = z.player or {}
    p("recorded %s: %s zones; player level %s faction %s map %s pvp %s", tostring(z.t), tostring(z.count),
        tostring(pl.level), s(pl.faction), tostring(pl.map), s(pl.pvp))
    for _, k in ipairs(keys(z.has)) do p("  has %-16s %s", k, tostring(z.has[k])) end
    local function packed(t)
        if type(t) ~= "table" then return tostring(t) end
        local o = {}
        for i = 1, (t.n or #t) do
            local v = t[i]
            if type(v) == "table" then
                local f = {}
                for _, k in ipairs(keys(v)) do f[#f + 1] = k .. "=" .. tostring(v[k]) end
                v = "{" .. table.concat(f, " ") .. "}"
            end
            o[#o + 1] = tostring(v)
        end
        return "(" .. table.concat(o, ", ") .. ")"
    end
    local ids = keys(z.zones)
    table.sort(ids, function(a, b) return a < b end)
    for _, id in ipairs(ids) do
        local x = z.zones[id]
        p("  %-5d %-28s parent %-5s flags %-6s levels %-22s rect %s%s", id, tostring(x.name), tostring(x.parent),
            tostring(x.flags), packed(x.levels), packed(x.rect), x.world and ("  world " .. packed(x.world)) or "")
    end
    for _, id in ipairs(keys(z.continents or {})) do
        p("  continent %d on the world map: %s", id, packed(z.continents[id]))
    end
end

function R.events()
    p("registration:"); for _, k in ipairs(keys(DB.eventRegistration)) do p("  %-30s %s", k, tostring(DB.eventRegistration[k])) end
    p("counts:"); for _, k in ipairs(keys(DB.eventCounts)) do p("  %-30s %s", k, tostring(DB.eventCounts[k])) end
    p("log entries: %d, diffs: %d", #(DB.log or {}), #(DB.diffs or {}))
    for _, d in ipairs(DB.diffs or {}) do
        p("  diff t=%s map=%s textures %s->%s triggers=%d", tostring(d.t), tostring(d.textures and d.textures.map), tostring(d.textures and d.textures.before), tostring(d.textures and d.textures.after), #(d.triggers or {}))
        for _, c in ipairs(d.changes or {}) do p("    %s #%s %s asset=%s crit=%s %s->%s", tostring(c.achName), tostring(c.index), tostring(c.name), tostring(c.assetID), tostring(c.criteriaID), tostring(c.from), tostring(c.to)) end
        for _, tr in ipairs(d.triggers or {}) do p("    trigger %s @%s", tostring(tr.e), tostring(tr.gt)) end
    end
    if DB.sniff then
        p("sniff (on=%s): %d distinct events", tostring(DB.sniffOn), count(DB.sniff.counts))
        local list = {}
        for k, v in pairs(DB.sniff.counts) do list[#list + 1] = { k, v } end
        table.sort(list, function(a, b) return a[2] > b[2] end)
        for i = 1, #list do p("  %-44s %d", list[i][1], list[i][2]) end
    end
end

function R.log(n)
    local log = DB.log or {}
    n = tonumber(n) or 60
    for i = math.max(1, #log - n + 1), #log do
        local l = log[i]
        local args = {}
        for j = 1, (l.args and l.args.n or 0) do args[#args + 1] = tostring(l.args[j]) end
        p("%s %-28s map=%s sub=%s args=%s", tostring(l.gt), l.e, tostring(l.where and l.where.map), tostring(l.where and l.where.subzone), table.concat(args, " | "))
    end
end

function R.art()
    for _, r in ipairs((DB.art or {}).results or {}) do
        p("  %-24s ok=%s ret=%s tex=%s fileID=%s", r.label, tostring(r.pcallOk), tostring(r.setTextureReturn), tostring(r.getTexture), tostring(r.getTextureFileID))
    end
end

function R.pad()
    local pad = DB.pad
    if not pad then p("no gamepad probe recorded") return end
    local e = pad.env or {}
    for _, k in ipairs(keys(e)) do
        if type(e[k]) ~= "table" then p("  %-22s %s", k, tostring(e[k])) end
    end
    p("  frame methods:"); for _, k in ipairs(keys(e.frameMethods)) do p("    %-26s %s", k, tostring(e.frameMethods[k])) end
    p("  C_GamePad: %s", table.concat(e.C_GamePadFunctions or {}, ", "))
    p("  constants:"); for _, k in ipairs(keys(e.constants)) do p("    %-36s %s", k, tostring(e.constants[k])) end
    p("  enableButton=%s enableStick=%s focusGamepad=%s stoppedBy=%s", tostring(pad.enableButton), tostring(pad.enableStick), tostring(pad.focusGamepad), tostring(pad.stoppedBy))
    p("  presses: %d", #(pad.presses or {}))
    for _, x in ipairs(pad.presses or {}) do if x.down then p("    %-16s @%.2f", x.key, (x.gt or 0) - (pad.startedAt or 0)) end end
    p("  sticks: %d", #(pad.sticks or {}))
    for i, s in ipairs(pad.sticks or {}) do if i <= 10 then p("    %s x=%.2f y=%.2f", s.stick, s.x or 0, s.y or 0) end end
end

-- skin: unique atlases, files and fonts per probed frame. "skin tree [root|overlays|templates]"
-- prints the indented frame tree instead.
local function eachNode(node, depth, fn)
    if type(node) ~= "table" then return end
    fn(node, depth)
    for _, r in ipairs(node.regions or {}) do fn(r, depth + 1) end
    for _, c in ipairs(node.children or {}) do eachNode(c, depth + 1, fn) end
end

local function nodeLine(n)
    local size = n.size and string.format("%sx%s", tostring(math.floor((tonumber(n.size[1]) or 0) + 0.5)), tostring(math.floor((tonumber(n.size[2]) or 0) + 0.5))) or "?"
    local label = (n.key and n.key ~= "nil" and n.key) or n.name or ""
    local bits = { tostring(n.type), label, size, n.shown == false and "hidden" or "" }
    if n.atlas and n.atlas ~= "nil" then bits[#bits + 1] = "atlas=" .. tostring(n.atlas) end
    if (not n.atlas or n.atlas == "nil") and n.texture and n.texture ~= "nil" then bits[#bits + 1] = "tex=" .. tostring(n.texture) end
    if n.fileID and n.fileID ~= "nil" then bits[#bits + 1] = "id=" .. tostring(n.fileID) end
    if n.layer then bits[#bits + 1] = "layer=" .. s(n.layer) end
    if n.color then bits[#bits + 1] = "rgba=" .. s(n.color) end
    if n.font then bits[#bits + 1] = "font=" .. s(n.font) end
    if n.text and n.text ~= "nil" then bits[#bits + 1] = "text=" .. tostring(n.text) end
    return table.concat(bits, " ")
end

local function skinRoots(sk)
    local list = {}
    for _, k in ipairs(keys(sk.roots)) do list[#list + 1] = { k, sk.roots[k] } end
    for i, o in ipairs(sk.overlays or {}) do list[#list + 1] = { "overlay" .. i .. " " .. tostring(o.name), o } end
    for _, t in ipairs(sk.templates or {}) do list[#list + 1] = { "template " .. t.template, t.tree } end
    return list
end

function R.skin(mode, which)
    local sk = DB.skin
    if not sk then p("no skin probe recorded") return end
    if mode == "tree" then
        for _, pair in ipairs(skinRoots(sk)) do
            if not which or pair[1]:lower():find(which:lower(), 1, true) then
                p("== %s", pair[1])
                eachNode(pair[2], 0, function(n, d)
                    if n.type == "Texture" or n.type == "FontString" or n.type == "MaskTexture" then
                        if n.shown == false then return end
                    end
                    p("%s%s", string.rep("  ", d), nodeLine(n))
                end)
            end
        end
        return
    end
    for _, pair in ipairs(skinRoots(sk)) do
        local atlases, files, fonts, nodes = {}, {}, {}, 0
        eachNode(pair[2], 0, function(n)
            nodes = nodes + 1
            if n.atlas and n.atlas ~= "nil" then atlases[n.atlas] = (atlases[n.atlas] or 0) + 1
            elseif n.texture and n.texture ~= "nil" then files[tostring(n.texture)] = (files[tostring(n.texture)] or 0) + 1 end
            if n.font then local f = s(n.font); fonts[f] = (fonts[f] or 0) + 1 end
        end)
        p("== %s (%d nodes%s)", pair[1], nodes, type(pair[2]) == "table" and pair[2].shown == false and ", hidden" or "")
        for _, k in ipairs(keys(atlases)) do p("  atlas %-50s x%d", k, atlases[k]) end
        for _, k in ipairs(keys(files)) do p("  file  %-50s x%d", k, files[k]) end
        for _, k in ipairs(keys(fonts)) do p("  font  %-50s x%d", k, fonts[k]) end
    end
    p("atlas checks:")
    for _, k in ipairs(keys(sk.atlases)) do
        local a = sk.atlases[k]
        p("  %-45s %s", k, a and string.format("file=%s %sx%s", tostring(a.file or a.filename), tostring(a.width), tostring(a.height)) or "MISSING")
    end
    p("templates:")
    for _, t in ipairs(sk.templates or {}) do p("  %-28s %s", t.template, t.ok and "ok" or ("FAILED " .. tostring(t.err))) end
end

function R.summary()
    R.errors(); print(); R.env(); print(); R.explore(); print(); R.quests(); print(); R.art()
end

local fn = R[section]
if not fn then print("unknown section " .. section) os.exit(1) end
fn(arg2, arg[3])
