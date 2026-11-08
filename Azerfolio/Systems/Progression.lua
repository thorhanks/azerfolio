-- The single aggregation service (spec §5.2, §7.5, §8.5). Pure; no WoW API use.
-- Every count, percentage and coverage value the UI shows comes from here.
local _, ns = ...

local Progression = {}
ns.Progression = Progression

local COVERAGE = { complete = true, partial = true, unavailable = true }

-- Aggregates sets of objectives for one scope (an objective list, a zone, a category, overall).
-- sets: { { category = "exploration", coverage = "complete"|"partial"|"unavailable",
--           objectives = { objective, ... } }, ... }
-- A set's coverage says whether its catalogue is complete. Only "complete" sets feed the
-- percentage; others are counted but listed under `excluded`.
--
-- Result:
--   total        distinct objectives (each counted once, by category and ID)
--   eligible, locked, unavailable, eligibilityUnknown   eligibility counts
--   complete, incomplete, completionUnknown             completion counts (all objectives)
--   completed    confirmed complete, in the denominator
--   remaining    confirmed incomplete, in the denominator
--   denominator  eligible or locked, completion known, from complete-coverage sets
--   uncounted    eligible/locked objectives left out because their state is unknown
--   conflicts    objectives reported twice with different states (made unknown)
--   percent      completed / denominator * 100, or nil when there is no denominator
--   coverage     "complete" | "partial" | "unavailable"
--   categories   included categories (complete coverage), sorted
--   excluded     categories left out of the percentage, sorted
--   trackedComplete  every counted objective is confirmed complete and nothing is unknown
function Progression.Aggregate(sets)
    local r = {
        total = 0, eligible = 0, locked = 0, unavailable = 0, eligibilityUnknown = 0,
        complete = 0, incomplete = 0, completionUnknown = 0,
        completed = 0, remaining = 0, denominator = 0, uncounted = 0, conflicts = 0,
        categories = {}, excluded = {},
    }
    local byKey, order, catState = {}, {}, {}
    local Key = ns.Objectives.Key

    for _, set in ipairs(sets or {}) do
        local cat = set.category
        if type(cat) == "string" then
            local cov = COVERAGE[set.coverage] and set.coverage or "unavailable"
            -- A category is included only if every set of it has complete coverage.
            if catState[cat] == nil then catState[cat] = (cov == "complete")
            elseif cov ~= "complete" then catState[cat] = false end
            for _, o in ipairs(set.objectives or {}) do
                if o.category == cat then
                    local k = Key(o)
                    local prev = byKey[k]
                    if not prev then
                        byKey[k] = { completion = o.completion, eligibility = o.eligibility, category = cat }
                        order[#order + 1] = k
                    else
                        if prev.completion ~= o.completion or prev.eligibility ~= o.eligibility then
                            if not prev.conflict then r.conflicts = r.conflicts + 1 end
                            prev.conflict = true
                            if prev.completion ~= o.completion then prev.completion = "unknown" end
                            if prev.eligibility ~= o.eligibility then prev.eligibility = "unknown" end
                        end
                    end
                end
            end
        end
    end

    for _, k in ipairs(order) do
        local o = byKey[k]
        r.total = r.total + 1
        local e, c = o.eligibility, o.completion
        if e == "eligible" then r.eligible = r.eligible + 1
        elseif e == "locked" then r.locked = r.locked + 1
        elseif e == "unavailable" then r.unavailable = r.unavailable + 1
        else r.eligibilityUnknown = r.eligibilityUnknown + 1 end
        if c == "complete" then r.complete = r.complete + 1
        elseif c == "incomplete" then r.incomplete = r.incomplete + 1
        else r.completionUnknown = r.completionUnknown + 1 end

        if catState[o.category] and (e == "eligible" or e == "locked") then
            if c == "complete" then
                r.completed = r.completed + 1; r.denominator = r.denominator + 1
            elseif c == "incomplete" then
                r.remaining = r.remaining + 1; r.denominator = r.denominator + 1
            else
                r.uncounted = r.uncounted + 1
            end
        elseif catState[o.category] and e == "unknown" then
            r.uncounted = r.uncounted + 1
        end
    end

    for cat, included in pairs(catState) do
        local list = included and r.categories or r.excluded
        list[#list + 1] = cat
    end
    table.sort(r.categories)
    table.sort(r.excluded)

    if r.denominator > 0 then r.percent = r.completed / r.denominator * 100 end

    if r.denominator == 0 then
        r.coverage = "unavailable"
    elseif #r.excluded == 0 and r.uncounted == 0 and r.conflicts == 0 then
        r.coverage = "complete"
    else
        r.coverage = "partial"
    end
    r.trackedComplete = r.coverage == "complete" and r.remaining == 0 and r.completed > 0
    return r
end

-- Percentage text for display, or nil when there is no valid percentage. Rounds down, so
-- "100%" only appears when every counted objective is confirmed complete.
function Progression.PercentText(result)
    if not result or not result.percent then return nil end
    local p = math.floor(result.percent)
    if p >= 100 and result.completed < result.denominator then p = 99 end
    return p .. "%"
end
