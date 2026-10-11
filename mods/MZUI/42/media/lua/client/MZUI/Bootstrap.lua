-- Title + pause (MainScreen) and settings (MainOptions) presentation.
-- MainScreen.prerender is patched exactly once here: the wrapper dispatches
-- to the right presenter by screen.inGame, then to OptionsPresenter.install
-- separately on its own MainOptions patch. installed flips only after every
-- presenter hooked up; a half-install retries on OnMainMenuEnter.
MZUI = MZUI or {}
local Hook = require "MZUI/Hook"
local Theme = require "MZUI/Theme"
local Draw = require "MZUI/Draw"
local Snapshot = require "MZUI/Snapshot"

local MainMenuPresenter = require "MZUI/screens/MainMenuPresenter"
local PausePresenter = require "MZUI/screens/PausePresenter"
local OptionsPresenter = require "MZUI/screens/OptionsPresenter"
local MultiplayerPresenter = require "MZUI/screens/MultiplayerPresenter"

-- Shared across file reloads: a reloadLuaFile replaces the chunk locals but
-- keeps this table (and the pre-reload listener closure) alive, so the
-- install-on-next-menu-entry flow survives even when the fresh chunk's event
-- adds were suppressed by the reloader.
local Boot = MZUI.Boot or {}
MZUI.Boot = Boot
Boot.scope = Boot.scope or nil
Boot.failedPrint = Boot.failedPrint or false

local function installMainScreen(scope)
    local stockPrerender = MainScreen.prerender
    scope:patch(MainScreen, "prerender", function(self, ...)
        stockPrerender(self, ...)
        if self.inGame then
            PausePresenter.layout(self)
        else
            MainMenuPresenter.layout(self)
        end
    end)
    -- Vanilla's render re-stacks four pause items after paint; correct them
    -- back onto the band so hits match the drawn cards (multiplayer pause).
    if MainScreen.render ~= nil then
        local stockRender = MainScreen.render
        scope:patch(MainScreen, "render", function(self, ...)
            stockRender(self, ...)
            MainMenuPresenter.reapply(self)
        end)
    end
end

local function installAll()
    local scope = Hook.new()
    local ok = pcall(installMainScreen, scope)
    if not ok then
        scope:dispose()
        return false
    end
    ok = pcall(OptionsPresenter.install, scope)
    if not ok then
        scope:dispose()
        return false
    end
    ok = pcall(MultiplayerPresenter.install, scope)
    if not ok then
        scope:dispose()
        return false
    end
    Boot.scope = scope
    return true
end

-- Idempotent and self-healing: healthy presentation = a live scope with our
-- prerender wrapper in place. Anything else (first boot, a reloadLuaFile
-- teardown, a half-failed install) retries here; callers register this on
-- OnGameBoot + OnMainMenuEnter + OnGameStart. A save can reset Lua before
-- entering the world, without another boot or main-menu event.
function Boot.install()
    if MainScreen == nil or MainScreen.prerender == nil then return end
    local scope = Boot.scope
    if scope ~= nil and not scope:isDisposed()
            and Hook.isWrapped(MainScreen, "prerender") then
        return
    end
    if scope ~= nil and not scope:isDisposed() then
        scope:dispose()
    end
    if not installAll() then
        if not Boot.failedPrint then
            Boot.failedPrint = true
            print("[MZUI] install failed; will retry on next menu entry")
        end
        return
    end
    Boot.failedPrint = false
    print("[MZUI] main menu, settings and multiplayer presentation enabled")
end

if Events and type(Events.OnGameBoot) == "table" then
    Events.OnGameBoot.Add(Boot.install)
end
if Events and type(Events.OnMainMenuEnter) == "table" then
    Events.OnMainMenuEnter.Add(Boot.install)
end
if Events and type(Events.OnGameStart) == "table" then
    Events.OnGameStart.Add(Boot.install)
end
