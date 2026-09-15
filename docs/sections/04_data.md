# S4：データ基盤（Standard setup の BYO）

このセクションを使う Run: Run 1 / Run 2 / Run 3｜先に要るセクション: S1（閉域時は S3）

## 1. 目的

統制層⑧ データ保護として、自テナントの Cosmos DB・Storage・AI Search を Standard setup の接続先にします。

## 2. 前提

S1 の専用 RG、データリソースの作成権限と MI へのロール割当権限が必要です。閉域版は S3 の名前解決・経路が前提です。

先に要るセクション：S1（閉域時は S3）。詳細な会社ルールは [Run 0](../runs/run0_desk.md) で確認します。

## 3. 構築

公式 41 の BYO param `azureCosmosDBAccountResourceId` / `azureStorageAccountResourceId` / `aiSearchResourceId` を使用する予定です。Cosmos サーバーレス、Storage LRS、Search Basic を事前作成して ID を渡す代替か、テンプレ改変かは要確認。専用モジュール S4 は今回作りません。

41 の新規作成では Cosmos に `EnableServerless` 指定がなく、Search は `standard`、Japan East の Storage は `Standard_ZRS` です。既定展開は見積り条件を満たしません。Run 1 の JSON は BYO ID を placeholder にして黙って既定 SKU を立てない形です。Cosmos 接続は `authType: AAD` と `metadata.ResourceId` が必要。既存 Cosmos の Provisioned / Serverless と 3000 RU/s の扱いは [設計判断](../00_design.md) を参照し、Serverless に Provisioned の RU/s を混在させません。

Run 2 は 15 のデータ PE・DNS を利用します。Search を検証日のみ作成する場合の capability host 依存・削除再作成順は要確認です。

当日の時間配分と実行順は該当 [Run 文書](00_overview.md#4-セクションと-run-の地図) に従います。骨組み・Azure 未実行です。

## 4. 確認

C01：capability host の接続先と自前 Cosmos / Storage / Search を照合し、Entra ID の合成入力 1 往復で確認します。Key Vault は 41 に含まれないため S2 の未完了を隠さず、C01 全体を自動 Pass にしません。

対象：C01。[checks](../../checks/README.md) に合成入力・期待結果・実結果・日付・Pass / Fail / Pending を記録します。未実施は Pending。公開しない証跡は `evidence/` に保存します。

```bash
bash scripts/verify.sh --section 4
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
| 2 | Cosmos サーバーレス RU | 0.285000 | 0.285000 |
| 3 | Cosmos サーバーレス容量 | 0.282500 | 0.282500 |
| 4 | Storage LRS Hot | 0.200000 | 0.200000 |
| 9 | AI Search Basic 常時分 | 0.000000 | 97.090000 |
| 17 | AI Search Basic 検証日分 | 4.256000 | 0.000000 |

2026-09-15 見積り report v2 の条件。都度は原則32h/月、WAFのみ8h/月、DNSは6 zone・4課金日です。常時列は同じ単価の固定費を730hへ換算し、従量は同じ使用量の仮定です。No.9 と17は切替で二重計上しません。No.6は S1/S6 の共通費で一度だけ計上。No.24は通常月 $8、初月無料を1か月と近似。No.26は承認してONなら月 $51.10。実請求保証ではありません。

## 8. 本番との差

AI Search Basic → S1、Cosmos サーバーレス → 3000 RU/s、Storage LRS → GRS。 [付録 B](appendix_b_production_diff.md) を参照します。
