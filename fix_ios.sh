#!/bin/bash

# Fix iOS Build Script
# Usage: ./fix_ios.sh

echo "=========================================="
echo "🛠️  Starting iOS Build Repair..."
echo "=========================================="

echo "🧹 Cleaning Xcode DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*

echo "🧹 Cleaning Flutter artifacts..."
flutter clean

echo "📥 Installing Dart dependencies..."
flutter pub get

echo "🍎 Re-installing iOS Pods..."
cd ios || exit
rm -rf Pods
rm -f Podfile.lock
pod install --repo-update

# Fixes for Project Settings
echo "🔧 Patching Xcode Project..."

# 1. Disable Sandboxing (Common cause of script failures)
sed -i '' 's/ENABLE_USER_SCRIPT_SANDBOXING = YES/ENABLE_USER_SCRIPT_SANDBOXING = NO/g' Runner.xcodeproj/project.pbxproj

# 2. Use Bash instead of Sh (Fixes interpreter mismatches)
# Target: /bin/sh "$FLUTTER_ROOT
# Replace: /bin/bash "$FLUTTER_ROOT
LC_ALL=C sed -i '' 's|/bin/sh \\"$FLUTTER_ROOT|/bin/bash \\"$FLUTTER_ROOT|g' Runner.xcodeproj/project.pbxproj

echo "✅ Repair Complete!"
echo "🚀 Try running your app now: 'flutter run'"
echo "=========================================="
