-- Snapshot/restore of vanilla control geometry + colors. Every presenter
-- adopts controls through here; restore() puts the exact original values back.
MZUI = MZUI or {}
local Snapshot = MZUI.Snapshot or {}
MZUI.Snapshot = Snapshot

local FIELDS = { "x", "y", "width", "height", "tabHeight",
    "equalTabWidth", "maxLength", "centerTabs", "tabPadX" }
local COLOR_FIELDS = {
    "backgroundColor", "backgroundColorMouseOver", "backgroundColorPressed",
    "borderColor", "borderColorMouseOver", "textColor", "font",
}

function Snapshot.capture(control)
    if control.mzuiSnapshot then return control.mzuiSnapshot end
    local state = { control = control, original = {} }
    for _, field in ipairs(FIELDS) do
        state.original[field] = control[field]
    end
    for _, field in ipairs(COLOR_FIELDS) do
        local value = control[field]
        if type(value) == "table" then
            state.original[field] = {
                r = value.r, g = value.g, b = value.b, a = value.a,
            }
        else
            state.original[field] = value
        end
    end
    control.mzuiSnapshot = state
    return state
end

function Snapshot.restore(control)
    local state = control.mzuiSnapshot
    if not state then return end
    for _, field in ipairs(FIELDS) do
        control[field] = state.original[field]
    end
    for _, field in ipairs(COLOR_FIELDS) do
        local value = state.original[field]
        if type(value) == "table" then
            control[field] = {
                r = value.r, g = value.g, b = value.b, a = value.a,
            }
        else
            control[field] = value
        end
    end
    control.mzuiSnapshot = nil
end

return Snapshot
