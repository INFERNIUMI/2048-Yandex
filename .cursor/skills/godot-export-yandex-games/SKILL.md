---
name: godot-export-yandex-games
description: Configures and validates Godot 4.6 HTML5 export for Yandex Games MVP. Use when exporting to Web, setting up HTML5 preset, debugging Yandex Games build, or when the user mentions WebAssembly, WebGL2, Yandex Games, or HTML5 export.
---

# Godot 4.6 Web Export for Yandex Games (MVP)

## Target

- Engine: Godot 4.6
- Platform: HTML5 (WebAssembly + WebGL2)
- Goal: fast, stable MVP build for Yandex Games

---

## Export Preset (HTML5)

### Required Settings

| Setting | Value | Reason |
|---------|-------|--------|
| Threads | OFF | Build rejected or crashes if enabled |
| WebGL2 | REQUIRED | WebGL1 deprecated |
| Use SharedArrayBuffer | OFF | Compatibility (see Advanced below) |
| Debug | OFF | Production build |

### Advanced: SharedArrayBuffer

If Yandex.Игры supports COOP/COEP headers:

- Enable SharedArrayBuffer for better performance
- Requires: `Cross-Origin-Opener-Policy: same-origin`
- And: `Cross-Origin-Embedder-Policy: require-corp`
- Test thoroughly before enabling

### Memory

- Initial memory size: 256–384 MB
- Prefer fixed size; avoid dynamic memory growth if possible

---

## Build Constraints

- WebGL2 required (WebGL1 deprecated since 2021)
- Target low-end mobile devices
- Avoid textures > 2048px
- Total build size target: < 50 MB uncompressed (< 15 MB with Brotli)

### Compression

- Enable Brotli compression on server (reduces size by 60–70%)
- Fallback to Gzip if Brotli unavailable
- Reduces load time by 3–5x

---

## Audio Rules

- No autoplay
- Start audio only after user input
- Pause audio on tab focus loss
- Audio before input → browser mute

---

## Common Failure Points

| Issue | Result |
|-------|--------|
| Threads enabled | Build rejected or crashes |
| Too large memory | Long loading / crash |
| Missing `gameReady` signal | Infinite loading screen |
| Audio before user input | Browser mute |

---

## MVP Acceptance Criteria

If the game:

- loads < 5 seconds
- runs stable at ~60 FPS
- does not crash without SDK

→ acceptable for MVP.

---

## Quick Checklist

Before export:

- [ ] Threads: OFF
- [ ] WebGL2: REQUIRED
- [ ] SharedArrayBuffer: OFF
- [ ] Memory: 256–384 MB
- [ ] Debug: OFF
- [ ] HTTPS enabled (required for production)
- [ ] Compression: Brotli or Gzip
- [ ] `gameReady` called on startup
- [ ] Audio starts only after user interaction
- [ ] No textures > 2048px
- [ ] Build size < 50 MB uncompressed
