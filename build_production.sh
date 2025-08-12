#!/bin/bash
echo "Building Flutter app for PRODUCTION..."

# Build for Android
echo "Building Android APK..."
flutter build apk --dart-define=ENV=production --release


echo "Production builds completed!"
