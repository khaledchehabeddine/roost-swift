# roost-swift

The Swift package for [Roost](https://github.com/chirp-org/roost). Roost's release workflow publishes each version here as a tag, so make changes in Roost.

## Install

Add the package with the latest release's version:

```swift
.package(url: "https://github.com/chirp-org/roost-swift.git", exact: "X.Y.Z")
```

Then add `.product(name: "Roost", package: "roost-swift")` to your target's dependencies, and commit `Package.resolved`.

This repository is private. Git checks it out with your usual GitHub credentials, but SwiftPM downloads the binary through the GitHub API, which needs a token that can read the repository. Add the token to `~/.netrc`:

```text
machine api.github.com login <username> password <token>
```
