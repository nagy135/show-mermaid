#!/usr/bin/env bash
# Builds build/Show Mermaid.app. Pass --install to copy it to ~/Applications.
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Show Mermaid.app"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/ShowMermaid"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/ShowMermaid"
cp Support/Info.plist "$APP/Contents/Info.plist"
cp Vendor/mermaid.min.js "$APP/Contents/Resources/mermaid.min.js"
cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"

echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
    mkdir -p ~/Applications
    rm -rf ~/Applications/"Show Mermaid.app"
    cp -R "$APP" ~/Applications/
    echo "Installed to ~/Applications/Show Mermaid.app"
fi
