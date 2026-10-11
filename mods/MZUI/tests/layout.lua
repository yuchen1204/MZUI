-- Headless Kahlua regression for the pure layout functions.
-- Returns "OK", or "FAILED:<count>:<names>" — LayoutCheck.java turns a
-- non-OK word into exit 1.
local failures = 0
local failedNames = {}
local function check(name, condition)
    if not condition then
        failures = failures + 1
        failedNames[#failedNames + 1] = tostring(name)
    end
end

if MZUI and MZUI.Geometry then
    local G = MZUI.Geometry
    local g = G.menuColumn(1920, 1080, 8, 200, 44, 24)
    check("column exists at 1080p", g ~= nil)
    if g then
        -- bottom-left anchored: last item's bottom sits bottomMargin above 1080
        local last = G.menuRow(g, 8)
        local lastBottom = g.y + last.y + g.rowHeight
        check("column bottom margin", lastBottom <= 1080 and lastBottom > 1080 - 80)
        check("column left margin", g.x == 48)
        check("cards stay on screen", g.x + g.cardWidth <= 1920)
        for i = 2, 8 do
            local p = G.menuRow(g, i)
            local prev = G.menuRow(g, i - 1)
            check("stack grows downward i=" .. i, p.y > prev.y)
        end
    end

    local small = G.menuColumn(1024, 640, 13, 260, 40, 20)
    check("small window survives 13 items", small ~= nil)
    if small then
        local last = G.menuRow(small, 13)
        check("small column fits", small.y + last.y + small.rowHeight < 640)
    end

    local tiny = G.menuColumn(800, 480, 16, 260, 40, 20)
    check("unsuitably small window returns nil", tiny == nil)
end

if MZUI and MZUI.I18n then
    local rendered = MZUI.I18n.t("ContinueHint", "Continue from the last save")
    check("i18n fallback", rendered == "Continue from the last save")
    local withArg = MZUI.I18n.t("Missing", "%1 and %2", "a", "b")
    check("i18n interpolation", withArg == "a and b")
else
    check("I18n loaded", false)
end

if MZUI and MZUI.Hook then
    local Hook = MZUI.Hook
    local target = { prerender = function() return "stock" end }
    local scope = Hook.new()
    scope:patch(target, "prerender", function(s, a) return "first:" .. tostring(a) end)
    check("wrap works", target.prerender(target, 9) == "first:9")
    check("slot marked wrapped", Hook.isWrapped(target, "prerender"))
    scope:dispose()
    check("dispose restores", target.prerender() == "stock")
    check("slot unmarked after dispose", not Hook.isWrapped(target, "prerender"))
    local scopeA = Hook.new()
    scopeA:patch(target, "prerender", function(s) return "A" end)
    check("live double patch rejected", not Hook.isSafeToPatch(target, "prerender"))
    scopeA:dispose()
    check("identity restore after chain", target.prerender() == "stock")
    check("disposed scope reported", scope:isDisposed())
else
    check("Hook loaded", false)
end

-- Follow UIElement's actual paint order: prerender -> children -> render.
-- Exercise both the custom strip and every stock-render fallback.
if MZUI and MZUI.OptionsPresenter then
    MainScreen = { instance = {} }
    local phase, backgrounds, covered, stockPre, stockRender
    local tabs = {
        tabHeight = 30, viewList = {}, blinkTabs = {},
        getWidth = function() return 1000 end,
        getHeight = function() return 700 end,
        getWidthOfAllTabs = function(self) return self.overflow and 1200 or 200 end,
        getActiveView = function() return nil end,
        setCenterTabs = function(self, center) self.centerTabs = center end,
        drawRectBorder = function() end,
        drawRect = function(self, x, y, w, h, a)
            if y >= self.tabHeight and a > 0 then
                backgrounds = backgrounds + 1
                if phase == "after children" then covered = true end
            end
        end,
        prerender = function() stockPre = stockPre + 1 end,
        render = function(self)
            stockRender = stockRender + 1
            self:drawRect(0, self.tabHeight, 1000, 670, self.backgroundColor.a)
        end,
    }
    local screen = { tabs = tabs, saveButton = {}, pzoptPanel = {} }
    for _, mode in ipairs({ "normal", "overflow", "drag", "blink" }) do
        backgrounds, covered, stockPre, stockRender = 0, false, 0, 0
        tabs.overflow = mode == "overflow"
        tabs.isDragging = mode == "drag"
        tabs.blinkTabs = mode == "blink" and { "Settings" } or {}
        MZUI.OptionsPresenter.layout(screen)
        MZUI.OptionsPresenter.layout(screen)
        phase = "before children"
        tabs:prerender()
        phase = "after children"
        tabs:render()
        check(mode .. " paints body once", backgrounds == 1)
        check(mode .. " keeps settings visible", not covered)
        check(mode .. " preserves stock prerender once", stockPre == 1)
        check(mode .. " stock fallback", stockRender == (mode == "normal" and 0 or 1))
    end
    -- Form translation must preserve spacing and never move scrollbars.
    local function element(x, width, kind)
        return { x = x, width = width, Type = kind,
            getX = function(self) return self.x end,
            getRight = function(self) return self.x + self.width end,
            getWidth = function(self) return self.width end,
            setX = function(self, value) self.x = value end }
    end
    local label = element(300, 180, "ISLabel")
    label.originalX = 480
    local control = element(500, 200, "ISComboBox")
    local secondColumn = element(800, 180, "ISButton")
    local heading = element(50, 150, "ISLabel")
    heading.anchorRight, heading.originalX = true, 50
    local rule = element(12, 976, "HorizontalLine")
    local scrollbar = element(987, 13, "ISScrollBar")
    local page = { width = 1000, vscroll = scrollbar,
        getWidth = function(self) return self.width end,
        getChildren = function() return { label, control, secondColumn, heading, rule, scrollbar } end }
    local align = MZUI.OptionsPresenter.alignPage
    align({}, page)
    check("form left margin", label.x == 24)
    check("label control gap preserved", control.x - label:getRight() == 20)
    check("keybinding column gap preserved", secondColumn.x - control.x == 300)
    check("heading aligned", heading.x == 24)
    check("label anchor follows translation", label.originalX == label:getRight())
    check("scrollbar and rules fixed", scrollbar.x == 987 and rule.x == 12)
    align({}, page)
    check("alignment does not drift", label.x == 24 and label.originalX == 204)
    page.width = 700
    align({}, page)
    check("narrow margin reduced", label.x == 7 and secondColumn:getRight() == 687)
    page.width = 600
    align({}, page)
    check("oversize form starts at zero", label.x == 0 and control.width == 200)
    label.x = 300
    align({ pzoptPanel = page }, page)
    check("pzopt geometry preserved", label.x == 300)
    page.onDoLayout = function() end
    align({}, page)
    check("responsive controller geometry preserved", label.x == 300)
    local layoutCalls = 0
    page.height = 700
    page.getHeight = function(self) return self.height end
    page.doLayout = function(self)
        layoutCalls = layoutCalls + 1
        self.onDoLayout(self)
    end
    MZUI.OptionsPresenter.layoutResponsivePage(page)
    MZUI.OptionsPresenter.layoutResponsivePage(page)
    check("responsive page laid out once at final size", layoutCalls == 1)
    page.width = 1200
    MZUI.OptionsPresenter.layoutResponsivePage(page)
    check("responsive page reflows after width change", layoutCalls == 2)
    page.height = 800
    MZUI.OptionsPresenter.layoutResponsivePage(page)
    check("responsive page reflows after height change", layoutCalls == 3)
    page.onDoLayout = nil
    align({ controllerTab = { contentPanel = page } }, page)
    check("controller excluded without layout callback", label.x == 300)
    local controller = element(0, 2496, "ISPanelJoypad")
    controller.midPanel, controller.rightPanel = {}, {}
    controller.onDoLayout = function() end
    controller.setY = function(self, value) self.y = value end
    controller.setWidth = function(self, value) self.width = value end
    controller.setHeight = function(self, value) self.height = value end
    controller.setAnchorRight = function(self, value) self.anchorRight = value end
    controller.setAnchorBottom = function(self, value) self.anchorBottom = value end
    local modal = { tabs = {
        tabHeight = 30,
        getAbsoluteX = function() return 24 end,
        getAbsoluteY = function() return 34 end,
        getWidth = function() return 2496 end,
        getHeight = function() return 1400 end,
    }, saveButton = { getAbsoluteY = function() return 1040 end } }
    MZUI.OptionsPresenter.fitControllerPage(modal, controller)
    check("controller width clamped to screen", controller.width == 1896)
    check("controller leaves footer visible", controller.height == 964 and controller.y == 30)
    check("controller avoids double anchor resizing", not controller.anchorRight and not controller.anchorBottom)
    MZUI.OptionsPresenter.fitControllerPage(modal, controller)
    check("controller viewport does not drift", controller.width == 1896 and controller.height == 964)
else
    check("OptionsPresenter loaded", false)
end

if MZUI and MZUI.MultiplayerPresenter then
    local calls = {}
    MultiplayerUI = {
        prerender = function() calls[#calls + 1] = "stock-pre" end,
        render = function() calls[#calls + 1] = "stock-render" end,
    }
    local originalPre, originalRender = MultiplayerUI.prerender, MultiplayerUI.render
    local scope = MZUI.Hook.new()
    MZUI.MultiplayerPresenter.install(scope)
    local panel = { getChildren = function() return {} end }
    local row = { index = 1 }
    local list = { selected = 1, itemheight = 40,
        getChildren = panel.getChildren,
        drawRect = function() calls[#calls + 1] = "selection" end,
        doDrawItem = function(_, y, item) check("server row preserved", item == row); return y + 40 end }
    local view = { tabWidth = 160 }
    local screen = {
        getWidth = function() return 1280 end,
        getHeight = function() return 720 end,
        drawRect = function() calls[#calls + 1] = "paint" end,
        getChildren = panel.getChildren,
        backButton = { getY = function() return 680 end },
        tabs = { viewList = { view }, activeView = view, tabHeight = 32,
            getTabX = function() return 1 end, getWidth = function() return 800 end,
            getX = function() return 0 end, getY = function() return 0 end },
        rightPanel = {}, rightPanelInternal = {}, accountList = list, internetList = list,
        connectBtn = {},
    }
    MultiplayerUI.prerender(screen)
    check("multiplayer stock pre retained", calls[#calls] == "stock-pre")
    local wrapper = list.doDrawItem
    MultiplayerUI.prerender(screen)
    check("server row wrapper installed once", wrapper == list.doDrawItem)
    check("server row height retained", list:doDrawItem(10, row, false) == 50)
    MultiplayerUI.render(screen)
    check("multiplayer stock render retained", calls[#calls - 1] == "stock-render")
    check("connect action emphasized", screen.connectBtn.borderColor == MZUI.Theme.palette.accent)
    scope:dispose()
    check("multiplayer hooks restore", MultiplayerUI.prerender == originalPre and MultiplayerUI.render == originalRender)
else
    check("MultiplayerPresenter loaded", false)
end

if failures == 0 then return "OK" end
return "FAILED:" .. failures .. ":" .. table.concat(failedNames, ";")
