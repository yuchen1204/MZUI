-- Settings (MainOptions) presenter: fullscreen the modal, reskin the tab
-- strip and the row controls. Vanilla doLayout / state untouched; geometry
-- recomputed only when the screen size or tab count changes (SlateUI lesson).
-- Bootstrap owns the Hook scope and passes it in (single owner per slot).
MZUI = MZUI or {}
local Theme = require "MZUI/Theme"
local Draw = require "MZUI/Draw"
local Snapshot = require "MZUI/Snapshot"

local Presenter = MZUI.OptionsPresenter or {}
MZUI.OptionsPresenter = Presenter

local transparentBackground = { r = 0, g = 0, b = 0, a = 0 }

local function drawTabsBackground(tabs)
    tabs.mzuiStockPrerender(tabs)
    local surface = Theme.palette.surface
    tabs:drawRect(0, tabs.tabHeight, tabs:getWidth(), tabs:getHeight() - tabs.tabHeight,
        surface.a, surface.r, surface.g, surface.b)
end

-- Tab strip repaint (SlateUI's drawTabs approach): when the panel is not
-- dragging/overflowing, draw flat tab cards in our theme; otherwise let the
-- stock render handle drag ghosts, blink and scroll arrows.
local function drawTabs(tabs)
    -- blinkTabs is a table that vanilla keeps allocated (empty = truthy),
    -- so test its length the same way SlateUI's guard should have.
    local blinking = type(tabs.blinkTabs) == "table" and #tabs.blinkTabs > 0
    if tabs.isDragging or blinking
            or tabs:getWidthOfAllTabs() > tabs:getWidth() then
        return tabs.mzuiStockRender(tabs)
    end
    local surface = Theme.palette.surface
    local surfaceAlt = Theme.palette.surfaceAlt
    local border = Theme.palette.border
    local accent = Theme.palette.accent
    local text = Theme.palette.text
    local textDim = Theme.palette.textDim
    local fontHgt = Draw.measureHeight(UIFont.Small)
    tabs:drawRectBorder(0, tabs.tabHeight, tabs:getWidth(), tabs:getHeight() - tabs.tabHeight,
        border.a, border.r, border.g, border.b)
    for i, view in ipairs(tabs.viewList) do
        local x = tabs:getTabX(i)
        local w = tabs.equalTabWidth and tabs.maxLength or view.tabWidth
        local selected = tabs.activeView == view
        local hot = tabs:isMouseOver() and tabs:getMouseY() >= 0
            and tabs:getMouseY() < tabs.tabHeight
            and tabs:getTabIndexAtX(tabs:getMouseX()) == i
        local color = selected and surfaceAlt or (hot and surfaceAlt or surface)
        tabs:drawRect(x, 0, w, tabs.tabHeight, color.a, color.r, color.g, color.b)
        tabs:drawTextCentre(view.name, x + w / 2, math.floor((tabs.tabHeight - fontHgt) / 2),
            selected and text.r or textDim.r,
            selected and text.g or textDim.g,
            selected and text.b or textDim.b, 1, UIFont.Small)
        if selected then
            tabs:drawRect(x, tabs.tabHeight - 2, w, 2, accent.a, accent.r, accent.g, accent.b)
        end
    end
end

local function bindTabsRender(tabs)
    if not tabs then return end
    if tabs.mzuiStockRender == nil then
        tabs.mzuiStockRender = tabs.render
        tabs.mzuiStockPrerender = tabs.prerender
        tabs.prerender = drawTabsBackground
        tabs.render = drawTabs
    end
end

-- Color-only reskin of the stock row controls (SlateUI's proven skin()):
-- replaces backgrounds/borders, keeps every other behavior. Selected-color
-- controls (color pickers encode value in the background) are left alone.
local function mzuiSkinControl(control)
    if control == nil or control.mzuiSkinned then return end
    local kind = control.Type
    local palette = Theme.palette
    if kind == "ISButton" or kind == "ISComboBox" or kind == "ISTextEntryBox" then
        if kind ~= "ISButton" or (not control.backgroundColor
                or (not control.pzoptValue and control.title ~= "")) then
            control.backgroundColor = palette.surfaceAlt
            control.backgroundColorMouseOver = palette.surfaceActive
        end
        control.borderColor = palette.border
        control.borderColorMouseOver = palette.accent
        control.mzuiSkinned = true
    end
end

local function skin(child)
    mzuiSkinControl(child)
end

function Presenter.layout(screen)
    local tabs = screen.tabs
    if not tabs or not screen.saveButton then return end
    local sw, sh = getCore():getScreenWidth(), getCore():getScreenHeight()

    -- Keep colors + tab reskin always on.
    local canvas = Theme.palette.canvas
    if MainScreen.instance and MainScreen.instance.inGame then
        canvas = Theme.palette.inGameCanvas or canvas
    end
    screen.backgroundColor = canvas
    -- UIElement draws prerender, children, then render. The stock render
    -- also fills the body, so keep that fill transparent even on fallback.
    tabs.backgroundColor = transparentBackground
    tabs.borderColor = Theme.palette.border
    -- Alignment applies even when pzopt owns the modal's geometry.
    tabs:setCenterTabs(false)
    bindTabsRender(tabs)
    local active = tabs:getActiveView()
    if active and active.getChildren then
        for _, child in pairs(active:getChildren()) do
            skin(child)
        end
    end

    -- GEOMETRY: the pzopt mod ships its own fullscreen-widen + reflow engine
    -- for this modal (fixed internal columns, its own scroll lists). Sizing
    -- on top of it shifts every pzopt page element out of the visible area
    -- (observed: its scrollbar parked at x=2480 inside a 1872px page and the
    -- whole tab rendered empty). When pzopt's tab is in this modal, or the
    -- modal already spans the screen, pzopt's geometry stays in charge and
    -- MZUI only reskins. Fresh installs with no pzopt tab take the SlateUI
    -- fullscreen path below.
    local pzoptTab = tostring(screen.pzoptPanel) ~= "nil"
        and tostring(screen.pzoptPanel) ~= ""
    if pzoptTab then return end
    local alreadyFullscreen = screen:getWidth() >= sw - 8
        and screen:getHeight() >= sh * 0.5
    if alreadyFullscreen then return end

    local pad = 24
    local header = Draw.measureHeight(UIFont.Large) + 30
    local footer = math.max(screen.saveButton:getHeight(), Draw.measureHeight(UIFont.Small) + 12) + 24
    local width, height = sw - pad * 2, sh - header - footer
    local changed = screen.mzuiWidth ~= sw or screen.mzuiHeight ~= sh
        or screen.mzuiViewCount ~= #tabs.viewList
    if changed then
        screen.mzuiWidth, screen.mzuiHeight, screen.mzuiViewCount = sw, sh, #tabs.viewList
        Snapshot.capture(tabs)
        screen:setX(0); screen:setY(0); screen:setWidth(sw); screen:setHeight(sh)
        screen:recalcSize()
        tabs:setX(pad); tabs:setY(header)
        tabs:setWidth(width); tabs:setHeight(height)
        tabs:setAnchorRight(false); tabs:setAnchorBottom(false)
        tabs.tabHeight = Draw.measureHeight(UIFont.Small) + 20
        tabs:recalcSize()
        for _, item in ipairs(tabs.viewList) do
            local page = item.view
            Snapshot.capture(page)
            page:setX(0); page:setY(tabs.tabHeight)
            page:setWidth(width); page:setHeight(height - tabs.tabHeight)
            page:setAnchorRight(false); page:setAnchorBottom(false)
            page:recalcSize()
        end
        if screen.keyButtonWidth and screen.doLayout then screen:doLayout() end
        -- One-shot geometry probe: sees what the presenter actually applied.
        if not screen.mzuiProbed then
            screen.mzuiProbed = true
            print("[MZUI] options relayout: screen " .. sw .. "x" .. sh
                .. " tabs " .. tabs:getX() .. "," .. tabs:getY() .. " "
                .. tabs:getWidth() .. "x" .. tabs:getHeight()
                .. " views " .. #tabs.viewList
                .. " tabH " .. tostring(tabs.tabHeight))
        end
        local buttons = { screen.backButton, screen.acceptButton, screen.saveButton }
        local x = sw - pad
        for i = #buttons, 1, -1 do
            local b = buttons[i]
            Snapshot.capture(b)
            x = x - b:getWidth()
            b:setX(x); b:setY(sh - footer + 10)
            b:setAnchorBottom(false)
            x = x - 10
        end
    end
end

-- Move a form as a group: label/control gaps, keybinding columns and row
-- heights stay intact. Full-width rules and anchored section headings aren't
-- part of the form bounds. Custom responsive pages own their own columns.
function Presenter.alignPage(screen, page)
    if not page or not page.getChildren or page == screen.pzoptPanel
            or (screen.controllerTab and page == screen.controllerTab.contentPanel)
            or page.onDoLayout then return end
    local children = page:getChildren()
    local rows, headings = {}, {}
    local left, right
    for _, child in pairs(children) do
        if child ~= page.vscroll and child ~= page.hscroll
                and child.Type ~= "ISScrollBar" and child.Type ~= "HorizontalLine" then
            if child.Type == "ISLabel" and child.anchorRight then
                headings[#headings + 1] = child
            else
                rows[#rows + 1] = child
                left = math.min(left or child:getX(), child:getX())
                right = math.max(right or child:getRight(), child:getRight())
            end
        end
    end
    if not left then return end
    local available = page:getWidth() - (page.vscroll and page.vscroll:getWidth() or 0)
    -- Reduce the margin on narrow windows rather than pushing the last
    -- control beyond the scrollbar. Oversize stock forms retain their width.
    local margin = math.max(0, math.min(24, available - (right - left)))
    local dx = margin - left
    for _, child in ipairs(rows) do
        if dx ~= 0 then
            child:setX(child:getX() + dx)
            if child.Type == "ISLabel" and child.originalX then
                child.originalX = child.originalX + dx
            end
        end
    end
    for _, child in ipairs(headings) do
        local shift = margin - child:getX()
        child:setX(margin)
        if child.originalX then child.originalX = child.originalX + shift end
    end
end

function Presenter.fitControllerPage(screen, page)
    if not page or not page.midPanel or not page.rightPanel or not page.onDoLayout then return end
    local tabs = screen.tabs
    local core = getCore()
    local x, y = tabs:getAbsoluteX(), tabs:getAbsoluteY() + tabs.tabHeight
    local bottom = math.min(core:getScreenHeight(), tabs:getAbsoluteY() + tabs:getHeight())
    if screen.saveButton then bottom = math.min(bottom, screen.saveButton:getAbsoluteY() - 12) end
    local width = math.max(1, math.min(tabs:getWidth(), core:getScreenWidth() - x))
    local height = math.max(1, bottom - y)
    -- This page is explicitly sized to the visible viewport. Parent anchor
    -- deltas must not enlarge it again after the fullscreen modal resizes.
    page:setAnchorRight(false)
    page:setAnchorBottom(false)
    page:setX(0)
    page:setY(tabs.tabHeight)
    page:setWidth(width)
    page:setHeight(height)
end

function Presenter.layoutResponsivePage(page)
    if not page or not page.onDoLayout or not page.doLayout then return end
    local width, height = page:getWidth(), page:getHeight()
    if page.mzuiLayoutWidth == width and page.mzuiLayoutHeight == height then return end
    -- Recalculate nested controller panels after the modal/anchors resize.
    -- recalcSize alone does not run their onDoLayout callbacks.
    page:doLayout()
    page.mzuiLayoutWidth, page.mzuiLayoutHeight = width, height
end

-- Reuse the native BACK button so unsaved-change prompts, controller cancel
-- and modal visibility still follow MainOptions. Place it after stock layout.
function Presenter.layoutBackButton(screen)
    local button = screen.backButton
    if not button or not screen.tabs then return end
    local height = Draw.measureHeight(UIFont.Small) + 8
    local headerBottom = height + 8
    local tabs = screen.tabs
    if tabs:getY() < headerBottom then
        local dy = headerBottom - tabs:getY()
        tabs:setY(headerBottom)
        tabs:setHeight(math.max(1, tabs:getHeight() - dy))
    end
    button:setAnchorLeft(true)
    button:setAnchorRight(false)
    button:setAnchorTop(true)
    button:setAnchorBottom(false)
    button:setX(8)
    button:setY(4)
    button:setHeight(height)
    mzuiSkinControl(button)
    button:bringToTop()
end

function Presenter.install(scope)
    local stockPrerender = MainOptions.prerender
    scope:patch(MainOptions, "prerender", function(self, ...)
        Presenter.layout(self)
        stockPrerender(self, ...)
        Presenter.layoutBackButton(self)
        if self.tabs then
            local page = self.tabs:getActiveView()
            Presenter.fitControllerPage(self, page)
            Presenter.layoutResponsivePage(page)
            Presenter.alignPage(self, page)
        end
    end)
end

return Presenter
