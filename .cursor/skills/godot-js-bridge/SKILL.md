---
name: godot-js-bridge
description: Patterns for JavaScript ↔ Godot bridge in Yandex Games. Use when calling JavaScript from Godot, integrating Yandex SDK, handling ads, or when the user mentions JavaScriptBridge, JS calls, SDK, or async Godot-JS communication.
---

# JavaScript ↔ Godot Bridge (MVP Patterns)

## Core Rules

- All JS calls are asynchronous
- Never block gameplay waiting for JS
- SDK may be unavailable (local / offline)
- JS failures must not break gameplay

---

## Recommended Pattern

1. **Fire-and-forget** calls
2. Handle result via **signal or callback**
3. **Always provide fallback**

---

## Timeouts & Fallbacks

- Never wait indefinitely for JS response
- Use simple timeout logic (e.g. Timer node)
- If JS does not respond → continue game flow

### Example Flow

```
Call JS → Start timer (3–5 sec) → No response? → Assume failure → Resume game
```

---

## Ads

### Interstitial (Fullscreen)

- Show only at:
  - game over
  - level transition
- Never during active gameplay
- Pause game & audio before ad
- Resume safely after close or error

### Rewarded Ads

- Show reward **only after ad completion**
- Handle close before completion → no reward
- Timeout: 60 sec max
- If timeout → assume failure → no reward

**Pattern:**

```
Show rewarded ad → Wait for callback → Reward granted? → Give reward
                                   ↓
                            Ad closed early → No reward
```

---

## Local Testing Rule

If Yandex SDK is not available:

- Skip SDK logic
- Run game normally
- Log warning only (no crash)

---

## Leaderboards

- Call async after game over
- Handle failure gracefully (no crash)
- Show fallback UI if unavailable

**Pattern:**

```
Submit score → Fire-and-forget → Success? → Update UI
                              ↓
                        Failure → Show local score only
```

---

## Anti-Patterns

| Avoid | Why |
|-------|-----|
| Blocking waits for JS | Freezes game |
| Chained JS calls | Fragile, hard to debug |
| Assuming SDK is always present | Crashes in local/offline |
| Game flow depending on ad success | Ads can fail; game must continue |
| Giving reward before ad completion | Exploitable; user can close ad early |
