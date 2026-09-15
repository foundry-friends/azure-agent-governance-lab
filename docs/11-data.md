# 4. データ基盤（Standard setup の BYO）

このセクションを使う Run: Run 1／Run 2。先に要るセクション: S1・S3。

> **Note** 現在は骨組み・Azure 未実行です。コマンドはリポジトリ直下の Bash で実行する予定の手順です。

## 4.1. 目的

統制層⑧として、自前 Bicep で目標 SKU・IP 制限・ローカル認証無効を持つデータ基盤を用意し、41 に ID を渡します。

## 4.2. 前提

S1 の専用 RG と S3 の非空の IP 許可リストが必要です。MI のデータプレーン権限は 41 の割当と照合します。

## 4.3. 構築

### BYO リソースを作成する

1. [04_data.bicep](../infra/modules/04_data.bicep) の設定を下表と照合します。
2. S5 のラッパ展開で `data` モジュールを 41 より先に作成します。
3. 展開後に各リソースの [プロパティ] で ARM ID を確認します。
4. 3 つの ID を `.env` に記録します。

| 項目 | 値 |
|---|---|
| Cosmos DB | `EnableServerless`、`disableLocalAuth=true`、社内 IP の `ipRules` |
| Storage | `Standard_LRS`、`allowSharedKeyAccess=false`、`defaultAction=Deny`、`bypass=AzureServices` |
| AI Search | `basic`、`disableLocalAuth=true`、社内 IP の `networkRuleSet.ipRules` |
| `.env` の Search ID | `AI_SEARCH_RESOURCE_ID` |
| `.env` の Storage ID | `AZURE_STORAGE_ACCOUNT_RESOURCE_ID` |
| `.env` の Cosmos ID | `AZURE_COSMOS_DB_ACCOUNT_RESOURCE_ID` |

### 41 に ID を渡す

1. main.bicep の `standardSetup` が下表の outputs を使うことを確認します。
2. 41 の BYO 存在確認が成功したことを確認します。
3. 41 が別名の既定リソースを新規作成していないことを確認します。

| 項目 | 値 |
|---|---|
| `aiSearchResourceId` | `data.outputs.aiSearchResourceId` |
| `azureStorageAccountResourceId` | `data.outputs.azureStorageAccountResourceId` |
| `azureCosmosDBAccountResourceId` | `data.outputs.azureCosmosDBAccountResourceId` |

> **補足** ラッパは同じ処理内で outputs を渡します。`.env` の ID は事後照合用です。41 を直接呼ぶ場合の入力名も同じですが、本手順の入口はラッパに統一します。

[41 の調査 §2](../infra/params/41_parameters.md) で、Cosmos サーバーレス、Search Basic、Storage LRS、ローカル認証無効、Key Vault、タグが新規作成 param では設定できないため BYO を採用します。Key Vault は S2、Foundry の認証とタグは S5 で補います。

> **Note** 要確認: Provisioned の 3000 RU/s 要件はサーバーレスへ適用しません。capability host・データプレーン RBAC・信頼サービス例外の実動作は Run 1 で確認します。

## 4.4. 確認

C01: capability host と接続先 3 ID、S2 の Key Vault、合成入力の応答を確認します。Cosmos 接続の AAD / ResourceId を照合します。SKU・ローカル認証・IP 制限の設定値も確認します。

```bash
bash scripts/verify.sh --section 4
```
実行結果の確認ポイント: 設定収集または案内のみで、未完了は終了コード 2 です。

[確認項目](../checks/README.md) ごとに実施日・Run・入力・期待結果・実結果・Pass / Fail / Pending を非公開の `evidence/` に記録します。未実施は Pending です。

## 4.5. うまくいかない場合

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

## 4.6. 削除

1. 当日に構築したリソースと共有依存を確認します。
2. [S9](90-cleanup-cost.md) に従って専用 RG を削除します。
3. RG 外・soft-delete・Defender の設定を別々に確認します。

> **Note** 要確認: 部分削除時の依存・capability host の再作成可否は（Run 1 初回で記入）です。

## 4.7. 費用

| Excel v3 明細 No | 項目 | 通常月 USD |
|---|---|---:|
| 2 | Azure Cosmos DB / サーバーレス RU | 0.285000 |
| 3 | Azure Cosmos DB / サーバーレス Storage | 0.282500 |
| 4 | Storage account / Standard LRS Hot | 0.200000 |
| 8 | AI Search / Basic 常時分 | 0.000000 |
| 12 | AI Search / Basic 検証日分 | 4.256000 |

2026-09-15 の見積り v3 の既定値です。Japan East、原則 32h/月の検証、CSPM は既定 OFF です。No.8 と No.12 は常時／検証日の切替で、二重計上しません。No.6 は S1/S6 の共通費です。見積り保証ではありません。

## 4.8. 本番との差

本番では負荷・復旧要件に合わせて Search S1、Provisioned Cosmos 3000 RU/s、Storage GRS と閉域接続を設計します。[付録 B](92-appendix-production-diff.md) を参照します。

---

前へ: [ネットワーク境界（IP 許可リストと送信の絞り込み）](10-network-boundary.md) / 次へ: [Foundry とエージェント](12-foundry-agent.md) / [トップに戻る](../README.md)
