# S2：ID と権限

このセクションを使う Run: Run 1 / Run 2 / Run 3｜先に要るセクション: S1

## 1. 目的

統制層① ID・権限を担当し、project 用とアプリ用 Managed Identity、RBAC、Key Vault、ローカル認証無効化を扱います。

## 2. 前提

RG のリソース作成・ロール割当権限が必要です。Azure AI User / Agent Consumer / Developer という計画上の役割と、現行 Foundry のロール名（User / Agent Consumer 等）の対応・適用スコープは要確認です。Owner のまま最小権限を検証しません。

先に要るセクション：S1。詳細な会社ルールは [Run 0](../runs/run0_desk.md) で確認します。

## 3. 構築

公式 41 の account / project の system-assigned MI とデータ接続・ロール割当を利用します。アプリ用 MI は S7 です。

**固定版の差分**：41 は Key Vault を作成せず、対応 param もありません。Key Vault の用途・作成方法は要確認。キーの保管で Entra ID 認証を代用しません。Foundry と Search は `disableLocalAuth: false`、Cosmos は `true`、Storage は `allowSharedKeyAccess: false` です。Policy の監査だけでは無効化できません。BYO Search の設定と Foundry の後追い設定（または公式テンプレの改変方針）を確定するまで未完了です。詳細は [41 パラメータ](../../infra/params/41_parameters.md)。

当日の時間配分と実行順は該当 [Run 文書](00_overview.md#4-セクションと-run-の地図) に従います。骨組み・Azure 未実行です。

## 4. 確認

C02：上位権限のない Consumer / User / 無権限主体で合成入力の呼び出しと編集を試します。C03：ローカル認証無効、Entra ID 成功、未認証拒否を別々に記録します。キーは取得しません。publish 前の共有 agent identity と publish 後の専用 identity を区別し、後者では RBAC の再割当を確認します。

対象：C02・C03。[checks](../../checks/README.md) に合成入力・期待結果・実結果・日付・Pass / Fail / Pending を記録します。未実施は Pending。公開しない証跡は `evidence/` に保存します。

```bash
bash scripts/verify.sh --section 2
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
| 5 | Key Vault 操作 | 0.030000 | 0.030000 |
| 10 | MI / RBAC | 0.000000 | 0.000000 |

2026-09-15 見積り report v2 の条件。都度は原則32h/月、WAFのみ8h/月、DNSは6 zone・4課金日です。常時列は同じ単価の固定費を730hへ換算し、従量は同じ使用量の仮定です。No.9 と17は切替で二重計上しません。No.6は S1/S6 の共通費で一度だけ計上。No.24は通常月 $8、初月無料を1か月と近似。No.26は承認してONなら月 $51.10。実請求保証ではありません。

## 8. 本番との差

このセクションには指定された Baseline SKU の直接の差分はありません。 [付録 B](appendix_b_production_diff.md) を参照します。
