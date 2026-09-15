#!/usr/bin/env bash
# 未実行の手順ドラフト。Azure に対する実機検証は行っていません。
set -euo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
fail() { printf '%s\n' "$*" >&2; exit 1; }
[[ $# -eq 2 && "$1" == --section && "$2" =~ ^[1-9]$ ]] || fail '使い方: bash scripts/verify.sh --section 1..9'
SECTION="$2"
case "$SECTION" in
  1|9) printf '%s\n' 'Pending C10: 予算通知・削除後残存・費用反映は checks/README.md で確認。'; exit 2 ;;
  3) printf '%s\n' 'Pending C08: 閉域/公開の同一権限呼出し・DNS・出口・例外は要確認。'; exit 2 ;;
  7) printf '%s\n' 'Pending C09: quota 403・経由ログ・ガードレール・fail openの適用範囲は要確認。'; exit 2 ;;
esac
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

case "$SECTION" in
  4|5) require_value AZURE_DEPLOYMENT_NAME ;;
  2) require_value FOUNDRY_ACCOUNT_RESOURCE_ID ;;
  6) require_value FOUNDRY_ACCOUNT_RESOURCE_ID; require_value LOG_ANALYTICS_RESOURCE_ID ;;
esac
# 別スコープの誤照会を防ぎます。共有 LAW を使うなら設計とこのチェックをレビューします。
RG_SCOPE="/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}"
if [[ "$SECTION" == 2 || "$SECTION" == 6 ]]; then
[[ "$FOUNDRY_ACCOUNT_RESOURCE_ID" == "$RG_SCOPE"/providers/Microsoft.CognitiveServices/accounts/* ]] || \
  fail 'Foundry account が対象 RG 配下ではありません。'
fi
if [[ "$SECTION" == 6 ]]; then
[[ "$LOG_ANALYTICS_RESOURCE_ID" == /subscriptions/"$AZURE_SUBSCRIPTION_ID"/* ]] || \
  fail 'Log Analytics が対象サブスクリプション配下ではありません。'
fi
# 自動ログインはしません。未ログイン時は利用者が az login を実行します。
command -v az >/dev/null 2>&1 || fail 'Azure CLI が見つかりません。'
ACTIVE_TENANT="$(az account show --subscription "$AZURE_SUBSCRIPTION_ID" --query tenantId --output tsv)"
[[ "$ACTIVE_TENANT" == "$AZURE_TENANT_ID" ]] || fail '対象テナントが .env と一致しません。'

if [[ "$SECTION" == 4 || "$SECTION" == 5 ]]; then
printf '%s\n' 'C01: deployment とリソースの設定収集（実呼び出し成功は別途確認）'
az deployment group show --subscription "$AZURE_SUBSCRIPTION_ID" \
  --resource-group "$AZURE_RESOURCE_GROUP" --name "$AZURE_DEPLOYMENT_NAME" \
  --query properties.provisioningState --output tsv
az resource list --subscription "$AZURE_SUBSCRIPTION_ID" \
  --resource-group "$AZURE_RESOURCE_GROUP" --query '[].{type:type,location:location}' --output table
fi
if [[ "$SECTION" == 2 ]]; then
printf '%s\n' 'C02: account スコープの権限一覧。project・継承・実効権限と拒否テストは要確認。'
az role assignment list --subscription "$AZURE_SUBSCRIPTION_ID" \
  --scope "$FOUNDRY_ACCOUNT_RESOURCE_ID" --include-inherited \
  --query '[].{role:roleDefinitionName,principalType:principalType}' --output table
fi
if [[ "$SECTION" == 2 ]]; then
printf '%s\n' 'C03: 要確認：API 世代によりプロパティが取得できない場合は未判定です。'
az resource show --subscription "$AZURE_SUBSCRIPTION_ID" \
  --ids "$FOUNDRY_ACCOUNT_RESOURCE_ID" \
  --query '{disableLocalAuth:properties.disableLocalAuth,publicNetworkAccess:properties.publicNetworkAccess}' --output json
fi
if [[ "$SECTION" == 6 ]]; then
printf '%s\n' 'C04: 診断カテゴリと設定。送信先でのログ到着は別途確認。'
az monitor diagnostic-settings categories list --subscription "$AZURE_SUBSCRIPTION_ID" \
  --resource "$FOUNDRY_ACCOUNT_RESOURCE_ID" --query 'value[].name' --output json
az monitor diagnostic-settings list --subscription "$AZURE_SUBSCRIPTION_ID" \
  --resource "$FOUNDRY_ACCOUNT_RESOURCE_ID" --output json
fi
if [[ "$SECTION" == 6 ]]; then
printf '%s\n' 'C05: LAW の保持設定。テーブル別保持・本文到着・閲覧制御は要確認。'
az resource show --subscription "$AZURE_SUBSCRIPTION_ID" \
  --ids "$LOG_ANALYTICS_RESOURCE_ID" --query properties.retentionInDays --output json
fi
if [[ "$SECTION" == 8 ]]; then
printf '%s\n' 'C06: RG の Policy 割当。継承・準拠評価・拒否効果は別途確認。'
az policy assignment list --subscription "$AZURE_SUBSCRIPTION_ID" \
  --scope "$RG_SCOPE" --query '[].{name:name,parameters:parameters,enforcementMode:enforcementMode}' --output json
fi
# 要確認：新ランタイムのcapability host API、agent呼び出しCLI、
# AppGenAIContentの照会・閲覧権限、Defenderのplanと安全な試験方法。
# 未確認の引数を作って成功判定することはしません。
case "$SECTION" in
  2) echo 'Pending C02/C03: 実効権限・拒否系・Entra ID呼出しを確認。' ;;
  4) echo 'Pending C01: 自前データ接続・capability host・実呼出しを確認。' ;;
  5) echo 'Pending C01/C09: 実呼出しとガードレールを確認。hosted固有試験は付録A。' ;;
  6) echo 'Pending C04/C05: ログと本文到着・閲覧拒否・保持を確認。' ;;
  8) echo 'Pending C06/C07: 監査/DenyはRunを分け、Defender状態・課金合意・安全な検知試験を確認。' ;;
esac
echo '設定収集のみ終了。統制の合格ではないため終了コード2を返します。'
exit 2
