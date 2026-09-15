# S5：Foundry とエージェント

このセクションを使う Run: Run 1 / Run 2 / Run 3｜先に要るセクション: S2・S4（閉域時は S3）

## 1. 目的

目的は Standard setup 上に prompt agent を 1 つ作り、ID・監査・Policy の統制を確認することです。Azure で未実行です。以下のコマンドは利用者が後で実行する例です。引数・API 世代・画面の未確定部分は「要確認」としています。

## 2. 前提

先に要るセクション：S2・S4（閉域時は S3）。詳細な会社ルールは [Run 0](../runs/run0_desk.md) で確認します。

## 3. 構築

### `41-standard-agent-setup` を展開する

[infra の手順](../../infra/README.md) で固定 SHA のテンプレートを取得します。`main.bicep` と依存 module を読んで例のパラメータを確定します。希望は Japan East、Cosmos DB Serverless、AI Search Basic です。

```bash
# パラメータ・認証・出力のレビューが終わってから実行します。
bash scripts/deploy.sh --run 1
```

**確認ポイント**：Foundry account / project、Cosmos DB、Storage、AI Search、Key Vault が揃い、接続が Entra ID / managed identity で成立することを確認します。account / project の capability host が成功していることをポータルで確認します。出力名と必要な RBAC の詳細は固定テンプレートで要確認です。机上確認ではトップレベルoutputsが0件で、Key Vaultも含まれません。必要なロールと取得経路は41_parameters.mdの結果を参照し、実機での照合は未完了です。

**よくある失敗**：Serverless の指定がなく Provisioned の既定値になる、managed identity にデータアクセス権限がない、capability host を更新しようとする。capability host は作成後変更不可です。

### Foundry ポータルで prompt agent を 1 つ作成する

対象 Foundry project を選び、利用可能なモデルで最小の prompt agent を作ります。合成入力だけを使い、外部ツールは追加せず、まず 1 往復の応答を確認します。新ランタイムの画面・作成項目・モデル選択手順は要確認です。

**確認ポイント**：実行者は Foundry Agent Consumer（呼び出しのみ）、開発者は Foundry User を基本に、管理用途の Foundry Project Manager / Foundry Account Owner / Foundry Owner を分離します。具体的な操作権限とスコープは [RBAC](https://learn.microsoft.com/en-us/azure/foundry/concepts/rbac-foundry) で確認します。テスト用の権限が上位スコープから継承されていないことも確認します。

**よくある失敗**：Owner のまま試して最小権限が機能したと判断する、Consumer に作成・編集を期待する、hub-based project を使う。

### 新しい Foundry account を展開する

- [ ] 固定コミットと確定パラメータで展開します。具体的なパラメータとコマンドは要確認です。
- [ ] capability host、Entra ID 接続、private endpoint、DNS、public network 無効化を確認します。
- [ ] Run 1 と同じログ・RBAC・Policy の検証をこの環境でも行います。

### モデルとエージェントのガードレールを分ける

- [ ] モデル向け（GA）の正常入力・拒否入力を合成データで検証します。
- [ ] エージェント向け guardrails、Tool call / Tool response 介入点、Task Adherence は Preview と明記します。
- [ ] 使用する RAI ポリシー ID の存在と対象への適用を確認します。具体的な参照 API / プロパティは要確認です。
- [ ] hosted agent の存在しない RAI ポリシー ID は fail open になるため、デプロイ成功だけで合格にしません。合成入力による挙動まで検証します。

### ラッパと公式テンプレの境界

S1/S2/S4/S5 の中心は公式 41 を薄いラッパで呼びます。[パラメータ一覧](../../infra/params/41_parameters.md) の差分を解消する前に展開しません。`enablePrivateNetwork=true` のときは **41 ではなく 15 を呼ぶ必要があります**。VNet injection は作成時固定であり、分岐の実装は Run 2 で確定（要確認）。現在のスクリプトは Run 2 を停止し、公開版 41 へフォールバックしません。

モデルは `modelName=gpt-5-mini`、`modelSkuName=GlobalStandard` を希望し、`modelVersion` と Japan East の提供・容量は要確認。ポータルの prompt agent、content filter / Prompt Shields、Control Plane の資産一覧も手で照合します。C09 の fail open 実再現は hosted agent の付録 A だけで、本編で試験済みにはしません。

当日の時間配分と実行順は該当 [Run 文書](00_overview.md#4-セクションと-run-の地図) に従います。骨組み・Azure 未実行です。

## 4. 確認

### 統制を検証する

```bash
bash scripts/verify.sh --section 5
```

[checks](../../checks/README.md) の C01〜C07 と C10 を行います。CLI 骨子は設定情報の収集だけで、実呼び出し・拒否テスト・本文の閲覧制限を自動判定しません。終了コード 2 は未完了を意味します。実証できた項目だけ Pass、失敗は Fail、未実施は Pending と記録します。

**確認ポイント**：成功系と拒否系を分けて記録し、合成入力・期待結果・実結果・実施日を残します。公開する証跡から実 ID と本文を除きます。

**よくある失敗**：デプロイ成功を統制の成功と扱う、CLI の一覧表示だけで Pass にする、Run 2/3 の項目まで合格扱いする。

対象：C01・C09 のガードレール部分。[checks](../../checks/README.md) に合成入力・期待結果・実結果・日付・Pass / Fail / Pending を記録します。未実施は Pending。公開しない証跡は `evidence/` に保存します。

```bash
bash scripts/verify.sh --section 5
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
| 1 | Foundry / project / prompt agent | 0.000000 | 0.000000 |
| 21 | gpt-5 mini 入力 | 9.000000 | 9.000000 |
| 22 | gpt-5 mini 出力 | 10.800000 | 10.800000 |
| 23 | Content Safety | 7.500000 | 7.500000 |

2026-09-15 見積り report v2 の条件。都度は原則32h/月、WAFのみ8h/月、DNSは6 zone・4課金日です。常時列は同じ単価の固定費を730hへ換算し、従量は同じ使用量の仮定です。No.9 と17は切替で二重計上しません。No.6は S1/S6 の共通費で一度だけ計上。No.24は通常月 $8、初月無料を1か月と近似。No.26は承認してONなら月 $51.10。実請求保証ではありません。

## 8. 本番との差

モデルと prompt agent に対する指定 Baseline SKU の直接の差分はありません。 [付録 B](appendix_b_production_diff.md) を参照します。
