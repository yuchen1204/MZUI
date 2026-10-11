MZUI = MZUI or {}

-- Pure token table, hex-driven. All values 0..1 floats for the draw API.
-- Kept in shared/ so headless Kahlua tests and client code load the same file.
local function hex(s)
    local n = tonumber(string.sub(s, 2), 16)
    if not n then return 0, 0, 0, 1 end
    return
        math.floor(n / 0x10000) % 0x100 / 255,
        math.floor(n / 0x100) % 0x100 / 255,
        n % 0x100 / 255,
        1
end

local function token(t)
    local r, g, b = hex(t)
    return { r = r, g = g, b = b, a = 1 }
end

local function alpha(t, a)
    local r, g, b = hex(t)
    return { r = r, g = g, b = b, a = a }
end

local Theme = MZUI.Theme or {}
MZUI.Theme = Theme

-- GitHub-dark inspired cool grey-blue, flat, high contrast.
Theme.palette = {
    canvas        = "#0D1117",  -- screen backdrop (menu only, translucent in game)
    surface       = "#161B22",  -- cards, panels
    surfaceAlt    = "#21262D",  -- hover rows, secondary surfaces
    surfaceActive = "#2F3742",  -- pressed / selected surface
    border        = "#30363D",
    borderBright  = "#8B949E",
    text          = "#E6EDF3",
    textDim       = "#8B949E",
    textFaint     = "#6E7681",
    accent        = "#58A6FF",
    accentSoft    = alpha("#58A6FF", 0.15),
    success       = "#3FB950",
    warning       = "#D29922",
    danger        = "#F85149",
}

-- rgba() leftovers resolved once; consumers read .r/.g/.b/.a only.
for _, name in ipairs({ "canvas", "surface", "surfaceAlt", "surfaceActive",
    "border", "borderBright", "text", "textDim", "textFaint",
    "accent", "success", "warning", "danger" }) do
    if type(Theme.palette[name]) == "string" then
        Theme.palette[name] = token(Theme.palette[name])
    end
end
-- Slightly transparent canvas for fullscreen settings opened from the pause
-- menu (game visible behind).
Theme.palette.inGameCanvas = alpha("#0D1117", 0.86)
-- Menu-button states: idle fully transparent, hover a muted grey veil.
Theme.palette.menuIdle = { r = 0, g = 0, b = 0, a = 0 }
Theme.palette.menuHover = alpha("#2A3240", 0.66)

-- Layout constants. Heights derive from font metrics at require time.
Theme.spacing = { xs = 4, sm = 8, md = 12, lg = 20, xl = 32 }
Theme.radius = 0        -- flat; corners are square
Theme.cardHoverLift = 0 -- flat design: no offset movement, color only

-- Menu buttons are transparent at rest; hovering fills a quiet grey so the
-- label stays readable over the animated scene. Rows and cards elsewhere
-- (settings body etc.) still read from the opaque palette entries.
function Theme.cardColor(state)
    if state == "hover" then return Theme.palette.menuHover end
    if state == "selected" then return Theme.palette.menuHover end
    return Theme.palette.menuIdle
end

-- Selection/focus indicator: 3px accent bar on the left edge of a row/card.
Theme.focusBarWidth = 3

return Theme
