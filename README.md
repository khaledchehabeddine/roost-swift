# roost-swift

Private SwiftPM distribution and native package checks for Roost. Rust declarations in
`RelayNet/roost` own the generated API. No generated Swift implementation source is committed here.

## Consume a release

Released version tags contain `Package.swift` with product, module and binary target `Roost`.
The binary URL identifies the versioned XCFramework through GitHub's authenticated release-asset
API and pins its ZIP checksum. The repository's `main` branch owns the tests; publication adds
only the manifest to the checked commit and tags that result.

```swift
.package(url: "https://github.com/RelayNet/roost-swift.git", exact: "0.16.0")
```

Use a published version only. Commit `Package.resolved` and review upgrades. Configure read access
for both the Git repository and `api.github.com` binary downloads through SwiftPM's keychain or
netrc support. Git checkout authentication alone does not authenticate the binary download.
Private artifact authentication must be checked with the consumer's Xcode version; see the
[SwiftPM private-download report](https://github.com/swiftlang/swift-package-manager/issues/8946).

Download the ZIP, signature, checksum and public key from the same release. Before accepting it,
run Roost's `scripts/release/verify-artifact.sh` with those four paths and the separately reviewed
SHA-256 pin. The trusted signer fingerprint is `8C936E5EE86B909B53B607EA0EEDE342BC541851`.
SwiftPM's binary-target checksum must match that pin. Keep local development overrides out of
consumer CI and release builds. Published-package resolution and Relay app, extension and device
validation are owned by RelayNet/roost#268.

## Check a candidate

Run `./check.sh <roost-checkout>` or dispatch **Package consumption** on `main` with a full source
SHA. The workflow requires owner initiation, including reruns, and `ROOST_READ_TOKEN` with Contents
read access to Roost. It builds once, extracts the exact ZIP, and tests native loading, foreign
storage errors, lost-write recovery, binary Transport Binding conversion, evidence results and
independent CryptoKit verification on one iPhone simulator. Rust owns protocol scenarios.
`ROOST_IOS_DESTINATION` selects another available simulator.

The workflow uploads the checked ZIP and tool-version notes for 30 days. Run it before publication
and after changes to bindings, packaging, release commands, toolchains, ABI lists, package layout
or consumer repositories. Both platforms must select the same Roost revision and workspace version.

For manual installation of a signed candidate, first use Roost's `mobile.py fetch` with its source,
workflow attempts and reviewed pins. Then run:

```bash
./check.sh <roost-checkout> <absolute-signed-candidate-directory>
```

Keep the fetch command's environment variables set. This mode verifies signatures and pins and
runs the same native calls without rebuilding. Roost's
[publication instructions](https://github.com/RelayNet/roost/blob/main/docs/mobile-publication.md)
cover signing, review, immutable upload and partial retries. These checks do not publish anything.
