#!/usr/bin/env python3
"""
Draw Things img2img pipeline for game-character-64.
Step 1: txt2img → canonical south-facing base sprite
Step 2: img2img(base) → all other directions (preserves character identity)

SETUP: Draw Things → Settings → API Server → Enable (port 7860)
"""

import random
import requests
import base64
import io
import sys
import time
from pathlib import Path
from PIL import Image

API_URL       = "http://localhost:7860"
RUN_DIR       = Path(__file__).parent
GENERATED_DIR = RUN_DIR / "generated"
GENERATED_DIR.mkdir(exist_ok=True)

MAX_RETRIES     = 3
RETRY_WAIT      = 15
RECONNECT_WAIT  = 120
REQUEST_TIMEOUT = 240

NEGATIVE_PROMPT = (
    "blurry, smooth, anti-aliasing, 3d render, photorealistic, realistic, "
    "text, watermark, signature, UI, shadow, floor, gradient background, "
    "multiple characters, extra limbs, deformed, ugly, disfigured, "
    "low quality, worst quality, jpeg artifacts"
)

CHARACTER_BASE = (
    "pixel art, 16-bit RPG game sprite, human knight, full body, "
    "dark navy blue plate armor, silver trim, closed visor helmet, longsword, "
    "flat lime green background (#00ff00), no shadow, no floor, "
    "hard pixel edges, limited palette, SNES style, centered"
)

DIRECTIONS = [
    "south", "south-east", "east", "north-east",
    "north", "north-west", "west", "south-west"
]

BASE_CONFIG = {
    "model": "PixelWave 10 (8-bit)",
    "width": 512, "height": 512,
    "steps": 25, "cfg_scale": 9,
    "sampler_name": "DPM++ 2M Karras",
    "batch_size": 1,
}

IMG2IMG_CONFIG = {
    "width": 512, "height": 512,
    "steps": 25, "cfg_scale": 9,
    "sampler_name": "DPM++ 2M Karras",
    "denoising_strength": 0.55,
}


def wait_for_api():
    print("  Waiting for API...", end="", flush=True)
    for _ in range(RECONNECT_WAIT // 5):
        try:
            if requests.get(f"{API_URL}/sdapi/v1/options", timeout=4).status_code == 200:
                print(" online")
                return True
        except Exception:
            pass
        print(".", end="", flush=True)
        time.sleep(5)
    print(" failed")
    return False


def image_to_b64(img: Image.Image) -> str:
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return base64.b64encode(buf.getvalue()).decode()


def call_api(endpoint: str, payload: dict) -> Image.Image | None:
    """Single-image call; returns first image or None."""
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            r = requests.post(
                f"{API_URL}{endpoint}", json=payload, timeout=REQUEST_TIMEOUT
            )
            r.raise_for_status()
            data = r.json()
            return Image.open(io.BytesIO(base64.b64decode(data["images"][0]))).convert("RGBA")

        except requests.exceptions.Timeout:
            print(f"    Timeout (attempt {attempt}/{MAX_RETRIES}), waiting {RETRY_WAIT}s...")
            time.sleep(RETRY_WAIT)

        except requests.exceptions.ConnectionError:
            print(f"    Connection lost, waiting for Draw Things...")
            if not wait_for_api():
                return None

        except Exception as e:
            print(f"    ERROR: {e}")
            if attempt < MAX_RETRIES:
                time.sleep(RETRY_WAIT)

    return None



def save(img: Image.Image, path: Path, target_size=(64, 64)):
    img = img.resize(target_size, Image.NEAREST)
    img.save(path)


def make_walk_strip(img: Image.Image, cols: int = 6) -> Image.Image:
    """Create a walk strip with vertical bob from a single 512×512 pose."""
    f = img.resize((64, 64), Image.NEAREST)
    # Bob offsets in pixels: simulate weight-shift walk cycle
    offsets = [0, -1, 0, 1, 0, -1]
    strip = Image.new("RGBA", (cols * 64, 64), (0, 0, 0, 0))
    for i, dy in enumerate(offsets[:cols]):
        if dy == 0:
            strip.paste(f, (i * 64, 0))
        else:
            shifted = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
            if dy < 0:
                shifted.paste(f.crop((0, -dy, 64, 64)), (0, 0))
            else:
                shifted.paste(f.crop((0, 0, 64, 64 - dy)), (0, dy))
            strip.paste(shifted, (i * 64, 0))
    return strip


def main():
    print("=== Draw Things Generator (img2img) ===")

    try:
        requests.get(f"{API_URL}/sdapi/v1/options", timeout=5).raise_for_status()
    except Exception:
        print("\nERROR: Draw Things API not reachable.")
        print("  Settings → API Server → Enable (port 7860)")
        sys.exit(1)

    print("API online\n")
    targets = sys.argv[1:] if len(sys.argv) > 1 else None

    session_seed = random.randint(0, 2**31 - 1)
    print(f"Session seed: {session_seed}  (save this to reproduce the same character)\n")

    # ── Step 1: canonical base sprite (south, txt2img) ──────────────────
    base_path = GENERATED_DIR / "base_south.png"
    base_large_path = GENERATED_DIR / "base_south_512.png"  # keep 512px for img2img

    if not base_path.exists():
        print("Step 1: Generating canonical base sprite (south, txt2img)...")
        prompt = f"{CHARACTER_BASE}, facing south, idle standing pose."
        img = call_api("/sdapi/v1/txt2img", {"prompt": prompt,
                                              "negative_prompt": NEGATIVE_PROMPT,
                                              **BASE_CONFIG,
                                              "seed": session_seed})
        if img is None:
            print("FAILED: could not generate base sprite")
            sys.exit(1)
        img.save(base_large_path)           # save 512px for img2img reference
        save(img, base_path)               # save 64px final
        print(f"  ✓ base_south.png\n")
        time.sleep(1)
    else:
        print(f"  Skip base_south.png (exists)\n")
        img = Image.open(base_large_path).convert("RGBA") if base_large_path.exists() else \
              Image.open(base_path).resize((512, 512), Image.NEAREST).convert("RGBA")

    base_img_512 = Image.open(base_large_path).convert("RGBA") \
        if base_large_path.exists() \
        else Image.open(base_path).resize((512, 512), Image.NEAREST).convert("RGBA")
    base_b64 = image_to_b64(base_img_512)

    # ── Step 2: walk strips per direction (img2img) ──────────────────────
    print("Step 2: Generating walk strips (img2img from base)...")
    results = []

    dirs = [d for d in DIRECTIONS if not targets or any(t in d for t in targets)]

    for direction in dirs:
        safe      = direction.replace("-", "_")
        out_path  = GENERATED_DIR / f"walk_{safe}.png"

        if out_path.exists():
            print(f"  Skip walk_{safe}.png (exists)")
            results.append((f"walk_{safe}", "skipped"))
            continue

        prompt = (
            f"{CHARACTER_BASE}, facing {direction}, "
            f"walking pose, mid-stride, full body visible, "
            f"consistent character identity."
        )
        dir_seed = session_seed + dirs.index(direction)
        print(f"  Generating walk-{direction} (seed {dir_seed})...")
        img = call_api("/sdapi/v1/img2img", {
            "prompt": prompt,
            "negative_prompt": NEGATIVE_PROMPT,
            "init_images": [base_b64],
            **IMG2IMG_CONFIG,
            "seed": dir_seed,
        })

        if img is None:
            results.append((f"walk_{safe}", "failed"))
        else:
            strip = make_walk_strip(img, cols=6)
            strip.save(out_path)
            print(f"  ✓ walk_{safe}.png")
            results.append((f"walk_{safe}", "ok"))

        time.sleep(1)

    # ── Summary ───────────────────────────────────────────────────────────
    print("\n=== Summary ===")
    for name, status in results:
        print(f"  {'✓' if status != 'failed' else '✗'} {name} [{status}]")

    failed = [r for r in results if r[1] == "failed"]
    if failed:
        print(f"\n{len(failed)} failed. Re-run: python draw_things_generate.py <direction>")
        sys.exit(1)
    print("\nAll done. Next: python assemble.py")


if __name__ == "__main__":
    main()
