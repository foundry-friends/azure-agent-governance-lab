# S9：削除と費用

このセクションを使う Run: Run 1 / Run 2 / Run 3｜先に要るセクション: 当日に構築した全セクション

## 1. 目的

統制層⑩ コスト・ライフサイクル。削除受付、RG 消失、残存確認、翌日以降の課金確認を分けて記録します。

## 2. 前提

### 構築前に予算を決める

[README の費用表](../../README.md#7-費用の目安) は Japan East・2026-09-14・USD・730h/月の概算です。構築前に見積り、終了時刻、削除担当、翌日以降の費用確認を決めます。初期ドラフトは週 1 回 × 8h で月 $100〜300 を想定していました（履歴）。現行の見積り v2 は月 $77.13／3か月 $223.38／12か月 $917.53 で、条件の違いは「7. 費用」を参照します。

[Azure portal](https://portal.azure.com/) の Cost Management + Billing で対象サブスクリプション / RG のスコープを選び、Cost analysis でサービス別・日別・RG 別に絞ります。Budgets で月予算と通知先を設定します。例として 50% / 80% / 100% と予測超過を通知候補にします。画面名、権限、通知方式、費用反映の遅延は要確認です。通知は自動停止ではありません。

共有サブスクリプションの Defender CSPM / AI Services の費用は、検証 RG の費用だけでは把握できない場合があります。変更前のプランと利用チームを確認し、合意のないプラン変更は行いません。[Defender](https://learn.microsoft.com/en-us/azure/defender-for-cloud/ai-onboarding)

### 削除前に対象と証跡を確認する

- `.env` の subscription / tenant / RG が今回の専用環境であることを確認します。
- 必要な証跡は ID、本文、内部情報を除いた形で残します。生ログは公開しません。
- RG 内外のリソース、ロック、共有依存、バックアップ、Policy 割当、Defender の変更有無を確認します。
- Foundry account の名前・リージョンは、soft-delete / purge 確認に必要になるため非公開の作業記録へ控えます。

```bash
source .env
az resource list --subscription "$AZURE_SUBSCRIPTION_ID" \
  --resource-group "$AZURE_RESOURCE_GROUP" --output table
```

先に要るセクション：当日に構築した全セクション。詳細な会社ルールは [Run 0](../runs/run0_desk.md) で確認します。

## 3. 構築

構築作業はありません。S1 の予算通知と専用 RG、全セクションの依存先を削除前に照合します。

当日の時間配分と実行順は該当 [Run 文書](00_overview.md#4-セクションと-run-の地図) に従います。骨組み・Azure 未実行です。

## 4. 確認

### 費用の反映を確認する

```bash
bash scripts/cost_check.sh
```

スクリプトはポータルでの確認項目と、後で利用者が実行する CLI 例を表示するだけです。翌日以降も Cost analysis で費用を確認し、反映遅延がある間は終了判定を保留します。RG 消失と、残存リソース・費用確認の完了を別々に記録します。

記録項目：実施日、削除対象の匿名識別子、RG 消失確認、soft-delete 確認、RG 外の確認、Defender 変更復帰、費用の確認期間と結果。未確認がある場合は C10 を Pending にします。

Azure OpenAI の費用にハードリミットはありません。APIM の `token-quota` もすべての費目を止める機能ではありません。[APIM 制限](https://learn.microsoft.com/en-us/azure/api-management/llm-token-limit-policy)

対象：C10。[checks](../../checks/README.md) に合成入力・期待結果・実結果・日付・Pass / Fail / Pending を記録します。未実施は Pending。公開しない証跡は `evidence/` に保存します。

```bash
bash scripts/verify.sh --section 9
```

コマンドはリポジトリ直下から実行します。設定収集だけでは合格になりません。

## 5. よくあるエラー

（Run 1 初回で記入）

S3 は Run 2、S7 と S8 の追加検証は Run 3 の初回に追記します。構築欄に引き継いだ「よくある失敗」は旧ドラフトの想定であり、この環境で経験した実測ではありません。

## 6. 削除

### 削除して費用を確認する

```bash
bash scripts/teardown.sh --delete '<resource-group-name>'
bash scripts/teardown.sh --status
bash scripts/cost_check.sh
```

**確認ポイント**：[削除・費用](09_teardown_cost.md) に従い、RG 消失、soft-delete / purge、RG 外のリソース、Defender プラン、課金反映を確認します。

**よくある失敗**：`--no-wait` の成功を削除完了とする、RG がないだけで請求が止まったと判断する。

コマンド形式の参照：[診断設定 CLI](https://learn.microsoft.com/en-us/cli/azure/monitor/diagnostic-settings?view=azure-cli-latest)、[Policy 割当 CLI](https://learn.microsoft.com/en-us/cli/azure/policy/assignment?view=azure-cli-latest)。リソース固有のカテゴリ、定義と効果、パラメータは上記の要確認事項として残しています。

### RG を削除する

スクリプトは `.env` の RG と引数の一致を要求します。対象 RG 内のすべてのリソースを削除するため、共有 RG では使いません。

```bash
bash scripts/teardown.sh --delete '<resource-group-name>'
```

内部で使う基本コマンドは次の形です。`--no-wait` は削除開始だけを意味します。

```bash
az group delete --subscription "$AZURE_SUBSCRIPTION_ID" \
  --name "$AZURE_RESOURCE_GROUP" --yes --no-wait
az group exists --subscription "$AZURE_SUBSCRIPTION_ID" \
  --name "$AZURE_RESOURCE_GROUP"
```

`teardown.sh` は定期的に RG 消失を確認し、待機上限でも存在すれば終了コード 2 を返します。ロックや依存関係による失敗をポータルで調べ、削除状況を再確認します。照会失敗を削除成功とは扱いません。

```bash
bash scripts/teardown.sh --status
```

### Soft-delete と purge を確認する

Foundry account は RG 削除後も削除済みリソースとして残り、再作成・完全削除に purge が必要な場合があります。対象・保持条件・CLI の対応は要確認です。Key Vault 等にも削除済み状態や purge protection の確認が必要です。不可逆の purge は対象と復元不要を確認してから利用者が行い、スクリプトからは自動実行しません。

```bash
# 要確認：使用中の CLI と Foundry account 種別で対応を確認する参考例。
az cognitiveservices account list-deleted \
  --subscription "$AZURE_SUBSCRIPTION_ID" --output table
# 要確認：一覧の対象と復元不要を確認した後だけ実行する例。
az cognitiveservices account purge \
  --subscription "$AZURE_SUBSCRIPTION_ID" \
  --location '<deleted-account-location>' \
  --resource-group '<original-resource-group-name>' \
  --name '<deleted-foundry-account-name>'
```

### RG 外の残存とプランを確認する

APIM、Firewall、WAF、Private Endpoint、DNS、監視、共有 Log Analytics、予算・Policy 割当等の所属先を確認します。共有リソースは勝手に削除しません。Run 2 と Run 3 の RG は個別に確認します。

検証のため変更した Defender プランを管理者と確認し、必要なら変更前へ戻します。RG 削除だけでサブスクリプション単位のプランが元に戻るとは扱いません。既存のプランを一律に無効化しません。

## 7. 費用

### 初期骨組みの概算（2026-09-14・履歴）

現在の既定値は下記 v2 見積りです。次の単価・比較シナリオは初期検討の前提として保持し、現行 Run の予算には転用しません。

**Japan East・2026-09-14・USD・730h/月**の入力単価です。提供された調査値を転記した概算で、見積り保証ではありません。実際の契約・SKU・リージョン・課金単位・税・通信量・無料枠は実行前に要確認です。

| サービス | 月額または従量単価 |
| --- | --- |
| Firewall Basic / Standard | $288 / $913 |
| APIM Basic v2 / Standard v2 | $150 / $700 |
| App Gateway WAF v2 | 約 $392 |
| AI Search Basic / S1 | $97 / $324 |
| Cosmos DB 3000 RU/s | $197（Serverless は小規模検証なら数ドルという想定。従量で変動） |
| Bastion Basic | $139 |
| Private Endpoint | $7.3 / 個 |
| App Service B1 | $14 |
| Log Analytics | $3.34 / GB |
| gpt-5 mini | 入力 $0.45 / 出力 $3.60、各 1M トークン |

| シナリオ | 概算月額 | 前提 |
| --- | --- | --- |
| 都度構築 | $100〜300 | 週 1 回 × 8h、各回削除。全費目が時間比例するとは限りません |
| 低コスト常時稼働 | 約 $700（WAF 込み約 $1,100） | Firewall Basic 288＋APIM Basic v2 150＋AI Search Basic 97＋Cosmos Serverless 約 5＋PE 6 個 44＋App Service B1 14＋Defender CSPM 約 51＋ログ 10＋guardrails 8＋モデル 20＋雑費 5 ≈ 692。App Gateway WAF v2 を足すと＋392。実構成の総額は要確認 |
| Baseline 相当の常時稼働 | 約 $2,900 | 提供された概算。全 SKU・台数の積上げと従量費は要確認 |

低コスト比較は費目の足し算であり、Basic v2 と閉域 Foundry の結合を示すものではありません。Run 2 と Run 3 は別環境です。同時稼働させれば両方に課金されます。

Defender for Cloud はサブスクリプション単位の従量課金プランです。CSPM は $0.007 / 課金対象リソース / 時、AI Services は $0.0008 / 1K トークン、30 日無料枠という前提です。対象・適用条件は要確認で、共有サブスクリプションでは他チームにも課金が及びます。[Defender の有効化](https://learn.microsoft.com/en-us/azure/defender-for-cloud/ai-onboarding)

Azure OpenAI に費用のハードリミットはありません。予算アラートは通知であり停止ではありません。Run 3 の `llm-token-limit` の `token-quota`（超過時 403）でトークン使用量を制限しますが、インフラ費用や迂回経路は別途管理します。[APIM ポリシー](https://learn.microsoft.com/en-us/azure/api-management/llm-token-limit-policy)

S9 自体の追加明細 No はありません。前提どおりなら月 $77.13／3か月 $223.38／12か月 $917.53。残存や無料枠、反映遅延で変動します。

## 8. 本番との差

都度削除に対し、Baseline の Firewall Standard・APIM Standard v2 + PE・WAF・Search S1・Cosmos 3000 RU/s・Bastion・GRS は常時費用を持ちます。 [付録 B](appendix_b_production_diff.md) を参照します。
