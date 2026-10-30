#!/usr/bin/env bash
# .app 을 배포용 DMG 로 묶는다. DMG 를 열면 앱과 Applications 바로가기가 보여 끌어서 설치할 수 있다.
# 사용법: scripts/make-dmg.sh <앱.app> <출력.dmg>   (build.sh 가 마지막에 부른다)
set -euo pipefail

if [[ $# -ne 2 || ! -d "$1" ]]; then
    echo "사용법: $0 <앱.app> <출력.dmg>" >&2
    exit 1
fi
APP="$1"
DMG="$2"
NAME="$(basename "$APP" .app)"

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

# ditto 는 번들의 서명·확장 속성을 그대로 복사한다
ditto "$APP" "$STAGING/$NAME.app"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG"
hdiutil create -volname "$NAME" -srcfolder "$STAGING" -fs HFS+ -format UDZO -quiet "$DMG"
hdiutil verify -quiet "$DMG"
