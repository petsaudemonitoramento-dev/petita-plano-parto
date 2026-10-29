#!/usr/bin/env python3
"""Resize/pad the official artwork only; no redrawing or generated character.

Reproduction dependency: Pillow 12.1.1. Runtime and CI builds use committed PNGs.
The monochrome alpha is derived from the source luminance, not a colored photo.
"""
import hashlib
from pathlib import Path
from PIL import Image, ImageDraw, ImageOps

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/branding/Petita_icone_android_1024.png'
EXPECTED = 'bea39885f9277a0d059a1a100c4821320617a56ff21c5d4178ad45cb8429ceb9'
assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == EXPECTED
RES = ROOT / 'android/app/src/main/res'
art = Image.open(SOURCE).convert('RGBA')
pink = (252, 231, 236, 255)


def centered(size, fraction, transparent=False):
    result = Image.new('RGBA', (size, size), (0, 0, 0, 0) if transparent else pink)
    side = round(size * fraction)
    scaled = art.resize((side, side), Image.Resampling.LANCZOS)
    result.alpha_composite(scaled, ((size - side) // 2, (size - side) // 2))
    return result


for density, scale in [('mdpi', 1), ('hdpi', 1.5), ('xhdpi', 2), ('xxhdpi', 3), ('xxxhdpi', 4)]:
    folder = RES / f'mipmap-{density}'
    folder.mkdir(parents=True, exist_ok=True)
    centered(round(48 * scale), .84).save(folder / 'ic_launcher.png')
    fg = centered(round(108 * scale), 60 / 108, transparent=True)
    fg.save(folder / 'ic_launcher_foreground.png')
    luminance = ImageOps.grayscale(fg)
    alpha = luminance.point(lambda value: max(0, min(255, round((230 - value) * 255 / 90))))
    # Keep the padding completely transparent (grayscale conversion ignores alpha).
    alpha = Image.composite(alpha, Image.new('L', fg.size, 0), fg.getchannel('A'))
    mono = Image.new('RGBA', fg.size, (255, 255, 255, 0))
    mono.putalpha(alpha)
    mono.save(folder / 'ic_launcher_monochrome.png')
    drawable = RES / f'drawable-{density}'
    drawable.mkdir(parents=True, exist_ok=True)
    centered(round(192 * scale), .7, transparent=True).save(drawable / 'petita_splash.png')

values = RES / 'values'
(values / 'colors.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<resources><color name="petita_background">#FCE7EC</color></resources>
''')
for qualifier, monochrome in [('mipmap-anydpi-v26', False), ('mipmap-anydpi-v33', True)]:
    folder = RES / qualifier
    folder.mkdir(parents=True, exist_ok=True)
    extra = '\n  <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>' if monochrome else ''
    (folder / 'ic_launcher.xml').write_text(f'''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
  <background android:drawable="@color/petita_background"/>
  <foreground android:drawable="@mipmap/ic_launcher_foreground"/>{extra}
</adaptive-icon>
''')
for qualifier in ['drawable', 'drawable-v21']:
    (RES / qualifier / 'launch_background.xml').write_text('''<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
  <item android:drawable="@color/petita_background"/>
  <item android:width="192dp" android:height="192dp" android:gravity="center">
    <bitmap android:gravity="fill" android:src="@drawable/petita_splash"/>
  </item>
</layer-list>
''')
for qualifier in ['values', 'values-night', 'values-v31', 'values-night-v31']:
    folder = RES / qualifier
    folder.mkdir(parents=True, exist_ok=True)
    extra = '''
    <item name="android:windowSplashScreenBackground">@color/petita_background</item>
    <item name="android:windowSplashScreenAnimatedIcon">@drawable/petita_splash</item>
    <item name="android:windowSplashScreenIconBackgroundColor">@color/petita_background</item>''' if 'v31' in qualifier else ''
    (folder / 'styles.xml').write_text(f'''<?xml version="1.0" encoding="utf-8"?>
<resources>
  <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
    <item name="android:windowBackground">@drawable/launch_background</item>{extra}
  </style>
  <style name="NormalTheme" parent="@android:style/Theme.Light.NoTitleBar">
    <item name="android:windowBackground">@color/petita_background</item>
  </style>
</resources>
''')

# Static preview of Android masks, not evidence of physical-device execution.
preview = Image.new('RGB', (960, 360), 'white')
for index, shape in enumerate(['circle', 'rounded', 'monochrome']):
    icon = centered(280, 60 / 72)
    if shape == 'monochrome':
        mono = Image.open(RES / 'mipmap-xxxhdpi/ic_launcher_monochrome.png')
        mono = mono.resize((420, 420), Image.Resampling.LANCZOS).crop((70, 70, 350, 350))
        icon = Image.new('RGBA', (280, 280), (230, 219, 245, 255))
        ink = Image.new('RGBA', (280, 280), (81, 48, 115, 255))
        icon.paste(ink, (0, 0), mono.getchannel('A'))
    mask = Image.new('L', (280, 280), 0)
    draw = ImageDraw.Draw(mask)
    if shape == 'circle': draw.ellipse((0, 0, 279, 279), fill=255)
    else: draw.rounded_rectangle((0, 0, 279, 279), radius=64, fill=255)
    preview.paste(icon, (20 + index * 320, 20), mask)
    ImageDraw.Draw(preview).text((30 + index * 320, 320), shape, fill='black')
out = ROOT / 'documentos/evidencias/android'
out.mkdir(parents=True, exist_ok=True)
preview.save(out / 'branding-preview.png')
print('Official source preserved; density, adaptive, monochrome and splash resources generated.')
