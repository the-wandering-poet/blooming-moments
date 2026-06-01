# Backend Shot Matching Logic

The user selects a curated portfolio style, not a single exact photo to copy.
Individual reference shots are browsable so the user can understand the taste, locations, gestures, and composition language.
When shooting begins, the selected portfolio becomes the recipe context for the backend.

## Inputs

- Selected scenario, such as Graduation, Wedding, or Anniversary.
- Selected curated portfolio.
- Portfolio reference images and metadata:
  - location
  - gesture
  - composition notes
  - lighting tags
  - capture technique tags
- Subject reference image.
- User scene input:
  - scan-surrounding video frames, or
  - a direct scene photo.

## Processing

### 1. Scene Similarity

Compare the user's uploaded scene frame against each reference image in the selected portfolio.

The server should estimate:

- location resemblance
- dominant geometry, such as arches, tower, lawn, wall, corridor, table, interior
- light pattern resemblance
- depth and leading-line resemblance
- subject placement feasibility
- clutter and background cleanliness

### 2. If The Scene Closely Matches A Reference

Use the closest portfolio reference as the primary recipe.

The AI coach should adapt:

- subject zone
- camera-holder position
- gesture or action cue
- framing ratio
- light direction
- capture technique
- finishing look

Example: if the uploaded scene resembles the arcade walkaway photo, guide the user toward the same walkaway motion, wide framing, warm side light, and motion-friendly capture.

### 3. If The Scene Does Not Closely Match A Reference

Use the whole portfolio as style context rather than forcing a bad copy.

The AI coach should synthesize:

- the portfolio's shared style DNA
- the strongest available light and background in the user scene
- a new shot plan that feels like the portfolio but fits the real location

Example: if there are no arches, the app should still preserve the selected portfolio's mood, such as landmark scale, warm contrast, motion, or dramatic light, while choosing a different composition.

## Output

Return a structured shot plan:

- `scene_match_type`: `reference_match` or `style_synthesis`
- `matched_reference_id`: optional
- `match_confidence`
- `capture_technique`
- `camera_position`
- `subject_zone`
- `subject_directions`
- `light_usage`
- `key_moment`
- `grooming_check`
- `fallback_if_scene_fails`

## Product Rule

Never tell the user the scene is bad without giving a next action.
The app should either:

- adapt the closest portfolio reference, or
- synthesize a new shot in the selected portfolio style, or
- tell the user exactly what nearby scene to look for.
