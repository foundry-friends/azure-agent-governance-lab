# S1：準備と土台

このセクションを使う Run: Run 1 / Run 2 / Run 3｜先に要るセクション: なし

## 1. 目的

統制層⑩ コスト、⑦ 監査の土台です。サブスク・RG・命名・タグ・予算・権限・Log Analytics と CLI / Bicep / 公式テンプレの固定を扱います。

## 2. 前提

### 前提を確認する

専用 RG を作成でき、対象 RG に Owner、またはリソース作成権限と User Access Administrator が必要です。Azure CLI 2.50 以上、Bicep、モデルの提供リージョンとクォータを確認します。Foundry project を使い、hub-based project は使いません。[Standard setup](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/standard-agent-setup)

```bash
az --version
az bicep version
# ログインしていない場合に利用者が実行します。
az login --tenant '<tenant-id>'
```

**確認ポイント**：Japan East で希望モデル・容量を使えること、対象サブスクリプションの費用負担、RG 作成権限と RBAC 割当権限を確認します。CLI 最低版の条件だけで最新 API の対応を保証しません。

**よくある失敗**：Contributor だけでロール割当を行う、モデルのクォータを確認しない、違うテナントにログインする。

先に要るセクション：なし。詳細な会社ルールは [Run 0](../runs/run0_desk.md) で確認します。

## 3. 構築

### `.env` を準備する

```bash
cp .env.example .env
cp infra/params/run1.example.json infra/params/run1.local.json
# エディターで .env とローカル JSON を編集します。
# .env は shell として実行されるため、信頼できる内容だけを書きます。
source .env
az account show --subscription "$AZURE_SUBSCRIPTION_ID" \
  --query '{subscription:id,tenant:tenantId}' --output table
```

**確認ポイント**：各 placeholder を置き換え、API キー・接続文字列を追加しません。実 ID のある `.env` と `*.local.json` は公開しません。

**よくある失敗**：引用符なしの `<...>` を shell がリダイレクトと解釈する、例の仮パラメータをそのまま使う。

### RG を作成する

```bash
az group create --subscription "$AZURE_SUBSCRIPTION_ID" \
  --name "$AZURE_RESOURCE_GROUP" --location "$AZURE_LOCATION"
```

**確認ポイント**：この検証だけの RG であることを確認します。展開スクリプトも同じ RG を作成・再利用するため、手動作成後に実行しても同一名を使います。後の RG 削除は中の全リソースが対象です。

**よくある失敗**：別チームの既存 RG を再利用する、サブスクリプション指定を省く。

### 初期骨組みの作業時間（履歴）

以下は組み替え前の仮置きで、現在の 8h × 初回・再現の計画に置き換えています。実測値ではありません。

時間は作業計画上の仮置きです。実測ではなく、権限・クォータ申請や提供待ちを含みません。

| Run | 内容 | 作業時間の目安 | 手順の状態 |
| --- | --- | --- | --- |
| Run 1 | Standard setup、ID、ログ、Policy、Defender、prompt agent | 3〜4 時間 | ドラフト |
| Run 2 | BYO VNet、Firewall Basic、Private Endpoint | 4〜6 時間 | 見出しと確認項目 |
| Run 3 | 公開側 APIM、ガードレール、最後に WAF | 3〜5 時間 | 骨子 |
| 各回の終了 | 削除、残存・課金確認 | 30〜60 分＋非同期削除待ち | 終了手順 |

### 開始コマンド

1. [設計判断](../00_design.md) と [削除・費用](09_teardown_cost.md) を読みます。
2. [公式テンプレートの固定取得・パラメータ確認](../../infra/README.md) を行います。
3. `.env.example` をコピーし、プレースホルダーを自分の環境の値に置き換えます。`.env` は公開しません。

```bash
cp .env.example .env
cp infra/params/run1.example.json infra/params/run1.local.json
# infra/README.md に従って main.bicep と照合し、ローカル JSON を完成させます。
# 要確認を解消後、.env の RUN1_PARAMETERS_REVIEWED=true を設定します。
bash scripts/deploy.sh --run 1
```

4. [S5](05_foundry_agent.md) の Application Insights、診断設定、Policy、Defender、agent 作成を手動で進めます。展開スクリプトだけでは統制設定は完了しません。
5. `bash scripts/verify.sh --section 5` と [10 個の検証項目](../../checks/README.md) で確認します。CLI 骨子は未検証項目を残して終了コード 2 を返します。
6. 作業後に `bash scripts/teardown.sh --delete '<resource-group-name>'`、続いて `bash scripts/teardown.sh --status` で削除を確認します。

このリポジトリを作成した時点では、上記コマンドは一度も Azure に対して実行していません。

### 命名・タグ・バージョン固定

用途・Run・削除予定を匿名のタグとして計画します。41 に tags param はないため適用方法は要確認。公式 41 の `deploymentTimestamp` は既定が毎回変わるため、**同じ RG での再展開は明示した固定文字列を再利用**します。CLI / Bicep の実バージョンは Run 1 当日に記録します。この環境に az / bicep はなく、インストールも実行もしていません。LAW は公式 41 の App Insights と一体のため S6 の接続方式が確定するまで独立の作成・所有を要確認とします。

当日の時間配分と実行順は該当 [Run 文書](00_overview.md#4-セクションと-run-の地図) に従います。骨組み・Azure 未実行です。

## 4. 確認

C10：通知先・しきい値・予測超過の設定と通知確認を記録します。予算通知は停止ではありません。Run 0 の会社承認を完了したとは扱いません。

対象：C10。[checks](../../checks/README.md) に合成入力・期待結果・実結果・日付・Pass / Fail / Pending を記録します。未実施は Pending。公開しない証跡は `evidence/` に保存します。

```bash
bash scripts/verify.sh --section 1
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
| 11 | Policy / 予算 / Activity Log 基本 | 0.000000 | 0.000000 |

2026-09-15 見積り report v2 の条件。都度は原則32h/月、WAFのみ8h/月、DNSは6 zone・4課金日です。常時列は同じ単価の固定費を730hへ換算し、従量は同じ使用量の仮定です。No.9 と17は切替で二重計上しません。No.6は S1/S6 の共通費で一度だけ計上。No.24は通常月 $8、初月無料を1か月と近似。No.26は承認してONなら月 $51.10。実請求保証ではありません。

## 8. 本番との差

Bastion を常設する構成との差を付録 B に示します。 [付録 B](appendix_b_production_diff.md) を参照します。
