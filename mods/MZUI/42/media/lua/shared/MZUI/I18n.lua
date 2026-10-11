MZUI = MZUI or {}

local I18n = MZUI.I18n or {}
MZUI.I18n = I18n

local PREFIX = "IGUI_MZUI_"
-- Inert argument values: Translator formats %1 templates even when queried
-- without arguments and throws MissingFormatArgumentException; supply dummies
-- and restore our own "%N" placeholders afterwards (same trick PZModernUI used).
local MARKERS = { "__MZUI_ARG_1__", "__MZUI_ARG_2__", "__MZUI_ARG_3__" }

I18n.cache = I18n.cache or {}

local function lookup(key)
    local cached = I18n.cache[key]
    if cached ~= nil then return cached or nil end
    if type(getTextOrNull) ~= "function" then return nil end
    local ok, value = pcall(getTextOrNull, key, MARKERS[1], MARKERS[2], MARKERS[3])
    if not ok or value == nil or value == "" or value == key then
        I18n.cache[key] = false
        return nil
    end
    value = tostring(value)
    for index, marker in ipairs(MARKERS) do
        value = string.gsub(value, marker, function() return "%" .. index end)
    end
    I18n.cache[key] = value
    return value
end

-- I18n.t(keySuffix, englishFallback, ...): looks up "IGUI_MZUI_<keySuffix>"
-- so call sites stay short; translate or fall back, then interpolate
-- %1..%3 with the remaining arguments (missing arguments keep "%N").
function I18n.t(keySuffix, fallback, ...)
    local value = lookup(PREFIX .. keySuffix) or fallback
    local arguments = { ... }
    local result = tostring(value or ""):gsub("%%(%d+)%$s", function(index)
        local replacement = arguments[tonumber(index)]
        return replacement == nil and ("%" .. index .. "$s") or tostring(replacement)
    end)
    return (result:gsub("%%(%d+)", function(index)
        local replacement = arguments[tonumber(index)]
        return replacement == nil and ("%" .. index) or tostring(replacement)
    end))
end

return I18n
