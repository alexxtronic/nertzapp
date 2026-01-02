#!/bin/bash
set -e

echo "🧹 Cleaning Flutter build..."
flutter clean

echo "🗑️ Removing iOS Pods and Lockfile..."
rm -rf ios/Pods
rm -rf ios/Podfile.lock

echo "📦 Installing Dependencies..."
flutter pub get

echo "📦 Installing Pods..."
cd ios
# Install pods and update repo to ensure we have latest specs
pod install --repo-update

echo "✅ iOS environment reset complete!"
echo "🚀 Try running your build now."
