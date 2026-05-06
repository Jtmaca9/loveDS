-- Dual-Screen Feature Demo for LÖVE + Ayn Thor
-- Demonstrates all scale modes, split modes, touch, swap, layout toggle, and device presets.

local ds = require("dualscreen")

local SCALE_MODES = { "fit", "fill", "fit-width", "fit-height", "stretch", "none" }
local SPLIT_MODES = { "equal", "physical", 0.6 }
local SPLIT_LABELS = { "equal (50/50)", "physical (device AR)", "0.6 (60/40)" }
local LAYOUTS     = { "vertical", "horizontal" }

local scaleModeIdx = 4   -- start on "fit-height"
local splitIdx     = 1
local layoutIdx    = 1
local touches      = {}
local gamepad      = nil
local ball         = { x = 0, y = 0, vx = 180, vy = 120 }
local time         = 0

local function reinit()
    ds.deinit()
    local mode = SCALE_MODES[scaleModeIdx]
    local pOpts = { scaleMode = mode }

    if mode == "fit-height" then
        pOpts.targetHeight = 540
    elseif mode == "fit-width" then
        pOpts.targetWidth = 960
    else
        pOpts.targetWidth  = 960
        pOpts.targetHeight = 540
    end

    ds.init({
        device   = ds.PRESETS.AYN_THOR,
        primary  = pOpts,
        secondary = {
            targetWidth  = 540,
            targetHeight = 620,
            scaleMode    = "fit",
        },
        singleScreenMode   = "stacked",
        singleScreenLayout = LAYOUTS[layoutIdx],
        stackedSplit       = SPLIT_MODES[splitIdx],
    })

    local tw, th = ds.getTargetDimensions("primary")
    ball.x = tw / 2
    ball.y = th / 2
end

function love.load()
    love.graphics.setBackgroundColor(0.1, 0.1, 0.15)
    reinit()

    ds.setTouchCallbacks("secondary", {
        onPressed  = function(id, x, y, pressure) touches[id] = { x = x, y = y, p = pressure } end,
        onMoved    = function(id, x, y, pressure) if touches[id] then touches[id].x = x; touches[id].y = y; touches[id].p = pressure end end,
        onReleased = function(id) touches[id] = nil end,
    })

    ds.setTouchCallbacks("primary", {
        onPressed  = function(id, x, y) touches["pri_" .. tostring(id)] = { x = x, y = y, pri = true } end,
        onMoved    = function(id, x, y) local k = "pri_" .. tostring(id); if touches[k] then touches[k].x = x; touches[k].y = y end end,
        onReleased = function(id) touches["pri_" .. tostring(id)] = nil end,
    })

    local joysticks = love.joystick.getJoysticks()
    if #joysticks > 0 then gamepad = joysticks[1] end
end

function love.joystickadded(joystick)
    if not gamepad then gamepad = joystick end
end

function love.joystickremoved(joystick)
    if gamepad == joystick then
        gamepad = nil
        local joysticks = love.joystick.getJoysticks()
        if #joysticks > 0 then gamepad = joysticks[1] end
    end
end

function love.update(dt)
    ds.update()
    time = time + dt

    local tw, th = ds.getTargetDimensions("primary")
    ball.x = ball.x + ball.vx * dt
    ball.y = ball.y + ball.vy * dt
    if ball.x < 0 or ball.x > tw then ball.vx = -ball.vx; ball.x = math.max(0, math.min(tw, ball.x)) end
    if ball.y < 0 or ball.y > th then ball.vy = -ball.vy; ball.y = math.max(0, math.min(th, ball.y)) end
end

local function drawGrid(w, h, spacing, r, g, b)
    love.graphics.setColor(r, g, b, 0.15)
    for x = 0, w, spacing do
        love.graphics.line(x, 0, x, h)
    end
    for y = 0, h, spacing do
        love.graphics.line(0, y, w, y)
    end
end

local function drawCanvasBorder(w, h)
    love.graphics.setColor(1, 1, 0, 0.6)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 1, 1, w - 2, h - 2)
    love.graphics.setLineWidth(1)
end

function love.draw()
    ds.drawToPrimary(function(w, h)
        love.graphics.setColor(0.08, 0.08, 0.12)
        love.graphics.rectangle("fill", 0, 0, w, h)

        drawGrid(w, h, 100, 0.3, 0.5, 1.0)
        drawCanvasBorder(w, h)

        love.graphics.setColor(0.2, 0.7, 1.0, 0.8)
        love.graphics.circle("fill", ball.x, ball.y, 20)

        for id, t in pairs(touches) do
            if t.pri then
                love.graphics.setColor(1, 0.8, 0.2, 0.6)
                love.graphics.circle("line", t.x, t.y, 25)
                love.graphics.circle("fill", t.x, t.y, 5)
            end
        end

        local pw, ph = ds.getPhysicalDimensions("primary")
        local mode = SCALE_MODES[scaleModeIdx]
        local y = 10
        local function info(text)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(text, 10, y)
            y = y + 18
        end

        info("=== DUAL-SCREEN FEATURE DEMO ===")
        y = y + 4
        info(string.format("Scale Mode: %s", mode))
        info(string.format("Split: %s", SPLIT_LABELS[splitIdx]))
        info(string.format("Canvas: %dx%d   Physical: %dx%d", w, h, pw, ph))
        info(string.format("Layout: %s", LAYOUTS[layoutIdx]))
        info(string.format("Device: AYN_THOR | Displays: %d | Dual: %s | Swapped: %s",
            ds.getDisplayCount(), tostring(ds.isDualScreen()), tostring(ds.isSwapped())))
        info(string.format("Gamepad: %s", gamepad and gamepad:getName() or "none"))
        y = y + 8
        info("Controls:          Keyboard / Gamepad")
        info("  Cycle scale mode:   S / X")
        info("  Cycle split mode:   D / LB")
        info("  Toggle layout:      L / Y")
        info("  Swap screens:       Tab / Start")
        info("  Quit:               Esc / Back")

        if mode == "fit-height" then
            y = y + 8
            love.graphics.setColor(0.3, 1, 0.4)
            love.graphics.print(string.format("fit-height: locked h=%d, width auto=%d from %.2f:1 AR",
                540, w, pw / ph), 10, y)
        elseif mode == "fit-width" then
            y = y + 8
            love.graphics.setColor(0.3, 1, 0.4)
            love.graphics.print(string.format("fit-width: locked w=%d, height auto=%d from %.2f:1 AR",
                960, h, pw / ph), 10, y)
        end

        love.graphics.setColor(1, 1, 0, 0.5)
        love.graphics.print(string.format("canvas edge: %d,%d", w, h), w - 130, h - 20)
    end)

    ds.drawToSecondary(function(w, h)
        love.graphics.setColor(0.06, 0.06, 0.09)
        love.graphics.rectangle("fill", 0, 0, w, h)

        drawGrid(w, h, 50, 0.2, 0.4, 0.2)
        drawCanvasBorder(w, h)

        local tw, th = ds.getTargetDimensions("primary")
        local mapX = (ball.x / tw) * w
        local mapY = (ball.y / th) * h
        love.graphics.setColor(0.2, 0.7, 1.0, 0.7)
        love.graphics.circle("fill", mapX, mapY, 6)

        local touchCount = 0
        for id, t in pairs(touches) do
            if not t.pri then
                touchCount = touchCount + 1
                love.graphics.setColor(0.3, 1, 0.3, 0.8)
                love.graphics.circle("line", t.x, t.y, 30)
                love.graphics.circle("fill", t.x, t.y, 4)
                love.graphics.setColor(0.5, 1, 0.5, 0.5)
                love.graphics.print(string.format("%.0f,%.0f", t.x, t.y), t.x + 15, t.y - 8)
            end
        end

        local y = 10
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print("Secondary Screen", 10, y); y = y + 18
        love.graphics.print(string.format("Canvas: %dx%d | Mode: %s", w, h, ds.getScaleMode("secondary")), 10, y); y = y + 18
        love.graphics.print(string.format("Touches: %d", touchCount), 10, y); y = y + 18

        local pulse = 0.5 + 0.5 * math.sin(time * 3)
        love.graphics.setColor(0.4, 0.4, 0.4, pulse)
        love.graphics.print("tap / click here to test touch", w / 2 - 100, h / 2)
    end)

    ds.present()
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "tab" then
        ds.swapScreens()
    elseif key == "s" then
        scaleModeIdx = (scaleModeIdx % #SCALE_MODES) + 1
        reinit()
    elseif key == "d" then
        splitIdx = (splitIdx % #SPLIT_MODES) + 1
        reinit()
    elseif key == "l" then
        layoutIdx = (layoutIdx % #LAYOUTS) + 1
        reinit()
    end
end

function love.gamepadpressed(joystick, button)
    if button == "back" then
        love.event.quit()
    elseif button == "x" then
        scaleModeIdx = (scaleModeIdx % #SCALE_MODES) + 1
        reinit()
    elseif button == "leftshoulder" then
        splitIdx = (splitIdx % #SPLIT_MODES) + 1
        reinit()
    elseif button == "y" then
        layoutIdx = (layoutIdx % #LAYOUTS) + 1
        reinit()
    elseif button == "start" then
        ds.swapScreens()
    end
end

function love.quit()
    ds.deinit()
end
