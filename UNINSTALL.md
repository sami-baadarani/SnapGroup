# Uninstalling & Resetting SnapGroup

## 1. Remove the built app

```bash
# Remove from /Applications if copied there
rm -rf /Applications/SnapGroup.app

# Remove Xcode's derived data for a clean rebuild
rm -rf ~/Library/Developer/Xcode/DerivedData/SnapGroup-*
```

## 2. Reset Accessibility permissions

```bash
# Reset for SnapGroup only
tccutil reset Accessibility dev.samib.SnapGroup

# If per-bundle reset doesn't work, reset all Accessibility permissions
tccutil reset Accessibility
```

Or manually remove it in **System Settings > Privacy & Security > Accessibility** using the minus button.

## 3. Clear UserDefaults (hotkey settings)

```bash
defaults delete dev.samib.SnapGroup
```

## 4. Rebuild

1. Open `SnapGroup.xcodeproj` in Xcode
2. Clean Build: **Cmd+Shift+K**
3. Build & Run: **Cmd+R**
4. The app will re-prompt for Accessibility permission on first launch
