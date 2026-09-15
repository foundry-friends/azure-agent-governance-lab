#!/usr/bin/env bash
# 未実行の手順ドラフト。Azure に対する実機検証は行っていません。
set -euo pipefail
echo "要確認：Run 2 は公式15を呼ぶ分岐が未実装です。41へフォールバックせず停止します。"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
fail() { printf '%s\n' "$*" >&2; exit 1; }
[[ $# -eq 2 && "$1" == --run && "$2" =~ ^[123]$ ]] || fail '使い方: bash scripts/deploy.sh --run 1|2|3'
RUN="$2"
case "$RUN" in
  1) EXTRA_PARAMETERS=(enablePrivateNetwork=false enableApim=false enableWaf=false) ;;
  2) fail '要確認：Run 2の15分岐・ネットワーク・認証・費用の実装を確定してください。' ;;
  3) EXTRA_PARAMETERS=(enablePrivateNetwork=false enableApim=true) ;;
esac
[[ -f .env ]] || fail '.env がありません。.env.example をコピーしてください。'
# .env は shell コードです。信頼できるローカルファイルだけを読み込みます。
source .env
PARAMETERS_FILE="infra/params/run${RUN}.local.json"
REVIEW_FIELD="RUN${RUN}_PARAMETERS_REVIEWED"
PARAMETERS_REVIEWED="${!REVIEW_FIELD:-false}"
require_value() {
  local field="$1" value
  value="${!field:-}"
  [[ -n "$value" && "$value" != *'<'* && "$value" != *'>'* ]] || \
    fail "$field のプレースホルダーを設定してください。"
}
for field in AZURE_SUBSCRIPTION_ID AZURE_TENANT_ID AZURE_RESOURCE_GROUP; do
  require_value "$field"
done

for field in AZURE_LOCATION AZURE_DEPLOYMENT_NAME FOUNDRY_SAMPLES_COMMIT PARAMETERS_FILE; do
  require_value "$field"
done
[[ "$AZURE_LOCATION" == japaneast ]] || fail 'このドラフトのリージョンは japaneast です。'
[[ "$FOUNDRY_SAMPLES_COMMIT" =~ ^[0-9a-f]{40}$ ]] || fail '40 桁の固定コミット SHA が必要です。'
[[ "${PARAMETERS_REVIEWED:-false}" == true ]] || fail '要確認：main.bicep とパラメータ・認証方式をレビューしてください。'
[[ "$PARAMETERS_FILE" == infra/params/*.local.json ]] || fail 'infra/params/ 配下の *.local.json を指定してください。'
[[ -f "$PARAMETERS_FILE" ]] || fail 'ローカルパラメータファイルがありません。'
TEMPLATE_FILE="infra/main.bicep"
[[ "$FOUNDRY_SAMPLES_COMMIT" == '58e4127567f7e9afcf0145d874df890284ca5faf' ]] || fail 'PINNED_COMMITとラッパの固定SHAが一致しません。'
[[ -f "infra/vendor/foundry-samples-${FOUNDRY_SAMPLES_COMMIT}/infrastructure/infrastructure-setup-bicep/41-standard-agent-setup/main.bicep" ]] || fail '固定版41を取得してください。'
[[ -f "$TEMPLATE_FILE" ]] || fail '要確認：固定コミットの main.bicep を infra/README.md に従って用意してください。'
command -v python3 >/dev/null 2>&1 || fail 'JSON のローカル検査に Python 3 が必要です。'
python3 - "$PARAMETERS_FILE" <<'PYJSON'
import json, sys
from pathlib import Path
p = Path(sys.argv[1])
raw = p.read_text(encoding='utf-8')
data = json.loads(raw)
if 'metadata' in data or '要確認' in raw or '<' in raw or '>' in raw:
    sys.exit('要確認の注記・metadata・プレースホルダーを解消してください。')
if not isinstance(data.get('parameters'), dict) or not data['parameters']:
    sys.exit('parameters がありません。')
# 正しいパラメータ名・SKU・認証方式の判定は main.bicep のレビューと validate に委ねます。
PYJSON
# 固定停止点：未完成の骨組みをレビュー済みフラグだけで展開しません。
# BYO事前作成、ローカル認証、Key Vault、S6のEntra ID接続、自前moduleを
# 実装・レビューし、bicep buildで確認した後にこの停止点を除去します。
fail '要確認：骨組みは未コンパイル・未完成です。infra/params/41_parameters.mdの差分を解消してください。'
# 以下は完成後の実行経路の骨子です。この版ではAzureコマンドへ到達しません。
# 自動ログインはしません。未ログイン時は利用者が az login を実行します。
command -v az >/dev/null 2>&1 || fail 'Azure CLI が見つかりません。'
ACTIVE_TENANT="$(az account show --subscription "$AZURE_SUBSCRIPTION_ID" --query tenantId --output tsv)"
[[ "$ACTIVE_TENANT" == "$AZURE_TENANT_ID" ]] || fail '対象テナントが .env と一致しません。'

az bicep version
# 同じ名前と入力を使います。共有 RG では実行しないでください。
az group create --subscription "$AZURE_SUBSCRIPTION_ID" \
  --name "$AZURE_RESOURCE_GROUP" --location "$AZURE_LOCATION" --output none
# 要確認：main.bicep が RG scope であること、CLI / Bicep と対応すること。
# テンプレート内にキー・接続文字列のパラメータや出力がないことを先に確認します。
az deployment group validate --subscription "$AZURE_SUBSCRIPTION_ID" \
  --resource-group "$AZURE_RESOURCE_GROUP" --name "$AZURE_DEPLOYMENT_NAME" \
  --template-file "$TEMPLATE_FILE" --parameters "@$PARAMETERS_FILE" "${EXTRA_PARAMETERS[@]}" --output none
az deployment group what-if --subscription "$AZURE_SUBSCRIPTION_ID" \
  --resource-group "$AZURE_RESOURCE_GROUP" --name "$AZURE_DEPLOYMENT_NAME" \
  --template-file "$TEMPLATE_FILE" --parameters "@$PARAMETERS_FILE" "${EXTRA_PARAMETERS[@]}"
# what-if を確認してから変更します。無人実行や入力省略では展開しません。
printf '上記の変更内容と専用 RG を確認したら deploy と入力してください: '
read -r CONFIRM_DEPLOY
[[ "$CONFIRM_DEPLOY" == deploy ]] || fail '展開を中止しました。作成済み RG の残存は確認してください。'
az deployment group create --subscription "$AZURE_SUBSCRIPTION_ID" \
  --resource-group "$AZURE_RESOURCE_GROUP" --name "$AZURE_DEPLOYMENT_NAME" \
  --mode Incremental --template-file "$TEMPLATE_FILE" \
  --parameters "@$PARAMETERS_FILE" "${EXTRA_PARAMETERS[@]}" --output none
# 要確認：公式41のトップレベルoutputsは0件。ラッパの項目名だけ表示し、値の一括出力はしません。
az deployment group show --subscription "$AZURE_SUBSCRIPTION_ID" \
  --resource-group "$AZURE_RESOURCE_GROUP" --name "$AZURE_DEPLOYMENT_NAME" \
  --query '{state:properties.provisioningState,outputNames:keys(properties.outputs)}' --output json
printf '%s\n' '展開処理が終了しました。docs/sections/05・06・08 と checks の実呼び出し検証へ進んでください。'
