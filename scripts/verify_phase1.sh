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

for field in AZURE_DEPLOYMENT_NAME FOUNDRY_ACCOUNT_RESOURCE_ID LOG_ANALYTICS_RESOURCE_ID; do
  require_value "$field"
done
# 別スコープの誤照会を防ぎます。共有 LAW を使うなら設計とこのチェックをレビューします。
RG_SCOPE="/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}"
[[ "$FOUNDRY_ACCOUNT_RESOURCE_ID" == "$RG_SCOPE"/providers/Microsoft.CognitiveServices/accounts/* ]] || \
  fail 'Foundry account が対象 RG 配下ではありません。'
[[ "$LOG_ANALYTICS_RESOURCE_ID" == /subscriptions/"$AZURE_SUBSCRIPTION_ID"/* ]] || \
  fail 'Log Analytics が対象サブスクリプション配下ではありません。'
# 自動ログインはしません。未ログイン時は利用者が az login を実行します。
command -v az >/dev/null 2>&1 || fail 'Azure CLI が見つかりません。'
ACTIVE_TENANT="$(az account show --subscription "$AZURE_SUBSCRIPTION_ID" --query tenantId --output tsv)"
[[ "$ACTIVE_TENANT" == "$AZURE_TENANT_ID" ]] || fail '対象テナントが .env と一致しません。'

printf '%s\n' 'C01: deployment とリソースの設定収集（実呼び出し成功は別途確認）'
az deployment group show --subscription "$AZURE_SUBSCRIPTION_ID" \
  --resource-group "$AZURE_RESOURCE_GROUP" --name "$AZURE_DEPLOYMENT_NAME" \
  --query properties.provisioningState --output tsv
az resource list --subscription "$AZURE_SUBSCRIPTION_ID" \
  --resource-group "$AZURE_RESOURCE_GROUP" --query '[].{type:type,location:location}' --output table
printf '%s\n' 'C02: account スコープの権限一覧。project・継承・実効権限と拒否テストは要確認。'
az role assignment list --subscription "$AZURE_SUBSCRIPTION_ID" \
  --scope "$FOUNDRY_ACCOUNT_RESOURCE_ID" --include-inherited \
  --query '[].{role:roleDefinitionName,principalType:principalType}' --output table
printf '%s\n' 'C03: 要確認：API 世代によりプロパティが取得できない場合は未判定です。'
az resource show --subscription "$AZURE_SUBSCRIPTION_ID" \
  --ids "$FOUNDRY_ACCOUNT_RESOURCE_ID" \
  --query '{disableLocalAuth:properties.disableLocalAuth,publicNetworkAccess:properties.publicNetworkAccess}' --output json
printf '%s\n' 'C04: 診断カテゴリと設定。送信先でのログ到着は別途確認。'
az monitor diagnostic-settings categories list --subscription "$AZURE_SUBSCRIPTION_ID" \
  --resource "$FOUNDRY_ACCOUNT_RESOURCE_ID" --query 'value[].name' --output json
az monitor diagnostic-settings list --subscription "$AZURE_SUBSCRIPTION_ID" \
  --resource "$FOUNDRY_ACCOUNT_RESOURCE_ID" --output json
printf '%s\n' 'C05: LAW の保持設定。テーブル別保持・本文到着・閲覧制御は要確認。'
az resource show --subscription "$AZURE_SUBSCRIPTION_ID" \
  --ids "$LOG_ANALYTICS_RESOURCE_ID" --query properties.retentionInDays --output json
printf '%s\n' 'C06: RG の Policy 割当。継承・準拠評価・拒否効果は別途確認。'
az policy assignment list --subscription "$AZURE_SUBSCRIPTION_ID" \
  --scope "$RG_SCOPE" --query '[].{name:name,parameters:parameters,enforcementMode:enforcementMode}' --output json
# 要確認：新ランタイムの capability host API、agent 呼び出し CLI、
# AppGenAIContent の照会・閲覧権限、Defender の plan と安全な試験方法。
# 未確認の引数を作って成功判定することはしません。
printf '%s\n' \
  'Pending C01-C06: 実呼び出し・拒否系・ログ到着・実効権限を checks/README.md で検証してください。' \
  'Pending C07: Defender の状態・課金合意・安全な検知テストを確認してください。' \
  'Pending C10: 予算、削除後の残存、費用反映を確認してください。' \
  'C08/C09 および C06 の Deny 試験は後続フェーズです。' \
  '設定収集のみ終了。統制の合格ではないため終了コード 2 を返します。'
exit 2
