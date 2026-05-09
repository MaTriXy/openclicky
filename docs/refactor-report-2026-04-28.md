# OpenClicky Refactor Report

Date: 2026-04-28  
Project: `/Users/jkneen/Documents/GitHub/openclicky`  
Primary app target source: `/Users/jkneen/Documents/GitHub/openclicky/leanring-buddy`

## Executive Summary

OpenClicky would benefit most from splitting several high-responsibility "god files" and moving from a flat source layout to a feature-and-layer architecture.

The top refactor target is `CompanionManager.swift` (9,618 lines), which currently mixes orchestration, state, automation, onboarding, and response pipeline logic.

## File Size Hotspots (Swift)

- `CompanionManager.swift` — 9,618 lines
- `ElevenLabsTTSClient.swift` — 1,949 lines
- `OverlayWindow.swift` — 1,723 lines
- `CodexAgentSession.swift` — 1,405 lines
- `CompanionPanelView.swift` — 1,243 lines
- `BuddyDictationManager.swift` — 1,152 lines
- `OpenClickySettingsWindowManager.swift` — 1,135 lines
- `OpenClickyComputerUseRuntime.swift` — 1,038 lines

## Core Structural Issues

1. **Single-file orchestration concentration**
   - `CompanionManager.swift` contains too many responsibilities.
2. **Mixed concerns across session/runtime classes**
   - `CodexAgentSession.swift` handles lifecycle + parsing + safety filtering + memory behavior.
3. **UI and control logic coupled**
   - Overlay/window/panel files include both rendering and operational logic.
4. **Flat directory shape**
   - Most Swift files live in one directory, increasing cognitive load.
5. **Limited protocol boundaries**
   - Harder to test components independently and reuse behavior.

## Recommended Restructure

### 1) Decompose `CompanionManager`

Split into focused collaborators:

- `CompanionStateStore`
- `CompanionPermissionCoordinator`
- `CompanionOnboardingCoordinator`
- `CompanionResponsePipeline`
- `CompanionAutomationRouter`

Keep `CompanionManager` as a thin composition root and event router.

### 2) Decompose `CodexAgentSession`

Extract modules:

- `AgentSessionRuntime`
- `AgentNotificationParser`
- `AgentSafetyFilter`
- `AgentMemoryRecorder`
- `AgentTaskTitleParser`

This isolates policy from transport/runtime concerns.

### 3) Separate UI from runtime/control code

- Keep SwiftUI/AppKit view files presentation-focused.
- Move side effects, process control, and orchestration into coordinators/services.

### 4) Increase protocol-driven design

Add protocols at seams for:

- TTS clients
- Transcription providers
- Automation executors
- Agent persistence/memory recording

This will improve testability and make swapping implementations easier.

### 5) Introduce clearer source layout

Suggested structure under `leanring-buddy/`:

- `Features/Companion/`
- `Features/AgentMode/`
- `Features/ComputerUse/`
- `UI/Shared/`
- `Services/TTS/`
- `Services/Transcription/`
- `Services/AI/`
- `Services/Persistence/`
- `Core/Models/`
- `Core/Utils/`
- `Core/Extensions/`

## Suggested Rollout Plan

### Phase 1 — Move-only reorganization
- Create folder structure.
- Move files without behavior changes.
- Keep commits mechanical.

### Phase 2 — `CompanionManager` extraction
- Extract onboarding, permissions, and automation routing first.
- Then split response pipeline.

### Phase 3 — `CodexAgentSession` extraction
- Pull parsing/safety modules first (lowest risk).
- Then memory/task-title helpers.

### Phase 4 — Test stabilization
- Add focused unit tests around extracted modules.
- Prioritize parsing, safety filters, and state transitions.

### Phase 5 — Naming and DI cleanup
- Normalize naming conventions.
- Tighten constructor injection and interfaces.

## Practical Targets

- General file target: < 400 lines where feasible.
- Coordinator/runtime files: typically < 700 lines.
- Restrict single-class responsibility to one clear domain.

## Expected Outcomes

- Faster onboarding for contributors.
- Better reuse between voice, agent, and computer-use paths.
- Lower risk changes due to narrower modules.
- Easier testing and regression isolation.

## Notes

- This report is architecture-focused and intentionally non-destructive.
- It is designed so refactor phases can be landed incrementally with low regression risk.

