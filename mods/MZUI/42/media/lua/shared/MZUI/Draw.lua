MZUI = MZUI or {}

local Theme = require "MZUI/Theme"

-- Drawing helpers over ISUIElement primitives. Every function takes the
-- (already instantiated) element as receiver so Kahlua's Java bridge can bind
-- the Draw calls.
local Draw = MZUI.Draw or {}
MZUI.Draw = Draw

function Draw.fill(part, x, y, w, h, color)
    if not color or not part.drawRect then return end
    part:drawRect(x, y, w, h, color.a, color.r, color.g, color.b)
end

-- Rounded-corner card pieces: 16px white quarter-arcs (alpha feathers the
-- edge) tinted per draw; generated at build time, loaded with filtering.
local RADII = 24
local cornerTextures = nil
local cornerNames = { "card_corner_tl.png", "card_corner_tr.png",
    "card_corner_bl.png", "card_corner_br.png" }

local function loadCorners()
    if cornerTextures ~= nil then return cornerTextures end
    if type(getTexture) ~= "function" then return nil end
    if type(useTextureFiltering) == "function" then
        useTextureFiltering(true)
    end
    cornerTextures = {}
    for i, name in ipairs(cornerNames) do
        cornerTextures[i] = getTexture("media/ui/MZUI/" .. name)
    end
    if type(useTextureFiltering) == "function" then
        useTextureFiltering(false)
    end
    return cornerTextures
end

-- Tinted quarter-arc corner at (x, y) sized r (top-left / top-right /
-- bottom-left / bottom-right by whichQuarter 1..4).
local function drawCorner(part, quarter, x, y, r, color)
    local textures = loadCorners()
    if textures == nil or not textures[quarter] then return end
    local tex = textures[quarter]
    if tex == nil or tex:getWidth() == 0 then return end
    part:drawTextureScaled(tex, x, y, r, r, color.a, color.r, color.g, color.b)
end

-- Rounded rect fill: two straight bands + four tinted corners. The corner
-- textures carry the alpha shape, so the result is a real rounded card over
-- any backdrop (no setStencil).
function Draw.roundedFill(part, x, y, w, h, color)
    if w <= 0 or h <= 0 then return end
    local r = math.min(RADII, math.floor(h / 2), math.floor(w / 2))
    if r < 4 then
        Draw.fill(part, x, y, w, h, color)
        return
    end
    Draw.fill(part, x + r, y, w - 2 * r, h, color)         -- vertical middle
    Draw.fill(part, x, y + r, w, h - 2 * r, color)         -- horizontal middle
    drawCorner(part, 1, x, y, r, color)                    -- top-left
    drawCorner(part, 2, x + w - r, y, r, color)            -- top-right
    drawCorner(part, 3, x, y + h - r, r, color)            -- bottom-left
    drawCorner(part, 4, x + w - r, y + h - r, r, color)    -- bottom-right
end

function Draw.border(part, x, y, w, h, color)
    if not color or not part.drawRectBorder then return end
    part:drawRectBorder(x, y, w, h, color.a, color.r, color.g, color.b)
end

-- Surface + optional hover/selected state + left focus bar. Rounded corners
-- come from the 9-slice roundedFill; the square border draw is skipped so the
-- rounding stays clean.
function Draw.card(part, x, y, w, h, state, focused)
    local c = Theme.cardColor(state and state or "idle")
    Draw.roundedFill(part, x, y, w, h, c)
    if focused then
        Draw.fill(part, x, y, Theme.focusBarWidth, h, Theme.palette.accent)
    end
end

-- Backdrop wash over a whole screen (main menu keeps the animated scene; the
-- wash darkens it so panels read).
function Draw.wash(part, color)
    Draw.fill(part, 0, 0, part:getWidth(), part:getHeight(), color)
end

function Draw.measureWidth(font, text)
    if type(getTextManager) ~= "function" then return #tostring(text or "") * 8 end
    return getTextManager():MeasureStringX(font, text or "")
end

function Draw.measureHeight(font)
    if type(getTextManager) ~= "function" then return 16 end
    return getTextManager():getFontHeight(font)
end

-- Clamp a text column: shrink to fit maxWidth with an ellipsis (no wrap).
function Draw.ellipsize(font, text, maxWidth)
    text = tostring(text or "")
    if Draw.measureWidth(font, text) <= maxWidth then return text end
    while #text > 1 do
        text = string.sub(text, 1, #text - 1)
        local candidate = text .. "..."
        if Draw.measureWidth(font, candidate) <= maxWidth then
            return candidate
        end
    end
    return "..."
end

return Draw
