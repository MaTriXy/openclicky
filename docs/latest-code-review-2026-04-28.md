# OpenClicky latest changes code review
Date: 2026-04-28
Repo: `/Users/jkneen/Documents/GitHub/openclicky`
Branch: `main` (working tree changes)

## Files reviewed
- `leanring-buddy/ClaudeAgentSDKAPI.swift`
- `leanring-buddy/CodexRuntimeLocator.swift`
- `leanring-buddy/CompanionManager.swift`
- `leanring-buddy/MenuBarPanelManager.swift`
- `leanring-buddy/OpenClickySDK.swift`
- `leanring-buddy/OverlayWindow.swift`
- `leanring-buddy/WindowPositionManager.swift`

## Validation run
- `swiftc -parse` on all changed Swift files: **passed**

## Findings

### 1) High — potential crash from force-casts in AX code
**File:** `leanring-buddy/WindowPositionManager.swift`

The updated AX extraction now force-casts:
- `focusedWindowValue as! AXUIElement`
- `positionValueRef as! AXValue`
- `sizeValueRef as! AXValue`

If accessibility APIs return unexpected CF types, this can crash at runtime.

**Recommendation:** switch back to guarded casts (`as?`) or validate via `CFGetTypeID` before casting.

---

### 2) Medium — thinking-dot tasks can accumulate
**Files:**
- `leanring-buddy/MenuBarPanelManager.swift` (`AgentMenuBarThinkingDots`)
- `leanring-buddy/OverlayWindow.swift` (`ClickyThinkingDots`)

Each view starts a looped `Task` in `onAppear`, but there is no stored handle and explicit `onDisappear` cancellation. Repeated appearance cycles can stack tasks.

**Recommendation:** store task in `@State var animationTask: Task<Void, Never>?` and cancel it in `onDisappear`.

---

### 3) Medium — cursor polling now fully MainActor-bound
**File:** `leanring-buddy/OverlayWindow.swift`

Cursor tracking moved from background dispatch timer to a `Task { @MainActor ... }` loop sampling every ~16ms. Under main-thread pressure (streaming + animation), this may regress cursor smoothness.

**Recommendation:** keep sampling off-main and post only state updates to main actor.

---

## Positives
- Bridge/resource lookup resiliency improved in `ClaudeAgentSDKAPI` + `CodexRuntimeLocator`.
- Agent dock UX changes are stronger (real activity over canned placeholders).
- `CompanionManager` acknowledgement and timing flow updates are directionally solid.

## Priority order
1. Fix AX force-casts (crash risk)
2. Fix thinking-dot task lifecycle
3. Revisit cursor polling thread model
