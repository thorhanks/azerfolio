return function(t)
    t.test("eq passes on equal values", function() t.eq(1 + 1, 2) end)
    t.test("eq raises on different values", function() t.raises(function() t.eq(1, 2) end) end)
    t.test("same compares tables deeply", function() t.same({ a = { 1, 2 } }, { a = { 1, 2 } }) end)
end
