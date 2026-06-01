# Backend Flow Skeleton

This pass adds an app-local backend skeleton for `Campus Editorial Graduation` using the repository's current Swift/Xcode stack.

## What exists now

- Shared typed domain models in `AIPhotographer/BackendModels.swift`
- Backend orchestration and adapter protocols in `AIPhotographer/BackendServices.swift`
- JSON mock persistence in `AIPhotographer/BackendPersistence.swift`
- App-local API facade in `AIPhotographer/BackendFlowAPI.swift`
- Frontend guidance consumption in `AIPhotographer/ContentView.swift`
- Local demo runner in `BackendDemo/main.swift`
- Local demo artifact renderer in `BackendDemo/render_artifacts.py`

## Core backend surface

`GuidedCaptureBackend.buildGuidance(request:)` is the current action boundary.
`LocalCaptureGuidanceAPI` wraps that boundary in an API-like facade for the SwiftUI flow.

It produces:

- curated portfolio style extraction
- scene analysis
- placement recommendation
- pose recommendation
- composition recommendation
- Apple camera style settings recommendation
- capture readiness state
- post-capture edit plan

This is the shape to preserve if the app later moves to:

- a server proxy route
- server actions
- an edge function
- a native on-device Vision + camera coordinator

## Apple Vision / Apple camera representation

The current pass uses protocols plus mocked adapters:

- `AppleVisionSceneAnalyzing`
- `CameraSettingsRecommending`
- `CaptureReadinessEvaluating`

The mocked responses are intentionally realistic enough for frontend integration:

- normalized subject box
- camera origin
- vision observations with confidence
- highlight risk zone
- AE/AF lock cues
- lens, zoom, exposure bias, white balance, focus distance, and stabilization guidance

## Persistence

`JSONCaptureSessionStore` writes session records as JSON. This is mock persistence standing in for a database or remote session store.
The app flow now calls the persistence facade when the user saves keepers, using mock capture paths until AVFoundation photo capture is wired.

## Frontend wiring

The SwiftUI flow now carries a `GuidanceResponse` through:

- scene scan/current-scene handoff
- live coaching cues
- dynamic guide overlay placement
- camera settings strip
- preview edit recipe
- saved keeper signal

The prototype still renders mocked camera imagery, but the displayed guidance now comes from backend service output instead of hardcoded live-coaching strings.

## Demo bundle

The generated demo bundle for this pass lives at:

- `demo-output/backend-flow-build-after-quota-refresh-20260601/`
- `demo-output/backend-flow-finished-20260601/`
- `demo-output/backend-flow-complete-20260601/`

It contains:

- original scene A
- guided capture simulation B
- edited result C
- per-scenario guidance JSON
- persisted session JSON
- top-level demo manifest

## Current limitations

- No live camera or live Apple Vision runtime in this environment
- No network API because the repo has no backend service runtime configured
- Guided capture artifact B is an annotated simulation, not a synthesized subject insertion
- Edited result C is a deterministic local edit of B, not a generative retouch
