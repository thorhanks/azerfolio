-- Event dispatcher behavior.
local wow = require("mocks.wow")

local function load()
    wow.install()
    local ns = {}
    for _, f in ipairs({ "Init", "Config", "Debug", "Events" }) do
        wow.loadAddonFile("Azerfolio/Core/" .. f .. ".lua", "Azerfolio", ns)
    end
    return ns, ns.Events
end

return function(t)
    t.test("game events reach every handler with arguments", function()
        local _, Events = load()
        local got = {}
        Events.Register("ZONE_CHANGED", function(a) got[#got + 1] = "one:" .. tostring(a) end)
        Events.Register("ZONE_CHANGED", function(a) got[#got + 1] = "two:" .. tostring(a) end)
        wow.fire("ZONE_CHANGED", "x")
        t.same(got, { "one:x", "two:x" })
    end)

    t.test("a failing handler doesn't stop the others and is recorded", function()
        local ns, Events = load()
        local reached = false
        Events.Register("ZONE_CHANGED", function() error("boom") end)
        Events.Register("ZONE_CHANGED", function() reached = true end)
        wow.fire("ZONE_CHANGED")
        t.ok(reached, "second handler ran")
        t.eq(#ns.Debug.errors, 1)
        t.ok(ns.Debug.errors[1].err:find("boom"), "error text kept")
    end)

    t.test("an unknown event is reported, not fatal", function()
        local ns, Events = load()
        wow.unknownEvents.MADE_UP_EVENT = true
        local ok = Events.Register("MADE_UP_EVENT", function() end)
        t.eq(ok, false)
        t.eq(#ns.Debug.errors, 1)
    end)

    t.test("handlers can unregister themselves while running", function()
        local _, Events = load()
        local count = 0
        local function once() count = count + 1; Events.Unregister("ZONE_CHANGED", once) end
        Events.Register("ZONE_CHANGED", once)
        wow.fire("ZONE_CHANGED")
        wow.fire("ZONE_CHANGED")
        t.eq(count, 1)
    end)

    t.test("internal messages", function()
        local _, Events = load()
        local got
        local function h(v) got = v end
        Events.On("AZF_TEST", h)
        Events.Send("AZF_TEST", 42)
        t.eq(got, 42)
        Events.Off("AZF_TEST", h)
        Events.Send("AZF_TEST", 7)
        t.eq(got, 42, "no call after Off")
    end)

    t.test("debounce runs once for a burst of calls", function()
        local _, Events = load()
        local count = 0
        for _ = 1, 5 do Events.Debounce("k", 0.5, function() count = count + 1 end) end
        wow.runTimers()
        t.eq(count, 1)
    end)

    t.test("debounce keys are independent", function()
        local _, Events = load()
        local a, b = 0, 0
        Events.Debounce("a", 0.5, function() a = a + 1 end)
        Events.Debounce("b", 0.5, function() b = b + 1 end)
        wow.runTimers()
        t.eq(a, 1)
        t.eq(b, 1)
    end)
end
