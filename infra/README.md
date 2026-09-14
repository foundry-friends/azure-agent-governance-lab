# 公式テンプレートの利用方法

## 対象と固定方法

[公式 Bicep テンプレート集](https://github.com/microsoft-foundry/foundry-samples/tree/main/infrastructure/infrastructure-setup-bicep) の `41-standard-agent-setup` を Phase 1、`15-private-network-standard-agent-setup` を Phase 2 に使います。`16-private-network-standard-agent-apim-setup` は閉域 APIM 統合の参考です。Phase 3 の公開側 Basic v2 環境に 16 をそのまま展開する手順ではありません。

再現性のため、GitHub のコミット画面から選んだ **40 桁の完全なコミット SHA** を `.env` の `FOUNDRY_SAMPLES_COMMIT` に保存します。現段階では採用コミット未選定です（要確認）。以下は作者・利用者が後で実行する取得例で、このリポジトリ作成時には取得していません。git 操作は不要です。取得例には Bash、curl、unzip が必要です。

```bash
# リポジトリ直下で実行します。信頼できる .env だけを読み込みます。
set -euo pipefail
source .env
[[ "$FOUNDRY_SAMPLES_COMMIT" =~ ^[0-9a-f]{40}$ ]] || exit 1
mkdir -p infra/vendor
curl --fail --location --output infra/vendor/foundry-samples.zip \
  "https://github.com/microsoft-foundry/foundry-samples/archive/${FOUNDRY_SAMPLES_COMMIT}.zip"
unzip infra/vendor/foundry-samples.zip -d infra/vendor
# 展開先: infra/vendor/foundry-samples-<full-40-character-commit-sha>/
```

取得済みの場合は再展開せず内容を照合します。LICENSE と依存 module も保持します。固定 SHA は追跡対象の手順書にも記録し、検証した日付・CLI/Bicep バージョンを付記してください。ダウンロード先は公開対象外です。アーカイブのハッシュを控え、取得物の改変も管理します。

## パラメータを確定する

`params/phase1.example.json` は **デプロイ可能な完成例ではありません**。JSON 標準にはコメントがないため、コメント相当を `metadata._comment` / `metadata.parameterNotes` に置いています。`location` を含めパラメータ名は未確認、`cosmosDbCapacityMode` と `aiSearchSku` は仮名です。

1. `41-standard-agent-setup/main.bicep` とその依存 module、README を読みます。ファイルの存在・配置も要確認です。
2. 各 `param` の型、default、allowed、必須性と deployment scope を一覧にします。RG scope かどうかは要確認です。異なる場合はスクリプトを修正してから使います。
3. Japan East / Cosmos DB Serverless / AI Search Basic を実現する実パラメータへ置き換えます。非対応なら黙って既定 SKU を使わず、公式が案内する BYO リソース方式を調べます（要確認）。
4. Foundry project、新ランタイム対応、モデル名・バージョン・クォータ・容量、capability host、Entra ID / managed identity 接続、ローカル認証無効化を照合します。テンプレートがキー・接続文字列を要求する方式なら、そのまま使わず Entra ID 方式を確定します（要確認）。Key Vault にキーを保存する方式で代用しません。
5. Application Insights / Log Analytics の有無、出力名、30 日保持の設定方法を照合します。接続文字列を出力やローカル設定へコピーしません。ログの Entra ID 経路の設定は要確認です。
6. コピーした `phase1.local.json` で全「要確認」を解消し、全 placeholder と仮名を除き、`metadata` を削除します。必要な非秘密パラメータだけを実名で記載します。
7. 内容をレビューして `.env` の `PHASE1_PARAMETERS_REVIEWED=true` を設定します。

## 展開スクリプトの範囲と再実行

`deploy_phase1.sh` はローカルファイルを検査してから、既存ログインとテナントを確認し、対象サブスクリプションを全コマンドで明示し、RG 作成、validate、what-if、Incremental 展開を行います。変更対象の事前レビューは手順側で行ってください。ログインしていなければ自動ログインせず停止します。

同じ RG・deployment 名・固定 SHA・パラメータで再実行する設計です。時刻や乱数を名前に追加しません。ただし capability host の変更はできず、公式テンプレート側の冪等性は未検証です。構成の変更が必要な場合は更新できると仮定せず、別 RG / 新アカウントを検討します。既存の共有 RG は対象にしません。

出力名が未確認のため、スクリプトは deployment の状態と **出力項目名だけ**を表示します。resource ID 等の必要な値はポータルで照合し `.env` に保存します。すべての出力をログへ書き出すことはしません。

## 本実行前の停止条件

コミット未固定、パラメータ未確認、Entra ID 方式未確認、対象 RG が共有、SKU・モデルの利用不可、費用の未合意の場合は展開しません。提供状況とコマンドの可用性を確認した結果を手順へ反映してから実行します。

基本コマンドの引数は [Azure CLI deployment group](https://learn.microsoft.com/en-us/cli/azure/deployment/group?view=azure-cli-latest) と [Azure CLI group](https://learn.microsoft.com/en-us/cli/azure/group?view=azure-cli-latest) を参照します。ここでの参照はコマンド形式の確認に限定し、サービスの追加機能や料金の根拠には使いません。
