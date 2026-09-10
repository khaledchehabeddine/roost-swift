#!/usr/bin/env bash
# Build one candidate and exercise its package on one available iPhone simulator.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SOURCE="$(cd "${1:?usage: check.sh <roost-source>}" && pwd -P)"
"$SOURCE/scripts/build/ios-package.sh"
VERSION="$(awk -F '"' '/^version = / { print $2; exit }' "$SOURCE/Cargo.toml")"
rm -rf "$ROOT/.candidate"
cp -R "$SOURCE/target/ios-distribution/roost-swift-v$VERSION" "$ROOT/.candidate"
DEVICE="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/ { print $2; exit }')"
cd "$ROOT/Tests"
xcodebuild -scheme RoostConsumer-Package \
    -destination "${ROOST_IOS_DESTINATION:-platform=iOS Simulator,id=$DEVICE}" \
    -derivedDataPath "$ROOT/.build" CODE_SIGNING_ALLOWED=NO test
