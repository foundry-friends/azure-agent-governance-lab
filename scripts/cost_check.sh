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

# このスクリプトは案内の表示だけです。az / azd を実行しません。
printf '%s\n' \
  'https://portal.azure.com/ を開き、Cost Management + Billing を選びます。' \
  '対象サブスクリプションと RG を照合し、Cost analysis で日別・サービス別に確認します。' \
  'Budgets で月予算と通知先を設定します。50% / 80% / 100% は検証用の候補です。' \
  '予算通知は停止機能ではありません。削除後も反映遅延と RG 外の費用を確認します。' \
  'Defender はサブスクリプション単位の費用も確認します。' \
  '下記は未実行の CLI 例です。要確認のまま実行しないでください。'
cat <<'EXAMPLE'
# リポジトリ直下で信頼できる .env を読み込みます。
source .env
# 対象のログインを確認する基本例。
az account show --subscription "$AZURE_SUBSCRIPTION_ID" \
  --query '{subscription:id,tenant:tenantId}' --output table
# 要確認：Cost Management Query API の version、権限、type、aggregation、
# filter（ResourceGroup 等）を公式の現行仕様と照合します。
# 完成した要求本文を infra/params/cost-query.local.json として用意します。
# この骨組みには要求本文は同梱していません。
az rest --method post \
  --url "https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/providers/Microsoft.CostManagement/query?api-version=<cost-query-api-version>" \
  --body @infra/params/cost-query.local.json
# 返り値だけで費用がゼロ・請求確定とは判断しません。
EXAMPLE
