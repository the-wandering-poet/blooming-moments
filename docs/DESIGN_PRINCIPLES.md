# Blooming Design Principles

Last updated: June 1, 2026

## Visual Direction

Blooming should feel airy, editorial, and quietly premium: soft powder-blue light, warm ivory paper, muted olive accents, refined serif typography, and delicate botanical details. The UI should feel closer to a photography studio mood board than a generic camera utility.

## Core Palette

| Token | Hex | RGB | Role |
| --- | --- | --- | --- |
| `powderBlue` | `#E4EBF1` | `228, 235, 241` | Main atmospheric backdrop. Use for welcome/home headers and soft full-screen surfaces. |
| `powderBlueShadow` | `#E0E8F0` | `224, 232, 240` | Slightly deeper blue for gradients, image shadows, and depth. |
| `olive` | `#6B7251` | `107, 114, 81` | Brand logo, primary CTA, selected states, and botanical accents. |
| `oliveButton` | `#6E714F` | `110, 113, 79` | Primary button fill when the button needs more body. |
| `warmIvory` | `#FAF6EF` | `250, 246, 239` | Paper sheets, card surfaces, and calm empty space. |
| `creamShadow` | `#F0EBE3` | `240, 235, 227` | Warm card depth, bottom sheet shadows, and image backgrounds. |
| `softPaper` | `#F6F1ED` | `246, 241, 237` | Light card interiors and image-safe panels. |
| `ink` | `#2F302C` | `47, 48, 44` | Primary text on light backgrounds. |

## Color Balance

- Use `powderBlue` as the emotional atmosphere, not as a flat block. It should usually have gentle texture, soft light, or a gradient.
- Use `warmIvory` and `softPaper` to keep the page breathable; the app should not become blue-only.
- Use `olive` sparingly but decisively: logo, primary CTA, active selection, thin borders, and small botanical marks.
- Avoid saturated blue, bright green, pure white, and harsh black on the main editorial screens.
- Let color proportion follow the screen's job. A welcome or home screen can lean heavily into blue atmosphere, while camera, coaching, upload, and review screens may use more ivory, dark camera chrome, or photo-first surfaces.

## Typography

| Use | Font | Current SwiftUI Token | Notes |
| --- | --- | --- | --- |
| Brand wordmark | Logo asset | `BloomingLogo` image asset | Do not recreate the wordmark with live text. Use the transparent image asset so the connected flower sprig stays consistent. |
| Hero titles | `BodoniSvtyTwoITCTT-Book` | `AppType.welcomeHero`, `AppType.homeHero`, `AppType.hero` | Use for poetic, editorial statements such as "Let the moments bloom." and "What's blooming now?" |
| Screen titles | `BodoniSvtyTwoITCTT-Book` | `AppType.screenTitle`, `AppType.sectionTitle` | Use for portfolio and flow screens where the title should still feel editorial. |
| Scene/card titles | `BodoniSvtyTwoSCITCTT-Book` or `BodoniSvtyTwoITCTT-Book` | `AppType.sceneTitle`, `AppType.cardTitle` | Use on large visual cards like Graduation, Wedding, Anniversary, and photographer portfolio cards. |
| Body copy | `AvenirNext-Regular` | `AppType.body`, `AppType.caption` | Use for concise guidance and descriptions. Keep it quiet and readable. |
| Labels/chips | `AvenirNext-DemiBold` | `AppType.chip`, `AppType.micro` | Use uppercase with generous tracking for small labels, recipe tags, and state indicators. |
| Profile/list names | `AvenirNext-DemiBold` | `AppType.profileName`, `AppType.profileItemTitle` | Use where clarity matters more than editorial drama. |

General typography rules:

- Keep serif type large and sparse; do not use it for dense instructions.
- Use Avenir Next for functional UI text, coaching cues, and metadata.
- Keep supporting labels uppercase, widely tracked, and muted olive or gray.
- Body copy should stay minimal; most screens should have one short instruction rather than explanatory paragraphs.

## Surface Rules

- Rounded cards should feel like paper or printed editorial panels, not heavy app cards.
- Prefer thin olive or ivory borders over dark strokes.
- Use shadows softly; no hard drop shadows.
- Keep flowers/botanical details delicate and low-contrast unless they are part of an image asset.

## SwiftUI Reference

```swift
enum BloomingDesignColor {
    static let powderBlue = Color(red: 228/255, green: 235/255, blue: 241/255)
    static let powderBlueShadow = Color(red: 224/255, green: 232/255, blue: 240/255)
    static let olive = Color(red: 107/255, green: 114/255, blue: 81/255)
    static let oliveButton = Color(red: 110/255, green: 113/255, blue: 79/255)
    static let warmIvory = Color(red: 250/255, green: 246/255, blue: 239/255)
    static let creamShadow = Color(red: 240/255, green: 235/255, blue: 227/255)
    static let softPaper = Color(red: 246/255, green: 241/255, blue: 237/255)
    static let ink = Color(red: 47/255, green: 48/255, blue: 44/255)
}
```

## Source References

- Welcome artwork: `AIPhotographer/Assets.xcassets/WelcomePageArtwork.imageset/welcome-page-artwork.png`
- Wordmark asset: `AIPhotographer/Assets.xcassets/BloomingLogo.imageset/blooming-logo.png`
- Current reference copy: `references/uiux/blooming-welcome-reference.png`
