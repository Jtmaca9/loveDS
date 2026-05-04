## Game Guide (Lua API)

Games use the Lua helper `dualscreen.lua`, which drives the real secondary display on Android (via `love.dualscreen`) and simulates dual-screen on desktop.

### Minimal pattern

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

  -- Android: blit bottom canvas to the physical second display.
  ds.present()

  -- Desktop: draw both canvases into the window for preview.
  ds.drawSimulation("vertical")
end

function love.quit()
  ds.deinit()
end
```

### API summary

- `ds.init(opts)` : initialize dual-screen (real on Android, simulated on desktop)\n+- `ds.isAvailable()` : `true` when the secondary output is active (or simulated)\n+- `ds.isSimulating()` : `true` on desktop simulation\n+- `ds.getDisplayCount()` : `1` or `2`\n+- `ds.getDimensions(\"top\"|\"bottom\")` : width/height\n+- `ds.getDisplayInfo(\"top\"|\"bottom\")` : `{width,height,refreshRate,available}`\n+- `ds.drawToTop(fn)` / `ds.drawToBottom(fn)` : draw callbacks into canvases/backbuffer\n+- `ds.present()` : Android-only physical present\n+- `ds.drawSimulation(\"vertical\"|\"horizontal\")` : desktop-only preview\n+- `ds.deinit()` : cleanup\n+
### Notes

- The bottom screen is presented via a dedicated Android `Presentation` surface and a shared EGL context.\n+- SDL only manages the primary window; the secondary display is bypassing SDL on Android.\n+
