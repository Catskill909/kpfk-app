# Bottom Corner Icons Plan (Donate + Alarm)

This plan adds two Material Design circular buttons attached to the bottom safe area on the main screen (`home_page.dart`):
- Bottom-left: Volunteer Activism icon (donate). Black icon in white circle, opens a bottom modal sheet with a WebView to `https://docs.pacifica.org/wpfw/donate/` and a close button. Any external links in the page open via `url_launcher`.
- Bottom-right: Alarm icon. Black icon in white circle. Behavior TBD (placeholder action included).

The style follows the app’s dark theme, sits slightly above the safe area, and uses Material motion/elevation.

---

## 1) Dependencies

- Add WebView and URL launcher
  - `pubspec.yaml`:
    - `webview_flutter: ^4.7.0`
    - `url_launcher: ^6.3.0`

- iOS setup
  - `ios/Runner/Info.plist`:
    - Ensure ATS allows HTTPS (default OK). If any non-HTTPS domains are required later, add ATS exceptions.
    - Add `LSApplicationQueriesSchemes` for any custom schemes you intend to open (e.g., `tel`, `mailto`, etc.) so `url_launcher` can query them on iOS 9+:
      - `tel`
      - `mailto`
      - `sms`
  - No special WebView configuration needed if target is iOS 11+.

- Android setup
  - No special changes are typically needed. `url_launcher` and `webview_flutter` work with default configs.

- Fonts/Icons
  - We will use Material Icons built into Flutter (`Icons.volunteer_activism`, `Icons.alarm`). No additional font files required.

---

## 2) UI Placement Strategy (Home Screen)

- File: `wpfw_radio/lib/presentation/pages/home_page.dart`
- Wrap the existing body content in a `Stack` so we can overlay two positioned circular buttons near the bottom corners.
- Use `SafeArea(bottom: true)` and then position the buttons slightly above with a small `Padding` (e.g., 8–12 px).
- Buttons style
  - Use `RawMaterialButton` or `IconButton.filled`/`FloatingActionButton.small` to achieve a white circular background with a black Material icon in the center.
  - Elevation: 4–6 for subtle shadow (`elevation` where available, or `Material` + `InkWell`).
  - Size target: ~56x56 dp (Material FAB small) to be comfortably tappable.

- Positioning
  - Bottom-left: `Positioned(left: 16, bottom: 16 + safeAreaInset)`. We’ll achieve the safe area lift by placing in a `SafeArea` and adding 8–12 px extra bottom padding.
  - Bottom-right: `Positioned(right: 16, bottom: 16 + safeAreaInset)`.

---

## 3) Donate Button Behavior (Bottom Sheet + WebView)

- On press of the left button:
  - Call `showModalBottomSheet` with `isScrollControlled: true` to provide a tall, almost-full-height bottom sheet (e.g., 90% of screen) with rounded top corners.
  - Content: a `Scaffold` inside the sheet that contains
    - A top app bar row with a close button (X icon) aligned right.
    - A `WebViewWidget` (from `webview_flutter`) filling the rest of the space.
  - Initial URL: `https://docs.pacifica.org/wpfw/donate/`.

- External link handling:
  - Use `NavigationDelegate` in `webview_flutter` to intercept navigation requests.
  - For external domains or when the target is a non-http(s) scheme (e.g., `tel:`, `mailto:`, `sms:`), prevent the WebView navigation and launch externally with `url_launcher`.
  - For same-origin navigation (still under `docs.pacifica.org`), allow navigation in the WebView.

- Page HTML considerations:
  - The provided HTML is an example of content already hosted at the target URL. We do not embed the raw HTML; we load the URL directly for consistency and maintainability.

---

## 4) Alarm Button Behavior (Placeholder)

- On press of the right button:
  - Placeholder action for now (e.g., open a simple `ModalBottomSheet` with a message "Coming soon: Alerts/Schedule").
  - This can later be wired to any required feature (program schedule, reminders, or live alerts).

---

## 5) Code Changes (Outline)

- `pubspec.yaml`
  - Add dependencies: `webview_flutter`, `url_launcher`
  - Run `flutter pub get`

- `ios/Runner/Info.plist`
  - Add `LSApplicationQueriesSchemes` entries for `tel`, `mailto`, `sms`.

- `home_page.dart`
  - Convert current `body` to a `Stack` with two `Positioned` buttons layered over the existing column content.
  - Create a helper widget for the circular icon buttons to ensure consistent styling.
  - Implement `onPressed` for Donate: opens a `showModalBottomSheet` with WebView, close button, and `NavigationDelegate` to route external links to `url_launcher`.
  - Implement `onPressed` for Alarm: placeholder bottom sheet.

- New helper (optional): `lib/presentation/widgets/donate_bottom_sheet.dart`
  - Encapsulate the bottom sheet UI + WebView + navigation handling for cleaner `home_page.dart`.

---

## 6) Pseudocode (for reference)

```dart
// In home_page.dart build():
return Scaffold(
  appBar: ..., drawer: ...,
  body: Stack(
    children: [
      // existing Column content
      _MainContent(),

      // Bottom-left donate
      SafeArea(
        child: Positioned(
          left: 16,
          bottom: 16,
          child: _CircleActionButton(
            icon: Icons.volunteer_activism,
            onPressed: () => _openDonateSheet(context),
          ),
        ),
      ),

      // Bottom-right alarm
      SafeArea(
        child: Positioned(
          right: 16,
          bottom: 16,
          child: _CircleActionButton(
            icon: Icons.alarm,
            onPressed: () => _openAlarmSheet(context), // placeholder
          ),
        ),
      ),
    ],
  ),
);
```

```dart
// Bottom sheet with WebView
Future<void> _openDonateSheet(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.9,
        child: DonateWebViewSheet(initialUrl: 'https://docs.pacifica.org/wpfw/donate/'),
      );
    },
  );
}
```

```dart
// In DonateWebViewSheet: use WebViewController + NavigationDelegate
onNavigationRequest: (NavigationRequest request) async {
  final uri = Uri.parse(request.url);
  final isHttp = uri.scheme == 'http' || uri.scheme == 'https';
  final isSameDomain = uri.host.endsWith('docs.pacifica.org');
  if (!isHttp || !isSameDomain) {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return NavigationDecision.prevent;
  }
  return NavigationDecision.navigate;
},
```

---

## 7) Visual/UX Specs

- Button size: 56x56 dp; icon size ~26–28 dp.
- Colors: background `Colors.white`, icon `Colors.black`, ripple with slight opacity.
- Elevation: 4–6; shadow consistent with Material 3.
- Placement: 16 px from side edges, 16 px above the bottom safe inset (via `SafeArea` + padding).
- Bottom sheet: 90% screen height; rounded top 16 px; surface color per theme; close button `Icons.close` top-right.

---

## 8) Testing Checklist

- Donate bottom sheet
  - Opens from bottom-left button with smooth animation.
  - Loads `https://docs.pacifica.org/wpfw/donate/` correctly.
  - In-page navigation within same domain stays in WebView.
  - External links (e.g., `tel:2025880999`, `mailto:`) launch externally and do not break the WebView.
  - Close button dismisses the sheet without leaks.

- Alarm button
  - Taps work; shows placeholder sheet.

- Layout
  - Buttons are visible above bottom safe area on phones with notches/home indicators.
  - Buttons do not overlap playback control on common devices (check small phones, tablets).
  - Dark mode contrast and ripples look consistent.

---

## 9) Future Enhancements

- Alarm button: hook into schedule/reminder feature or an alerts feed.
- Add haptic feedback on tap.
- Remember last scroll position in WebView if reopened.
- Telemetry: log taps and external link launches for UX insights.
