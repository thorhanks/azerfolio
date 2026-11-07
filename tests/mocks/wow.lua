-- Minimal WoW API mock for loading addon files outside the game.
-- Only add what tested code actually uses. Fixture data should come from real SavedVariables dumps.

local M = {}

local frames, timers, chat = {}, {}, {}

local frameMethods = {}
frameMethods.__index = frameMethods

function frameMethods:SetScript(name, fn) self.scripts[name] = fn end
function frameMethods:GetScript(name) return self.scripts[name] end
function frameMethods:HookScript(name, fn)
    local prev = self.scripts[name]
    self.scripts[name] = function(...) if prev then prev(...) end fn(...) end
end
function frameMethods:RegisterEvent(e)
    if M.unknownEvents[e] then error("Attempt to register unknown event \"" .. e .. "\"") end
    self.events[e] = true
end
function frameMethods:UnregisterEvent(e) self.events[e] = nil end
function frameMethods:RegisterAllEvents() self.allEvents = true end
function frameMethods:UnregisterAllEvents() self.allEvents = false; self.events = {} end
function frameMethods:Hide() self.shown = false end
function frameMethods:Show() self.shown = true end
function frameMethods:SetShown(v) self.shown = v and true or false end
function frameMethods:IsShown() return self.shown end
-- Layout and appearance calls are accepted and ignored.
for _, name in ipairs({ "SetSize", "SetPoint", "SetFrameStrata", "SetBackdrop", "SetBackdropColor",
    "SetBackdropBorderColor", "EnableMouse", "SetMovable", "RegisterForDrag", "StartMoving",
    "StopMovingOrSizing", "SetText", "SetAllPoints" }) do
    frameMethods[name] = function() end
end
function frameMethods:CreateFontString() return setmetatable({ scripts = {}, events = {} }, frameMethods) end
function frameMethods:CreateTexture()
    local tex = setmetatable({ scripts = {}, events = {} }, frameMethods)
    function tex:SetTexture(path) self.path = path; return true end
    function tex:GetTexture() return self.path end
    function tex:GetTextureFileID() return nil end
    return tex
end

function M.reset()
    frames, timers, chat = {}, {}, {}
    M.unknownEvents = {}
    M.chat = chat
end

-- Installs mock globals. `overrides` replaces or adds globals.
function M.install(overrides)
    M.reset()
    _G.CreateFrame = function(frameType, name, parent, template)
        if template and M.unknownTemplates and M.unknownTemplates[template] then
            error("Couldn't find inherited node \"" .. template .. "\"")
        end
        local f = setmetatable({ type = frameType, name = name, scripts = {}, events = {}, shown = true }, frameMethods)
        frames[#frames + 1] = f
        if name then _G[name] = f end
        return f
    end
    _G.time = os.time
    _G.GetTime = os.clock
    _G.unpack = _G.unpack or table.unpack
    _G.C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
    _G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) chat[#chat + 1] = text end }
    _G.SlashCmdList = {}
    _G.UIParent = setmetatable({ scripts = {}, events = {} }, frameMethods)
    for k, v in pairs(overrides or {}) do _G[k] = v end
end

-- Delivers an event to every frame registered for it.
function M.fire(event, ...)
    for _, f in ipairs(frames) do
        if (f.events[event] or f.allEvents) and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end

-- Runs queued C_Timer callbacks (including ones queued while running).
function M.runTimers()
    local guard = 0
    while #timers > 0 and guard < 1000 do
        local fn = table.remove(timers, 1)
        fn()
        guard = guard + 1
    end
end

-- Loads an addon file the way the client does: chunk(addonName, addonTable).
function M.loadAddonFile(path, addonName, ns)
    local chunk, err = loadfile(path)
    if not chunk then error(err) end
    ns = ns or {}
    chunk(addonName, ns)
    return ns
end

M.reset()
return M
