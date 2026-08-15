# Main Screen Layout Fix

Working doc for the recurring struggle to make the **home screen** (`kpfk_radio/lib/presentation/pages/home_page.dart`) use its vertical space well: a large, stable station image up top, metadata below, and the play/pause button in the lower area — **without dumping dead space below the play button** and **without the image shrinking every time the text wraps to another line**.

This is a shared-template app. Whatever we land here must be ported to the WBAI sister app (`~/Desktop/wbai-app`). See memory `sister-apps-kpfk-wbai`.

---

## The symptom (what the user sees)

- On an iPhone 17 Pro (large screen) — and on smaller screens too — there is a large empty band **below the play/pause button**, down to the floating donate/alarm buttons. That space is **never used**.
- The station image renders **smaller than it should**, even with only the default single-line metadata (title + time + one "Song:" / "Next:" line). There is clearly room to make it bigger.
- When the metadata wraps to a second line (e.g. a long "Song: … - …"), the image gets **smaller still** — even though the dead band below the button never shrinks. So text length steals from the image instead of from the empty space.

Screens attached by the user:
1. Old build — large host image (`Nuestra Voz`), 2 metadata lines. Image big; still space below button.
2. `Way Out West` — song wraps to 2 lines; image noticeably smaller.
3. `Democracy Now!` — single "Next:" line; still a big empty band below the button.

---

## Root cause (why it happens)

The body is a `LayoutBuilder` → `Column` (no `mainAxisAlignment`) whose children are, top to bottom:

```
SizedBox(topReserve)
Image        // height = logoSize  (a fixed, pre-computed number)
text block   // measured height = textBlockH
Spacer()     // flex 1   ← A (between text and button)
PlayButton   // height = buttonBlock
[error card]
Spacer()     // flex 1   ← B (between button and bottom)
```

The image height is precomputed:

```
columnH     = constraints.maxHeight - bottomReserve
imageBudget = columnH - topReserve - imgToTextGap - textBlockH - buttonBlock - minBreath
logoSize    = imageBudget.clamp(floor, logoPreferred)     // logoPreferred = width * 0.9 (phone)
```

Three compounding defects fall out of this:

### 1. Two **equal** `Spacer()`s park half of all surplus below the button
After the image, text, and button are laid out, the remaining height is split **50/50** between spacer A (above the button) and spacer B (below the button). Spacer B is the empty band the user is complaining about. It exists **by construction**: the equal spacers keep the button vertically centered in the leftover, so exactly half of every free pixel is dead air below the button. This is the "TONS of space under the play/pause icon, NEVER used."

### 2. The image is starved twice and can never reclaim the space
- `minBreath` (16px small / 36px otherwise) is carved out of `imageBudget` **before** the image is sized.
- `logoSize` is then hard-capped at `logoPreferred = width * 0.9`, a **width-based** cap that ignores how much vertical room exists.

So even when spacer B proves there are 100+ free vertical pixels, the image is not allowed to grow into them. The one element that should absorb surplus is the one element forbidden from doing so.

### 3. Text length shrinks the image 1:1
`textBlockH` is subtracted **directly** from `imageBudget`. Every extra wrapped line pushes `imageBudget` down by that line's height, so the image shrinks by the same amount — **even though the dead band below the button had room to absorb it**. That is exactly the "more lines forces the image smaller even though there is tons of space below" behavior, and it was present in the old layout too.

**Net:** the layout reserves breathing for the button, centers the button, dumps the leftover below it, and caps + starves the image. The result is a small image floating above a large dead band.

---

## Fix direction (the model we want)

Make the **image the single elastic element**. Surplus vertical space should flow *into the image*, not into a dead spacer below the button. Text and the button block get fixed, floored gaps; the image eats everything else up to a sane cap.

Target column model:

```
SizedBox(topReserve)                    // fixed
Flexible/Expanded → Image               // GROWS to fill; capped + floored
SizedBox(imgToTextGap)                  // fixed
text block                              // natural height, maxLines 2
SizedBox(breathAbove)                   // fixed, comfortable gap
PlayButton                              // fixed footprint
SizedBox(breathBelow)                   // fixed, small
// bottomReserve handled by Padding (unchanged — clears floating buttons)
```

Rules the new model must satisfy:

1. **No equal-spacer centering.** The button is anchored by fixed `breathAbove` / `breathBelow` gaps. There is no `Spacer()` below the button that can grow into a dead band.
2. **Image absorbs surplus.** Give the image a `Flexible`/`Expanded` (or compute `logoSize` from the *full* remaining height minus only the fixed gaps), so free vertical space enlarges the image instead of the space under the button.
3. **Text steals from gaps, then from the image — never from dead space.** When metadata wraps, the extra height should first consume any slack, then shrink the image; but because there is no dead band anymore, the image simply grows/shrinks to fit and the button stays put.
4. **Height-aware cap so it never gets grotesque.** Cap the image at `min(width * widthFactor, columnH * heightFactor)` (start `heightFactor ≈ 0.55–0.60`) so tall screens get a big — but not absurd — image. Keep a floor (`~120px`, `~80px` small) so tiny phones still fit everything.
5. **Stable across shows.** The image should not visibly jump between a 1-line and 2-line metadata show. If the cap is the binding constraint (common on large screens), the image size is constant regardless of text — only the gaps flex. Prefer the cap to bind on normal phones so size feels stable.

### Simplest concrete implementation
Replace the two `Spacer()`s with fixed `SizedBox` gaps, and change the image sizing from a width-cap to a height-fill:

```dart
final double breathAbove = small ? 16.0 : 28.0;
final double breathBelow = small ? 12.0 : 20.0;

// Everything the image is NOT allowed to use:
final double reserved = topReserve + imgToTextGap + textBlockH +
    breathAbove + buttonBlock + breathBelow;

final double heightCap = columnH * (small ? 0.5 : 0.58);
final double widthCap  = mq.width * (small ? 0.95 : (isTablet ? 0.78 : 0.92));
final double cap       = math.min(widthCap, heightCap);

final double logoSize = (columnH - reserved)
    .clamp(small ? 80.0 : 120.0, cap)
    .toDouble();
```

Then in the `Column`: `SizedBox(topReserve)`, the image at `logoSize`, `SizedBox(imgToTextGap)`, text, `SizedBox(breathAbove)`, button, `SizedBox(breathBelow)`. No `Spacer()`s. If we still want the block vertically centered as a whole, wrap the fixed column in a `Center` / add one `Spacer()` **above** `topReserve` and one **below** `breathBelow` with a deliberate ratio (e.g. 1 : 1) — but only *after* the image has taken the cap, so the residual being centered is small, not a giant band.

> Design note: whether the leftover (when the cap binds) sits above the image, is split, or pushes the whole block down is a **judgment call** — get the user's eye on it. The non-negotiable is that the leftover is small (the image ate most of it) and is **not** a lone band trapped under the button.

---

## Acceptance criteria

- [ ] On iPhone 17 Pro, the empty band directly below the play/pause button is gone (or a thin, intentional margin — not a large void).
- [ ] The station image is visibly larger than the current build for the default 1-line-metadata case.
- [ ] Switching from a 1-line to a 2-line metadata show does **not** noticeably shrink the image on normal phones (size stable; gaps flex).
- [ ] Small phones (`shortestSide < 380`) still fit everything with no overflow and no clipping.
- [ ] Tablets / iPad Pro: image large but not grotesque; no overlap with the floating donate/alarm buttons.
- [ ] Floating donate (bottom-left) and alarm (bottom-right) buttons never overlap the image or button.
- [ ] No layout jump/flicker when metadata arrives (`Loading stream information…` → real metadata).

## Test matrix

| Device class            | shortestSide | Check |
|-------------------------|--------------|-------|
| Small phone (SE-ish)    | < 380        | fits, no overflow, image floored |
| Normal phone            | 380–430      | big image, no dead band, stable across 1↔2 lines |
| iPhone 17 Pro           | ~402         | primary regression case |
| Medium tablet           | 600–800      | image large, gaps sane |
| iPad Pro                | > 800        | image capped, no button overlap |

Metadata cases to cycle through each device:
- No metadata yet (`Loading stream information…`).
- Title + time + **1** "Next:" line (e.g. Democracy Now!).
- Title + time + **2**-line "Song:" (e.g. Way Out West).
- Host image present vs. absent (network image vs. default logo).

---

## Failed / superseded attempts (from git)

- **`adcc693`** — "Lock home screen layout to portrait + responsive sizing." Introduced `Flexible` + `AspectRatio(1)` for the image inside a `Column(mainAxisAlignment: center)`. The `Flexible` let the image shrink to fit height, but the centered column + surrounding gaps still left space below the button, and the image shrank whenever text grew.
- **`e1ce312`, `65afa18`** — "small-screen drawer + home-logo tuning" / "adjust logo sizing and padding." Tuned `logoMaxWidth` (0.9→0.95 small), `topGap` (8→4 small), horizontal padding (12→8), bottom reserve (80→64), and button vertical margin (20→10). Pure constant-tweaking; did not change the structural cause.
- **`c220d17`** (current) — "adjust spacing for better layout." Replaced the `Flexible`/`AspectRatio` approach with a **measured** layout: `_measureMetadataHeight()` computes `textBlockH` via `TextPainter`, and `logoSize` is derived as `imageBudget.clamp(floor, logoPreferred)`. Also switched the column to **two equal `Spacer()`s** around the button.
  - This is the build in the screenshots. It is the source of all three defects above: equal spacers park surplus below the button (defect 1), the width cap + reserved `minBreath` starve the image (defect 2), and `textBlockH` subtracts straight from the image budget (defect 3).

**Lesson:** every prior attempt tuned *constants* or added *reserves*. The structural problem is that the **button is centered by equal spacers and the image is capped by width** — so surplus can only go to the dead band, never the image. The fix must make the **image** the elastic element and remove the below-button spacer.

---

---

## RESOLUTION (2026-07-09) — go back to WIDTH-based sizing

The "elastic image" / height-budget direction above was **wrong** and made the
image *smaller*. Confirmed on the iPhone 17 Pro simulator: any layout that
derives the image height from remaining vertical space (`columnH - reserved`,
`imageBudget`, `Flexible`+`AspectRatio`, or a `columnH * factor` cap) shrinks
the image, because on a normal phone the big image + text + button genuinely
sit right at the edge of the viewport — so a height-driven size always lands
below the width-based size.

**The original, good design sized the image purely by WIDTH** (commit `65602dc`
and earlier): a fixed `screenWidth * factor` square in a `SingleChildScrollView`,
top-aligned. No measuring, no budgets. That is what makes the image look large
and stay stable across shows. Every regression since then replaced that with
height math.

### What we shipped
In `home_page.dart`, the body is now:

```
LayoutBuilder → SingleChildScrollView(padding: bottomReserve)
  → ConstrainedBox(minHeight: viewport - bottomReserve)   // center when it fits
    → Column(mainAxisAlignment: center)
       image  = SizedBox(width: logoSize, height: logoSize)   // WIDTH-based
       text block (maxLines 2)
       SizedBox gap
       play button
       [error]
       SizedBox gap
```

with

```dart
final double logoSize = mq.width * (small ? 0.8 : (isTablet ? 0.72 : 0.85));
```

- **Image is WIDTH-based** → big, and never shrinks when the text wraps.
- **`SingleChildScrollView` + `ConstrainedBox(minHeight)`** → content is centered
  when it fits (normal phones — nothing scrolls, big image, no giant dead band),
  and scrolls instead of shrinking the image when it can't (tiny screen / huge
  accessibility font).
- Deleted `_measureMetadataHeight()` and the `dart:math` import — no longer used.

### FINAL FORMULA (2026-07-09, verified on two device sizes)

The width-only version was still not quite right: on a genuinely small phone it
would *scroll* instead of shrinking the image, which is not what "shrink only as
a last resort" means. Final rule:

```dart
// bigWidthSize = width * (small ? 0.8 : (isTablet ? 0.72 : 0.85))  — the size the
// image WANTS whenever there is room. It is the UPPER CAP of the clamp.
final double spaceLeftForImage = viewportH
    - topGap - textBlockH - gapAboveButton - buttonBlock - gapBelowButton;
final double logoSize =
    spaceLeftForImage.clamp(floor, bigWidthSize).toDouble();
```

`textBlockH` comes from `_measureMetadataHeight()` (re-added), a `TextPainter`
measure of the actual metadata lines. It is used **only** to compute `spaceLeft`,
never as the image size. The clamp's upper cap = `bigWidthSize` is the whole
trick:

- room to spare → `spaceLeft ≥ bigWidthSize` → clamp returns **bigWidthSize**
  (the image CANNOT shrink — this is the guarantee prior attempts lacked); the
  slack is absorbed by the centered `Column` inside `ConstrainedBox(minHeight)`.
- genuinely tight → `spaceLeft < bigWidthSize` → clamp returns **spaceLeft**
  (image shrinks by exactly the shortfall, no more, no scroll).
- extreme (huge font) → floor, then the `SingleChildScrollView` scrolls.

### Verified on real simulators
- [x] **iPhone 17 Pro** (`Law and Disorder`, title + time + "Next:" = 3 lines):
      image at full `bigWidthSize` (~342pt ≈ 0.85 width), sits high, holds its
      size across the 3 lines. **No shrink — room to spare, cap wins.**
- [x] **iPhone SE (3rd gen)** (same show): viewport is tight (~527pt); the
      formula shrank the image from its 300pt preferred to ~290pt — exactly the
      ~10pt shortfall — so everything fits with **no scroll and no overflow**.
      This is the last-resort shrink working: image gives up only what's needed.
- Result: image is big on both, shrinks *only* on the tight screen and *only* by
  the shortfall, never while space remains. Matches the requirement.

### FOLLOW-UP FIX — the oversized `bottomReserve` was still starving the image

First device check exposed one more mole: the image was still ~0.74 width on the
17 Pro instead of the full 0.85. Cause was **not** the formula — it was the
**reserves fed into it**, chiefly `bottomReserve = 90`. The clamp shrinks the
image when `spaceLeft < bigWidthSize`, and `spaceLeft` subtracts every reserve:

```
spaceLeft = (maxH − bottomReserve) − topGap − text − gapAbove − button − gapBelow
17 Pro   = (725 − 90) − 20 − 110 − 40 − 136 − 24 = 305   →  clamp → 305 (SHRUNK)
```

The 90px `bottomReserve` was the exact empty band under the button — and it was
far larger than the floating donate/alarm buttons need (they're ~56px and live
in the **corners**, which the centered play button never reaches). Reduced the
reserves so `spaceLeft ≥ bigWidthSize` on normal/large phones:

```dart
bottomReserve   = small ? 40 : 48;   // was 64 / 90
topGap          = small ? 12 : 16;   // was 12 / 20
gapAboveButton  = small ? 20 : 28;   // was 24 / 40
gapBelowButton  = small ? 12 : 24;   // was 16 / 24
```

Now `spaceLeft` (17 Pro) ≈ 359 ≥ 342 → clamp returns the full **342 (0.85)**.

### Re-verified on device (2026-07-09)
- [x] **iPhone 17 Pro** — image full **0.85 width** (measured ~0.84), fills the
      space like the reference; play button clears the corner buttons.
- [x] **iPhone SE** — image full **0.8 width**, everything fits, no scroll.
- Reserve math leaves headroom so a 2-line "Song:" line still keeps the full
      image on the 17 Pro (≈724 ≤ 725 budget); on the SE a 2-line song trims the
      image by only the shortfall (last-resort shrink, as intended).

**Takeaway #2:** the clamp formula is right; if the image still looks small,
the reserves feeding `spaceLeft` are too big — shrink the reserves, not the
formula. `bottomReserve` especially must only clear the corner buttons.

### Worst-case verified (forced 2-line title + 2-line song = 5 text lines)
Temporarily injected long strings into `ShowInfo.fromJson` (reverted after):
- **iPhone 17 Pro** — image ~0.74 width, everything fits, no scroll, song
  ellipsised at 2 lines, play button clears corners.
- **iPhone SE** — image ~0.77 width, fits, no scroll.
- The image shrinks here **because 5 lines genuinely leave no room** — the exact
  "last resort" case. Typical 1-line metadata → full 0.85 / 0.8. Accepted.

---

## GUARDRAILS — how to not repeat this on ANY layout

### Why this was such a struggle (the one root cause, restated)
Every failed attempt made the station image's size **driven by the leftover
vertical space** (height-first): `image = columnH − everything_else`. On a phone
the leftover is almost always smaller than a good big image, so the image shrank
constantly — and worse, it shrank *more* whenever text wrapped. Each "fix" then
**tuned a constant** (a factor, a gap, a cap) without changing the height-first
model, so the bug just reappeared somewhere else. That is the whack-a-mole. It
was compounded by (a) an oversized `bottomReserve` silently eating the image's
budget, and (b) never verifying on real devices / worst-case text, so
regressions shipped unseen.

### The invariant (keep this true)
The image is **width-first**: it wants `bigWidthSize = screenWidth * factor` and
only shrinks as a **last resort** to fit. Encoded as:
```dart
logoSize = spaceLeft.clamp(floor, bigWidthSize);
```
`bigWidthSize` is the clamp's **upper cap**. When there's room the cap wins and
the image CANNOT shrink for text. Height (`spaceLeft`) only ever *lowers* it when
the content genuinely doesn't fit.

### Rules for any future layout work here
1. **Never size the image (or any hero element) from leftover height as the
   primary value.** Leftover height is a *clamp floor case*, never the target.
   If you write `size = available − stuff`, stop — that's the bug.
2. **Reserves subtract from the hero's budget — keep them minimal and justified.**
   `bottomReserve` must only clear the floating corner buttons (~56px, in the
   corners), nothing more. If the image looks small, suspect the reserves feeding
   `spaceLeft` *before* touching the formula.
3. **Verify every layout change on real simulators at BOTH extremes** — a large
   phone (iPhone 17 Pro) and a small phone (iPhone SE, shortestSide < 380) — and
   **force worst-case text** (2-line title + 2-line song) by injecting long
   strings into `ShowInfo.fromJson` (revert after). Screenshot each and *look*.
   Never declare a layout fixed from the math alone.
4. **One change at a time, then re-measure.** Don't batch constant tweaks; you
   lose the ability to attribute a regression.
5. **This screen is a simple vertical stack.** If a fix needs `Flexible` +
   `AspectRatio`, `IntrinsicHeight`, nested `LayoutBuilder`s, or measured-text
   budgets used as the *primary* size, you are overbuilding — step back to the
   clamp.

### Current constants (source of truth: `home_page.dart`)
```
bigWidthSize   = width * (small ? 0.8 : (isTablet ? 0.72 : 0.85))
floor          = small ? 80 : 120
bottomReserve  = small ? 40 : 48
topGap         = small ? 12 : 16
gapAboveButton = small ? 20 : 28
gapBelowButton = small ? 12 : 24
```

---

## Status — RESOLVED (2026-07-09)
- [x] Width-first clamp implemented in `home_page.dart`.
- [x] Reserves right-sized so the image is full-size on normal/large phones.
- [x] Verified on iPhone 17 Pro + iPhone SE, 1-line and forced 2-line/2-line.
- [ ] **Port the same change to WBAI** (`~/Desktop/wbai-app`) — still open.

### Still to check / decide
- [ ] 2-line "Song:" show (e.g. Way Out West) — confirm no unwanted scroll on a
      normal phone and the image stays the same size.
- [ ] Small phone (`shortestSide < 380`) — confirm it fits or scrolls gracefully.
- [ ] Tablet / iPad Pro — confirm `0.72` factor looks right, no button overlap.
- [ ] Decide: keep the block **centered** (current) vs **top-aligned** like the
      original (image right under the header). Centered balances the slack;
      top-aligned puts the image higher. User's call on a device screenshot.
- [ ] Port the same change to WBAI (`~/Desktop/wbai-app`).

**Takeaway for next time:** on this screen the image is sized by **width**, full
stop. If you find yourself computing the image height from leftover vertical
space, you are re-introducing this bug.
