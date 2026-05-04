--[[
Dual-screen convenience library for LÖVE.

On Android with a secondary display (e.g. Ayn Thor), this drives the real
bottom screen via love.dualscreen (C++ module). On desktop, it provides a
simulated split-view in a single window for development and testing.

Usage:
  local ds = require("dualscreen")

  function love.load()
      ds.init()
      ds.bottomCanvas = love.graphics.newCanvas(ds.getWidth("bottom"), ds.getHeight("bottom"))
  end

  function love.draw()
      -- Draw to top screen (normal)
      love.graphics.print("Top", 100, 100)

      -- Draw to bottom screen
      ds.drawToBottom(function()
          love.graphics.print("Bottom", 50, 50)
      end)

      -- In desktop simulation mode, call this to render the preview
      ds.drawSimulation()
  end
--]]

local dualscreen = {}

-- Defaults for desktop simulation (Ayn Thor-like layout).
-- On Android these are ignored; actual device display metrics are used.
local DEFAULT_TOP = { width = 1920, height = 1080, refreshRate = 120 }
local DEFAULT_BOTTOM = { width = 1080, height = 1240, refreshRate = 60 }

local native = nil      -- love.dualscreen C++ module (nil on desktop)
local simulating = false
local initialized = false

local topInfo = {}
local bottomInfo = {}
local topCanvas = nil
local bottomCanvas = nil

-- Simulation state (desktop only)
local simScale = 1
local simGap = 10

local function isAndroid()
    return love.system and love.system.getOS() == "Android"
end

--- Initialize the dual-screen system.
-- On Android, this delegates to love.dualscreen.init().
-- On desktop, it sets up simulation mode with the given (or default) dimensions.
-- @param opts Optional table: { top = {width, height}, bottom = {width, height}, simScale = number }
-- @return true if secondary display is available (or simulated)
function dualscreen.init(opts)
    opts = opts or {}

    if initialized then
        return dualscreen.isAvailable()
    end

    if isAndroid() then
        local ok, mod = pcall(require, "love.dualscreen")
        if ok and mod then
            native = mod
            native.init()

            if native.isAvailable() then
                topInfo = native.getDisplayInfo("top")
                bottomInfo = native.getDisplayInfo("bottom")
                initialized = true
                simulating = false
                return true
            end
        end
    end

    -- Fallback: simulation mode
    simulating = true
    simScale = opts.simScale or 0.5

    local topDef = opts.top or DEFAULT_TOP
    local botDef = opts.bottom or DEFAULT_BOTTOM

    topInfo = {
        width = topDef.width,
        height = topDef.height,
        refreshRate = topDef.refreshRate or 120,
        available = true,
    }
    bottomInfo = {
        width = botDef.width,
        height = botDef.height,
        refreshRate = botDef.refreshRate or 60,
        available = true,
    }

    initialized = true
    return true
end

--- Check if dual-screen output is available.
function dualscreen.isAvailable()
    if native then
        return native.isAvailable()
    end
    return simulating
end

--- Check if we're running in desktop simulation mode.
function dualscreen.isSimulating()
    return simulating
end

--- Get the number of displays.
function dualscreen.getDisplayCount()
    if native then
        return native.getDisplayCount()
    end
    return simulating and 2 or 1
end

--- Get the width of a screen ("top" or "bottom").
function dualscreen.getWidth(screen)
    if screen == "bottom" then
        return bottomInfo.width or 0
    end
    return topInfo.width or 0
end

--- Get the height of a screen ("top" or "bottom").
function dualscreen.getHeight(screen)
    if screen == "bottom" then
        return bottomInfo.height or 0
    end
    return topInfo.height or 0
end

--- Get width and height of a screen.
function dualscreen.getDimensions(screen)
    return dualscreen.getWidth(screen), dualscreen.getHeight(screen)
end

--- Get full display info for a screen.
function dualscreen.getDisplayInfo(screen)
    if native then
        return native.getDisplayInfo(screen)
    end
    if screen == "bottom" then
        return bottomInfo
    end
    return topInfo
end

--- Get or create the top screen canvas (used in simulation mode).
function dualscreen.getTopCanvas()
    if topCanvas == nil then
        local w = dualscreen.getWidth("top")
        local h = dualscreen.getHeight("top")
        if w > 0 and h > 0 then
            topCanvas = love.graphics.newCanvas(w, h)
        end
    end
    return topCanvas
end

--- Draw to the top screen using a callback.
-- In simulation mode, this draws to an offscreen canvas.
-- On Android with a real secondary display, this draws to the backbuffer directly.
-- The callback receives the canvas width and height as arguments.
-- @param drawFunc function(width, height)
function dualscreen.drawToTop(drawFunc)
    if simulating then
        local canvas = dualscreen.getTopCanvas()
        if canvas == nil then return end

        local prevCanvas = love.graphics.getCanvas()
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 1)
        love.graphics.origin()

        local w, h = canvas:getDimensions()
        drawFunc(w, h)

        love.graphics.setCanvas(prevCanvas)
    else
        local w = dualscreen.getWidth("top")
        local h = dualscreen.getHeight("top")
        drawFunc(w, h)
    end
end

--- Get or create the bottom screen canvas.
function dualscreen.getBottomCanvas()
    if bottomCanvas == nil then
        local w = dualscreen.getWidth("bottom")
        local h = dualscreen.getHeight("bottom")
        if w > 0 and h > 0 then
            bottomCanvas = love.graphics.newCanvas(w, h)
        end
    end
    return bottomCanvas
end

--- Draw to the bottom screen using a callback.
-- The callback receives the canvas width and height as arguments.
-- @param drawFunc function(width, height) - your drawing code
function dualscreen.drawToBottom(drawFunc)
    local canvas = dualscreen.getBottomCanvas()
    if canvas == nil then return end

    local prevCanvas = love.graphics.getCanvas()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.origin()

    local w, h = canvas:getDimensions()
    drawFunc(w, h)

    love.graphics.setCanvas(prevCanvas)
end

--- Present the bottom canvas to the secondary display.
-- On Android, this blits the canvas texture to the physical screen.
-- On desktop in simulation mode, this is a no-op (use drawSimulation instead).
function dualscreen.present()
    if native and bottomCanvas then
        native.present(bottomCanvas)
    end
end

--- Get the auto-fit scale so both screens fit inside the window.
-- Returns the scale factor and the layout metrics.
function dualscreen.getSimLayout(layout)
    layout = layout or "vertical"
    local ww = love.graphics.getWidth()
    local wh = love.graphics.getHeight()
    local tw, th = topInfo.width, topInfo.height
    local bw, bh = bottomInfo.width, bottomInfo.height
    local padding = simGap

    local s
    if layout == "vertical" then
        local maxW = math.max(tw, bw)
        local totalH = th + bh + padding
        s = math.min(ww / maxW, wh / totalH)
    else
        local totalW = tw + bw + padding
        local maxH = math.max(th, bh)
        s = math.min(ww / totalW, wh / maxH)
    end

    return s, layout
end

--- (Desktop only) Draw a simulation preview of both screens in the window.
-- Draws the top screen content (from a canvas you provide or the backbuffer)
-- and the bottom canvas, auto-scaled to fit the window.
-- Call this at the end of love.draw().
-- @param layout "vertical" (default) or "horizontal"
function dualscreen.drawSimulation(layout)
    if not simulating then return end

    layout = layout or "vertical"
    local canvas = dualscreen.getBottomCanvas()
    if canvas == nil then return end

    local s = dualscreen.getSimLayout(layout)
    local ww = love.graphics.getWidth()
    local wh = love.graphics.getHeight()

    local tw = topInfo.width * s
    local th = topInfo.height * s
    local bw = bottomInfo.width * s
    local bh = bottomInfo.height * s

    local topC = dualscreen.getTopCanvas()

    love.graphics.clear(0.12, 0.12, 0.14, 1)

    if layout == "vertical" then
        local totalH = th + simGap + bh
        local yOff = (wh - totalH) / 2

        if topC then
            local tx = (ww - tw) / 2
            local ty = yOff
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(topC, tx, ty, 0, s, s)
            love.graphics.setColor(0.4, 0.4, 0.4, 1)
            love.graphics.rectangle("line", tx, ty, tw, th)
        end

        local bx = (ww - bw) / 2
        local by = yOff + th + simGap
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(canvas, bx, by, 0, s, s)
        love.graphics.setColor(0.4, 0.4, 0.4, 1)
        love.graphics.rectangle("line", bx, by, bw, bh)
    else
        local totalW = tw + simGap + bw
        local xOff = (ww - totalW) / 2

        if topC then
            local tx = xOff
            local ty = (wh - th) / 2
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(topC, tx, ty, 0, s, s)
            love.graphics.setColor(0.4, 0.4, 0.4, 1)
            love.graphics.rectangle("line", tx, ty, tw, th)
        end

        local bx = xOff + tw + simGap
        local by = (wh - bh) / 2
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(canvas, bx, by, 0, s, s)
        love.graphics.setColor(0.4, 0.4, 0.4, 1)
        love.graphics.rectangle("line", bx, by, bw, bh)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

--- Clean up resources.
function dualscreen.deinit()
    if native then
        native.deinit()
    end
    if topCanvas then
        topCanvas:release()
        topCanvas = nil
    end
    if bottomCanvas then
        bottomCanvas:release()
        bottomCanvas = nil
    end
    initialized = false
    simulating = false
    native = nil
end

return dualscreen

