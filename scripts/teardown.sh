#!/usr/bin/env bash
# 未実行の手順ドラフト。Azure に対する実機検証は行っていません。
set -euo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
fail() { printf '%s\n' "$*" >&2; exit 1; }
[[ -f .env ]] || fail '.env がありません。.env.example をコピーしてください。'
# .env は shell コードです。信頼できるローカルファイルだけを読み込みます。
source .env
require_value() {
  local field="$1" value
  value="${!field:-}"
  [[ -n "$value" && "$value" != *'<'* && "$value" != *'>'* ]] || \
    fail "$field のプレースホルダーを設定してください。"
}
for field in AZURE_SUBSCRIPTION_ID AZURE_TENANT_ID AZURE_RESOURCE_GROUP; do
  require_value "$field"
done

ACTION="${1:---status}"
case "$ACTION" in
  --delete)
    [[ $# -eq 2 && "$2" == "$AZURE_RESOURCE_GROUP" ]] || \
      fail '削除は --delete <.env と同じ専用 RG 名> で指定してください。'
    ;;
  --status) [[ $# -le 1 ]] || fail '使い方: --status または --delete <専用 RG 名>' ;;
  *) fail '使い方: --status または --delete <専用 RG 名>' ;;
esac
TEARDOWN_MAX_POLLS="${TEARDOWN_MAX_POLLS:-60}"
[[ "$TEARDOWN_MAX_POLLS" =~ ^[1-9][0-9]{0,3}$ ]] || fail 'TEARDOWN_MAX_POLLS は 1〜9999 の整数にします。'
# 自動ログインはしません。未ログイン時は利用者が az login を実行します。
command -v az >/dev/null 2>&1 || fail 'Azure CLI が見つかりません。'
ACTIVE_TENANT="$(az account show --subscription "$AZURE_SUBSCRIPTION_ID" --query tenantId --output tsv)"
[[ "$ACTIVE_TENANT" == "$AZURE_TENANT_ID" ]] || fail '対象テナントが .env と一致しません。'

rg_exists() {
  local result
  result="$(az group exists --subscription "$AZURE_SUBSCRIPTION_ID" --name "$AZURE_RESOURCE_GROUP" --output tsv)" || return 1
  [[ "$result" == true || "$result" == false ]] || fail 'RG 状態を判定できません。'
  printf '%s' "$result"
}
EXISTS="$(rg_exists)"
if [[ "$EXISTS" == false ]]; then
  printf '%s\n' 'RG は存在しません。soft-delete / purge、RG 外、Defender と費用は別途確認してください。'
  exit 0
fi
if [[ "$ACTION" == --status ]]; then
  printf '%s\n' 'RG はまだ存在します。削除完了ではありません。'
  exit 2
fi
# RG 内の全リソースが対象です。共有 RG では実行しないでください。
az group delete --subscription "$AZURE_SUBSCRIPTION_ID" \
  --name "$AZURE_RESOURCE_GROUP" --yes --no-wait
for ((attempt=1; attempt<=TEARDOWN_MAX_POLLS; attempt++)); do
  EXISTS="$(rg_exists)"
  if [[ "$EXISTS" == false ]]; then
    printf '%s\n' 'RG 消失を確認しました。課金停止・完全削除の確認は docs/sections/09_teardown_cost.md を続けてください。'
    exit 0
  fi
  printf '削除待機中: %s/%s\n' "$attempt" "$TEARDOWN_MAX_POLLS"
  if (( attempt < TEARDOWN_MAX_POLLS )); then sleep 30; fi
done
printf '%s\n' '待機上限です。削除成功とは判定しません。ポータルと --status で再確認してください。' >&2
# Foundry account は soft-delete 後に purge が必要な場合があります（要確認）。
# 不可逆の purge は自動実行しません。docs/sections/09_teardown_cost.md の対象確認手順を参照します。
exit 2
