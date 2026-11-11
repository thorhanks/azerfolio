-- Class trainer rules (Class tab, round 4; docs/research/class-spells.md): your class abilities
-- by level, from the trainer's own list (recorded by Systems/ClassTrainer.lua whenever you open
-- your class trainer). The first time a name appears (by level) is a new ability; later ones are
-- its ranks. A service is learned when the trainer said "used"; otherwise available once your
-- level reaches it, later before. Nothing is guessed: without a recorded list there's nothing.
--
-- Pure: no WoW globals, so tests and tools can load it.
local _, ns = ...
ns = ns or {}

local Rules = {}
ns.ClassTrainerRules = Rules

-- Pure: one service's state. kind: the trainer's type when recorded; level: yours now.
function Rules.State(kind, need, level)
    if kind == "used" then return "learned" end
    if type(level) ~= "number" then return "unknown" end
    return (need or 0) <= level and "available" or "later"
end

-- Pure: the abilities by level.
--   services = { { name, rank, kind, level, icon, cost } ... } (the recorded list)
--   level = your level now (nil = not known: nothing is "available" or "later", only "unknown")
-- Returns {
--   levels = { { level, abilities = { { name, rank, icon, cost, state, new } ... } } ... } by level,
--   marks = { { level, state, new = n, abilities } ... }   levels with at least one new ability;
--           a mark's state: available (a new ability you could train now) > later > learned
--   counts = { learned, available, later, unknown, new, total }, availableNow = { ability ... } }
function Rules.Abilities(services, level)
    local list = {}
    for i, s in ipairs(services or {}) do
        list[#list + 1] = { name = s.name, rank = s.rank, icon = s.icon, cost = s.cost, kind = s.kind,
            level = math.max(1, s.level or 1), order = i }
    end
    table.sort(list, function(a, b)
        if a.level ~= b.level then return a.level < b.level end
        return a.order < b.order
    end)
    local seen, byLevel, levels = {}, {}, {}
    local counts = { learned = 0, available = 0, later = 0, unknown = 0, new = 0, total = 0 }
    local availableNow = {}
    for _, a in ipairs(list) do
        local ab = { name = a.name, rank = a.rank, icon = a.icon, cost = a.cost, level = a.level,
            state = Rules.State(a.kind, a.level, level), new = not seen[a.name] }
        seen[a.name] = true
        local L = byLevel[a.level]
        if not L then L = { level = a.level, abilities = {} }; byLevel[a.level] = L; levels[#levels + 1] = L end
        table.insert(L.abilities, ab)
        counts[ab.state] = counts[ab.state] + 1
        counts.total = counts.total + 1
        if ab.new then counts.new = counts.new + 1 end
        if ab.state == "available" then availableNow[#availableNow + 1] = ab end
    end
    local marks = {}
    for _, L in ipairs(levels) do
        local n, any = 0, {}
        for _, ab in ipairs(L.abilities) do
            if ab.new then n = n + 1; any[ab.state] = true end
        end
        if n > 0 then
            local state = any.available and "available" or any.later and "later" or any.unknown and "unknown" or "learned"
            marks[#marks + 1] = { level = L.level, state = state, new = n, abilities = L.abilities }
        end
    end
    return { levels = levels, marks = marks, counts = counts, availableNow = availableNow }
end

return Rules
