-- Pure geometry for the main-menu card column. No game globals beyond UIFont
-- metrics passed in as arguments, so headless Kahlua tests drive this directly.
-- Applied every frame in the patched MainScreen prerender; original control
-- geometry/color/font snapshots live in Presenters.Snapshot.
--
-- The column origin goes on the PANEL (children are panel-local); items
-- receive PANEL-LOCAL offsets from menuRow.
MZUI = MZUI or {}
local Geometry = MZUI.Geometry or {}
MZUI.Geometry = Geometry

-- Vertical card column anchored at the screen's bottom-left. Cards shrink to
-- the text (small buttons), stack top-down to bottom, left margin 48px, and
-- the whole stack sits `margin` px above the screen's bottom edge. Returns
-- nil when nothing fits (caller then leaves the vanilla layout untouched).
function Geometry.menuColumn(width, height, count, longestText, rowHeight, fontHgt)
    local marginX = 48
    local pad = 24
    local top = (fontHgt or 24) + 48
    local bottomMargin = 36
    local minHeight = top + bottomMargin
    if height < minHeight or count <= 0 then return nil end

    local gap = 6
    local cardWidth = math.min(260, math.max(170, longestText + 44))
    if marginX + cardWidth + pad > width then return nil end

    local available = height - top - bottomMargin
    local minRow = (fontHgt or 16) + 8
    -- Tight windows shrink the rows toward the font minimum and compress the
    -- gap before giving up.
    local rowsHeight = count * rowHeight + (count - 1) * gap
    if rowsHeight > available then
        local shrinkable = math.max(0, rowHeight - minRow) * count
        local overflow = rowsHeight - available
        if overflow <= shrinkable then
            rowHeight = rowHeight - math.ceil(overflow / count)
            gap = 4
            rowsHeight = count * rowHeight + (count - 1) * gap
        end
        if rowsHeight > available then return nil end
    end

    return {
        x = marginX,                       -- screen-space panel origin
        y = height - bottomMargin - rowsHeight,
        cardWidth = cardWidth,
        rowHeight = rowHeight,
        gap = gap,
        count = count,
    }
end

-- PANEL-LOCAL placement of item i (1-based) inside the column. The caller
-- moves the panel itself to (g.x, g.y).
function Geometry.menuRow(g, i)
    local index = i - 1
    return {
        x = 0,
        y = index * (g.rowHeight + g.gap),
    }
end

return Geometry
