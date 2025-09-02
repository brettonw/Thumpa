# Thumpa

[![iOS CI](https://github.com/brettonw/Thumpa/actions/workflows/ios-ci.yml/badge.svg?branch=master)](https://github.com/brettonw/Thumpa/actions/workflows/ios-ci.yml)

SwiftUI iOS app. Open `Thumpa.xcworkspace` in Xcode to build and run.

- Build: Product → Build (⌘B) or `xcodebuild -workspace Thumpa.xcworkspace -scheme Thumpa build`
- Test: Product → Test (⌘U) or `xcodebuild -workspace Thumpa.xcworkspace -scheme Thumpa test`

See `AGENTS.md` for contributor guidelines and CI details.

## Local Tooling
- Test script: `./scripts/test.sh` builds and runs tests; use `--show-dest` to list simulators, `--build-only` to skip running.
- Pretty logs: `brew install xcbeautify`. The script uses `xcbeautify` automatically (falls back to raw output if unavailable).
- Optional: `xcpretty` via `gem install xcpretty` (used only if `xcbeautify` is not present).
