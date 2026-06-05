# Graduation Demo Video Script

This is a speaking script for a simulator or phone walkthrough. It answers the four required video questions while showing the Graduation flow.

## Opening: Why I Built This

Hi, my project is called Blooming Moments. It is an AI-assisted photography director for important life moments, and this demo focuses on a graduation flow.

I built this because I noticed a bottleneck in tasteful photography. For moments like graduation, weddings, anniversaries, or family milestones, people want real memories. They do not want an AI-generated fake image of the event. They want the actual people, the actual place, and the actual feeling, but captured more beautifully.

Professional photographers can do this because they bring taste: they understand light, composition, posing, emotion, and timing. But good photographers are expensive, hard to schedule, and physically limited to one place and one session at a time. On the other side, many people want better photos, but they only have a phone and maybe a friend taking the picture.

The broader question I wanted to explore is whether taste can be distributed through AI in a way that helps both sides. Users get more accessible creative guidance, and photographers could eventually share their portfolio taste and receive value from it. This is also a reaction to what I think of as AI flop: generic AI content that may be efficient, but loses human taste and personality.

## Product Overview

The ideal version of Blooming Moments works like this. A photographer contributes a curated portfolio. The backend analyzes that portfolio and distills a style profile: what kinds of light they prefer, how they frame people, how much environment they preserve, what poses feel natural, and what post-capture edits match their taste.

Then a user chooses a portfolio style, uploads a selfie so the app understands who should be protected in the photo, captures a scene, and receives guidance. The app tells the photographer where to stand, where the subjects should stand, how to face the light, and what kind of natural pose to try. Finally, it captures a real photo and fine-tunes the real pixels. The important design decision is that Blooming does not regenerate the photo. It improves the real moment.

For this class submission, what I built is a high-fidelity working demo of that flow. Some parts are real, like the iPhone camera, on-device face detection, local voice coaching, and CoreImage fine-tune. Some parts are contract-shaped demo logic or cloud-ready but not fully production AI yet.

## Walkthrough Step 1: Choose Graduation And Portfolio

Here I start on the app and choose the Graduation flow. The user is not choosing a generic filter. They are choosing a photographic taste source.

In the full product, these portfolios would come from photographers who opt in. The backend would distill their visual style into a structured profile. In this demo, I use a local graduation style profile and bundled reference imagery to represent that idea.

When I open the portfolio, the app shows the mood and reference images. The user adopts this style, which means the rest of the flow should try to guide the shoot according to this portfolio's taste.

## Walkthrough Step 2: Subject Selfie

Next, the app asks who will be in the photo. This is important because the system needs to know who should be protected in the final shot.

Here I capture or confirm a selfie. In the current build, the app can use on-device Apple Vision face detection to estimate whether faces are visible and how many protected subjects are present. If Vision is unavailable, it uses a clearly labeled deterministic fallback so the demo can continue.

This step produces backend-style data such as a protected subject set, a subject count, confidence, and readiness notes. In a production version, this could combine on-device vision with cloud multimodal analysis.

## Walkthrough Step 3: Scene Input

After the subject is known, the user chooses the scene. There are two paths: scan surroundings or use current scene.

The reason this matters is that good photography is not only about the person. It is also about light, background, distance, and whether the scene has useful affordances: an arch, a tower, a wall, a patch of soft light, or space for people to stand.

In the ideal product, this scene input would be sent to a multimodal model. The model would analyze the image or video and return a shot plan. In the current demo, there is a cloud-first provider path for DigitalOcean and Gemini if credentials are configured, plus a deterministic local fallback so the demo is reliable.

The output is structured: stand point, subject position, operator position, facing direction, rough framing, coaching cues, camera recommendations, and post-capture edit signals.

## Walkthrough Step 4: Live Coaching

Now the app enters live coaching. This is where the product becomes different from a normal camera app.

The app is not just showing a pretty UI. It is translating the selected portfolio style and the current scene into concrete direction. It can show where to stand, what framing to keep, whether to step back, whether faces are in usable light, and whether the camera is ready.

In the current build, I added a local voice coaching layer. So during the final camera step, the app can speak short prompts like: hold the phone lower, stand inside the guide, turn toward soft light, hold hands, lean in slightly, and capture when ready. This is important because during a real shoot, the subject may not be looking at the screen.

## Walkthrough Step 5: Final Capture

Now I open the final camera. This uses a custom AVFoundation camera surface, because I learned that an iOS app cannot simply remote-control the built-in Apple Camera app UI.

The app gives visual guidance and voice prompts. The photographer can use the guide to frame the shot. In a production version, the live coach would continuously evaluate camera frames and check if the user actually followed the guidance. The current version has the UI and contract path for that, but the full closed-loop intelligence is future work.

The user captures the real photo. This becomes photo A, the original final capture.

## Walkthrough Step 6: Fine Tune And Save

After capture, the app goes to the fine-tune stage. The important point is that this is not image generation. It is a real pixel edit of the captured photo.

The current implementation uses CoreImage to crop and apply a warm editorial fine-tune inspired by the graduation training set. It adjusts things like exposure, contrast, saturation, warmth, highlight/shadow balance, and crispness. The goal is to make the real photo closer to the selected taste profile while preserving the actual moment.

Then the user can save the result into My Blooming Moments.

## Technical Summary

Technically, this is a SwiftUI iOS app. It includes:

- AVFoundation camera capture.
- Apple Vision face detection for subject selfie analysis.
- Backend-style Swift contracts for scene analysis, scene planning, live readiness, and final capture handoff.
- A cloud-ready scene planning provider that can route through DigitalOcean first and Gemini as fallback.
- Local fallback logic for reliable demo recording.
- A structured runtime style profile JSON.
- CoreImage post-capture rendering.
- AVSpeechSynthesizer for voice coaching.

I used Codex heavily as my coding partner, and I also used Claude and Gemini at different points for review, planning, and prototype thinking. The product concept, UX direction, problem framing, and final decisions were my own.

## Evaluation And Learning

I evaluated the idea through informal user conversations, photographer feedback, product pivots, and technical testing.

One important input was a conversation with Renee, a photographer I met online. That conversation gave me more confidence that photographers may be interested in scaling their taste and reaching more people, as long as the product respects their creative value. I also spoke informally with people who had gone through graduation, wedding, or milestone photography decisions, and they described similar pain points around taste matching, price, and scheduling.

Before this project, I tried two other ideas. One was a privacy redaction assistant for prompts sent to LLMs. I found that consumer redaction was hard because rule-based redaction can remove context users actually need. The second was a social media co-pilot. That exposed the AI flop problem more clearly: AI could make writing faster, but it often flattened personal voice into generic content.

Those failures led me to this project. Blooming Moments became a way to ask whether AI can support human taste rather than erase it.

On the technical side, I tested the app on a physical iPhone, ran Swift typechecks, ran Xcode simulator builds, and repeatedly tested the graduation flow. I also learned a lot about software process: branch management, commits, rollback, and coordinating AI coding agents. My commit history is not as complete as I would like because this was my first full app development project, but that became one of my biggest engineering lessons.

For sources, some prototype reference images came from public photographer/reference imagery and Unsplash-style sources. Before a production launch, those assets would need explicit licensing review or replacement with fully licensed photographer portfolios.

## Impact And Use Cases

The immediate use cases are graduation, weddings, anniversaries, family moments, travel, and other happy milestones. The social value is making tasteful photography more accessible while still respecting the real moment.

Longer term, I imagine Blooming as a marketplace between users, photographers, and AI. Users get better guidance. Photographers can distribute their taste beyond their physical schedule and geography. AI becomes a collaborator with creative workers, not just a system that absorbs their work without clear value sharing.

## What I Would Add Next

If I had more time, I would complete the full AI pipeline:

1. Evidence-backed style distillation from real photographer portfolios.
2. Multimodal cloud analysis for selfies, scene photos, and short scene videos.
3. Closed-loop live coaching that verifies whether users followed the guidance.
4. More camera controls for focus, exposure, white balance, zoom, depth, and burst capture.
5. A secure backend proxy, database, user accounts, and photographer marketplace.
6. Consent, licensing, and revenue sharing for photographers.

So the demo today is not the full production system. It is a working prototype of the core idea: AI should help people capture real blooming moments with more taste, not replace those moments with artificial ones.
