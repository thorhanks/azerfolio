-- Event dispatcher: one frame for all game events, plus internal messages and debouncing.
-- Every handler runs under pcall, so one failing handler never blocks the others.
local _, ns = ...

local Events = {}
ns.Events = Events

local frame = CreateFrame("Frame")
local gameHandlers = {}    -- [event] = { fn, ... }
local messageHandlers = {} -- [message] = { fn, ... }
local debounceTokens = {}  -- [key] = token of the latest scheduled call

local function dispatch(handlers, name, ...)
    local list = handlers[name]
    if not list then return end
    -- Copy so handlers can unregister themselves while running.
    local snapshot = {}
    for i = 1, #list do snapshot[i] = list[i] end
    for i = 1, #snapshot do
        local ok, err = pcall(snapshot[i], ...)
        if not ok then ns.Debug.Error(name, err) end
    end
end

frame:SetScript("OnEvent", function(_, event, ...)
    dispatch(gameHandlers, event, ...)
end)

local function remove(list, fn)
    if not list then return end
    for i = #list, 1, -1 do
        if list[i] == fn then table.remove(list, i) end
    end
end

-- Registers fn(...) for a game event. Returns true, or false plus the error if the client
-- doesn't know the event (the addon keeps working without it).
function Events.Register(event, fn)
    if not gameHandlers[event] then
        local ok, err = pcall(frame.RegisterEvent, frame, event)
        if not ok then
            ns.Debug.Error("RegisterEvent " .. event, err)
            return false, err
        end
        gameHandlers[event] = {}
    end
    table.insert(gameHandlers[event], fn)
    return true
end

function Events.Unregister(event, fn)
    local list = gameHandlers[event]
    remove(list, fn)
    if list and #list == 0 then
        gameHandlers[event] = nil
        pcall(frame.UnregisterEvent, frame, event)
    end
end

-- Internal messages (names start with "AZF_" by convention).
function Events.On(message, fn)
    messageHandlers[message] = messageHandlers[message] or {}
    table.insert(messageHandlers[message], fn)
end

function Events.Off(message, fn)
    remove(messageHandlers[message], fn)
end

function Events.Send(message, ...)
    dispatch(messageHandlers, message, ...)
end

-- Runs fn once, `delay` seconds after the most recent call with the same key.
function Events.Debounce(key, delay, fn)
    local token = {}
    debounceTokens[key] = token
    C_Timer.After(delay, function()
        if debounceTokens[key] ~= token then return end
        debounceTokens[key] = nil
        local ok, err = pcall(fn)
        if not ok then ns.Debug.Error("debounce " .. tostring(key), err) end
    end)
end
