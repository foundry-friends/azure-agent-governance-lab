# 5. 人とサービスの権限を設定する

進め方: README の第0〜10章を順番に実施します。第4章の完了条件を満たしてから進めます。

> **Note** 状態: 手順ドラフト（Azure 未実行）。構成変更日 2026-09-15。

> **補足** この章では環境を削除しません。通常の削除は最後の第10章です。中断して片付ける場合だけ、第10章へ進みます。

## 5.1. 目的

作成済みのエージェントに対して、開発者と呼び出し専用ユーザーの権限を設定します。構築時に付いたサービスの ID とロールも照合します。

## 5.2. 前提

エージェントの初回応答を確認済みで、第0章で選んだ試験ユーザーを使います。

## 5.3. 設定

### 人のロールを割り当てる

| ロール | 用途 | 旧名・補足 |
|---|---|---|
| Foundry Account Owner | account／project の管理 | 旧 Azure AI Account Owner。開発・呼び出し権限を兼ねるとは限りません |
| Foundry User | エージェントの作成・編集・テスト | 旧 Azure AI User |
| Foundry Agent Consumer | エージェントの呼び出し | 管理画面閲覧・作成・編集の権限は含みません |
| Foundry Project Manager | project 管理・公開など | 旧 Azure AI Project Manager。今回の利用者試験には付けません |

1. 第4章で作成した対象 project の Azure リソースを開きます。
2. [アクセス制御 (IAM)] を選択します。
3. [追加] から [ロールの割り当ての追加] を選択します。
4. 対象ロールを検索して選択します。
5. [メンバー] で [ユーザー、グループ、またはサービス プリンシパル] を選択します。
6. [メンバーを選択する] で対象の検証用ユーザーを選択します。
7. [レビューと割り当て] でロール・対象・スコープを確認します。
8. 割当を確定します。
9. 開発用と呼び出し用のユーザーについて同じ手順を繰り返します。
10. [アクセス権の確認] で各主体の継承された割当も確認します。

> **Note** 要確認: project の IAM への導線とロールの日本語表記は 初回 で照合します。対象 project が選べないときにサブスクリプションへ割当範囲を拡大しません。ロールの旧名が表示される場合は公式定義との対応を確認します。

11. Cloud Shell で主体ごとの割当を照合します。

```bash
az role assignment list --assignee "<test-user-object-id>" --scope "<project-resource-id>" --include-inherited --include-groups --output table
```
実行結果の確認ポイント: 対象ロールと project スコープが一致し、上位スコープやグループ経由の追加権限がないことを確認します。Graph の照会権限不足は「割当なし」と扱いません。

### サービスが使う ID を照合する

固定した公式テンプレート 41 は account と project にそれぞれ system-assigned Managed Identity を作ります。人の ID と区別して記録します。

1. Azure portal で対象 account のリソース ID を確認します。
2. 対象 project のリソース ID を確認します。
3. 各 ID を次のコマンドに指定して照合します。

```bash
az resource show --ids "<account-or-project-resource-id>" --query '{id:id,identity:identity}' --output json
```
実行結果の確認ポイント: account と project ごとに `identity.type` と `principalId` を記録します。ID が取得できない場合は同一主体と推測せず Pending にします。

4. 接続先の [アクセス制御 (IAM)] で project の主体に対する割当を確認します。

| 接続先 | 固定テンプレート 41 の照合対象 | 留意点 |
|---|---|---|
| Storage | project の Storage Blob Data Contributor | 作成済みのコンテナー側の割当も照合 |
| Search | project の Search Service Contributor／Search Index Data Contributor | 人の Foundry User とは別の割当 |
| Cosmos DB | project の Cosmos DB Operator とデータ側の割当 | Operator だけでデータアクセスを保証しません |
| Foundry account | project の Foundry User | GUI 作成時の自動割当は作成者の権限に依存 |
| Key Vault | この検証で必要になった主体だけ | 41 が自動で接続・割当する前提にしません |

> **Note** 要確認: GUI 構築の実際の割当と固定テンプレートの期待値を、この章で比較します。Cosmos DB のデータ権限は Azure IAM の一覧だけでは判定できません。公開後に別の agent identity がある場合も、その主体と接続先を別途記録します。

## 5.4. 完了条件

ユーザーと MI ごとに、割当先・ロール・継承を記録できたら次へ進みます。この章の完了条件は設定の確認です。呼び出し用アプリを作る前に C02 の動作試験を要求しません。

## 5.5. うまくいかない場合

| 症状 | 切り分け → 代替 | 記録 → 元に戻す |
|---|---|---|
| ロールを割り当てられない | 対象スコープと割当権限を確認し、部門管理者へ依頼 | 必要スコープを記録。上位スコープへ広げない |
| Consumer が画面を開けない | 管理面の閲覧権限の有無を記録する。呼び出し試験は第8章で実施 | 画面と API の結果を別記。閲覧のために User を追加しない |
| 権限付与後も拒否される | 反映待ち・再サインイン後、対象 ID とスコープを再確認 | 待機と再試行時刻を記録。追加した試験用割当だけを戻す |
| Key Vault のデータ操作が拒否される | 社内 IP か、データ用ロールがあるかを確認 | ネットワークと認可を区別。切り分けのための全面公開は行わない |
| 無権限ユーザーが成功する | グループ・上位スコープ・アプリ共通 MI・キー認証を確認 | C02 は Fail。今回追加した誤った割当のみ削除し、既存権限は管理者へ照会 |
| MI が見つからない | account と project の取り違え、作成完了、表示権限を確認 | 作成済みリソースの ID を再照合。再生成を目的に ID をオフ／オンしない |

> **Note** 要確認: 初回で実際のエラーと復旧結果を追記します。BYO データへの到達失敗は接続時の記録と照合し、第5章の権限追加だけで解決したと推測しません。

## 5.6. 次の操作

設定を維持して第6章へ進みます。統制の動作試験は第8章にまとめています。

## 5.7. 費用

基本の Managed Identity・RBAC は既存見積りの No.9 です。新しいライセンスを追加する手順ではありません。

## 5.8. 本番との差

職務分離と ID のライフサイクルを設計します。

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

---

前へ: [Foundry とエージェントを作る](04-foundry-agent.md) / 次へ: [監視と監査を設定する](06-monitoring.md) / [トップに戻る](../README.md)
