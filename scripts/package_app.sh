#!/usr/bin/env bash
# 未実行の手順ドラフト。Azure に対する実機検証は行っていません。
set -euo pipefail

if [[ $# -ne 1 || ! "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  echo '使い方: bash scripts/package_app.sh <version>（英数字で開始し、英数字・.・_・- のみ）' >&2
  exit 1
fi
if ! command -v zip >/dev/null 2>&1; then
  echo 'zip が必要です。配布端末の社内ルールに従って用意してください。' >&2
  exit 1
fi
if command -v shasum >/dev/null 2>&1; then
  hash_command=(shasum -a 256)
elif command -v sha256sum >/dev/null 2>&1; then
  hash_command=(sha256sum)
else
  echo 'shasum または sha256sum が必要です。' >&2
  exit 1
fi
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
archive_name="app-$1.zip"
mkdir -p "$repo_dir/outputs"
if [[ -e "$repo_dir/outputs/$archive_name" || -e "$repo_dir/outputs/$archive_name.sha256" ]]; then
  echo '同じ版の配布物が既にあります。別の version を指定してください。' >&2
  exit 1
fi
package_tmp="$(mktemp -d)"
trap 'rm -rf "$package_tmp"' EXIT
(
  cd "$repo_dir/assets/app"
  zip -q -r "$package_tmp/$archive_name" app requirements.txt \
    -x '*/__pycache__/*' '*.pyc' '*/.DS_Store' '.DS_Store'
)
cp "$package_tmp/$archive_name" "$repo_dir/outputs/$archive_name"
(
  cd "$repo_dir/outputs"
  "${hash_command[@]}" "$archive_name" | tee "$archive_name.sha256"
)
