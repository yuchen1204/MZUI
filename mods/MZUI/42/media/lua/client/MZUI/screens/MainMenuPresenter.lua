-- Title screen presenter (inGame == false) and pause menu presenter (inGame
-- == true) share one prerender wrapper installed by Bootstrap: Boot captures
-- the stock MainScreen.prerender once and calls into us by screen.inGame, so
-- no scope ever double-patches the same slot.
--
-- Technique (SlateUI-verified): re-lay the vanilla bottomPanel menu controls
-- every prerender from pure math, rendering band coordinates onto the panel
-- origin (children are parent-local), and swap each label's prerender for one
-- that paints our card, then draws the text itself. Vanilla handlers, sounds,
-- joypad rows and hover sounds stay untouched; the stock grey hover-fade rect
-- and vanilla's left-edge text are replaced by the card chrome.
MZUI = MZUI or {}
local Theme = require "MZUI/Theme"
local Draw = require "MZUI/Draw"
local Geometry = require "MZUI/Geometry"
local Snapshot = require "MZUI/Snapshot"

local Presenter = MZUI.MainMenuPresenter or {}
MZUI.MainMenuPresenter = Presenter

local function visibleItems(screen, panel)
    local items = {}
    if not panel or not panel:getIsVisible() then return items end
    for _, child in pairs(panel:getChildren()) do
        local kind = child.Type
        if child ~= screen.controllerLabel and child ~= screen.controllerLabel2
                and child ~= screen.abutton and child ~= screen.versionBtn
                and (kind == "ISLabel" or kind == "ISButton")
                and child:getIsVisible() then
            table.insert(items, child)
        end
    end
    -- Original vertical order, with stable tiebreak by panel child ID.
    table.sort(items, function(a, b)
        local ay = a.mzuiOrderY or a:getY()
        local by = b.mzuiOrderY or b:getY()
        if ay == by then return (a.ID or 0) < (b.ID or 0) end
        return ay < by
    end)
    return items
end

-- Card paint on the label element itself: fill, border, focus bar.
local function paintCard(item)
    local w, h = item:getWidth(), item:getHeight()
    local hot = item:isMouseOver() or item.joypadFocused
    local state = hot and "hover" or "idle"
    Draw.card(item, 0, 0, w, h, state, item.joypadFocused)
    if item.internal == "LATESTSAVE" and MainScreen.instance
            and MainScreen.instance.continueDisabled then
        local dim = Theme.palette.textFaint
        item.textColor = { r = dim.r, g = dim.g, b = dim.b, a = 0.72 }
    end
end

-- Card + text prerender replicating ISLabel:prerender's text essentials
-- (font metrics, translation override, textColor, tooltip), centered over the
-- card's free width, with the joypad A-icon drawn INSIDE the card instead of
-- the stock -32 offset. Kept in one place with a vanilla-source citation; a
-- game update touching ISLabel:prerender needs a re-diff here.
local JOYPAD_ICON = 32
local ICON_PAD = 10

local function cardPrerender(item)
    paintCard(item)
    local txt = item.translation or item.name
    local metrics = getTextManager()
    local font = item.font or UIFont.Large
    local height = metrics:MeasureFont(font)
    local heightText = metrics:MeasureStringY(font, txt)
    height = math.max(height, heightText)
    if item.textColor then
        item.r = item.textColor.r
        item.g = item.textColor.g
        item.b = item.textColor.b
        item.a = item.textColor.a
    end
    -- Text centered in the card; the joypad A-icon floats left when focused
    -- (overlaying padding, so it never enters the text area of small cards).
    local textW = metrics:MeasureStringX(font, txt)
    local freeW = item:getWidth() - ICON_PAD * 2
    local x = ICON_PAD + math.max(0, (freeW - textW) / 2)
    local y = (item:getHeight() / 2) - (height / 2)
    item:drawText(txt, x, y, item.r, item.g, item.b, item.a, font)
    if item.joypadFocused and item.joypadTexture then
        local texY = item:getHeight() / 2 - JOYPAD_ICON / 2
        item:drawTextureScaled(item.joypadTexture, ICON_PAD, texY, JOYPAD_ICON, JOYPAD_ICON,
            1, 1, 1, 1)
    end
    item:updateTooltip()
end

local function bindItemPrerender(item)
    item.prerender = cardPrerender
    -- Kill the vanilla hover-fade (prerenderBottomPanelLabel's grey rect);
    -- keep the object alive so updateBottomPanelButtons (which reads child.fade)
    -- still works.
    if item.fade ~= nil and item.fade.setFadeIn ~= nil then
        item.fade.setFadeIn(item.fade, false)
    end
end

function Presenter.layout(screen)
    local panel = screen.bottomPanel
    if not panel or not panel:getIsVisible() then return end
    local items = visibleItems(screen, panel)
    if #items == 0 then return end

    local width, height = getCore():getScreenWidth(), getCore():getScreenHeight()
    local fontHgt = Draw.measureHeight(UIFont.Large)
    -- Small buttons: a compact row just the font plus comfortable padding.
    local rowHeight = math.max(34, fontHgt + 12)
    local longest = 0
    for _, item in ipairs(items) do
        local text = item.translation or item.name or item.title or ""
        longest = math.max(longest, Draw.measureWidth(item.font or UIFont.Large, text))
    end
    local column = Geometry.menuColumn(width, height, #items, longest + 20, rowHeight, fontHgt)
    if not column then return end

    -- Remember each item's original y once; it anchors the sort above across
    -- frames even while we keep moving the items themselves.
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
        bindItemPrerender(item)
    end

    -- Move the panel to the column origin: children are panel-local, and
    -- moving the panel supersedes vanilla prerender's own position math (it
    -- sets panel X each frame from the logo) — our patched call runs after
    -- stock, so we win locally for this frame.
    panel:setX(column.x)
    panel:setY(column.y)
    panel:setHeight(#items * column.rowHeight + (#items - 1) * column.gap)
    screen.mzuiBand = column
end

-- Vanilla MainScreen:render re-stacks four pause-menu items (invite, options,
-- exit, quitToDesktop) and re-heights the panel AFTER children painted, with
-- vanilla column coordinates. Called after the stock render so our band wins.
local RESTACKED_FIELDS = { "inviteOption", "optionsOption", "exitOption",
    "quitToDesktopOption" }

function Presenter.reapply(screen)
    local band = screen.mzuiBand
    local panel = screen.bottomPanel
    if not band or not panel then return end
    panel:setX(band.x)
    panel:setY(band.y)
    panel:setHeight(band.count * band.rowHeight + (band.count - 1) * band.gap)
    local items = visibleItems(screen, panel)
    for _, field in ipairs(RESTACKED_FIELDS) do
        local item = screen[field]
        if item ~= nil then
            for i, ordered in ipairs(items) do
                if ordered == item then
                    local spot = Geometry.menuRow(band, i)
                    item:setX(spot.x)
                    item:setY(spot.y)
                    item:setWidth(band.cardWidth)
                    item:setHeight(band.rowHeight)
                    break
                end
            end
        end
    end
end

return Presenter
