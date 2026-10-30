#!/usr/bin/env bash
# iPhoneRingtones.app 빌드 — Xcode 없이 Command Line Tools 만으로 arm64 + x86_64 Universal 번들을 만든다.
# 사용법: ./build.sh   →   테스트 후 build/iPhoneRingtones.app 과 배포용 build/iPhoneRingtones.dmg 생성
set -euo pipefail

APP_NAME="iPhoneRingtones"
BUNDLE_ID="dev.rastalion.iPhoneRingtones"
# 릴리스 워크플로는 VERSION 을 넘긴다. 로컬 빌드는 마지막 릴리스 태그(없으면 1.0.0)를 쓴다
VERSION="${VERSION:-$(git describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null | sed 's/^v//' || true)}"
VERSION="${VERSION:-1.0.0}"
MIN_MACOS="15.0" # Package.swift 의 platforms(.macOS(.v15)) 와 같게 유지
PRODUCT="iPhoneRingtones" # Package.swift 의 executableTarget 이름 = swift build 가 만드는 실행 파일 이름

cd "$(dirname "$0")"
APP_DIR="build/$APP_NAME.app"

# CLT 의 swift test 는 Swift Testing 매크로 플러그인 경로를 스스로 넘기지 않아 직접 알려 준다
TOOLCHAIN_USR="$(dirname "$(dirname "$(xcrun --find swift)")")"
swift test -Xswiftc -plugin-path -Xswiftc "$TOOLCHAIN_USR/lib/swift/host/plugins/testing"

BUILD_FLAGS=(-c release --arch arm64 --arch x86_64)
swift build "${BUILD_FLAGS[@]}"
BINARY="$(swift build "${BUILD_FLAGS[@]}" --show-bin-path)/$PRODUCT"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BINARY" "$APP_DIR/Contents/MacOS/$APP_NAME"

# 앱 아이콘: 코드로 그린 PNG 세트를 iconutil 로 .icns 로 묶는다 (asset catalog 를 만드는 actool 은 Xcode 에만 있다)
ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET"
swift scripts/make-icon.swift "$ICONSET"
iconutil -c icns "$ICONSET" -o "$APP_DIR/Contents/Resources/AppIcon.icns"

cat >"$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>ko</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>$MIN_MACOS</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
plutil -lint "$APP_DIR/Contents/Info.plist"

# Apple Silicon 은 서명 없는 코드를 실행하지 않으므로 Info.plist 까지 묶어 ad-hoc 서명한다
codesign --force --sign - "$APP_DIR"
codesign --verify --strict "$APP_DIR"

DMG="build/$APP_NAME.dmg"
scripts/make-dmg.sh "$APP_DIR" "$DMG"

echo "완료: $APP_DIR ($(lipo -archs "$APP_DIR/Contents/MacOS/$APP_NAME")), $DMG"
