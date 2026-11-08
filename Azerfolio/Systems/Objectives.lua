-- Objective model (spec §7.4, §8.2). Pure; no WoW API use.
-- Completion and eligibility are separate fields. Anything a provider can't confirm is "unknown".
local _, ns = ...

local Objectives = {}
ns.Objectives = Objectives

Objectives.COMPLETE, Objectives.INCOMPLETE, Objectives.UNKNOWN = "complete", "incomplete", "unknown"
Objectives.ELIGIBLE, Objectives.LOCKED, Objectives.UNAVAILABLE = "eligible", "locked", "unavailable"

local COMPLETION = { complete = true, incomplete = true, unknown = true }
local ELIGIBILITY = { eligible = true, locked = true, unavailable = true, unknown = true }

-- Completion from a game done flag: only a real boolean is a confirmed state.
function Objectives.CompletionFromFlag(flag)
    if flag == true then return "complete" end
    if flag == false then return "incomplete" end
    return "unknown"
end

-- Builds an objective. Required: id (number or string) and category (string).
-- Invalid or missing completion/eligibility become "unknown". Returns nil if id or category is bad.
--   { id, category, zone, name, completion, eligibility, source }
function Objectives.New(fields)
    if type(fields) ~= "table" then return nil end
    local id, category = fields.id, fields.category
    if (type(id) ~= "number" and type(id) ~= "string") or type(category) ~= "string" then return nil end
    return {
        id = id,
        category = category,
        zone = fields.zone,
        name = fields.name,
        completion = COMPLETION[fields.completion] and fields.completion or "unknown",
        eligibility = ELIGIBILITY[fields.eligibility] and fields.eligibility or "unknown",
        source = fields.source,
    }
end

-- Key used to count an objective once: IDs are only unique within a category.
function Objectives.Key(o) return o.category .. ":" .. tostring(o.id) end
