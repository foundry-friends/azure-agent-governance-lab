# 公式テンプレートの利用方法

## 対象と固定方法

[公式 Bicep テンプレート集](https://github.com/microsoft-foundry/foundry-samples/tree/main/infrastructure/infrastructure-setup-bicep) の `41-standard-agent-setup` を Run 1、`15-private-network-standard-agent-setup` を Run 2 に使います。`16-private-network-standard-agent-apim-setup` は閉域 APIM 統合の参考です。Run 3 の公開側 Basic v2 環境に 16 をそのまま展開する手順ではありません。

再現性のため、GitHub のコミット画面から選んだ **40 桁の完全なコミット SHA** を `.env` の `FOUNDRY_SAMPLES_COMMIT` に保存します。Run 0で採用コミットを固定しました。元のコミット未選定の要確認は机上解消し、[PINNED_COMMIT](PINNED_COMMIT.md)にSHAとUTC取得日時を記録しています。以下は同じ版を再取得する例です。git 操作は不要です。取得例には Bash、curl、unzip が必要です。

```bash
# リポジトリ直下で実行します。信頼できる .env だけを読み込みます。
set -euo pipefail
source .env
# 採用版を固定します。
FOUNDRY_SAMPLES_COMMIT='58e4127567f7e9afcf0145d874df890284ca5faf'
[[ "$FOUNDRY_SAMPLES_COMMIT" =~ ^[0-9a-f]{40}$ ]] || exit 1
mkdir -p infra/vendor
curl --fail --location --output infra/vendor/foundry-samples.zip \
  "https://github.com/microsoft-foundry/foundry-samples/archive/${FOUNDRY_SAMPLES_COMMIT}.zip"
unzip infra/vendor/foundry-samples.zip -d infra/vendor
# 展開先: infra/vendor/foundry-samples-<full-40-character-commit-sha>/
```

取得済みの場合は再展開せず内容を照合します。LICENSE と依存 module も保持します。固定 SHA は追跡対象の PINNED_COMMIT に記録済みです。実機検証した日付・CLI/Bicep バージョンは実行時に付記してください。ダウンロード先は公開対象外です。アーカイブのハッシュを控え、取得物の改変も管理します。

## パラメータを確定する

`params/run1.example.json`（Run 2は15向け、Run 3は自前ラッパ向け） は **デプロイ可能な完成例ではありません**。JSON 標準にはコメントがないため、コメント相当を `metadata._comment` に置いています（旧例の `metadata.parameterNotes` の論点は41_parameters.mdへ移行）。`location` は実在を確認しました。旧 `cosmosDbCapacityMode` / `aiSearchSku` は仮名だったため削除し、実在のBYO ID paramに置き換えました。

1. `41-standard-agent-setup/main.bicep` とその依存 module、README を読みます。ファイルの存在・配置の要確認は今回解消しました。
2. 各 `param` の型、default、allowed、必須性と deployment scope を一覧にします。RG scope の要確認は今回ソースで解消しました。異なる場合はスクリプトを修正してから使います。
3. Japan East / Cosmos DB Serverless / AI Search Basic を実現する実パラメータへ置き換えます。非対応なら黙って既定 SKU を使わず、公式が案内する BYO リソース方式を調べます（要確認）。
4. Foundry project、新ランタイム対応、モデル名・バージョン・クォータ・容量、capability host、Entra ID / managed identity 接続、ローカル認証無効化を照合します。テンプレートがキー・接続文字列を要求する方式なら、そのまま使わず Entra ID 方式を確定します（要確認）。Key Vault にキーを保存する方式で代用しません。
5. Application Insights / Log Analytics の有無、出力名、30 日保持の設定方法を照合します。接続文字列を出力やローカル設定へコピーしません。ログの Entra ID 経路の設定は要確認です。
6. コピーした `run1.local.json` で全「要確認」を解消し、全 placeholder と仮名を除き、`metadata` を削除します。必要な非秘密パラメータだけを実名で記載します。
7. 内容をレビューして 該当Runの `.env` 設定（`RUN1_PARAMETERS_REVIEWED=true` 等）を更新します。

## 展開スクリプトの範囲と再実行

完成後の `deploy.sh --run 1` はローカルファイルを検査してから、既存ログインとテナントを確認し、対象サブスクリプションを全コマンドで明示し、RG 作成、validate、what-if、Incremental 展開を行います。変更対象の事前レビューは手順側で行ってください。ログインしていなければ自動ログインせず停止します。

同じ RG・deployment 名・固定 SHA・パラメータ（特にdeploymentTimestamp）で再実行する設計です。ラッパは実行のたびに時刻や乱数を追加しません。公式41は固定したdeploymentTimestampとRG IDからsuffixを作ります。ただし capability host の変更はできず、公式テンプレート側の冪等性は未検証です。構成の変更が必要な場合は更新できると仮定せず、別 RG / 新アカウントを検討します。既存の共有 RG は対象にしません。

トップレベルoutputsは0件です。将来出力を追加しても、スクリプトは deployment の状態と **出力項目名だけ**を表示します。resource ID 等の必要な値はポータルで照合し `.env` に保存します。すべての出力をログへ書き出すことはしません。

## 本実行前の停止条件

コミット未固定、パラメータ未確認、Entra ID 方式未確認、対象 RG が共有、SKU・モデルの利用不可、費用の未合意の場合は展開しません。提供状況とコマンドの可用性を確認した結果を手順へ反映してから実行します。

基本コマンドの引数は [Azure CLI deployment group](https://learn.microsoft.com/en-us/cli/azure/deployment/group?view=azure-cli-latest) と [Azure CLI group](https://learn.microsoft.com/en-us/cli/azure/group?view=azure-cli-latest) を参照します。ここでの参照はコマンド形式の確認に限定し、サービスの追加機能や料金の根拠には使いません。


## Run 0 の結果と現在の停止点

全param・allowed・scope・outputs・SKU・認証の差は [41_parameters.md](params/41_parameters.md)。41はそのままではサーバーレス / Search Basic / LRS / ローカル認証無効 / Entra IDによるApp Insights / Key Vaultの目標を満たしません。`deploy.sh --run 1|2|3`は骨組みの固定停止点を持ち、未実装のままAzureへ送信しません。Run 1までに未解決を実装・レビューし停止点を外す作業が必要です。PARAMETERS_REVIEWEDだけでこの停止を解除できません。

**bicep build はこの環境で未実行**。azもbicepもありません。main.bicepと自前moduleは未コンパイル・未検証です。enablePrivateNetwork=trueは41を呼ばず、15への分岐実装はRun 2で確定（要確認）。15の例JSONを41へ誤送信しません。

監視とPolicyの自前moduleはenableDiagnostics / enablePolicyDefenderがfalseの骨子です。これらの切替は配置の意図を示すだけで、現在の空propertiesを埋めないまま有効化しません。予算承認とDefenderの会社承認はRun 0チェックリストで利用者が確認します。
