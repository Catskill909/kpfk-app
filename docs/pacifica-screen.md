# Pacifica Foundation screen — audit and sister-app port plan

**Audited:** 2026-08-19 · **KPFK state:** shipped in `f016754` · **Ported:** not yet

The Pacifica Foundation screen was rebuilt as a two-tab layout (Sister Stations
/ Affiliates). It is verified good on iPhone and iPad. WBAI and WPFW still run
the older single-page version.

Two files carry the whole screen:

- `lib/presentation/pages/pacifica_apps_page.dart`
- `lib/presentation/widgets/affiliate_buttons_section.dart`

---

## 1. What the rebuild changed

| Before | After |
|---|---|
| One long scroll: sister-station grid, then affiliates appended below | Two tabs — `SISTER STATIONS` / `AFFILIATES` |
| No way to find one affiliate among ~60 | Sticky search field, live result count, empty-state |
| Affiliates as a 2–4 column grid of buttons | Phone: flat rows with hairline dividers. Tablet: two-column bordered cards |
| Logos on the page background — dark logos melded into it | Each logo inset in a `0xFF26282D` card with a hairline border, so black, red, and white logos all frame identically |
| No intro copy | A short blurb on each tab explaining what Pacifica is |
| `GestureDetector`, no tap feedback | `InkWell` ripple over the artwork |
| Images popped in | 250ms fade-in via `frameBuilder` |
| Refresh only on the sister grid | Pull-to-refresh on the sister tab |

Supporting code — `pacifica_bloc.dart`, both repositories, both models — was
**not** changed and is byte-identical across all three apps.

---

## 2. Audit findings

All three were reproduced by running them, not inferred. None affect normal
text sizes, which is why the screen tests clean on device.

### 2.1 Sister-station tiles have no screen-reader label

The tile's only content is a logo image inside an `InkWell`. There is no
`Semantics` label and no `semanticLabel` on the image, so VoiceOver and
TalkBack announce an unnamed button. There are five of them, indistinguishable.

Evidence: `Semantics` / `semanticLabel` / `tooltip:` appear in four files under
`lib/` — `home_page.dart`, `app_drawer.dart`, `donate_webview_sheet.dart`,
`stream_notice_modal.dart`. Both Pacifica files have **zero**. The rest of the
app is labelled; this screen is the gap.

Fix when taken: wrap the tile in `Semantics(label: <station title>, button: true)`
inside a `MergeSemantics`, with the feed title stripped of its HTML tags.

### 2.2 Tablet affiliate grid overflows at accessibility text sizes

`SliverGridDelegateWithFixedCrossAxisCount(childAspectRatio: 5.2)` pins the row
height to the tile width, so the two lines of text outgrow it as text scales.

| Text size | Result |
|---|---|
| 1.0x – 1.6x | Clean |
| 2.0x | `RenderFlex overflowed by 11 pixels` |
| 3.0x | `RenderFlex overflowed by 53 pixels` |

Fix when taken: drop `childAspectRatio` and pass `mainAxisExtent`, measuring
the two text styles with a `TextPainter` at the current `MediaQuery.textScalerOf`.

### 2.3 Tab bar overflows at the largest text size

`Tab` with both `icon:` and `text:` is a fixed 72pt. As text scales the labels
both grow **and wrap onto a second line**, which is what actually bursts the
height — a single-line measurement understates it.

| Text size | Result |
|---|---|
| 1.0x – 2.0x | Clean |
| 3.0x | `RenderFlex overflowed by 14 pixels` |

Fix when taken: measure each label with a `TextPainter` constrained to the real
tab width (`screenWidth / 2 - 32`, since `TabBar`'s default `labelPadding` is 16
a side) so wrapping is counted, pass the result to `Tab(height:)`, and drop the
decorative icon past roughly 1.5x so the label gets that room.

### 2.4 Minor, non-blocking

- The Affiliates tab has no retry after a failed fetch. The Sister Stations tab
  has one. The future is cached in a `late final`, so a failure is permanent
  until the page is left and re-entered.
- Pull-to-refresh on the Sister Stations tab adds the bloc event but does not
  await it, so the spinner snaps away before data arrives.
- The intro copy hardcodes `KPFK`. It must be edited per app on the port.
- The detail webview injects the feed title into an `alt="…"` attribute without
  escaping quotes, and loads a Google Fonts stylesheet from the network.

---

## 3. Sister-app port plan

**Not yet done.** Order below is deliberate: WPFW first because it is the
simpler of the two.

### Readiness — verified 2026-08-19

All three apps are structurally identical for this screen:

- Same `AppTextStyles` (`font_constants.dart` is the same shape in all three)
- Same dependencies — `flutter_inappwebview`, `flutter_bloc`, `http`,
  `url_launcher`, `equatable`, `xml`
- `pacifica_bloc.dart`, `pacifica_repository.dart`, `affiliate_repository.dart`,
  `pacifica_item.dart`, `affiliate_station.dart` — **byte-identical**
- All three already use `Colors.red` as the accent on this screen
- Neither target file contains station names, URLs, or per-station colors
- All three define `StreamConstants.stationName` (`'KPFK'` / `'WBAI'` / `'WPFW'`)

So the port is a two-file copy plus one string edit.

### 3.1 WPFW — do this one first

Dark-only (`theme: AppTheme.darkTheme`, `themeMode: ThemeMode.dark`), exactly
like KPFK. Straight copy of both files; change `KPFK` to `WPFW` in the sister-tab
intro sentence. Nothing else.

> **Repo note:** `wpfw_radio` has uncommitted work that is **not ours** —
> a modified `pubspec.lock` and an untracked `docs/SISTER_APP_PARITY_LEDGER.md`.
> Never run `git checkout -- .` or `git clean` there. Preserve both.

### 3.2 WBAI — second, and it has one trap

**WBAI is the only one of the three that supports light mode.** `main.dart`
wires `theme: AppTheme.lightTheme`, `darkTheme: AppTheme.darkTheme`, and a
user-selectable `themeMode`. Its light `appBarTheme.foregroundColor` is
`WBAIColors.darkBrown`.

The Pacifica screen hardcodes a near-black `0xFF18191A` AppBar, so WBAI's
existing version carries a line KPFK's does not:

```dart
iconTheme: const IconThemeData(color: Colors.white),
```

**Keep it.** A naive copy drops it and leaves a dark-brown back arrow on a
near-black bar whenever the user is in light mode. It is one line, and it is the
only theme-related difference in either file.

The tab bar's `labelColor: Colors.white` / `unselectedLabelColor: Colors.white54`
are already hardcoded and are correct against the dark bar in both modes.

### 3.3 Port exactly what shipped

Port the screen **as it is on device today**. Do not fold the §2 fixes into the
port — that would put unvalidated changes into two apps at once. Bring the
siblings to parity first; take §2 as a separate, deliberate change across all
three afterwards.

---

## 4. Verification checklist for the port

Per app, before committing:

- [ ] `git status` lists **only** the two target files
- [ ] `flutter analyze` clean
- [ ] `flutter test` fully passing
- [ ] Diff reviewed and approved before commit
- [ ] Device: both tabs open, search filters, an affiliate opens its site, a
      sister-station logo opens its detail page
- [ ] WBAI only: back arrow is visible on this screen in **light** mode

---

## 5. Related

- `handoff.md` §3.6 — never run `dart format` on a directory
- `handoff.md` §4 — outstanding work
- `docs/main-screen-layout-fix.md` — the other layout bug that keeps regressing
