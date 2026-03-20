
local Test =
{
    failures = 0
}

function Test.initialize()
    Test.failures = 0
end

function Test.reportFailure(msg)
    eprint(debug.traceback())
    eprint("Test Failure: " .. msg)
    Test.failures = Test.failures + 1
end


function Test.Check(value)
    if not value then
        Test.reportFailure(string.format("Expected a value that evaluates to 'true', but was '%s'", tostring(value)))
    end
end

function Test.CheckEqual(expected, actual)
    local result = (expected == actual)

    if not result then
        Test.reportFailure(string.format("Expected '%s', but was '%s'", tostring(expected), tostring(actual)))
    end
end

function Test.CheckClose(expected, actual, margin)
    local result = (actual >= expected - margin and actual <= expected + margin)

    if not result then
        Test.reportFailure(string.format("Expected '%s' +- '%s', but was '%s'", tostring(expected), tostring(margin), tostring(actual)))
    end
end

function Test.CheckNotEqual(expected, actual)
    local result = (expected ~= actual)

    if not result then
        Test.reportFailure(string.format("Expected anything but '%s', but was '%s'", tostring(expected), tostring(actual)))
    end
end

function Test.Test(TestRun)
    return function(...)
        local failuresBefore = Test.failures
        TestRun(...)
        local failuresAfter = Test.failures

        return failuresAfter - failuresBefore
    end
end

return Test
