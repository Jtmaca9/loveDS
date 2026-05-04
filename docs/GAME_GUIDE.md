# Game Guide — Lua API

Games use the `dualscreen.lua` library, which drives the real secondary display on Android (via `love.dualscreen`) and simulates dual-screen on desktop.

## Minimal Pattern

```lua
local ds = require("dualscreen")

function love.load()
  ds.init({ simScale = 0.5 })
end

function love.draw()
  ds.drawToTop(function(w, h)
    love.graphics.print("Top", 10, 10)
  end)

  ds.drawToBottom(function(w, h)
    love.graphics.print("Bottom", 10, 10)
  end)

  -- Android: blit bottom canvas to the physical second display
  ds.present()

  -- Desktop: draw both canvases into the window for preview
  ds.drawSimulation("vertical")
end

function love.quit()
  ds.deinit()
end
```

## API Reference

| Function | Description |
|---|---|
| `ds.init(opts)` | Initialize dual-screen (real on Android, simulated on desktop). Options: `{ simScale, top = {width, height}, bottom = {width, height} }` |
| `ds.isAvailable()` | `true` when the secondary output is active (or simulated) |
| `ds.isSimulating()` | `true` on desktop simulation |
| `ds.getDisplayCount()` | Returns `1` or `2` |
| `ds.getDimensions("top"\|"bottom")` | Returns `width, height` for the given screen |
| `ds.getDisplayInfo("top"\|"bottom")` | Returns `{ width, height, refreshRate, available }` |
| `ds.drawToTop(fn)` | Draw into the top screen. Callback receives `(width, height)` |
| `ds.drawToBottom(fn)` | Draw into the bottom screen. Callback receives `(width, height)` |
| `ds.present()` | Android-only — blit the bottom canvas to the physical second display |
| `ds.drawSimulation(layout)` | Desktop-only — render both screens in the window. Layout: `"vertical"` (default) or `"horizontal"` |
| `ds.deinit()` | Clean up resources. Call from `love.quit()` |

## Notes

- The bottom screen is presented via a dedicated Android `Presentation` surface and a shared EGL context.
- SDL only manages the primary window; the secondary display bypasses SDL on Android.
- On desktop, both screens are drawn to offscreen canvases and composited into the window by `drawSimulation()`.
- The default simulated display sizes match the Ayn Thor: 1920x1080 (top) and 1080x1240 (bottom).
