# Blooming Moments

Blooming Moments is an AI-assisted iOS photography director for important life moments. The current demo focuses on a graduation flow: a user chooses a curated photographer-style portfolio, captures a subject selfie, captures or scans a scene, receives guided composition and pose coaching, takes a real photo, and reviews a fine-tuned result.

This repository was built for the CS 153 final project, "The One-Person Frontier Lab." It is a high-fidelity working prototype, not a production-ready marketplace.

## Why I Built This

The problem I wanted to explore is not just "how can AI take better photos?" It is how human taste can collaborate with AI without becoming generic AI content.

People often want beautiful, real records of important moments: graduation, weddings, anniversaries, family milestones, becoming parents, or other moments worth remembering. A professional photographer can bring taste, composition, light awareness, and emotional direction to those moments. But good photographers are expensive, geographically constrained, and limited by time. For example, a graduation session can cost hundreds or thousands of dollars, and the most tasteful photographers can only serve a small number of people.

At the same time, simply generating an AI image is not the right solution. For these moments, people want the real event, the real people, and the real memory. The product should not replace the photo with a fake image. It should help ordinary phone photos become more guided, more composed, and more tasteful while preserving the truth of the moment.

The broader experiment is whether taste can become more accessible through AI. Many creative workers have distinctive judgment, but their taste is hard to distribute, monetize, or protect. Blooming Moments imagines a marketplace where photographers can license curated portfolios, AI can distill their style into guidance, users can access better creative direction, and photographers can share in the value created by their taste.

## Product Concept

In the ideal product:

1. A photographer contributes a curated portfolio.
2. The backend distills a structured style profile from that portfolio, including composition preferences, lighting patterns, camera intent, subject placement, pose tendencies, and post-capture editing signals.
3. A user selects a portfolio style for a moment such as graduation.
4. The user uploads a selfie or group selfie so the system knows who should be protected in the final photo.
5. The user captures a scene photo or scan.
6. The system analyzes the scene, finds usable standing/framing opportunities, and creates a shot plan.
7. The app opens a custom camera with live visual and voice coaching.
8. The app captures a real photo and applies a real pixel crop and fine-tune. It does not regenerate the image.

## Current Demo Scope

The current demo implements a graduation walkthrough of that product vision.

What is working in the current codebase:

- Native SwiftUI iOS app named `Blooming`.
- High-fidelity graduation-oriented UI flow.
- Portfolio selection and portfolio detail screens.
- Subject selfie capture through the iPhone camera.
- On-device Apple Vision face detection for subject calibration, with deterministic fallback.
- Current-scene and scan-surroundings paths for scene input.
- Contract-shaped scene planning data, including subject/operator cues, stand point, rough framing, camera recommendations, and post-capture signals.
- A cloud-first scene plan provider path that can call DigitalOcean's OpenAI-compatible inference router first and Gemini as fallback when credentials are provided in the Xcode run environment.
- Deterministic local fallback so the demo can still run without cloud keys.
- A custom AVFoundation camera surface for final shooting.
- Live coaching HUD and local voice coaching through `AVSpeechSynthesizer`.
- CoreImage crop and fine-tune pipeline for final captured photos.
- A structured runtime style profile JSON for the graduation demo.

Important current limitations:

- The full evidence-backed photographer style distillation pipeline is not finished.
- The cloud path is present, but the submission demo can run in fallback mode and does not yet prove full multimodal production inference over real image/video bytes.
- The portfolio marketplace, photographer revenue sharing, authentication, cloud database, and production persistence are not implemented.
- Some training/reference images are used for academic prototype purposes and would require explicit licensing review before production.
- The Git history does not show every design and product iteration because this was my first full app development project and I learned proper commit/branch practices during the process.

## Technical Architecture

### iOS App

- Language/framework: Swift and SwiftUI.
- Target: iOS 17+.
- Camera: custom AVFoundation camera flow.
- On-device vision: Apple Vision face detection for subject selfie calibration.
- Local speech: `AVSpeechSynthesizer` for spoken live coaching prompts.
- Image editing: CoreImage for real pixel crop and color/contrast fine-tune.

### Backend-Style Contract Layer

Although this is an app-local prototype, the code is organized around backend-style contracts:

- `SceneRuntimeService.swift`: core scene runtime models and service shapes.
- `SceneRuntimeIntegration.swift`: frontend/native integration bridge.
- `PhoneTestSubjectSceneAnalysisAdapter.swift`: phone-test subject and scene analysis adapter.
- `DevDirectCloudScenePlanProvider.swift`: optional cloud-first scene plan provider for DigitalOcean/Gemini.
- `RuntimeStyleProfiles/style_profile_training_graduation_local_same_photographer_v1_runtime_contract.json`: structured graduation style profile used by the runtime.
- `FinalMoment*` services: after-capture crop, keeper selection, fine-tune, save, and local test pipeline.
- `CoreImageFineTuneRenderer.swift`: real pixel edit renderer.

The intended production architecture would move cloud keys and model calls behind a secure server proxy. Durable API keys should not be shipped inside the iPhone app binary.

## How To Run

1. Open `AIPhotographer.xcodeproj` in Xcode.
2. Select the `AIPhotographer` scheme.
3. Select an iPhone simulator or a connected physical iPhone.
4. Build and run.

For a physical iPhone:

- Enable Developer Mode on the phone.
- Trust the Mac when prompted.
- Use Xcode automatic signing with a valid Apple developer team.
- Camera permissions are required for selfie, scene, and final capture flows.

Optional cloud credentials for development:

- `DIGITALOCEAN_MODEL_ACCESS_KEY`
- `DIGITALOCEAN_INFERENCE_BASE_URL`
- `DIGITALOCEAN_ROUTER_OVERRIDE`
- `GEMINI_API_KEY`
- `GEMINI_MODEL_CANDIDATES`

Do not commit secrets. The repository ignores `.env` style files.

## Demo Walkthrough

The suggested demo path is:

1. Open the app and select Graduation.
2. Choose a curated portfolio style.
3. Adopt the portfolio.
4. Capture or confirm a subject selfie.
5. Choose whether to scan surroundings or use the current scene.
6. Capture a scene.
7. Let the app calculate a plan.
8. Enter live coaching.
9. Open the final camera and listen to voice coaching.
10. Capture the final photo.
11. Review AI fine-tune before/after.
12. Save the moment.

## Evaluation And Evidence

The project was evaluated through several kinds of evidence:

- User/problem discovery conversations around graduation, wedding, and important-moment photography.
- Photographer feedback, including a conversation with Renee, a photographer whose perspective helped validate the photographer-side pain point: good photographers have limited time, limited geography, and a desire to scale their taste without simply giving it away.
- Multiple product pivots before choosing this direction:
  - A privacy redaction assistant, which seemed more valuable for enterprise workflows than consumer use.
  - A social media co-pilot, which exposed the "AI flop" problem because AI tended to flatten personal voice into generic content.
  - The final photography direction, which preserves real moments while using AI for guidance and taste-aware support.
- Technical testing:
  - Physical iPhone install and camera permission testing.
  - Swift source typecheck with the iOS simulator SDK.
  - Xcode simulator build validation.
  - Manual walkthroughs of the graduation demo flow.
- Failure analysis:
  - I learned that Apple does not allow an app to remotely control the built-in Camera app UI, so Blooming needs a custom AVFoundation camera.
  - I learned that narrative-only style review is not enough; a usable system needs structured style fields that runtime code can consume.
  - I learned the hard way that regular commits and clean branches matter after a UI regression required rollback work.

Validation commands used during development included:

```bash
xcrun --sdk iphonesimulator swiftc -typecheck \
  -module-cache-path /tmp/ai-photographer-swift-module-cache \
  -target arm64-apple-ios17.0-simulator \
  AIPhotographer/*.swift
```

I also used Xcode simulator builds and physical iPhone installation tests for the camera-dependent paths.

## AI Usage Disclosure

AI tools were used extensively and intentionally.

Development assistance:

- Codex was the main coding assistant for SwiftUI implementation, backend-style contract design, debugging, file edits, validation, and documentation.
- Claude was used for design/product review, architecture critique, and planning feedback.
- Gemini and DigitalOcean model routing were explored for future cloud multimodal analysis.

Product concept:

- The product itself is designed around AI-assisted style distillation, subject/scene analysis, and live coaching.
- The current demo includes local deterministic fallbacks and partial cloud-ready code, but it does not claim full production AI training or complete cloud inference.

Human contribution:

- The product framing, problem choice, user insight, UX direction, taste thesis, and final decisions were directed by me.
- AI was used as a development collaborator, not as a replacement for product judgment.

## Sources And Collaborators

- Public photographer/reference imagery and Unsplash reference sources informed the training/reference image set for the academic prototype.
- Renee and other informal photographer/user conversations informed the problem framing.
- Some reference material in this repository is for academic demonstration only and should be license-reviewed or replaced before production use.

## What I Would Add Next

If I had more time, I would add:

1. A full evidence-backed style distillation pipeline for multiple photographers and categories.
2. Real multimodal cloud analysis over subject selfies, scene photos, and short videos.
3. Closed-loop live coaching that continuously checks whether users followed the guidance.
4. More robust native camera controls for focus, exposure, white balance, depth, zoom, and burst capture.
5. Secure backend proxy, database persistence, authentication, and user accounts.
6. Photographer onboarding, consent, licensing, and revenue sharing.
7. More moments beyond graduation: wedding, anniversary, family, travel, and parenthood.

## Project Status

Blooming Moments is a high-fidelity, phone-testable prototype. It demonstrates the core product idea: AI should help people capture real moments with more taste, not replace those moments with generated images.
