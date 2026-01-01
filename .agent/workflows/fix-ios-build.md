---
description: Fix iOS build errors (PhaseScriptExecution failed, Module not found)
---

# Fix iOS Build Errors

Use this workflow when you see Xcode errors like:
- "Command PhaseScriptExecution failed"
- "Module 'xyz' not found"
- "No such module 'app_links'" (or any pod module)

## Step 1: Run Flutter Analyzer First

Check for Dart code errors that cause build failures:

```bash
cd /Users/alexdamore/Desktop/Vibe_Code/Antigravity/Antigravity_Dec282025_Nertz/nertz_royale
flutter analyze 2>&1 | grep -E "error|Error"
```

If there are errors, fix them before proceeding.

## Step 2: Clean Everything

// turbo
```bash
cd /Users/alexdamore/Desktop/Vibe_Code/Antigravity/Antigravity_Dec282025_Nertz/nertz_royale
flutter clean
rm -rf ios/Pods ios/Podfile.lock ios/.symlinks
rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*
rm -rf ~/Library/Developer/Xcode/DerivedData
```

## Step 3: Reinstall Dependencies

// turbo
```bash
cd /Users/alexdamore/Desktop/Vibe_Code/Antigravity/Antigravity_Dec282025_Nertz/nertz_royale
flutter pub get
cd ios && pod deintegrate && pod install --repo-update && cd ..
```

## Step 4: Rebuild with Flutter

// turbo
```bash
cd /Users/alexdamore/Desktop/Vibe_Code/Antigravity/Antigravity_Dec282025_Nertz/nertz_royale
flutter build ios --no-codesign
```

## Step 5: Open in Xcode Correctly

**IMPORTANT:** Always open the `.xcworkspace` file, NOT `.xcodeproj`:

```bash
open /Users/alexdamore/Desktop/Vibe_Code/Antigravity/Antigravity_Dec282025_Nertz/nertz_royale/ios/Runner.xcworkspace
```

Then in Xcode:
1. Product → Clean Build Folder (Shift+Cmd+K)
2. Build (Cmd+B)

## Common Root Causes

| Error | Likely Cause |
|-------|-------------|
| Missing method/undefined | Incomplete Dart code - run `flutter analyze` |
| Module not found | Stale Xcode cache or opened .xcodeproj instead of .xcworkspace |
| PhaseScriptExecution failed | Can be either of the above - check the detailed error message |
| Path with spaces in error | Old cached data from renamed project folder |
