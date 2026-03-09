# Build, Sign, Notarize & Verify — SnapGroup

## Prerequisites

- Xcode 14+
- Apple Developer Program enrollment
- **Developer ID Application** certificate installed in Keychain
  - Create at [developer.apple.com/account/resources/certificates](https://developer.apple.com/account/resources/certificates)
  - Select "Developer ID Application", upload a CSR from Keychain Access, download and double-click the `.cer` to install
- `create-dmg` installed (`brew install create-dmg`)
- App-specific password from [appleid.apple.com](https://appleid.apple.com) → Sign-In and Security → App-Specific Passwords

Verify your certificate is installed:

```bash
security find-identity -v -p codesigning
# Should show: "Developer ID Application: Sami Baadarani (Y4M378P55D)"
```

## Step 0: Store Notarization Credentials (one-time)

```bash
xcrun notarytool store-credentials "SnapGroup-Notary" \
  --apple-id "YOUR_APPLE_ID_EMAIL" \
  --team-id "Y4M378P55D" \
  --password "YOUR_APP_SPECIFIC_PASSWORD"
```

## Step 1: Archive

```bash
xcodebuild archive \
  -project SnapGroup.xcodeproj \
  -scheme SnapGroup \
  -configuration Release \
  -archivePath build/SnapGroup.xcarchive
```

## Step 2: Export

```bash
xcodebuild -exportArchive \
  -archivePath build/SnapGroup.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist
```

Produces `build/export/SnapGroup.app` signed with "Developer ID Application".

## Step 3: Create DMG

```bash
create-dmg \
  --volname "SnapGroup" \
  --window-size 660 400 \
  --icon "SnapGroup.app" 180 200 \
  --app-drop-link 480 200 \
  --hide-extension "SnapGroup.app" \
  --no-internet-enable \
  "build/SnapGroup.dmg" \
  "build/export/SnapGroup.app"
```

## Step 4: Notarize

```bash
xcrun notarytool submit build/SnapGroup.dmg \
  --keychain-profile "SnapGroup-Notary" \
  --wait
```

Usually takes 2-15 minutes. You'll see `status: Accepted` on success.

## Step 5: Staple

```bash
xcrun stapler staple build/SnapGroup.dmg
```

Embeds the notarization ticket so users can verify offline.

## Step 6: Verify

```bash
spctl --assess --type open --context context:primary-signature build/SnapGroup.dmg
xcrun stapler validate build/SnapGroup.dmg
```

Both should pass silently (no output or "accepted").

## All-in-One

```bash
rm -rf build

xcodebuild archive \
  -project SnapGroup.xcodeproj \
  -scheme SnapGroup \
  -configuration Release \
  -archivePath build/SnapGroup.xcarchive && \
xcodebuild -exportArchive \
  -archivePath build/SnapGroup.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist && \
create-dmg \
  --volname "SnapGroup" \
  --window-size 660 400 \
  --icon "SnapGroup.app" 180 200 \
  --app-drop-link 480 200 \
  --hide-extension "SnapGroup.app" \
  --no-internet-enable \
  "build/SnapGroup.dmg" \
  "build/export/SnapGroup.app" && \
xcrun notarytool submit build/SnapGroup.dmg \
  --keychain-profile "SnapGroup-Notary" \
  --wait && \
xcrun stapler staple build/SnapGroup.dmg
```

## Troubleshooting

| Error | Fix |
|-------|-----|
| "No signing certificate 'Developer ID Application' found" | Create the certificate at [developer.apple.com](https://developer.apple.com/account/resources/certificates/list) → + → Developer ID Application. Download and double-click to install. |
| Notarization rejected | Run `xcrun notarytool log <submission-id> --keychain-profile "SnapGroup-Notary"` for details. |
| `spctl` fails | DMG wasn't stapled, or the app inside wasn't signed with Developer ID. |
| "No accounts with 'Developer ID' found" | Your Apple Developer Program membership may have expired or you're signed into the wrong team in Xcode. |
