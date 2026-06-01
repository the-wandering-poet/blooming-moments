# AI Photographer Version 1 Baseline

Baseline created before the next round of product, PRD, and implementation changes.

## Product Direction

- Product: AI Photographer, a phone-based photography director for graduation and campus-style shoots.
- Current beta style name: Campus Editorial Graduation.
- Visual direction: Instagram/editorial template inspired UI with powder blue, warm paper, olive accents, Didot-style serif headings, and rounded post-style reference cards.
- Target: a functional iOS app within the current 72-hour build window, not just a static demo.

## Current App State

- Native SwiftUI iOS app scaffold exists.
- End-to-end prototype flow exists:
  - style selection
  - subject calibration
  - scene path choice
  - scan surroundings
  - current scene analysis
  - live coaching
  - capture processing
  - edited preview
  - saved/keeper signal
- Reference images are bundled in asset catalog:
  - HooverTower
  - ArchesWalk
  - StripedLight
- Home screen has the current Instagram-style design treatment.
- Current implementation still uses mocked/simulated AI, camera, scene analysis, capture, and saving states.

## Current PRD State

- Existing source artifact: `AI_Photographer_PRD.pdf`.
- The PRD should be moved to editable Markdown in a future change.
- Future PRD update should keep the style name `Campus Editorial Graduation`.
- Future PRD update should remove artificial solo/selfie/tripod exclusions and define the product as applicable to solo, selfie, couples, friends, and groups wherever technically possible.
- Vision model selection remains TBD and should be validated during implementation.
- Production API path should use a server proxy or ephemeral-token approach instead of shipping a durable API key in the app binary.

## Known Gaps For Next Version

- Real camera capture is not yet wired.
- Photo library save is not yet wired.
- Real subject registration image capture is not yet wired.
- Real scene analysis and vision model calls are not yet wired.
- Real-time Apple Vision readiness detection is not yet wired.
- Auto focus/exposure/white-balance control is not yet wired.
- The PRD is PDF-only and should become Markdown-first.

## Rollback

After this baseline is committed, roll back a later design or implementation experiment by restoring files from this commit or by checking out the baseline tag/commit.
