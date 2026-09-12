#!/usr/bin/env bash
# Build once, or check an existing signed candidate without rebuilding it.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SOURCE="$(cd "${1:?usage: check.sh <roost-source> [signed-candidate-directory]}" && pwd -P)"
VERSION="$(awk -F '"' '/^version = / { print $2; exit }' "$SOURCE/Cargo.toml")"
if [[ $# == 2 ]]; then
    CANDIDATE="$(cd "$2" && pwd -P)"
    python3 "$SOURCE/scripts/release/mobile.py" verify "$CANDIDATE"
    ARCHIVE="$CANDIDATE/Roost-v$VERSION.xcframework.zip"
else
    "$SOURCE/scripts/build/ios-package.sh"
    ARCHIVE="$SOURCE/target/ios-distribution/Roost-v$VERSION.xcframework.zip"
fi
BEFORE="$(shasum -a 256 "$ARCHIVE")"
rm -rf "$ROOT/.candidate"
mkdir -p "$ROOT/.candidate/Artifacts"
unzip -q "$ARCHIVE" -d "$ROOT/.candidate/Artifacts"
cat > "$ROOT/.candidate/Package.swift" <<'PACKAGE'
// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "Roost",
    platforms: [.iOS(.v13)],
    products: [.library(name: "Roost", targets: ["Roost"])],
    targets: [.binaryTarget(name: "Roost", path: "Artifacts/Roost.xcframework")]
)
PACKAGE
DEVICE="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone/ { print $2; exit }')"
cd "$ROOT/Tests"
xcodebuild -scheme RoostConsumer-Package \
    -destination "${ROOST_IOS_DESTINATION:-platform=iOS Simulator,id=$DEVICE}" \
    -derivedDataPath "$ROOT/.build" CODE_SIGNING_ALLOWED=NO test
[[ "$(shasum -a 256 "$ARCHIVE")" == "$BEFORE" ]]
rm -rf "$ROOT/.release"
mkdir -p "$ROOT/.release"
cp "$ARCHIVE" "$ROOT/.release/"
{
    printf '\nSwift package tools:\n```text\n'
    (cd "$SOURCE" && rustc --version)
    xcodebuild -version
    xcrun swift --version
    printf 'iOS SDK: '; xcrun --sdk iphoneos --show-sdk-version
    printf 'Simulator SDK: '; xcrun --sdk iphonesimulator --show-sdk-version
    printf 'Destination: %s\n' "${ROOST_IOS_DESTINATION:-platform=iOS Simulator,id=$DEVICE}"
    printf '```\n'
} > "$ROOT/.release/swift-notes.md"
