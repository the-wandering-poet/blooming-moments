# Backend Review (Product Perspective)

Review of the backend Codex added: `BackendModels.swift`, `BackendServices.swift`,
`BackendFlowAPI.swift`, `BackendPersistence.swift`, how `ContentView.swift` consumes it,
the `BackendDemo` runner, and the demo output.

**Status: proposals only — no code changed yet.**

## Overall

Clean, well-layered skeleton (typed models → protocol-based services → API facade →
SwiftUI). As an architecture stub it's solid. The concern is whether the *shape* can
deliver the core promise — "borrow the eye, keep the moment" via **live** coaching — or
whether it bakes in assumptions that break when real ML/camera work lands.

---

## P0 — Gaps that block the core promise

### 1. There's no "live" loop — coaching is a one-shot static response
`buildGuidance(request:)` produces a single `GuidanceResponse` once. The UI's "readiness"
is just a boolean toggle (`isReadyToCapture = true`, ContentView.swift:277). The product
sells *live* coaching that reacts to where the subject is right now, but the backend has no
concept of evaluating a live frame. The readiness math (`MockReadinessEvaluator`) is computed
from static scene scores and, with current seed data, always returns 98/`ready` — it can
never actually coach.

- **Proposal:** Add a second boundary alongside `buildGuidance` — e.g.
  `evaluateFrame(liveFrame:against:) -> LiveCoachingState` returning incremental cues + a real
  readiness delta. Keep `buildGuidance` as the one-time "plan"; make readiness a function of
  live signals (subject in zone? faces toward light? exposure locked?), not a one-time score.
- **Why:** This is the single most important surface for the product, and it currently doesn't
  exist as a concept anywhere in the backend.

### 2. The subject reference photo — the most differentiating input — is dropped
The UI's subject-calibration step says "capture everyone once so the app can judge scale, pose
readiness, and faces during the shoot" (ContentView.swift:533). But `SubjectProfileInput` only
carries `scenario`/`count`/`ageMix`/`mobilityNotes` — no reference image, no face/scale data.
The promise can't be fulfilled by this model.

- **Proposal:** Add a `subjectReference` (image path + derived face/scale signals) to
  `SubjectProfileInput`, and thread it into readiness/pose evaluation.
- **Why:** "Judge faces and pose readiness against the people in front of you" is a key reason
  this beats a generic camera grid overlay.

### 3. `portfolioId` is requested, validated, then silently ignored
`GuidanceRequest.validate()` requires a non-empty `portfolioId`, but `GuidedCaptureBackend`
always uses its own injected `portfolio` and never matches the request's id. A mismatched id
silently produces guidance for the wrong style.

- **Proposal:** Either resolve `portfolioId` through a `PortfolioCatalog` lookup inside the
  backend, or drop the field until multi-style exists. Don't validate an input you ignore.
- **Why:** This is the seam where "multiple photographers' styles" plugs in — getting it honest
  now prevents a silent-wrong-result bug later.

---

## P1 — Product limitations worth deciding on now

### 4. Single hardcoded style/photographer
The whole catalog is one struct: `BackendPreviewFactory.portfolio` ("Campus Editorial
Graduation" / Ann Li). "Borrow the eye" implies a *library* of styles. The catalog is the core
product asset and there's no abstraction for it.

- **Proposal:** Introduce a `PortfolioCatalog` provider (even if it returns one entry today) so
  the style-select screen and `portfolioId` resolution have something real to talk to.

### 5. User feedback (thumbs up/down) and keeper selections are discarded
`feedbackPositive` is set in the UI and thrown away on "Done" (ContentView.swift:323);
persistence is write-only (`JSONCaptureSessionStore.save` with no load/list). The "keeper
signal logged for the recipe" copy implies a learning loop that doesn't exist.

- **Proposal:** (a) Persist feedback + which keepers were chosen into the session record;
  (b) add a read/list method to `CaptureSessionPersisting`.
- **Why:** This signal is the data that would let recipes improve — cheap to capture now,
  impossible to backfill later.

### 6. Backend over-produces data the UI never shows
`composition.keepOutZones`, `sceneAnalysis.appleVisionObservations` (highlight-risk rects),
and the `lighting/pose/editing` directive arrays are computed but never surfaced. Meanwhile the
user never sees the "highlight risk" warning the model flags.

- **Proposal:** Pick a direction — surface the high-value ones (keep-out zones as red overlays,
  a highlight-risk warning in live coach) or trim the model to what's shown. Right now it's an
  awkward middle.

### 7. No realistic failure states
The only error path is validation → a generic "Guidance fallback active" string, after which
the UI shows hardcoded cues. A camera-guidance product lives or dies on graceful handling of
"no scene detected," "too dark," "no faces found," "subject left frame."

- **Proposal:** Model these as explicit `ReadinessState`/coaching states rather than one
  fallback string.

---

## P2 — Hygiene / smaller smells

### 8. Three near-duplicate `demo-output/` folders
`build-after-quota-refresh`, `finished`, `complete` — all dated 20260601, committed with binary
images + JSON. Looks like leftover iterative re-runs.
- **Proposal:** Keep one canonical demo bundle, `.gitignore` the rest (or move generated demos
  out of the repo).

### 9. Protocol names hard-code the implementation tech
`AppleVisionSceneAnalyzing`, `MockAppleCameraAdapter`. If guidance ever runs server-side or
swaps models, the names lie.
- **Proposal:** Rename to capability-based (`SceneAnalyzing`, etc.) while callers are few.

### 10. `MockReadinessEvaluator.reasons` mixes semantics
It concatenates a placement cue, a pose face-direction, and a clutter verdict into one "reasons"
array. Confusing to consume.
- **Proposal:** Separate "what to fix" (actionable cues) from "why this score" (diagnostics).

---

## Recommended order

**3 → 1 → 2 → 5** (honest portfolio resolution, then the live-evaluation boundary, then subject
reference, then the feedback/persistence loop) — these unlock the actual product story. The rest
are cleanups.
