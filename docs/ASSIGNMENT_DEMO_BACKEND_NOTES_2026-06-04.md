# Assignment Demo Backend Notes - June 4, 2026

This build is a high-fidelity phone-test demo with a minimum viable AI/backend loop. It is not claiming full production readiness.

## What Is Real

- The scene planning path is cloud-first when an API key is present.
  - `SceneRuntimeFrontendNativeCoordinator.phoneTestCloudFirst()` selects `DevDirectCloudScenePlanProvider` when `DIGITALOCEAN_MODEL_ACCESS_KEY` or `GEMINI_API_KEY` exists in the Xcode run environment.
  - `DevDirectCloudScenePlanProvider` calls a DigitalOcean OpenAI-compatible inference router first, then Gemini as fallback.
  - Cloud responses are parsed into `SceneRuntimeModels.GenerateScenePlanResponse`, including stand point, subject/operator position, coaching cues, camera recommendation, runtime affordance signals, and post-capture fine-tune signals.
- The app consumes typed backend contracts instead of only UI-only state.
  - Subject selfie analysis produces a `protectedSubjectSetId` and protected-subject count.
  - Scene input analysis produces scene quality/context fields.
  - Scene planning feeds live shooting guidance and camera recommendation.
  - Final capture flows into after-capture crop/fine-tune services.
- The style profile is a structured runtime artifact, not a paragraph-only review.
  - `AIPhotographer/RuntimeStyleProfiles/style_profile_training_graduation_local_same_photographer_v1_runtime_contract.json`
  - It includes runtime affordance signals, camera parameter intent, and post-capture fine-tune signals that the runtime can consume.

## Demo Fallbacks

- If no DigitalOcean/Gemini key is configured, or cloud generation fails, the app falls back to deterministic local analysis so the phone-test flow still records cleanly.
- The fallback is intentionally contract-shaped, but it is not presented as successful cloud inference.
- The current assignment build uses local portfolio imagery/fixtures so the demo can be recorded at night without requiring a real outdoor shoot.

## Production Gaps

- Full evidence-backed Wedding and Graduation style distillation is still future work.
- Scene/cloud analysis should be upgraded to send actual image/video bytes to a multimodal model instead of relying on structured scene metadata.
- Subject analysis should be upgraded from deterministic phone-test inference to Vision and/or cloud multimodal analysis.
- Persistence is demo/local only; production database sync remains out of scope for this short demo build.

