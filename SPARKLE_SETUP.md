# Sparkle Auto-Update Setup

## Step 1: Generate EdDSA Key Pair (one-time)

Download the latest Sparkle release from https://github.com/sparkle-project/Sparkle/releases and extract it.

```bash
# Generate key pair
./bin/generate_keys
```

This will:
- Save the **private key** to your login Keychain (service: `https://sparkle-project.org`, account: `ed25519`)
- Print the **public key** as a base64 string

### Save the public key

Open `Info.plist` in the project root and replace `PLACEHOLDER_REPLACE_WITH_EDDSA_PUBLIC_KEY` with the base64 public key string.

### Back up the private key

```bash
./bin/generate_keys -x
```

Store the exported private key securely (password manager, encrypted disk). If you lose it, existing users cannot verify updates and you'd need to ship a transitional release with a new key.

---

## Step 2: Release Workflow

Run these steps each time you publish a new version.

### 2.1 Build, sign, and notarize

Follow the existing process in `DISTRIBUTION_CHECKLIST.md` (sections 1.4 and 3):

```bash
# Archive
xcodebuild archive \
  -project SnapGroup.xcodeproj \
  -scheme SnapGroup \
  -configuration Release \
  -archivePath build/SnapGroup.xcarchive

# Export
xcodebuild -exportArchive \
  -archivePath build/SnapGroup.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist

# Create DMG
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

# Sign DMG
codesign --sign "Developer ID Application: Sami Baadarani (Y4M378P55D)" build/SnapGroup.dmg

# Notarize
xcrun notarytool submit build/SnapGroup.dmg \
  --keychain-profile "SnapGroup-Notary" \
  --wait

# Staple
xcrun stapler staple build/SnapGroup.dmg
```

### 2.2 Sign DMG for Sparkle

```bash
./bin/sign_update build/SnapGroup.dmg
```

This outputs an `edSignature` and `length` — you'll need both for the appcast.

### 2.3 Update the appcast

**Option A: Automatic (recommended)**

Place all release DMGs in a single directory and run:

```bash
# --download-url-prefix is REQUIRED. Without it, enclosure URLs are written as
# bare filenames (e.g. "SnapGroup.dmg") instead of real download URLs.
./bin/generate_appcast \
  --download-url-prefix "https://github.com/sami-baadarani/SnapGroup/releases/download/v1.0.1/" \
  /path/to/releases/
```

Copy the generated `appcast.xml` to the project root.

> **GitHub Releases caveat:** every GitHub asset URL embeds its own tag
> (`.../download/v1.0.1/SnapGroup.dmg`), so a single `--download-url-prefix`
> only works when every DMG in the folder belongs to the *same* release. If you
> keep multiple historical DMGs in one folder, either host them in a single flat
> directory (e.g. GitHub Pages) or use **Option B** and add one `<item>` by hand
> per release.

**Option B: Manual**

Create or update `appcast.xml` in the project root:

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>SnapGroup Updates</title>
    <language>en</language>
    <item>
      <title>Version 1.0.1</title>
      <pubDate>Sat, 14 Mar 2026 12:00:00 +0000</pubDate>
      <sparkle:version>2</sparkle:version>
      <sparkle:shortVersionString>1.0.1</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
      <description><![CDATA[
        <h2>What's New</h2>
        <ul>
          <li>Bug fixes and improvements</li>
        </ul>
      ]]></description>
      <enclosure
        url="https://github.com/sami-baadarani/SnapGroup/releases/download/v1.0.1/SnapGroup.dmg"
        length="FILESIZE_IN_BYTES"
        type="application/octet-stream"
        sparkle:edSignature="ED_SIGNATURE_FROM_SIGN_UPDATE"
      />
    </item>
  </channel>
</rss>
```

Key fields:
- `sparkle:version` — the build number (`CURRENT_PROJECT_VERSION`, integer)
- `sparkle:shortVersionString` — the display version (`MARKETING_VERSION`, e.g. "1.0.1")
- `sparkle:minimumSystemVersion` — must be <= your deployment target (15.0)
- `sparkle:edSignature` — from the `sign_update` output
- `length` — exact file size in bytes of the DMG
- `url` — direct download URL (GitHub Release asset)

### 2.4 Publish

```bash
# Create GitHub Release and upload DMG
gh release create v1.0.1 build/SnapGroup.dmg --title "v1.0.1" --notes "Release notes here"

# Commit and push appcast
git add appcast.xml
git commit -m "Update appcast for v1.0.1"
git push
```

---

## How It Works

- On launch, Sparkle checks `appcast.xml` at the `SUFeedURL` in Info.plist
- On second launch, Sparkle asks the user if they want automatic update checks
- When an update is found, Sparkle shows a prompt with release notes
- The update is verified using the EdDSA signature against the `SUPublicEDKey` in Info.plist
- "Check for Updates..." in the menu bar menu triggers a manual check

## Appcast Hosting

Currently configured to use GitHub raw URL:
```
https://raw.githubusercontent.com/sami-baadarani/SnapGroup/main/appcast.xml
```

Alternative: use GitHub Pages for CDN-backed delivery. Update `SUFeedURL` in `Info.plist` if you change the hosting.
