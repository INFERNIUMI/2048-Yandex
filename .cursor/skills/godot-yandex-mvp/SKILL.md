---
name: godot-yandex-mvp
description: Coordinates Godot 4.6 HTML5/Yandex Games workflows for this project, delegating to export, JS bridge, and debug-monitoring skills. Use when working on this Godot 4.6 web project, integrating Yandex Games SDK, configuring HTML5 export, or adding runtime logging and error handling.
---

# Godot 4.6 + Yandex Games (MVP Orchestration)

## Purpose

This skill ties together three project-specific skills for Godot 4.6 on Yandex Games:

- `godot-export-yandex-games` – HTML5 export preset and platform constraints
- `godot-js-bridge` – JavaScript ↔ Godot bridge and Yandex SDK patterns
- `godot-debug-monitoring` – Minimal runtime logging, FPS checks, and freeze prevention

Use this orchestration skill to pick the right sub-skill and avoid duplicating logic.

## Quick Routing

- **Export / build issues** (HTML5, WebAssembly, WebGL2, memory size, `gameReady`, Yandex moderation):
  - Read and apply [`godot-export-yandex-games/SKILL.md`](../godot-export-yandex-games/SKILL.md).

- **JavaScript / SDK / ads / leaderboards** (Yandex SDK, `JavaScriptBridge`, async JS calls, rewarded/fullscreen ads):
  - Read and apply [`godot-js-bridge/SKILL.md`](../godot-js-bridge/SKILL.md).

- **Stability / monitoring** (FPS drops, freezes, logging JS/SDK failures without crashes):
  - Read and apply [`godot-debug-monitoring/SKILL.md`](../godot-debug-monitoring/SKILL.md).

## Project-Wide Rules (Summary)

When using any of the three sub-skills in this project:

1. **Engine & Platform**
   - Godot 4.6, target **HTML5 (WebAssembly + WebGL2)**, platform **Yandex Games**.
   - Threads **must stay disabled** in web export.

2. **Web Safety**
   - Never crash the game on SDK/JS/ad failures.
   - Treat all JS calls as **asynchronous** and non-blocking for gameplay.

3. **Performance & UX**
   - Aim for fast load (< ~5 s on Yandex) and stable FPS on low-end mobile.
   - Avoid freezes, infinite loading, and heavy telemetry.

4. **Audio & Focus**
   - Start audio only after user interaction.
   - Pause gameplay/audio on tab blur, ads, and visibility loss; resume safely after.

## How the Agent Should Work

1. **Identify the main concern** (export, JS/SDK, or runtime stability).
2. **Read the corresponding sub-skill SKILL.md** file listed above.
3. Apply those instructions to edits in `scripts/` and `scenes/` only (ignore generated/exported artifacts).
4. Keep solutions **simple, strictly typed (GDScript)**, and safe for HTML5/Yandex Games.

