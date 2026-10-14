# 0. Azure へのサインインと命名規則

進め方: README の第0〜10章を順番に実施します。この章から開始します。

> **Note** 状態: ドラフト（Learn 2026-10 時点の記述に基づく・未実行）。操作手順の見直し日 2026-10-14。

前提は、Azure アカウントが払い出され、サインインできることと、検証の費用と期間は承認済みであることです。

> **Note** 実 ID・社内 IP・認証情報を、この手順書やリポジトリへ書き込みません。

## 0.1. 目的

Azure portal の対象テナント・サブスクリプションと自分のロールを確認し、リソースの命名規則を揃えます。

### なぜこの作業が必要か

共有サブスクリプションで他の人のリソースを触らないために、自分がどこに・どの権限で入っているかを確認します。RG を作る前に検証者ごとの名前を決め、第1章以降で自分のリソースを区別できるようにします。

## 0.2. Azure portal にサインインし、対象を照合する

1. 社内 PC のブラウザで [Azure portal](https://portal.azure.com) を開きます。
2. 案内された検証用の個人アカウントでサインインします。
3. ポータル右上の [Settings]（[設定]、歯車のアイコン）を選択します。
4. 設定画面の [Language + region]（[言語 + 地域]）を選択します。
5. [Language]（[言語]）の一覧で [日本語] を選択します。
6. [Apply]（[適用]）を選択します。
7. 設定画面を再度開きます。
8. 言語が [日本語] になっていることを確認します。
9. ポータル上部の検索欄に「サブスクリプション」と入力します。
10. 検索結果の [サブスクリプション] を選択します。
11. 管理担当者から案内されたサブスクリプションを一覧から選択します。
12. [概要] の名称とサブスクリプション ID を案内された値と照合します。
13. ポータル上部の検索から [Microsoft Entra ID] を開きます。
14. [プロパティ] を選択します。
15. [テナント ID] を管理担当者から案内された値と照合します。
16. 照合結果と確認日を手元の非公開メモに記録します。

> **補足** 本手順の画面名と項目名は、Microsoft Learn 日本語版の表記（2026-10 時点）に合わせています。ポータルの表示言語が英語のままだと項目名が一致しないため、最初に日本語に揃えます。

> **画面の見え方** テナントとサブスクリプションは別の ID です。混同して同じものとして転記しないようにします。

> **Note** 対象が見つからない場合は、右上の [設定] → [ディレクトリとサブスクリプション] で現在のディレクトリとサブスクリプションの絞り込みを確認します。別のディレクトリを使用中なら、案内されたディレクトリの [切り替え] を選択して手順 9 からやり直します。Entra の情報を閲覧できない場合は管理担当者に照合を依頼し、確認のためだけに管理権限を追加しません。

## 0.3. 自分のロールを確認する

Standard setup の公式テンプレート 41 を展開する実施者には、次のロールが必要です。

| 何をするか | 要るロール |
|---|---|
| Foundry account と project の作成 | **Foundry Account Owner**（旧名 Azure AI Account Owner。ID と権限は改名前後で同じ） |
| Standard setup で Cosmos DB・AI Search・Storage に RBAC を付与 | `Microsoft.Authorization/roleAssignments/write` を持つロール。**所有者**・**ユーザー アクセス管理者**・**ロールベースのアクセス制御管理者** のいずれか |
| Azure Policy の割当（第9章） | **Resource Policy Contributor** または所有者。共同作成者では定義・割当を作れません |
| 予算アラートの作成（第1章） | 所有者。共同作成者と Cost Management 共同作成者は自分が作った予算のみ操作できます |
| モデルのクォータ閲覧 | **Cognitive Services Usages Reader**（サブスクリプション スコープ）。増枠要求は所有者か共同作成者 |

1. ポータル上部の検索に「サブスクリプション」と入力します。
2. 検索結果の [サブスクリプション] を選択します。
3. 一覧から検証用サブスクリプションを選択します。
4. 左側メニューの [アクセス制御 (IAM)] を選択します。
5. [アクセスの確認] タブを選択します。
6. [マイ アクセスの表示] を選択します。
7. 割り当ての一覧で、ロール名と割り当てスコープを上表の必要な操作と照合します。
8. 不足する操作権限がある場合は、該当ロール・スコープ・対象工程・管理者への依頼先を共有 Excel に記録します。
9. 専用 RG の作成と RG 内のロール割当を自分で実施できるかを部門管理者に確認します。
10. 自分でできない操作の担当者を共有 Excel に記録します。

> **画面の見え方** PIM を利用している環境では、[アクセスの確認] に直接ロール一覧が表示される場合があります。「資格がある」だけのロールは有効化済みとは限りません。部門で決めた PIM の有効化手順を済ませ、有効な割り当てを確認します。表のロールすべてを一律に追加するのではなく、各操作の権限を既存ロールで満たすか確認します。

> **画面の見え方** このスコープでの割り当てと、上位（管理グループ）から継承した割り当てが一覧に出ます。下位（リソースグループ）だけに付いた割り当ては出ません。リソースグループを作った後に、RG のスコープでも同じ手順で確認します（[第1章 1.3](01-prerequisites.md#rg-スコープの権限の再確認)）。

> **Note** 要確認: 必要ロールのスコープは Learn のページで表現が揺れます（環境セットアップのページは「Foundry Account Owner をサブスクリプション スコープで」、Standard setup の概念ページは「リソースグループの所有者かユーザー アクセス管理者」、公式テンプレート 41 の README は「Foundry Account Owner と Role Based Access Administrator」）。初回で実際に通った組み合わせを記録して確定します。

> **補足** Foundry のロールは 2026 年に改名されました。Foundry User・Foundry Owner・Foundry Account Owner・Foundry Project Manager は、それぞれ旧 Azure AI User・Azure AI Owner・Azure AI Account Owner・Azure AI Project Manager です。ポータルで旧名しか見つからない場合も同じロールです。

## 0.4. 命名規則を決める

形式は `<リソース種別の略称>-<検証者略号>-<環境>-<連番>` です。例は `rg-funato-dev-01` です（`funato` は例示の略号です）。

| 項目 | 値 |
|---|---|
| リソース種別の略称 | 下表の Microsoft Cloud Adoption Framework（CAF）の略称。掲載のない種別はラボ独自の略称 |
| 検証者略号 | 英小文字で、検証者ごとに固定。PJ 名にはしません。下の名前の制約を満たす長さにします（例: Key Vault は略号14文字以内） |
| 環境 | `dev` 固定。この検証は1環境です |
| 連番 | `01` からの2桁。同じ種類を追加・作り直すときに上げます |
| リージョン | Japan East だけなので名前には含めません |

プロジェクトの識別は、第1章の `purpose` タグで行います。

### リソース種別の略称

CAF の「Azure リソースの省略形に関する推奨事項」（取得日 2026-10-14）と照合しています。

| リソース種別 | 略称 |
|---|---|
| リソースグループ | `rg` |
| Log Analytics ワークスペース | `log` |
| Key Vault | `kv` |
| ストレージ アカウント | `st` |
| Azure Cosmos DB for NoSQL アカウント | `cosno` |
| Azure Cosmos DB データベース | `cosmos` |
| AI Search | `srch` |
| Foundry account（AIServices） | `aif` |
| Foundry account の project | `proj`（本編は `proj-<略号>-dev-<連番>`、例 `proj-funato-dev-01`） |
| Application Insights | `appi` |
| 仮想ネットワーク | `vnet` |
| サブネット | `snet` |
| App Service プラン | `asp` |
| App Service（Web アプリ） | `app` |
| API Management | `apim` |
| ユーザー割り当てマネージド ID | `id` |
| 診断設定 | `diag`（CAF の略称表にはない、このラボの決め） |
| Fabric ワークスペース | `ws`（Azure リソースではない、このラボの決め） |
| Entra アプリ登録 | `appreg`（Azure リソースではない、このラボの決め） |
| Azure Policy の割当 | `policy`（CAF の略称表にはない、このラボの決め） |
| ARM デプロイ | `deploy`（CAF の略称表にはない、このラボの決め） |
| 予算（Cost Management） | `budget`（CAF の略称表にはない、このラボの決め） |

### 名前の制約と例外

英小文字を使う本ラボの規則に加え、次のサービス固有の制約を守ります。Azure 全体で一意の名前は、チーム内で重複しなくても使用済みの場合があります。

| 対象 | 文字数・使える文字 | 一意の範囲・例 |
|---|---|---|
| ストレージ アカウント | 3〜24文字。英小文字と数字のみ。区切りのハイフンを除きます | Azure 全体。`stfunatodev01` |
| Key Vault | 3〜24文字。英数字とハイフン。先頭は英字、末尾は英数字、連続ハイフン不可 | Azure 全体。`kv-funato-dev-01` |
| Foundry account／カスタム サブドメイン | 2〜64文字。英数字とハイフン。account 名の先頭・末尾は英数字 | account 名は RG 内、カスタム サブドメインは Azure 全体で一意。本編は `aif-<略号>-dev-<連番>`（例 `aif-funato-dev-01`）。IaC でテンプレート 41 を使う場合だけ `aif`＋略号の 9 文字以内の接頭辞（例 `aiffunato`）＋自動の英数字（[IaC の説明](../infra/README.md#パラメータを確定する)） |
| AI Search | 2〜60文字。英小文字・数字・ハイフン。先頭2文字と末尾は英数字、連続ハイフン不可 | Azure 全体の `search.windows.net` 内。`srch-funato-dev-01` |
| Cosmos DB アカウント | 3〜44文字。英小文字・数字・ハイフン。先頭は英小文字または数字 | Azure 全体。`cosno-funato-dev-01` |
| API Management | 1〜50文字。英数字・ハイフン。先頭は英字、末尾は英数字 | Azure 全体。`apim-funato-dev-01` |
| Cloud Shell 用のリソースグループ | RG の規則と同じ | 検証用 RG とは別に置き、第10章で検証用 RG を削除しても残すため、環境の位置を `shell` にします。`rg-funato-shell-01` |

Key Vault・Foundry account・API Management は、論理削除による保持中は同じ名前を再利用できません。同名で作り直せない場合も連番を上げます。保持の確認は [第10章](10-cleanup-cost.md#論理削除された資産を確認する) で扱います。

1. 自分の検証者略号を決めます。
2. チームの共有 Excel に略号を記録します。
3. 他の人と略号が重複しないことを確認します。
4. 上の表に従い、自分の RG 名（`rg-<略号>-dev-01`）を手元に控えます。

## 0.5. 完了条件

- Azure portal にサインインし、対象テナント・サブスクリプションを照合済みです。
- 自分のロールとスコープを確認済みです。不足する操作権限・対象工程・依頼先は共有 Excel に記録し、依存する構築は保留にしています。
- 自分の検証者略号の重複がなく、命名規則に沿った RG 名を控えています。

## 0.6. うまくいかない場合

| 困ったこと | 最初に確認する場所・内容 | 次の対応と再開条件 |
|---|---|---|
| 対象サブスクリプションが出ない | [設定] → [ディレクトリとサブスクリプション]、使用アカウント | 管理者へ対象 ID とアクセス権の照合を依頼し、結果を記録します。対象が一致してから再開します |
| Entra のテナント ID を閲覧できない | 使用テナントと閲覧権限 | 管理担当者に照合を依頼し、確認結果を非公開で受け取ります。確認だけのために管理権限は追加しません |
| 必要なロールが不足している | 0.3 の必要ロールとスコープ、PIM の有効化状態 | 不足・依頼先・対象工程を共有 Excel に記録し、担当者による実施または権限の確認後に依存工程を再開します |

節・手順番号・期待した表示・実際の表示・確認担当・再確認日を記録します。既存のアクセス制限は変更せず、対象を切り替えた場合は検証用テナント・サブスクリプションへ戻して照合します。

## 0.7. 次の操作

第1章で専用 RG・Log Analytics・予算アラートを作ります。

### 出典

- 出典: [テナント ID を検索する](https://learn.microsoft.com/ja-jp/entra/fundamentals/how-to-find-tenant)（取得日 2026-10-14）
- 出典: [Azure portal の設定](https://learn.microsoft.com/ja-jp/azure/azure-portal/set-preferences)（取得日 2026-10-14）
- 出典: [Azure RBAC のアクセス確認](https://learn.microsoft.com/ja-jp/azure/role-based-access-control/check-access)（取得日 2026-10-14）
- 出典: [Azure ロールの割当](https://learn.microsoft.com/ja-jp/azure/role-based-access-control/role-assignments-portal)（取得日 2026-10-14）
- 出典: [Foundry の RBAC](https://learn.microsoft.com/ja-jp/azure/foundry/concepts/rbac-foundry)（取得日 2026-10-14）
- 出典: [Azure リソースの省略形に関する推奨事項](https://learn.microsoft.com/ja-jp/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations)（取得日 2026-10-14）
- 出典: [名前付け規則を定義する](https://learn.microsoft.com/ja-jp/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming)（取得日 2026-10-14）
- 出典: [Azure リソースの名前付け規則と制限事項](https://learn.microsoft.com/ja-jp/azure/azure-resource-manager/management/resource-name-rules)（取得日 2026-10-14）
- 出典: [Foundry Tools のカスタム サブドメイン](https://learn.microsoft.com/ja-jp/azure/ai-services/cognitive-services-custom-subdomains)（取得日 2026-10-14）
- 出典: [Key Vault の論理削除](https://learn.microsoft.com/ja-jp/azure/key-vault/general/soft-delete-overview)（取得日 2026-10-14）
- 出典: [Foundry リソースの回復と消去](https://learn.microsoft.com/ja-jp/azure/ai-services/recover-purge-resources)（取得日 2026-10-14）
- 出典: [API Management の論理削除](https://learn.microsoft.com/ja-jp/azure/api-management/soft-delete)（取得日 2026-10-14）
- 出典: [Azure built-in roles for Privileged](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged)（取得日 2026-09-15）
- 出典: [Azure built-in roles for Management and governance](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/management-and-governance)（取得日 2026-09-15）
- 出典: [Foundry Agent Service: environment setup](https://learn.microsoft.com/en-us/azure/foundry/agents/environment-setup)（取得日 2026-09-15）
- 出典: [Standard agent setup](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/standard-agent-setup)（取得日 2026-09-15）
- 出典: [foundry-samples 41-standard-agent-setup README（固定コミット）](https://github.com/microsoft-foundry/foundry-samples/blob/58e4127567f7e9afcf0145d874df890284ca5faf/infrastructure/infrastructure-setup-bicep/41-standard-agent-setup/README.md)（取得日 2026-09-15）
- 出典: [AI Search の名前付け規則](https://learn.microsoft.com/ja-jp/rest/api/searchservice/naming-rules)（取得日 2026-10-14）
- 出典: [AI Search のサービス名](https://learn.microsoft.com/ja-jp/azure/search/search-create-service-portal)（取得日 2026-10-14）

---

前へ: [概要](../README.md) / 次へ: [準備と土台](01-prerequisites.md) / [トップに戻る](../README.md)
