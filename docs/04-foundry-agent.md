# 4. Foundry とエージェントを作る

進め方: README の第0〜10章を順番に実施します。第3章の完了条件を満たしてから進めます。

> **Note** 状態: 構成ドラフト・操作の詳細は未確定（Azure 未実行）。構成変更日 2026-09-15。

> **補足** この章では環境を削除しません。通常の削除は最後の第10章です。中断して片付ける場合だけ、第10章へ進みます。

## 4.1. 目的

作成済みのデータ基盤に接続する Foundry account／project と prompt agent を作り、最初の応答を確認します。

## 4.2. 前提

第3章の3リソースが存在し、ARM ID・認証・IP 制限を記録済みです。構築担当は account/project の作成、サービス接続用ロールの割当、エージェント作成に必要な権限を持ちます。

## 4.3. 構築

### account・project・モデルとデータ接続

> **Note** 要確認: GUI による Standard setup の作成・BYO 接続・capability host・初期の IP 制限と認証設定は手順を確定できていません。次の表は執筆すべき工程です。この依存を解消するまで、この章の構築は停止します。

| 順番 | この章で完了させる操作 | 出力 |
|---|---|---|
| 1 | Foundry account と project を作成し、作成時の IP 制限・Entra 認証を確保 | account/project の ID |
| 2 | 承認モデルを配置 | モデル配置名 |
| 3 | project の MI に接続先の必要ロールを割当 | Storage/Search/Cosmos の実効権限 |
| 4 | 第3章の3 IDを使う BYO 接続と capability host を作成 | 接続成功と接続先の一致 |
| 5 | 構築担当の Foundry User 相当の開発権限を確認 | エージェントを作成できる主体 |

> **補足** この接続用の権限割当は構築の一部です。第5章で行う利用者ごとの最小権限の設定と区別します。第5章の作業を先取りして戻る必要はありません。

### account の認証・IP・ID を確認する

| 項目 | 期待する値 |
|---|---|
| `publicNetworkAccess` | `Enabled` |
| `disableLocalAuth` | `true` |
| `networkAcls.defaultAction` | `Deny` |
| `networkAcls.ipRules` | 社内公開 IP の許可リスト |
| `networkAcls.bypass` | 既存目標は `None`。サービス経路への適用は要確認 |

作成した account の ARM ID を `.env` の `FOUNDRY_ACCOUNT_RESOURCE_ID` に記録します。project の ID と接続先3 IDも非公開記録に残します。

> **Note** 要確認: Foundry Tools の認証設定資料だけでは、この account を GUI で制限付き作成する導線は確定しません。上表の設定を確保できる手順を確定してから、以下のエージェント作成へ進みます。

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
| ツール | この章では追加なし |

```text
合成データだけを扱う検証用アシスタントです。登録した許可済みツール以外を使わず、不明な内容は不明と回答してください。
```
実行結果の確認ポイント: 指示を権限制御の代わりにせず、ツールと RBAC の設定も確認します。

> **画面の見え方** 上記は操作のドラフトです。新ランタイムの画面名・入力欄は（初回で記入）です。

### モデル向けガードレールを確認する

1. モデル配置の [コンテンツ フィルター] で適用する RAI ポリシーを確認します。
2. [合成プロンプト](../assets/prompts/README.md) の正常入力と拒否入力を試します。
3. 適用設定と実結果を別々に記録します。

> **Note** 要確認: UI・適用プロパティと GA 範囲を確認します。エージェント guardrails の Preview 介入点、Tool call / Tool response、Task Adherence は対象外で GA 後に追記します。hosted 固有の fail open 再現は付録 A の骨子です。

## 4.4. 完了条件

C01として capability host、3つの接続先、Entra IDによる合成入力の1往復を確認します。Key Vault は独立した監査用リソースであり、自動接続されたとは扱いません。最初の応答が確認できたら次へ進みます。

後続章では、このエージェントを作り直さずに使います。利用者の権限差とネットワークの拒否試験は第8章で初めて実施します。

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

> **Note** 要確認: UI 名・反映時間・例外の適用を確認します。ここではまだ Policy の Deny を設定していません。既存の組織 Policy が変更を拒否する場合は管理者に確認します。

> **補足** この代替手順は N2 の例外です。ネットワーク制限を外した事実を記録し、本番では Private Endpoint が必要な差分として [付録 B](92-appendix-production-diff.md) に引き継ぎます。Foundry・Key Vault・APIM・App Service を一括で公開には戻しません。

### それ以外の失敗

（初回で記入）

1. モデル版とクォータを確認します。
2. capability host の失敗時は RBAC と到達を切り分けます。
3. 作成後の host 更新可否を推測せず、再作成の要否を確認します。

## 4.6. 次の操作

エージェントを残して第5章へ進みます。

## 4.7. 費用

| Excel v3 明細 No | 項目 | 通常月 USD |
|---|---|---:|
| 1 | Microsoft Foundry リソース / project / prompt agent | 0.000000 |
| 14 | gpt-5 mini / Global Standard 入力 | 9.000000 |
| 15 | gpt-5 mini / Global Standard 出力 | 10.800000 |
| 16 | Content Safety / Standard テキストレコード | 7.500000 |

2026-09-15 の見積り v3 の既定値です。Japan East、原則 32h/月の検証、CSPM は既定 OFF です。No.8 と No.12 は常時／検証日の切替で、二重計上しません。No.6 は 第1章/第6章の共通費です。見積り保証ではありません。

## 4.8. 本番との差・IaC で再現する (任意)

本番ではモデル変更管理と可用性を設計します。[付録 B](92-appendix-production-diff.md) を参照します。

固定した [公式テンプレートの説明](../infra/PINNED_COMMIT.md) と [IaC の停止条件](../infra/README.md) は参考資料です。GUI で作成済みのリソースを含めて一式を再展開しません。旧 CLI 主線の後追い変更を GUI 手順の代用として実行しません。Preview API を含むテンプレートの扱いは未解決のため、固定停止点を維持します。

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
- 出典: [環境セットアップ](https://learn.microsoft.com/ja-jp/azure/foundry/agents/environment-setup)（取得日 2026-09-15）

---

前へ: [データ基盤を作る](03-data.md) / 次へ: [人とサービスの権限を設定する](05-identity.md) / [トップに戻る](../README.md)
