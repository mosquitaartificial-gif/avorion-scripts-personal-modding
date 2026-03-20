
function string.starts(String,Start)
    return string.sub(String, 1, string.len(Start)) == Start
end

function string.ends(String,End)
    return End == "" or string.sub(String, -string.len(End)) == End
end

function string:split(sep)
    local sep, fields = sep or ":", {}
    local pattern = string.format("([^%s]+)", sep)
    self:gsub(pattern, function(c) table.insert(fields, c) end)
    return fields
end

_T = {}
_de = {}
function interp(s, arguments)
    if arguments == _T or arguments == _de then return s end -- pass through when called with %_T or %_de
    if not arguments then return GetLocalizedString(s) end

    return (s:gsub('($%b{})', function(w)
        local t = arguments
        local key = w:sub(3, -2)

        local fragments = key:split(".")

        local num = #fragments
        for i = 1, num - 1, 1 do
            key = fragments[i]
            t = t[key]

            if not t then return w end
        end

        key = fragments[num]

        local argument = t[key]
        if not argument then return w end
        if type(argument) == "userdata" and argument.__avoriontype == "PluralForm" then
            return argument.translated
        else
            return argument
        end
    end))
end
--print( interp("${name} is ${value}", {name = "foo", value = "bar"}) )

getmetatable("").__mod = interp

-- print( "${name} is ${value}" % {name = "foo", value = "bar"} )
-- Outputs "foo is bar"

function enumerate(values, f)

    local result = ""
    local num = #values

    for i = 1, num do
        local value = values[i]

        if i > 1 then
            if i == num then
                result = result .. " and  /* this is for the last connection of enumerations, such as A, B and C */"%_t
            else
                result = result .. ", "
            end
        end

        local str

        if f then
            str = f(value)
        else
            str = value
        end

        result = result .. str
    end

    return result
end

function string.join(tbl, sep, fmt)
    local result = ""

    local first = true
    for k, v in pairs(tbl) do
        local element
        if fmt then
            element = fmt(k,v)
        else
            element = tostring(v)
        end

        if element then
            if not first then
                result = result .. sep
            end
            first = false

            result = result .. element
        end
    end

    return result;
end

function string.trim(s)
   return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function to_yes_no(value)
    if value then
        return "yes"
    else
        return "no"
    end
end
