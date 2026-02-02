---
name: godot-debug-monitoring
description: Minimal runtime debug and monitoring for Godot games on Yandex Games. Use when adding logging, FPS monitoring, error handling, or when the user mentions debug mode, telemetry, crash prevention, or production builds.
---

# Runtime Debug & Monitoring (MVP)

## Philosophy

- No heavy telemetry
- No external services
- Minimal visibility is enough for MVP

---

## Debug vs Production

Use a simple flag:

| Flag | Behavior |
|------|----------|
| `DEBUG = true` | Logs enabled |
| `DEBUG = false` | Logs silent |

---

## What to Monitor (Minimum)

- FPS (rough)
- Game freeze detection
- Ad failures (count only)

---

## FPS Monitoring

- Simple FPS counter (optional)
- Detect drops below ~30 FPS
- Do NOT optimize prematurely

**Example:**

```gdscript
func _process(delta: float) -> void:
    if Engine.get_frames_per_second() < 30:
        push_warning("FPS drop: %d" % Engine.get_frames_per_second())
```

---

## Error Handling

- Never crash on:
  - SDK init failure
  - Ad failure
  - JS error
- Log once per session
- Do not spam console

---

## Local Testing

When testing without Yandex SDK:

- SDK calls will fail (expected)
- Use `--disable-web-security` flag in Chrome (dev only)
- Or serve via local HTTPS proxy

**Chrome dev command:**

```
chrome.exe --disable-web-security --user-data-dir="C:/temp/chrome_dev"
```

---

## User Reality

On Yandex:

- Users do not report bugs
- They just leave

**Goal:**

- Avoid crashes
- Avoid freezes
- Avoid infinite loading

Nothing else matters for MVP.
