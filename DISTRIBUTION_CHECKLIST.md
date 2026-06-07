# SnapGroup — Developer ID Distribution Checklist

> Non-App-Store distribution via Developer ID signing + notarization.
> Generated 2026-02-28. Replaces `APP_STORE_READINESS.md`.

SnapGroup's core functionality (AXUIElement-based window management) is incompatible with App Sandbox, making Mac App Store distribution impossible without a full architectural redesign. Developer ID distribution is the standard path for comparable apps (Rectangle, Amethyst, Hammerspoon, BetterTouchTool, yabai).

---

## Table of Contents

1. [Signing & Notarization](#1-signing--notarization)
2. [Code Fixes Required](#2-code-fixes-required)
3. [Packaging (DMG)](#3-packaging-dmg)
4. [Auto-Updates (Sparkle)](#4-auto-updates-sparkle)
5. [Branding & Assets](#5-branding--assets)
6. [Legal & Compliance](#6-legal--compliance)
7. [Distribution Channels](#7-distribution-channels)
8. [Marketing & Launch](#8-marketing--launch)
9. [User Experience](#9-user-experience)
10. [CI/CD & Build Automation](#10-cicd--build-automation)
11. [Implementation Sequence](#11-implementation-sequence)

---

## 1. Signing & Notarization

### 1.1 Apple Developer Program

- [x] Enroll in the Apple Developer Program ($99/year) if not already enrolled
- [x] Note your **Team ID**: `Y4M378P55D`

### 1.2 Build Settings Changes

Apply these in `project.pbxproj` (both Debug and Release target configurations unless noted):

| Setting | Value | Notes |
|---------|-------|-------|
| `DEVELOPMENT_TEAM` | `Y4M378P55D` | ~~Currently absent~~ Done |
| `ENABLE_HARDENED_RUNTIME` | `YES` | ~~Currently absent~~ Done |
| `CODE_SIGN_IDENTITY` | `Apple Development` (Debug) / `Developer ID Application` (Release) | Managed by `CODE_SIGN_STYLE = Automatic`; export step handles Developer ID |
| `CODE_SIGN_STYLE` | `Automatic` | Already set |
| `OTHER_CODE_SIGN_FLAGS` | Remove | ~~Debug had a custom `--requirements` flag~~ Removed |
| `REGISTER_APP_GROUPS` | Remove | ~~Set to `YES`~~ Removed |
| `ENABLE_APP_SANDBOX` | `NO` | Already correct — must stay off for AX API |
| `ENABLE_USER_SELECTED_FILES` | Remove | ~~Sandbox-related dead setting~~ Removed |

### 1.3 Create Entitlements File

~~Create `SnapGroup/SnapGroup.entitlements`~~ Done. Created with an empty dict — no Hardened Runtime exceptions are needed. SnapGroup doesn't use JIT, DYLD environment variables, load unsigned libraries, or send Apple Events. The Accessibility API relies on the user-granted system permission, not an entitlement.

`CODE_SIGN_ENTITLEMENTS = SnapGroup/SnapGroup.entitlements` added to both Debug and Release configurations.

### 1.4 Notarization Workflow

**Prerequisites:** Xcode 14+, an app-specific password from [appleid.apple.com](https://appleid.apple.com), and `xcrun notarytool` credentials stored in Keychain.

```bash
# 1. Store credentials (one-time)
xcrun notarytool store-credentials "SnapGroup-Notary" \
  --apple-id "your@email.com" \
  --team-id "Y4M378P55D" \
  --password "app-specific-password"

# 2. Archive
xcodebuild archive \
  -project SnapGroup.xcodeproj \
  -scheme SnapGroup \
  -configuration Release \
  -archivePath build/SnapGroup.xcarchive

# 3. Export
xcodebuild -exportArchive \
  -archivePath build/SnapGroup.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist

# 4. Create DMG (see Section 3)

# 5. Sign the DMG
codesign --sign "Developer ID Application: Sami Baadarani (Y4M378P55D)" build/SnapGroup.dmg

# 6. Notarize
xcrun notarytool submit build/SnapGroup.dmg \
  --keychain-profile "SnapGroup-Notary" \
  --wait

# 7. Staple (embeds the notarization ticket for offline verification)
xcrun stapler staple build/SnapGroup.dmg

# 8. Verify
spctl --assess --type open --context context:primary-signature build/SnapGroup.dmg
xcrun stapler validate build/SnapGroup.dmg
```

**`ExportOptions.plist`** — Created at project root:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>Y4M378P55D</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
```

---

## 2. Code Fixes Required

Filtered to what matters for Developer ID distribution. Organized by priority.

### Blocking (prevents signing/notarization or crashes)

| # | Issue | Status |
|---|-------|--------|
| 2.1 | No Hardened Runtime | Done (see 1.2) |
| 2.2 | No Development Team | Done (see 1.2) |
| 2.3 | No entitlements file | Done (see 1.3) |
| 2.4 | No shared Xcode scheme | Done — created `xcshareddata/xcschemes/SnapGroup.xcscheme` |
| 2.5 | macOS 26.1 deployment target | Done — lowered to `15.0` |

### High (crash risk, broken UX, or poor first impression)

| # | Issue | Status |
|---|-------|--------|
| 2.6 | Force casts crash risk | Done — fixed `CFBoolean` cast to use `NSNumber`; AXUIElement casts kept as `as!` (CF types can't use `as?`, and cast is safe after `.success` check) |
| 2.7 | Missing `NSAccessibilityUsageDescription` | Done — added to both configs |
| 2.8 | 28 `print()` in production | Done — all wrapped in `#if DEBUG` across all files |
| 2.9 | Deprecated `activate(ignoringOtherApps:)` | Done — updated to `NSApp.activate()` / `app.activate()` in all 3 files |
| 2.10 | Empty copyright string | Done — set to `"Copyright © 2025-2026 Sami Baadarani. All rights reserved."` |
| 2.11 | No app icon | Done — teal-to-cyan gradient squircle with stacked windows, all 10 sizes generated |
| 2.12 | "Preferences" → "Settings" | Done — renamed in both `PreferencesWindowController` and `MenuBarController` |

### Medium (polish, code quality)

| # | Issue | Status |
|---|-------|--------|
| 2.13 | `Thread.sleep` on main thread | Deferred — 50-100ms delays are acceptable for hotkey-triggered AX retry logic; async refactor would cascade through the call chain |
| 2.14 | Dead `ViewController.swift` + storyboard bloat | Done — deleted `ViewController.swift`; storyboard stripped later |
| 2.15 | Dark mode layer colors don't update | Done — added `viewDidChangeEffectiveAppearance()` override |
| 2.16 | Hardcoded pixel layout in Preferences | Deferred — Auto Layout refactor is a larger task |
| 2.17 | `runModal()` blocking alerts | Deferred — `runModal()` is the correct approach for a windowless menu bar app; `beginSheetModal` requires a window |
| 2.18 | No confirmation on "Clear All Groups" | Done — added confirmation alert |
| 2.19 | HotKey pinned to revision, not version | Done — pinned to `v0.2.1` via `upToNextMinorVersion` (`>= 0.2.1, < 0.3.0`); the revision was already exactly the `v0.2.1` tag |
| 2.20 | Version numbering | Done — changed to `1.0.0` (semver) |

> **Note:** Items from `APP_STORE_READINESS.md` that are App-Store-only (sandbox requirement, `LSApplicationCategoryType`, App Store Connect metadata, App Review notes, privacy nutrition labels) are intentionally excluded. The semi-private `AXEnhancedUserInterface` attribute (used for Chromium browser compatibility) is fine for Developer ID distribution.

---

## 3. Packaging (DMG)

### 3.1 DMG Creation

Use [create-dmg](https://github.com/create-dmg/create-dmg) (Homebrew: `brew install create-dmg`):

```bash
create-dmg \
  --volname "SnapGroup" \
  --volicon "build/export/SnapGroup.app/Contents/Resources/AppIcon.icns" \
  --background "assets/dmg/background.png" \
  --window-pos 200 120 \
  --window-size 660 400 \
  --icon-size 80 \
  --icon "SnapGroup.app" 180 200 \
  --app-drop-link 480 200 \
  --hide-extension "SnapGroup.app" \
  --no-internet-enable \
  "build/SnapGroup.dmg" \
  "build/export/SnapGroup.app"
```

Set the app icon on the DMG file itself (visible in Finder before mounting):

```bash
osascript -e '
use framework "AppKit"
set iconPath to POSIX path of "'"$(pwd)"'/build/export/SnapGroup.app/Contents/Resources/AppIcon.icns"
set dmgPath to POSIX path of "'"$(pwd)"'/build/SnapGroup.dmg"
set iconImage to current application'\''s NSImage'\''s alloc()'\''s initWithContentsOfFile:iconPath
current application'\''s NSWorkspace'\''s sharedWorkspace()'\''s setIcon:iconImage forFile:dmgPath options:0'
```

### 3.2 DMG Background Image

- **Size:** 660×400 @1x (1320×800 @2x for Retina)
- **Content:** App name/logo, subtle arrow from app icon to Applications folder, minimal branding
- **Format:** PNG
- **Location:** `assets/dmg/background.png` and `background@2x.png`

### 3.3 Sign the DMG

```bash
codesign --sign "Developer ID Application: Sami Baadarani (Y4M378P55D)" build/SnapGroup.dmg
```

Then notarize and staple (see 1.4, steps 5-7).

### 3.4 Alternative: ZIP Distribution

For lightweight distribution (e.g., GitHub Releases), a signed ZIP works too:

```bash
ditto -c -k --keepParent "build/export/SnapGroup.app" "build/SnapGroup.zip"
xcrun notarytool submit build/SnapGroup.zip --keychain-profile "SnapGroup-Notary" --wait
# Note: ZIPs can't be stapled — Gatekeeper checks online on first launch
```

---

## 4. Auto-Updates (Sparkle)

[Sparkle](https://sparkle-project.org/) is the standard auto-update framework for non-App-Store macOS apps.

### 4.1 Add Sparkle via SPM

In Xcode: File → Add Package Dependencies → `https://github.com/sparkle-project/Sparkle` → Add `Sparkle` framework to the SnapGroup target.

### 4.2 Generate EdDSA Key Pair

```bash
# Download Sparkle tools or build from source
./bin/generate_keys
# Outputs:
#   Private key saved to Keychain (SparklePrivateKey)
#   Public key: <base64 string>
```

Add the public key to `Info.plist` build settings:

```
INFOPLIST_KEY_SUFeedURL = "https://yourdomain.com/appcast.xml"
```

Or set it programmatically. Store the public key in the app's `Info.plist` as `SUPublicEDKey`.

### 4.3 Integration Code

In `AppDelegate.swift`:

```swift
import Sparkle

private var updaterController: SPUStandardUpdaterController!

func applicationDidFinishLaunching(_ notification: Notification) {
    updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
    // ...existing code...
}
```

Add a "Check for Updates..." menu item in `MenuBarController.swift` wired to `updaterController.checkForUpdates(_:)`.

### 4.4 Appcast

Host an `appcast.xml` file at a stable URL. Use `generate_appcast` tool from Sparkle to create it from your signed builds:

```bash
./bin/generate_appcast /path/to/releases/
```

The appcast contains version info, release notes, download URLs, and EdDSA signatures.

### 4.5 Hosting the Appcast

Options (simplest first):
1. **GitHub Releases** — host the DMG as a release asset, appcast.xml in the repo or GitHub Pages
2. **Static site** (Netlify, Vercel, Cloudflare Pages) — host appcast.xml + DMG
3. **S3 / R2 / GCS bucket** — for high bandwidth needs

---

## 5. Branding & Assets

### 5.1 App Icon

**Required sizes** (all PNG, sRGB color space):

| Size | Scale | Pixels | Filename |
|------|-------|--------|----------|
| 16×16 | 1x | 16×16 | `icon_16x16.png` |
| 16×16 | 2x | 32×32 | `icon_16x16@2x.png` |
| 32×32 | 1x | 32×32 | `icon_32x32.png` |
| 32×32 | 2x | 64×64 | `icon_32x32@2x.png` |
| 128×128 | 1x | 128×128 | `icon_128x128.png` |
| 128×128 | 2x | 256×256 | `icon_128x128@2x.png` |
| 256×256 | 1x | 256×256 | `icon_256x256.png` |
| 256×256 | 2x | 512×512 | `icon_256x256@2x.png` |
| 512×512 | 1x | 512×512 | `icon_512x512.png` |
| 512×512 | 2x | 1024×1024 | `icon_512x512@2x.png` |

Also generate `AppIcon.icns` for the DMG volume icon:
```bash
iconutil -c icns AppIcon.iconset
```

**Design direction:** Window-grouping concept. Consider overlapping rectangles with a snap/magnet motif. Follow Apple's macOS icon guidelines (rounded-rect shape, front-facing perspective, realistic materials).

### 5.2 Menu Bar Icon

Done — replaced SF Symbol `rectangle.3.group` with custom template image (`MenuBarIcon.imageset`) using the same stacked-windows graphic on transparent background. Template rendering auto-adapts to light/dark mode.
- [x] Verify it renders well at 18×18 @1x and @2x in both light and dark menu bars
- [x] Consider a custom template image if the SF Symbol doesn't read clearly at small sizes

### 5.3 DMG Background Image

See section 3.2.

### 5.4 Screenshots (for website/README/directories)

- Menu bar dropdown showing populated groups
- Preferences window with hotkey configuration
- Before/after of window recall in action
- Accessibility permission grant flow
- Suggested sizes: 1440×900, 2880×1800 (@2x)

### 5.5 OG Image / Social Card

- **Size:** 1200×630 (standard Open Graph)
- **Content:** App icon, name, one-line tagline
- **Use:** GitHub repo social preview, website `<meta property="og:image">`, Product Hunt, etc.

---

## 6. Legal & Compliance

### 6.1 LICENSE File

- [x] Created `LICENSE` (MIT) in the project root — permissive reuse with attribution, the standard for free open-source macOS utilities.

### 6.2 Credits.rtf

- [x] Created `SnapGroup/Credits.rtf` for the About panel — the actual file also credits **Sparkle** (added after this template was written). Template:

```rtf
{\rtf1\ansi
{\b SnapGroup}\par
Copyright \u169 2025-2026 Sami Baadarani\par
\par
{\b Open Source Libraries}\par
HotKey by Sam Soffes (MIT License)\par
https://github.com/soffes/HotKey\par
}
```

Auto-included via the project's synchronized file group — macOS shows it in the standard About panel automatically (no manual Copy Bundle Resources step needed). The "About SnapGroup" menu item that opens that panel is now in place (§9.5); it appears after a rebuild.

### 6.3 PrivacyInfo.xcprivacy

- [x] Done — `SnapGroup/PrivacyInfo.xcprivacy` exists and is auto-included via the synchronized file group:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

> Required since April 2024. Declares that UserDefaults is the only "required reason" API used. No data is collected, no tracking occurs, no network calls exist in the codebase.

### 6.4 Privacy Policy

- [x] Created `PRIVACY.md` at the repo root (it accounts for Sparkle's update request).

Even for free, non-tracking apps, a privacy policy builds trust and is required by some distribution channels.

Create a simple page stating:
- SnapGroup does not collect, transmit, or store any personal data
- Window titles are held in memory only during the session and never written to disk or sent over the network
- No analytics, telemetry, crash reporting, or network calls of any kind
- UserDefaults stores only hotkey preferences locally on your Mac

Host on GitHub Pages, a simple static site, or in the README.

### 6.5 GDPR / International

No action needed — SnapGroup collects zero user data and makes zero network requests. No consent banners, data processing agreements, or DPIA required.

---

## 7. Distribution Channels

### 7.1 GitHub Releases (Start Here)

The simplest and most common channel for open-source macOS utilities.

- [ ] Create a GitHub release for each version tag
- [ ] Upload the notarized DMG (and/or ZIP) as a release asset
- [ ] Include release notes and changelog
- [ ] Add install instructions to README

Sparkle can point directly at GitHub Releases for the appcast download URL.

### 7.2 Direct Website

A simple landing page with:
- Download button (links to latest GitHub Release or direct CDN)
- Screenshots and feature overview
- Install instructions (including Gatekeeper first-run)
- Privacy policy

Options: GitHub Pages (free), Netlify, Vercel, or a custom domain.

### 7.3 App Directories & Listings

Submit to free directories once the app is stable:
- [macOS Setup](https://github.com/nikitavoloboev/my-mac-os) and similar curated lists
- [Awesome macOS](https://github.com/iCHAIT/awesome-macOS)
- [Product Hunt](https://producthunt.com) (see 8.1)
- [AlternativeTo](https://alternativeto.net) — list as alternative to Rectangle, Magnet, BetterSnapTool

---

## 8. Marketing & Launch

### 8.1 Product Hunt

- Schedule a launch (Tuesday-Thursday for best visibility)
- Prepare: tagline (≤60 chars), description, 3-5 screenshots/GIFs, maker comment
- Suggested tagline: "Tag windows to groups, recall them instantly with hotkeys"
- Have a few supporters ready to upvote and comment early

### 8.2 Hacker News

- Post as "Show HN: SnapGroup – Instant window group recall for macOS"
- Best times: weekday mornings US time (10am-12pm ET)
- Be ready to answer technical questions (AX API, Carbon hotkeys, etc.)

### 8.3 Reddit

Relevant subreddits:
- r/macapps (primary — very receptive to free utilities)
- r/mac
- r/productivityapps
- r/commandline (if open source with CLI aspects)

### 8.4 README

Ensure the GitHub README includes:
- One-line description and key value proposition
- GIF/video showing the app in action (tag → recall flow)
- Install instructions (DMG download)
- Default hotkeys table
- How it works (brief technical explanation)
- Screenshots
- Build from source instructions
- License

### 8.5 SEO / Discoverability

- GitHub repo description and topics: `macos`, `window-manager`, `productivity`, `swift`, `accessibility-api`, `menu-bar-app`
- Website title: "SnapGroup — Instant Window Groups for macOS"
- OG tags on landing page (see 5.5)

---

## 9. User Experience

### 9.1 Gatekeeper First-Run

When users download a non-App-Store app, macOS shows a Gatekeeper dialog. With notarization, the dialog says the app was "checked for malicious software" (positive framing). Without notarization, users must right-click → Open.

**Include in install instructions:**
1. Open the DMG
2. Drag SnapGroup to Applications
3. Launch SnapGroup — if prompted, click "Open"
4. Grant Accessibility permission when prompted

### 9.2 Accessibility Permission Flow

Current state: The app checks permission on launch with `prompt: false`, then prompts when an actual AX error occurs. For a good first-run experience:

- [ ] Add `NSAccessibilityUsageDescription` to Info.plist (see 2.7)
- [ ] Consider a pre-permission screen explaining *why* before triggering the system dialog
- [ ] Handle the "permission denied" state gracefully with a re-prompt option in the menu bar

### 9.3 Onboarding

- [ ] Detect first launch via UserDefaults flag
- [ ] Show a welcome window covering:
  - What SnapGroup does (one sentence + visual)
  - Default hotkeys (Ctrl+1-5 recall, Ctrl+Shift+1-5 tag)
  - Why Accessibility permission is needed
  - Where to find the app in the menu bar

### 9.4 Launch at Login

- [ ] Add a "Launch at Login" toggle to the menu bar menu
- [ ] Use `SMAppService.mainApp` (ServiceManagement framework, macOS 13+)
- No helper app or LaunchAgent needed with this API

### 9.5 About Window

- [x] Added "About SnapGroup" item to the status bar menu (`MenuBarController.swift`, between "Settings…" and "Check for Updates…")
- [x] Wired to `NSApp.orderFrontStandardAboutPanel(nil)` (calls `NSApp.activate()` first so the panel comes to the front)
- The native panel auto-shows the app icon, **Version 0.2.0 (2)**, the copyright string, and a Credits… button (HotKey + Sparkle, from `Credits.rtf`). Since `LSUIElement = YES`, the standard About menu in the storyboard menu bar is never visible.

### 9.6 Uninstall

`UNINSTALL.md` already exists. Ensure it covers:
- [ ] Delete `SnapGroup.app` from Applications
- [ ] Remove preferences: `defaults delete dev.samib.SnapGroup`
- [ ] Remove from Login Items (if Launch at Login was enabled)
- [ ] Remove Accessibility permission entry in System Settings → Privacy & Security → Accessibility

---

## 10. CI/CD & Build Automation

### 10.1 Shared Xcode Scheme

- [ ] In Xcode: Product → Scheme → Manage Schemes → check "Shared" for SnapGroup
- [ ] Commit `SnapGroup.xcodeproj/xcshareddata/xcschemes/SnapGroup.xcscheme`

### 10.2 GitHub Actions Workflow

Create `.github/workflows/build.yml`:

```yaml
name: Build & Notarize

on:
  push:
    tags: ['v*']

jobs:
  build:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.app

      - name: Import signing certificate
        env:
          CERTIFICATE_P12: ${{ secrets.CERTIFICATE_P12 }}
          CERTIFICATE_PASSWORD: ${{ secrets.CERTIFICATE_PASSWORD }}
        run: |
          echo "$CERTIFICATE_P12" | base64 --decode > certificate.p12
          security create-keychain -p "" build.keychain
          security default-keychain -s build.keychain
          security unlock-keychain -p "" build.keychain
          security import certificate.p12 -k build.keychain \
            -P "$CERTIFICATE_PASSWORD" -T /usr/bin/codesign
          security set-key-partition-list -S apple-tool:,apple: \
            -s -k "" build.keychain

      - name: Build archive
        run: |
          xcodebuild archive \
            -project SnapGroup.xcodeproj \
            -scheme SnapGroup \
            -configuration Release \
            -archivePath build/SnapGroup.xcarchive \
            CODE_SIGN_IDENTITY="Developer ID Application"

      - name: Export app
        run: |
          xcodebuild -exportArchive \
            -archivePath build/SnapGroup.xcarchive \
            -exportPath build/export \
            -exportOptionsPlist ExportOptions.plist

      - name: Create DMG
        run: |
          brew install create-dmg
          create-dmg \
            --volname "SnapGroup" \
            --volicon "build/export/SnapGroup.app/Contents/Resources/AppIcon.icns" \
            --window-size 660 400 \
            --icon "SnapGroup.app" 180 200 \
            --app-drop-link 480 200 \
            --hide-extension "SnapGroup.app" \
            --no-internet-enable \
            "build/SnapGroup.dmg" \
            "build/export/SnapGroup.app"

      - name: Sign DMG
        run: |
          codesign --sign "Developer ID Application" build/SnapGroup.dmg

      - name: Notarize
        env:
          APPLE_ID: ${{ secrets.APPLE_ID }}
          APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
          APPLE_APP_PASSWORD: ${{ secrets.APPLE_APP_PASSWORD }}
        run: |
          xcrun notarytool submit build/SnapGroup.dmg \
            --apple-id "$APPLE_ID" \
            --team-id "$APPLE_TEAM_ID" \
            --password "$APPLE_APP_PASSWORD" \
            --wait
          xcrun stapler staple build/SnapGroup.dmg

      - name: Upload to GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          files: build/SnapGroup.dmg
```

### 10.3 Required GitHub Secrets

| Secret | Value |
|--------|-------|
| `CERTIFICATE_P12` | Base64-encoded Developer ID Application certificate + private key (.p12) |
| `CERTIFICATE_PASSWORD` | Password for the .p12 file |
| `APPLE_ID` | Apple ID email for notarization |
| `APPLE_TEAM_ID` | 10-character Apple Developer Team ID |
| `APPLE_APP_PASSWORD` | App-specific password from appleid.apple.com |

### 10.4 Local Build Script

Create `scripts/build.sh` for manual releases:

```bash
#!/bin/bash
set -euo pipefail

VERSION=${1:?"Usage: ./scripts/build.sh <version>"}
BUILD_DIR="build"

echo "==> Building SnapGroup v${VERSION}..."

xcodebuild archive \
  -project SnapGroup.xcodeproj \
  -scheme SnapGroup \
  -configuration Release \
  -archivePath "${BUILD_DIR}/SnapGroup.xcarchive"

xcodebuild -exportArchive \
  -archivePath "${BUILD_DIR}/SnapGroup.xcarchive" \
  -exportPath "${BUILD_DIR}/export" \
  -exportOptionsPlist ExportOptions.plist

create-dmg \
  --volname "SnapGroup" \
  --volicon "${BUILD_DIR}/export/SnapGroup.app/Contents/Resources/AppIcon.icns" \
  --window-size 660 400 \
  --icon "SnapGroup.app" 180 200 \
  --app-drop-link 480 200 \
  --hide-extension "SnapGroup.app" \
  --no-internet-enable \
  "${BUILD_DIR}/SnapGroup-${VERSION}.dmg" \
  "${BUILD_DIR}/export/SnapGroup.app"

# Set DMG file icon in Finder
osascript -e '
use framework "AppKit"
set iconPath to POSIX path of "'"$(pwd)/${BUILD_DIR}"'/export/SnapGroup.app/Contents/Resources/AppIcon.icns"
set dmgPath to POSIX path of "'"$(pwd)/${BUILD_DIR}"'/SnapGroup-'"${VERSION}"'.dmg"
set iconImage to current application'\''s NSImage'\''s alloc()'\''s initWithContentsOfFile:iconPath
current application'\''s NSWorkspace'\''s sharedWorkspace()'\''s setIcon:iconImage forFile:dmgPath options:0'

echo "==> Signing DMG..."
codesign --sign "Developer ID Application: Sami Baadarani (Y4M378P55D)" "${BUILD_DIR}/SnapGroup-${VERSION}.dmg"

echo "==> Notarizing..."
xcrun notarytool submit "${BUILD_DIR}/SnapGroup-${VERSION}.dmg" \
  --keychain-profile "SnapGroup-Notary" \
  --wait

xcrun stapler staple "${BUILD_DIR}/SnapGroup-${VERSION}.dmg"

echo "==> Done! Output: ${BUILD_DIR}/SnapGroup-${VERSION}.dmg"
```

---

## 11. Implementation Sequence

### Phase 1: MVP Release (Make It Shippable)

These are the minimum requirements to distribute a signed, notarized build.

- [x] **Set Development Team** in Xcode project (`Y4M378P55D`)
- [x] **Enable Hardened Runtime** (`ENABLE_HARDENED_RUNTIME = YES`)
- [x] **Create entitlements file** (`SnapGroup.entitlements`)
- [x] **Lower deployment target** to macOS 15.0
- [x] **Create shared Xcode scheme** (committed `xcshareddata/xcschemes/SnapGroup.xcscheme`)
- [x] **Add `NSAccessibilityUsageDescription`** to Info.plist build settings
- [x] **Set copyright string** in Info.plist build settings
- [x] **Create `PrivacyInfo.xcprivacy`**
- [x] **Design and add app icon** (all 10 sizes)
- [x] **Fix force casts** (CFBoolean → NSNumber; AXUIElement casts are safe with `.success` check)
- [x] **Wrap `print()` in `#if DEBUG`**
- [x] **Fix deprecated `activate` API calls**
- [x] **Remove dead build settings** (`REGISTER_APP_GROUPS`, `ENABLE_USER_SELECTED_FILES`, `OTHER_CODE_SIGN_FLAGS`)
- [x] **Build, sign, notarize, and verify** the app
- [x] **Create DMG** and notarize it
- [x] **Test on a clean Mac** (fresh user account, no Accessibility pre-granted)

### Phase 2: Polish

- [x] Rename "Preferences" → "Settings"
- [x] Add "About SnapGroup" to menu bar menu (opens native About panel with version + credits)
- [ ] Add "Launch at Login" toggle
- [ ] Add first-launch onboarding window
- [x] Create `Credits.rtf` with HotKey + Sparkle attribution
- [x] Delete dead `ViewController.swift` and strip storyboard
- [ ] ~~Fix `Thread.sleep` on main thread~~ Deferred (acceptable for hotkey retry)
- [x] Fix dark mode layer color updates
- [x] Add version numbering (semver: `1.0.0`)
- [x] Choose and add a `LICENSE` file (MIT)
- [x] Write privacy policy (`PRIVACY.md`)

### Phase 3: Distribution Infrastructure

- [ ] Set up GitHub Actions CI/CD workflow
- [ ] Create local build script (`scripts/build.sh`)
- [x] Create `ExportOptions.plist`
- [ ] Integrate Sparkle for auto-updates
- [ ] Generate EdDSA keys and configure appcast
- [ ] Add "Check for Updates..." menu item
- [ ] Set up landing page / GitHub Pages site

### Phase 4: Launch

- [ ] Write comprehensive README with screenshots/GIF
- [ ] Set GitHub repo description and topics
- [ ] Create OG image for social sharing
- [ ] Prepare and submit to Product Hunt
- [ ] Post Show HN
- [ ] Post to r/macapps
- [ ] Submit to AlternativeTo and curated lists

---

## Dependency Audit

| Dependency | License | Notes |
|------------|---------|-------|
| [HotKey](https://github.com/soffes/HotKey) | MIT | Global hotkey handling via Carbon `RegisterEventHotKey`. Pinned to `v0.2.1` via `upToNextMinorVersion`. |
| [Sparkle](https://sparkle-project.org/) | MIT | Auto-update framework. **Not yet added** — see Section 4. |
