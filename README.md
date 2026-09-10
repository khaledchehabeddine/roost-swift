# roost-swift

iOS package consumption checks for Roost. Run `./check.sh ../aether` with a local
Roost checkout, or dispatch the **Package consumption** workflow with the exact source
revision intended for release. Prerequisites are in Roost's `docs/building-mobile.md`.

The check builds one production package, loads its native library and tests foreign storage
error recovery, binary Transport Binding conversion, and native signature verification.
The package tests keep their signed example locally. Rust owns protocol scenarios.

Run this when bindings or packaging change and before releasing. Publish the checked artifact
bytes with the matching source revision and version. These checks do not publish anything.
Package publication metadata will be added when the first Roost package is released.

The workflow needs `ROOST_SOURCE_TOKEN` with Contents read access to `RelayNet/roost`.
