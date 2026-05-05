-- Dual-Screen Example for LÖVE + Ayn Thor
-- (Template game shipped with the dual-screen SDK)

local ds = require("dualscreen")

local player = { x = 400, y = 300, speed = 200 }
local touches = {}
local gamepad = nil
local DEADZONE = 0.25

function love.load()
    ds.init({
        primary = {
            targetWidth  = 960,
            targetHeight = 540,
            scaleMode    = "fit",
        },
        secondary = {
            targetWidth  = 540,
            targetHeight = 620,
            scaleMode    = "fit",
        },
        singleScreenMode   = "stacked",
        singleScreenLayout = "vertical",
    })

    love.graphics.setBackgroundColor(0.1, 0.1, 0.15)

    ds.setTouchCallbacks("secondary", {
        onPressed = function(id, x, y, pressure)
            touches[id] = { x = x, y = y }
        end,
        onMoved = function(id, x, y, pressure)
            if touches[id] then
                touches[id].x = x
                touches[id].y = y
            end
        end,
        onReleased = function(id, x, y, pressure)
            touches[id] = nil
        end,
    })

    local joysticks = love.joystick.getJoysticks()
    if #joysticks > 0 then
        gamepad = joysticks[1]
    end
end

function love.joystickadded(joystick)
    if gamepad == nil then
        gamepad = joystick
    end
end

function love.joystickremoved(joystick)
    if gamepad == joystick then
        gamepad = nil
        local joysticks = love.joystick.getJoysticks()
        if #joysticks > 0 then
            gamepad = joysticks[1]
        end
    end
end

function love.update(dt)
    ds.update()

    local dx, dy = 0, 0

    if love.keyboard.isDown("left")  then dx = dx - 1 end
    if love.keyboard.isDown("right") then dx = dx + 1 end
    if love.keyboard.isDown("up")    then dy = dy - 1 end
    if love.keyboard.isDown("down")  then dy = dy + 1 end

    if gamepad and gamepad:isConnected() then
        if gamepad:isGamepadDown("dpleft")  then dx = dx - 1 end
        if gamepad:isGamepadDown("dpright") then dx = dx + 1 end
        if gamepad:isGamepadDown("dpup")    then dy = dy - 1 end
        if gamepad:isGamepadDown("dpdown")  then dy = dy + 1 end

        local lx = gamepad:getGamepadAxis("leftx")
        local ly = gamepad:getGamepadAxis("lefty")
        if math.abs(lx) > DEADZONE then dx = dx + lx end
        if math.abs(ly) > DEADZONE then dy = dy + ly end
    end

    local len = math.sqrt(dx * dx + dy * dy)
    if len > 1 then
        dx, dy = dx / len, dy / len
    end

    player.x = player.x + dx * player.speed * dt
    player.y = player.y + dy * player.speed * dt

    local tw, th = ds.getTargetDimensions("primary")
    player.x = player.x % tw
    player.y = player.y % th
end

function love.draw()
    ds.drawToPrimary(function(w, h)
        love.graphics.setColor(0.1, 0.1, 0.15)
        love.graphics.rectangle("fill", 0, 0, w, h)

        love.graphics.setColor(0.2, 0.6, 1.0)
        love.graphics.circle("fill", player.x, player.y, 30)

        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Primary Screen - D-pad/stick or arrow keys to move", 10, 10)
        love.graphics.print(string.format("Player: %.0f, %.0f", player.x, player.y), 10, 30)
        love.graphics.print(string.format("Displays: %d | Dual: %s | Swapped: %s",
            ds.getDisplayCount(),
            tostring(ds.isDualScreen()),
            tostring(ds.isSwapped())), 10, 50)
        love.graphics.print(string.format("Gamepad: %s",
            gamepad and gamepad:getName() or "none"), 10, 70)
    end)

    ds.drawToSecondary(function(w, h)
        love.graphics.setColor(0.05, 0.05, 0.1)
        love.graphics.rectangle("fill", 0, 0, w, h)

        love.graphics.setColor(0.15, 0.15, 0.2)
        for x = 0, w, 50 do
            love.graphics.line(x, 0, x, h)
        end
        for y = 0, h, 50 do
            love.graphics.line(0, y, w, y)
        end

        local tw, th = ds.getTargetDimensions("primary")
        local mapX = (player.x / tw) * w
        local mapY = (player.y / th) * h
        love.graphics.setColor(1, 0.3, 0.3)
        love.graphics.circle("fill", mapX, mapY, 8)

        love.graphics.setColor(0.3, 1, 0.3)
        for _, t in pairs(touches) do
            love.graphics.circle("line", t.x, t.y, 30)
        end

        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print("Secondary Screen - Map View", 10, 10)
        love.graphics.print(string.format("%dx%d", w, h), 10, 30)
    end)

    ds.present()
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "tab" then
        ds.swapScreens()
    end
end

function love.gamepadpressed(joystick, button)
    if button == "back" then
        love.event.quit()
    end
end

function love.quit()
    ds.deinit()
end
