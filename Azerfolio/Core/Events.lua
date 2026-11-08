-- Event dispatcher: one frame for all game events, plus internal messages and debouncing.
-- Every handler runs under pcall, so one failing handler never blocks the others.
local _, ns = ...

local Events = {}
ns.Events = Events

local frame = CreateFrame("Frame")
local gameHandlers = {}    -- [event] = { fn, ... }
local messageHandlers = {} -- [message] = { fn, ... }
local debounceTokens = {}  -- [key] = token of the latest scheduled call

-- Performance counters (plan Phase 8 task 3), kept only while debug mode is on:
-- stats[name] = { count, ms, max }; names are game events, AZF_* messages and "debounce:<key>".
-- Times use debugprofilestop() (milliseconds) when the client has it; otherwise only counts.
Events.stats = {}
Events.statsSince = nil -- GetTime() when counting started

local function clock()
    return type(debugprofilestop) == "function" and debugprofilestop() or nil
end

local function record(name, started)
    local s = Events.stats[name]
    if not s then
        s = { count = 0, ms = 0, max = 0 }
        Events.stats[name] = s
    end
    s.count = s.count + 1
    local now = started and clock()
    if now then
        local ms = now - started
        s.ms = s.ms + ms
        if ms > s.max then s.max = ms end
    end
end

local function counting()
    if not ns.Debug.IsEnabled() then return false end
    if not Events.statsSince then Events.statsSince = type(GetTime) == "function" and GetTime() or 0 end
    return true
end

-- Pure: the counters as a list, busiest first (by total time, then count, then name).
-- Times include nested work (a game event's time includes the AZF_* messages it sends).
function Events.StatsList(stats)
    local list = {}
    for name, s in pairs(stats or Events.stats) do
        list[#list + 1] = { name = name, count = s.count, ms = s.ms, max = s.max }
    end
    table.sort(list, function(a, b)
        if a.ms ~= b.ms then return a.ms > b.ms end
        if a.count ~= b.count then return a.count > b.count end
        return a.name < b.name
    end)
    return list
end

function Events.ResetStats()
    Events.stats = {}
    Events.statsSince = nil
end

-- Runs fn under pcall and counts it as `name` while debug mode is on.
function Events.Measure(name, fn, ...)
    local on = counting()
    local started = on and clock()
    local ok, err = pcall(fn, ...)
    if on then record(name, started) end
    return ok, err
end

local function dispatch(handlers, name, ...)
    local list = handlers[name]
    if not list then return end
    local on = counting()
    local started = on and clock()
    -- Copy so handlers can unregister themselves while running.
    local snapshot = {}
    for i = 1, #list do snapshot[i] = list[i] end
    for i = 1, #snapshot do
        local ok, err = pcall(snapshot[i], ...)
        if not ok then ns.Debug.Error(name, err) end
    end
    if on then record(name, started) end
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
        local ok, err = Events.Measure("debounce:" .. tostring(key), fn)
        if not ok then ns.Debug.Error("debounce " .. tostring(key), err) end
    end)
end
