# Frontend Overall UI Reference Set

This folder archives the high-fidelity static UI redesign from the historical `Frontend Overall UI` Codex thread.

- Source thread title: `Frontend Overall UI`
- Source thread id: `019e84c8-ea3a-7ce0-bec7-72a69d5c72fb`
- Source cache folder: `/Users/annli/.codex/generated_images/019e84c8-ea3a-7ce0-bec7-72a69d5c72fb`

Important: these are reference images, not SwiftUI implementation files. Future frontend work should treat this set as the visual target and then implement the chosen screens in `AIPhotographer/ContentView.swift` and related assets.

The original thread described the intended output as 15 single-screen images plus 1 full-flow board. The source folder currently contains 17 PNGs, so this archive preserves every generated image to avoid losing a possible revision.

## Files

- `00-flow-board.png` - Full-flow overview board.
- `01-welcome-root.png` - Welcome root.
- `02-scenario-select.png` - Scenario select.
- `03-curated-portfolio-feed.png` - Curated portfolio feed.
- `04-portfolio-detail-shot-recipe.png` - Portfolio detail / shot recipe.
- `05-subject-calibration.png` - Subject calibration.
- `06-scene-choice.png` - Scene choice.
- `07-scan-surroundings.png` - Scan surroundings.
- `08-scene-analysis.png` - Scene analysis.
- `09-realtime-live-coach.png` - Realtime live coach.
- `10-keeper-selection.png` - Keeper selection.
- `11-ai-fine-tune-review.png` - AI fine tune review.
- `12-profile-saved-moments.png` - Profile / saved moments.
- `13-use-current-scene.png` - Use current scene.
- `14-invite-tab.png` - Invite tab.
- `15-saved-moments-bottom-sheet.png` - Saved moments bottom sheet.
- `16-extra-generated-screen-or-revision.png` - Extra generated screen or revision found in the source folder.

## How To Use

Before starting UI implementation or redesign work:

1. Read `docs/FRONTEND_CONTEXT_HANDOFF.md`.
2. Open `00-flow-board.png` to understand the full product flow.
3. Compare the relevant numbered screen image with the current SwiftUI implementation.
4. Implement only the requested screen or flow slice, preserving shared navigation and current product logic unless the user asks for a broader redesign.
