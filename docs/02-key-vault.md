# 2. Key Vault を準備する

進め方: README の第0〜10章を順番に実施します。第1章の完了条件を満たしてから進めます。

> **Note** 状態: 手順ドラフト（Azure 未実行）。構成変更日 2026-09-15。

> **補足** この章では環境を削除しません。通常の削除は最後の第10章です。中断して片付ける場合だけ、第10章へ進みます。

## 2.1. 目的

RBAC と監査の検証に使う Key Vault を用意します。この章では Foundry の作成や利用者ロール割当は行いません。

### なぜこの作業が必要か

Key Vault は、パスワードや API キーなどの秘密情報をアプリのコードから分離して保管し、アクセスできる主体を制御するサービスです。一般的な用途は、秘密情報を必要な人やサービスだけに渡し、その利用を追跡できるようにすることです。[Microsoft Learn の概要](https://learn.microsoft.com/ja-jp/azure/key-vault/general/overview)で役割を確認できます。

**今回のラボで用意する理由は、秘密情報を守るリソースの権限設定と監査を学ぶためです。** 本手順では実際のキーや接続文字列を保存せず、独立した RBAC・監査の検証対象として扱います。第5章で必要な主体の権限を確認し、第6章で診断ログの設定につなげます。Vault を作成しただけでは、データへのアクセス制御や監査が検証できたことにはなりません。

この Vault は、現在の構成で Foundry エージェントの必須接続先として使うものではありません。エージェントの接続用シークレットを保管するために必須、という意味ではなく、今回のガバナンス学習の対象として準備します。

## 2.2. 前提

専用 RG、タグ、社内 IP、Cloud Shell の準備が完了しています。

## 2.3. 構築

### Key Vault を作成する

1. Azure portal の [リソースの作成] を選択します。
2. 検索欄に `Key Vault` を入力します。
3. 検索結果の [Key Vault] を選択します。
4. [作成] を選択します。
5. 基本情報に次の値を入力します。

| 項目 | 値 |
|---|---|
| サブスクリプション | 第1章の検証用サブスクリプション |
| リソース グループ | `rg-agentgov-<operator-code>-run<N>` |
| 名前 | `<key-vault-name>`（一意な名前を用意） |
| 場所 | Japan East |
| 価格レベル | Standard |
| 論理的な削除の保持期間 | 7 日（既存の検証用 module と同じ） |
| 消去保護 | 検証用 module は明示有効化なし。組織の必須設定があれば従います |

6. アクセス許可モデルに [Azure ロールベースのアクセス制御] を選択します。
7. ネットワークのアクセス元を、特定の仮想ネットワークと IP アドレスからのパブリックアクセスに限定します。
8. 許可する IPv4／CIDR に管理者から受け取った社内公開 IP を入力します。
9. 信頼された Microsoft サービスのバイパスを有効にします。
10. 第1章 と同じ用途・実施者・Run・削除予定日のタグを設定します。
11. [確認および作成] で設定を照合します。
12. [作成] を選択します。

> **Note** 要確認: 作成ウィザード内のタブ名・ネットワーク選択肢・回復オプションの配置は実画面で照合します。ネットワーク制限を作成時に設定できない場合は作成を保留し、差分を記録します。無制限公開を前提に進めません。

> **補足** Key Vault は本ラボの RBAC・監査の検証対象です。Foundry が自動でこの Vault を利用するとは限らず、キーや接続文字列は保存しません。信頼されたサービスの例外は Azure 全体の許可ではなく、すべての Managed Identity の通信を通す仕組みでもありません。

13. 作成した Vault の [ネットワーク] で社内 IP と例外を確認します。
14. アクセス許可モデルが RBAC になっていることを確認します。
15. Cloud Shell で設定を照合します。

```bash
az keyvault show --name "<key-vault-name>" --resource-group "<resource-group-name>" --query '{rbac:properties.enableRbacAuthorization,publicAccess:properties.publicNetworkAccess,network:properties.networkAcls,retention:properties.softDeleteRetentionInDays,purgeProtection:properties.enablePurgeProtection}' --output json
```
実行結果の確認ポイント: `rbac=true`、`publicAccess=Enabled`、`defaultAction=Deny`、社内 IP、`bypass=AzureServices`、保持 7 日を確認し、消去保護の実値も記録します。

> **補足** これは管理面の設定確認です。シークレットを読めることの証明にはなりません。消去保護を有効にした Vault は後で無効にできず、保持期間中は完全削除できません。

## 2.4. 完了条件

Vault が存在し、RBAC 認可・社内 IP・論理削除の保持設定を確認できたら次へ進みます。まだエージェントの呼び出し試験は行いません。

## 2.5. うまくいかない場合

RBAC の管理権限とデータ閲覧権限を区別します。ネットワーク制限を作成時に設定できない場合は作成を保留し、画面の差分を記録します。

## 2.6. 次の操作

Vault を残したまま第3章へ進みます。

## 2.7. 費用

| Excel v3 明細 No | 項目 | 通常月 USD |
|---|---|---:|
| 5 | Key Vault / Standard 操作 | 0.030000 |
| 9 | Entra ID / Managed Identity / RBAC / 基本機能 | 0.000000 |

[README の費用の目安](../README.md) にある 2026-09-15 の見積り v3 の既定値です。Japan East、原則 32h/月の検証を前提とし、実利用額の保証ではありません。既存の Entra 条件付きアクセスに必要なライセンスを無料とする意味ではありません。

## 2.8. 本番との差・任意の再現

本番では職務分離と ID のライフサイクル、Key Vault の消去保護と復旧を設計します。本ラボで扱わない閉域・WAF 等との差は [付録 B](92-appendix-production-diff.md) を参照します。

### IaC で再現する (任意)

[02_keyvault.bicep](../infra/modules/02_keyvault.bicep) が再現用の設定です。`location`、`prefix`、`allowedIpRanges`、`tags` を GUI の記録と照合します。GUI で作成済みの場合、異なる名前の Vault を追加しないようにします。現在の [main.bicep](../infra/main.bicep) は Key Vault の既存 ID を受け取る構成ではないため、GUI 構築後に一式を重ねて展開しません。実行条件は [IaC の説明](../infra/README.md) に従います。

### 出典

- 出典: [Key Vault の役割と利用理由](https://learn.microsoft.com/ja-jp/azure/key-vault/general/overview)（取得日 2026-09-15）

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

---

前へ: [準備と土台](01-prerequisites.md) / 次へ: [データ基盤を作る](03-data.md) / [トップに戻る](../README.md)
