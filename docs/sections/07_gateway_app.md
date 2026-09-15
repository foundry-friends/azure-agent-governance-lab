# S7：ゲートウェイと呼び出しアプリ

このセクションを使う Run: Run 3｜先に要るセクション: S1・S2・S5・S6

## 1. 目的

Azure で未実行です。Run 2 から分離した公開側の環境で APIM Basic v2 を検証します。Entra ID 認証を維持し、API キーや APIM subscription key を必要とする設計は使いません。

## 2. 前提

先に要るセクション：S1・S2・S5・S6。詳細な会社ルールは [Run 0](../runs/run0_desk.md) で確認します。

## 3. 構築

### 公開側の検証環境を用意する

- [ ] Run 1 相当の別 RG / Foundry account を用意し、モデルと managed identity のアクセス権限を確認します。
- [ ] Foundry ポータルの AI Gateway 設定で APIM Basic v2 を作成・関連付けします。Entra ID の認証構成と実際の UI は要確認です。
- [ ] 新規・既存 project の関連付けと、実際の呼び出し経路を確認します。
- [ ] 閉域結合が目的の場合は Standard v2 / Premium v2＋Private Endpoint が必要です。テンプレート `16-private-network-standard-agent-apim-setup` を参考に別途設計します。Basic v2 をそのまま閉域へ接続しません。

### トークン制限を設定する

- [ ] `llm-token-limit` の `token-quota`、期間、集計キーを決めます。XML 属性・期間の値・配置場所は要確認です。
- [ ] C09：小さな検証用 quota を設定して超過時 403 を確認します。レート超過と混同しません。
- [ ] APIM ログで実際に経由したことを確認します。バックエンドへの直接呼び出しで迂回できない権限設計は要確認です。
- [ ] Azure OpenAI に費用のハードリミットはありません。quota はトークン制御であり、インフラ課金・全経路の費用停止を保証しません。

### 最終回だけ App Gateway WAF を追加する

- [ ] 保護するアプリの入口、バックエンド、Entra ID 認証、WAF ルール・検証入力を先に確定します（要確認）。
- [ ] WAF を置いただけで Foundry のすべての呼び出しを保護したことにしません。
- [ ] 当日構築・当日削除を計画し、約 $392/月相当の入力単価を費用表へ反映します。

### 呼び出しアプリ

自前 `07_gateway_app.bicep` は APIM Basic v2・App Service Linux B1・最終回のみ WAF v2 を扱う骨子です。呼び出し UI の OBO によるユーザーコンテキストと MI を設計します。OBO の具体的な構成は要確認。APIM の subscription key を要求する方式を採用しません。16 は閉域の参考で、固定版の実在名は `16-private-network-standard-agent-apim-setup` です。

当日の時間配分と実行順は該当 [Run 文書](00_overview.md#4-セクションと-run-の地図) に従います。骨組み・Azure 未実行です。

## 4. 確認

### APIM の LLM ログと本文の保護を確認する

- [ ] 本文を記録する必要性を決め、LLM ログの有効化・対象フィールド・マスキング・閲覧権限を確認します（要確認）。
- [ ] Foundry 診断ログと本文ログを区別し、Application Insights の `AppGenAIContent` と重複収集するかを決めます。
- [ ] 30 日保持、機微属性へのアクセス制限、収集停止手順、従量費を確認します。

対象：C09。[checks](../../checks/README.md) に合成入力・期待結果・実結果・日付・Pass / Fail / Pending を記録します。未実施は Pending。公開しない証跡は `evidence/` に保存します。

```bash
bash scripts/verify.sh --section 7
```

コマンドはリポジトリ直下から実行します。設定収集だけでは合格になりません。

## 5. よくあるエラー

（Run 1 初回で記入）

S3 は Run 2、S7 と S8 の追加検証は Run 3 の初回に追記します。構築欄に引き継いだ「よくある失敗」は旧ドラフトの想定であり、この環境で経験した実測ではありません。

## 6. 削除

### 検証・終了

- [ ] C09 と C10 を実施し、Run 1 相当の C01〜C07 もこの環境で再確認します。
- [ ] [削除・費用](09_teardown_cost.md) を実施します。Gateway の関連付け解除だけで APIM 本体が削除されたと判断しません。

根拠：[AI Gateway](https://learn.microsoft.com/en-us/azure/foundry/configuration/enable-ai-api-management-gateway-portal)、[トークン制限](https://learn.microsoft.com/en-us/azure/api-management/llm-token-limit-policy)、[ガードレール](https://learn.microsoft.com/en-us/azure/foundry/guardrails/guardrails-overview)、[モデル Policy](https://learn.microsoft.com/en-us/azure/foundry/how-to/model-deployment-policy)、[組み込み Policy](https://learn.microsoft.com/en-us/azure/ai-services/policy-reference)、[本文トレース](https://learn.microsoft.com/en-us/azure/foundry/observability/how-to/traces-sensitive-content)。

専用 Run 環境の終了時は [S9](09_teardown_cost.md) で RG 単位に削除します。このセクションだけの部分削除は依存・共有・capability host の再作成可否を確認後に行います（要確認）。未確定の個別削除 API は置きません。RG 外、soft-delete、Defender のサブスク設定は別確認です。

## 7. 費用

| Excel 明細 No | 項目 | 都度構築の月額 USD | 常時730hの月額 USD |
|---|---|---:|---:|
| 16 | APIM Basic v2 | 6.575360 | 150.000400 |
| 18 | App Service Linux B1 | 0.608000 | 13.870000 |
| 19 | WAF v2 固定 | 4.176000 | 381.060000 |
| 20 | WAF v2 1 CU | 0.115200 | 10.512000 |

2026-09-15 見積り report v2 の条件。都度は原則32h/月、WAFのみ8h/月、DNSは6 zone・4課金日です。常時列は同じ単価の固定費を730hへ換算し、従量は同じ使用量の仮定です。No.9 と17は切替で二重計上しません。No.6は S1/S6 の共通費で一度だけ計上。No.24は通常月 $8、初月無料を1か月と近似。No.26は承認してONなら月 $51.10。実請求保証ではありません。

## 8. 本番との差

APIM Basic v2 → Standard v2 + PE、WAF は最終回のみ → 常設。 [付録 B](appendix_b_production_diff.md) を参照します。
