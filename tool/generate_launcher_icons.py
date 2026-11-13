"""Generates the Android launcher icon variants from a single source of truth.

`assets/icon/app_icon.png` is the icon design (the app's ballot glyph). This
script bakes it into one icon per variant listed in `VARIANTS` below, so every
variant shares the glyph and differs only in its background color:

  * an adaptive-icon background drawable in the variant's seed color,
  * an adaptive-icon foreground (the glyph tinted for that background), plus
  * a legacy square icon in the seed color for API < 26.

The variant ids and seed colors here are the contract with
`lib/services/launcher_icon_service.dart`: the Dart service derives the icon
list the user picks from from the same aliases, and each alias needs a
matching `<activity-alias>` entry in AndroidManifest.xml. Change all three
together.

Run from the repository root after editing the source icon or the variant list:

    python3 tool/generate_launcher_icons.py
"""

from __future__ import annotations

import os
import subprocess
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
RES_DIR = REPO_ROOT / "android" / "app" / "src" / "main" / "res"
SOURCE_ICON = REPO_ROOT / "assets" / "icon" / "app_icon.png"

# `id` doubles as the resource-name suffix, so it must stay lowercase ASCII.
VARIANTS = (
    # Material 500 tones, matching the seed colors the app offers.
    {"id": "deep_purple", "seed": "#673AB7", "foreground": "#EDE7F6"},
    {"id": "blue", "seed": "#2196F3", "foreground": "#E3F2FD"},
    {"id": "teal", "seed": "#009688", "foreground": "#E0F2F1"},
    {"id": "green", "seed": "#4CAF50", "foreground": "#E8F5E9"},
    {"id": "orange", "seed": "#FF9800", "foreground": "#FFF3E0"},
    {"id": "red", "seed": "#F44336", "foreground": "#FFEBEE"},
    {"id": "pink", "seed": "#E91E63", "foreground": "#FCE4EC"},
    {"id": "cyan", "seed": "#00BCD4", "foreground": "#E0F7FA"},
    {"id": "indigo", "seed": "#3F51B5", "foreground": "#E8EAF6"},
    {"id": "amber", "seed": "#FFC107", "foreground": "#FF8F00"},
)

# Legacy square icons are rasterized at these densities (px, square).
LEGACY_SIZES = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}

# Adaptive icons declare 108dp with a 72dp safe zone, so the glyph is drawn at
# 1000px inside a 1500px canvas (the xxxhdpi foreground is 432px).
FOREGROUND_CANVAS = 1500
FOREGROUND_GLYPH = 1000


def write_background(variant: dict[str, str]) -> None:
    """Writes the adaptive-icon background drawable of [variant]."""
    path = RES_DIR / "drawable" / f"ic_launcher_background_{variant['id']}.xml"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<shape xmlns:android="http://schemas.android.com/apk/res/android">\n'
        f'    <solid android:color="{variant["seed"]}" />\n'
        "</shape>\n"
    )


def write_adaptive_icon(variant: dict[str, str]) -> None:
    """Writes the adaptive-icon definition of [variant]."""
    path = RES_DIR / "mipmap-anydpi-v26" / f"ic_launcher_{variant['id']}.xml"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@drawable/ic_launcher_background_'
        f'{variant["id"]}" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground_'
        f'{variant["id"]}" />\n'
        "</adaptive-icon>\n"
    )


def glyph_mask(size: int) -> Path:
    """Returns a temporary [size]-px PNG carrying the source glyph's alpha.

    The alpha channel is extracted into a grayscale mask so it can be reused
    as an ImageMagick `CopyOpacity` source: that is what makes the flat tint
    below follow the glyph outline, including its anti-aliased edges.
    """
    handle, name = tempfile.mkstemp(prefix="vote-glyph-mask-", suffix=".png")
    os.close(handle)
    path = Path(name)
    subprocess.run(
        [
            "magick",
            str(SOURCE_ICON),
            "-resize",
            f"{size}x{size}",
            "-alpha",
            "extract",
            str(path),
        ],
        check=True,
    )
    return path


def tinted(color: str, size: int) -> Path:
    """Returns a temporary [size]-px PNG of the source glyph flattened to [color].

    Only the glyph's silhouette is kept: the artwork's own colors would
    otherwise survive wherever it is opaque, which is what made the variants
    look alike.
    """
    handle, name = tempfile.mkstemp(prefix="vote-glyph-", suffix=".png")
    os.close(handle)
    path = Path(name)
    mask_path = glyph_mask(size)
    try:
        subprocess.run(
            [
                "magick",
                "-size",
                f"{size}x{size}",
                f"xc:{color}",
                str(mask_path),
                "-alpha",
                "off",
                "-compose",
                "copy_opacity",
                "-composite",
                str(path),
            ],
            check=True,
        )
    finally:
        mask_path.unlink(missing_ok=True)
    return path


def write_foreground(variant: dict[str, str]) -> None:
    """Writes the adaptive-icon foreground assets of [variant].

    Adaptive icons draw the foreground over the seed-colored background and
    then mask it, so the source glyph is flattened to a light tint of that seed
    color instead of keeping its own dark artwork.
    """
    for density, size in LEGACY_SIZES.items():
        canvas = round(FOREGROUND_CANVAS * size / 192)
        glyph = round(FOREGROUND_GLYPH * size / 192)
        path = (
            RES_DIR
            / f"mipmap-{density}"
            / f"ic_launcher_foreground_{variant['id']}.png"
        )
        path.parent.mkdir(parents=True, exist_ok=True)
        tinted_path = tinted(variant["foreground"], glyph)
        try:
            subprocess.run(
                [
                    "magick",
                    "-size",
                    f"{canvas}x{canvas}",
                    "xc:none",
                    str(tinted_path),
                    "-gravity",
                    "center",
                    "-compose",
                    "over",
                    "-composite",
                    str(path),
                ],
                check=True,
            )
        finally:
            tinted_path.unlink(missing_ok=True)


def write_legacy(variant: dict[str, str]) -> None:
    """Writes the pre-API-26 square launcher icon of [variant].

    Below API 26 there is no adaptive icon and no mask, so the icon has to
    carry its own background: the seed-colored square the legacy launchers
    show, with the source artwork dropped in at its center.
    """
    for density, size in LEGACY_SIZES.items():
        glyph = round(size * 0.66)
        path = RES_DIR / f"mipmap-{density}" / f"ic_launcher_{variant['id']}.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        tinted_path = tinted(variant["foreground"], glyph)
        try:
            subprocess.run(
                [
                    "magick",
                    "-size",
                    f"{size}x{size}",
                    f"xc:{variant['seed']}",
                    str(tinted_path),
                    "-gravity",
                    "center",
                    "-compose",
                    "over",
                    "-composite",
                    str(path),
                ],
                check=True,
            )
        finally:
            tinted_path.unlink(missing_ok=True)


def res_dirs() -> list[Path]:
    """Returns the density folders that hold launcher icon bitmaps.

    Every variant ships both the legacy square icon and the adaptive foreground
    in each of them, so both file families have to be checked for leftovers.
    """
    return [RES_DIR / f"mipmap-{density}" for density in LEGACY_SIZES]


def variant_id_of(file_name: str) -> str | None:
    """Returns the variant a generated launcher icon file belongs to.

    Returns `None` for the app-wide default `ic_launcher` icon, which is not
    tied to a variant.
    """
    if not file_name.startswith("ic_launcher_"):
        return None
    suffix = file_name[len("ic_launcher_") :]
    if suffix in ("icon.png", "round.png"):
        return None
    for prefix in ("background_", "foreground_"):
        if suffix.startswith(prefix):
            suffix = suffix[len(prefix) :]
            break
    return suffix.rsplit(".", 1)[0]


def remove_stale() -> None:
    """Deletes variant assets whose id is no longer listed in [VARIANTS]."""
    known = {variant["id"] for variant in VARIANTS}
    folders = [RES_DIR / "drawable", RES_DIR / "mipmap-anydpi-v26", *res_dirs()]
    for folder in folders:
        if not folder.is_dir():
            continue
        for path in sorted(folder.iterdir()):
            variant_id = variant_id_of(path.name)
            if variant_id is None or variant_id in known:
                continue
            path.unlink()
            print(f"removed stale {path.relative_to(REPO_ROOT)}")


def main() -> None:
    if not SOURCE_ICON.is_file():
        raise SystemExit(f"missing source icon: {SOURCE_ICON}")
    remove_stale()
    for variant in VARIANTS:
        write_background(variant)
        write_adaptive_icon(variant)
        write_foreground(variant)
        write_legacy(variant)
        print(f"generated ic_launcher_{variant['id']} ({variant['seed']})")


if __name__ == "__main__":
    main()
