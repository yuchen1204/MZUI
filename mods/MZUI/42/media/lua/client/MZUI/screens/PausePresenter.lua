-- In-game pause menu presenter. Same band layout as the title screen but with
-- a translucent wash (game visible behind). Shares the MainScreen.prerender
-- wrapper that Bootstrap installs; layout() is gated on screen.inGame there.
MZUI = MZUI or {}
local MainMenuPresenter = require "MZUI/screens/MainMenuPresenter"
local Draw = require "MZUI/Draw"
local Geometry = require "MZUI/Geometry"
local Snapshot = require "MZUI/Snapshot"

local Presenter = MZUI.PausePresenter or {}
MZUI.PausePresenter = Presenter

local function layout(screen)
    local panel = screen.bottomPanel
    if not panel or not panel:getIsVisible() then return end
    local items = {}
    for _, child in pairs(panel:getChildren()) do
        local kind = child.Type
        if child ~= screen.controllerLabel and child ~= screen.controllerLabel2
                and child ~= screen.abutton and child ~= screen.versionBtn
                and (kind == "ISLabel" or kind == "ISButton") and child:getIsVisible() then
            table.insert(items, child)
        end
    end
    if #items == 0 then return end
    table.sort(items, function(a, b)
        local ay = a.mzuiOrderY or a:getY()
        local by = b.mzuiOrderY or b:getY()
        if ay == by then return (a.ID or 0) < (b.ID or 0) end
        return ay < by
    end)

    local width, height = getCore():getScreenWidth(), getCore():getScreenHeight()
    local fontHgt = Draw.measureHeight(UIFont.Large)
    local rowHeight = math.max(34, fontHgt + 12)
    local longest = 0
    for _, item in ipairs(items) do
        local text = item.translation or item.name or item.title or ""
        longest = math.max(longest, Draw.measureWidth(item.font or UIFont.Large, text))
    end
    local column = Geometry.menuColumn(width, height, #items, longest + 20, rowHeight, fontHgt)
    if not column then return end

    for _, item in ipairs(items) do
        item.mzuiOrderY = item.mzuiOrderY or item:getY()
    end
    for i, item in ipairs(items) do
        Snapshot.capture(item)
        local spot = Geometry.menuRow(column, i)
        item:setX(spot.x)
        item:setY(spot.y)
        item:setWidth(column.cardWidth)
        item:setHeight(column.rowHeight)
        MainMenuPresenter.bindItemPrerender(item)
    end
    panel:setX(column.x)
    panel:setY(column.y)
    panel:setHeight(#items * column.rowHeight + (#items - 1) * column.gap)
    screen.mzuiBand = column
end

function Presenter.layout(screen)
    layout(screen)
end

return Presenter
