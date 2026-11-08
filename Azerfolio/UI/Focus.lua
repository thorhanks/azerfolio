-- The window's gamepad focus: one FocusGrid per tab (so focus is remembered per tab), the
-- native yellow chevron (SmartNavigation's gamepad-largecursor-white, bobbing), the focused
-- control's highlight, scrolling it into view, and the info line.
-- Pages opt in with page:GetFocusRows() returning FocusGrid rows of items:
--   { key, frame, title, detail, scroll = ScrollFrame or nil, onActivate = fn or nil }
-- An item's frame may implement SetFocused(on) to draw its own highlight.
local _, ns = ...

local Focus = {}
ns.Focus = Focus

local window, pointer
local grids = {}   -- [tabId] = FocusGrid
local pages = {}   -- [tabId] = page frame
local tabId
local highlighted  -- item whose frame currently shows the focus highlight

local SCROLL_PAD = 8

local function grid() return tabId and grids[tabId] end

function Focus.Current()
    local g = grid()
    return g and g:Current()
end

local function active() return ns.Gamepad and ns.Gamepad.IsActive() or false end

-- Keeps the item fully inside its scroll frame. `toTop` puts it near the top instead, with
-- `item.topGap` above it (room for its section header), as after an LT/RT jump.
-- Returns true if it scrolled.
local function scrollIntoView(item, toTop)
    local sf = item.scroll
    if not sf then return false end
    local top, bottom = item.frame:GetTop(), item.frame:GetBottom()
    local vTop, vBottom = sf:GetTop(), sf:GetBottom()
    if not (top and bottom and vTop and vBottom) then return false end
    local cur, range = sf:GetVerticalScroll(), sf:GetVerticalScrollRange()
    local new = cur
    if toTop then
        new = cur + (vTop - top) - (item.topGap or SCROLL_PAD)
    elseif top > vTop - SCROLL_PAD then
        new = cur - (top - vTop) - SCROLL_PAD
    elseif bottom < vBottom + SCROLL_PAD then
        new = cur + (vBottom - bottom) + SCROLL_PAD
    end
    new = math.max(0, math.min(range or 0, new))
    if new ~= cur then sf:SetVerticalScroll(new) return true end
    return false
end

-- Is the item's centre inside its scroll frame's visible area?
local function visible(item)
    local sf = item.scroll
    if not sf then return true end
    local top, bottom = item.frame:GetTop(), item.frame:GetBottom()
    local vTop, vBottom = sf:GetTop(), sf:GetBottom()
    if not (top and bottom and vTop and vBottom) then return true end
    local mid = (top + bottom) / 2
    return mid <= vTop and mid >= vBottom
end

-- Info line for whatever should be described now: the focused item while the controller
-- drives the window, else the current tab.
function Focus.RestoreInfo()
    local item = active() and Focus.Current()
    if item then ns.UI.SetInfo(item.title, item.detail) else ns.UI.ShowTabInfo() end
end

-- Redraws the focus: highlight, chevron, info line. `scroll` brings the item into view
-- ("top" puts it at the top of the list).
function Focus.Update(scroll)
    if not window then return end
    local item = Focus.Current()
    local show = active() and item ~= nil and window:IsShown()
    if highlighted and (highlighted ~= item or not show) then
        if highlighted.frame.SetFocused then highlighted.frame:SetFocused(false) end
        highlighted = nil
    end
    if not show then
        pointer:Hide()
        Focus.RestoreInfo()
        return
    end
    if scroll then scrollIntoView(item, scroll == "top") end
    if item.frame.SetFocused then item.frame:SetFocused(true) end
    highlighted = item
    pointer:ClearAllPoints()
    pointer:SetPoint("RIGHT", item.frame, "LEFT", 4, 0)
    pointer:SetShown(visible(item))
    ns.UI.SetInfo(item.title, item.detail)
end

-- The window shows tab `id`'s page. Builds or refreshes that tab's grid.
function Focus.SetPage(id, page)
    tabId = id
    pages[id] = page
    grids[id] = grids[id] or ns.FocusGrid.New()
    Focus.Rebuild()
end

-- Re-reads the current page's focus rows (keeps focus on the same key).
function Focus.Rebuild()
    local g, page = grid(), tabId and pages[tabId]
    if not g then return end
    g:SetRows(page and page.GetFocusRows and page:GetFocusRows() or {})
    Focus.Update(true)
end

function Focus.Move(dir)
    local g = grid()
    if g and g:Move(dir) then Focus.Update(true) end
end

function Focus.Jump(delta)
    local g = grid()
    if g and g:JumpSection(delta) then Focus.Update("top") end
end

-- Focus the item with this key on the current tab (used to restore after /azf shots).
function Focus.FocusKey(key)
    local g = grid()
    if g and key ~= nil and g:FocusKey(key) then Focus.Update(true) end
end

function Focus.Activate()
    local item = Focus.Current()
    if item and item.onActivate then item.onActivate(item) end
end

-- Does the current page have sections (for the LT/RT hint)?
function Focus.HasSections()
    local page = tabId and pages[tabId]
    return page and page.hasSections or false
end

function Focus.Attach(f)
    if window then return end
    window = f
    local T = ns.Theme
    pointer = CreateFrame("Frame", nil, f)
    pointer:SetSize(T.layout.pointer[1], T.layout.pointer[2])
    pointer:SetFrameLevel(f:GetFrameLevel() + 30)
    local tex = pointer:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()
    T.SetAtlas(tex, T.atlas.pointer)
    tex:SetVertexColor(T.RGB("focus"))
    -- Bob left and right like the client's pointer.
    if pointer.CreateAnimationGroup then
        local ag = pointer:CreateAnimationGroup()
        ag:SetLooping("BOUNCE")
        local a = ag:CreateAnimation("Translation")
        a:SetOffset(-4, 0)
        a:SetDuration(0.5)
        if a.SetSmoothing then a:SetSmoothing("IN_OUT") end
        ag:Play()
        pointer.anim = ag
    end
    pointer:Hide()
    Focus.pointer = pointer
end
