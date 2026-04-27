# OpenClicky SDK Integration Guide (Embedded Window Mode)

`OpenClickySDKSession` is the SDK-facing entrypoint introduced for embedding OpenClicky runtime into another macOS app while keeping the native menu-bar companion behavior unchanged in the default app.

## What this current version gives you

- A self-contained runtime object: `OpenClickySDKSession`.
- Embedded mode via `OpenClickySDKMode.embeddedWindow`.
- A SwiftUI panel wrapper: `OpenClickySDKPanel`.
- App-safe action callbacks for panel controls (`dismiss`, `quit`, `HUD`, `memory`, `feedback`, `settings`).

> Scope note: this repository is currently an app target, not a packaged Swift library, so integration is done by linking source/resources directly from this repo into your host app.

## 1) Add source files to the host target

In the host app target, add Swift sources from this repo:

- `leanring-buddy/OpenClickySDK.swift` **(required)**
- `leanring-buddy/CompanionManager.swift`
- `leanring-buddy/CompanionPanelView.swift`
- all dependent files in `leanring-buddy/` used by those two files (including Codex/agent, model, overlay, and settings managers).

For a first pass, easiest is to include the full `leanring-buddy/*.swift` folder and **exclude only**:

- `leanring-buddy/leanring_buddyApp.swift` (menu-bar app entrypoint)
- optional: any files intended only for the menu-bar launch surface you explicitly want to omit

## 2) Ensure resources are in the host bundle

OpenClicky loads several bundled resources from `Bundle.main`, and falls back to source paths in development.

Bundle these into your host app target **at the resource root** (matching the existing app's copy behavior):

- `SOUL.md`
- `OpenClickyModelInstructions.md`
- `AGENTS.md`
- `OpenClickyBundledSkills/`
- `OpenClickyBundledWikiSeed/`
- `CodexRuntime/`
- `ClaudeAgentSDKBridge/`
- `agent-done.mp3`

Example copy phase (same style as this repo):

```sh
ROOT="${PROJECT_DIR}/AppResources/OpenClicky"
DST="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
mkdir -p "$DST"
for rel in SOUL.md OpenClickyModelInstructions.md AGENTS.md OpenClickyBundledSkills OpenClickyBundledWikiSeed CodexRuntime ClaudeAgentSDKBridge agent-done.mp3; do
  if [ -e "$ROOT/$rel" ]; then
    rm -rf "$DST/$rel"
    /usr/bin/ditto "$ROOT/$rel" "$DST/$rel"
  fi
done
```

If you are not using Agent Mode, you can still start and test text prompts, but `Codex`-backed workflows require `CodexRuntime` and related assets.

## 3) Add privacy keys + capabilities

At minimum for runtime behavior, include these Info.plist keys in the host app:

- `NSMicrophoneUsageDescription`
- `NSSpeechRecognitionUsageDescription`
- `NSScreenCaptureUsageDescription`
- `NSAppleEventsUsageDescription` (used for local automation commands)

Also ensure your host app can access the required frameworks/network/mic as needed by your features (Speech, AVFoundation, ScreenCaptureKit, etc.).

## 4) Launch & embed in SwiftUI

**Preferred pattern**:

```swift
struct HostView: View {
    @StateObject private var sdk = OpenClickySDKSession(mode: .embeddedWindow)
    @State private var showOpenClicky = false

    var body: some View {
        VStack {
            Button("Open OpenClicky") { showOpenClicky = true }
        }
        .onAppear {
            sdk.start()
        }
        .sheet(isPresented: $showOpenClicky) {
            sdk.makePanelView(
                isPanelPinned: false,
                actions: .init(
                    onPanelDismiss: { showOpenClicky = false },
                    onQuit: { showOpenClicky = false },
                    onOpenHUD: { /* route to your HUD */ },
                    onOpenMemory: { /* route to your memory UI */ },
                    onOpenFeedback: { /* open issue page or your feedback form */ },
                    onShowSettings: { /* route to your settings UI */ }
                ),
                setPanelPinned: { _ in }
            )
            .frame(minWidth: 356, minHeight: 720)
            .padding(8)
        }
        .onDisappear {
            sdk.stop()
        }
    }
}
```

## 5) Sending input from host

```swift
sdk.submitTextPrompt("Summarize this page")

sdk.submitAgentPrompt("Create a bug report from these logs") // agent mode entry

sdk.startVoiceCapture() // begin follow-up dictation
sdk.stopVoiceCapture()  // end follow-up dictation early
```

## 5b) Copy-paste host side files (minimal)

### OpenClickyHostRuntime.swift

```swift
import Foundation
import SwiftUI

@MainActor
final class OpenClickyHostRuntime: ObservableObject {
    let sdk = OpenClickySDKSession(mode: .embeddedWindow)

    @Published var isPanelPresented = false
    @Published var isPanelPinned = false

    func start() {
        sdk.start()
    }

    func stop() {
        sdk.stop()
    }

    func makePanel(onDismiss: @escaping () -> Void) -> some View {
        sdk.makePanelView(
            isPanelPinned: isPanelPinned,
            actions: .init(
                onPanelDismiss: onDismiss,
                onQuit: onDismiss,
                onOpenHUD: {
                    // Route to your HUD/window
                },
                onOpenMemory: {
                    // Route to your memory UI
                },
                onOpenFeedback: {
                    // Open your preferred feedback UX
                },
                onShowSettings: {
                    // Route to your settings UI
                }
            ),
            setPanelPinned: { pinned in
                isPanelPinned = pinned
            }
        )
    }
}
```

### In your App scene / controller

```swift
import SwiftUI

@main
struct MyHostApp: App {
    @StateObject private var openClickyRuntime = OpenClickyHostRuntime()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(openClickyRuntime)
                .onAppear {
                    openClickyRuntime.start()
                }
                .onDisappear {
                    openClickyRuntime.stop()
                }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var openClickyRuntime: OpenClickyHostRuntime

    var body: some View {
        VStack(spacing: 16) {
            Button("Open OpenClicky") {
                openClickyRuntime.isPanelPresented = true
            }
        }
        .sheet(isPresented: $openClickyRuntime.isPanelPresented) {
            openClickyRuntime.makePanel {
                openClickyRuntime.isPanelPresented = false
            }
            .frame(minWidth: 356, minHeight: 720)
        }
    }
}
```

### If your app uses `NSWindow` / AppKit windows instead of `.sheet`

- keep one persistent `OpenClickySDKSession` instance at a controller level
- create an `NSHostingView(rootView:)` from `runtime.makePanel(...)`
- present/close that hosting view in your normal host window flow

> For non-SwiftUI hosts, still call `OpenClickySDKSession.start()` once at app launch and `stop()` on app shutdown.


## 6) API key wiring

```swift
sdk.setAnthropicAPIKey("...")
sdk.setCodexAgentAPIKey("...")
sdk.setElevenLabsAPIKey("...")
sdk.setCartesiaAPIKey("...")
```

These setters update existing OpenClicky code paths and persist the keys the same way the native app does.

## 7) Runtime-mode behavior to verify

In embedded mode:

- Global push-to-talk shortcut monitor is not started.
- On startup, overlay auto-show is disabled.
- Onboarding/reveal behavior is not tied to menu-bar state.

Menu-bar behavior is unaffected when run from the default app using `CompanionManager()` (default `.menuBar`).

## 8) Logging during test

Use existing OpenClicky request logs to validate runs:

- `~/Library/Application Support/OpenClicky/Logs/messages-*.jsonl`

You can confirm completion/cancellation semantics by filtering `openclicky.request.completed`.

## 9) Known limitations in this integration

- This is a source-level SDK path, not yet a dedicated SPM product.
- Your host app may need permission re-prompts if keys/features are first used.
- If the host app already has a strong app lifecycle architecture, you may want to gate `sdk.start()` to avoid starting before UI permissions/scene mount.
