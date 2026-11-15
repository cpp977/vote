"""Generates the Android launcher icon variants from a single source of truth.

`assets/icon/app_icon.png` is the icon design: a rounded plate carrying a
ballot box, a folded ballot and a check mark. This script bakes it into one icon
per variant listed in `VARIANTS` below. Every variant keeps the illustration as
drawn -- the ballot box, the folded ballot and the white check mark keep their
own colors -- and only the plate behind them takes that variant's color:

  * an adaptive-icon background drawable, in the variant's seed color,
  * an adaptive-icon foreground: the artwork with its plate recolored, plus
  * a legacy square icon that is the same, cropped to a full-bleed square.

## Recoloring instead of tinting

The plate covers four fifths of the canvas, so a flat tint of the whole artwork
leaves a plain colored square with no illustration left on it. What the launcher
shows instead is the design's own look -- a plate carrying the ballot box, the
folded ballot and the check mark -- in the color the variant is named after.

## Telling the plate from the illustration

The plate is a purple gradient, so it has no single color to match, but it never
leaves the violet band ([PLATE_HUE_LOW], [PLATE_HUE_HIGH]), while the
illustration does: the ballot box is teal (~172 degrees), the folded ballot olive
(~86) and the card blue (~205), and the check mark is white and has no hue at
all. Hue and saturation together are therefore enough to tell the two apart.

The test runs on a blurred copy of the artwork and its result is blurred again.
Without that, the pixels that blend plate into illustration along their shared
edge are classified by whichever of the two wins the blend, and the cut-out grows
a one-pixel fringe of the wrong class around every shape -- which shows up in the
finished icon as a thin outline traced around the illustration.

## What is taken from the seed, and what is kept from the artwork

The recolored plate takes its hue and its saturation from the variant's seed
color and **keeps the artwork's own lightness, pixel for pixel**. That is the
whole trick, and both halves of it matter:

  * keeping the lightness is what makes the plate look like the artwork rather
    than like a colored tile. The source plate is a gradient running from L=0.47
    at its top edge down to L=0.26 at its base, and that gradient is what makes
    the ballot box and the check mark stand off the plate;
  * not taking the seed's lightness is what keeps a light seed from washing the
    icon out. A Material tone sits around L=0.50-0.58, so a plate filled with the
    raw seed is a pale slab -- worst for amber and cyan, which are pastel to
    begin with -- and the white check mark and the olive ballot disappear into
    it. Deriving the plate from the seed's lightness instead would only move the
    problem to the other end, where indigo and deep purple crush the
    illustration's shadows.

Only the saturation is scaled ([PLATE_SATURATION_SCALE]), because the source
plate is a muted purple at about 50% saturation: copying that muted level to
every variant would leave the vivid seeds (cyan, amber) looking grey, while
copying the seed's saturation outright would let a fully saturated fill compete
with the illustration's own teal and olive.

## Which assets carry the recolored plate

The launcher on API 26+ draws the background drawable itself and puts the
foreground on top of it, and it also themes the pair when the user turns themed
icons on. So the roles are split:

  * the background drawable is the variant's plain seed color. That is what the
    launcher themes, and what the app's own settings menu shows next to the icon
    (see `_LauncherIconBadge`), so it stays the plain tone the variant is named
    after. It is also only ever seen in the corners of the 108dp canvas, which
    the launcher's mask crops away,
  * the foreground is the recolored artwork, centered at 1000px in a 1500px
    canvas. The launcher masks the foreground to its own outline, and the
    artwork's plate is drawn at exactly the size of the adaptive icon's 72dp
    visible area, so the plate lands where the launcher's mask expects it,
  * the legacy square icon has no drawable behind it and no mask to crop it, so
    it is the same recolored artwork scaled up past the square and cropped to it:
    a full-bleed square with the plate running off every edge, which is what the
    launchers of that era draw.

The variant ids and colors here are the contract with
`lib/services/launcher_icon_service.dart`: the Dart service derives the icon list
the user picks from from the same colors, and each alias needs a matching
`<activity-alias>` entry in AndroidManifest.xml. Change all three together.

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
# `seed` is the color the plate is derived from and `foreground` the light tint
# the in-app menu previews the icon with.
VARIANTS = (
    # Material tones, matching the seed colors the app offers.
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

# Adaptive icons declare 108dp with a 72dp safe zone, so the artwork is drawn at
# 1000px inside a 1500px canvas (the xxxhdpi foreground is 432px).
FOREGROUND_CANVAS = 1500
FOREGROUND_GLYPH = 1000

# The legacy square icon has no mask to crop it into a shape, so it draws its own
# plate edge to edge: the artwork is scaled up past the square and cropped to it,
# which puts the plate's rounded corners outside the icon. The factor has to stay
# above ~1.15, or the corners of the square fall outside the plate and the icon
# ends up with transparent notches in them.
LEGACY_BLEED = 1.35

# Hue band the artwork's plate stays inside, in degrees (see the module
# docstring). The illustration is outside it.
PLATE_HUE_LOW = 250
PLATE_HUE_HIGH = 290
PLATE_MIN_SATURATION = 0.15

# Radius the mask is blurred by, as a fraction of the image width. Wide enough to
# absorb the plate/illustration blend along their shared edge, narrow enough that
# the plate's own edge moves by well under a pixel at these sizes.
PLATE_BLUR = 0.004

# Saturation of the source plate, in HSL. Measured off `app_icon.png`: the plate
# runs from about 44% to 52%. It is the reference the seed's saturation is scaled
# against -- see the module docstring.
PLATE_SATURATION = 0.5

# How far the plate's saturation may be pushed, relative to the source plate's,
# and the range the result is clamped to.
PLATE_SATURATION_SCALE = 1.0
PLATE_SATURATION_MIN = 0.8
PLATE_SATURATION_MAX = 1.8


def temp_png(prefix: str) -> Path:
    """Returns the path of a new temporary PNG."""
    handle, name = tempfile.mkstemp(prefix=prefix, suffix=".png")
    os.close(handle)
    return Path(name)


def magick(*args: str) -> str:
    """Runs ImageMagick with [args] and returns its standard output."""
    result = subprocess.run(
        ["magick", *args], check=True, capture_output=True, text=True
    )
    return result.stdout


def write_background(variant: dict[str, str]) -> None:
    """Writes the adaptive-icon background drawable of [variant].

    This is the color the launcher themes when the user turns themed icons on,
    and the color the app's settings menu shows next to the icon, so it stays the
    variant's plain seed color rather than the recolored plate the foreground
    carries.
    """
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


def hue_mask(size: int) -> Path:
    """Returns a temporary [size]-px grayscale mask of the artwork's plate.

    White is plate, black is illustration. Both blurs keep the mask off the
    plate/illustration boundary: see the module docstring.
    """
    path = temp_png("vote-hue-mask-")
    blur = max(1, round(size * PLATE_BLUR))
    magick(
        str(SOURCE_ICON),
        "-resize",
        f"{size}x{size}",
        "-blur",
        f"0x{blur}",
        "-alpha",
        "off",
        "-fx",
        f"(hue>({PLATE_HUE_LOW}/360)&&hue<({PLATE_HUE_HIGH}/360)"
        f"&&saturation>{PLATE_MIN_SATURATION})?1:0",
        "-blur",
        f"0x{blur}",
        str(path),
    )
    return path


def plate_alpha(size: int) -> Path:
    """Returns a temporary [size]-px mask of the artwork's plate.

    The hue test only says which pixels are plate; the artwork's own alpha is
    what bounds them, so multiplying the two keeps the silhouette -- the rounded
    corners and the soft drop shadow under the plate -- the way the artwork drew
    it, instead of ending at the hue test's hard edge.
    """
    path = temp_png("vote-plate-alpha-")
    hue = hue_mask(size)
    try:
        magick(
            "(",
            str(SOURCE_ICON),
            "-resize",
            f"{size}x{size}",
            "-alpha",
            "extract",
            ")",
            str(hue),
            "-compose",
            "multiply",
            "-composite",
            str(path),
        )
    finally:
        hue.unlink(missing_ok=True)
    return path


def recolored(size: int, variant: dict[str, str]) -> Path:
    """Returns a temporary [size]-px copy of the artwork with a recolored plate.

    The plate is recolored where it stands rather than cut out and dropped on a
    fresh background: the fill lands exactly where the plate was, so the boundary
    between the plate and the illustration stays where the artwork drew it, and
    the artwork's alpha -- its rounded corners, its anti-aliasing, the shadow it
    casts -- survives untouched. What is left of the artwork, the illustration,
    keeps its own colors, which is what made the original design work.

    Only the hue and the saturation of the plate are replaced; the lightness is
    the artwork's own, pixel for pixel (see the module docstring).
    """
    path = temp_png("vote-recolored-")
    resized = temp_png("vote-resized-")
    candidate = temp_png("vote-candidate-")
    layer = temp_png("vote-plate-layer-")
    alpha = plate_alpha(size)
    try:
        magick(str(SOURCE_ICON), "-resize", f"{size}x{size}", str(resized))
        # A copy of the artwork with the plate's hue and saturation replaced.
        # The alpha has to come off before the colorspace conversion: ImageMagick
        # smears the alpha channel into the HSL channels otherwise, which fringes
        # the whole silhouette.
        #
        # The hue goes in as a percentage and the saturation as a plain factor:
        # `-evaluate set` reads a bare fraction as a percentage of nothing and
        # silently writes zero, which turns the whole plate red, and
        # `-evaluate multiply` reads a percentage as a whole number, which blows
        # the saturation up to a million percent.
        magick(
            str(resized),
            "-alpha",
            "off",
            "-colorspace",
            "HSL",
            "-channel",
            "R",
            "-evaluate",
            "set",
            f"{_hue(variant['seed']) / 3.6:.4f}%",
            "-channel",
            "G",
            "-evaluate",
            "multiply",
            f"{_plate_saturation(variant['seed']):.4f}",
            "+channel",
            "-colorspace",
            "sRGB",
            str(candidate),
        )
        # ... and a version of it that is only visible where the plate is.
        magick(
            str(candidate),
            "(",
            str(alpha),
            ")",
            "-alpha",
            "off",
            "-compose",
            "copy_opacity",
            "-composite",
            str(layer),
        )
        magick(
            str(resized),
            str(layer),
            "-compose",
            "over",
            "-composite",
            str(path),
        )
    finally:
        for temporary in (resized, candidate, layer, alpha):
            temporary.unlink(missing_ok=True)
    return path


def _hue(color: str) -> float:
    """Returns the hue of [color], in degrees."""
    return _hsl_of(color)[0]


def _plate_saturation(seed: str) -> float:
    """Returns how far the seed's saturation pushes the plate's.

    The seed's own saturation, relative to the source plate's and clamped: see
    [PLATE_SATURATION_SCALE] and its neighbours.
    """
    scaled = _hsl_of(seed)[1] / PLATE_SATURATION * PLATE_SATURATION_SCALE
    return min(PLATE_SATURATION_MAX, max(PLATE_SATURATION_MIN, scaled))


def _hsl_of(color: str) -> tuple[float, float, float]:
    """Returns the hue in degrees, the saturation and the lightness of [color]."""
    value = magick(
        f"xc:{color}",
        "-colorspace",
        "HSL",
        "-format",
        "%[fx:360*u.r] %[fx:u.g] %[fx:u.b]",
        "info:",
    ).split()
    return (float(value[0]), float(value[1]), float(value[2]))


def write_icon(variant: dict[str, str]) -> None:
    """Writes the adaptive foreground and the legacy square icon of [variant]."""
    for density, size in LEGACY_SIZES.items():
        write_foreground(variant, density)
        write_legacy(variant, density, size)


def write_foreground(variant: dict[str, str], density: str) -> None:
    """Writes the adaptive-icon foreground of [variant] at [density].

    The recolored artwork is centered in the canvas at
    [FOREGROUND_GLYPH] of [FOREGROUND_CANVAS], which is the adaptive icon's 72dp
    visible area inside its 108dp canvas: the launcher's mask crops the rest, so
    the plate lands where the mask expects it and the corners stay transparent
    for the background drawable behind them.
    """
    canvas = round(FOREGROUND_CANVAS * LEGACY_SIZES[density] / 192)
    glyph = round(FOREGROUND_GLYPH * LEGACY_SIZES[density] / 192)
    path = (
        RES_DIR / f"mipmap-{density}" / f"ic_launcher_foreground_{variant['id']}.png"
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    art = recolored(glyph, variant)
    try:
        magick(
            "-size",
            f"{canvas}x{canvas}",
            "xc:none",
            str(art),
            "-gravity",
            "center",
            "-compose",
            "over",
            "-composite",
            str(path),
        )
    finally:
        art.unlink(missing_ok=True)


def write_legacy(variant: dict[str, str], density: str, size: int) -> None:
    """Writes the pre-API-26 square launcher icon of [variant] at [density].

    Below API 26 there is no adaptive icon and no mask, so the icon draws its own
    square: the recolored artwork scaled up past the square and cropped to it, so
    the plate runs off every edge instead of leaving transparent notches in the
    corners. The few pixels the plate's rounded corners still leave transparent
    are filled with the plate's own color, sampled from the artwork beside them.
    """
    path = RES_DIR / f"mipmap-{density}" / f"ic_launcher_{variant['id']}.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    scaled = max(size + 1, round(size * LEGACY_BLEED))
    art = recolored(scaled, variant)
    cropped = temp_png("vote-legacy-crop-")
    try:
        magick(
            str(art),
            "-gravity",
            "center",
            "-crop",
            f"{size}x{size}+0+0",
            "+repage",
            str(cropped),
        )
        magick(
            "-size",
            f"{size}x{size}",
            f"xc:{_plate_colour(cropped, size)}",
            str(cropped),
            "-compose",
            "over",
            "-composite",
            str(path),
        )
    finally:
        art.unlink(missing_ok=True)
        cropped.unlink(missing_ok=True)


def _plate_colour(image: Path, size: int) -> str:
    """Returns the plate color of [image], as an ImageMagick color string.

    Sampled from the left edge at mid height, which the artwork keeps inside the
    plate for its whole height (the plate spans the full width from a quarter of
    the way down), so the sample is plate rather than background.
    """
    return magick(
        str(image),
        "-format",
        f"%[pixel:p{{{max(0, round(size * 0.02))},{size // 2}}}]",
        "info:",
    ).strip()


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
        write_icon(variant)
        print(f"generated ic_launcher_{variant['id']} ({variant['seed']})")


if __name__ == "__main__":
    main()