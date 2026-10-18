#!/bin/sh

#  ci_post_xcodebuild.sh
#  BeatRate
#
#  Created by Tomasz Wojtyniak on 01/06/2025.
#
#  Uploads the archive's dSYMs to Crashlytics. The Crashlytics build phase
#  uploads in the background, and Xcode Cloud tears the machine down when the
#  build ends — so on Xcode Cloud that upload never finishes. This one runs in
#  the foreground. A failed upload is logged but doesn't fail the build.

# Only archive actions produce dSYMs worth uploading.
[ -n "$CI_ARCHIVE_PATH" ] || exit 0

case "$CI_XCODE_SCHEME" in
  "BeatRate Development") ENVIRONMENT=Development ;;
  *) ENVIRONMENT=Production ;;
esac

"$CI_DERIVED_DATA_PATH/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/upload-symbols" \
  -gsp "$CI_PRIMARY_REPOSITORY_PATH/App/$ENVIRONMENT/GoogleService-Info.plist" \
  -p ios \
  "$CI_ARCHIVE_PATH/dSYMs" \
  || echo "error: Crashlytics dSYM upload failed for $CI_XCODE_SCHEME"
