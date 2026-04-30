# Clicky — Product Requirements Document & Technical Specification

**Version:** 1.0.10-equivalent  
**Date:** 2026-04-30  
**Source:** Reverse engineering of `com.humansongs.clicky` (Universal macOS binary)  
**Scope:** Complete functional and technical specification sufficient for engineering implementation

---

## 1. Product Overview

### 1.1 Elevator Pitch
Clicky is a voice-first AI assistant that lives in the macOS menu bar. Users press a global hotkey, speak naturally, and Clicky transcribes their voice in real-time, takes screenshots of their desktop, and either answers directly via Claude or delegates complex tasks to a bundled Codex agent. Results are spoken back via ElevenLabs TTS or displayed as floating overlay cards.

### 1.2 Core Value Proposition
- **Zero-friction voice input:** Global push-to-talk, real-time streaming transcription
- **Ambient desktop awareness:** Automatic multi-screen capture with self-exclusion
- **Agent delegation:** Seamless handoff from quick Q&A (Claude) to complex tasks (Codex)
- **Guided screen interaction:** "Click here" overlays for directing the agent
- **Persistent knowledge:** Local wiki compounds across sessions

### 1.3 Target Platform
- macOS 14.2+
- Universal binary (arm64 + x86_64)
- Menu bar app (`LSUIElement` — no dock icon)
- Notarized, signed, with Sparkle auto-updater

### 1.4 External Identities
| Attribute | Value |
|---|---|
| Bundle ID | `com.humansongs.clicky` |
| Display Name | Clicky |
| URL Scheme | `clicky://` (for OAuth callbacks) |
| Developer | Human Songs (Farza Majeed) |
| Internal Codename | `leanring-buddy` |

---

## 2. User Experience Flows

### 2.1 Primary Flow: Voice Query

```
1. User presses global hotkey (default: configurable)
2. BuddyDictationManager starts microphone capture via AVAudioEngine
3. AssemblyAIStreamingTranscriptionProvider streams audio via WebSocket
4. Real-time transcript appears in floating HUD (CodexHUDWindowManager)
5. On hotkey release:
   a. If simple query → CompanionManager routes to ClaudeAPI
   b. If agent task → CompanionManager spawns CodexAgentSession
6. ScreenshotManager captures all screens, excludes own floating button
7. ClaudeAPI sends: transcript + screenshots + thread context
8. Response streamed back via TTS (ElevenLabsTTSClient) or text overlay
```

### 2.2 Secondary Flow: Agent Delegation (Complex Tasks)

```
1. User voice/text indicates complex task ("build me a website", "fix this bug")
2. CompanionManager+CodexAgent creates CodexAgentSession
3. CodexProcessManager spawns bundled Codex runtime subprocess
   - Isolated CODEX_HOME directory
   - JSON-RPC protocol over stdin/stdout
4. CodexProtocolClient manages JSON-RPC lifecycle:
   - Initialize handshake
   - Task dispatch with thread context
   - Delta streaming (partial results)
   - File attachments (screenshots as localImage)
5. User can interrupt via Escape key (CompanionManager+EscapeInterrupt)
6. Agent results displayed in ResponseCardOverlay
7. User can do follow-up voice/text in same thread
```

### 2.3 Tertiary Flow: Guided Screen Interaction

```
1. Agent asks user to click something ("Click the Deploy button")
2. HandoffManager prepares region selection overlay
3. HandoffRegionSelectOverlayManager displays dimmed screen with click target
4. ElementLocationDetector analyzes screen content for clickable elements
5. User clicks target location
6. Coordinates sent back to agent as [POINT:x,y:label] or [POINT:none]
7. Agent continues with next step
```

### 2.4 Quaternary Flow: Wiki / Knowledge Persistence

```
1. User says "remember this" or "save this"
2. save skill ingests: links, screenshots, notes
3. WikiManager updates ~/Library/Application Support/Clicky/wiki/
4. Structured markdown with backlinks, entity pages, cross-references
5. Future queries can reference wiki content
```

---

## 3. Feature Requirements

### 3.1 Voice Input System (FR-V1)

| ID | Requirement | Priority |
|---|---|---|
| FR-V1.1 | Global push-to-talk hotkey (system-wide, works from any app) | P0 |
| FR-V1.2 | Real-time streaming transcription via AssemblyAI WebSocket | P0 |
| FR-V1.3 | Fallback transcription via Apple Speech framework | P1 |
| FR-V1.4 | Audio power level visualization in HUD | P1 |
| FR-V1.5 | Push-to-talk cancel: release before recording starts = cancel | P1 |
| FR-V1.6 | PCM16 audio format conversion from AVAudioEngine float | P0 |
| FR-V1.7 | Multi-language support (inferred from response language settings) | P2 |

**States:**
- `idle` → `requestingPermissions` → `startingCapture` → `listening` → `finalizing` → `processing`
- Cancel paths: `shortcutReleasedBeforeStart`, `shortcutReleasedDuringPermission`, `startSuperseded`

### 3.2 Screen Capture System (FR-S1)

| ID | Requirement | Priority |
|---|---|---|
| FR-S1.1 | Capture all connected displays automatically | P0 |
| FR-S1.2 | Exclude Clicky's own floating button window from capture | P0 |
| FR-S1.3 | Exclude Clicky HUD windows from capture | P0 |
| FR-S1.4 | Detect fullscreen apps and adjust capture strategy | P1 |
| FR-S1.5 | Element detection for guided click workflows | P1 |
| FR-S1.6 | Screenshot count tracking per turn | P2 |

### 3.3 AI Model Routing (FR-A1)

| ID | Requirement | Priority |
|---|---|---|
| FR-A1.1 | Primary: Anthropic Claude (messages API) | P0 |
| FR-A1.2 | Model tiers: quality-based routing (`clicky_quality_tier`) | P1 |
| FR-A1.3 | Fallback: OpenAI API | P1 |
| FR-A1.4 | Custom models via OpenRouter (`openRouterCustomModel`) | P2 |
| FR-A1.5 | Codex agent for complex multi-step tasks | P0 |
| FR-A1.6 | Agent paywall/gating for premium features | P1 |

### 3.4 Codex Agent Runtime (FR-C1)

| ID | Requirement | Priority |
|---|---|---|
| FR-C1.1 | Bundled Codex CLI binary (universal, both architectures) | P0 |
| FR-C1.2 | Isolated CODEX_HOME per session | P0 |
| FR-C1.3 | JSON-RPC protocol over stdin/stdout | P0 |
| FR-C1.4 | Initialize → Task Start → Delta Stream → Complete lifecycle | P0 |
| FR-C1.5 | Screenshot injection as `localImage` attachments | P0 |
| FR-C1.6 | Thread history persistence and resumption | P1 |
| FR-C1.7 | Multi-thread: background agents + foreground voice flow | P1 |
| FR-C1.8 | Rate limiting display (`codexRateLimitPercent`) | P2 |
| FR-C1.9 | Interrupt/stop handling (Escape key, voice stop pill) | P1 |
| FR-C1.10 | Process lifecycle: start, monitor, restart-on-idle, cleanup | P0 |

### 3.5 Text-to-Speech (FR-T1)

| ID | Requirement | Priority |
|---|---|---|
| FR-T1.1 | ElevenLabs TTS integration | P0 |
| FR-T1.2 | Streaming playback of agent responses | P1 |
| FR-T1.3 | Playback interrupt: new query stops previous TTS | P1 |
| FR-T1.4 | Agent start/finish audio cues (`agent-done.mp3`, `enter.mp3`) | P1 |
| FR-T1.5 | Debug TTS mode (`clicky-tts-debug`) | P2 |

### 3.6 UI / Overlay System (FR-U1)

| ID | Requirement | Priority |
|---|---|---|
| FR-U1.1 | Menu bar icon + popup panel (MenuBarPanelManager) | P0 |
| FR-U1.2 | Floating agent HUD during voice/agent sessions | P0 |
| FR-U1.3 | Response cards as floating overlays | P0 |
| FR-U1.4 | Cursor text input overlay (click-to-type follow-up) | P1 |
| FR-U1.5 | Handoff region select overlay (dimmed screen + click target) | P1 |
| FR-U1.6 | Handoff voice stop pill ("click to stop") | P1 |
| FR-U1.7 | Handoff indicator chip (status indicator) | P1 |
| FR-U1.8 | Permission guide overlay (first-run coaching) | P1 |
| FR-U1.9 | Agent paywall HUD | P1 |
| FR-U1.10 | Wiki viewer panel | P2 |
| FR-U1.11 | Place detail overlay (maps integration) | P2 |
| FR-U1.12 | Window positioning across multiple displays | P1 |
| FR-U1.13 | Cursor variants: IBeam, Pointer for different overlays | P2 |
| FR-U1.14 | NSPanel-based floating button (excluded from screenshots) | P0 |

### 3.7 Auth & Billing (FR-B1)

| ID | Requirement | Priority |
|---|---|---|
| FR-B1.1 | Supabase auth (OAuth + email) | P0 |
| FR-B1.2 | Google sign-in support | P1 |
| FR-B1.3 | Subscription state management (`BillingStateManager`) | P1 |
| FR-B1.4 | In-app purchases / billing flow (`BillingClient`) | P1 |
| FR-B1.5 | Paywall detection and presentation | P1 |
| FR-B1.6 | Premium permission gating | P1 |

### 3.8 Permissions (FR-P1)

| ID | Requirement | Priority |
|---|---|---|
| FR-P1.1 | Microphone access (with usage description) | P0 |
| FR-P1.2 | Screen recording access (with usage description) | P0 |
| FR-P1.3 | Speech recognition access | P0 |
| FR-P1.4 | Accessibility access (for global hotkey) | P0 |
| FR-P1.5 | Calendar probe (for agent context) | P2 |
| FR-P1.6 | Contacts probe | P2 |
| FR-P1.7 | Photos probe | P2 |
| FR-P1.8 | Reminders probe | P2 |
| FR-P1.9 | Permission flow coordinator with visual coaching | P1 |
| FR-P1.10 | Silent auto-probe after Screen Recording grant | P1 |

### 3.9 Bundled Skills System (FR-K1)

| ID | Requirement | Priority |
|---|---|---|
| FR-K1.1 | Markdown-based skill definitions (SKILL.md frontmatter) | P0 |
| FR-K1.2 | 8 bundled skills: animate, doc, frontend-design, pdf, polish, save, spreadsheet, create-onboarding-hello-world | P0 |
| FR-K1.3 | Skill triggers matching user intent | P0 |
| FR-K1.4 | Script execution (Python for docx/spreadsheet rendering) | P1 |
| FR-K1.5 | Reference materials per skill | P1 |
| FR-K1.6 | Versioned skills with argument hints | P2 |

### 3.10 Wiki / Knowledge Base (FR-W1)

| ID | Requirement | Priority |
|---|---|---|
| FR-W1.1 | Local markdown wiki at `~/Library/Application Support/Clicky/wiki/` | P1 |
| FR-W1.2 | Entity pages with backlinks | P1 |
| FR-W1.3 | Auto-extract from ingested sources | P1 |
| FR-W1.4 | Seed wiki with bundled content | P2 |
| FR-W1.5 | Cross-reference and contradiction tracking | P2 |

### 3.11 Additional APIs (FR-X1)

| ID | Requirement | Priority |
|---|---|---|
| FR-X1.1 | Stock quote lookup | P2 |
| FR-X1.2 | Image search | P2 |
| FR-X1.3 | Place/location search | P2 |
| FR-X1.4 | Maps widget integration | P2 |

### 3.12 Analytics & Observability (FR-O1)

| ID | Requirement | Priority |
|---|---|---|
| FR-O1.1 | Sentry crash reporting + continuous profiling | P1 |
| FR-O1.2 | PostHog analytics | P1 |
| FR-O1.3 | MetricKit integration | P2 |
| FR-O1.4 | ANR (app not responding) detection | P2 |
| FR-O1.5 | Session replay recording | P2 |

### 3.13 Update System (FR-U2)

| ID | Requirement | Priority |
|---|---|---|
| FR-U2.1 | Sparkle auto-updater framework | P1 |
| FR-U2.2 | Update permission prompt | P2 |
| FR-U2.3 | Defer scheduled updates | P2 |

---

## 4. Technical Architecture

### 4.1 High-Level Component Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        macOS System                          │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────────┐ │
│  │ AVAudioEngine│  │ ScreenCaptureKit│  │ Speech.framework   │ │
│  └──────┬──────┘  └──────┬───────┘  └──────────┬──────────┘ │
│         │                │                      │            │
└─────────┼────────────────┼──────────────────────┼────────────┘
          │                │                      │
          ▼                ▼                      ▼
┌─────────────────────────────────────────────────────────────┐
│                      Clicky Core Layer                       │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────────┐ │
│  │BuddyDictation│  │ScreenshotMgr │  │AssemblyAI/AppleSpeech│ │
│  │   Manager    │  │              │  │   Transcription      │ │
│  └──────┬───────┘  └──────┬───────┘  └──────────┬──────────┘ │
│         │                 │                      │            │
│         └─────────────────┼──────────────────────┘            │
│                           │                                   │
│                           ▼                                   │
│                  ┌─────────────────┐                          │
│                  │  CompanionManager │  ← Central orchestrator │
│                  │  (main state machine)│                      │
│                  └────────┬────────┘                          │
│                           │                                   │
│         ┌─────────────────┼─────────────────┐                │
│         ▼                 ▼                 ▼                │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────────┐ │
│  │   ClaudeAPI │  │  OpenAIAPI   │  │ CodexAgentSession   │ │
│  └─────────────┘  └──────────────┘  └─────────────────────┘ │
│                                              │               │
│                                              ▼               │
│                                   ┌─────────────────────┐    │
│                                   │ CodexProcessManager │    │
│                                   │  (subprocess spawn)  │    │
│                                   └─────────────────────┘    │
│                                              │               │
│                                              ▼               │
│                                   ┌─────────────────────┐    │
│                                   │ CodexProtocolClient │    │
│                                   │   (JSON-RPC)        │    │
│                                   └─────────────────────┘    │
│                                              │               │
└──────────────────────────────────────────────┼───────────────┘
                                               │
                                               ▼
                                   ┌─────────────────────┐
                                   │  Bundled Codex CLI   │
                                   │  + ripgrep binary    │
                                   └─────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                      UI / Overlay Layer                      │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────────┐ │
│  │MenuBarPanel  │  │ CodexHUD     │  │ ResponseCardOverlay │ │
│  │   Manager    │  │ WindowManager│  │     Manager         │ │
│  └──────────────┘  └──────────────┘  └─────────────────────┘ │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────────┐ │
│  │ HandoffRegion│  │HandoffVoice  │  │ CursorTextInput     │ │
│  │SelectOverlay │  │ StopWindow   │  │ OverlayManager      │ │
│  └──────────────┘  └──────────────┘  └─────────────────────┘ │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────────┐ │
│  │   WikiViewer │  │AgentPaywall  │  │PermissionGuide      │ │
│  │ PanelManager  │  │   HUDManager │  │   Assistant         │ │
│  └──────────────┘  └──────────────┘  └─────────────────────┘ │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    Supporting Services                       │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────────┐ │
│  │SupabaseAuth  │  │BillingState  │  │ ElevenLabsTTSClient │ │
│  │   Manager    │  │   Manager    │  │                     │ │
│  └──────────────┘  └──────────────┘  └─────────────────────┘ │
│  ┌──────────────┐  ┌──────────────┐  ┌─────────────────────┐ │
│  │WikiManager   │  │SparkleUpdate │  │   WindowPosition    │ │
│  │              │  │   Delegate   │  │     Manager         │ │
│  └──────────────┘  └──────────────┘  └─────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 Complete Source File Inventory

The original project contains 53 Swift source files, organized as a flat module:

**Core Application:**
- `leanring_buddyApp.swift` — App entry point, `@main`
- `AppBundleConfiguration.swift` — Build/config metadata
- `GeneratedAssetSymbols.swift` — Auto-generated asset references

**Companion / Orchestration:**
- `CompanionManager.swift` — Central state machine and coordinator
- `CompanionManager+CodexAgent.swift` — Codex integration extension
- `CompanionManager+EscapeInterrupt.swift` — Escape key interrupt handling
- `CompanionManager+PermissionFlow.swift` — Permission flow extension
- `CompanionManager+ResponsePipeline.swift` — Response processing extension
- `CompanionPanelView.swift` — Main SwiftUI panel view

**Voice & Audio:**
- `BuddyDictationManager.swift` — Voice orchestrator
- `BuddyAudioConversionSupport.swift` — PCM16 conversion utilities
- `AssemblyAIStreamingTranscriptionProvider.swift` — AssemblyAI WebSocket client
- `AppleSpeechTranscriptionProvider.swift` — Apple Speech fallback
- `ElevenLabsTTSClient.swift` — Text-to-speech client

**Codex Agent:**
- `CodexAgentSession.swift` — Agent session lifecycle
- `CodexProcessManager.swift` — Subprocess management
- `CodexProtocolClient.swift` — JSON-RPC protocol handler
- `CodexRuntimeBridge.swift` — Runtime integration
- `CodexHUDWindow.swift` — Agent HUD window

**Screen & Capture:**
- `ScreenshotManager.swift` — Screen capture orchestration
- `ElementLocationDetector.swift` — Clickable element detection

**Window & Overlay System:**
- `OverlayWindow.swift` — Base overlay window
- `MenuBarPanelManager.swift` — Menu bar popup
- `WindowPositionManager.swift` — Multi-display positioning
- `ResponseCardOverlay.swift` — Result card overlay
- `CompanionResponseOverlay.swift` — Response overlay
- `CursorTextInputOverlay.swift` — Text input floater
- `HandoffIndicatorWindow.swift` — Status indicator
- `HandoffRegionSelectOverlay.swift` — Region selection overlay
- `HandoffVoiceStopWindow.swift` — Voice stop pill
- `HandoffManager.swift` — Handoff coordination
- `AgentPaywallHUDWindow.swift` — Paywall overlay
- `WikiViewerPanel.swift` — Wiki reader panel
- `PlaceDetailOverlay.swift` — Maps detail overlay

**AI Model APIs:**
- `ClaudeAPI.swift` — Anthropic integration
- `OpenAIAPI.swift` — OpenAI fallback

**Search & Data APIs:**
- `ImageSearchAPI.swift` — Image search
- `PlaceSearchAPI.swift` — Places/locations
- `StockQuoteAPI.swift` — Stock data
- `PlaceWidget.swift` — Maps widget

**Auth & Billing:**
- `SupabaseAuthManager.swift` — Authentication
- `BillingClient.swift` — Purchase client
- `BillingStateManager.swift` — Subscription state

**Permissions:**
- `PermissionFlowCoordinator.swift` — Permission flow orchestration
- `PermissionGuideAssistant.swift` — Visual coaching
- `AgentPermissionsInspector.swift` — Permission checking
- `AgentPermissionsPage.swift` — Permission UI page

**Knowledge:**
- `WikiManager.swift` — Local wiki management

**Observability:**
- `ClickyAITracing.swift` — AI request tracing

---

## 5. Data Models & State

### 5.1 CompanionManager State Machine

```swift
// Central application state
enum BuddyNavigationMode {
    case idle
    case listening
    case processing
    case responding
    case agentRunning
    case error
}

// Key properties (from reflection metadata)
struct CompanionManagerState {
    var buddyDictationManager: BuddyDictationManager
    var companionManager: CompanionManager  // self-reference
    var codexRateLimitPercent: Double
    var activeCodexTaskCount: Int
    var activeCodexFollowUpTaskIdentifier: String?
    var codexTasks: [CodexTask]
    var codexThreadHistory: [ThreadEntry]
    var isRecordingFromKeyboardShortcut: Bool
    var isKeyboardShortcutSessionActiveOrFinalizing: Bool
    var isShortcutCurrentlyPressed: Bool
    var recordedAudioPowerHistory: [Float]
    var currentAudioPowerLevel: Float
    var didSpeakAgentStartVoiceCue: Bool
    var didSpeakAgentFinishedVoiceCue: Bool
    var clickyMode: ClickyMode
    var clickyStage: ClickyStage
    var clickyTurnStatus: TurnStatus
}
```

### 5.2 Codex Protocol Messages

```swift
// JSON-RPC over stdin/stdout
enum CodexProtocolMessage {
    // Initialize handshake
    case initialize(params: InitializeParams)
    case initializeResponse(result: InitializeResult)
    
    // Task lifecycle
    case taskStart(params: TaskStartParams)
    case taskComplete(result: TaskResult)
    case taskInterrupt(threadId: String)
    
    // Streaming
    case delta(content: String, threadId: String)
    case thinking(content: String)
    
    // File attachments
    case localImage(path: String, threadId: String)
    
    // Server requests (from Codex to Clicky)
    case serverRequest(method: String, params: [String: Any], id: String)
    
    // Error handling
    case errorResponse(id: String, error: CodexError)
    case protocolError(message: String)
    case stdinWriteFailed(error: String)
    case stdoutEOF
}

struct TaskStartParams {
    let threadId: String
    let transcript: String
    let screenshots: [Screenshot]
    let context: ThreadContext
}

struct TaskResult {
    let threadId: String
    let success: Bool
    let output: String
    let filesModified: [String]?
}
```

### 5.3 Window / Overlay State

```swift
struct OverlayWindowState {
    var currentPositionInSwiftUICoordinates: CGPoint
    var cursorPosition: CGPoint
    var cursorOpacity: Double
    var cursorPositionWhenNavigationStarted: CGPoint
    var cardGlobalFrame: CGRect
    var bubbleSize: CGSize
    var bubbleOpacity: Double
    var detectedElementDisplayFrame: CGRect
    var detectedElementScreenLocation: CGPoint
    var detectedElementBubbleText: String
    var currentScale: CGFloat
    var currentRotationDegrees: Double
    var baseFadeOpacity: Double
    var attachedAppBundleIdentifier: String?
    var attachedAppDisplayName: String?
}
```

### 5.4 User Defaults / Preferences

```swift
// All stored in UserDefaults under com.humansongs.clicky
struct ClickyPreferences {
    var clicky_agent_thread_id: String?
    var clicky_agent_thread_resumed: Bool
    var clicky_agent_thread_title: String?
    var clicky_app_version: String
    var clicky_mode: String
    var clicky_point_follow_up: Bool
    var clicky_point_follow_up_open_router_model: String?
    var clicky_point_follow_up_open_router_verbosity: String?
    var clicky_point_follow_up_round: Int
    var clicky_prompt_profile: String?
    var clicky_quality_tier: String
    var clicky_screenshot_count: Int
    var clicky_stage: String
    var clicky_turn_status: String
    var clicky_error: String?
    var clicky_openai_backend_key_invalid: Bool
    var clicky_upstream_auth_error: String?
    var clicky_widget: String?
}
```

---

## 6. API Specifications

### 6.1 Anthropic Messages API

```yaml
Endpoint: POST https://api.anthropic.com/v1/messages
Headers:
  x-api-key: <anthropic_api_key>
  anthropic-version: "2023-06-01"
  anthropic-beta: <optional_beta_features>
Body:
  model: "claude-sonnet-4-6"  # or tier-based selection
  max_tokens: 4096
  messages:
    - role: user
      content:
        - type: text
          text: <transcript>
        - type: image
          source:
            type: base64
            media_type: image/png
            data: <screenshot_base64>
  system: <ClickyModelInstructions.md content>
```

### 6.2 AssemblyAI Streaming Transcription

```yaml
Endpoint: wss://streaming.assemblyai.com/v3/ws
Headers:
  Authorization: <assemblyai_api_key>
Query Params:
  sample_rate: 16000
  encoding: pcm_s16le
  language_code: en_us
Protocol:
  1. Open WebSocket connection
  2. Stream PCM16 audio chunks (100ms frames)
  3. Receive partial transcripts: { "text": "...", "message_type": "PartialTranscript" }
  4. Receive final transcript: { "text": "...", "message_type": "FinalTranscript" }
  5. Send terminate_session message to end
```

### 6.3 Codex Proxy Worker

```yaml
Endpoint: https://clicker-proxy-v2.farza-0cb.workers.dev
Purpose: Relay/proxy for Codex agent tasks
Methods: Varies by task type
```

### 6.4 Codex Runtime JSON-RPC

```yaml
Transport: Stdin/Stdout of spawned Codex CLI subprocess
Format: JSON-RPC 2.0

// Initialize
-> { "jsonrpc": "2.0", "method": "initialize", "params": { "capabilities": {...} }, "id": 1 }
<- { "jsonrpc": "2.0", "result": { "capabilities": {...} }, "id": 1 }

// Start task
-> { "jsonrpc": "2.0", "method": "tasks/run", "params": { "input": "..." }, "id": 2 }

// Streaming delta
<- { "jsonrpc": "2.0", "method": "notifications/delta", "params": { "delta": "..." } }

// Complete
<- { "jsonrpc": "2.0", "result": { "output": "..." }, "id": 2 }
```

### 6.5 ElevenLabs TTS

```yaml
Endpoint: POST https://api.elevenlabs.io/v1/text-to-speech/<voice_id>/stream
Headers:
  xi-api-key: <elevenlabs_api_key>
Body:
  text: <response_text>
  model_id: "eleven_multilingual_v2"
  voice_settings:
    stability: 0.5
    similarity_boost: 0.75
Protocol: Stream audio chunks, play via AVAudioPlayer
```

### 6.6 Supabase Auth

```yaml
Endpoint: <supabase_project_url>/auth/v1/
Methods:
  - signUp (email/password)
  - signIn (email/password, OAuth)
  - signInWithOAuth (Google)
  - getUser
  - refreshSession
```

---

## 7. UI/UX Specifications

### 7.1 Menu Bar Panel

```
┌─────────────────────────────┐
│  [Menu Bar Icon]            │  ← NSStatusItem
├─────────────────────────────┤
│  Clicky                     │
│  ─────────────              │
│  🎤 Hold [shortcut] to talk │
│  [Transcript area]          │
│  [Status: Listening...]     │
│  ─────────────              │
│  History...                 │
│  Settings...                │
│  ─────────────              │
│  Quit Clicky                │
└─────────────────────────────┘
```

### 7.2 Voice HUD

```
┌─────────────────────────────┐
│  ◉ Listening...             │  ← Animated recording indicator
│  "Build me a landing page"  │  ← Live transcript
│  ▓▓▓▓▓▓░░░░░░░░░░░         │  ← Audio power meter
│  [Stop]                     │  ← Voice stop pill
└─────────────────────────────┘
```

### 7.3 Response Card Overlay

```
┌─────────────────────────────┐
│  ✓ Done                     │
│  ─────────────────────      │
│  Here's your landing page:  │
│  [Preview]                  │
│                             │
│  [Open in Finder] [Edit]    │
│  [Follow up]                │
└─────────────────────────────┘
```

### 7.4 Region Select Overlay

```
┌─────────────────────────────────────────────┐
│  🔅 Dimmed screen background                │
│                                             │
│        ┌─────────┐                          │
│        │ Click   │  ← Detected element      │
│        │ here    │     with bubble label    │
│        └─────────┘                          │
│                                             │
│  [POINT:x,y:label] protocol                │
└─────────────────────────────────────────────┘
```

### 7.5 Permission Guide

```
┌─────────────────────────────┐
│  Welcome to Clicky 🎤       │
│                             │
│  We need a few permissions: │
│                             │
│  ✅ Microphone              │
│  ⏳ Screen Recording        │  ← Animated coaching
│  ⏳ Accessibility           │
│                             │
│  [Grant Access]             │
└─────────────────────────────┘
```

---

## 8. Codex Agent Mode System Prompt

The bundled `ClickyModelInstructions.md` defines the agent personality:

```
You are Clicky's temporary Codex agent mode.

Clicky handles microphone input, screenshots, onboarding, the floating HUD, 
and spoken task-finished summaries.
You handle reasoning, tools, concise commentary, and the final answer for 
the explicit agent run the user triggered from their last transcript.

Environment:
- You are running inside Clicky's macOS assistant shell
- The user may have selected an older Clicky thread from history before speaking
- Attached screenshots are the user's current desktop context
- Clicky may keep multiple background agent threads alive at once
- Bundled skills are available for docs, PDFs, and spreadsheets
- Browser MCPs are available when bundled and configured

Behavior:
- Treat any attached screenshots as the user's current desktop context
- Keep the main Clicky voice flow separate from this explicit agent lane
- Assume Clicky already decided whether this is a fresh thread, resumed thread, 
  or active thread steer
- Use browser tools directly when the task is about the web or browser
- Prefer chrome-devtools when reusing user's already-open Chrome state
- Prefer playwright when deterministic, isolated browser run is needed
- Keep browser work lean: background tabs, non-visible manipulation
- Avoid bouncing browser to front during intermediate steps
- Use bundled skills when they materially help
- When task is clear, take action directly instead of only describing
- Keep commentary brief and milestone-based
- Give concise final answer that Clicky can summarize aloud naturally
- If blocked, say exactly what tool, permission, or capability is missing

Style:
- Sound confident, active, and helpful
- Prefer action over hesitation when request is clear
- Avoid long explanations unless user explicitly asks for depth
```

---

## 9. Bundled Skills Specification

### 9.1 Skill Format

Each skill is a directory containing:
```
SkillName/
  SKILL.md              # Definition, triggers, workflow
  scripts/              # Optional executable scripts
  references/           # Optional reference materials
  templates/            # Optional templates
```

### 9.2 Skill: `save` (Wiki Ingest)

**Triggers:** "save", "remember", "note this"

**Workflow:**
1. Accept URL, screenshot path, or text
2. Read and extract key information
3. Update wiki at `~/Library/Application Support/Clicky/wiki/`
4. Create/update entity pages
5. Add cross-references and backlinks
6. Note contradictions with existing knowledge

**Three layers:**
- Raw sources (screenshots, URLs)
- Entity pages (people, projects, concepts)
- Index and summaries

### 9.3 Skill: `frontend-design`

**Triggers:** Build web components, pages, applications

**Workflow:**
1. Understand purpose, audience, constraints
2. Commit to bold aesthetic direction (minimal, maximalist, retro, etc.)
3. Generate working code with real design choices
4. Avoid generic "AI slop" aesthetics

### 9.4 Other Skills

| Skill | Triggers | Key Capability |
|---|---|---|
| animate | animation, transitions, micro-interactions | Motion design with `$impeccable` context |
| doc | docx, word document | python-docx + visual rendering |
| pdf | PDF creation, reading | reportlab, pdfplumber, visual check |
| polish | polish, finishing touches | Quality pass with `$impeccable` |
| spreadsheet | xlsx, csv, excel | openpyxl, pandas, formula-aware |
| create-onboarding-hello-world | hello world site | Personalized HTML greeting page |

---

## 10. Build & Deployment

### 10.1 Xcode Configuration

```
Project: leanring-buddy.xcodeproj
Target: Clicky (macOS App)
Minimum Deployment: macOS 14.2
Architectures: arm64, x86_64 (Universal)
Code Signing: Required (Distribution)
LSUIElement: YES (menu bar only, no dock)
Sandbox: YES (with entitlements)
```

### 10.2 Embedded Binaries

```
CodexRuntime/
  bin/
    codex                           # Universal Codex CLI
  vendor/
    aarch64-apple-darwin/
      codex/codex                   # arm64 Codex binary
      path/rg                       # arm64 ripgrep
    x86_64-apple-darwin/
      codex/codex                   # x86_64 Codex binary
      path/rg                       # x86_64 ripgrep
```

### 10.3 Bundled Resources

```
Resources/
  ClickyModelInstructions.md        # Agent system prompt
  AGENTS.md                         # Source documentation
  ClickyBuildInfo.plist             # Git metadata
  ClickyBundledSkills/              # 8 skill directories
  ClickyBundledWikiSeed/            # Pre-populated wiki
  agent-done.mp3                    # Audio cue
  enter.mp3                         # Audio cue
  eshop.mp3                         # Audio cue
  ff.mp3                            # Audio cue
  steve.jpg                         # Easter egg asset
```

### 10.4 Third-Party Frameworks

| Framework | Version | Purpose |
|---|---|---|
| Sparkle | 2.9.0 | Auto-updates |
| Sentry | Latest | Crash reporting + profiling |
| PostHog | Latest | Analytics |

### 10.5 Swift Package Dependencies

Inferred from linked libraries and build paths:
- PostHog iOS SDK
- Sentry Cocoa SDK
- PLCrashReporter (via Sentry)
- Supabase Swift client

---

## 11. Security & Privacy

### 11.1 Data Handling

| Data Type | Storage | Encryption | Notes |
|---|---|---|---|
| Auth tokens | Keychain | System | Supabase session |
| API keys | Keychain / Env | System | Anthropic, OpenAI, ElevenLabs |
| Screenshots | Memory only | N/A | Transient, not persisted |
| Voice audio | Memory only | N/A | Streamed to AssemblyAI |
| Wiki content | Local filesystem | None | `~/Library/Application Support/Clicky/wiki/` |
| Transcripts | Supabase / Local | TLS | Thread history |
| Analytics | PostHog (external) | TLS | Opt-out available |
| Crash reports | Sentry (external) | TLS | May include screenshots in replay |

### 11.2 Permissions Model

```
Permission Flow:
1. First launch → PermissionGuideAssistant shows coaching UI
2. Microphone → NSSpeechRecognitionUsageDescription
3. Screen Recording → NSScreenCaptureUsageDescription
4. Accessibility → Required for global hotkey (CGEvent tap)
5. After Screen Recording grant → Auto-probe Calendar, Contacts, Photos, Reminders
6. Denied permissions → Graceful degradation with re-prompt option
```

### 11.3 URL Scheme Security

```
clicky://auth/callback — OAuth redirect
clicky:// — General app activation
```

---

## 12. Error Handling

### 12.1 Graceful Degradation Matrix

| Failure | Behavior |
|---|---|
| Microphone denied | Show permission guide, offer text input fallback |
| Screen recording denied | Explain limitation, continue without screenshots |
| AssemblyAI down | Fallback to Apple Speech transcription |
| Claude API error | Retry once, then fallback to OpenAI |
| Codex agent crash | Restart subprocess, preserve thread context |
| Network offline | Queue request, notify user |
| TTS failure | Display text response only |
| Auth expired | Re-prompt login, preserve local data |

### 12.2 Key Error Strings (from binary)

```
"BuddyDictationManager: failed to start recognition session"
"BuddyDictationManager: permissions missing or denied"
"Global push-to-talk: couldn't create CGEvent tap"
"ElementLocationDetector: API error"
"ImageSearchAPI: encode failed"
"ImageSearchAPI: request failed"
"Clicky failed to refresh Codex thread history"
"Clicky Codex runtime was not ready"
"Agents stopped working. Contact Clicky support plz"
"no recognized text, likely a quick push-to-talk tap"
"ANR stopped."
```

---

## 13. Testing Strategy

### 13.1 Unit Tests

- BuddyDictationManager state transitions
- CodexProtocolClient JSON-RPC serialization
- CompanionManager mode switching
- WindowPositionManager multi-display geometry

### 13.2 Integration Tests

- Full voice query → response pipeline
- Codex agent lifecycle (start → run → complete)
- Screen capture with exclusion
- Permission flow

### 13.3 Manual QA Checklist

- [ ] Global hotkey works from fullscreen apps
- [ ] Floating button excluded from screenshots
- [ ] Multi-display positioning correct
- [ ] Agent interrupt via Escape works
- [ ] Follow-up voice in same thread works
- [ ] Region select overlay dims correctly
- [ ] TTS playback interrupts on new query
- [ ] Wiki persists across app restarts
- [ ] Sparkle update check works
- [ ] Paywall gates premium features

---

## 14. Reverse-Engineering Artifacts

### 14.1 Recovered Class Hierarchy

```
NSObject
├── CompanionManager
│   ├── CompanionManager+CodexAgent
│   ├── CompanionManager+EscapeInterrupt
│   ├── CompanionManager+PermissionFlow
│   └── CompanionManager+ResponsePipeline
├── BuddyDictationManager
├── CodexProcessManager
├── CodexProtocolClient
├── CodexAgentSession
├── ElevenLabsTTSClient
├── ClaudeAPI
├── OpenAIAPI
├── WikiManager
├── SupabaseAuthManager
├── BillingStateManager
├── BillingClient
├── ScreenshotManager
├── ElementLocationDetector
├── MenuBarPanelManager
├── WindowPositionManager
├── OverlayWindowManager
├── CodexHUDWindowManager
├── ResponseCardOverlayManager
├── HandoffManager
├── HandoffRegionSelectOverlayManager
├── HandoffVoiceStopWindowManager
├── HandoffIndicatorWindowManager
├── CursorTextInputOverlayManager
├── AgentPaywallHUDManager
├── WikiViewerPanelManager
├── PermissionFlowCoordinator
├── PermissionGuideAssistant
├── AgentPermissionsInspector
├── SparkleUpdateDelegate
├── AppleSpeechTranscriptionProvider
├── AssemblyAIStreamingTranscriptionProvider
├── BuddyPCM16AudioConverter
├── ImageSearchAPI
├── PlaceSearchAPI
├── StockQuoteAPI
└── ClickyAITracing
```

### 14.2 Recovered Source Paths (Build Machine)

```
/Users/thorfinn/Developer/learning-buddy/leanring-buddy/
├── CompanionResponseOverlay.swift
├── OverlayWindow.swift
└── PermissionGuideAssistant.swift
```

### 14.3 Reflection Metadata Properties (Partial)

```swift
// From __swift5_reflstr section
_activeCodexFollowUpTaskIdentifier
_activeCodexTaskCount
_activeFlights
_appDelegate
_appLifecyclePublisher
_articles
_articleCount
_assignedPaletteIndex
_attachedAppBundleIdentifier
_attachedAppDisplayName
_autoCapture
_availableUpdateDisplayVersion
_baseFadeOpacity
_billingActionErrorText
_billingStateManager
_bubbleOpacity
_bubbleSize
_buddyDictationManager
_buddyFlightScale
_buddyNavigationMode
_cachedFrontmostWindowIsFullscreen
_cachedInputTokenCount
_cachedQuotes
_cameraPosition
_cardGlobalFrame
_claudeAPI
_codexAgentSession
_codexProcessManager
_codexRateLimitPercent
_codexTasks
_codexThreadHistory
_colorScheme
_companionManager
_currentAudioPowerLevel
_currentLeadingImageID
_currentLeadingPhotoName
_currentLightColor
_currentOpacity
_currentPermissionProblem
_currentPhotoName
_currentPositionInSwiftUICoordinates
_currentRotationDegrees
_currentScale
_cursorOpacity
_cursorPosition
_cursorPositionWhenNavigationStarted
_deferredScheduledUpdateDisplayVersion
_demoTypewriterText
_detachedCursorFloatOffset
_detachedCursorPulseToggle
_detectedElementBubbleText
_detectedElementDisplayFrame
_detectedElementScreenLocation
_didSpeakAgentFinishedVoiceCue
_didSpeakAgentStartVoiceCue
_didTimeOut
_displayedText
_draftModelSlug
_elevenLabsTTSClient
_failureSummary
_fetchingRange
_fileDiffItems
_fileManager
_flightManager
_globalPushToTalkShortcutMonitor
_imageSearchAPI
_isKeyboardShortcutSessionActiveOrFinalizing
_isRecordingFromKeyboardShortcut
_isShortcutCurrentlyPressed
_metricKitManager
_onScreenView
_openRouterChatAPI
_openRouterCustomModel
_permissionDrivers
_permissionFlowViewState
_placeDetailOverlayManager
_placeSearchAPI
_recordedAudioPowerHistory
_requestManager
_responseCardOverlayManager
_screenSize
_screenViewPublisher
_selectedResponseModelSelection
_statusItemRightClickMenu
_stockQuoteAPI
_systemInfo
_thePersonPropertiesContext
_theSdkInfo
_theStaticContext
```

---

## 15. Glossary

| Term | Definition |
|---|---|
| **Buddy** | Internal codename for the voice assistant subsystem |
| **Codex** | OpenAI's coding agent, bundled as CLI runtime |
| **Handoff** | Guided screen interaction where agent tells user where to click |
| **HUD** | Heads-up display window during voice/agent sessions |
| **MCP** | Model Context Protocol (browser automation tools) |
| **Point Follow-up** | Feature allowing user to click screen element for agent context |
| **Quality Tier** | Model routing level (free/premium/pro) |
| **Region Select** | Dimmed screen overlay for guided clicking |
| **Voice Stop Pill** | Floating "click to stop" button during recording |
| **Wiki** | Local persistent knowledge base |

---

## 16. Appendix: Binary Analysis Notes

### 16.1 Mach-O Sections Present

| Section | Content |
|---|---|
| `__TEXT,__text` | Main executable code |
| `__TEXT,__swift5_typeref` | Type references |
| `__TEXT,__swift5_capture` | Capture descriptors |
| `__TEXT,__cstring` | C string literals |
| `__TEXT,__swift5_reflstr` | Reflection strings (property names) |
| `__TEXT,__swift5_fieldmd` | Field metadata |
| `__TEXT,__swift5_builtin` | Built-in type metadata |
| `__TEXT,__swift5_assocty` | Associated type metadata |
| `__TEXT,__swift5_proto` | Protocol descriptors |
| `__TEXT,__swift5_types` | Type metadata |

### 16.2 Linked System Frameworks

AVFAudio, AVFoundation, AppKit, ApplicationServices, Charts, Combine, Contacts, CoreData, CoreFoundation, CoreGraphics, CoreMedia, CoreServices, DeveloperToolsSupport, EventKit, IOKit, MetricKit, Photos, QuartzCore, ScreenCaptureKit, Security, ServiceManagement, Speech, SwiftUI, SystemConfiguration, _MapKit_SwiftUI

### 16.3 Build Environment

```
Build Machine OS: macOS 15.4 (25D2128)
Xcode: 16.4 (2641)
SDK: macOS 14.2 (25E251)
Swift: 6.0 (inferred from SwiftUI 7.4.27)
Developer: thorfinn (build machine user)
```

---

*Document generated from reverse engineering of Clicky.app v1.0.10. All API endpoints, class names, and behavior patterns recovered via static analysis of the release binary. Implementation details inferred from Swift reflection metadata, string tables, and Info.plist configuration.*
