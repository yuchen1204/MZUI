-- Multiplayer browser presentation. Stock geometry and callbacks own the
-- server/account lists, responsive detail panel and connection dialogs.
MZUI = MZUI or {}
local Theme = require "MZUI/Theme"
local Presenter = MZUI.MultiplayerPresenter or {}
MZUI.MultiplayerPresenter = Presenter

local function fill(ui, x, y, w, h, color)
    if w > 0 and h > 0 then
        ui:drawRect(x, y, w, h, color.a, color.r, color.g, color.b)
    end
end

local function skinControl(control)
    if not control then return end
    local p = Theme.palette
    local kind = control.Type
    if kind == "ISButton" or kind == "ISMPButton" or kind == "ISTextEntryBox" then
        control.backgroundColor = p.surfaceAlt
        control.backgroundColorMouseOver = p.surfaceActive
        control.borderColor = p.border
        control.borderColorMouseOver = p.accent
    elseif kind == "ISTickBox" then
        control.choicesColor = p.text
    end
end

local function skinChildren(panel)
    if not panel or not panel.getChildren then return end
    for _, child in pairs(panel:getChildren()) do skinControl(child) end
end

function Presenter.present(screen)
    if not screen.tabs or not screen.backButton then return end
    local p = Theme.palette
    -- Paint before children; never place an opaque fill over server rows.
    fill(screen, 0, 0, screen:getWidth(), screen:getHeight(), p.canvas)
    screen.borderColor = p.border
    screen.serverInfoBluePanelColor = p.surfaceAlt
    screen.serverInfoBlueTextColor = p.accent
    screen.serverInfoGrayTextColor = p.text
    screen.progressBarColor = p.accent
    local tabs = screen.tabs
    tabs.backgroundColor = p.surface
    tabs.backgroundColorSelected = p.surfaceAlt
    tabs.backgroundColorPanel = p.surface
    tabs.borderColor = p.border
    tabs.centerTabs = false
    for _, panel in ipairs({ screen.rightPanel, screen.rightPanelInternal }) do
        panel.backgroundColor = p.surface
        panel.borderColor = p.border
    end
    skinChildren(screen)
    skinChildren(screen.leftFavoritesPanel)
    skinChildren(screen.leftInternetPanel)
    -- Account action buttons may be rebuilt when a server is refreshed.
    skinChildren(screen.accountList)
    skinChildren(screen.internetList)
    for _, list in ipairs({ screen.accountList, screen.internetList }) do
        list.backgroundColor = p.surface
        list.borderColor = p.border
        if not list.mzuiDrawItem and list.doDrawItem then
            list.mzuiDrawItem = list.doDrawItem
            list.doDrawItem = function(self, y, item, alt)
                local nextY = self.mzuiDrawItem(self, y, item, alt)
                if self.selected == item.index then
                    fill(self, 0, y, 3, self.itemheight - 1, Theme.palette.accent)
                end
                return nextY
            end
        end
    end
    if screen.connectBtn then
        screen.connectBtn.backgroundColor = p.accentSoft
        screen.connectBtn.borderColor = p.accent
    end
    -- Footer uses the stock button positions so refresh cooldown, streaming
    -- privacy controls and controller navigation keep their existing bounds.
    local footerY = screen.backButton:getY() - 6
    fill(screen, 0, footerY, screen:getWidth(), screen:getHeight() - footerY, p.surface)
    fill(screen, 0, footerY, screen:getWidth(), 1, p.border)
end

function Presenter.drawSelection(screen)
    local tabs = screen.tabs
    if not tabs or not tabs.activeView then return end
    -- Match the tab panel's own hit-test coordinates, including scrolling.
    for i, view in ipairs(tabs.viewList) do
        if view == tabs.activeView then
            local width = tabs.equalTabWidth and tabs.maxLength or view.tabWidth
            local x = tabs:getTabX(i)
            if x >= 0 and x + width <= tabs:getWidth() then
                fill(screen, tabs:getX() + x, tabs:getY() + tabs.tabHeight - 3,
                    width, 3, Theme.palette.accent)
            end
            break
        end
    end
end

function Presenter.install(scope)
    if not MultiplayerUI then return end
    local stockPrerender = MultiplayerUI.prerender
    local stockRender = MultiplayerUI.render
    scope:patch(MultiplayerUI, "prerender", function(self, ...)
        Presenter.present(self)
        stockPrerender(self, ...)
    end)
    scope:patch(MultiplayerUI, "render", function(self, ...)
        stockRender(self, ...)
        Presenter.drawSelection(self)
    end)
end

return Presenter
