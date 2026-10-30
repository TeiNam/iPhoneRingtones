#!/usr/bin/env bash
# 마지막 릴리스 버전과 그 뒤의 커밋 메시지(stdin)로 다음 버전을 정한다 (Conventional Commits 기준).
#   type!: 또는 BREAKING CHANGE → major, feat → minor, 그 밖 → patch, 첫 릴리스(버전 없음) → 1.0.0
# 사용법: git log --format=%B v1.2.3..HEAD | scripts/next-version.sh 1.2.3
set -euo pipefail

last="${1:-}"
messages="$(cat)"

if [[ -z "$last" ]]; then
    echo "1.0.0"
    exit 0
fi
if [[ ! "$last" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    echo "next-version: 버전 형식이 X.Y.Z 가 아닙니다: $last" >&2
    exit 1
fi
major="${BASH_REMATCH[1]}"
minor="${BASH_REMATCH[2]}"
patch="${BASH_REMATCH[3]}"

if grep -qE '^[a-z]+(\([^)]*\))?!:|BREAKING[ -]CHANGE' <<<"$messages"; then
    echo "$((major + 1)).0.0"
elif grep -qE '^feat(\([^)]*\))?:' <<<"$messages"; then
    echo "$major.$((minor + 1)).0"
else
    echo "$major.$minor.$((patch + 1))"
fi
