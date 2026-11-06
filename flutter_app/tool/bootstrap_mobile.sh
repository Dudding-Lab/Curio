#!/usr/bin/env bash
# Run from anywhere, on a machine with a supported Flutter SDK.
set -euo pipefail
cd "$(dirname "$0")/.."
platforms="android"
if [[ "$(uname -s)" == "Darwin" ]]; then
  platforms="android,ios"
fi
# This project intentionally did not have native runners committed.
# Flutter's own templates remain the source of truth for Gradle/Xcode.
flutter create --platforms="$platforms" --project-name=curio --org=de.kovunela .
flutter pub get
if [[ "$(uname -s)" == "Darwin" ]]; then
  python3 tool/configure_ios_permissions.py
fi
echo "Native $platforms shell generated. Review the generated applicationId/bundle ID before release."
