## Mission: reduce strict concurrency errors in OpenClickySDK Swift 6 build

Goal: make `swift build -c debug` succeed by removing/errors from `-strict-concurrency=complete` diagnostics in OpenClickySDK integration files.

Scope:
- Address errors in: OpenAIAudioTranscriptionProvider.swift, MenuBarPanelManager.swift, BuddyDictationManager.swift, ElevenLabsTTSClient.swift, OpenClickyComputerUseRuntime.swift, CompanionManager.swift, OpenClickySDK.swift (if needed), OverlayWindow.swift warnings may remain.
- Prefer minimal but safe actor/sendability fixes.
- Keep behavior and persistence/logging conventions unchanged.

Success condition:
- `swift build -c debug` reaches near-success with no concurrency errors in listed files.

## Progress
- Fixed transcription provider/session sendability across OpenAI, Apple Speech, AssemblyAI, and Deepgram providers.
- Fixed `MenuBarPanelManager` nonisolated `deinit` monitor/observer token access.
- Reworked filler phrase prefetching to avoid sending a main-actor TTS client through a task group.
- Reworked Background Computer Use runtime startup to avoid capturing `FileManager` in a detached task.
- Fixed `CompanionManager` completion-helper crossings with an unchecked request-field wrapper and synchronous main-actor assumptions.
- Marked `ClaudeAPI` and `OpenAIAPI` main-actor isolated to match their use from `CompanionManager`.
- Fixed overlay fade completion to mutate windows under `MainActor.assumeIsolated`.
- Validation: `cd /Users/jkneen/Documents/GitHub/muxy && swift build -c debug` completed successfully. Remaining diagnostics are warnings only.