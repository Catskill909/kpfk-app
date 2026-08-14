# Xcode recommended-settings workflow

Xcode's **Update to recommended settings** prompt must never be mixed into
untested Flutter feature work or an archive attempt. Xcode can rewrite the
project and shared scheme, while Flutter may rewrite those files again during
the next build. These checkpoints keep every change attributable and
recoverable.

## Safe order

1. Finish the Flutter feature and physical-device testing.
2. Reset every debug override to its production/default value.
3. Stop `flutter run` so no process holds the Xcode debugger.
4. Run `flutter analyze` and `flutter test`.
5. Build with `flutter build ios --release --no-codesign`.
6. Confirm debug-only strings and test URLs are absent from the release binary.
7. Review `git status` and `git diff`; exclude generated debug-session changes.
8. Commit and push this known-good baseline to `main` **before** accepting any
   Xcode recommendation.
9. Open `ios/Runner.xcworkspace`—never `Runner.xcodeproj`.
10. Inspect the individual recommendations. Do not accept unrelated migrations
    as a bundle.
11. After applying an approved item, inspect the complete Git diff immediately.
12. Run the unsigned iOS release build again. Flutter may intentionally update
    or reverse Xcode's metadata changes.
13. Inspect Git again after the build:
    - clean tree: Flutter owns or reverted the metadata; nothing needs committing;
    - narrow expected diff: commit and push it separately from the feature;
    - signing, capabilities, bundle ID, deployment target, Swift, or other
      unexpected build-setting changes: stop and review rather than archive.
14. Archive only from the verified, clean or intentionally committed state.

## Xcode 26.6 result on 2026-08-14

Xcode offered three **Remove Embed Swift Standard Libraries Setting** items for
Runner's build configurations. Applying them produced only:

- `LastUpgradeCheck`: `1510` → `2660` in `project.pbxproj`;
- `LastUpgradeVersion`: `1510` → `2660` in `Runner.xcscheme`;
- empty CocoaPods script-phase `inputPaths` and `outputPaths` arrays.

The obsolete `EMBEDDED_CONTENT_CONTAINS_SWIFT` and
`ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES` settings were already absent. The next
`flutter build ios --release --no-codesign` reported that it was updating the
project for compatibility, restored the project/scheme metadata to `1510`,
passed the release build, and returned Git to a clean tree.

Conclusion: ignore that repeated recommendation for this Flutter project. Do
not keep reapplying it or manually fight Flutter's project migrator. There was
no durable Xcode change to commit.

## What not to do

- Do not accept Xcode updates before committing and pushing current work.
- Do not open `Runner.xcodeproj`; CocoaPods integration requires the workspace.
- Do not combine an Xcode migration with a feature commit.
- Do not run `flutter clean` routinely. It creates unnecessary regeneration
  work. Reserve it for a reproducible stale build that ordinary rebuilds cannot
  fix.
- Do not change signing, capabilities, bundle ID, or deployment target merely
  because Xcode groups them under a recommendation.
- After changing `pubspec.yaml`, run `flutter build ios --config-only` and
  confirm `Generated.xcconfig` carries the same build number before archiving.

## Current recurring warning

Flutter currently warns that future iOS versions will require UIScene lifecycle
support. Treat UIScene as a deliberate migration with its own diff, tests,
device run, and commit. It is separate from the recommended-settings prompt and
should not be introduced immediately before an archive.
