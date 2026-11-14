-- Professions (Phase 14 step 4; spec §8.12; docs/research/professions.md): this character's
-- professions from the game, plus what the game shows only while a window is open, recorded per
-- character (AzerfolioCharDB.professions):
--   windows[skillLine]  = { time, rows = { { id, name, learned, grey, category } }, categories = { [id] = name } }
--                         the profession window's whole recipe list, read when it opens
--   trainers[skillLine] = { time, services = { [name] = { kind, skill, cost } } }
--                         profession trainers' lists, merged by service name (a later visit
--                         updates what it lists, keeps what an earlier trainer listed)
-- Learned state stays live with IsPlayerSpell(recipeID) [verified-ingame: 550 of 550 agree].
-- Skill and cap from GetProfessionInfo [verified-ingame]; GetProfessionInfoBySkillLineID reads
-- 0/0 until a window opens, so it isn't used. Rules: Systems/ProfessionRules. Recipe item
-- sources, ingredients and tracking come in step 5.
-- Announces AZF_PROFESSIONS_UPDATED.
local _, ns = ...

local Prof = {}
ns.Professions = Prof

local MAX_RECIPES = 1500 -- Blacksmithing lists 507 [verified-ingame]; a cap against a runaway list

local function try(label, fn, ...) return ns.Debug.Try(label, fn, ...) end
local function clock() return type(debugprofilestop) == "function" and debugprofilestop() or nil end

local cache -- Prof.Get()'s result until something changes

local function store()
    local c = ns.charDB
    if not c then return nil end
    if type(c.professions) ~= "table" then c.professions = {} end
    local p = c.professions
    if type(p.windows) ~= "table" then p.windows = {} end
    if type(p.trainers) ~= "table" then p.trainers = {} end
    return p
end

local function changed(why)
    cache = nil
    ns.Events.Debounce("professions:changed", 0.2, function() ns.Events.Send("AZF_PROFESSIONS_UPDATED", why) end)
end

-- This character's professions: { { skillLine, name, skill, cap, icon } ... } (primary and
-- secondary; GetProfessions gives 5 slots on Gideon, nil for an empty one [verified-ingame]).
function Prof.Skills()
    if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then return {} end
    local slots = { pcall(GetProfessions) }
    if not slots[1] then ns.Debug.Error("GetProfessions", slots[2]); return {} end
    local out, seen = {}, {}
    for i = 2, table.maxn(slots) do
        local slot = slots[i]
        if type(slot) == "number" then
            -- name, icon, skill, max, numAbilities, spellOffset, skillLine [verified-ingame]
            local name, icon, skill, cap, _, _, line = try("GetProfessionInfo", GetProfessionInfo, slot)
            if type(line) == "number" and not seen[line] and ns.ProfessionData.skills[line] then
                seen[line] = true
                out[#out + 1] = { skillLine = line, name = name, icon = icon,
                    skill = type(skill) == "number" and skill or nil, cap = type(cap) == "number" and cap or nil }
            end
        end
    end
    return out
end

-- Reads the open profession window (yours, not a linked or guild one). Returns the record or nil.
local function readWindow()
    local T = rawget(_G, "C_TradeSkillUI")
    if type(T) ~= "table" or type(T.IsTradeSkillReady) ~= "function" or not try("IsTradeSkillReady", T.IsTradeSkillReady) then return nil end
    if type(T.IsTradeSkillLinked) == "function" and try("IsTradeSkillLinked", T.IsTradeSkillLinked) then return nil end
    if type(T.IsTradeSkillGuild) == "function" and try("IsTradeSkillGuild", T.IsTradeSkillGuild) then return nil end
    local base = type(T.GetBaseProfessionInfo) == "function" and try("GetBaseProfessionInfo", T.GetBaseProfessionInfo)
    local line = type(base) == "table" and base.professionID
    if type(line) ~= "number" or not ns.ProfessionData.skills[line] then return nil end
    local ids = type(T.GetAllRecipeIDs) == "function" and try("GetAllRecipeIDs", T.GetAllRecipeIDs)
    if type(ids) ~= "table" or #ids == 0 then return nil end
    local rows, cats = {}, {}
    for i, id in ipairs(ids) do
        if i > MAX_RECIPES then break end
        local info = type(T.GetRecipeInfo) == "function" and try("GetRecipeInfo", T.GetRecipeInfo, id)
        if type(info) == "table" and type(info.name) == "string" then
            -- The crafted item from the recipe's hyperlink ("|Hitem:227684:..." [verified-ingame,
            -- probe run 4]), so an ingredient can say "Craft it: <recipe>".
            local item = type(info.hyperlink) == "string" and tonumber(info.hyperlink:match("item:(%d+)")) or nil
            rows[#rows + 1] = { id = id, name = info.name, learned = info.learned and true or false,
                grey = type(info.maxTrivialLevel) == "number" and info.maxTrivialLevel or nil,
                category = type(info.categoryID) == "number" and info.categoryID or 0,
                item = item and item > 0 and item or nil }
            local cat = info.categoryID
            if type(cat) == "number" and cat > 0 and cats[cat] == nil and type(T.GetCategoryInfo) == "function" then
                local c = try("GetCategoryInfo", T.GetCategoryInfo, cat)
                cats[cat] = type(c) == "table" and type(c.name) == "string" and c.name or false
            end
        end
    end
    for k, v in pairs(cats) do if v == false then cats[k] = nil end end
    if #rows == 0 then return nil end
    return line, { time = time and time() or nil, rows = rows, categories = cats }
end

local function recordWindow()
    local started = clock()
    local line, rec = readWindow()
    if not line then return end
    local p = store()
    if not p then return end
    p.windows[line] = rec
    local learned = 0
    for _, r in ipairs(rec.rows) do if r.learned then learned = learned + 1 end end
    local ms = started and clock() and (clock() - started) or nil
    ns.Debug.Trace("professions", { event = "window", skillLine = line, count = #rec.rows, learned = learned, ms = ms })
    changed("window")
end

-- The open trainer's profession (its services name it: GetTrainerServiceSkillLine = "Cooking"
-- [verified-ingame, probe runs 1-2]) and its services.
local function lineByName(name)
    for line, d in pairs(ns.ProfessionData.skills) do if d.name == name then return line end end
end

local function readTrainer()
    if type(IsTradeskillTrainer) ~= "function" or not try("IsTradeskillTrainer", IsTradeskillTrainer) then return nil end
    if type(GetTrainerServiceInfo) ~= "function" then return nil end
    local count = 0
    local byLine = ns.ClassTrainer.WithAllFilters(function(n)
        count = n
        local byLine = {}
        for i = 1, n do
            local name, kind = try("GetTrainerServiceInfo", GetTrainerServiceInfo, i)
            local lineName = type(GetTrainerServiceSkillLine) == "function" and try("GetTrainerServiceSkillLine", GetTrainerServiceSkillLine, i)
            local line = type(lineName) == "string" and lineByName(lineName)
            if line and type(name) == "string" and (kind == "used" or kind == "available" or kind == "unavailable") then
                -- skill name, skill needed, met [verified-ingame]; no requirement = 0 (Apprentice)
                local need
                if type(GetTrainerServiceSkillReq) == "function" then
                    need = select(2, try("GetTrainerServiceSkillReq", GetTrainerServiceSkillReq, i))
                end
                local cost = type(GetTrainerServiceCost) == "function" and try("GetTrainerServiceCost", GetTrainerServiceCost, i)
                byLine[line] = byLine[line] or {}
                byLine[line][name] = { kind = kind, skill = type(need) == "number" and need or 0,
                    cost = type(cost) == "number" and cost or nil }
            end
        end
        return byLine
    end)
    return byLine, count
end

local lastSignature -- ClassTrainer.Signature() at the last read; cleared when a trainer opens
local function recordTrainer()
    if ns.ClassTrainer.IsReading() then return end
    if type(IsTradeskillTrainer) ~= "function" or not try("IsTradeskillTrainer", IsTradeskillTrainer) then return end
    local sig = ns.ClassTrainer.Signature()
    if sig == lastSignature then return end -- our own filter changes, or nothing new
    lastSignature = sig
    local byLine, n = readTrainer()
    if byLine and not next(byLine) and (n or 0) > 0 then
        -- A profession trainer whose services named no profession we know: say so in the trace.
        ns.Debug.Trace("professions", { event = "trainer?", count = n })
    end
    if not byLine or not next(byLine) then return end
    local p = store()
    if not p then return end
    for line, services in pairs(byLine) do
        local rec = p.trainers[line]
        if type(rec) ~= "table" or type(rec.services) ~= "table" then rec = { services = {} }; p.trainers[line] = rec end
        local n = 0
        for name, s in pairs(services) do rec.services[name] = s; n = n + 1 end
        rec.time = time and time() or nil
        ns.Debug.Trace("professions", { event = "trainer", skillLine = line, count = n })
    end
    changed("trainer")
end

-- Pure-ish helpers for Get: the trainer's recipe skills by name (rank services left out: they
-- aren't in the window's list, so they never match a recipe).
local function trainerSkills(rec)
    local out = {}
    if type(rec) == "table" and type(rec.services) == "table" then
        for name, s in pairs(rec.services) do
            if type(s) == "table" and type(s.skill) == "number" then out[name] = s.skill end
        end
    end
    return out
end

local function isPlayerSpell(id)
    if type(IsPlayerSpell) ~= "function" then return nil end
    local ok, v = pcall(IsPlayerSpell, id)
    if not ok then return nil end
    return v and true or false
end

-- The continent a map lies on (walking its parents to a Continent map), cached; nil when not known.
local CONTINENT = (rawget(_G, "Enum") and Enum.UIMapType and Enum.UIMapType.Continent) or 2
local continents = {}
local function continentOf(mapID)
    if type(mapID) ~= "number" then return nil end
    if continents[mapID] ~= nil then return continents[mapID] or nil end
    local id, found, guard = mapID, nil, 0
    while type(id) == "number" and id > 0 and guard < 8 do
        local info = C_Map and type(C_Map.GetMapInfo) == "function" and try("GetMapInfo", C_Map.GetMapInfo, id)
        if type(info) ~= "table" then break end
        if info.mapType == CONTINENT then found = id; break end
        id, guard = info.parentMapID, guard + 1
    end
    continents[mapID] = found or false
    return found
end

-- How near a trainer's zone is: 0 the zone you're in, 1 your continent, 2 elsewhere.
local function nearness()
    local here = ns.Exploration and ns.Exploration.CurrentZone and ns.Exploration.CurrentZone()
    if not here and C_Map and type(C_Map.GetBestMapForUnit) == "function" then here = try("GetBestMapForUnit", C_Map.GetBestMapForUnit, "player") end
    local hc = continentOf(here)
    return function(mapID)
        if not mapID then return 2 end
        if mapID == here then return 0 end
        if hc and continentOf(mapID) == hc then return 1 end
        return 2
    end
end

-- Everything the tab and the Overview panel show:
--   { professions = { { model (ProfessionRules.Profession), status, stones, recipes (nil = window
--       not read), recipesTime, trainerTime, gatherRows (nil = no gathering), nextUp, trainers
--       (for the next rank) } ... } in rail order, summary = { mastered, total },
--     sources = ProfessionSources.State().status, tracked = { [recipeID] = true } }
-- Rebuilt when something changes (events), or when the game's tracked recipes differ.
function Prof.Get()
    local tracked, trackedSig = Prof.Tracked()
    if cache and cache.trackedSig == trackedSig then return cache end
    local R = ns.ProfessionRules
    local Src = ns.ProfessionSources
    local sourcesReady = Src.State().status == "ready"
    local side = ns.character and ns.character.faction == "Horde" and "H" or (ns.character and ns.character.faction == "Alliance" and "A") or nil
    local p = store() or { windows = {}, trainers = {} }
    local near = nearness()
    local list = {}
    for _, s in ipairs(Prof.Skills()) do
        local m = R.Profession(s)
        local win = p.windows[s.skillLine]
        local tr = p.trainers[s.skillLine]
        local recipes
        -- A recorded window shows its recipes even for a gathering profession (Fishing lists 3
        -- Camping recipes [verified-ingame, Gideon 2026-11-14]); only crafting ones ask you to
        -- open the window before one has been seen.
        if type(win) == "table" and type(win.rows) == "table" and #win.rows > 0 then m.hasRecipes = true end
        if m.hasRecipes and type(win) == "table" and type(win.rows) == "table" then
            local rows, itemsByName, output = {}, {}, {}
            for i, r in ipairs(win.rows) do
                rows[i] = { id = r.id, name = r.name, learned = r.learned, grey = r.grey, category = r.category,
                    categoryName = type(win.categories) == "table" and win.categories[r.category] or nil }
                output[r.id] = r.item
                if sourcesReady then itemsByName[r.name] = Src.RecipeItem(s.skillLine, r.name) end
            end
            recipes = R.Recipes(rows, { skill = m.skill, trainer = trainerSkills(tr), known = isPlayerSpell,
                items = itemsByName, tracked = tracked })
            -- Output item for each recipe, for "Craft it" (rows recorded before step 5 have none).
            for _, r in ipairs(recipes.list) do r.item = output[r.id] end
        end
        if m.next and sourcesReady then
            m.trainers = R.TrainersFor(Src.Trainers(s.skillLine), m.next.name, side, ns.ZoneData and ns.ZoneData.faction, near)
        end
        local gather
        if m.gather then gather = R.Gather(m.gather, m.skill, ns.ZoneData and ns.ZoneData.levels) end
        m.status = R.Status(m, recipes)
        m.stones = R.Stones(m.skill, m.cap)
        m.recipes = recipes
        m.recipesTime = type(win) == "table" and win.time or nil
        m.trainerTime = type(tr) == "table" and tr.time or nil
        m.gatherRows = gather
        m.nextUp = R.NextUp(m, recipes, gather)
        list[#list + 1] = m
    end
    list = R.Order(list)
    cache = { professions = list, summary = R.Summary(list), sources = Src.State().status,
        tracked = tracked, trackedSig = trackedSig }
    return cache
end

---------------------------------------------------------------------------------------------
-- The game's recipe tracking (owner, 2026-11-14: no tracker of our own). GetRecipesTracked(false)
-- lists the tracked recipe IDs with the window shut [verified-ingame, probe run 8: {3275}].
---------------------------------------------------------------------------------------------

-- { [recipeID] = true }, and a signature to notice changes.
function Prof.Tracked()
    local T = rawget(_G, "C_TradeSkillUI")
    local out, ids = {}, {}
    if type(T) == "table" and type(T.GetRecipesTracked) == "function" then
        local ok, list = pcall(T.GetRecipesTracked, false)
        if ok and type(list) == "table" then
            for _, id in ipairs(list) do
                if type(id) == "number" then out[id] = true; ids[#ids + 1] = id end
            end
        end
    end
    table.sort(ids)
    return out, table.concat(ids, ",")
end

-- Can the game track recipes at all on this client?
function Prof.CanTrack()
    local T = rawget(_G, "C_TradeSkillUI")
    return type(T) == "table" and type(T.SetRecipeTracked) == "function" and type(T.GetRecipesTracked) == "function"
end

-- The player's X: track or untrack a recipe in the game's objective tracker. Returns the
-- recipe's tracked state as the game reports it afterwards (true/false), or nil when the call
-- failed. Never called by Azerfolio on its own.
function Prof.SetTracked(recipeID, on)
    if not Prof.CanTrack() or type(recipeID) ~= "number" then return nil end
    local T = C_TradeSkillUI
    -- (recipeID, tracked, isRecraft): the third is required on this client [verified-ingame:
    -- "Usage: C_TradeSkillUI.SetRecipeTracked(recipeID, tracked, isRecraft)", 2026-11-14].
    local ok, err = pcall(T.SetRecipeTracked, recipeID, on and true or false, false)
    if not ok then ns.Debug.Error("SetRecipeTracked", err); return nil end
    local now = Prof.Tracked()
    local state = now[recipeID] and true or false
    ns.Debug.Trace("professions", { event = "track", recipeID = recipeID, asked = on and true or false, tracked = state })
    changed("tracked")
    return state
end

---------------------------------------------------------------------------------------------
-- Ingredients: GetRecipeSchematic answers with the window shut, for any recipe [verified-ingame,
-- probe runs 7-8]; have = C_Item.GetItemCount (bags). Names: QuestieDB's item name first (no
-- server query), else the client's (nil until cached: asked for, and GET_ITEM_INFO_RECEIVED
-- refreshes).
---------------------------------------------------------------------------------------------

local schematics = {} -- [recipeID] = { output, reagents = { { itemID, need } } } or false
local waitingItems = {} -- item IDs whose names we asked the client for

local function schematic(recipeID)
    if schematics[recipeID] ~= nil then return schematics[recipeID] or nil end
    local T = rawget(_G, "C_TradeSkillUI")
    local s = type(T) == "table" and type(T.GetRecipeSchematic) == "function" and try("GetRecipeSchematic", T.GetRecipeSchematic, recipeID, false)
    if type(s) ~= "table" then schematics[recipeID] = false; return nil end
    local out = { output = s.outputItemID, reagents = {} }
    for _, slot in ipairs(type(s.reagentSlotSchematics) == "table" and s.reagentSlotSchematics or {}) do
        local first = type(slot.reagents) == "table" and slot.reagents[1]
        if type(first) == "table" and type(first.itemID) == "number" and slot.required ~= false then
            out.reagents[#out.reagents + 1] = { itemID = first.itemID, need = type(slot.quantityRequired) == "number" and slot.quantityRequired or 1 }
        end
    end
    schematics[recipeID] = out
    return out
end

local function itemName(itemID)
    local n = ns.ProfessionSources.State().status == "ready" and rawget(_G, "LibQuestieDB")
    if n and type(n.Item) == "table" and type(n.Item.name) == "function" then
        local ok, v = pcall(n.Item.name, itemID)
        if ok and type(v) == "string" then return v end
    end
    if C_Item and type(C_Item.GetItemNameByID) == "function" then
        local ok, v = pcall(C_Item.GetItemNameByID, itemID)
        if ok and type(v) == "string" and v ~= "" then return v end
        if type(C_Item.RequestLoadItemDataByID) == "function" then pcall(C_Item.RequestLoadItemDataByID, itemID) end
        waitingItems[itemID] = true
    end
    return nil
end

local function count(itemID)
    if not (C_Item and type(C_Item.GetItemCount) == "function") then return nil end
    local ok, v = pcall(C_Item.GetItemCount, itemID, false)
    return ok and type(v) == "number" and v or nil
end

-- A recipe's ingredients: ProfessionRules.Reagents' result plus { output = itemID } and each
-- item's name, or nil when the game gives no schematic. m = the profession (Prof.Find).
function Prof.Reagents(recipeID, m)
    local s = schematic(recipeID)
    if not s then return nil end
    local R = ns.ProfessionRules
    -- "Craft it": a recipe of any of your professions that makes the reagent (Copper Bar is
    -- Mining's Smelt Copper, WoWScrnShot_111426_122953); this profession's own recipes first.
    local craftedBy, have, sources = {}, {}, {}
    local function add(prof)
        for _, r in ipairs(prof and prof.recipes and prof.recipes.list or {}) do
            if r.item and r.id ~= recipeID and not craftedBy[r.item] then
                craftedBy[r.item] = (prof == m) and r or { id = r.id, name = r.name, known = r.known, prof = prof.name }
            end
        end
    end
    add(m)
    for _, other in ipairs(cache and cache.professions or {}) do if other ~= m and other.skillLine ~= (m and m.skillLine) then add(other) end end
    local reagents = {}
    for i, g in ipairs(s.reagents) do
        reagents[i] = { itemID = g.itemID, need = g.need, name = itemName(g.itemID) }
        have[g.itemID] = count(g.itemID)
        sources[g.itemID] = ns.ProfessionSources.Item(g.itemID)
    end
    local out = R.Reagents(reagents, { craftedBy = craftedBy, nodes = R.NodesByItem(), sources = sources, have = have })
    out.output = s.output
    return out
end

-- One profession by skill line, or nil.
function Prof.Find(skillLine)
    for _, m in ipairs(Prof.Get().professions) do if m.skillLine == skillLine then return m end end
end

-- One reagent line for the debug report: "Linen Cloth 4/1 gather|craft|vendor|drop|unknown".
local function reagentText(g)
    local parts = {}
    for _, it in ipairs(g.items) do
        local w = it.where
        local detail = w.kind == "craft" and w.recipe.name or w.kind == "gather" and w.node.name
            or w.kind == "vendor" and (w.vendor.npc .. (w.more > 0 and (" +" .. w.more) or "")) or w.kind == "drop" and tostring(w.n) or ""
        parts[#parts + 1] = string.format("%s %s/%d %s %s", tostring(it.name or it.itemID), it.have == nil and "?" or tostring(it.have),
            it.need, w.kind, detail)
    end
    return table.concat(parts, "; ") .. (g.ready and " READY" or (" missing " .. g.missing .. (g.unknown and " (counts unknown)" or "")))
end

-- /azf debug professions [track <recipeID>]: what Get sees, in chat and in the trace
-- (trace-report.lua professions). "track <id>" switches the game's tracking of that recipe (the
-- player's own command; open check G3: an unlearned recipe).
function Prof.DebugReport(args)
    args = args or {}
    if args[1] == "track" then
        local id = tonumber(args[2])
        if not id then ns.Print("Usage: /azf debug professions track <recipeID>"); return end
        local now = Prof.Tracked()
        local state = Prof.SetTracked(id, not now[id])
        ns.Printf("Recipe %d: asked to %s; the game now says %s.", id, now[id] and "untrack" or "track",
            state == nil and "the call failed" or (state and "tracked" or "not tracked"))
        return
    end
    ns.ProfessionSources.Start()
    local started = clock()
    cache = nil
    local g = Prof.Get()
    local ms = started and clock() and (clock() - started) or nil
    local src = ns.ProfessionSources.State()
    local entry = { report = true, mastered = g.summary.mastered, total = g.summary.total, ms = ms, profs = {},
        sources = string.format("%s%s, trainers %s, work %s ms, max step %s ms, steps %s, elapsed %s ms", tostring(src.status),
            src.reason and (" (" .. src.reason .. ")") or "", tostring(src.trainers), tostring(src.workMs), tostring(src.maxStepMs),
            tostring(src.steps), tostring(src.elapsedMs)), tracked = {} }
    ns.Printf("Professions: %d of %d mastered (%s ms); sources %s", g.summary.mastered, g.summary.total,
        ms and string.format("%.1f", ms) or "?", entry.sources)
    for _, m in ipairs(g.professions) do
        local c = m.recipes and m.recipes.counts
        local line = string.format("%s %s/%s %s; status %s; next %s", tostring(m.name), tostring(m.skill), tostring(m.cap),
            tostring(m.title), m.status and m.status.kind or "-", m.next and (m.next.name .. "@" .. m.next.at) or "-")
        if c then
            line = line .. string.format("; recipes %d: known %d, now %d, later %d, nosource %d (sod %d), counted %d, foryou %d",
                c.total, c.known, c.now, c.later, c.nosource, c.sod, c.all, c.foryou)
        elseif m.hasRecipes then
            line = line .. "; window not read"
        end
        local tr = 0
        local rec = (store() or { trainers = {} }).trainers[m.skillLine]
        if type(rec) == "table" and type(rec.services) == "table" then for _ in pairs(rec.services) do tr = tr + 1 end end
        line = line .. string.format("; trainer services %d", tr)
        local ups = {}
        for _, it in ipairs(m.nextUp) do ups[#ups + 1] = it.kind end
        line = line .. "; next up " .. table.concat(ups, ",")
        if m.gatherRows then
            local cur, nx = m.gatherRows.current, m.gatherRows.nextRow
            line = line .. string.format("; gather %s -> %s", cur and (cur.name or cur.mapID) or "-", nx and (nx.name or nx.mapID) or "-")
        end
        if m.trainers then
            local names = {}
            for i, t in ipairs(m.trainers) do
                if i > 3 then break end
                names[#names + 1] = string.format("%s (%s, %s)", t.name, t.rank or "trainer", t.place or tostring(t.mapID))
            end
            line = line .. string.format("; %s trainers %d: %s", m.next.name, #m.trainers, table.concat(names, ", "))
        end
        if m.recipes then
            -- Sources by kind, and a sample of each kind (recipe: source).
            local kinds, sample = {}, {}
            for _, r in ipairs(m.recipes.list) do
                local k = r.sources[1] and r.sources[1].kind
                if k then
                    kinds[k] = (kinds[k] or 0) + 1
                    if not sample[k] then
                        local s = r.sources[1]
                        sample[k] = r.name .. ": " .. (s.npc and (s.npc .. " " .. tostring(s.maps and s.maps[1])) or s.n and (s.n .. "") or s.skill and ("skill " .. s.skill) or k)
                    end
                end
            end
            local ks = {}
            for k, n in pairs(kinds) do ks[#ks + 1] = k .. " " .. n .. " [" .. sample[k] .. "]" end
            table.sort(ks)
            line = line .. "; first sources " .. table.concat(ks, ", ")
        end
        ns.Print("  " .. line)
        entry.profs[tostring(m.name)] = line
    end
    -- The game's tracked recipes, with their ingredients.
    for id in pairs(g.tracked) do
        local owner, name
        for _, m in ipairs(g.professions) do
            for _, r in ipairs(m.recipes and m.recipes.list or {}) do if r.id == id then owner, name = m, r.name end end
        end
        local rg = Prof.Reagents(id, owner)
        local text = string.format("%s (%s): %s", tostring(name or id), owner and owner.name or "?", rg and reagentText(rg) or "no schematic")
        ns.Print("  Tracked " .. text)
        entry.tracked[tostring(id)] = text
    end
    ns.Debug.Trace("professions", entry)
end

ns.Events.Register("TRADE_SKILL_SHOW", function() ns.Events.Debounce("professions:window", 0.5, recordWindow) end)
ns.Events.Register("TRADE_SKILL_LIST_UPDATE", function() ns.Events.Debounce("professions:window", 0.5, recordWindow) end)
ns.Events.Register("TRADE_SKILL_DATA_SOURCE_CHANGED", function() ns.Events.Debounce("professions:window", 0.5, recordWindow) end)
ns.Events.Register("TRAINER_SHOW", function() lastSignature = nil; recordTrainer() end)
ns.Events.Register("TRAINER_UPDATE", function()
    if ns.ClassTrainer.IsReading() then return end
    ns.Events.Debounce("professions:trainer", 0.3, recordTrainer)
end)
-- Skill-ups and new recipes: the skills and IsPlayerSpell are read again on the next Get.
ns.Events.Register("SKILL_LINES_CHANGED", function() changed("skill") end)
ns.Events.Register("NEW_RECIPE_LEARNED", function() changed("learned") end)
ns.Events.On("AZF_REFRESH_REQUESTED", function() changed("refresh") end)
ns.Events.On("AZF_PROFESSION_SOURCES", function() changed("sources") end)
-- The nearest trainers depend on where you are.
ns.Events.Register("ZONE_CHANGED_NEW_AREA", function() changed("zone") end)
-- An item name we asked for has arrived.
ns.Events.Register("GET_ITEM_INFO_RECEIVED", function(itemID)
    if waitingItems[itemID] then
        waitingItems[itemID] = nil
        changed("item")
    end
end)
-- The game's own tracking changes (its window's Track box): the event's name isn't confirmed on
-- this client, so only registered when the client knows it; Get also compares the tracked list.
if C_EventUtils and type(C_EventUtils.IsEventValid) == "function" and C_EventUtils.IsEventValid("TRACKED_RECIPE_UPDATE") then
    ns.Events.Register("TRACKED_RECIPE_UPDATE", function() changed("tracked") end)
end
