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
local function fire(self, script, ...)
    if self.scripts[script] then self.scripts[script](self, ...) end
end
function frameMethods:Hide()
    local was = self.shown
    self.shown = false
    if was then fire(self, "OnHide") end
end
function frameMethods:Show()
    local was = self.shown
    self.shown = true
    if not was then fire(self, "OnShow") end
end
function frameMethods:SetShown(v) if v then self:Show() else self:Hide() end end
function frameMethods:IsShown() return self.shown end
-- Layout and appearance calls are accepted and ignored.
for _, name in ipairs({ "SetFrameStrata", "SetBackdrop", "SetBackdropColor",
    "SetBackdropBorderColor", "EnableMouse", "SetMovable", "RegisterForDrag", "StartMoving",
    "StopMovingOrSizing", "SetAllPoints", "SetToplevel", "SetClampedToScreen", "SetResizable",
    "SetResizeBounds", "SetClipsChildren", "SetColorTexture", "SetGradient", "SetTextColor",
    "SetShadowColor", "SetShadowOffset", "SetFontObject", "SetWordWrap", "SetStatusBarTexture",
    "SetStatusBarColor", "SetMinMaxValues", "SetValue", "SetNormalTexture", "SetHighlightTexture",
    "SetPushedTexture", "SetAlpha", "SetVertexColor", "SetAtlas", "SetDesaturated", "SetTitle", "SetHorizTile", "SetVertTile", "SetFrameLevel", "StartSizing", "AddMaskTexture", "SetJustifyH",
    "ClearAllPoints" }) do
    frameMethods[name] = function() end
end
function frameMethods:GetEffectiveScale() return 1 end
function frameMethods:SetScale(s) self.scale = s end
function frameMethods:GetScale() return self.scale or 1 end
-- EditBox
for _, name in ipairs({ "SetAutoFocus", "SetMaxLetters", "SetTextInsets" }) do frameMethods[name] = function() end end
function frameMethods:SetFocus() self.hasFocus = true end
function frameMethods:ClearFocus() self.hasFocus = false end
function frameMethods:HasFocus() return self.hasFocus == true end
for _, name in ipairs({ "SetScrollChild", "EnableMouseWheel", "SetTexCoord", "RegisterForClicks" }) do
    frameMethods[name] = function() end
end
function frameMethods:SetVerticalScroll(v) self.vscroll = v end
function frameMethods:GetVerticalScroll() return self.vscroll or 0 end
function frameMethods:GetVerticalScrollRange() return 0 end
-- No layout engine: edges are unknown (code must cope with nil before the first layout).
function frameMethods:GetTop() return nil end
function frameMethods:GetBottom() return nil end
function frameMethods:SetFont() return true end
function frameMethods:SetText(text) self.text = text end
function frameMethods:GetText() return self.text end
function frameMethods:GetStringWidth() return #tostring(self.text or "") * 7 end
function frameMethods:SetSize(w, h) self.width, self.height = w, h end
function frameMethods:SetWidth(w) self.width = w end
function frameMethods:SetHeight(h) self.height = h end
function frameMethods:GetWidth() return self.width or 0 end
function frameMethods:GetHeight() return self.height or 0 end
function frameMethods:GetFrameLevel() return 1 end
function frameMethods:GetButtonState() return "NORMAL" end
-- Only CENTER-to-UIParent anchors are tracked (enough for window geometry).
function frameMethods:SetPoint(point, rel, relPoint, x, y)
    if point == "CENTER" and rel == _G.UIParent then self.cx, self.cy = x or 0, y or 0 end
end
function frameMethods:GetCenter()
    if self == _G.UIParent then return self.width / 2, self.height / 2 end
    if self.cx then return _G.UIParent.width / 2 + self.cx, _G.UIParent.height / 2 + self.cy end
end
function frameMethods:EnableGamePadButton(v) self.gamePadButton = v end
function frameMethods:EnableGamePadStick(v) self.gamePadStick = v end
local function region() return setmetatable({ scripts = {}, events = {}, shown = true }, frameMethods) end
function frameMethods:CreateFontString() return region() end
function frameMethods:CreateMaskTexture() return frameMethods.CreateTexture(self) end
function frameMethods:CreateTexture()
    local tex = region()
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
        local f = setmetatable({ type = frameType, name = name, template = template, scripts = {}, events = {}, shown = true }, frameMethods)
        frames[#frames + 1] = f
        if name then _G[name] = f end
        -- PortraitFrameTemplate children as recorded in game by /azfdiag skin.
        if template == "PortraitFrameTemplate" then
            local function child(shown)
                local c = setmetatable({ scripts = {}, events = {}, shown = shown }, frameMethods)
                frames[#frames + 1] = c
                return c
            end
            f.NineSlice, f.TitleContainer, f.CloseButton = child(true), child(true), child(true)
            f.PortraitContainer = child(true)
            f.PortraitContainer.portrait = f:CreateTexture()
            f.FrameGlow = child(false)
            function f:SetTitle(text) self.title = text end
        end
        return f
    end
    _G.time = os.time
    _G.date = os.date
    _G.GetTime = os.clock
    _G.unpack = _G.unpack or table.unpack
    _G.C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
    _G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) chat[#chat + 1] = text end }
    _G.SlashCmdList = {}
    -- 3440x1440 with the default UI scale: UIParent is 768 units tall.
    _G.UIParent = setmetatable({ scripts = {}, events = {}, shown = true, width = 1835, height = 768 }, frameMethods)
    _G.UISpecialFrames = {}
    _G.InCombatLockdown = function() return M.combat == true end
    M.combat = false
    for k, v in pairs(overrides or {}) do _G[k] = v end
end

function M.frameCount() return #frames end

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

-- Loads every file listed in an addon's TOC, in order, with one shared namespace table.
-- Returns the namespace and the list of files loaded. Fails if a listed file is missing.
function M.loadToc(addonDir, addonName)
    local tocPath = addonDir .. "/" .. addonName .. ".toc"
    local toc = assert(io.open(tocPath, "r"), "missing " .. tocPath)
    local ns, files = {}, {}
    for line in toc:lines() do
        line = line:gsub("\r$", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" and not line:match("^#") then
            local path = addonDir .. "/" .. line:gsub("\\", "/")
            files[#files + 1] = path
            M.loadAddonFile(path, addonName, ns)
        end
    end
    toc:close()
    return ns, files
end

-- Reads "## Key: value" metadata from a TOC.
function M.tocMetadata(addonDir, addonName)
    local meta = {}
    for line in io.lines(addonDir .. "/" .. addonName .. ".toc") do
        local k, v = line:match("^##%s*([%w%-]+)%s*:%s*(.-)%s*$")
        if k then meta[k] = v end
    end
    return meta
end

M.reset()
return M
