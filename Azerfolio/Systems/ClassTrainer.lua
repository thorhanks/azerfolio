-- Class trainer (Class tab, round 4; docs/research/class-spells.md): records your class trainer's
-- full list whenever you open it, so the Class tab can show your abilities along the road. The
-- spellbook lists no future spells in Forever, and the trainer lists every service with its level
-- and whether you've learned it [verified-ingame, /azfdiag spells, 2026-11-10].
-- The read turns every service-type filter on (available, unavailable, used), reads the list, and
-- puts the filters back as they were. Saved per character (AzerfolioCharDB.trainer).
-- Announces AZF_CLASS_UPDATED.
local _, ns = ...

local Trainer = {}
ns.ClassTrainer = Trainer

local FILTERS = { "available", "unavailable", "used" }
local reading = false -- our own filter changes fire TRAINER_UPDATE: don't read again from them

local function try(label, fn, ...) return ns.Debug.Try(label, fn, ...) end

-- Is the open trainer a class trainer (not a profession's)?
local function classTrainer()
    if type(GetNumTrainerServices) ~= "function" or type(GetTrainerServiceInfo) ~= "function" then return false end
    if type(IsTradeskillTrainer) == "function" and try("IsTradeskillTrainer", IsTradeskillTrainer) then return false end
    return true
end

-- Sets one service-type filter. Forever's client rejects the number 1 ("Missing on/off
-- parameter", WoWScrnShot_111026_200313 and the probe's errors), so a boolean first, then a
-- number; quietly, since the list came back whole even when neither took [verified-ingame].
local function setFilter(f, on)
    if pcall(SetTrainerServiceTypeFilter, f, on and true or false) then return true end
    return pcall(SetTrainerServiceTypeFilter, f, on and 1 or 0)
end

-- Reads the open trainer's whole list. Returns the services, or nil.
function Trainer.Read()
    if not classTrainer() then return nil end
    reading = true
    local saved = {}
    local canFilter = type(GetTrainerServiceTypeFilter) == "function" and type(SetTrainerServiceTypeFilter) == "function"
    if canFilter then
        for _, f in ipairs(FILTERS) do
            local ok, v = pcall(GetTrainerServiceTypeFilter, f)
            if ok then saved[f] = v and v ~= 0 end
            setFilter(f, true)
        end
    end
    local services = {}
    local n = try("GetNumTrainerServices", GetNumTrainerServices)
    for i = 1, (type(n) == "number" and math.min(n, 400) or 0) do
        -- name, type, icon, ?, rank text [verified-ingame, probe v2]
        local name, kind, icon, _, rank = try("GetTrainerServiceInfo", GetTrainerServiceInfo, i)
        if type(name) == "string" and (kind == "used" or kind == "available" or kind == "unavailable") then
            local level = type(GetTrainerServiceLevelReq) == "function" and try("GetTrainerServiceLevelReq", GetTrainerServiceLevelReq, i)
            local cost = type(GetTrainerServiceCost) == "function" and try("GetTrainerServiceCost", GetTrainerServiceCost, i)
            services[#services + 1] = { name = name, kind = kind, icon = icon, level = type(level) == "number" and level or 0,
                rank = type(rank) == "string" and rank ~= "" and rank or nil, cost = type(cost) == "number" and cost or nil }
        end
    end
    if canFilter then
        for _, f in ipairs(FILTERS) do
            if saved[f] ~= nil then setFilter(f, saved[f]) end
        end
    end
    reading = false
    return services
end

local function record()
    if reading then return end
    local services = Trainer.Read()
    if not services or #services == 0 or not ns.charDB then return end
    ns.charDB.trainer = { time = time and time() or nil, class = ns.character and ns.character.classFile, services = services }
    ns.Debug.Trace("trainer", { count = #services })
    ns.Events.Send("AZF_CLASS_UPDATED")
end

-- The abilities for the Class tab:
--   { status = "recorded", time, abilities = ClassTrainerRules.Abilities(...) }
--   { status = "none" }   your class trainer not visited yet (with this addon)
function Trainer.Get()
    local t = ns.charDB and ns.charDB.trainer
    local c = ns.character or {}
    if type(t) ~= "table" or type(t.services) ~= "table" or #t.services == 0 then return { status = "none" } end
    if t.class and c.classFile and t.class ~= c.classFile then return { status = "none" } end
    return { status = "recorded", time = t.time, abilities = ns.ClassTrainerRules.Abilities(t.services, c.level) }
end

ns.Events.Register("TRAINER_SHOW", record)
ns.Events.Register("TRAINER_UPDATE", function() ns.Events.Debounce("trainer", 0.3, record) end)
