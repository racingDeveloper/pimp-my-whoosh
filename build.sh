#!/bin/bash
# Builds "Pimp My Whoosh.app" into ./build. Only the Xcode Command Line Tools are needed, not Xcode.
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Pimp My Whoosh.app"
rm -rf "$APP" build/obj
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/obj

# Universal binary: Apple Silicon + Intel.
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -parse-as-library \
    -target "$arch-apple-macos13.0" \
    -o "build/obj/PimpMyWhoosh-$arch" Sources/*.swift
done
lipo -create -output "$APP/Contents/MacOS/PimpMyWhoosh" build/obj/PimpMyWhoosh-arm64 build/obj/PimpMyWhoosh-x86_64

cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp -R Resources/*.lproj "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key><string>Pimp My Whoosh</string>
	<key>CFBundleDisplayName</key><string>Pimp My Whoosh</string>
	<key>CFBundleIdentifier</key><string>com.pimpmywhoosh.app</string>
	<key>CFBundleExecutable</key><string>PimpMyWhoosh</string>
	<key>CFBundleIconFile</key><string>AppIcon</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>0.0.1</string>
	<key>CFBundleVersion</key><string>1</string>
	<key>CFBundleDevelopmentRegion</key><string>en</string>
	<key>CFBundleLocalizations</key>
	<array>
		<string>en</string>
		<string>it</string>
	</array>
	<key>LSMinimumSystemVersion</key><string>13.0</string>
	<key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
	<key>NSHighResolutionCapable</key><true/>
	<key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

# Ad-hoc signature: enough to run locally. Distributed builds need a Developer ID signature and notarization.
codesign --force --sign - "$APP"
echo "OK: $APP"
