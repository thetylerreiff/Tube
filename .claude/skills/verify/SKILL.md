---
name: verify
description: Build, launch, and manually exercise Tube.app to verify UI/window/keyboard behavior
---

Build and launch the app:

```sh
scripts/build-app.sh debug
open Build/Tube.app
```

Then walk through this checklist. Each item states the expected behavior.

1. **Copy/paste** — Click the YouTube search box, type text, Cmd-A, Cmd-C,
   clear the field, Cmd-V. The text should round-trip correctly. Cmd-Z should
   undo the paste.
2. **Esc reaches the page** — Enter player fullscreen (press `f`), then press
   Esc. It should exit fullscreen. Separately, Cmd-period should be bound to
   Stop Loading.
3. **Drag** — Hover the top band of the window so the traffic lights and nav
   pill appear, then click-drag the revealed band. It should move the window.
   The 6pt bezel border should also drag the window.
4. **Top-edge resize** — Dragging the very top edge of the window should
   resize it, not move it.
5. **Double-click the revealed band** — Should follow the System Settings
   "double-click title bar" preference (zoom / minimize / do nothing).
6. **Scroll in the revealed top band** — With the cursor over the revealed
   top band, scrolling should still scroll the page underneath.
7. **Frame persistence** — Move and/or resize the window, Cmd-Q to quit, then
   relaunch. The window should restore its prior position and size.

The app's current frame can be inspected without a screenshot via:

```sh
osascript -e 'tell application "System Events" to get {position, size} of window 1 of process "Tube"'
```

For hands-off verification, the `codex-computer-use` skill can drive this
checklist automatically (build, launch, click through each step, and report
back).
