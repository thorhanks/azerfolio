-- Minimal test runner. Usage (from repo root): luajit tests/run.lua
-- Lua 5.1 semantics only (matches the WoW client).
-- Each test file returns function(t) and registers cases with t.test(name, fn).

package.path = "./tests/?.lua;./?.lua;" .. package.path

local FILES = {
    "tests/runner_test.lua",
    "tests/diag_smoke_test.lua",
    "tests/sv_test.lua",
    "tests/events_test.lua",
    "tests/addon_smoke_test.lua",
    "tests/ui_test.lua",
    "tests/focusgrid_test.lua",
    "tests/catalogue_test.lua",
    "tests/progression_test.lua",
    "tests/zones_test.lua",
    "tests/overview_test.lua",
    "tests/quests_test.lua",
    "tests/questrules_test.lua",
    "tests/completion_test.lua",
    "tests/tools_test.lua",
}

local t = {}
local cases = {}

function t.test(name, fn) cases[#cases + 1] = { name = name, fn = fn } end

local function fmt(v)
    if type(v) == "string" then return string.format("%q", v) end
    return tostring(v)
end

function t.ok(v, msg)
    if not v then error(msg or "expected truthy value", 2) end
end

function t.eq(actual, expected, msg)
    if actual ~= expected then
        error(string.format("%sexpected %s, got %s", msg and (msg .. ": ") or "", fmt(expected), fmt(actual)), 2)
    end
end

local function deepEq(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k, v in pairs(a) do if not deepEq(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

function t.same(actual, expected, msg)
    if not deepEq(actual, expected) then error((msg or "tables differ"), 2) end
end

function t.raises(fn, msg)
    if pcall(fn) then error(msg or "expected an error", 2) end
end

local passed, failed = 0, 0
for _, file in ipairs(FILES) do
    cases = {}
    local chunk, loadErr = loadfile(file)
    if not chunk then
        print("LOAD FAIL " .. file .. ": " .. tostring(loadErr))
        failed = failed + 1
    else
        local ok, register = pcall(chunk)
        if ok and type(register) == "function" then ok, register = pcall(register, t) end
        if not ok then
            print("LOAD FAIL " .. file .. ": " .. tostring(register))
            failed = failed + 1
        end
        for _, c in ipairs(cases) do
            local cok, err = xpcall(c.fn, debug.traceback)
            if cok then
                passed = passed + 1
            else
                failed = failed + 1
                print("FAIL " .. file .. " :: " .. c.name .. "\n  " .. tostring(err))
            end
        end
    end
end

print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
