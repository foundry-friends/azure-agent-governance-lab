# 2. ID と権限

このセクションを使う Run: Run 1／Run 2。先に要るセクション: S1。Foundry の権限割当と呼び出し試験は S5 の構築後に戻って実施します。

> **Note** 状態: ドラフト（Learn 2026-09 時点の記述に基づく・未実行）

> **Note** 作成・変更は Azure portal（日本語）、確認コマンドは Azure Cloud Shell（Bash）で実施します。データへのアクセス試験は社内 IP のブラウザから行います。

## 2.1. 目的

「誰が環境を作るか」「誰がエージェントを使うか」「エージェントがどの ID でデータを読むか」を分けます。Managed Identity（Azure リソースに付く ID）、RBAC（役割に基づくアクセス制御）、Key Vault の認可設定を確認し、キー認証に依存しない構成を準備します。

管理用の Owner で成功するだけでは、利用者の最小権限を検証できません。C02 は主体別の操作結果、C03 は認証設定と呼び出し結果を分けて記録します。

## 2.2. 前提

### 実施する順番

| 時点 | このページで行うこと | 完了の目安 |
|---|---|---|
| S1 の直後 | 検証主体の選定、既存の条件付きアクセス確認、Key Vault 作成 | 土台の準備。C02／C03 全体は Pending |
| S4 の作成時 | データ基盤のローカル認証無効化 | 各リソースの設定を記録 |
| S5 の構築後 | account／project の ID 照合、利用者ロール割当、Foundry 認証設定確認 | 実際に可能な C02／C03 の試験を実施 |
| S7 のアプリ準備後 | 利用者本人のトークンで呼び出し試験 | 残っていた試験を実施し、結果で判定 |

1. [S1](01-prerequisites.md) で作成した自分専用の RG を確認します。
2. S1 の権限表で、実施者が対象スコープのロール割当を行えることを確認します。
3. 検証チーム内で、次のテスト主体を選びます。

| 主体 | 役割 | 注意点 |
|---|---|---|
| 構築担当 | リソース作成・ロール割当 | 最小権限試験の主体にはしません |
| 開発用ユーザー | Foundry User | 対象 project に限定します |
| 呼び出し用ユーザー | Foundry Agent Consumer | エージェントとの対話専用です |
| 無権限ユーザー | 対象へのロール割当なし | サインイン可能な検証用ユーザーを使います |

> **Note** 要確認: 検証用ユーザーの手配と既存のグループ／上位スコープからの継承は、部門管理者と確認します。適切な主体を用意できなければ C02 を Pending にします。既存の管理者権限を削除して試験用ユーザーに作り替えません。

### 既存の Entra 条件付きアクセスを確認する

1. Microsoft Entra 管理センターで対象テナントを開きます。
2. [監視と正常性] のサインインログを開きます。
3. 検証用ユーザーの該当サインインを選択します。
4. [条件付きアクセス] で適用ポリシーと結果を確認します。
5. ポリシーの対象リソース、対象ユーザー、許可する場所を管理者と照合します。
6. 確認結果を非公開の `evidence/` に記録します。

> **Note** 要確認: メニューの日本語表記は Run 0 の画面で照合します。ログとポリシーの閲覧には Entra 側の権限が必要です。Azure RG の Owner だけで閲覧できるとは限りません。閲覧できなければ管理者に確認を依頼します。

> **補足** 既存ポリシーは変更しません。CAE（継続的アクセス評価）は対象サービスとクライアントに依存します。サインイン成功だけで Foundry のトークン失効やリソース側の IP 制限を確認したとは扱いません。C08 は [S3](10-network-boundary.md) の別試験です。

## 2.3. 構築

### Key Vault を作成する（S1 の直後）

1. Azure portal の [リソースの作成] を選択します。
2. 検索欄に `Key Vault` を入力します。
3. 検索結果の [Key Vault] を選択します。
4. [作成] を選択します。
5. 基本情報に次の値を入力します。

| 項目 | 値 |
|---|---|
| サブスクリプション | S1 の検証用サブスクリプション |
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
10. S1 と同じ用途・実施者・Run・削除予定日のタグを設定します。
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

### 人のロールを割り当てる（S5 の構築後）

| ロール | 用途 | 旧名・補足 |
|---|---|---|
| Foundry Account Owner | account／project の管理 | 旧 Azure AI Account Owner。開発・呼び出し権限を兼ねるとは限りません |
| Foundry User | エージェントの作成・編集・テスト | 旧 Azure AI User |
| Foundry Agent Consumer | エージェントの呼び出し | 管理画面閲覧・作成・編集の権限は含みません |
| Foundry Project Manager | project 管理・公開など | 旧 Azure AI Project Manager。今回の利用者試験には付けません |

1. S5 で作成した対象 project の Azure リソースを開きます。
2. [アクセス制御 (IAM)] を選択します。
3. [追加] から [ロールの割り当ての追加] を選択します。
4. 対象ロールを検索して選択します。
5. [メンバー] で [ユーザー、グループ、またはサービス プリンシパル] を選択します。
6. [メンバーを選択する] で対象の検証用ユーザーを選択します。
7. [レビューと割り当て] でロール・対象・スコープを確認します。
8. 割当を確定します。
9. 開発用と呼び出し用のユーザーについて同じ手順を繰り返します。
10. [アクセス権の確認] で各主体の継承された割当も確認します。

> **Note** 要確認: project の IAM への導線とロールの日本語表記は Run 1 で照合します。対象 project が選べないときにサブスクリプションへ割当範囲を拡大しません。ロールの旧名が表示される場合は公式定義との対応を確認します。

11. Cloud Shell で主体ごとの割当を照合します。

```bash
az role assignment list --assignee "<test-user-object-id>" --scope "<project-resource-id>" --include-inherited --include-groups --output table
```
実行結果の確認ポイント: 対象ロールと project スコープが一致し、上位スコープやグループ経由の追加権限がないことを確認します。Graph の照会権限不足は「割当なし」と扱いません。

### サービスが使う ID を照合する（S5 の構築後）

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
| Storage | project の Storage Blob Data Contributor | コンテナー側の割当も S4／S5 で確認 |
| Search | project の Search Service Contributor／Search Index Data Contributor | 人の Foundry User とは別の割当 |
| Cosmos DB | project の Cosmos DB Operator とデータ側の割当 | Operator だけでデータアクセスを保証しません |
| Foundry account | project の Foundry User | GUI 作成時の自動割当は作成者の権限に依存 |
| Key Vault | この検証で必要になった主体だけ | 41 が自動で接続・割当する前提にしません |

> **Note** 要確認: GUI 構築と固定テンプレートの自動割当が同じかは S5 で比較します。Cosmos DB のデータ権限は Azure IAM の一覧だけでは判定できません。公開後に別の agent identity がある場合も、その主体と接続先を別途記録します。

### キー認証を無効にする（S4／S5 で対象作成後）

対象は自分の Run 用リソースのみです。既存の Cloud Shell 用 Storage は変更しません。

| 対象 | GUI での設定 | 設定確認の期待値 |
|---|---|---|
| Storage（S4） | [設定] → [構成] → [ストレージ アカウント キーのアクセスを許可する] を [無効] | `allowSharedKeyAccess=false` |
| Search（S4） | [キー] → [ロールベースのアクセス制御] | `disableLocalAuth=true` |
| Cosmos DB for NoSQL（S4） | 新規作成の [セキュリティ] → [キーベースの認証] を [無効] | `disableLocalAuth=true` |
| Foundry account（S5） | 下記の未確定点を確認してから設定 | `disableLocalAuth=true` |

1. 対象の設定画面を開きます。
2. 上表の値を選択します。
3. 保存操作がある画面では [保存] を選択します。
4. 管理面のプロパティを照合します。

```bash
az resource show --ids "<target-resource-id>" --query '{type:type,disableLocalAuth:properties.disableLocalAuth,allowSharedKeyAccess:properties.allowSharedKeyAccess}' --output json
```
実行結果の確認ポイント: 対象種別に対応する上表のプロパティが期待値になっていることを確認します。期待するプロパティが `null` なら無効化済みと判定しません。

> **Note** 要確認: Foundry Tools の公式資料は `disableLocalAuth` と Policy／ARM による設定を説明していますが、今回の Foundry account の GUI 導線までは確認できていません。S5 で GUI と GA の変更手段を確定するまで Foundry の C03 設定確認を Pending にします。未確認の CLI 変更手順を代用として実行しません。

> **補足** キーの表示・取得・コピーは行いません。無効設定が存在することと、実キーによる拒否が確認できたことは別です。エージェントの Entra ID 呼び出し成功だけで、account 配下のキー利用可能な機能がすべて無効になったとも判定しません。

### S7 の呼び出しアプリへ引き継ぐ認証要件

S7 のアプリは次の条件を満たすように設計します。この段階ではアプリ登録や全社設定を変更しません。

| 経路 | S7 で確定すること |
|---|---|
| ブラウザ → アプリ | Easy Auth のサインイン主体、対象テナント、未認証時の拒否 |
| アプリ → APIM → Foundry | ユーザーの委任トークンで呼ぶ経路と、サービスの MI で呼ぶ経路の区別 |
| C02 の利用者試験 | Foundry がテストユーザー本人を認可すること。全員を同じ MI に置き換えないこと |
| トークン取得 | Foundry が要求する audience／scope、同意、転送または OBO の必要性 |
| 証跡 | 主体・対象・成功／拒否・拒否した層を記録し、トークン本文は保存しないこと |

> **補足** Easy Auth でログインできても下流 API 用トークンの取得は別設定です。APIM の `authentication-managed-identity` は APIM の ID で下流トークンを取得するため、その経路だけでは利用者本人の Foundry RBAC を検証できません。

> **Note** 要確認: 利用者の委任認証を保った呼び出しアプリは未実装です。Consumer の管理画面アクセス失敗を呼び出し拒否と取り違えず、実行経路ができるまで対応する C02／C03 は Pending とします。

## 2.4. 確認

### C02：主体別に同じ操作を比較する

1. 管理者と別のブラウザプロファイルで検証用ユーザーにサインインします。
2. S5 の同じエージェントに、合成入力「検証です。こんにちはと答えてください」を送ります。
3. S5 の作成操作を使って検証用エージェントの新規作成を試します。
4. 作成できた検証用エージェントの指示に「短く答えてください」を追加して保存を試します。
5. 各操作の実結果を下表と比較します。

| 主体 | 呼び出し | 作成・編集 | 判定上の注意 |
|---|---|---|---|
| Foundry User | 成功 | 成功 | モデルのデプロイや公開の権限とは別 |
| Foundry Agent Consumer | 成功 | 拒否 | 呼び出しは本人トークンを使うアプリ経路で確認 |
| 無権限ユーザー | 拒否 | 拒否 | サインイン／IP 拒否だけなら RBAC 試験は Pending |

画面に作成ボタンがない場合は「GUI 操作不可」と記録します。バックエンドの作成・編集拒否は、その操作を送れる検証経路がない限り Pending にします。別主体で作ったエージェントを編集できるかは所有関係も影響するため、新規作成と分けて記録します。

### C03：設定・認証成功・未認証拒否を分ける

| 試験 | 期待 | 実施できない場合 |
|---|---|---|
| 対象ごとの設定照合 | 2.3 の無効設定と一致 | 対象作成前／設定手段未確定は Pending |
| Entra ID による呼び出し | 権限ありの主体で成功 | S5／S7 の経路待ちは Pending |
| 認証情報なしの呼び出し | 対象エンドポイントで拒否 | アプリのログイン画面だけ確認した場合は Foundry の試験は Pending |

認証なし試験は S7 で確定する同一操作・同一エンドポイントの検証経路を使います。URL をブラウザで開いた結果だけでは、認証拒否と HTTP メソッド違いを区別できません。キーを使った拒否試験は本手順に含めません。

S5 の構築後、Cloud Shell の `.env` に検証対象の `AZURE_SUBSCRIPTION_ID`、`AZURE_TENANT_ID`、`AZURE_RESOURCE_GROUP`、`FOUNDRY_ACCOUNT_RESOURCE_ID` を設定してから実行します。

```bash
bash scripts/verify.sh --section 2
```
実行結果の確認ポイント: account スコープのロールと認証設定を収集し、未実施の試験を Pending と表示します。設定不足や照会失敗はエラーになり、設定収集完了時の終了コード 2 も試験合格を意味しません。

[確認項目](../checks/README.md) ごとに、Run・手順番号・主体の区別・入力・期待・実結果・拒否した層・Pass／Fail／Pending を非公開の `evidence/` に記録します。未実施行を残したまま C02／C03 全体を Pass にしません。

## 2.5. うまくいかない場合

| 症状 | 切り分け → 代替 | 記録 → 元に戻す |
|---|---|---|
| ロールを割り当てられない | 対象スコープと割当権限を確認し、部門管理者へ依頼 | 必要スコープを記録。上位スコープへ広げない |
| Consumer が画面を開けない | 管理面の閲覧権限と呼び出し権限を分離し、S7 の本人トークン経路で試す | 画面と API の結果を別記。閲覧のために User を追加しない |
| 権限付与後も拒否される | 反映待ち・再サインイン後、対象 ID とスコープを再確認 | 待機と再試行時刻を記録。追加した試験用割当だけを戻す |
| Key Vault のデータ操作が拒否される | 社内 IP か、データ用ロールがあるかを確認 | ネットワークと認可を区別。切り分けのための全面公開は行わない |
| 無権限ユーザーが成功する | グループ・上位スコープ・アプリ共通 MI・キー認証を確認 | C02 は Fail。今回追加した誤った割当のみ削除し、既存権限は管理者へ照会 |
| MI が見つからない | account と project の取り違え、作成完了、表示権限を確認 | S5 へ戻り確認。再生成を目的に ID をオフ／オンしない |

> **Note** 要確認: Run 1 初回で実際のエラーと復旧結果を追記します。BYO データへの到達失敗は [S4](11-data.md) で扱い、S2 の権限追加だけで解決したと推測しません。

## 2.6. 削除

1. テストのために追加したロール割当を一覧にします。
2. 対象リソースの [アクセス制御 (IAM)] で今回の試験用割当を選択します。
3. 共有環境の既存割当でないことを確認します。
4. [削除] を選択します。
5. [S9](90-cleanup-cost.md) に従って自分の Run 用 RG を削除します。
6. Key Vault の論理削除残存と消去保護の設定を確認します。

Vault の削除直後は同名を再利用できない場合があります。完全削除は保持・組織方針・権限を確認して S9 で扱います。検証に使った既存のユーザーやグループは削除しません。

## 2.7. 費用

| Excel v3 明細 No | 項目 | 通常月 USD |
|---|---|---:|
| 5 | Key Vault / Standard 操作 | 0.030000 |
| 9 | Entra ID / Managed Identity / RBAC / 基本機能 | 0.000000 |

[README の費用の目安](../README.md) にある 2026-09-15 の見積り v3 の既定値です。Japan East、原則 32h/月の検証を前提とし、実利用額の保証ではありません。既存の Entra 条件付きアクセスに必要なライセンスを無料とする意味ではありません。

## 2.8. 本番との差

本番では職務分離と ID のライフサイクル、Key Vault の消去保護と復旧を設計します。本ラボで扱わない閉域・WAF 等との差は [付録 B](92-appendix-production-diff.md) を参照します。

### IaC で再現する (任意)

[02_keyvault.bicep](../infra/modules/02_keyvault.bicep) が再現用の設定です。`location`、`prefix`、`allowedIpRanges`、`tags` を GUI の記録と照合します。GUI で作成済みの場合、異なる名前の Vault を追加しないようにします。現在の [main.bicep](../infra/main.bicep) は Key Vault の既存 ID を受け取る構成ではないため、GUI 構築後に一式を重ねて展開しません。実行条件は [IaC の説明](../infra/README.md) に従います。

### 出典

- 出典: [Foundry の RBAC](https://learn.microsoft.com/ja-jp/azure/foundry/concepts/rbac-foundry)（取得日 2026-09-15）
- 出典: [Key Vault を portal で作成](https://learn.microsoft.com/ja-jp/azure/key-vault/general/quick-create-portal)（取得日 2026-09-15）
- 出典: [Azure ロールの割当](https://learn.microsoft.com/ja-jp/azure/role-based-access-control/role-assignments-portal)（取得日 2026-09-15）
- 出典: [Key Vault の RBAC](https://learn.microsoft.com/ja-jp/azure/key-vault/general/rbac-guide)（取得日 2026-09-15）
- 出典: [Key Vault のネットワーク](https://learn.microsoft.com/ja-jp/azure/key-vault/general/network-security)（取得日 2026-09-15）
- 出典: [Key Vault の論理削除](https://learn.microsoft.com/ja-jp/azure/key-vault/general/soft-delete-overview)（取得日 2026-09-15）
- 出典: [Standard setup](https://learn.microsoft.com/ja-jp/azure/foundry/agents/concepts/standard-agent-setup)（取得日 2026-09-15）
- 出典: [BYO リソース](https://learn.microsoft.com/ja-jp/azure/foundry/agents/how-to/use-your-own-resources)（取得日 2026-09-15）
- 出典: [Search のロール認証](https://learn.microsoft.com/ja-jp/azure/search/search-security-enable-roles)（取得日 2026-09-15）
- 出典: [Storage 共有キーの無効化](https://learn.microsoft.com/ja-jp/azure/storage/common/shared-key-authorization-prevent)（取得日 2026-09-15）
- 出典: [Cosmos DB の RBAC とキー無効化](https://learn.microsoft.com/ja-jp/azure/cosmos-db/nosql/how-to-connect-role-based-access-control)（取得日 2026-09-15）
- 出典: [Foundry Tools のローカル認証無効化](https://learn.microsoft.com/ja-jp/azure/ai-services/disable-local-auth)（取得日 2026-09-15）
- 出典: [条件付きアクセスの適用ログ](https://learn.microsoft.com/ja-jp/entra/identity/monitoring-health/how-to-view-applied-conditional-access-policies)（取得日 2026-09-15）
- 出典: [継続的アクセス評価](https://learn.microsoft.com/ja-jp/entra/identity/conditional-access/concept-continuous-access-evaluation)（取得日 2026-09-15）
- 出典: [Easy Auth の OAuth トークン](https://learn.microsoft.com/ja-jp/azure/app-service/configure-authentication-oauth-tokens)（取得日 2026-09-15）
- 出典: [APIM の Managed Identity 認証](https://learn.microsoft.com/ja-jp/azure/api-management/authentication-managed-identity-policy)（取得日 2026-09-15）
- 出典: [az keyvault](https://learn.microsoft.com/ja-jp/cli/azure/keyvault)（取得日 2026-09-15）
- 出典: [az role assignment](https://learn.microsoft.com/ja-jp/cli/azure/role/assignment)（取得日 2026-09-15）
- 出典: [az resource](https://learn.microsoft.com/ja-jp/cli/azure/resource)（取得日 2026-09-15）
- 出典: [公式テンプレート 41（固定コミット）](https://github.com/microsoft-foundry/foundry-samples/tree/58e4127567f7e9afcf0145d874df890284ca5faf/infrastructure/infrastructure-setup-bicep/41-standard-agent-setup)（取得済みソース照合日 2026-09-15）

---

前へ: [準備と土台](01-prerequisites.md) / 次へ: [ネットワーク境界（IP 許可リストと送信の絞り込み）](10-network-boundary.md) / [トップに戻る](../README.md)
