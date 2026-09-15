# S6：監視と監査

このセクションを使う Run: Run 1 / Run 2 / Run 3｜先に要るセクション: S1・S5

## 1. 目的

統制層⑦ 監査・トレース。診断ログ、本文トレース、Activity Log を分けて確認します。

## 2. 前提

S1 の Log Analytics と S5 が前提です。LAW / App Insights の読み取りと本文用の権限は分けて確認します。

先に要るセクション：S1・S5。詳細な会社ルールは [Run 0](../runs/run0_desk.md) で確認します。

## 3. 構築

### Application Insights を接続する

Foundry ポータルで対象 account / project と Application Insights の接続・トレース設定を確認します。既にテンプレートが接続している場合は重複作成しません。未接続なら公式の [Standard setup](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/standard-agent-setup) と [機微なトレース内容の扱い](https://learn.microsoft.com/en-us/azure/foundry/observability/how-to/traces-sensitive-content) に従います。

**確認ポイント**：接続画面、Entra ID だけでテレメトリ送信する設定、必要ロール、使用する SDK/API、本文収集を有効にする手順は要確認です。接続文字列を貼り付ける手順は採用しません。実現方法を確認できるまでは本ステップを未完了にします。合成入力でトレースを発生させ、本文は `AppGenAIContent`、実行情報はトレースで確認します。30 日保持と閲覧制限を確認します。

**よくある失敗**：診断ログだけでプロンプト本文が残ると思う、本文収集の設定や閲覧権限を確認せず収集成功とする。

### 診断設定を Log Analytics に送る

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

### 固定版で見つかった接続方式の不一致

41 の `deployApplicationInsights=true` は LAW（30 日保持）と App Insights を作成しますが、接続は `authType: ApiKey` と `ConnectionString` です。**Entra ID のみという本手順の条件を満たしません。** 例では `false` にして公式の当該経路を使わず、S6 の別接続方式を要確認に残します。App Insights を使わないことを完成目標にはしません。

`06_diagnostics.bicep` は未検証の骨子です。Foundry / Cosmos / Search / Key Vault / Firewall / APIM の対象ごとにカテゴリを列挙し LAW に送信します。S1 と LAW を二重計上・二重作成しません。Activity Log、Purview Audit トグル、protected table の権限を確認します。Purview の有償機能は対象外です。

当日の時間配分と実行順は該当 [Run 文書](00_overview.md#4-セクションと-run-の地図) に従います。骨組み・Azure 未実行です。

## 4. 確認

C04 はログ到着、C05 は AppGenAIContent の本文到着・閲覧許可／拒否・30 日保持を確認します。公式が project MI に Log Analytics Reader と Privileged Monitoring Data Reader を付与する意図と実効権限も照合します。接続方式未確定は Pending です。

対象：C04・C05。[checks](../../checks/README.md) に合成入力・期待結果・実結果・日付・Pass / Fail / Pending を記録します。未実施は Pending。公開しない証跡は `evidence/` に保存します。

```bash
bash scripts/verify.sh --section 6
```

コマンドはリポジトリ直下から実行します。設定収集だけでは合格になりません。

## 5. よくあるエラー

（Run 1 初回で記入）

S3 は Run 2、S7 と S8 の追加検証は Run 3 の初回に追記します。構築欄に引き継いだ「よくある失敗」は旧ドラフトの想定であり、この環境で経験した実測ではありません。

## 6. 削除

専用 Run 環境の終了時は [S9](09_teardown_cost.md) で RG 単位に削除します。このセクションだけの部分削除は依存・共有・capability host の再作成可否を確認後に行います（要確認）。未確定の個別削除 API は置きません。RG 外、soft-delete、Defender のサブスク設定は別確認です。

## 7. 費用

| Excel 明細 No | 項目 | 都度構築の月額 USD | 常時730hの月額 USD |
|---|---|---:|---:|
| 6 | Log Analytics 取り込み | 10.020000 | 10.020000 |
| 7 | Application Insights | 0.000000 | 0.000000 |
| 25 | 30 日保持・追加保持なし | 0.000000 | 0.000000 |

2026-09-15 見積り report v2 の条件。都度は原則32h/月、WAFのみ8h/月、DNSは6 zone・4課金日です。常時列は同じ単価の固定費を730hへ換算し、従量は同じ使用量の仮定です。No.9 と17は切替で二重計上しません。No.6は S1/S6 の共通費で一度だけ計上。No.24は通常月 $8、初月無料を1か月と近似。No.26は承認してONなら月 $51.10。実請求保証ではありません。

## 8. 本番との差

このセクションには指定された Baseline SKU の直接の差分はありません。 [付録 B](appendix_b_production_diff.md) を参照します。
