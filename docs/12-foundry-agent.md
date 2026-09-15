# 5. Foundry とエージェント

このセクションを使う Run: Run 1／Run 2。先に要るセクション: S2・S4。

> **Note** 現在は骨組み・Azure 未実行です。コマンドはリポジトリ直下の Bash で実行する予定の手順です。

## 5.1. 目的

Standard setup に prompt agent を作り、C01 と C09 のガードレール部分を確認します。

## 5.2. 前提

S2 の Key Vault / 権限設計と S4 の BYO 設計が必要です。新ランタイム用 Foundry project を使用します。

> **Note** 要確認: 固定版 41 の Preview API 使用と「Preview 手順なし」の適合性は未解決です。vendor を変更せず、GA 機能との対応をレビューするまで deploy.sh の固定停止点を外しません。

## 5.3. 構築

### 固定版 41 をラッパから呼ぶ

1. [Run 1 例](../infra/params/run1.example.json) をローカル JSON にコピーします。
2. modelVersion、容量、社内 IP と固定 deploymentTimestamp を入力します。
3. S4 の 3 outputs が 41 の BYO param に渡ることを確認します。
4. `deployApplicationInsights=false` を確認します。
5. [infra の停止条件](../infra/README.md) をレビューします。
6. レビュー完了後の入口を実行します。

```bash
bash scripts/deploy.sh --run 1
```
実行結果の確認ポイント: 現在は固定停止点で終了します。展開成功とは扱いません。

> **Note** 要確認: 固定版 41 に networkAcls / publicNetworkAccess / disableLocalAuth の入力 param はありません。41 の作成から後追い設定まで公開・ローカル認証有効の時間が生じます。この順序と既存 Deny の競合を Run 1 前に解決し、統制済みと誤認しないようにします。

### Foundry account の IP 制限と認証を後追いする

1. [03_network_acls.bicep](../infra/modules/03_network_acls.bicep) の既存 account 名を実物と照合します。
2. Foundry account の ARM ID を `.env` に記録します。
3. 社内 IP の規則を JSON に変換します。

```bash
FOUNDRY_IP_RULES="$(python3 -c 'import json,sys; print(json.dumps([{"value": x} for x in json.loads(sys.argv[1])]))' "$ALLOWED_IP_RANGES")"
```
実行結果の確認ポイント: S3 で検証した社内 IP だけを使用します。

4. 認証とネットワークを更新します。

```bash
az resource update --subscription "$AZURE_SUBSCRIPTION_ID" --ids "$FOUNDRY_ACCOUNT_RESOURCE_ID" --api-version 2025-06-01 --set properties.publicNetworkAccess=Enabled properties.disableLocalAuth=true properties.networkAcls.defaultAction=Deny properties.networkAcls.bypass=None "properties.networkAcls.ipRules=$FOUNDRY_IP_RULES" --output none
```
実行結果の確認ポイント: 再取得して値を照合し、C03/C08 で効果を確認します。未実行です。

5. account / project / モデルの [タグ] に S1 の匿名タグを追加します。

> **補足** `existing` 宣言だけではリソースを変更できません。03 モジュールは参照と目標値を返し、上記の更新を明示的に行います。再展開すると 41 が設定を戻す可能性があるため、毎回再確認します。tags の適用可能なリソース種別は要確認です。

### prompt agent を作成する

1. Microsoft Foundry <https://ai.azure.com> に移動します。
2. 対象の Foundry project を選択します。
3. [エージェント] を開きます。
4. [エージェントの作成] を選択します。
5. 下表の値を入力します。
6. [保存] を選択します。
7. [テスト] で合成入力を送信します。

| 項目 | 値 |
|---|---|
| 名前 | `governance-lab-agent` |
| モデル | 検証した `gpt-5-mini` / `GlobalStandard` の配置 |
| 指示 | 下記の合成検証用指示 |
| ツール | Run 1 は追加なし、Run 2 は APIM 経由の許可先だけ |

```text
合成データだけを扱う検証用アシスタントです。登録した許可済みツール以外を使わず、不明な内容は不明と回答してください。
```
実行結果の確認ポイント: 指示を権限制御の代わりにせず、ツールと RBAC の設定も確認します。

> **画面の見え方** 上記は操作のドラフトです。新ランタイムの画面名・入力欄は（Run 1 初回で記入）です。

### モデル向けガードレールを確認する

1. モデル配置の [コンテンツ フィルター] で適用する RAI ポリシーを確認します。
2. [合成プロンプト](../assets/prompts/README.md) の正常入力と拒否入力を試します。
3. 適用設定と実結果を別々に記録します。

> **Note** 要確認: UI・適用プロパティと GA 範囲を確認します。エージェント guardrails の Preview 介入点、Tool call / Tool response、Task Adherence は対象外で GA 後に追記します。hosted 固有の fail open 再現は付録 A の骨子です。

## 5.4. 確認

C01: capability host 成功、Entra ID 接続、合成入力の 1 往復を確認します。C09: RAI ポリシーの存在と適用、期待する拒否を確認します。S6 の App Insights 接続は未完了のまま合格にしません。

```bash
bash scripts/verify.sh --section 5
```
実行結果の確認ポイント: 設定収集または案内のみで、未完了は終了コード 2 です。

[確認項目](../checks/README.md) ごとに実施日・Run・入力・期待結果・実結果・Pass / Fail / Pending を非公開の `evidence/` に記録します。未実施は Pending です。

## 5.5. うまくいかない場合

### IP 制限で agent service が到達できない場合

1. 同じ合成入力で、Cosmos / Storage / Search のどの接続が失敗するかを特定します。
2. 対象リソースの RBAC とローカル認証無効設定を確認します。
3. 変更前の IP 規則と拒否結果を非公開の `evidence/` に記録します。
4. Azure portal で当該リソースの [ネットワーク] を開きます。
5. 下表の当該リソースの設定だけを「Entra 認証のみ＋公開」に変更します。
6. 同じ合成入力を再実行します。
7. 到達結果と IP 制限を外した範囲を `evidence/` に記録します。
8. 検証後に元の IP 許可リストを戻します。

| 項目 | 値 |
|---|---|
| Cosmos の復旧設定 | `publicNetworkAccess=Enabled`、`ipRules=[]`、`isVirtualNetworkFilterEnabled=false`、`disableLocalAuth=true` を維持 |
| Storage の復旧設定 | `publicNetworkAccess=Enabled`、`networkAcls.defaultAction=Allow`、`allowSharedKeyAccess=false` を維持 |
| Search の復旧設定 | `publicNetworkAccess=enabled`、`networkRuleSet.ipRules=[]`、`disableLocalAuth=true` を維持 |
| 判定 | 接続が回復しても C08 の IP 制限下の到達は Pass にしません |

> **Note** 要確認: UI 名・反映時間・信頼サービス例外の適用は（Run 1 初回で記入）です。Run 2 の Deny が変更を拒否する場合は、S8 の対象限定例外の確認へ戻ります。

> **補足** この代替手順は N2 の例外です。ネットワーク制限を外した事実を記録し、本番では Private Endpoint が必要な差分として [付録 B](92-appendix-production-diff.md) に引き継ぎます。Foundry・Key Vault・APIM・App Service を一括で公開には戻しません。

### それ以外の失敗

（Run 1 初回で記入）

1. モデル版とクォータを確認します。
2. capability host の失敗時は RBAC と到達を切り分けます。
3. 作成後の host 更新可否を推測せず、再作成の要否を確認します。

## 5.6. 削除

1. 当日に構築したリソースと共有依存を確認します。
2. [S9](90-cleanup-cost.md) に従って専用 RG を削除します。
3. RG 外・soft-delete・Defender の設定を別々に確認します。

> **Note** 要確認: 部分削除時の依存・capability host の再作成可否は（Run 1 初回で記入）です。

## 5.7. 費用

| Excel v3 明細 No | 項目 | 通常月 USD |
|---|---|---:|
| 1 | Microsoft Foundry リソース / project / prompt agent | 0.000000 |
| 14 | gpt-5 mini / Global Standard 入力 | 9.000000 |
| 15 | gpt-5 mini / Global Standard 出力 | 10.800000 |
| 16 | Content Safety / Standard テキストレコード | 7.500000 |

2026-09-15 の見積り v3 の既定値です。Japan East、原則 32h/月の検証、CSPM は既定 OFF です。No.8 と No.12 は常時／検証日の切替で、二重計上しません。No.6 は S1/S6 の共通費です。見積り保証ではありません。

## 5.8. 本番との差

本番ではモデル変更管理と可用性を設計します。[付録 B](92-appendix-production-diff.md) を参照します。

---

前へ: [データ基盤（Standard setup の BYO）](11-data.md) / 次へ: [監視と監査](13-monitoring.md) / [トップに戻る](../README.md)
