# Phase 1：最小構成（公開側・手順ドラフト）

目的は Standard setup 上に prompt agent を 1 つ作り、ID・監査・Policy の統制を確認することです。Azure で未実行です。以下のコマンドは利用者が後で実行する例です。引数・API 世代・画面の未確定部分は「要確認」としています。

## 1. 前提を確認する

専用 RG を作成でき、対象 RG に Owner、またはリソース作成権限と User Access Administrator が必要です。Azure CLI 2.50 以上、Bicep、モデルの提供リージョンとクォータを確認します。Foundry project を使い、hub-based project は使いません。[Standard setup](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/standard-agent-setup)

```bash
az --version
az bicep version
# ログインしていない場合に利用者が実行します。
az login --tenant '<tenant-id>'
```

**確認ポイント**：Japan East で希望モデル・容量を使えること、対象サブスクリプションの費用負担、RG 作成権限と RBAC 割当権限を確認します。CLI 最低版の条件だけで最新 API の対応を保証しません。

**よくある失敗**：Contributor だけでロール割当を行う、モデルのクォータを確認しない、違うテナントにログインする。

## 2. `.env` を準備する

```bash
cp .env.example .env
cp infra/params/phase1.example.json infra/params/phase1.local.json
# エディターで .env とローカル JSON を編集します。
# .env は shell として実行されるため、信頼できる内容だけを書きます。
source .env
az account show --subscription "$AZURE_SUBSCRIPTION_ID" \
  --query '{subscription:id,tenant:tenantId}' --output table
```

**確認ポイント**：各 placeholder を置き換え、API キー・接続文字列を追加しません。実 ID のある `.env` と `*.local.json` は公開しません。

**よくある失敗**：引用符なしの `<...>` を shell がリダイレクトと解釈する、例の仮パラメータをそのまま使う。

## 3. RG を作成する

```bash
az group create --subscription "$AZURE_SUBSCRIPTION_ID" \
  --name "$AZURE_RESOURCE_GROUP" --location "$AZURE_LOCATION"
```

**確認ポイント**：この検証だけの RG であることを確認します。展開スクリプトも同じ RG を作成・再利用するため、手動作成後に実行しても同一名を使います。後の RG 削除は中の全リソースが対象です。

**よくある失敗**：別チームの既存 RG を再利用する、サブスクリプション指定を省く。

## 4. `41-standard-agent-setup` を展開する

[infra の手順](../infra/README.md) で固定 SHA のテンプレートを取得します。`main.bicep` と依存 module を読んで例のパラメータを確定します。希望は Japan East、Cosmos DB Serverless、AI Search Basic です。

```bash
# パラメータ・認証・出力のレビューが終わってから実行します。
bash scripts/deploy_phase1.sh
```

**確認ポイント**：Foundry account / project、Cosmos DB、Storage、AI Search、Key Vault が揃い、接続が Entra ID / managed identity で成立することを確認します。account / project の capability host が成功していることをポータルで確認します。出力名と必要な RBAC の詳細は固定テンプレートで要確認です。

**よくある失敗**：Serverless の指定がなく Provisioned の既定値になる、managed identity にデータアクセス権限がない、capability host を更新しようとする。capability host は作成後変更不可です。

## 5. Application Insights を接続する

Foundry ポータルで対象 account / project と Application Insights の接続・トレース設定を確認します。既にテンプレートが接続している場合は重複作成しません。未接続なら公式の [Standard setup](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/standard-agent-setup) と [機微なトレース内容の扱い](https://learn.microsoft.com/en-us/azure/foundry/observability/how-to/traces-sensitive-content) に従います。

**確認ポイント**：接続画面、Entra ID だけでテレメトリ送信する設定、必要ロール、使用する SDK/API、本文収集を有効にする手順は要確認です。接続文字列を貼り付ける手順は採用しません。実現方法を確認できるまでは本ステップを未完了にします。合成入力でトレースを発生させ、本文は `AppGenAIContent`、実行情報はトレースで確認します。30 日保持と閲覧制限を確認します。

**よくある失敗**：診断ログだけでプロンプト本文が残ると思う、本文収集の設定や閲覧権限を確認せず収集成功とする。

## 6. 診断設定を Log Analytics に送る

`.env` に Foundry account と Log Analytics workspace の resource ID を設定して再読み込みします。CLI で実際のカテゴリを先に確認します。

```bash
source .env
az monitor diagnostic-settings categories list \
  --subscription "$AZURE_SUBSCRIPTION_ID" \
  --resource "$FOUNDRY_ACCOUNT_RESOURCE_ID" --output table
# 要確認：対象リソースで列挙されたカテゴリだけを指定します。
# 以下は Audit が存在することを確認後に使う最小例です。
az monitor diagnostic-settings create \
  --subscription "$AZURE_SUBSCRIPTION_ID" \
  --name '<diagnostic-setting-name>' \
  --resource "$FOUNDRY_ACCOUNT_RESOURCE_ID" \
  --workspace "$LOG_ANALYTICS_RESOURCE_ID" \
  --logs '[{"category":"Audit","enabled":true}]'
```

**確認ポイント**：`Audit / RequestResponse / Trace / AzureOpenAIRequestUsage / ManagedNetworkEvent` の対象・提供状況を列挙結果で確認し、必要なものを追加します。これらの診断ログにプロンプト本文は含まれません。送信先でレコードを確認し、Log Analytics と個別テーブルの保持を 30 日に設定できるか要確認です。[本文トレースの仕様](https://learn.microsoft.com/en-us/azure/foundry/observability/how-to/traces-sensitive-content)

**よくある失敗**：別リソースのカテゴリを指定する、保存先だけ指定して収集カテゴリを有効化しない、本文ログと診断ログを混同する。

## 7. Azure Policy を監査モードで割り当てる

まず対象 RG スコープで、ローカル認証無効・public network 制限・承認モデル限定の定義を選びます。定義 JSON の effect、対象 type、parameters を読みます。[モデル制限](https://learn.microsoft.com/en-us/azure/foundry/how-to/model-deployment-policy)、[組み込み定義一覧](https://learn.microsoft.com/en-us/azure/ai-services/policy-reference)

```bash
az policy definition list --subscription "$AZURE_SUBSCRIPTION_ID" \
  --query '[].{displayName:displayName,name:name}' --output table
# 要確認：選んだ定義の effect に Audit があることを確認し、
# 実際のパラメータ schema に合わせたローカル JSON を用意します。
# 以下のファイルはこの骨組みには同梱していません。
az policy assignment create --subscription "$AZURE_SUBSCRIPTION_ID" \
  --name '<policy-assignment-name>' \
  --scope "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}" \
  --policy '<policy-definition-id>' \
  --params @infra/params/policy-audit.local.json
```

**確認ポイント**：`effect=Audit` を許容する定義だけ監査として割り当てます。Audit 非対応なら勝手に Deny を割り当てず、`DoNotEnforce` 等の評価方式・結果を要確認として扱います。Audit と enforcement 無効化は同義ではありません。公開側で行う Phase 1 では public network 制限の非準拠を記録し、Phase 2 で是正します。

ローカル認証は監査だけで無効になりません。Foundry の認証設定または固定テンプレートの対応プロパティで**実際に無効化**します（正確な設定経路・引数は要確認）。API キーは RBAC を迂回するためです。承認モデルの定義は Deny にできますが、本段階は監査です。content filter 系の組み込み定義は Preview / Audit のみです。

**よくある失敗**：Audit 割当を防止統制と呼ぶ、effect の存在を確かめず渡す、サブスクリプション全体に割り当てて他チームへ影響させる。

## 8. Defender を有効化する（可能なら）

[Defender for AI Services の手順](https://learn.microsoft.com/en-us/azure/defender-for-cloud/ai-onboarding) に従い、Defender for Cloud の対象サブスクリプション設定で CSPM と AI Services を確認します。サブスクリプション管理者と費用負担・適用範囲・既存プランの状態を合意してから有効化します。CLI の plan 名、subplan、extension、無料枠の適用条件は要確認のため、自動有効化コマンドは置いていません。

**確認ポイント**：変更前後のプラン状態と戻し方を記録します。有効化できなければ C07 は「未実施」とします。共有サブスクリプションでは他チームも課金対象になり得ます。Agent 365 のエージェント単位機能の検証と混同しません。

**よくある失敗**：RG だけの設定だと思う、無料枠で全費用が無料になると思う、検証終了時に既存プランまで無効化する。

## 9. Foundry ポータルで prompt agent を 1 つ作成する

対象 Foundry project を選び、利用可能なモデルで最小の prompt agent を作ります。合成入力だけを使い、外部ツールは追加せず、まず 1 往復の応答を確認します。新ランタイムの画面・作成項目・モデル選択手順は要確認です。

**確認ポイント**：実行者は Foundry Agent Consumer（呼び出しのみ）、開発者は Foundry User を基本に、管理用途の Foundry Project Manager / Foundry Account Owner / Foundry Owner を分離します。具体的な操作権限とスコープは [RBAC](https://learn.microsoft.com/en-us/azure/foundry/concepts/rbac-foundry) で確認します。テスト用の権限が上位スコープから継承されていないことも確認します。

**よくある失敗**：Owner のまま試して最小権限が機能したと判断する、Consumer に作成・編集を期待する、hub-based project を使う。

## 10. 統制を検証する

```bash
bash scripts/verify_phase1.sh
```

[checks](../checks/README.md) の C01〜C07 と C10 を行います。CLI 骨子は設定情報の収集だけで、実呼び出し・拒否テスト・本文の閲覧制限を自動判定しません。終了コード 2 は未完了を意味します。実証できた項目だけ Pass、失敗は Fail、未実施は Pending と記録します。

**確認ポイント**：成功系と拒否系を分けて記録し、合成入力・期待結果・実結果・実施日を残します。公開する証跡から実 ID と本文を除きます。

**よくある失敗**：デプロイ成功を統制の成功と扱う、CLI の一覧表示だけで Pass にする、Phase 2/3 の項目まで合格扱いする。

## 11. 削除して費用を確認する

```bash
bash scripts/teardown.sh --delete '<resource-group-name>'
bash scripts/teardown.sh --status
bash scripts/cost_check.sh
```

**確認ポイント**：[削除・費用](90_teardown_and_cost.md) に従い、RG 消失、soft-delete / purge、RG 外のリソース、Defender プラン、課金反映を確認します。

**よくある失敗**：`--no-wait` の成功を削除完了とする、RG がないだけで請求が止まったと判断する。

コマンド形式の参照：[診断設定 CLI](https://learn.microsoft.com/en-us/cli/azure/monitor/diagnostic-settings?view=azure-cli-latest)、[Policy 割当 CLI](https://learn.microsoft.com/en-us/cli/azure/policy/assignment?view=azure-cli-latest)。リソース固有のカテゴリ、定義と効果、パラメータは上記の要確認事項として残しています。
