# 72-Hour Functional App Tracker

Goal: ship a functional iOS beta that can be installed on an iPhone and used by friends to complete a real guided shoot.

## North Star

By the end of the 72-hour window, the app should support a real path through:

1. Select `Campus Editorial Graduation`.
2. Capture or choose a subject reference photo.
3. Capture or choose a scene frame, with scan/current-scene paths supported.
4. Send subject + scene context to a vision model for shot guidance.
5. Show concise coaching cues.
6. Open a real camera shooting view.
7. Capture photos.
8. Apply a basic editorial warm-contrast finish.
9. Save selected photos to the camera roll.
10. Log local keeper signals.

## Build Priorities

### P0 - Must Work

- Real iPhone camera preview and photo capture.
- Camera/photo permissions with denied-state recovery.
- Subject reference capture or picker.
- Scene frame capture or picker.
- One working vision-model integration path, provider swappable.
- Portfolio-level shot matching logic:
  - compare user scene against selected portfolio references
  - adapt the closest matching reference when confidence is high
  - synthesize from the portfolio style when the scene is different
- Live coaching screen that uses real camera input, even if readiness starts with lightweight heuristics.
- Save selected images to Photos.
- Local keeper signal storage.
- TestFlight-capable project configuration.

### P1 - Strong Beta

- Scout mode frame sampling with basic on-device quality filters.
- Apple Vision person detection and subject bounding boxes.
- Basic exposure/focus lock actions.
- CoreImage finishing look: Editorial Warm Contrast.
- Before/after preview.
- Retake and try-another-scene flows.

### P2 - If Time Allows

- Audio coaching.
- Grooming cues.
- Multi-frame best-pick ranking.
- More advanced auto camera settings per technique.
- Server proxy for model calls.

## 72-Hour Sequence

### Block 1 - Baseline And Real Camera

- Freeze Version 1 baseline in git.
- Move PRD to Markdown after baseline.
- Add real camera preview.
- Add capture pipeline.
- Add permission handling.
- Verify on Simulator where possible and physical iPhone for camera behavior.

### Block 2 - Subject And Scene Inputs

- Wire subject capture/picker into app state.
- Wire scene capture/picker into app state.
- Replace simulated upload states with real images.
- Keep both scene paths:
  - Scan Surroundings
  - Use Current Scene

### Block 3 - Vision Model Integration

- Define provider protocol.
- Add a temporary direct-provider implementation for fastest beta testing.
- Keep model choice swappable.
- Prompt with subject reference + scene frame + `Campus Editorial Graduation` recipe.
- Parse structured JSON shot plan.
- Add fallback coaching if the API fails.

### Block 4 - Live Coaching And Capture

- Feed shot plan into coaching screen.
- Add person/face detection where feasible.
- Show framing, light, and position cues.
- Gate capture readiness with transparent heuristics.
- Capture one or more photos.

### Block 5 - Edit, Save, And Keeper Signal

- Apply CoreImage warm contrast finish.
- Add before/after preview.
- Save selected photos to camera roll.
- Log keeper signal locally:
  - style id
  - recipe author
  - scene path
  - capture technique
  - saved count

### Block 6 - Device QA And TestFlight

- Run through all app paths on device.
- Test permission-denied states.
- Test bad lighting and good lighting scenes.
- Archive build.
- Prepare TestFlight upload.

## Daily Tracking

Use this checklist at least every few hours:

- What is now real instead of simulated?
- What is blocking an end-to-end user shoot?
- What can be downgraded without breaking the shoot?
- What must be tested on physical iPhone?
- What changed since the Version 1 baseline?

## Versioning Rule

Commit after each stable milestone:

- `v1-baseline-current-prototype`
- `v1.1-real-camera`
- `v1.2-subject-scene-inputs`
- `v1.3-vision-shot-plan`
- `v1.4-live-coaching-capture`
- `v1.5-edit-save-keeper`
- `v1.6-testflight-beta`
