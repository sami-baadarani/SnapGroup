# Releasing a new version of SnapGroup

> One-time setup (already done): EdDSA signing key in Keychain, `SnapGroup-Notary`
> notarytool profile, Developer ID certificate. Run all commands from the project root.

## 1. Bump the version
In the SnapGroup target's build settings (before archiving):
- **`CURRENT_PROJECT_VERSION`** — must **increase every release** (this is Sparkle's `sparkle:version`). e.g. `2 → 3`
- **`MARKETING_VERSION`** — the display version. e.g. `0.2.0 → 0.3.0`

## 2. Archive & export (Xcode)
1. **Product → Archive**
2. **Organizer → Distribute App → Developer ID → Export**
3. When prompted for the export location, choose the project's **`build/`** folder → `build/SnapGroup <date>/SnapGroup.app`. Note that folder name for the next step.

## 3. Build the DMG
```bash
cd ~/Data/mac-apps/SnapGroup
mkdir -p build
rm -f build/SnapGroup.dmg                      # create-dmg can't overwrite an existing file

SRC="build/SnapGroup <date>/SnapGroup.app"

create-dmg \
  --volname "SnapGroup" \
  --volicon "$SRC/Contents/Resources/AppIcon.icns" \
  --window-size 660 400 \
  --icon "SnapGroup.app" 180 200 \
  --app-drop-link 480 200 \
  --hide-extension "SnapGroup.app" \
  --no-internet-enable \
  "build/SnapGroup.dmg" \
  "$SRC"
```

## 4. Sign → notarize → staple the DMG (in this order)
```bash
codesign --sign "Developer ID Application: Sami Baadarani (Y4M378P55D)" build/SnapGroup.dmg
xcrun notarytool submit build/SnapGroup.dmg --keychain-profile "SnapGroup-Notary" --wait
xcrun stapler staple build/SnapGroup.dmg
```
> Notarize fails with an "agreement" error? Accept the updated agreement at
> developer.apple.com/account (and App Store Connect → Business), then re-run.

## 5. Sign for Sparkle — MUST be last
Stapling rewrites the file, so the Sparkle signature must be taken from the **final stapled DMG**:
```bash
SIGN_UPDATE=$(find ~/Library/Developer/Xcode/DerivedData -path '*artifacts/sparkle/Sparkle/bin/sign_update' 2>/dev/null | head -1)
"$SIGN_UPDATE" build/SnapGroup.dmg
```
Copy the printed **`sparkle:edSignature`** and **`length`**.

## 6. Update `appcast.xml`
Add a new `<item>` at the **top** (copy the previous one) and set:
- `sparkle:version` → new `CURRENT_PROJECT_VERSION`
- `sparkle:shortVersionString` → new `MARKETING_VERSION`
- `pubDate` → output of `date -u "+%a, %d %b %Y %H:%M:%S +0000"`
- `enclosure url` → `https://github.com/sami-baadarani/SnapGroup/releases/download/vX.Y.Z/SnapGroup.dmg`
- `length` and `sparkle:edSignature` → from step 5

## 7. Update `RELEASE_NOTES.md`, commit, and push
```bash
git commit -am "Release vX.Y.Z"      # version bump + appcast + release notes
git push                              # appcast must be live on main; the next step's tag lands here
```

## 8. Create the GitHub release
```bash
gh release create vX.Y.Z build/SnapGroup.dmg \
  --title "vX.Y.Z" \
  --notes-file RELEASE_NOTES.md
```
Straight quotes only. The tag (`vX.Y.Z`) and asset name (`SnapGroup.dmg`) **must match** the appcast `url`.

---

✅ Done. Anyone on an older build is offered the update at their next Sparkle check.
(Replace `vX.Y.Z` and the export folder's `<date>` throughout with the real values.)
