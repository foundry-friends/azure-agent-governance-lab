# 3. データ基盤を作る

進め方: README の第0〜10章を順番に実施します。第2章の完了条件を満たしてから進めます。

> **Note** 状態: 構成ドラフト・操作の詳細は未確定（Azure 未実行）。構成変更日 2026-09-15。

> **補足** この章では環境を削除しません。通常の削除は最後の第10章です。中断して片付ける場合だけ、第10章へ進みます。

## 3.1. 目的

Foundry に渡す Storage・Cosmos DB・AI Search を先に作ります。後の章で一括作成する前提は使いません。

## 3.2. 前提

専用 RG と社内 IP の一覧があり、Key Vault の準備が完了しています。

## 3.3. 構築

> **Note** 要確認: この章は作成順と目標設定までのドラフトです。各作成ウィザードの GUI 操作を執筆・照合する必要があります。以下の表だけで構築済みとは扱いません。

### Storage → Cosmos DB → AI Search の順に作る

| 順番 | 作るもの | 作成する章内で設定すること |
|---|---|---|
| 1 | Storage account | Standard LRS、共有キー無効、既定拒否と社内 IP |
| 2 | Cosmos DB for NoSQL | Serverless、キーベース認証無効、社内 IP の許可リスト |
| 3 | AI Search | Basic、ロールベース認証のみ、社内 IP の許可リスト |

### キー認証の設定

| 対象 | GUI の設定 | 確認するプロパティ |
|---|---|---|
| Storage | [設定] → [構成] → [ストレージ アカウント キーのアクセスを許可する] を [無効] | `allowSharedKeyAccess=false` |
| Cosmos DB | 新規作成の [セキュリティ] → [キーベースの認証] を [無効] | `disableLocalAuth=true` |
| Search | [キー] → [ロールベースのアクセス制御] | `disableLocalAuth=true` |

### ID を次の章に渡す

1. 各リソースの ARM ID を確認します。
2. `.env` の次の項目に記録します。

| 項目 | 値 |
|---|---|
| `AZURE_STORAGE_ACCOUNT_RESOURCE_ID` | 作成した Storage の ARM ID |
| `AZURE_COSMOS_DB_ACCOUNT_RESOURCE_ID` | 作成した Cosmos DB の ARM ID |
| `AI_SEARCH_RESOURCE_ID` | 作成した Search の ARM ID |

> **Note** 要確認: Cosmos DB の IP 設定で Azure 全体を許可する例外を「信頼されたサービス」と同一視しません。社内 IP 制限下で Agent Service が到達できるかは第4章で接続時に確認します。Storage／Search のサービス例外も個別に確認します。

## 3.4. 完了条件

3リソースが実際に存在し、SKU・認証・IP 規則・ARM ID を確認できたら次へ進みます。ここでは未作成の capability host やエージェントへの呼び出しを確認しません。

```bash
az resource show --ids "<data-resource-id>" --query '{id:id,sku:sku,disableLocalAuth:properties.disableLocalAuth,allowSharedKeyAccess:properties.allowSharedKeyAccess,networkAcls:properties.networkAcls,ipRules:properties.ipRules,networkRuleSet:properties.networkRuleSet}' --output json
```
実行結果の確認ポイント: 対象リソースに対応する項目を目標値と照合します。期待する項目が null の場合は成功扱いにしません。

## 3.5. うまくいかない場合

作成権限、SKU の提供、IP 設定を確認します。GUI 手順が未確定ならこの章で止まり、未作成のまま次へ進めません。

## 3.6. 次の操作

データ基盤を残して第4章へ進み、作成済みの3 IDを Foundry の接続に使います。

## 3.7. 費用

| Excel v3 明細 No | 項目 | 通常月 USD |
|---|---|---:|
| 2 | Azure Cosmos DB / サーバーレス RU | 0.285000 |
| 3 | Azure Cosmos DB / サーバーレス Storage | 0.282500 |
| 4 | Storage account / Standard LRS Hot | 0.200000 |
| 8 | AI Search / Basic 常時分 | 0.000000 |
| 12 | AI Search / Basic 検証日分 | 4.256000 |

2026-09-15 の見積り v3 の既定値です。Japan East、原則 32h/月の検証、CSPM は既定 OFF です。No.8 と No.12 は常時／検証日の切替で、二重計上しません。No.6 は 第1章/第6章の共通費です。見積り保証ではありません。

## 3.8. 本番との差・IaC で再現する (任意)

本番では負荷・復旧要件に合わせて Search S1、Provisioned Cosmos 3000 RU/s、Storage GRS と閉域接続を設計します。[付録 B](92-appendix-production-diff.md) を参照します。

[04_data.bicep](../infra/modules/04_data.bicep) は目標設定の参考です。GUI 作成済みの環境へ main.bicep を重ねて別リソースを作りません。

### 出典

- 出典: [Foundry の RBAC](https://learn.microsoft.com/ja-jp/azure/foundry/concepts/rbac-foundry)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Key Vault を portal で作成](https://learn.microsoft.com/ja-jp/azure/key-vault/general/quick-create-portal)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Azure ロールの割当](https://learn.microsoft.com/ja-jp/azure/role-based-access-control/role-assignments-portal)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Key Vault の RBAC](https://learn.microsoft.com/ja-jp/azure/key-vault/general/rbac-guide)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Key Vault のネットワーク](https://learn.microsoft.com/ja-jp/azure/key-vault/general/network-security)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Key Vault の論理削除](https://learn.microsoft.com/ja-jp/azure/key-vault/general/soft-delete-overview)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Standard setup](https://learn.microsoft.com/ja-jp/azure/foundry/agents/concepts/standard-agent-setup)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [BYO リソース](https://learn.microsoft.com/ja-jp/azure/foundry/agents/how-to/use-your-own-resources)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Search のロール認証](https://learn.microsoft.com/ja-jp/azure/search/search-security-enable-roles)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Storage 共有キーの無効化](https://learn.microsoft.com/ja-jp/azure/storage/common/shared-key-authorization-prevent)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Cosmos DB の RBAC とキー無効化](https://learn.microsoft.com/ja-jp/azure/cosmos-db/nosql/how-to-connect-role-based-access-control)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Foundry Tools のローカル認証無効化](https://learn.microsoft.com/ja-jp/azure/ai-services/disable-local-auth)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [条件付きアクセスの適用ログ](https://learn.microsoft.com/ja-jp/entra/identity/monitoring-health/how-to-view-applied-conditional-access-policies)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [継続的アクセス評価](https://learn.microsoft.com/ja-jp/entra/identity/conditional-access/concept-continuous-access-evaluation)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Easy Auth の OAuth トークン](https://learn.microsoft.com/ja-jp/azure/app-service/configure-authentication-oauth-tokens)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [APIM の Managed Identity 認証](https://learn.microsoft.com/ja-jp/azure/api-management/authentication-managed-identity-policy)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [az keyvault](https://learn.microsoft.com/ja-jp/cli/azure/keyvault)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [az role assignment](https://learn.microsoft.com/ja-jp/cli/azure/role/assignment)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [az resource](https://learn.microsoft.com/ja-jp/cli/azure/resource)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [公式テンプレート 41（固定コミット）](https://github.com/microsoft-foundry/foundry-samples/tree/58e4127567f7e9afcf0145d874df890284ca5faf/infrastructure/infrastructure-setup-bicep/41-standard-agent-setup)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Cosmos DB IP 制御](https://learn.microsoft.com/ja-jp/azure/cosmos-db/how-to-configure-firewall)（取得日 2026-09-15）

---

前へ: [Key Vault を準備する](02-key-vault.md) / 次へ: [Foundry とエージェントを作る](04-foundry-agent.md) / [トップに戻る](../README.md)
