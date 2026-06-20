#!/bin/sh
#
# Generate dSYMs for Flutter native-asset frameworks that are built outside Xcode
# (e.g. objective_c.framework, pulled in transitively by path_provider_foundation).
#
# These frameworks are compiled by Dart's native-assets build hook, so Xcode never
# produces a dSYM for them. On upload, App Store Connect then warns:
#
#   "The archive did not include a dSYM for the objective_c.framework with the
#    UUIDs [...]. Ensure that the archive's dSYM folder includes a DWARF file ..."
#
# This script runs during archive only (DWARF_DSYM_FOLDER_PATH is set) and fills in
# any missing dSYM by running dsymutil on the embedded framework binary. The
# generated dSYM carries the matching Mach-O UUID, which satisfies App Store
# Connect's check and silences the warning. (The native-asset binaries are built
# without -g, so the dSYM has no source-level symbols — that is a Flutter
# native-assets limitation, not something this project controls.)
#
# See docs/ios-warnings.md.

set -u

if [ -z "${DWARF_DSYM_FOLDER_PATH:-}" ]; then
  echo "note: no dSYM folder set (non-archive build); skipping native-asset dSYM generation"
  exit 0
fi

FRAMEWORKS_DIR="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
if [ ! -d "${FRAMEWORKS_DIR}" ]; then
  echo "note: no embedded Frameworks dir at ${FRAMEWORKS_DIR}; nothing to do"
  exit 0
fi

# Source of truth for *which* frameworks are native assets. Anything Xcode or
# Flutter builds normally (Runner, App.framework, Flutter.framework, the CocoaPods
# plugin frameworks, Swift package frameworks) already gets a proper dSYM and must
# NOT be touched here -- regenerating App.framework's dSYM, in particular, would
# wipe out the Dart AOT symbols. So we only act on frameworks that exist in the
# native-assets output directory.
NATIVE_ASSETS_DIR="${FLUTTER_APPLICATION_PATH}/${FLUTTER_BUILD_DIR}/native_assets/ios"
if [ ! -d "${NATIVE_ASSETS_DIR}" ]; then
  echo "note: no native-assets dir at ${NATIVE_ASSETS_DIR}; nothing to do"
  exit 0
fi

mkdir -p "${DWARF_DSYM_FOLDER_PATH}"

for src_fw in "${NATIVE_ASSETS_DIR}"/*.framework; do
  [ -d "${src_fw}" ] || continue
  name=$(basename "${src_fw}" .framework)

  # Use the binary actually embedded in the app -- its UUID is the one App Store
  # Connect expects in the dSYM.
  binary="${FRAMEWORKS_DIR}/${name}.framework/${name}"
  [ -f "${binary}" ] || continue

  dsym="${DWARF_DSYM_FOLDER_PATH}/${name}.framework.dSYM"
  if [ -e "${dsym}" ]; then
    continue
  fi

  echo "note: generating dSYM for native-asset ${name}.framework"
  if ! dsymutil "${binary}" -o "${dsym}"; then
    echo "warning: dsymutil failed for ${name}.framework"
  fi
done
