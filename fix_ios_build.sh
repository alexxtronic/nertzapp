#!/bin/bash
set -e

echo "🧹 Cleaning project..."
flutter clean
rm -rf ios/Pods
rm -f ios/Podfile.lock

echo "📦 Getting flutter packages..."
flutter pub get

echo "🥥 Installing pods..."
cd ios
pod install
cd ..

echo "🔧 Patching frameworks.sh manually..."
FRAMEWORKS_SCRIPT="ios/Pods/Target Support Files/Pods-Runner/Pods-Runner-frameworks.sh"

if [ -f "$FRAMEWORKS_SCRIPT" ]; then
    # Replace the readlink line with the Python version which handles spaces correctly
    # We use a temporary file to avoid sed issues on macOS
    sed 's/source=\"$(readlink \"${source}\")\"/source=\"$(python3 -c \"import os, sys; print(os.path.realpath(sys.argv[1]))\" \"${source}\")\"/g' "$FRAMEWORKS_SCRIPT" > "$FRAMEWORKS_SCRIPT.tmp" && mv "$FRAMEWORKS_SCRIPT.tmp" "$FRAMEWORKS_SCRIPT"
    chmod +x "$FRAMEWORKS_SCRIPT"
    echo "✅ Patched frameworks.sh successfully (Python method)"
else
    echo "❌ frameworks.sh not found at $FRAMEWORKS_SCRIPT"
    exit 1
fi

echo "🚀 Build environment fixed!"
