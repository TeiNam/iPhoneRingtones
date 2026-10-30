#!/usr/bin/env bash
# scripts/next-version.sh 자체 검사 — 릴리스 워크플로가 버전을 정하기 전에 돌린다.
set -euo pipefail
cd "$(dirname "$0")"

check() { # check <기대 버전> <마지막 버전> <커밋 메시지>
    local actual
    actual="$(printf '%s\n' "$3" | ./next-version.sh "$2")"
    if [[ "$actual" != "$1" ]]; then
        echo "실패: 마지막 '$2' + 메시지 '$3' → $actual (기대: $1)" >&2
        exit 1
    fi
}

check 1.0.0 "" "feat: 첫 기능"
check 1.0.1 1.0.0 "fix: 버그 수정 (#3)"
check 1.0.1 1.0.0 "refactor: 내부 정리"
check 1.1.0 1.0.1 $'fix: 하나\nfeat(ui): 파형 추가 (#4)'
check 1.1.0 1.0.1 $'fix: 본문에만 feat 언급\n\n- feat: 이 줄은 제목이 아니다\nfeat: 이 줄은 제목이다'
check 2.0.0 1.1.0 "feat!: 설정 형식 변경"
check 2.0.0 1.1.0 $'refactor: 정리\n\nBREAKING CHANGE: 최소 macOS 16'
check 1.0.1 1.0.0 "docs: feat 라는 단어만 들어간 문서"

if printf 'fix: x\n' | ./next-version.sh "v1.0" 2>/dev/null; then
    echo "실패: 잘못된 버전 형식을 받아들였습니다" >&2
    exit 1
fi
echo "next-version: 모든 검사 통과"
