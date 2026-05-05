# Game Guide — Lua API

Games use the `dualscreen.lua` library, which drives the real secondary display on Android (via `love.dualscreen`) and composites both screens into a single window on desktop or single-screen devices.

## Minimal Pattern

```lua
local ds = require("dualscreen")

function love.load()
    ds.init()
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
```

## Configuration

Pass an options table to `ds.init()` for full control:

```lua
ds.init({
    primary = {
        targetWidth  = 960,
        targetHeight = 540,
        scaleMode    = "fit",    -- "fit" | "fill" | "fit-width" | "fit-height" | "stretch" | "none"
    },
    secondary = {
        targetWidth  = 540,
        targetHeight = 620,
        scaleMode    = "fit",
    },
    singleScreenMode   = "stacked",   -- "stacked" | "primary-only"
    singleScreenLayout = "vertical",  -- "vertical" | "horizontal"
    primaryScreen      = "main",      -- "main" | "ext"
})
```

### Scale modes

| Mode | Behaviour |
|---|---|
| `"fit"` | Uniform scale, letterbox/pillarbox to preserve aspect ratio |
| `"fill"` | Uniform scale, crop to fill (no bars, content may clip) |
| `"fit-width"` | Uniform scale locked to width. Height may overflow or be pillarboxed. If `targetHeight` is omitted, it is auto-computed from the physical aspect ratio. |
| `"fit-height"` | Uniform scale locked to height. Width may overflow or be pillarboxed. If `targetWidth` is omitted, it is auto-computed from the physical aspect ratio. |
| `"stretch"` | Non-uniform scale, fills entire display (may distort) |
| `"none"` | 1:1 pixel rendering, centered, no scaling |

#### Auto-computed dimensions

With `fit-width` or `fit-height`, you can omit the non-locked target dimension and the library will derive it from the physical display's aspect ratio:

```lua
primary = {
    targetHeight = 540,       -- lock the height
    scaleMode    = "fit-height", -- width auto-computed from physical aspect ratio
},
```

On the Ayn Thor main display (1920x1080 physical), this would produce a canvas of 960x540. You can still provide both dimensions explicitly if you want a specific virtual resolution that doesn't match the physical aspect ratio.

### Single-screen modes

When only one display is available (desktop, single-screen Android):

| Mode | Behaviour |
|---|---|
| `"stacked"` (default) | Both screens composited into the window |
| `"primary-only"` | Only the primary screen is shown; secondary still renders to a hidden canvas |

In `"primary-only"` mode, call `ds.swapScreens()` to swap which content is visible.

### Primary screen mapping

`primaryScreen` controls which physical display is the primary slot. Defaults to `"main"` (the device's default/built-in display). Set to `"ext"` if the external display should be the primary gameplay display.

## API Reference

### Lifecycle

| Function | Description |
|---|---|
| `ds.init(opts)` | Initialize. Options described above. Omit for defaults. |
| `ds.update()` | Call from `love.update(dt)`. Polls touch events. |
| `ds.present()` | Call at the end of `love.draw()`. Handles all display modes automatically. |
| `ds.deinit()` | Clean up. Call from `love.quit()`. |

### Drawing

| Function | Description |
|---|---|
| `ds.drawToPrimary(fn)` | Draw into the primary display slot. `fn` receives `(width, height)`. |
| `ds.drawToSecondary(fn)` | Draw into the secondary display slot. `fn` receives `(width, height)`. |
| `ds.drawToMain(fn)` | Draw to the main (default) display (bypasses content swap). |
| `ds.drawToExt(fn)` | Draw to the external display (bypasses content swap). |

### Content Swap

| Function | Description |
|---|---|
| `ds.swapScreens()` | Swap which draw callback content is routed to which display slot. Slot configs and touch handlers stay fixed. |
| `ds.isSwapped()` | Returns `true` if content is currently swapped. |

When swapped, `drawToPrimary(fn)` renders `fn` onto the secondary slot's canvas (at the secondary's target resolution), and vice versa. In `"primary-only"` single-screen mode, swapping changes which canvas is visible.

### Touch

| Function | Description |
|---|---|
| `ds.setTouchCallbacks(slot, cbs)` | Register touch handlers for `"primary"` or `"secondary"` slot. |
| `ds.getTouches(slot)` | Returns `{ [id] = {x, y, pressure} }` for the given slot. |

Touch callbacks table:

```lua
ds.setTouchCallbacks("secondary", {
    onPressed  = function(id, x, y, pressure) end,
    onMoved    = function(id, x, y, pressure) end,
    onReleased = function(id, x, y, pressure) end,
})
```

- Coordinates are in the **slot's canvas target resolution**, not physical pixels.
- Callbacks are bound to the **display slot**, not the content. They remain stable across `swapScreens()`.
- On desktop, mouse clicks are mapped as touch events with `id = "mouse"`.
- In stacked mode, clicks/touches are hit-tested against both screen regions.

### Display State

| Function | Description |
|---|---|
| `ds.isDualScreen()` | `true` when two physical displays are active. |
| `ds.isSingleScreen()` | `true` when running with one display. |
| `ds.isAvailable()` | `true` after `init()` completes. |
| `ds.getDisplayCount()` | Returns `1` or `2`. |
| `ds.getSingleScreenMode()` | Returns `"stacked"` or `"primary-only"`. |
| `ds.getPrimaryScreen()` | Returns `"main"` or `"ext"`. |
| `ds.getSecondaryScreen()` | Returns `"main"` or `"ext"` (opposite of primary). |

### Screen Config Queries

| Function | Description |
|---|---|
| `ds.getScaleMode(screen)` | Returns scale mode. `screen`: `"primary"`, `"secondary"`, `"main"`, or `"ext"`. |
| `ds.getTargetDimensions(screen)` | Returns `width, height` of the canvas (target resolution). |
| `ds.getPhysicalDimensions(screen)` | Returns `width, height` of the physical display. |

### Backward-Compatible Queries

| Function | Description |
|---|---|
| `ds.getWidth(screen)` | Target width for `"main"` or `"ext"`. |
| `ds.getHeight(screen)` | Target height for `"main"` or `"ext"`. |
| `ds.getDimensions(screen)` | Returns `width, height` for `"main"` or `"ext"`. |
| `ds.getDisplayInfo(screen)` | Returns `{ width, height, refreshRate, available }`. |

### Coordinate Mapping

| Function | Description |
|---|---|
| `ds.screenToCanvas(screen, physX, physY)` | Convert screen/window coords to canvas coords. |
| `ds.canvasToScreen(screen, canvasX, canvasY)` | Convert canvas coords to screen/window coords. |

## Notes

- The secondary display is presented via a dedicated Android `Presentation` surface and a shared EGL context.
- SDL only manages the primary window; the secondary display bypasses SDL on Android.
- Both screens always render to offscreen canvases. `present()` blits them to the appropriate surfaces.
- Default display sizes for desktop preview match the Ayn Thor: 1920x1080 (main) and 1080x1240 (ext).
- On desktop, the library defaults to single-screen stacked mode. No separate "simulation" call is needed.
