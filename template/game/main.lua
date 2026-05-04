-- Dual-Screen Example for LÖVE + Ayn Thor
-- (Template game shipped with the dual-screen SDK)

local ds = require("dualscreen")

local player = { x = 400, y = 300, speed = 200 }
local touches = {}
local gamepad = nil
local DEADZONE = 0.25

function love.load()
    ds.init({
        simScale = 0.5,
    })

    love.graphics.setBackgroundColor(0.1, 0.1, 0.15)

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

    local tw, th = ds.getDimensions("top")
    player.x = player.x % tw
    player.y = player.y % th
end

function love.draw()
    ds.drawToTop(function(w, h)
        love.graphics.setColor(0.1, 0.1, 0.15)
        love.graphics.rectangle("fill", 0, 0, w, h)

        love.graphics.setColor(0.2, 0.6, 1.0)
        love.graphics.circle("fill", player.x, player.y, 30)

        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Top Screen - D-pad/stick or arrow keys to move", 10, 10)
        love.graphics.print(string.format("Player: %.0f, %.0f", player.x, player.y), 10, 30)
        love.graphics.print(string.format("Displays: %d | Available: %s | Simulating: %s",
            ds.getDisplayCount(),
            tostring(ds.isAvailable()),
            tostring(ds.isSimulating())), 10, 50)
        local ti = ds.getDisplayInfo("top")
        local bi = ds.getDisplayInfo("bottom")
        love.graphics.print(string.format("Top: %dx%d @ %.0fHz | Bottom: %dx%d @ %.0fHz",
            ti.width, ti.height, ti.refreshRate or 0,
            bi.width, bi.height, bi.refreshRate or 0), 10, 70)
        love.graphics.print(string.format("Gamepad: %s",
            gamepad and gamepad:getName() or "none"), 10, 90)
    end)

    ds.drawToBottom(function(w, h)
        love.graphics.setColor(0.05, 0.05, 0.1)
        love.graphics.rectangle("fill", 0, 0, w, h)

        love.graphics.setColor(0.15, 0.15, 0.2)
        for x = 0, w, 50 do
            love.graphics.line(x, 0, x, h)
        end
        for y = 0, h, 50 do
            love.graphics.line(0, y, w, y)
        end

        local tw, th = ds.getDimensions("top")
        local mapX = (player.x / tw) * w
        local mapY = (player.y / th) * h
        love.graphics.setColor(1, 0.3, 0.3)
        love.graphics.circle("fill", mapX, mapY, 8)

        love.graphics.setColor(0.3, 1, 0.3)
        for _, t in pairs(touches) do
            love.graphics.circle("line", t.x, t.y, 30)
        end

        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print("Bottom Screen - Map View", 10, 10)
        love.graphics.print(string.format("%dx%d", w, h), 10, 30)
    end)

    ds.present()
    ds.drawSimulation("vertical")
end

function love.touchpressed(id, x, y, dx, dy, pressure)
    touches[id] = { x = x, y = y }
end

function love.touchmoved(id, x, y, dx, dy, pressure)
    if touches[id] then
        touches[id].x = x
        touches[id].y = y
    end
end

function love.touchreleased(id, x, y, dx, dy, pressure)
    touches[id] = nil
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
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

