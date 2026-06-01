# Frontend Context Handoff

This project is back on a shared frontend workflow. Frontend A, Frontend B, and Frontend C all edit the main workspace:

`/Users/annli/Documents/AI photographer`

The old frontend worktrees were merged into `main` and removed. Use the thread history and files below as the source of truth when picking work back up.

## Active Threads

- `Frontend A`
  - Thread id: `019e8183-b028-7950-91ef-c7031bfc3419`
  - Focus: UX flow, portfolio detail, curated portfolio selection, scene capture/confirm/calculating flow.

- `Frontend B`
  - Thread id: `019e7ce8-7b39-7250-9e27-1c4d830d1c4c`
  - Focus: UI polish, visual system, bottom navigation, fine tune review, app branding.

- `Frontend C`
  - Thread id: `019e7be1-48a4-7af3-a461-2774d74426ae`
  - Focus: product narrative, recipe-based flow, high-fidelity SwiftUI app direction, realtime coaching experience.

## Removed Temporary Worktree Threads

These were short-lived worktree threads. Their code changes were merged into `main`, then the worktrees were removed. Their chat history can still be read if needed.

- Temporary Frontend A worktree thread
  - Thread id: `019e84c8-ea3a-7ce0-bec7-729d9476ede6`
  - Former branch: `codex/frontend-a`
  - Commit merged to main: `7e2e5f9` via merge `d44fc50`
  - Main change: refined portfolio detail UX, selectable reference shots, `selectedShotIndex` flow.

- Temporary Frontend B worktree thread
  - Thread id: `019e84c8-ea3a-7ce0-bec7-728c6a61e8ec`
  - Former branch: `codex/frontend-b`
  - Commit merged to main: `bf7cd20` via merge `da14dc1`
  - Main change: app icon, Blooming branding, project icon settings, small visual polish.

- Temporary Frontend C worktree thread
  - Thread id: `019e84c8-ea3a-7ce0-bec7-72a69d5c72fb`
  - Former branch: `codex/frontend-c`
  - Commit merged to main: `20fba67` via merge `e2feaa7`
  - Main change: clarified recipe/product-flow language connecting portfolio choice, scene analysis, and live coaching.
  - Also contains the historical `Frontend Overall UI` high-fidelity static image generation history.

## High-Fidelity Design Source

There is no separate Figma file in the repo right now. There is, however, a high-fidelity static UI redesign image set from the historical `Frontend Overall UI` thread.

Important: this image set has not yet been fully implemented in SwiftUI. Treat it as the visual target/reference for future UI implementation work.

Archived reference images:

- `references/uiux/frontend-overall-ui/README.md`
- `references/uiux/frontend-overall-ui/00-flow-board.png`
- `references/uiux/frontend-overall-ui/01-welcome-root.png`
- `references/uiux/frontend-overall-ui/02-scenario-select.png`
- `references/uiux/frontend-overall-ui/03-curated-portfolio-feed.png`
- `references/uiux/frontend-overall-ui/04-portfolio-detail-shot-recipe.png`
- `references/uiux/frontend-overall-ui/05-subject-calibration.png`
- `references/uiux/frontend-overall-ui/06-scene-choice.png`
- `references/uiux/frontend-overall-ui/07-scan-surroundings.png`
- `references/uiux/frontend-overall-ui/08-scene-analysis.png`
- `references/uiux/frontend-overall-ui/09-realtime-live-coach.png`
- `references/uiux/frontend-overall-ui/10-keeper-selection.png`
- `references/uiux/frontend-overall-ui/11-ai-fine-tune-review.png`
- `references/uiux/frontend-overall-ui/12-profile-saved-moments.png`
- `references/uiux/frontend-overall-ui/13-use-current-scene.png`
- `references/uiux/frontend-overall-ui/14-invite-tab.png`
- `references/uiux/frontend-overall-ui/15-saved-moments-bottom-sheet.png`
- `references/uiux/frontend-overall-ui/16-extra-generated-screen-or-revision.png`

Historical source:

- Thread title: `Frontend Overall UI`
- Thread id: `019e84c8-ea3a-7ce0-bec7-72a69d5c72fb`
- Original generated image cache: `/Users/annli/.codex/generated_images/019e84c8-ea3a-7ce0-bec7-72a69d5c72fb`

The current SwiftUI implementation is the app baseline, not the final version of the image reference set.

Primary file:

- `AIPhotographer/ContentView.swift`

Important current SwiftUI screens and flow areas:

- Welcome / opening page: `WelcomeView`
- Scenario home: scenario cards and Blooming home surface
- Curated portfolio list and detail page
- Portfolio shot/reference selection and masonry-style portfolio detail
- Subject calibration/selfie confirmation
- Find the shot: `Scan Surroundings` and `Use Current Scene`
- Scene capture/confirm upload
- `Blooming is calculating` loading page
- Live coaching camera surface
- Preview / fine tune / keeper selection
- Profile and saved Blooming moments

## Design Docs

Read these before visual or flow changes:

- `docs/DESIGN_PRINCIPLES.md`
  - Color tokens, typography, visual principles.
- `docs/72_HOUR_FUNCTIONAL_APP_TRACKER.md`
  - Functional beta tracker and implementation priorities.
- `docs/BACKEND_SHOT_MATCHING_LOGIC.md`
  - Product/backend logic for scene and shot matching.
- `docs/VERSION_1_BASELINE.md`
  - Baseline app state.

## Visual Assets

Primary bundled app assets:

- `AIPhotographer/Assets.xcassets/BloomingLogo.imageset`
- `AIPhotographer/Assets.xcassets/BloomingLogoVector.imageset`
- `AIPhotographer/Assets.xcassets/BloomingHeaderBackdrop.imageset`
- `AIPhotographer/Assets.xcassets/WelcomePageArtwork.imageset`
- `AIPhotographer/Assets.xcassets/AppIcon.appiconset`
- `AIPhotographer/Assets.xcassets/HooverTower.imageset`
- `AIPhotographer/Assets.xcassets/ArchesWalk.imageset`
- `AIPhotographer/Assets.xcassets/StripedLight.imageset`
- `AIPhotographer/Assets.xcassets/GraduationScenePoster.imageset`
- `AIPhotographer/Assets.xcassets/WeddingScenePoster.imageset`
- `AIPhotographer/Assets.xcassets/AnniversaryScenePoster.imageset`

Reference-only UI assets:

- `references/uiux/blooming-welcome-reference.png`
- `references/uiux/instagram-template-color-typography-reference.png`
- `references/uiux/README.md`

## Workflow Rule

Frontend work is no longer split by frontend worktree. All frontend threads should edit `main` in the shared project directory. Before editing:

1. Run `git status --short --branch`.
2. Confirm the branch is `main`.
3. Read this handoff file and the relevant old thread history.
4. For visual redesign work, use `references/uiux/frontend-overall-ui/00-flow-board.png` and the relevant numbered screen PNG as the reference.
5. Preserve current product logic and navigation unless the user explicitly asks to redesign the flow.

Backend work remains separate for now on:

- Branch: `codex/backend-flow-skeleton`
- Worktree: `/Users/annli/.codex/worktrees/d65b/AI photographer`
