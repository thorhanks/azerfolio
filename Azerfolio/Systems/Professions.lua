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
            rows[#rows + 1] = { id = id, name = info.name, learned = info.learned and true or false,
                grey = type(info.maxTrivialLevel) == "number" and info.maxTrivialLevel or nil,
                category = type(info.categoryID) == "number" and info.categoryID or 0 }
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

-- Everything the tab and the Overview panel show:
--   { professions = { { model (ProfessionRules.Profession), status, stones, recipes (nil = window
--       not read), recipesTime, trainerTime, gather (nil = no gathering), nextUp } ... } in rail
--     order, summary = { mastered, total } }
function Prof.Get()
    if cache then return cache end
    local R = ns.ProfessionRules
    local p = store() or { windows = {}, trainers = {} }
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
            local rows = {}
            for i, r in ipairs(win.rows) do
                rows[i] = { id = r.id, name = r.name, learned = r.learned, grey = r.grey, category = r.category,
                    categoryName = type(win.categories) == "table" and win.categories[r.category] or nil }
            end
            recipes = R.Recipes(rows, { skill = m.skill, trainer = trainerSkills(tr), known = isPlayerSpell })
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
    cache = { professions = list, summary = R.Summary(list) }
    return cache
end

-- One profession by skill line, or nil.
function Prof.Find(skillLine)
    for _, m in ipairs(Prof.Get().professions) do if m.skillLine == skillLine then return m end end
end

-- /azf debug professions: what Get sees, in chat and in the trace (trace-report.lua professions).
function Prof.DebugReport()
    local started = clock()
    cache = nil
    local g = Prof.Get()
    local ms = started and clock() and (clock() - started) or nil
    local entry = { report = true, mastered = g.summary.mastered, total = g.summary.total, ms = ms, profs = {} }
    ns.Printf("Professions: %d of %d mastered (%s ms)", g.summary.mastered, g.summary.total, ms and string.format("%.1f", ms) or "?")
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
        ns.Print("  " .. line)
        entry.profs[tostring(m.name)] = line
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
