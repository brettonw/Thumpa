# Repository Guidelines

## Project Structure & Module Organization
- Source: `Thumpa/Thumpa/` (SwiftUI app entry in `ThumpaApp.swift`, root UI in `ContentView.swift`).
- Assets: `Thumpa/Thumpa/Assets.xcassets` (app icon, colors, images).
- Unit tests: `Thumpa/ThumpaTests/` (XCTest).
- UI tests: `Thumpa/ThumpaUITests/` (XCUITest).
- Workspace: `Thumpa.xcworkspace` (open this in Xcode). Project file lives in `Thumpa/Thumpa.xcodeproj`.

## Build, Test, and Development Commands
- Open in Xcode: `open Thumpa.xcworkspace`
- Build (CLI, simulator):
  `xcodebuild -workspace Thumpa.xcworkspace -scheme Thumpa -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' build`
- Run tests (CLI, simulator):
  `xcodebuild -workspace Thumpa.xcworkspace -scheme Thumpa -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' test`
- Run locally: use Xcode (select a simulator, press Run). Ensure signing is configured if building for device.
 - Scripted: `./scripts/test.sh` to build-and-test; `--show-dest` lists simulators; `--build-only` skips running.
 - Pretty logs: `brew install xcbeautify` (script pipes through it automatically).

## Coding Style & Naming Conventions
- Language: Swift (SwiftUI). Indentation: 2 spaces, no tabs.
- Types: UpperCamelCase (`ContentView`, `ThumpaApp`). Methods/properties: lowerCamelCase.
- Files: one primary type per file; name matches type (`FeatureView.swift`, `FeatureViewModel.swift`).
- Views: prefer `struct` + `var body: some View`; keep small, compose.
- Formatting: use Xcode’s default formatter. If adding tools (SwiftFormat/SwiftLint), include configs in the repo.

## Testing Guidelines
- Frameworks: XCTest (`ThumpaTests`) and XCUITest (`ThumpaUITests`).
- Naming: test methods start with `test...`; keep one assertion focus per test where practical.
- Scope: cover view models/business logic; add UI smoke tests for navigation/launch.
- Run: via Product > Test in Xcode or the `xcodebuild ... test` command above.

## Commit & Pull Request Guidelines
- Commits: concise, imperative mood (e.g., “Add UI tests”), ≤72 chars summary; include rationale in body if needed.
- Branches: short, descriptive (`feature/audio-engine`, `fix/crash-on-launch`).
- PRs: clear description, link issues, list changes, add screenshots for UI tweaks, note test coverage/impacts, and specify simulator/device tested.

## Security & Configuration Tips
- Do not commit secrets, signing certificates, or provisioning profiles.
- Keep bundle identifiers and signing managed via Xcode settings; document any required capabilities/entitlements in the PR.

## CI Setup
- Workflow: `.github/workflows/ios-ci.yml` runs `xcodebuild test` on `macos-14`.
- Scheme: in Xcode, share `Thumpa` (Product → Scheme → Manage Schemes → check “Shared”).
- Destination: update `-destination 'platform=iOS Simulator,OS=latest,name=iPhone 15'` if your project/device differs; list options with `xcodebuild -workspace Thumpa.xcworkspace -scheme Thumpa -showdestinations`.
- Artifacts: CI uploads `TestResults.xcresult` for debugging failures.
 - Log formatting: CI installs `xcbeautify` and pipes `xcodebuild` output through it.
