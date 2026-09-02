#!/usr/bin/env python3
"""Generate AppIcon-1024.png via gpt-image-2 on api.shu.cool.

Auth: SHU_API_KEY (optional SHU_BASE_URL). Never prints the key.

Note: as of 2026-09, api.shu.cool returns
`Transparent background is not supported for this model` for gpt-image-*.
Default here still requests transparent; pass --opaque for a reliable opaque PNG,
then chroma-key locally if you need alpha.
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUT = ROOT / "Resources" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon-1024.png"
BASE_URL = os.environ.get("SHU_BASE_URL", "https://api.shu.cool/v1").rstrip("/")
MODEL = "gpt-image-2"
HTTP_TIMEOUT = 300

DEFAULT_PROMPT = (
    "macOS application icon glyph for a photo lasso-crop utility. "
    "Centered subject only: a refined champagne-gold freehand lasso loop "
    "interlocking with a thin metallic square crop frame, subtle brushed-metal "
    "and lacquer highlights, elegant and minimal, high contrast silhouette that "
    "reads clearly at small Dock sizes. "
    "Fully transparent background (alpha), no backdrop, no floor, no drop shadow plate, "
    "no checkerboard, no text, no letters, no watermark."
)


def die(msg: str, code: int = 2) -> None:
    print(msg, file=sys.stderr)
    raise SystemExit(code)


def api_key() -> str:
    key = (os.environ.get("SHU_API_KEY") or "").strip()
    if not key:
        die("缺少 SHU_API_KEY")
    return key


def post_generate(prompt: str, quality: str, transparent: bool) -> dict:
    payload = {
        "model": MODEL,
        "prompt": prompt,
        "size": "1024x1024",
        "quality": quality,
        "output_format": "png",
        "background": "transparent" if transparent else "opaque",
        "moderation": "low",
        "n": 1,
    }
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        f"{BASE_URL}/images/generations",
        data=body,
        method="POST",
        headers={
            "Authorization": f"Bearer {api_key()}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=HTTP_TIMEOUT) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")
        die(f"HTTP {exc.code} {exc.reason}: {detail[:2000]}")
    except urllib.error.URLError as exc:
        die(f"请求失败: {exc.reason}")


def decode_image(data: dict) -> bytes:
    items = data.get("data") or []
    if not items:
        die(f"响应没有图片: {list(data.keys())}")
    item = items[0]
    if item.get("b64_json"):
        return base64.b64decode(item["b64_json"])
    if item.get("url"):
        with urllib.request.urlopen(item["url"], timeout=120) as resp:
            return resp.read()
    die(f"图片缺少 b64_json/url: {list(item.keys())}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate LassoCropper AppIcon via gpt-image-2")
    parser.add_argument("--prompt", default=DEFAULT_PROMPT)
    parser.add_argument("--quality", default="high", choices=["low", "medium", "high"])
    parser.add_argument("--opaque", action="store_true", help="Use opaque background instead of transparent")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    print(f"POST {BASE_URL}/images/generations model={MODEL} transparent={not args.opaque}", flush=True)
    data = post_generate(args.prompt, args.quality, transparent=not args.opaque)
    blob = decode_image(data)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_bytes(blob)
    print(f"wrote {args.out} ({len(blob)} bytes)")

    try:
        from PIL import Image

        image = Image.open(args.out)
        print(f"mode={image.mode} size={image.size}")
        if image.mode == "RGBA":
            print(f"alpha_range={image.getextrema()[3]}")
    except Exception as exc:
        print(f"pillow check skipped: {exc}")


if __name__ == "__main__":
    main()
