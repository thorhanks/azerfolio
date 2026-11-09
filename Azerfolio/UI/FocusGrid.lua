-- Explicit focus grid for gamepad navigation (plan Phase 4 task 6). Pure logic: no WoW API.
-- A page lists its focus targets as rows of items; each row may belong to a section (LT/RT).
--   grid = FocusGrid.New()
--   grid:SetRows({ { items = { a, b }, section = 1 }, { items = { c }, section = 1 }, ... })
--   grid:Move("down") / grid:JumpSection(1) / grid:Current()
-- Items are opaque tables; an item's `key` (if any) lets focus survive SetRows.
-- An item's `group` (if any) makes a column: up/down stay among items of the same group and
-- skip rows that have none (the Overview's two columns share rows); left/right cross groups.
local _, ns = ...

local FocusGrid = {}
FocusGrid.__index = FocusGrid
ns.FocusGrid = FocusGrid

function FocusGrid.New()
    return setmetatable({ rows = {}, row = nil, col = nil, wantCol = nil }, FocusGrid)
end

local function nonEmpty(rows)
    local out = {}
    for _, r in ipairs(rows or {}) do
        if r.items and #r.items > 0 then out[#out + 1] = r end
    end
    return out
end

-- Replaces the rows. Keeps focus on the same item (by key) if it still exists, else on the
-- nearest valid position, else the first item.
function FocusGrid:SetRows(rows)
    local key = self:CurrentKey()
    self.rows = nonEmpty(rows)
    if key ~= nil and self:FocusKey(key) then return end
    if self.row then
        self.row = math.min(self.row, #self.rows)
        if self.row >= 1 then
            self.col = math.min(self.col or 1, #self.rows[self.row].items)
            return
        end
    end
    self:Reset()
end

-- Focus the first item (or nothing if the grid is empty).
function FocusGrid:Reset()
    if #self.rows == 0 then
        self.row, self.col, self.wantCol = nil, nil, nil
    else
        self.row, self.col, self.wantCol = 1, 1, 1
    end
end

function FocusGrid:IsEmpty() return #self.rows == 0 end

function FocusGrid:Current()
    if not self.row then return nil end
    local r = self.rows[self.row]
    return r and r.items[self.col], self.row, self.col
end

function FocusGrid:CurrentKey()
    local item = self:Current()
    return item and item.key
end

-- The columns (indexes) in row `row` whose items are in `group` (nil = items without one).
local function inGroup(r, group)
    local out = {}
    for ci, item in ipairs(r.items) do
        if item.group == group then out[#out + 1] = ci end
    end
    return out
end

-- The position of (row, col) among the items of its group in that row.
function FocusGrid:GroupIndex(row, col)
    local r = self.rows[row]
    local item = r and r.items[col]
    if not item then return col end
    for i, ci in ipairs(inGroup(r, item.group)) do
        if ci == col then return i end
    end
    return col
end

function FocusGrid:Focus(row, col)
    local r = self.rows[row]
    if not r then return false end
    self.row = row
    self.col = math.max(1, math.min(col or 1, #r.items))
    self.wantCol = self:GroupIndex(self.row, self.col)
    return true
end

function FocusGrid:FocusKey(key)
    for ri, r in ipairs(self.rows) do
        for ci, item in ipairs(r.items) do
            if item.key == key then return self:Focus(ri, ci) end
        end
    end
    return false
end

-- Moves focus. Returns true if it changed. Up/down keep the column you were aiming for
-- (wantCol), so passing through a shorter row and back returns to the same column.
-- Edges don't wrap.
function FocusGrid:Move(dir)
    if not self.row then
        if #self.rows == 0 then return false end
        self:Reset()
        return true
    end
    if dir == "left" or dir == "right" then
        local step = dir == "left" and -1 or 1
        local n = #self.rows[self.row].items
        local col = self.col + step
        if col < 1 or col > n then
            -- Two columns with different lengths (the Overview): from an item whose row has
            -- nothing on that side, go to the nearest row (up first) that has an item of
            -- another group, its last one going left, its first going right.
            local cur = self.rows[self.row].items[self.col]
            if not (cur and cur.group) then return false end
            -- Which groups lie on that side: seen before (left) or after (right) cur's group
            -- in a row that has both.
            local side = {}
            for _, r in ipairs(self.rows) do
                local mine
                for ci, item in ipairs(r.items) do if item.group == cur.group then mine = mine or ci end end
                if mine then
                    for ci, item in ipairs(r.items) do
                        if item.group and item.group ~= cur.group and ((dir == "left") == (ci < mine)) then
                            side[item.group] = true
                        end
                    end
                end
            end
            for d = 1, #self.rows do
                for _, ri in ipairs({ self.row - d, self.row + d }) do
                    local r = self.rows[ri]
                    if r then
                        local pick
                        for ci, item in ipairs(r.items) do
                            if side[item.group] and (dir == "left" or not pick) then pick = ci end
                        end
                        if pick then
                            self.row, self.col = ri, pick
                            self.wantCol = self:GroupIndex(ri, pick)
                            return true
                        end
                    end
                end
            end
            return false
        end
        self.col = col
        self.wantCol = self:GroupIndex(self.row, col)
        return true
    elseif dir == "up" or dir == "down" then
        local step = dir == "up" and -1 or 1
        local cur = self.rows[self.row].items[self.col]
        local group = cur and cur.group
        local row = self.row + step
        while row >= 1 and row <= #self.rows do
            local cols = inGroup(self.rows[row], group)
            if #cols > 0 then
                self.row = row
                self.col = cols[math.min(self.wantCol or 1, #cols)]
                return true
            end
            row = row + step
        end
        return false
    end
    return false
end

-- LT/RT: to the first row of the next or previous section. Backwards goes to the start of
-- the current section first, then to the previous one. Returns true if focus changed.
-- Grids without sections page by `pageRows` instead (default 8).
function FocusGrid:JumpSection(delta, pageRows)
    if not self.row then return self:Move("down") end
    local rows, cur = self.rows, self.rows[self.row].section
    if cur == nil then
        local target = math.max(1, math.min(#rows, self.row + delta * (pageRows or 8)))
        if target == self.row then return false end
        self.row = target
        self.col = math.min(self.wantCol or 1, #rows[target].items)
        return true
    end
    local function startOf(i)
        local s = rows[i].section
        while i > 1 and rows[i - 1].section == s do i = i - 1 end
        return i
    end
    local target
    if delta > 0 then
        for i = self.row + 1, #rows do
            if rows[i].section ~= cur then target = i break end
        end
    else
        local start = startOf(self.row)
        if start < self.row then
            target = start
        elseif start > 1 then
            target = startOf(start - 1)
        end
    end
    if not target then return false end
    self.row, self.col, self.wantCol = target, 1, 1
    return true
end
