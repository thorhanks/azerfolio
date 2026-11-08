-- Quest eligibility (Phase 9 step 3, spec §7.4). Pure; no WoW API use.
-- Decides, for one character, whether a QuestieDB quest is eligible (can be done now), locked
-- (not yet: level or prerequisite), unavailable (never for this character: race, class,
-- exclusive choice, a chain or breadcrumb that moved on, too high a level) or unknown.
-- Field meanings come from QuestieDB's own docs (Types/Meta.t.lua, Quest.t.lua) [verified-files].
-- Requirements we can't check yet (profession, reputation, spell) make a quest unknown, so it
-- stays out of the totals instead of being guessed.
local _, ns = ...

local Rules = {}
ns.QuestRules = Rules

-- Severity: the worst rule wins. Unknown outranks locked (we can't say it will become possible).
local RANK = { eligible = 0, locked = 1, unknown = 2, unavailable = 3 }

-- questFlags bits that make a quest repeat (QuestieDB enum questFlags) [verified-files].
local DAILY, WEEKLY, MONTHLY = 4096, 32768, 65536

-- Pure: is bit (a power of two) set in mask? Arithmetic, since masks pass 2^32 (Skyborne)
-- and Lua 5.1's bit library is 32-bit.
function Rules.HasBit(mask, bit)
    return math.floor(mask / bit) % 2 == 1
end

-- Pure: repeatable by specialFlags bit 1, or a daily, weekly or monthly questFlags bit.
function Rules.IsRepeatable(specialFlags, questFlags)
    if type(specialFlags) == "number" and specialFlags % 2 == 1 then return true end
    if type(questFlags) == "number" then
        return Rules.HasBit(questFlags, DAILY) or Rules.HasBit(questFlags, WEEKLY) or Rules.HasBit(questFlags, MONTHLY)
    end
    return false
end

-- Pure: the character's bit in QuestieDB's race mask: 2^(raceID - 1) for the classic races
-- 1-9 (HUMAN 1 ... GOBLIN 256) [verified-files, enum; Human = race 1 verified-ingame]. Other
-- races (Skyborne uses bits 2^32 / 2^33, race ID unknown) return nil: not checked.
function Rules.RaceBit(raceID)
    if type(raceID) == "number" and raceID >= 1 and raceID <= 9 and raceID == math.floor(raceID) then
        return 2 ^ (raceID - 1)
    end
    return nil
end

-- Pure: class bit 2^(classID - 1) (WARRIOR 1 ... DRUID 1024) [verified-ingame].
function Rules.ClassBit(classID)
    if type(classID) == "number" and classID >= 1 and classID <= 11 and classID == math.floor(classID) then
        return 2 ^ (classID - 1)
    end
    return nil
end

local function list(v)
    if type(v) == "table" then return v end
    if type(v) == "number" and v > 0 then return { v } end
    return nil
end

local function set(v) return type(v) == "number" and v > 0 end

-- A context for one character and one completed-quest set:
--   info(id) -> record or nil   (Quests.ReadDetails shape; nil = not in QuestieDB)
--   completed = { [questID] = true } or nil (unknown)
--   char = { raceID, classID, level }
-- Results are memoised in ctx.memo, so prerequisite chains are evaluated once.
function Rules.Context(info, completed, char)
    return { info = info, completed = completed, char = char or {}, memo = {} }
end

local evaluate

-- worst of two (state, reason) pairs
local function worse(s1, r1, s2, r2)
    if RANK[s2] > RANK[s1] then return s2, r2 end
    return s1, r1
end

-- One prerequisite's state: completed counts as met.
local function prereq(ctx, id)
    if ctx.completed and ctx.completed[id] then return "met" end
    return (evaluate(ctx, id))
end

local function check(ctx, id)
    local r = ctx.info(id)
    if not r then return "unknown", "not in QuestieDB" end
    if r.err then return "unknown", "QuestieDB read error" end
    local c, done = ctx.char, ctx.completed
    local s, why = "eligible", nil

    -- Race (faction comes with it) and class.
    if type(r.races) == "number" and r.races > 0 then
        local bit = Rules.RaceBit(c.raceID)
        if not bit then s, why = worse(s, why, "unknown", "race not checked")
        elseif not Rules.HasBit(r.races, bit) then s, why = worse(s, why, "unavailable", "race or faction") end
    end
    if type(r.classes) == "number" and r.classes > 0 then
        local bit = Rules.ClassBit(c.classID)
        if not bit then s, why = worse(s, why, "unknown", "class not checked")
        elseif not Rules.HasBit(r.classes, bit) then s, why = worse(s, why, "unavailable", "class") end
    end

    -- Level.
    if type(c.level) ~= "number" then
        if set(r.reqLevel) or set(r.maxLevel) then s, why = worse(s, why, "unknown", "level not known") end
    else
        if set(r.maxLevel) and c.level > r.maxLevel then s, why = worse(s, why, "unavailable", "level too high") end
        if set(r.reqLevel) and c.level < r.reqLevel then
            s, why = worse(s, why, "locked", "level " .. r.reqLevel)
        end
    end

    -- Choices and chains that close a quest for good (needs the completed list).
    if done then
        for _, x in ipairs(list(r.exclusive) or {}) do
            if done[x] then s, why = worse(s, why, "unavailable", "exclusive choice") end
        end
        if set(r.next) and done[r.next] then s, why = worse(s, why, "unavailable", "chain moved on") end
        if set(r.untilCompleted) and done[r.untilCompleted] then s, why = worse(s, why, "unavailable", "no longer offered") end
        if set(r.breadcrumbFor) and done[r.breadcrumbFor] then s, why = worse(s, why, "unavailable", "breadcrumb skipped") end
        if set(r.parent) and done[r.parent] then s, why = worse(s, why, "unavailable", "parent quest done") end
    elseif list(r.exclusive) or set(r.next) or set(r.untilCompleted) or set(r.breadcrumbFor) or set(r.parent) then
        s, why = worse(s, why, "unknown", "completed quests not known")
    end

    -- Requirements not checked yet.
    if r.needs then s, why = worse(s, why, "unknown", r.needs .. " not checked") end

    -- Prerequisites: all of preGroup; any one of preSingle; availableStartingWith.
    local function needAll(ids)
        for _, p in ipairs(ids) do
            local ps = prereq(ctx, p)
            if ps == "unavailable" then s, why = worse(s, why, "unavailable", "prerequisite unavailable")
            elseif ps == "unknown" then s, why = worse(s, why, "unknown", "prerequisite unknown")
            elseif ps ~= "met" then s, why = worse(s, why, "locked", "prerequisite") end
        end
    end
    local function needOne(ids)
        local best = "unavailable"
        for _, p in ipairs(ids) do
            local ps = prereq(ctx, p)
            if ps == "met" then return end
            if ps == "eligible" or ps == "locked" then best = "locked"
            elseif ps == "unknown" and best == "unavailable" then best = "unknown" end
        end
        if best == "locked" then s, why = worse(s, why, "locked", "prerequisite")
        elseif best == "unknown" then s, why = worse(s, why, "unknown", "prerequisite unknown")
        else s, why = worse(s, why, "unavailable", "prerequisite unavailable") end
    end
    local group, single = list(r.preGroup), list(r.preSingle)
    if (group or single or set(r.startingWith)) and not done then
        s, why = worse(s, why, "unknown", "completed quests not known")
    else
        if group then needAll(group) end
        if single and #single > 0 then needOne(single) end
        if set(r.startingWith) then needOne({ r.startingWith }) end
    end
    -- A parent quest must be active: possible only while it's not done (checked above).
    if set(r.parent) and done and not done[r.parent] then s, why = worse(s, why, "locked", "parent quest") end
    return s, why
end

-- Pure: eligibility and reason for quest `id`. A completed quest is eligible (it was done).
-- Cycles in prerequisite data evaluate as unknown.
function evaluate(ctx, id)
    if ctx.completed and ctx.completed[id] then return "eligible", "completed" end
    local m = ctx.memo[id]
    if m == true then return "unknown", "prerequisite loop" end
    if m then return m[1], m[2] end
    ctx.memo[id] = true
    local s, why = check(ctx, id)
    ctx.memo[id] = { s, why }
    return s, why
end
Rules.Evaluate = evaluate

-- Pure: completion from the completed list: complete, incomplete, or unknown without a list.
function Rules.Completion(completed, id)
    if not completed then return "unknown" end
    return completed[id] and "complete" or "incomplete"
end
