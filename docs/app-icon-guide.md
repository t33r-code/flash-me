# App Icon Guide

How to produce the app launcher icon assets for Agora so they render correctly on
**Android (adaptive icons)**, **iOS**, web, and desktop.

> **Why this matters:** Android 8+ uses *adaptive icons* (foreground + background
> layers, masked to a circle/squircle/etc. per launcher). If the app ships only a
> flat square icon, Android wraps it in a white background and shrinks it inside the
> mask — producing a "small square floating in a white box" on the home screen.
> The fix is to provide real adaptive layers.

---

## What `flutter_launcher_icons` needs

Three assets (the third can be a colour instead of an image):

| Asset | Size | Background | Used for |
|---|---|---|---|
| **Flat icon** (`icon.png`) | 1024×1024 | Full-bleed brand colour, opaque | Legacy Android, iOS, web, desktop |
| **Foreground** (`foreground.png`) | 1024×1024 | **Transparent** | Android adaptive icon (artwork only) |
| **Background** | hex colour *or* 1024×1024 PNG | Solid brand colour | Android adaptive icon backing layer |

The asset that fixes the white-box problem is the **foreground**.

---

## The safe-zone rule (most important)

Android only guarantees the **centre ~66%** of the foreground is visible — the outer
ring is masked off into whatever shape the launcher uses. So **all artwork must sit
inside that central zone** with transparent margin around it.

For a **1024×1024** canvas:

- Full canvas: **1024×1024**
- Keep all artwork within the central **~680×680** box (≈66%) — ideally within a
  **660 px circle**, since some launchers use a circular mask
- That leaves **~170 px transparent margin** on every side

This is the key difference from a flat full-bleed icon: the artwork must be **shrunk
so it no longer touches the edges**.

---

## Producing the assets in Affinity (Designer / Photo / Publisher)

Affinity has no one-click "Android icon" preset, but the export persona covers it.

1. **New document, 1024×1024 px**, 72 dpi, RGB/8, transparent background.
2. Add **guides** (or a temporary circle) marking the central 66% — your safe zone.
3. Build two layer groups:
   - **Background** — a single brand-colour rectangle covering the whole canvas.
   - **Foreground** — the artwork (column + cards), scaled so the whole composition
     fits *inside* the safe-zone guides (no element touches the canvas edge).
4. **Export the foreground** (Export persona, or File → Export):
   - Hide the Background group → only the artwork on transparency
   - PNG with **transparency** (PNG-32), 1024×1024 → `foreground.png`
5. **Export the flat icon**:
   - Show the Background group
   - PNG, 1024×1024 → `icon.png`
   - This doubles as the iOS / App Store icon. Apple requires **no transparency and
     no rounded corners**; Affinity PNGs carry an alpha channel, so the config sets
     `remove_alpha_ios: true` to strip it.
6. **Background colour** — simplest to read the **hex** from the Affinity colour
   picker and use it directly in the config (use a background PNG only for a gradient).

---

## Wiring it into the project

Place `icon.png` and `foreground.png` in `assets/icon/`, then configure
`flutter_launcher_icons` in `pubspec.yaml`:

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  remove_alpha_ios: true
  image_path: "assets/icon/icon.png"
  adaptive_icon_background: "#CCD4F5"          # brand hex, or an image path
  adaptive_icon_foreground: "assets/icon/foreground.png"
  web:     { generate: true, image_path: "assets/icon/icon.png" }
  windows: { generate: true, image_path: "assets/icon/icon.png" }
  macos:   { generate: true, image_path: "assets/icon/icon.png" }
```

Then regenerate and ship:

```bash
flutter pub get
dart run flutter_launcher_icons
# bump version in pubspec.yaml (versionCode must increase for each Play Store upload)
# commit, then push a v* tag to trigger the release workflow
```

---

## Verifying before you ship

- Eyeball the safe-zone guides: if every element sits inside the central circle,
  masking won't crop it.
- Preview adaptive masking with a tool like <https://hangar.dev> (paste foreground +
  background, cycle through mask shapes).
- After install, long-press the home-screen icon — on most launchers you can see the
  masked shape; confirm no white box and no clipped artwork.

---

## Checklist

- [ ] `icon.png` — 1024×1024, full-bleed, opaque
- [ ] `foreground.png` — 1024×1024, transparent, artwork within central ~66%
- [ ] Background hex (or `background.png`) decided
- [ ] `flutter_launcher_icons` config updated (incl. `remove_alpha_ios: true`)
- [ ] `dart run flutter_launcher_icons` run and generated files committed
- [ ] `versionCode` bumped (the `+N` in `pubspec.yaml`)
- [ ] `v*` tag pushed