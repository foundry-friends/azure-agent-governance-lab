# 5. 人とサービスの権限を設定する

進め方: README の第0〜10章を順番に実施します。第4章の完了条件を満たしてから進めます。

> **Note** 状態: ドラフト（Learn 2026-09 時点の記述に基づく・未実行）。Consumer の project 割当は Cloud Shell で実施。更新日 2026-09-20。

> **補足** この章では環境を削除しません。通常の削除は最後の第10章です。中断して片付ける場合だけ、第10章へ進みます。

## 5.1. 目的

作成済みのエージェントに対して、開発者と呼び出し専用ユーザーの権限を設定します。構築時に付いたサービスの ID とロールも照合します。

### なぜこの作業が必要か

エージェントを作る人と、完成したエージェントを使う人では、必要な操作が異なります。全員を構築担当と同じ権限にすると、利用者が不要な変更までできてしまい、役割に応じた制御を確認できません。

この章では「誰が、どの範囲で、何をできるか」をロールとして設定します。あわせて、サービスがデータ基盤へ接続するときの ID と権限を照合します。設定結果は第8章で、開発用・呼び出し用・無権限のユーザーによる成功と拒否の比較に使います。

### 作業前に知っておくこと：権限を決める3つの要素

RBAC（ロールベースのアクセス制御）は、**主体（誰に）・ロール（何を許可するか）・スコープ（どの範囲で）**の組み合わせで権限を付ける仕組みです。同じロールでも、project に付ける場合と親の account に付ける場合では影響する範囲が変わります。

| 用語 | この章での意味・確認例 |
|---|---|
| 主体 | 人のユーザー、またはサービスのマネージド ID（MI）。表示名だけでなく、記録済みのオブジェクト ID／principal ID で照合 |
| ロール | 開発用の Foundry User、呼び出し用の Foundry Agent Consumer、閲覧用の Reader など |
| スコープ | 権限を付ける対象。今回は project、親 account、接続先のリソース／コンテナーを区別 |
| 継承・グループ経由 | 上位スコープや所属グループから得る権限。今回の直接割当だけを見ても、実際の権限は判断できない |

**人の権限**は「利用者がエージェントを使う／開発するため」、**サービスの権限**は「エージェントが保存先などに接続するため」に使います。呼び出し用ユーザーにサービス用のロールをまとめて付けることはしません。5.3の表で割当先を確認してから操作します。

## 5.2. 前提

> **Note** 第4章の G1〜G3 は根拠確認済みです。実行は第4章の C01・C08 初回確認の完了後とし、Basic 分岐時は第4章4.5の対象外・失敗の記録を引き継ぎます。第5章の執筆が進んでいても、第4章を飛ばして構築を進められるという意味ではありません。

### 作業前に確認するもの

- [ ] 第4章の初回応答の確認記録がある。Standard は BYO 接続の結果、Basic 分岐時は4.5の失敗・対象外の記録もある。
- [ ] 今回使用する account / project の ARM ID と、それぞれのマネージド ID を記録済みである。Standard は接続先の ARM ID もある。Basic 分岐前の ID と混同しない。
- [ ] 第0章の開発用・呼び出し用・無権限のユーザーを区別できる。
- [ ] 構築担当が対象スコープでロールを割り当てられる。
- [ ] 各試験ユーザーの既存権限とグループ所属を確認できる。

| 手元に用意する情報 | 用途・確認元 |
|---|---|
| テナント・サブスクリプション・専用 RG | 第1・4章の非公開記録。画面と Cloud Shell の対象照合 |
| 今回の account 名・project 名と各 ARM ID | 第4章の結果。`<project-resource-id>` に account の ID を入れない |
| 3種類の試験ユーザーのサインイン名・オブジェクト ID | 第0章で選んだ主体。表示名が似た別ユーザーを選ばないために使用。対象テナント内の ID を確認できなければ管理者に照会 |
| account MI と project MI の principal ID | 第4章の結果。人のオブジェクト ID、アプリの client ID と区別 |
| Standard の接続先・コンテナーの ARM ID | 第4章の接続・ロール記録。コンテナー名を推測して作らない |

Azure portal と Microsoft Foundry は構築担当のまま別タブで開きます。開発用・呼び出し用ユーザーへログインを切り替える動作試験は、この章では行いません。

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

1. 構築担当で [Azure portal](https://portal.azure.com) を開きます。
2. 上部の検索欄で、第4章の Foundry account 名を検索します。
3. 対象リソースの [概要] を開き、サブスクリプション・RG・名前を非公開記録と照合します。
4. 左側の [アクセス制御 (IAM)] を選択します。
5. [アクセスの確認] タブを選択します。
6. [アクセスの確認] ボタンを選択します。
7. 表示されたペインで [ユーザー、グループ、またはサービス プリンシパル] を選択します。
8. 試験ユーザーのサインイン名で検索し、対象ユーザーを選択します。
9. 表示された割当のロール・スコープ・継承元を非公開記録に残します。
10. 他の2種類の試験ユーザーについても、手順6〜9を繰り返します。

account の画面では、子の project だけに付いた割当を確認できません。続けて project を指定した照会を行います。

11. Azure portal 上部の [Cloud Shell] を選択します。
12. シェルの切替メニューで [Bash] を選択します。初回の準備画面が出た場合は、第1章の Cloud Shell 準備を参照します。
13. Bash のプロンプトが表示されたら、次のコマンドを実行します。

```bash
az account show --query '{tenantId:tenantId,subscriptionId:id,user:user.name}' --output json
```
実行結果の確認ポイント: テナント・サブスクリプション・サインイン中の構築担当が今回の対象と一致することを確認します。不一致なら第1章の対象確認へ戻り、以後の割当操作は進めません。

14. 下表に従ってコマンドの山括弧を置き換えます。
15. 次の照会を、3種類の試験ユーザーについて1人ずつ実行します。

| 置き換える箇所 | 入力する値 |
|---|---|
| `<test-user-object-id>` | 今回照会する人のオブジェクト ID |
| `<project-resource-id>` | 今回の project の完全な ARM ID。短い project 名ではない |

```bash
az role assignment list --assignee "<test-user-object-id>" --scope "<project-resource-id>" --include-inherited --include-groups --query '[].{assignmentId:id,principalId:principalId,role:roleDefinitionName,roleDefinitionId:roleDefinitionId,scope:scope}' --output json
```
実行結果の確認ポイント: 直接割当・グループ経由・親スコープからの継承を記録し、想定外の権限が混ざっていないか確認します。

16. 出力の `principalId` が本人か所属グループかを照合します。
17. `scope` が対象 project か上位スコープかを照合します。
18. 割当 ID と確認時刻を、「変更前」の記録としてユーザーごとに残します。

`[]` は取得条件に合う割当が空であることを示します。照会成功とグループ所属等の確認が揃うまでは「無権限」と確定しません。想定外の権限がある場合は既存権限を変更せず、第0章の試験主体の選定を見直します。

これは認証済みの Azure Cloud Shell（Bash）で行う管理面の照会です。ローカル PC から Azure CLI を実行する手順ではありません。`<...>` は記録済みの値に置き換えます。照会失敗や Microsoft Graph の参照権限不足を、割当なしと解釈しません。

> **Note** 要確認: 実際のグループ所属・継承・条件付きの割当は実機で照合します。権限を十分に確認できない主体は、最小権限試験に使えると判定しません。PIM を既に利用している環境では、試験時の有効な割当と資格のある割当も区別して記録します。この手順で PIM を新規導入しません。

### 3. 開発用ユーザーに project の開発権限を付ける

1. 構築担当で [Microsoft Foundry](https://ai.azure.com) を開きます。
2. 第4章と同じ project を選びます。
3. [管理] の [プロジェクトの詳細] を開きます。
4. [ユーザー] タブを開きます。
5. 既存のユーザー一覧で開発用ユーザーを確認します。同じ project に同じロールがある場合は追加せず、手順10へ進みます。
6. [ユーザーの追加] を選択します。
7. 開発用ユーザーのサインイン名で対象を検索・選択します。
8. 下表と追加画面を照合します。
9. 追加画面で確定操作を行います。確定後に [ユーザー] タブを開き直し、選んだユーザーが一覧に表示されることを確認します。
10. 構築担当の Cloud Shell に戻り、5.3の工程2のロール照会を開発用ユーザーの ID で再実行します。

| 確定前に確認する項目 | 期待する内容 |
|---|---|
| ユーザー | 開発用ユーザー。呼び出し用・無権限ユーザーを含めない |
| 対象 | 第4章の今回の project |
| ロール | Foundry User（旧名 Azure AI User） |
| 確定後の照会 | `scope` が project の ARM ID、`principalId` が開発用ユーザーの ID |

> **Note** 要確認: Learn は [管理] → [プロジェクトの詳細] → [ユーザー] → [ユーザーの追加] までを案内しています。追加ダイアログのロール選択欄と確定ボタンの名称は初回に照合し、選択肢と割当結果を記録します。期待するロール・スコープを確認できない場合は確定しません。

ロール名が旧名の Azure AI User で表示される場合があります。名前だけで判断せず、[公式のロール定義](https://learn.microsoft.com/ja-jp/azure/role-based-access-control/built-in-roles/ai-machine-learning) と照合します。Azure AI Developer は別のロールなので選びません。

> **画面の見え方** [リソースの詳細] は account 側の操作です。ここでは [プロジェクトの詳細] を使います。想定したロール・スコープを確認できなければ追加を保留し、広い権限で代用しません。

### 4. 開発用ユーザーに account の閲覧権限を付ける

1. Azure portal 上部の検索欄で親の Foundry account 名を検索し、対象リソースの [概要] を開きます。
2. [アクセス制御 (IAM)] を開きます。
3. 5.3の工程2の変更前記録に同じ account・ユーザー・Reader の割当がない場合だけ、[追加] → [ロールの割り当ての追加] を選びます。同じ割当がある場合は手順18へ進みます。
4. [ロール] タブの検索欄に Reader と入力します。
5. Reader（閲覧者）の行を選択します。
6. [次へ] を選択します。
7. [メンバー] タブで [ユーザー、グループ、またはサービス プリンシパル] を選択します。
8. [メンバーの選択] を選択します。
9. 開発用ユーザーのサインイン名を検索欄に入力します。
10. 対象ユーザーを選択します。
11. [選択] を押して、メンバー一覧に追加します。
12. 一覧が開発用ユーザーだけであることを確認します。
13. [確認と割り当て]（Review + assign）を開きます。
14. 対象ユーザー・Reader・今回の account スコープを確認します。
15. 確認画面の [確認と割り当て] を選択して確定します。
16. [アクセス制御 (IAM)] の [ロールの割り当て] を開き直します。
17. 開発用ユーザーの Reader が account スコープにあることを確認します。
18. 5.3の工程2の照会で、project の Foundry User と account から継承する Reader を確認します。

既に同じ割当がある場合は重複追加しません。リソースグループやサブスクリプションへ割当範囲を拡大しません。

### 5. 呼び出し用ユーザーに project の Consumer を付ける

> **補足** 公式資料では Azure portal の Consumer 割当は account スコープのみ対応とされています。project に限定するため、この操作だけは GUI にない操作の代替として Cloud Shell を使います。

1. 構築担当の Azure Cloud Shell（Bash）を開き、5.3の工程2の `az account show` で対象を再確認します。
2. 次の照会で組み込みロールの定義を取得します。

```bash
az role definition list --name "Foundry Agent Consumer" --query '[].{roleName:roleName,roleType:roleType,roleDefinitionId:name,permissions:permissions}' --output json
```
実行結果の確認ポイント: Foundry Agent Consumer の組み込みロールが1件取得でき、ロール定義 ID が公式 RBAC 資料の Consumer と一致することを確認します。

3. 出力の `roleType` が `BuiltInRole` であることを確認します。
4. `roleDefinitionId` を非公開メモへ控えます。
5. 対象 project の ARM ID と呼び出し用ユーザーのオブジェクト ID を非公開記録で照合します。
6. 取得した定義 ID を以下の `<consumer-role-definition-id>` に指定します。
7. 5.3の工程2で記録した既存割当に同じ割当がない場合だけ、次のコマンドを実行します。

```bash
az role assignment create --assignee-object-id "<consumer-user-object-id>" --assignee-principal-type User --role "<consumer-role-definition-id>" --scope "<project-resource-id>" --query '{assignmentId:id,principalId:principalId,principalType:principalType,roleDefinitionId:roleDefinitionId,scope:scope}' --output json
```
実行結果の確認ポイント: `principalType` が User、主体が呼び出し用ユーザー、スコープが対象 project、ロールが確認した Consumer と一致することを記録します。

8. 構築担当のまま、呼び出し用ユーザーの ID を指定して5.3の工程2のロール照会を再実行します。
9. Foundry User や上位のアクセス権が混ざっていないことを確認します。
10. 作成結果の `assignmentId` を「今回追加した割当」として記録します。これは誤割当を戻すときに使用します。

公式の例にはサービスプリンシパル向けのものもありますが、ここで指定するのは**人のユーザー**です。アプリの client ID や project のマネージド ID を入力しません。ロールが見つからない、または割当が拒否された場合は保留します。カスタムロールの新規作成や account 全体への Consumer 割当で代用しません。

### 6. サービスの ID と接続用ロールを照合する

人が使う権限と、サービスが使う権限を別々に記録します。以下は第4章で構築済みの状態の確認であり、動作確認前に不足していた接続用権限を、この章まで後回しにする手順ではありません。

Basic 分岐時は、現在使用する account／project と、第4章で確認したサービス権限を照合します。Standard の BYO 向けの表・照会は対象外として理由を残し、元の Standard 環境の失敗記録を引き継ぎます。Basic を動かすために元の3リソースへのロールを追加しません。

1. 構築担当の Cloud Shell（Bash）を開きます。
2. 下の `<account-or-project-resource-id>` を account の ARM ID に置き換えて実行します。
3. 同じコマンドの ID を project の ARM ID に置き換えて、もう一度実行します。

```bash
az resource show --ids "<account-or-project-resource-id>" --query '{id:id,identity:identity}' --output json
```
実行結果の確認ポイント: 2つのリソースの `identity.type` と `principalId` をそれぞれ記録し、同じ主体と推測しないことを確認します。

4. 2回の出力を account／project 別に記録し、第4章の `principalId` と照合します。
5. Standard の場合は、第4章の記録と下表の割当を照合します。

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

6. 下表に従って照会コマンドの山括弧を置き換えます。
7. Azure IAM の割当を、上表の Foundry account〜Cosmos DB account の各行のスコープで1回ずつ確認します。Cosmos のデータロールは手順8〜10、Key Vault は第2章で明示した主体の記録と照合します。

| 置き換える箇所 | 入力する値 |
|---|---|
| `<project-mi-principal-id>` | 直前の照会で確認した project MI の `principalId` |
| `<target-resource-or-container-resource-id>` | 確認するリソースまたはコンテナーの ARM ID。第4章の割当記録から取得 |

コンテナー単位の行を確認するときは、そのコンテナーの ID を指定します。親 account の ID だけを使い回すと、子スコープの割当を見落とします。

```bash
az role assignment list --assignee-object-id "<project-mi-principal-id>" --scope "<target-resource-or-container-resource-id>" --include-inherited --fill-principal-name false --query '[].{assignmentId:id,principalId:principalId,role:roleDefinitionName,scope:scope}' --output json
```
実行結果の確認ポイント: 対象の MI・ロール・割当スコープを照合し、コンテナーでの割当と account からの継承を区別します。

8. `<resource-group-name>` と `<cosmos-account-name>` を第3・4章の対象に置き換えます。
9. `<project-mi-principal-id>` を今回の project MI に置き換え、Cosmos DB のデータロール割当を照会します。

```bash
az cosmosdb sql role assignment list --resource-group "<resource-group-name>" --account-name "<cosmos-account-name>" --query "[?principalId=='<project-mi-principal-id>'].{assignmentId:id,principalId:principalId,roleDefinitionId:roleDefinitionId,scope:scope}" --output json
```
実行結果の確認ポイント: project MI の割当が存在し、対象データベースのスコープとロール定義 ID を取得できることを確認します。

10. 続けて同じ Cosmos DB account のロール定義を照会します。

```bash
az cosmosdb sql role definition list --resource-group "<resource-group-name>" --account-name "<cosmos-account-name>" --query '[].{id:id,roleName:roleName,type:type,permissions:permissions}' --output json
```
実行結果の確認ポイント: 割当の `roleDefinitionId` と定義の `id` を照合し、Cosmos DB Built-in Data Contributor であることを確認します。

Cosmos DB Operator だけではデータアクセスを確認できません。また、IAM の一覧だけでは Cosmos DB のデータロールを確認できません。Cloud Shell のこれらの管理面の照会成功は、Agent Service からのデータ通信成功の証明ではありません。

> **Note** 要確認: 実際に作成された ID・割当スコープを第4章の結果と照合します。不一致があれば原因と影響を確認するまで保留し、MI の再生成や広いロールの追加で回避しません。この章ではエージェントの公開操作や新たな専用 ID の作成は行いません。

### 7. 第8章へ引き継ぐ設定記録を残す

1. 第4章までに使っている非公開の記録先を開きます。
2. 第5章の記録に、下表の項目を主体ごとに追記します。
3. 変更前と変更後の割当を比べ、今回追加した割当 ID を明示します。
4. 保存後に記録を開き直し、3種類の試験ユーザーと2種類の MI を取り違えていないか確認します。

以下は非公開の `evidence/` に置く記録です。手順の不足があれば共有 Excel に記入し、修正が必要な課題を Issue に転記するときは実 ID や生の照会結果を含めません。

| 記録項目 | 内容 |
|---|---|
| 主体 | 構築用・開発用・呼び出し用・無権限・account MI・project MI の区別 |
| 割当 | 対象スコープ、ロール名、ロール定義 ID、割当 ID |
| 付与経路 | 直接 / グループ / 上位からの継承、今回追加したか既存か |
| 確認 | 確認日時、照会結果、不一致・未確認事項 |
| 動作試験 | ユーザー別の権限確認（C02）は第8章まで Pending |

第7章で用意するアプリは、利用者本人の権限を Foundry 側で検証できる必要があります。全員の呼び出しを共通のアプリ MI に置き換えた経路では、今回のユーザー別 RBAC の効果を判定できません。

## 5.4. 完了条件

- 開発用ユーザーの project の Foundry User と account の Reader を確認できる。
- 呼び出し用ユーザーの project の Consumer を確認でき、開発権限が混ざっていない。
- 無権限ユーザーについて、対象への直接・グループ・継承によるアクセスがないことを確認できる。
- 現在使用する account MI / project MI と、接続用ロールの対象・スコープを記録できる。Basic 分岐時は BYO 向けの対象外理由と元の失敗記録を引き継いでいる。
- 今回追加した割当を特定でき、照会失敗や不一致が残っていない。

ここでの完了は**設定の確認**です。呼び出し・作成・編集の許可と拒否は、第7章のアプリができた後に第8章で試します。管理画面を開けたことや割当コマンドの成功だけで C02 を Pass にしません。

## 5.5. うまくいかない場合

| 症状 | 切り分け・対応 |
|---|---|
| [ユーザーの追加] が使えない / 割当が拒否される | 構築担当の割当権限、対象スコープ、割当に付いた条件を確認し、必要なら管理者へ照会する |
| project の Consumer が画面で選べない | 5.3の工程5の Cloud Shell 代替を使う。account 全体へ広げない |
| Consumer で管理画面を開けない | ロールの想定と区別する。呼び出し試験は第8章で行い、閲覧のために User を追加しない |
| 開発ユーザーに project が見えない | 対象テナント・project の User・親 account の Reader・反映状態を確認する |
| Graph の照会が失敗する | グループ・継承の確認を管理者へ依頼する。グループを除いた照会だけで権限混入なしとしない |
| 割当後も拒否される | 反映を待ち、再サインインして主体とスコープを再確認する。直ちに上位ロールを足さない |
| MI の変更が反映されない | サービス側のトークンキャッシュも切り分ける。人の再サインインで MI も更新されるとは扱わない |
| 接続先のデータ操作が拒否される | データロール・管理ロール・ネットワークを分け、第4章の接続確認記録と照合する |

誤った割当を追加した場合は、次の順で今回の変更だけを戻します。既存の組織権限やグループ所属は変更しません。

1. 変更前後の記録を開き、今回追加した誤割当の ID・主体・ロール・スコープを照合します。
2. Azure portal で、その割当を追加した対象リソースを開きます。
3. [アクセス制御 (IAM)] → [ロールの割り当て] を開きます。
4. 対象ユーザーを検索し、今回追加した誤割当の行だけにチェックを入れます。
5. [削除] を選択します。
6. 確認画面の対象が一致する場合だけ削除を確定します。
7. 5.3の工程2のロール照会を再実行し、誤割当だけがなくなったことを確認します。

Consumer の project 割当など GUI で対象を特定できない場合は、手順1で照合した**割当の ARM ID**を次の `<mistaken-assignment-resource-id>` に入力します。project の ARM ID やロール定義 ID ではありません。

```bash
az role assignment delete --ids "<mistaken-assignment-resource-id>"
```
実行結果の確認ポイント: 5.3の工程2のロール照会を再実行し、指定した今回の誤割当だけがなくなり、既存の必要な割当が残っていることを確認します。

修正内容・再試行時刻・結果を非公開に記録します。正しい設定に戻せない場合は保留し、後続の動作試験で成功扱いにしません。

## 5.6. 次の操作

5.4の設定確認を終えてから、環境を維持して第6章へ進みます。第8章のユーザー比較に使うため、今回設定した正しい割当は残します。

## 5.7. 費用

基本の Managed Identity・RBAC は既存見積りの No.9 です。新しいライセンスを追加する手順ではありません。作業中も既存リソースの料金は継続するため、環境全体の費用は README の見積りと実績で確認します。

## 5.8. 本番との差

このラボは専用ユーザーへの割当で役割の違いを学びます。本番では所属変更・退職・サービス廃止時の権限回収、職務分離、権限の定期点検を設計します。既存の条件付きアクセスは変更しません。IaC の固定停止点も維持し、権限表を確認しただけでテンプレートを再展開しません。

### 出典

- 出典: [Cloud Shell の対象確認（az account show）](https://learn.microsoft.com/en-us/cli/azure/account?view=azure-cli-latest#az-account-show)（取得日 2026-09-20）

- 出典: [Foundry の RBAC](https://learn.microsoft.com/ja-jp/azure/foundry/concepts/rbac-foundry)（取得日 2026-09-20）
- 出典: [Foundry の認証と承認](https://learn.microsoft.com/ja-jp/azure/foundry/concepts/authentication-authorization-foundry)（取得日 2026-09-15）
- 出典: [AI と機械学習の組み込みロール](https://learn.microsoft.com/ja-jp/azure/role-based-access-control/built-in-roles/ai-machine-learning)（取得日 2026-09-20）
- 出典: [Azure portal でロールを割り当てる](https://learn.microsoft.com/ja-jp/azure/role-based-access-control/role-assignments-portal)（取得日 2026-09-20）
- 出典: [リソースへのアクセス権を確認する](https://learn.microsoft.com/ja-jp/azure/role-based-access-control/check-access)（取得日 2026-09-20）
- 出典: [Azure ロール割当の削除](https://learn.microsoft.com/ja-jp/azure/role-based-access-control/role-assignments-remove)（取得日 2026-09-20）
- 出典: [Azure RBAC のトラブルシューティング](https://learn.microsoft.com/ja-jp/azure/role-based-access-control/troubleshooting)（取得日 2026-09-15）
- 出典: [Standard setup の接続用ロール](https://learn.microsoft.com/ja-jp/azure/foundry/agents/concepts/standard-agent-setup)（取得日 2026-09-20）
- 出典: [Managed Identity の権限変更とキャッシュ](https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/managed-identity-best-practice-recommendations)（取得日 2026-09-15）
- 出典: [az role assignment](https://learn.microsoft.com/en-us/cli/azure/role/assignment?view=azure-cli-latest)（取得日 2026-09-20）
- 出典: [az role definition](https://learn.microsoft.com/en-us/cli/azure/role/definition?view=azure-cli-latest)（取得日 2026-09-20）
- 出典: [az resource](https://learn.microsoft.com/en-us/cli/azure/resource?view=azure-cli-latest)（取得日 2026-09-20）
- 出典: [az cosmosdb sql role assignment](https://learn.microsoft.com/en-us/cli/azure/cosmosdb/sql/role/assignment?view=azure-cli-latest)（取得日 2026-09-20）
- 出典: [az cosmosdb sql role definition](https://learn.microsoft.com/en-us/cli/azure/cosmosdb/sql/role/definition?view=azure-cli-latest)（取得日 2026-09-20）

---

前へ: [Foundry とエージェントを作る](04-foundry-agent.md) / 次へ: [監視と監査を設定する](06-monitoring.md) / [トップに戻る](../README.md)
