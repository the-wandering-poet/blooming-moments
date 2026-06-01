#!/usr/bin/env python3
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont


def load_font(size: int, bold: bool = False):
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Supplemental/Helvetica.ttc",
        "/System/Library/Fonts/SFNSText.ttf",
    ]
    for candidate in candidates:
        path = Path(candidate)
        if path.exists():
            try:
                return ImageFont.truetype(str(path), size=size)
            except OSError:
                continue
    return ImageFont.load_default()


def denormalize(zone: dict, width: int, height: int):
    zone_w = zone["normalizedWidth"] * width
    zone_h = zone["normalizedHeight"] * height
    x = zone["normalizedCenterX"] * width - zone_w / 2
    y = zone["normalizedCenterY"] * height - zone_h / 2
    return [x, y, x + zone_w, y + zone_h]


def draw_guided_capture(original_path: Path, guidance: dict, scenario: str, output_path: Path):
    base = Image.open(original_path).convert("RGBA")
    overlay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    width, height = base.size

    draw.rectangle([(0, 0), (width, height)], fill=(8, 8, 8, 48))

    zone = guidance["placement"]["subjectZone"]
    rect = denormalize(zone, width, height)
    draw.rounded_rectangle(rect, radius=24, outline=(242, 206, 74, 255), width=8)

    bold = load_font(28, bold=True)
    body = load_font(22)
    small = load_font(20, bold=True)

    label_box = [rect[0] + 24, rect[1] - 52, rect[0] + 220, rect[1] - 8]
    draw.rounded_rectangle(label_box, radius=20, fill=(242, 206, 74, 255))
    draw.text((label_box[0] + 18, label_box[1] + 10), f'{zone["action"]} here', fill=(20, 20, 20), font=small)

    origin = guidance["sceneAnalysis"]["cameraOrigin"]
    start = (origin["normalizedX"] * width, origin["normalizedY"] * height)
    end = ((rect[0] + rect[2]) / 2, (rect[1] + rect[3]) / 2)
    draw.line([start, end], fill=(242, 206, 74, 255), width=5)

    camera_box = [start[0] - 44, start[1] - 18, start[0] + 64, start[1] + 22]
    draw.rounded_rectangle(camera_box, radius=18, fill=(18, 18, 18, 190))
    draw.text((camera_box[0] + 16, camera_box[1] + 8), "camera", fill=(255, 255, 255), font=small)

    banner = [28, 28, width - 28, 88]
    draw.rounded_rectangle(banner, radius=22, fill=(18, 18, 18, 188))
    readiness = guidance["readiness"]
    draw.text((46, 44), f'{scenario.upper()}  READY {readiness["score"]}', fill=(255, 255, 255), font=bold)

    panel = [24, height - 300, width - 24, height - 24]
    draw.rounded_rectangle(panel, radius=26, fill=(16, 16, 16, 198))
    draw.text((panel[0] + 18, panel[1] + 18), "Placement + Pose", fill=(242, 206, 74), font=bold)
    draw.text((panel[0] + 18, panel[1] + 66), guidance["placement"]["movementCue"], fill=(255, 255, 255), font=body)
    draw.text((panel[0] + 18, panel[1] + 116), guidance["pose"]["bodyArrangement"], fill=(255, 255, 255), font=body)
    camera_line = (
        f'Lens {guidance["cameraSettings"]["lens"]}  '
        f'Zoom {guidance["cameraSettings"]["zoomFactor"]:.1f}x  '
        f'EV {guidance["cameraSettings"]["exposureBiasEV"]:.1f}  '
        f'Sat {guidance["cameraSettings"]["saturation"]:.2f}'
    )
    draw.text((panel[0] + 18, panel[1] + 192), camera_line, fill=(255, 255, 255), font=body)

    guided = Image.alpha_composite(base, overlay).convert("RGB")
    guided.save(output_path)


def apply_edit(guided_path: Path, guidance: dict, output_path: Path):
    plan = guidance["postCaptureEdit"]
    image = Image.open(guided_path).convert("RGB")
    image = ImageEnhance.Brightness(image).enhance(1.0 + plan["brightnessDelta"])
    image = ImageEnhance.Contrast(image).enhance(1.0 + plan["contrastDelta"])
    image = ImageEnhance.Color(image).enhance(1.0 + plan["saturationDelta"])

    warm = Image.new("RGB", image.size, (255, 214, 170))
    image = Image.blend(image, warm, min(0.18, max(0.0, plan["warmthDelta"])))

    vignette = Image.new("L", image.size, 0)
    vignette_draw = ImageDraw.Draw(vignette)
    inset = int(min(image.size) * 0.06)
    vignette_draw.ellipse(
        (inset, inset, image.size[0] - inset, image.size[1] - inset),
        fill=255,
    )
    vignette = vignette.filter(ImageFilter.GaussianBlur(radius=min(image.size) // 10))
    dark = Image.new("RGB", image.size, (10, 8, 6))
    image = Image.composite(image, Image.blend(image, dark, plan["vignette"]), vignette)
    image.save(output_path)


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: render_artifacts.py <demo-output-dir>")

    root = Path(sys.argv[1])
    manifest = json.loads((root / "demo-manifest.json").read_text())
    for scenario in manifest["scenarios"]:
        guidance = json.loads(Path(scenario["guidanceJSONPath"]).read_text())
        original = Path(scenario["originalSceneImagePath"])
        guided = Path(scenario["guidedCaptureImagePath"])
        edited = Path(scenario["editedImagePath"])

        draw_guided_capture(original, guidance, scenario["scenario"], guided)
        apply_edit(guided, guidance, edited)


if __name__ == "__main__":
    main()
