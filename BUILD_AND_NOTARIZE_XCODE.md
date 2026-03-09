# Build, Sign, Notarize & Verify via Xcode — SnapGroup

## Prerequisites

- Xcode 14+
- Apple Developer Program enrollment
- **Developer ID Application** certificate installed in Keychain
- Signed into your Apple Developer account in Xcode

### Verify your Apple account in Xcode

1. Open **Xcode → Settings** (Cmd+,)
2. Go to the **Accounts** tab
3. Your Apple ID should be listed with Team **"Sami Baadarani (Y4M378P55D)"**
4. If not, click **+** → Add Apple ID → sign in
5. Click **Manage Certificates...** and confirm **"Developer ID Application"** is listed
   - If missing, click **+** → Developer ID Application to create one

---

## Step 1: Configure Signing Settings

1. Open `SnapGroup.xcodeproj` in Xcode
2. Select the **SnapGroup** project in the navigator (blue icon)
3. Select the **SnapGroup** target
4. Go to **Signing & Capabilities** tab
5. Verify:
   - **Team:** Sami Baadarani (Y4M378P55D)
   - **Signing Certificate:** Shows "Development" (this is normal — the export step handles Developer ID)
   - **Hardened Runtime** capability is listed

---

## Step 2: Set the Scheme to Release

1. In the menu bar: **Product → Scheme → Edit Scheme...** (Cmd+Shift+<)
2. Select **Archive** in the left sidebar
3. Set **Build Configuration** to **Release**
4. Click **Close**

---

## Step 3: Archive the App

1. In the menu bar: **Product → Archive**
   - If "Archive" is grayed out, make sure the scheme destination is set to **"My Mac"** (not a simulator) in the toolbar
2. Wait for the build to complete
3. When done, the **Organizer** window opens automatically showing your archive

---

## Step 4: Distribute (Export + Sign with Developer ID)

1. In the **Organizer** (Window → Organizer if it didn't open), select the archive you just created
2. Click **Distribute App**
3. Select **Developer ID** → click **Next**
4. Select **Export** (creates a signed .app locally; "Upload" sends it to Apple for notarization directly — see Step 5 for that option)
5. Select **Automatically manage signing** → click **Next**
6. Review the signing details:
   - Should show **"Developer ID Application: Sami Baadarani (Y4M378P55D)"**
7. Click **Export**
8. Choose a destination folder (e.g., `Desktop/SnapGroup-export`)
9. Wait for the export to finish

You now have a `SnapGroup.app` signed with Developer ID.

---

## Step 5: Notarize

You have two options:

### Option A: Notarize via Xcode (recommended)

Instead of choosing **Export** in Step 4, do this:

1. In the **Organizer**, select the archive
2. Click **Distribute App**
3. Select **Developer ID** → click **Next**
4. Select **Upload** (instead of Export)
5. Select **Automatically manage signing** → click **Next**
6. Click **Upload**
7. Xcode uploads to Apple's notarization service and **waits for the result**
8. When it shows **"Ready to distribute"** with a green checkmark, click **Export Notarized App**
9. Choose a destination folder — this gives you the notarized, stapled `.app`

### Option B: Notarize via CLI (if Xcode upload hangs)

If Xcode's upload option doesn't work, use the exported `.app` from Step 4:

```bash
ditto -c -k --keepParent /path/to/SnapGroup.app SnapGroup.zip
xcrun notarytool submit SnapGroup.zip --keychain-profile "SnapGroup-Notary" --wait
```

---

## Step 6: Create DMG (optional, for distribution)

If you want to distribute as a DMG instead of a bare .app:

```bash
brew install create-dmg  # if not already installed

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

Then notarize and staple the DMG:

```bash
xcrun notarytool submit SnapGroup.dmg --keychain-profile "SnapGroup-Notary" --wait
xcrun stapler staple SnapGroup.dmg
```

---

## Step 7: Verify

### Verify via Xcode

If you used **Option A** (Upload via Xcode), Xcode already verified notarization before giving you the "Ready to distribute" result. The exported app is signed, notarized, and stapled.

### Verify via CLI

```bash
# Verify code signature
codesign --verify --deep --strict /path/to/SnapGroup.app

# Check signing details
codesign -dvv /path/to/SnapGroup.app

# Verify Gatekeeper will accept it
spctl --assess --type execute /path/to/SnapGroup.app

# If you made a DMG, verify that too
spctl --assess --type open --context context:primary-signature SnapGroup.dmg
xcrun stapler validate SnapGroup.dmg
```

---

## Summary of the Xcode Flow

| Step | Where | Action |
|------|-------|--------|
| Configure signing | Xcode → Target → Signing & Capabilities | Verify team and hardened runtime |
| Set Release config | Product → Scheme → Edit Scheme → Archive | Set to Release |
| Archive | Product → Archive | Builds the archive |
| Distribute + Notarize | Organizer → Distribute App → Developer ID → Upload | Signs, uploads, notarizes, staples |
| Export | "Ready to distribute" → Export Notarized App | Saves the final .app |
| Create DMG | Terminal (create-dmg) | Optional packaging step |
| Verify | Terminal (codesign, spctl) | Confirm everything is correct |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "Archive" is grayed out | Set the scheme destination to **"My Mac"** in the toolbar (not a simulator) |
| No "Developer ID" option in Distribute App | You're not enrolled in the Apple Developer Program, or your account isn't added in Xcode → Settings → Accounts |
| "No signing certificate found" during export | Click **Manage Certificates** in Xcode → Settings → Accounts → your team, and create a Developer ID Application certificate |
| Notarization stuck "In Progress" | Try again later or use the Xcode Upload path instead of CLI |
| "Ready to distribute" never appears | Check your internet connection; look at the Xcode activity bar at the top for progress or errors |
| Exported app blocked by Gatekeeper | It wasn't notarized — go back to Step 5 and use the Upload option |
