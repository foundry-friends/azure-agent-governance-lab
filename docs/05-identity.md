# 5. 人とサービスの権限を設定する

進め方: README の第0〜10章を順番に実施します。第4章の完了条件を満たしてから進めます。

> **Note** 状態: ドラフト（Learn 2026-09 時点の記述に基づく・未実行）。Consumer の project 割当は Cloud Shell で実施。更新日 2026-09-15。

> **補足** この章では環境を削除しません。通常の削除は最後の第10章です。中断して片付ける場合だけ、第10章へ進みます。

## 5.1. 目的

作成済みのエージェントに対して、開発者と呼び出し専用ユーザーの権限を設定します。構築時に付いたサービスの ID とロールも照合します。

### なぜこの作業が必要か

エージェントを作る人と、完成したエージェントを使う人では、必要な操作が異なります。全員を構築担当と同じ権限にすると、利用者が不要な変更までできてしまい、役割に応じた制御を確認できません。

この章では「誰が、どの範囲で、何をできるか」をロールとして設定します。あわせて、サービスがデータ基盤へ接続するときの ID と権限を照合します。設定結果は第8章で、開発用・呼び出し用・無権限のユーザーによる成功と拒否の比較に使います。

## 5.2. 前提

> **Note** 第4章の停止条件 G1〜G3 が解決し、C01 の完了条件を満たした後に実行します。第5章の執筆が進んでいても、第4章を飛ばして構築を進められるという意味ではありません。

### 作業前に確認するもの

- [ ] 第4章の初回応答と BYO 接続の確認記録がある。
- [ ] account / project / 接続先の ARM ID と、account / project のマネージド ID を記録済みである。
- [ ] 第0章の開発用・呼び出し用・無権限のユーザーを区別できる。
- [ ] 構築担当が対象スコープでロールを割り当てられる。
- [ ] 各試験ユーザーの既存権限とグループ所属を確認できる。

ロール割当には `Microsoft.Authorization/roleAssignments/write` が必要です。Azure の Owner や Role Based Access Control Administrator などの権限と、その条件・対象スコープを確認します。Foundry Account Owner による条件付きの割当権限だけで、Consumer を含む任意のロールを割り当てられるとは扱いません。

この章の作成・変更は構築担当が行います。ユーザーごとの動作比較は第8章です。既存の管理者から権限を剥がして試験ユーザーにすることは避け、第0章で選んだ専用の主体を使います。

## 5.3. 設定

### 1. 誰に何を許可するかを決める

| 主体 | 割当先 | この章で用意するロール | 目的 |
|---|---|---|---|
| 構築担当 | 作成済みの専用環境 | 既存の構築・ロール割当権限を維持 | 環境を管理する。最小権限の比較対象にはしない |
| 開発用ユーザー | 対象 project | Foundry User | エージェントの開発・テスト |
| 開発用ユーザー | 親の Foundry account | Reader（閲覧者） | ポータルで親リソースを閲覧する |
| 呼び出し用ユーザー | 対象 project | Foundry Agent Consumer | project 内のエージェントエンドポイントを利用する |
| 無権限ユーザー | 対象 project と上位スコープ | 対象へのアクセスを付与しない | 権限のない状態の比較対象にする |
| project のマネージド ID | Foundry account と BYO 接続先 | 第4章で確定した接続用ロールを照合 | サービス自身が接続先へアクセスする |

[公式の RBAC マッピング](https://learn.microsoft.com/ja-jp/azure/foundry/concepts/rbac-foundry) は、開発者に project の Foundry User と account の Reader、呼び出し専用に project の Foundry Agent Consumer を案内しています。account の Reader は他の project の存在等も閲覧する範囲になるため、専用環境内に限定します。

Consumer は project 内の全エージェントエンドポイントを対象とします。1エージェントだけへの制限を検証したことにはなりません。また、Consumer には管理画面の閲覧やエージェント作成・編集の権限はありません。画面を開くために Foundry User を追加すると、呼び出し専用の比較が成立しなくなります。

### 2. 既存の割当を記録する

1. 構築担当で Azure portal を開きます。
2. 対象 Foundry account の [アクセス制御 (IAM)] を開きます。
3. [ロールの割り当て] で試験ユーザーと所属グループの割当を確認します。
4. 上位スコープから継承した割当を確認します。
5. 以下の Cloud Shell の確認を、3種類の試験ユーザーごとに行います。

```bash
az role assignment list --assignee "<test-user-object-id>" --scope "<project-resource-id>" --include-inherited --include-groups --query '[].{assignmentId:id,principalId:principalId,role:roleDefinitionName,roleDefinitionId:roleDefinitionId,scope:scope}' --output json
```
実行結果の確認ポイント: 直接割当・グループ経由・親スコープからの継承を記録し、想定外の権限が混ざっていないか確認します。

これは認証済みの Azure Cloud Shell（Bash）で行う管理面の照会です。ローカル PC から Azure CLI を実行する手順ではありません。`<...>` は記録済みの値に置き換えます。照会失敗や Microsoft Graph の参照権限不足を、割当なしと解釈しません。

> **Note** 要確認: 実際のグループ所属・継承・条件付きの割当は実機で照合します。権限を十分に確認できない主体は、最小権限試験に使えると判定しません。PIM を既に利用している環境では、試験時の有効な割当と資格のある割当も区別して記録します。この手順で PIM を新規導入しません。

### 3. 開発用ユーザーに project の開発権限を付ける

1. 構築担当で [Microsoft Foundry](https://ai.azure.com) を開きます。
2. 第4章と同じ project を選びます。
3. [管理] の [プロジェクトの詳細] を開きます。
4. [ユーザー] タブを開きます。
5. [ユーザーの追加] で開発用ユーザーを指定します。
6. 対象が project、ロールが Foundry User であることを確認して追加します。
7. 構築担当のまま、開発用ユーザーの ID を指定して手順2の照会を再実行します。

ロール名が旧名の Azure AI User で表示される場合があります。名前だけで判断せず、[公式のロール定義](https://learn.microsoft.com/ja-jp/azure/role-based-access-control/built-in-roles/ai-machine-learning) と照合します。Azure AI Developer は別のロールなので選びません。

> **画面の見え方** [リソースの詳細] は account 側の操作です。ここでは [プロジェクトの詳細] を使います。想定したロール・スコープを確認できなければ追加を保留し、広い権限で代用しません。

### 4. 開発用ユーザーに account の閲覧権限を付ける

1. Azure portal で親の Foundry account を開きます。
2. [アクセス制御 (IAM)] を開きます。
3. [追加] から [ロールの割り当ての追加] を選びます。
4. [ロール] で Reader（閲覧者）を選びます。
5. [メンバー] で [ユーザー、グループ、またはサービス プリンシパル] を選びます。
6. [メンバーを選択する] で開発用ユーザーを選びます。
7. [レビューと割り当て] で対象・ロール・account スコープを確認します。
8. 割当を確定します。
9. 手順2の照会で project の Foundry User と account から継承する Reader を確認します。

既に同じ割当がある場合は重複追加しません。リソースグループやサブスクリプションへ割当範囲を拡大しません。

### 5. 呼び出し用ユーザーに project の Consumer を付ける

> **補足** 公式資料では Azure portal の Consumer 割当は account スコープのみ対応とされています。project に限定するため、この操作だけは GUI にない操作の代替として Cloud Shell を使います。

1. 構築担当の Azure Cloud Shell（Bash）を開きます。
2. 次の照会で組み込みロールの定義を取得します。

```bash
az role definition list --name "Foundry Agent Consumer" --query '[].{roleName:roleName,roleType:roleType,roleDefinitionId:name,permissions:permissions}' --output json
```
実行結果の確認ポイント: Foundry Agent Consumer の組み込みロールが1件取得でき、ロール定義 ID が公式 RBAC 資料の Consumer と一致することを確認します。

3. 対象 project の ARM ID と呼び出し用ユーザーのオブジェクト ID を確認します。
4. 取得した定義 ID を以下の `<consumer-role-definition-id>` に指定します。
5. 手順2の既存割当に同じ割当がない場合だけ、次のコマンドを実行します。

```bash
az role assignment create --assignee-object-id "<consumer-user-object-id>" --assignee-principal-type User --role "<consumer-role-definition-id>" --scope "<project-resource-id>" --query '{assignmentId:id,principalId:principalId,principalType:principalType,roleDefinitionId:roleDefinitionId,scope:scope}' --output json
```
実行結果の確認ポイント: `principalType` が User、主体が呼び出し用ユーザー、スコープが対象 project、ロールが確認した Consumer と一致することを記録します。

6. 構築担当のまま、呼び出し用ユーザーの ID を指定して手順2の照会を再実行します。
7. Foundry User や上位のアクセス権が混ざっていないことを確認します。

公式の例にはサービスプリンシパル向けのものもありますが、ここで指定するのは**人のユーザー**です。アプリの client ID や project のマネージド ID を入力しません。ロールが見つからない、または割当が拒否された場合は保留します。カスタムロールの新規作成や account 全体への Consumer 割当で代用しません。

### 6. サービスの ID と接続用ロールを照合する

人が使う権限と、サービスが使う権限を別々に記録します。以下は第4章で構築済みの状態の確認であり、動作確認前に不足していた接続用権限を、この章まで後回しにする手順ではありません。

1. account と project それぞれに対して次の照会を実行します。

```bash
az resource show --ids "<account-or-project-resource-id>" --query '{id:id,identity:identity}' --output json
```
実行結果の確認ポイント: 2つのリソースの `identity.type` と `principalId` をそれぞれ記録し、同じ主体と推測しないことを確認します。

2. 第4章の記録と、下表の割当を照合します。

| 対象 | project のマネージド ID の照合対象 | 確認する範囲 |
|---|---|---|
| Foundry account | Foundry User | account スコープの割当 |
| Storage account | Storage Account Contributor | 管理操作の割当 |
| project 用 blobstore コンテナー | Storage Blob Data Contributor | 対象コンテナーのデータ権限 |
| project 用 agent コンテナー | Storage Blob Data Owner | 対象コンテナーのデータ権限 |
| AI Search service | Search Service Contributor / Search Index Data Contributor | 管理とデータの両方 |
| Cosmos DB account | Cosmos DB Operator | 管理操作の割当 |
| Cosmos DB の `enterprise_memory` | Cosmos DB Built-in Data Contributor | 全コンテナーを含むデータベースのデータ権限 |
| Key Vault | 今回の学習で明示した主体のみ | Foundry の必須接続・自動割当とは扱わない |

この表は現在の Standard setup と Foundry RBAC 資料に基づきます。固定テンプレート41を実行済みとは扱わず、GUI 構築の実結果を照合します。

3. Azure IAM の割当を、対象スコープごとに確認します。

```bash
az role assignment list --assignee-object-id "<project-mi-principal-id>" --scope "<target-resource-or-container-resource-id>" --include-inherited --fill-principal-name false --query '[].{assignmentId:id,principalId:principalId,role:roleDefinitionName,scope:scope}' --output json
```
実行結果の確認ポイント: 対象の MI・ロール・割当スコープを照合し、コンテナーでの割当と account からの継承を区別します。

4. Cosmos DB のデータ権限を別に確認します。

```bash
az cosmosdb sql role assignment list --resource-group "<resource-group-name>" --account-name "<cosmos-account-name>" --query "[?principalId=='<project-mi-principal-id>'].{assignmentId:id,principalId:principalId,roleDefinitionId:roleDefinitionId,scope:scope}" --output json
```
実行結果の確認ポイント: project MI の割当が存在し、対象データベースのスコープとロール定義 ID を取得できることを確認します。

```bash
az cosmosdb sql role definition list --resource-group "<resource-group-name>" --account-name "<cosmos-account-name>" --query '[].{id:id,roleName:roleName,type:type,permissions:permissions}' --output json
```
実行結果の確認ポイント: 割当の `roleDefinitionId` と定義の `id` を照合し、Cosmos DB Built-in Data Contributor であることを確認します。

Cosmos DB Operator だけではデータアクセスを確認できません。また、IAM の一覧だけでは Cosmos DB のデータロールを確認できません。Cloud Shell のこれらの管理面の照会成功は、Agent Service からのデータ通信成功の証明ではありません。

> **Note** 要確認: 実際に作成された ID・割当スコープを第4章の結果と照合します。不一致があれば原因と影響を確認するまで保留し、MI の再生成や広いロールの追加で回避しません。この章ではエージェントの公開操作や新たな専用 ID の作成は行いません。

### 7. 第8章へ引き継ぐ設定記録を残す

次の項目を非公開の `evidence/` に記録します。

| 記録項目 | 内容 |
|---|---|
| 主体 | 構築用・開発用・呼び出し用・無権限・account MI・project MI の区別 |
| 割当 | 対象スコープ、ロール名、ロール定義 ID、割当 ID |
| 付与経路 | 直接 / グループ / 上位からの継承、今回追加したか既存か |
| 確認 | 確認日時、照会結果、不一致・未確認事項 |
| 動作試験 | C02 は第8章まで Pending |

第7章で用意するアプリは、利用者本人の権限を Foundry 側で検証できる必要があります。全員の呼び出しを共通のアプリ MI に置き換えた経路では、今回のユーザー別 RBAC の効果を判定できません。

## 5.4. 完了条件

- 開発用ユーザーの project の Foundry User と account の Reader を確認できる。
- 呼び出し用ユーザーの project の Consumer を確認でき、開発権限が混ざっていない。
- 無権限ユーザーについて、対象への直接・グループ・継承によるアクセスがないことを確認できる。
- account MI / project MI と、接続用ロールの対象・スコープを記録できる。
- 今回追加した割当を特定でき、照会失敗や不一致が残っていない。

ここでの完了は**設定の確認**です。呼び出し・作成・編集の許可と拒否は、第7章のアプリができた後に第8章で試します。管理画面を開けたことや割当コマンドの成功だけで C02 を Pass にしません。

## 5.5. うまくいかない場合

| 症状 | 切り分け・対応 |
|---|---|
| [ユーザーの追加] が使えない / 割当が拒否される | 構築担当の割当権限、対象スコープ、割当に付いた条件を確認し、必要なら管理者へ照会する |
| project の Consumer が画面で選べない | 手順5の Cloud Shell 代替を使う。account 全体へ広げない |
| Consumer で管理画面を開けない | ロールの想定と区別する。呼び出し試験は第8章で行い、閲覧のために User を追加しない |
| 開発ユーザーに project が見えない | 対象テナント・project の User・親 account の Reader・反映状態を確認する |
| Graph の照会が失敗する | グループ・継承の確認を管理者へ依頼する。グループを除いた照会だけで権限混入なしとしない |
| 割当後も拒否される | 反映を待ち、再サインインして主体とスコープを再確認する。直ちに上位ロールを足さない |
| MI の変更が反映されない | サービス側のトークンキャッシュも切り分ける。人の再サインインで MI も更新されるとは扱わない |
| 接続先のデータ操作が拒否される | データロール・管理ロール・ネットワークを分け、第4章の接続確認記録と照合する |

誤った割当を追加した場合は、まず割当 ID・主体・スコープと変更前の記録を照合します。Azure portal の対象スコープの [アクセス制御 (IAM)] → [ロールの割り当て] で、**今回追加した誤った割当だけ**を選択して [削除] します。既存の組織権限やグループ所属は変更しません。Consumer の project 割当など GUI で対象を特定できない場合は、次の代替を使います。

```bash
az role assignment delete --ids "<mistaken-assignment-resource-id>"
```
実行結果の確認ポイント: 手順2の照会を再実行し、指定した今回の誤割当だけがなくなり、既存の必要な割当が残っていることを確認します。

修正内容・再試行時刻・結果を非公開に記録します。正しい設定に戻せない場合は保留し、後続の動作試験で成功扱いにしません。

## 5.6. 次の操作

5.4の設定確認を終えてから、環境を維持して第6章へ進みます。第8章のユーザー比較に使うため、今回設定した正しい割当は残します。

## 5.7. 費用

基本の Managed Identity・RBAC は既存見積りの No.9 です。新しいライセンスを追加する手順ではありません。作業中も既存リソースの料金は継続するため、環境全体の費用は README の見積りと実績で確認します。

## 5.8. 本番との差

このラボは専用ユーザーへの割当で役割の違いを学びます。本番では所属変更・退職・サービス廃止時の権限回収、職務分離、権限の定期点検を設計します。既存の条件付きアクセスは変更しません。IaC の固定停止点も維持し、権限表を確認しただけでテンプレートを再展開しません。

### 出典

- 出典: [Foundry の RBAC](https://learn.microsoft.com/ja-jp/azure/foundry/concepts/rbac-foundry)（取得日 2026-09-15）
- 出典: [Foundry の認証と承認](https://learn.microsoft.com/ja-jp/azure/foundry/concepts/authentication-authorization-foundry)（取得日 2026-09-15）
- 出典: [AI と機械学習の組み込みロール](https://learn.microsoft.com/ja-jp/azure/role-based-access-control/built-in-roles/ai-machine-learning)（取得日 2026-09-15）
- 出典: [Azure portal でロールを割り当てる](https://learn.microsoft.com/ja-jp/azure/role-based-access-control/role-assignments-portal)（取得日 2026-09-15）
- 出典: [リソースへのアクセス権を確認する](https://learn.microsoft.com/ja-jp/azure/role-based-access-control/check-access)（取得日 2026-09-15）
- 出典: [Azure ロール割当の削除](https://learn.microsoft.com/ja-jp/azure/role-based-access-control/role-assignments-remove)（取得日 2026-09-15）
- 出典: [Azure RBAC のトラブルシューティング](https://learn.microsoft.com/ja-jp/azure/role-based-access-control/troubleshooting)（取得日 2026-09-15）
- 出典: [Standard setup の接続用ロール](https://learn.microsoft.com/ja-jp/azure/foundry/agents/concepts/standard-agent-setup)（取得日 2026-09-15）
- 出典: [Managed Identity の権限変更とキャッシュ](https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/managed-identity-best-practice-recommendations)（取得日 2026-09-15）
- 出典: [az role assignment](https://learn.microsoft.com/ja-jp/cli/azure/role/assignment)（取得日 2026-09-15）
- 出典: [az role definition](https://learn.microsoft.com/ja-jp/cli/azure/role/definition)（取得日 2026-09-15）
- 出典: [az resource](https://learn.microsoft.com/ja-jp/cli/azure/resource)（取得日 2026-09-15）
- 出典: [az cosmosdb sql role assignment](https://learn.microsoft.com/ja-jp/cli/azure/cosmosdb/sql/role/assignment)（取得日 2026-09-15）
- 出典: [az cosmosdb sql role definition](https://learn.microsoft.com/ja-jp/cli/azure/cosmosdb/sql/role/definition)（取得日 2026-09-15）

---

前へ: [Foundry とエージェントを作る](04-foundry-agent.md) / 次へ: [監視と監査を設定する](06-monitoring.md) / [トップに戻る](../README.md)
