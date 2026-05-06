--[[
Dual-screen library for LÖVE.

On Android with a secondary display (e.g. Ayn Thor), renders to two
independent physical displays. On desktop or single-screen Android,
composites both screens into the window ("stacked") or shows only the
primary screen ("primary-only").

Usage:
  local ds = require("dualscreen")

  function love.load()
      ds.init({
          primary   = { targetHeight = 540, scaleMode = "fit-height" },
          secondary = { targetWidth = 540, targetHeight = 620, scaleMode = "fit" },
          singleScreenMode   = "stacked",   -- "stacked" | "primary-only"
          singleScreenLayout = "vertical",  -- "vertical" | "horizontal"
          primaryScreen      = "main",       -- "main" | "ext"
      })
  end

  function love.update(dt)
      ds.update()
  end

  function love.draw()
      ds.drawToPrimary(function(w, h)
          love.graphics.print("Primary", 10, 10)
      end)
      ds.drawToSecondary(function(w, h)
          love.graphics.print("Secondary", 10, 10)
      end)
      ds.present()
  end

  function love.quit()
      ds.deinit()
  end
--]]

local dualscreen = {}

---------------------------------------------------------------------------
-- Device presets (used as desktop fallback physical dimensions)
---------------------------------------------------------------------------

dualscreen.PRESETS = {
    AYN_THOR = {
        main = { width = 1920, height = 1080, refreshRate = 120 },
        ext  = { width = 1080, height = 1240, refreshRate = 60  },
    },
}

---------------------------------------------------------------------------
-- Defaults & constants
---------------------------------------------------------------------------

local DEFAULT_MAIN = dualscreen.PRESETS.AYN_THOR.main
local DEFAULT_EXT  = dualscreen.PRESETS.AYN_THOR.ext

local ACTION_DOWN         = 0
local ACTION_UP           = 1
local ACTION_MOVE         = 2
local ACTION_POINTER_DOWN = 5
local ACTION_POINTER_UP   = 6

---------------------------------------------------------------------------
-- Internal state
---------------------------------------------------------------------------

local native        = nil
local initialized   = false
local dualScreenMode = false
local contentSwapped = false

local config = {
    singleScreenMode   = "stacked",
    singleScreenLayout = "vertical",
    stackedSplit       = "equal",
    primaryScreen      = "main",
}

local slots = { primary = nil, secondary = nil }

local STACKED_GAP = 10

local prevWindowTouches = {}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function isAndroid()
    return love.system and love.system.getOS() == "Android"
end

local function newSlot(physicalScreen)
    return {
        physicalScreen = physicalScreen,
        targetWidth    = 0,
        targetHeight   = 0,
        physicalWidth  = 0,
        physicalHeight = 0,
        refreshRate    = 60,
        scaleMode      = "fit",
        anchor         = "center",
        canvas         = nil,
        touchCallbacks = nil,
        activeTouches  = {},
        drawX      = 0,
        drawY      = 0,
        drawScaleX = 1,
        drawScaleY = 1,
    }
end

local function computeDrawParams(canvasW, canvasH, surfaceW, surfaceH, scaleMode)
    if scaleMode == "stretch" then
        return 0, 0, surfaceW / canvasW, surfaceH / canvasH
    elseif scaleMode == "fill" then
        local s = math.max(surfaceW / canvasW, surfaceH / canvasH)
        return (surfaceW - canvasW * s) / 2,
               (surfaceH - canvasH * s) / 2,
               s, s
    elseif scaleMode == "fit-width" then
        local s = surfaceW / canvasW
        return 0,
               (surfaceH - canvasH * s) / 2,
               s, s
    elseif scaleMode == "fit-height" then
        local s = surfaceH / canvasH
        return (surfaceW - canvasW * s) / 2,
               0,
               s, s
    elseif scaleMode == "none" then
        return (surfaceW - canvasW) / 2,
               (surfaceH - canvasH) / 2,
               1, 1
    end
    -- "fit" (default)
    local s = math.min(surfaceW / canvasW, surfaceH / canvasH)
    return (surfaceW - canvasW * s) / 2,
           (surfaceH - canvasH * s) / 2,
           s, s
end

local function computeViewport(canvasW, canvasH, surfaceW, surfaceH, scaleMode)
    local x, y, sx, sy = computeDrawParams(canvasW, canvasH, surfaceW, surfaceH, scaleMode)
    return math.floor(x), math.floor(y),
           math.floor(canvasW * sx), math.floor(canvasH * sy)
end

local function resolveTargetDimensions(slotOpts, phys)
    local mode = slotOpts.scaleMode or "fit"
    local tw   = slotOpts.targetWidth
    local th   = slotOpts.targetHeight
    local ar   = phys.width / phys.height

    if mode == "fit-width" then
        tw = tw or phys.width
        th = th or math.floor(tw / ar + 0.5)
    elseif mode == "fit-height" then
        th = th or phys.height
        tw = tw or math.floor(th * ar + 0.5)
    else
        tw = tw or phys.width
        th = th or phys.height
    end

    return tw, th
end

local function getSlotForPhysical(physical)
    if slots.primary and slots.primary.physicalScreen == physical then
        return slots.primary
    end
    return slots.secondary
end

local function getSlotForLogical(logical)
    if logical == "primary" then
        return contentSwapped and slots.secondary or slots.primary
    end
    return contentSwapped and slots.primary or slots.secondary
end

local function drawToSlot(slot, drawFunc)
    if not slot or not slot.canvas then return end
    local prevCanvas = love.graphics.getCanvas()
    love.graphics.setCanvas(slot.canvas)
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.origin()
    local w, h = slot.canvas:getDimensions()
    drawFunc(w, h)
    love.graphics.setCanvas(prevCanvas)
end

---------------------------------------------------------------------------
-- Present helpers
---------------------------------------------------------------------------

local function presentDualScreen()
    local ww = love.graphics.getWidth()
    local wh = love.graphics.getHeight()

    local windowSlot  = getSlotForPhysical("main")
    local presentSlot = getSlotForPhysical("ext")

    if windowSlot and windowSlot.canvas then
        local x, y, sx, sy = computeDrawParams(
            windowSlot.targetWidth, windowSlot.targetHeight,
            ww, wh, windowSlot.scaleMode)
        windowSlot.drawX, windowSlot.drawY       = x, y
        windowSlot.drawScaleX, windowSlot.drawScaleY = sx, sy

        love.graphics.setCanvas()
        love.graphics.clear(0, 0, 0, 1)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(windowSlot.canvas, x, y, 0, sx, sy)
    end

    if presentSlot and presentSlot.canvas and native then
        local vpX, vpY, vpW, vpH = computeViewport(
            presentSlot.targetWidth, presentSlot.targetHeight,
            presentSlot.physicalWidth, presentSlot.physicalHeight,
            presentSlot.scaleMode)
        presentSlot.drawX, presentSlot.drawY = vpX, vpY
        presentSlot.drawScaleX = vpW / presentSlot.targetWidth
        presentSlot.drawScaleY = vpH / presentSlot.targetHeight

        native.present(presentSlot.canvas, vpX, vpY, vpW, vpH)
    end
end

local function drawSlotInSurface(slot, surfX, surfY, surfW, surfH)
    if not slot.canvas then return end
    local dx, dy, sx, sy = computeDrawParams(
        slot.targetWidth, slot.targetHeight,
        surfW, surfH, slot.scaleMode)
    slot.drawX, slot.drawY       = surfX + dx, surfY + dy
    slot.drawScaleX, slot.drawScaleY = sx, sy

    love.graphics.setScissor(surfX, surfY, surfW, surfH)
    love.graphics.draw(slot.canvas, slot.drawX, slot.drawY, 0, sx, sy)
    love.graphics.setScissor()

    love.graphics.setColor(0.4, 0.4, 0.4, 1)
    love.graphics.rectangle("line", surfX, surfY, surfW, surfH)
    love.graphics.setColor(1, 1, 1, 1)
end

local function computeSplitFraction()
    local split = config.stackedSplit
    if type(split) == "number" then
        return math.max(0.1, math.min(0.9, split))
    elseif split == "physical" then
        local ps = slots.primary
        local ss = slots.secondary
        if config.singleScreenLayout == "vertical" then
            return ps.physicalHeight / (ps.physicalHeight + ss.physicalHeight)
        else
            return ps.physicalWidth / (ps.physicalWidth + ss.physicalWidth)
        end
    end
    return 0.5
end

local function presentStacked()
    local ww = love.graphics.getWidth()
    local wh = love.graphics.getHeight()
    local ps = slots.primary
    local ss = slots.secondary
    local layout = config.singleScreenLayout
    local frac   = computeSplitFraction()

    love.graphics.setCanvas()
    love.graphics.clear(0.12, 0.12, 0.14, 1)
    love.graphics.setColor(1, 1, 1, 1)

    if layout == "vertical" then
        local available = wh - STACKED_GAP
        local priH = math.floor(available * frac)
        local secH = available - priH
        drawSlotInSurface(ps, 0, 0, ww, priH)
        drawSlotInSurface(ss, 0, priH + STACKED_GAP, ww, secH)
    else
        local available = ww - STACKED_GAP
        local priW = math.floor(available * frac)
        local secW = available - priW
        drawSlotInSurface(ps, 0, 0, priW, wh)
        drawSlotInSurface(ss, priW + STACKED_GAP, 0, secW, wh)
    end
end

local function presentPrimaryOnly()
    local ww = love.graphics.getWidth()
    local wh = love.graphics.getHeight()
    local visible = contentSwapped and slots.secondary or slots.primary

    if visible and visible.canvas then
        local x, y, sx, sy = computeDrawParams(
            visible.targetWidth, visible.targetHeight,
            ww, wh, visible.scaleMode)
        visible.drawX, visible.drawY             = x, y
        visible.drawScaleX, visible.drawScaleY   = sx, sy

        love.graphics.setCanvas()
        love.graphics.clear(0, 0, 0, 1)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(visible.canvas, x, y, 0, sx, sy)
    end
end

---------------------------------------------------------------------------
-- Touch helpers
---------------------------------------------------------------------------

local function windowToSlotCoords(slot, wx, wy)
    if not slot or not slot.canvas then return nil, nil end
    local cx = (wx - slot.drawX) / slot.drawScaleX
    local cy = (wy - slot.drawY) / slot.drawScaleY
    local tw, th = slot.canvas:getDimensions()
    if cx >= 0 and cx <= tw and cy >= 0 and cy <= th then
        return cx, cy
    end
    return nil, nil
end

local function dispatchTouch(slot, event, id, x, y, pressure)
    local cbs = slot.touchCallbacks
    if not cbs then return end
    if event == "pressed"  and cbs.onPressed  then cbs.onPressed(id, x, y, pressure)  end
    if event == "moved"    and cbs.onMoved    then cbs.onMoved(id, x, y, pressure)    end
    if event == "released" and cbs.onReleased then cbs.onReleased(id, x, y, pressure) end
end

local function resolveWindowTouch(x, y)
    if dualScreenMode then
        local mainSlot = getSlotForPhysical("main")
        local cx, cy = windowToSlotCoords(mainSlot, x, y)
        if cx then return mainSlot, cx, cy end
    elseif config.singleScreenMode == "stacked" then
        local cx, cy = windowToSlotCoords(slots.primary, x, y)
        if cx then return slots.primary, cx, cy end
        cx, cy = windowToSlotCoords(slots.secondary, x, y)
        if cx then return slots.secondary, cx, cy end
    else
        local visible = contentSwapped and slots.secondary or slots.primary
        local cx, cy = windowToSlotCoords(visible, x, y)
        if cx then return visible, cx, cy end
    end
    return nil
end

local function pollWindowTouches()
    local current = {}

    if love.touch then
        local ids = love.touch.getTouches()
        for _, id in ipairs(ids) do
            local x, y = love.touch.getPosition(id)
            local pressure = love.touch.getPressure(id)
            local slot, cx, cy = resolveWindowTouch(x, y)
            if slot then
                current[id] = { slot = slot, x = cx, y = cy, pressure = pressure }
            end
        end
    end

    if not isAndroid() and love.mouse and love.mouse.isDown(1) then
        local mx, my = love.mouse.getPosition()
        local slot, cx, cy = resolveWindowTouch(mx, my)
        if slot then
            current["mouse"] = { slot = slot, x = cx, y = cy, pressure = 1.0 }
        end
    end

    for id, t in pairs(current) do
        local prev = prevWindowTouches[id]
        if not prev then
            dispatchTouch(t.slot, "pressed", id, t.x, t.y, t.pressure)
        elseif prev.slot ~= t.slot then
            dispatchTouch(prev.slot, "released", id, prev.x, prev.y, prev.pressure)
            dispatchTouch(t.slot, "pressed", id, t.x, t.y, t.pressure)
        elseif prev.x ~= t.x or prev.y ~= t.y then
            dispatchTouch(t.slot, "moved", id, t.x, t.y, t.pressure)
        end
    end

    for id, t in pairs(prevWindowTouches) do
        if not current[id] then
            dispatchTouch(t.slot, "released", id, t.x, t.y, t.pressure)
        end
    end

    local priActive = {}
    local secActive = {}
    for id, t in pairs(current) do
        local entry = { x = t.x, y = t.y, pressure = t.pressure }
        if t.slot == slots.primary then
            priActive[id] = entry
        else
            secActive[id] = entry
        end
    end

    if dualScreenMode then
        slots.primary.activeTouches = priActive
    else
        slots.primary.activeTouches   = priActive
        slots.secondary.activeTouches = secActive
    end

    prevWindowTouches = current
end

local function pollNativeTouches()
    if not native or not native.pollTouchEvents then return end
    local events = native.pollTouchEvents()
    if not events or #events == 0 then return end

    local extSlot = getSlotForPhysical("ext")
    if not extSlot then return end

    for _, ev in ipairs(events) do
        local cx = (ev.x - extSlot.drawX) / extSlot.drawScaleX
        local cy = (ev.y - extSlot.drawY) / extSlot.drawScaleY

        if ev.action == ACTION_DOWN or ev.action == ACTION_POINTER_DOWN then
            extSlot.activeTouches[ev.id] = { x = cx, y = cy, pressure = ev.pressure }
            dispatchTouch(extSlot, "pressed", ev.id, cx, cy, ev.pressure)
        elseif ev.action == ACTION_MOVE then
            extSlot.activeTouches[ev.id] = { x = cx, y = cy, pressure = ev.pressure }
            dispatchTouch(extSlot, "moved", ev.id, cx, cy, ev.pressure)
        elseif ev.action == ACTION_UP or ev.action == ACTION_POINTER_UP then
            local prev = extSlot.activeTouches[ev.id]
            extSlot.activeTouches[ev.id] = nil
            if prev then
                dispatchTouch(extSlot, "released", ev.id, prev.x, prev.y, prev.pressure)
            else
                dispatchTouch(extSlot, "released", ev.id, cx, cy, ev.pressure)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Public API: lifecycle
---------------------------------------------------------------------------

function dualscreen.init(opts)
    opts = opts or {}
    if initialized then return true end

    config.singleScreenMode   = opts.singleScreenMode   or "stacked"
    config.singleScreenLayout = opts.singleScreenLayout or "vertical"
    config.stackedSplit       = opts.stackedSplit       or "equal"
    config.primaryScreen      = opts.primaryScreen      or "main"

    local device = opts.device
    local secondaryPhysical = config.primaryScreen == "main" and "ext" or "main"

    if isAndroid() then
        local ok, mod = pcall(require, "love.dualscreen")
        if ok and mod then
            native = mod
            native.init()
            dualScreenMode = native.isAvailable()
        end
    end

    local mainPhys, extPhys
    if native then
        mainPhys = native.getDisplayInfo("main")
        extPhys  = native.getDisplayInfo("ext")
    elseif device then
        mainPhys = { width = device.main.width, height = device.main.height, refreshRate = device.main.refreshRate or 60 }
        extPhys  = { width = device.ext.width,  height = device.ext.height,  refreshRate = device.ext.refreshRate  or 60 }
    else
        mainPhys = { width = DEFAULT_MAIN.width, height = DEFAULT_MAIN.height, refreshRate = DEFAULT_MAIN.refreshRate }
        extPhys  = { width = DEFAULT_EXT.width,  height = DEFAULT_EXT.height,  refreshRate = DEFAULT_EXT.refreshRate  }
    end

    local primaryPhys   = config.primaryScreen == "main" and mainPhys or extPhys
    local secondaryPhys = config.primaryScreen == "main" and extPhys  or mainPhys

    local pOpts = opts.primary   or {}
    local sOpts = opts.secondary or {}

    slots.primary = newSlot(config.primaryScreen)
    slots.primary.physicalWidth  = primaryPhys.width
    slots.primary.physicalHeight = primaryPhys.height
    slots.primary.refreshRate    = primaryPhys.refreshRate or 60
    slots.primary.scaleMode      = pOpts.scaleMode or "fit"
    slots.primary.anchor         = pOpts.anchor    or "center"
    slots.primary.targetWidth, slots.primary.targetHeight =
        resolveTargetDimensions(pOpts, primaryPhys)

    slots.secondary = newSlot(secondaryPhysical)
    slots.secondary.physicalWidth  = secondaryPhys.width
    slots.secondary.physicalHeight = secondaryPhys.height
    slots.secondary.refreshRate    = secondaryPhys.refreshRate or 60
    slots.secondary.scaleMode      = sOpts.scaleMode or "fit"
    slots.secondary.anchor         = sOpts.anchor    or "center"
    slots.secondary.targetWidth, slots.secondary.targetHeight =
        resolveTargetDimensions(sOpts, secondaryPhys)

    if slots.primary.targetWidth > 0 and slots.primary.targetHeight > 0 then
        slots.primary.canvas = love.graphics.newCanvas(
            slots.primary.targetWidth, slots.primary.targetHeight)
    end
    if slots.secondary.targetWidth > 0 and slots.secondary.targetHeight > 0 then
        slots.secondary.canvas = love.graphics.newCanvas(
            slots.secondary.targetWidth, slots.secondary.targetHeight)
    end

    initialized    = true
    contentSwapped = false
    prevWindowTouches = {}
    return true
end

function dualscreen.update()
    if not initialized then return end
    pollWindowTouches()
    pollNativeTouches()
end

function dualscreen.present()
    if not initialized then return end
    if dualScreenMode then
        presentDualScreen()
    elseif config.singleScreenMode == "stacked" then
        presentStacked()
    else
        presentPrimaryOnly()
    end
end

function dualscreen.deinit()
    if native then native.deinit() end
    if slots.primary   and slots.primary.canvas   then slots.primary.canvas:release()   end
    if slots.secondary and slots.secondary.canvas then slots.secondary.canvas:release() end
    slots.primary   = nil
    slots.secondary = nil
    initialized      = false
    dualScreenMode   = false
    contentSwapped   = false
    native           = nil
    prevWindowTouches = {}
end

---------------------------------------------------------------------------
-- Public API: drawing
---------------------------------------------------------------------------

function dualscreen.drawToPrimary(drawFunc)
    drawToSlot(getSlotForLogical("primary"), drawFunc)
end

function dualscreen.drawToSecondary(drawFunc)
    drawToSlot(getSlotForLogical("secondary"), drawFunc)
end

function dualscreen.drawToMain(drawFunc)
    drawToSlot(getSlotForPhysical("main"), drawFunc)
end

function dualscreen.drawToExt(drawFunc)
    drawToSlot(getSlotForPhysical("ext"), drawFunc)
end

---------------------------------------------------------------------------
-- Public API: content swap
---------------------------------------------------------------------------

function dualscreen.swapScreens()
    contentSwapped = not contentSwapped
end

function dualscreen.isSwapped()
    return contentSwapped
end

---------------------------------------------------------------------------
-- Public API: touch
---------------------------------------------------------------------------

function dualscreen.setTouchCallbacks(slotName, callbacks)
    if not slots[slotName] then return end
    slots[slotName].touchCallbacks = callbacks
end

function dualscreen.getTouches(slotName)
    if not slots[slotName] then return {} end
    return slots[slotName].activeTouches
end

---------------------------------------------------------------------------
-- Public API: queries
---------------------------------------------------------------------------

function dualscreen.isDualScreen()
    return dualScreenMode
end

function dualscreen.isSingleScreen()
    return not dualScreenMode
end

function dualscreen.isAvailable()
    return initialized
end

function dualscreen.getSingleScreenMode()
    return config.singleScreenMode
end

function dualscreen.getStackedSplit()
    return config.stackedSplit
end

function dualscreen.getDisplayCount()
    if native then return native.getDisplayCount() end
    return dualScreenMode and 2 or 1
end

function dualscreen.getPrimaryScreen()
    return config.primaryScreen
end

function dualscreen.getSecondaryScreen()
    return config.primaryScreen == "main" and "ext" or "main"
end

function dualscreen.getScaleMode(screen)
    if screen == "primary"   then return slots.primary.scaleMode   end
    if screen == "secondary" then return slots.secondary.scaleMode end
    return getSlotForPhysical(screen or "main").scaleMode
end

function dualscreen.getTargetDimensions(screen)
    local slot
    if     screen == "primary"   then slot = slots.primary
    elseif screen == "secondary" then slot = slots.secondary
    else   slot = getSlotForPhysical(screen or "main") end
    return slot.targetWidth, slot.targetHeight
end

function dualscreen.getPhysicalDimensions(screen)
    local slot
    if     screen == "primary"   then slot = slots.primary
    elseif screen == "secondary" then slot = slots.secondary
    else   slot = getSlotForPhysical(screen or "main") end
    return slot.physicalWidth, slot.physicalHeight
end

function dualscreen.getWidth(screen)
    return getSlotForPhysical(screen or "main").targetWidth
end

function dualscreen.getHeight(screen)
    return getSlotForPhysical(screen or "main").targetHeight
end

function dualscreen.getDimensions(screen)
    local slot = getSlotForPhysical(screen or "main")
    return slot.targetWidth, slot.targetHeight
end

function dualscreen.getDisplayInfo(screen)
    if native then return native.getDisplayInfo(screen or "main") end
    local slot = getSlotForPhysical(screen or "main")
    return {
        width       = slot.physicalWidth,
        height      = slot.physicalHeight,
        refreshRate = slot.refreshRate,
        available   = true,
    }
end

---------------------------------------------------------------------------
-- Public API: coordinate mapping
---------------------------------------------------------------------------

function dualscreen.screenToCanvas(screen, physX, physY)
    local slot
    if     screen == "primary"   then slot = slots.primary
    elseif screen == "secondary" then slot = slots.secondary
    else   slot = getSlotForPhysical(screen) end
    return (physX - slot.drawX) / slot.drawScaleX,
           (physY - slot.drawY) / slot.drawScaleY
end

function dualscreen.canvasToScreen(screen, canvasX, canvasY)
    local slot
    if     screen == "primary"   then slot = slots.primary
    elseif screen == "secondary" then slot = slots.secondary
    else   slot = getSlotForPhysical(screen) end
    return canvasX * slot.drawScaleX + slot.drawX,
           canvasY * slot.drawScaleY + slot.drawY
end

return dualscreen
