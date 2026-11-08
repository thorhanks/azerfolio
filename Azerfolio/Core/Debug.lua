-- Debug output and error capture. Debug output is off by default (AzerfolioDB.debug).
local _, ns = ...

local Debug = {}
ns.Debug = Debug

Debug.errors = {} -- recent errors this session: { t = GetTime(), label, err }

function Debug.IsEnabled()
    return ns.db ~= nil and ns.db.debug == true
end

function Debug.Print(fmt, ...)
    if not Debug.IsEnabled() then return end
    local ok, text = pcall(string.format, fmt, ...)
    DEFAULT_CHAT_FRAME:AddMessage("|cff8888ffAzerfolio debug|r " .. (ok and text or tostring(fmt)))
end

-- Debug mode only: appends { t = GetTime(), kind, ... } to AzerfolioDB.trace (newest last,
-- capped), so in-game behaviour can be read from the SavedVariables file after /reload.
-- Only addon state goes here; never chat or other players' data.
function Debug.Trace(kind, fields)
    if not Debug.IsEnabled() or type(ns.db.trace) ~= "table" then return end
    local entry = { t = GetTime(), kind = tostring(kind) }
    for k, v in pairs(fields or {}) do entry[k] = v end
    local list = ns.db.trace
    list[#list + 1] = entry
    ns.SavedVariables.TrimList(list, ns.Config.LIMITS.trace)
end

-- Records an error without stopping the caller. Always kept; printed only in debug mode.
function Debug.Error(label, err)
    local list = Debug.errors
    list[#list + 1] = { t = GetTime(), label = tostring(label), err = tostring(err) }
    local limit = ns.Config.LIMITS.errors
    while #list > limit do table.remove(list, 1) end
    Debug.Print("error in %s: %s", tostring(label), tostring(err))
end

-- Calls fn(...) safely. Returns fn's results, or nil after recording the error.
function Debug.Try(label, fn, ...)
    if type(fn) ~= "function" then return nil end
    local results = { pcall(fn, ...) }
    if not results[1] then
        Debug.Error(label, results[2])
        return nil
    end
    return unpack(results, 2, table.maxn(results))
end
