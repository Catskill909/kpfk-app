# WBAI Handoff — Home Screen Layout Lock, Responsive Sizing & Portrait Lock

**Date:** 2026-06-21
**Source app:** KPFK (`kpfk_radio`) — changes verified on iOS Simulator (iPhone SE 3rd gen, iPhone 16e) and analyzed clean.
**Target app:** WBAI — uses mostly the same Flutter template and has the **same sizing + rotation issues**. Apply the same edits.

> WBAI shares this template, so the file paths, widget structure, and class names below should match closely. Search for the same anchors; if names differ slightly, the structure (a `Stack` → `Positioned.fill` main content with a station logo, show metadata text, and a center play button, plus floating bottom Donate / Sleep-timer buttons) will be the giveaway.

---

## Problems solved

1. **Home screen drifted up/down** — the main content was in a `SingleChildScrollView`, so it scrolled and re-centered every time metadata changed (image load, "Song:" vs "Next:" line, etc.). → **Locked** to a fixed, non-scrolling, vertically-centered layout.
2. **Overflowed / didn't fit very small phones** — the logo was sized purely off screen *width*, so on short phones the logo + play button overflowed (which also forced the scroll). → Logo now **shrinks to fit** the available height.
3. **Too cramped on large phones / tablets** — no breathing room above the image and the image could be a little larger. → Added **device-scaled top gap** and a **slightly larger image** on big screens/tablets.
4. **Rotation not fully locked** — app could rotate; portrait lock was Android-only in Dart and allowed upside-down. → **Locked to portrait** (phone + tablet) at native + Flutter levels.

---

## Device tiers (breakpoints)

All sizing keys off `MediaQuery.of(context).size.shortestSide`:

| Tier | Condition | Helper |
|---|---|---|
| Small phone | `shortestSide < 380` | `_isSmallPhone(context)` |
| Tablet | `shortestSide > 600` | `mq.shortestSide > 600` (inline `isTablet`) |
| Regular phone | everything in between | (default branch) |

These helpers already exist in the template (`_isSmallPhone`, `_isMediumTablet`, `_isLargeTablet`). Reuse them.

---

## Change 1 — Lock + responsive layout (`lib/presentation/pages/home_page.dart`)

**Replace** the main-content `SingleChildScrollView` (inside the `Stack` in `build`) with a non-scrolling, centered `LayoutBuilder` + `Column`. The logo goes in a `Flexible` → `Center` → `ConstrainedBox(maxWidth)` → `AspectRatio(1)` so it auto-shrinks to leftover height and is capped by width.

### Key structure
```dart
// Main content — locked (non-scrolling), vertically centered.
// The logo lives in a Flexible/AspectRatio so it shrinks to
// whatever vertical space remains after the text + play button.
Positioned.fill(
  child: LayoutBuilder(
    builder: (context, constraints) {
      final mq = MediaQuery.of(context).size;
      final bool small = _isSmallPhone(context);
      final bool isTablet = mq.shortestSide > 600;
      // Logo a touch larger on bigger screens / tablets.
      final double logoMaxWidth =
          mq.width * (small ? 0.8 : (isTablet ? 0.78 : 0.9));
      // Breathing room above the logo, scaled up on larger
      // screens and tablets (kept tight on small phones).
      final double topGap = small ? 8.0 : (isTablet ? 40.0 : 24.0);
      return Padding(
        padding: EdgeInsets.only(
          left: small ? 12.0 : 16.0,
          right: small ? 12.0 : 16.0,
          bottom: small ? 80.0 : 90.0, // reserve for floating bottom buttons
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: topGap),
            // Station Logo — shrinks to fit height, capped by width.
            Flexible(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: logoMaxWidth),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: GestureDetector(
                      onTap: state.metadata != null
                          ? () => setState(() => _showInfoModal = true)
                          : null,
                      child: Container(
                        // ...existing decoration (border, radius, shadow)...
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: /* existing Image.network / loading container */,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Show metadata text (showName / time / Song or Next)
            // — keep existing responsive styles + maxLines:2 + ellipsis.
            // Play button Container — see margin change below.
            // Error display (if any).
          ],
        ),
      );
    },
  ),
),
```

### Tuning values (final, after the large-screen pass)
| Value | Small phone | Regular phone | Tablet |
|---|---|---|---|
| `logoMaxWidth` factor | `0.8` | `0.9` | `0.78` |
| `topGap` (above logo) | `8` | `24` | `40` |
| bottom reserve (Padding) | `80` | `90` | `90` |
| play-button vertical margin | `20` | `28` | `28` |
| SizedBox after logo (before title) | `12` | `20` | `20` |

### Play button margin
```dart
margin: EdgeInsets.symmetric(vertical: small ? 20.0 : 28.0),
```

### Why these specific values
On a regular phone (e.g. iPhone 17 Pro) the image is **height-constrained**, so simply raising the width factor doesn't enlarge it — you must reclaim vertical space. That's why the play-button margin (32→28) and bottom reserve (100→90) were trimmed: it lets the logo grow *and* leaves room for the `topGap`. Small phones keep tight values so they still fit without overflow.

### Bottom buttons unchanged
The floating Donate (bottom-left) and Sleep-timer (bottom-right) `Positioned` widgets stay as-is. The `Column`'s bottom padding (80/90) reserves space so the centered content never collides with them.

### Pitfall (don't reintroduce)
- Do **not** wrap the content back in a scroll view — that's what caused the drift.
- Keep `maxLines: 2` + `TextOverflow.ellipsis` on the metadata `Text` widgets.
- The `Flexible` is the overflow safety net; keep it. Without it, a 2-line title on a tiny screen can overflow.

---

## Change 2 — Lock portrait orientation (3 places)

WBAI almost certainly has the same Android-only Dart guard. Apply all three.

### 2a. `lib/main.dart`
**Before** (Android-only, allowed upside-down):
```dart
if (Platform.isAndroid) {
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
}
```
**After** (all platforms incl. iPad, portraitUp only — matches iOS Info.plist):
```dart
// Lock orientation to portrait on all devices (phone and tablet).
// portraitUp only, to match the iOS Info.plist (no upside-down).
await SystemChrome.setPreferredOrientations([
  DeviceOrientation.portraitUp,
]);
```
> Leave the other `Platform.is*` checks in `main.dart` alone — `Platform` is still used elsewhere, so the `dart:io` import stays.

### 2b. `android/app/src/main/AndroidManifest.xml`
Add `android:screenOrientation="portrait"` to the main `<activity>` (the `com.ryanheise.audioservice.AudioServiceActivity`). It already has `android:configChanges="orientation|...|screenSize|..."`; just add the screenOrientation line:
```xml
<activity
    android:name="com.ryanheise.audioservice.AudioServiceActivity"
    android:exported="true"
    android:launchMode="singleTop"
    android:theme="@style/LaunchTheme"
    android:screenOrientation="portrait"
    android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
    ...>
```

### 2c. `ios/Runner/Info.plist`
Ensure **both** keys list portrait only (KPFK already had this; verify WBAI does too):
```xml
<key>UISupportedInterfaceOrientations</key>
<array>
    <string>UIInterfaceOrientationPortrait</string>
</array>
<key>UISupportedInterfaceOrientations~ipad</key>
<array>
    <string>UIInterfaceOrientationPortrait</string>
</array>
```
If WBAI's iPad key lists landscape variants, remove them so iPad is portrait-only too.

---

## Verification

1. `cd <wbai_project> && flutter analyze lib/presentation/pages/home_page.dart lib/main.dart` → expect "No issues found!"
2. **Orientation changes require a full rebuild** (native + app startup) — a hot reload won't apply them.
3. Visual checks:
   - Small phone (iPhone SE 3rd gen, 375pt → small branch): logo shrinks, title/time/Next all fit, no overflow stripes, no scroll.
   - Regular phone (iPhone 17 Pro): breathing room above logo, slightly larger logo, content centered and stable.
   - Tablet (iPad): more breathing room, larger logo, portrait-locked (does not rotate).
   - Rotate device → stays portrait on phone **and** tablet.

> Prefer verifying on a **real device** or a **single** simulator. Running multiple simulators strains the machine and burns several GB of disk.

---

## Status

- KPFK changes: implemented, `flutter analyze` clean. **Not yet committed** (working tree changes only).
- Files touched in KPFK:
  - `kpfk_radio/lib/presentation/pages/home_page.dart`
  - `kpfk_radio/lib/main.dart`
  - `kpfk_radio/android/app/src/main/AndroidManifest.xml`
  - (`ios/Runner/Info.plist` already portrait-only — no change needed)

## Disk / simulator housekeeping (lessons learned)
- iOS debug builds accumulate fast: project `build/` + `.dart_tool/` (~1 GB) and Xcode **DerivedData** `Runner-*` (~2.5 GB).
- Reclaim with: `flutter clean`, `rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*`, and prune simulators (`xcrun simctl delete <udid>` / `delete unavailable`). Per-device CoreSimulator data can balloon to several GB.
- Xcode-**bundled** runtimes (e.g. the one baked into Xcode.app) can't be removed via `simctl`; only separately-downloaded runtime images appear in `xcrun simctl runtime list`.
</content>
</invoke>
