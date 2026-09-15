#!/usr/bin/env bash
# 未実行の手順ドラフト。Azure に対する実機検証は行っていません。
set -euo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
fail() { printf '%s\n' "$*" >&2; exit 1; }
[[ $# -eq 2 && "$1" == --run && "$2" =~ ^[12]$ ]] || fail '使い方: bash scripts/deploy.sh --run 1|2'
RUN="$2"
case "$RUN" in
  1) EXTRA_PARAMETERS=(enableApim=false) ;;
  2) EXTRA_PARAMETERS=(enableApim=true) ;;
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

for field in AZURE_LOCATION AZURE_DEPLOYMENT_NAME FOUNDRY_SAMPLES_COMMIT PARAMETERS_FILE ALLOWED_IP_RANGES; do
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
python3 - "$PARAMETERS_FILE" "$ALLOWED_IP_RANGES" "$RUN" <<'PYJSON'
import json, sys, ipaddress, re
from pathlib import Path
p = Path(sys.argv[1])
raw = p.read_text(encoding='utf-8')
data = json.loads(raw)
if 'metadata' in data or '要確認' in raw or '<' in raw or '>' in raw:
    sys.exit('要確認の注記・metadata・プレースホルダーを解消してください。')
if not isinstance(data.get('parameters'), dict) or not data['parameters']:
    sys.exit('parameters がありません。')
params = {k: v['value'] for k, v in data['parameters'].items()}
allowed = set(re.findall(r'^param (\w+) ', Path('infra/main.bicep').read_text(), re.M))
if set(params) - allowed:
    sys.exit('main.bicep にないパラメータがあります。')
try:
    ips = json.loads(sys.argv[2])
    if not isinstance(ips, list) or not ips or not all(isinstance(ip, str) for ip in ips):
        raise ValueError()
    nets = [ipaddress.ip_network(ip, strict=True) for ip in ips]
    if any(n.version != 4 or n.prefixlen == 0 or not n.network_address.is_global or not n.broadcast_address.is_global for n in nets):
        raise ValueError()
    if sum(n.num_addresses for n in ipaddress.collapse_addresses(nets)) >= 2**32:
        raise ValueError()
except (ValueError, TypeError):
    sys.exit('ALLOWED_IP_RANGES は非空の社内公開 IPv4 CIDR 配列にします。全許可は禁止です。')
if params.get('allowedIpRanges') != ips:
    sys.exit('.env とローカル JSON の IP 許可リストが一致しません。')
if params.get('enableApim') is not (sys.argv[3] == '2'):
    sys.exit('Run と enableApim が一致しません。')
if params.get('deployApplicationInsights', False) is not False:
    sys.exit('41 の App Insights 接続は使用しません。')
if sys.argv[3] == '2':
    expected = [{'from': str(n.network_address), 'to': str(n.broadcast_address)} for n in nets]
    if params.get('allowedIpAddressRanges') != expected:
        sys.exit('APIM の開始・終了アドレスが CIDR と一致しません。')
# CIDR の所有・承認、認証経路、SKU はレビューと実機確認で判定します。
PYJSON
# 固定停止点：未完成の骨組みをレビュー済みフラグだけで展開しません。
# BYO の到達・41 の GA 適合性・S5 後追い・S6 Entra ID 接続・S7 経路・S8 定義を
# 実装レビューし、bicep build で確認した後にこの停止点を除去します。
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
printf '%s\n' '展開処理が終了しました。docs/12-foundry-agent.md・13-monitoring.md・15-policy-defender-eval.md と checks の実呼び出し検証へ進んでください。'
