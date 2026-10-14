# 3. データ基盤を作る

進め方: README の第0〜10章を順番に実施します。第2章の完了条件を満たしてから進めます。

> **Note** 状態: ドラフト（Learn 2026-09 時点の記述に基づく・未実行）。操作手順の見直し日 2026-09-20。

> **補足** この章では環境を削除しません。通常の削除は最後の第10章です。中断して片付ける場合だけ、第10章へ進みます。

## 3.1. 目的

Foundry に渡す Storage・Cosmos DB・AI Search を、この順に作ります。各リソースの認証と IP 制限を設定してから次へ進みます。この章の到達点はデータ基盤の準備です。エージェントの応答確認は第4章で行います。

### なぜこの作業が必要か

エージェントのガバナンスを考えるときは、応答の内容だけでなく、会話やファイルをどこに置き、誰がアクセスできるかも管理する必要があります。このラボでは、自分たちの Azure リソースを接続する Standard setup を目指すため、接続先を先に作って設定を把握します。[Standard setup の説明](https://learn.microsoft.com/ja-jp/azure/foundry/agents/concepts/standard-agent-setup)に基づく構成です。

| リソース | Standard setup での役割 | この章で準備する理由 |
|---|---|---|
| Storage | ファイルを保存する場所 | ファイルの保存先とアクセス条件を管理するため |
| Cosmos DB | 会話などのエージェントの状態を保存する場所 | 状態の保存先とアクセス条件を管理するため |
| AI Search | ファイル検索で使う検索基盤 | 検索用データの配置先とアクセス条件を管理するため |

この章ではリソースの認証と IP 制限までを揃え、第4章で Foundry に接続します。3 リソースが存在することと、エージェントがそれらを利用できることは別なので、接続成功は次章で確かめます。

## 3.2. 前提

- 第2章が完了し、自分専用の RG が存在します。
- 第1章で確認したリソース作成権限があります。
- 社内の公開 IPv4 の許可リストがあります。
- 各自の非公開 `.env` と `evidence/` を用意しています。
- 同じ RG・Japan East に 3 リソースを作ります。選択できない場合は別リージョンへ変更せず、3.5 で切り分けます。

| 対象 | 今回の設定 | 名前の入力例（置換必須） |
|---|---|---|
| Storage | 汎用 v2 / Standard LRS / Hot | `st<略号>dev01`（以降の `<storage-account-name>`。英小文字・数字、3〜24 文字） |
| Cosmos DB | for NoSQL / Serverless / 単一リージョン | `cosno-<略号>-dev-01`（以降の `<cosmos-account-name>`） |
| AI Search | Basic / レプリカ 1 / パーティション 1 | `srch-<略号>-dev-01`（以降の `<search-service-name>`。英小文字・数字・ハイフン、2〜60 文字） |

> **補足** 公開エンドポイントを有効にすることと、全 IP を許可することは別です。人の入口は社内 IP に制限し、Agent Service 用にはリソース別の例外を設定します。ネットワークの許可があっても、データ操作には別途 Entra ID の権限が必要です。Cloud Shell の送信元は社内 IP ではないため、ここでは管理面の設定確認だけに使います。

3 リソースの名前を非公開の作業メモに先に記入します。以降の `<storage-account-name>` などはその名前に置き換えます。Cloud Shell 用の Storage と、この章で新規作成する Storage を取り違えません。

| 共通のタグ名 | 入力する値 |
|---|---|
| purpose | `agent-governance-lab` |
| run | 今回の Run 番号（初回は `1`） |
| operator | 自分の検証者略号 |
| deleteAfter | 第1章で決めた削除予定日（`YYYY-MM-DD`） |

> **画面の見え方** 「第1章と同じタグ」は上表の 4 組です。RG のタグが各リソースに自動で付くとは考えず、作成画面または作成後の [タグ] で入力・確認します。

## 3.3. 構築

### 3.3.1. Storage を作る

[Storage 作成手順](https://learn.microsoft.com/ja-jp/azure/storage/common/storage-account-create)に沿って、作成時に認証と IP を設定します。

1. Azure portal 上部の検索欄に「ストレージ アカウント」と入力し、検索結果の [ストレージ アカウント] を選択します。
2. [作成] を選択します。
3. [基本] タブに表の値を入力します。

| 項目 | 値 |
|---|---|
| サブスクリプション / リソース グループ | 第1章の検証用サブスクリプション / 自分専用 RG |
| ストレージ アカウント名 | 事前に決めた未使用の名前 |
| リージョン | Japan East |
| 優先ストレージの種類 | BLOB ストレージまたは Azure Data Lake Storage |
| パフォーマンス | Standard |
| 冗長性 | ローカル冗長ストレージ（LRS） |

4. [詳細設定] を開きます。
5. [アクセス階層] を [ホット] にします。
6. [階層型名前空間を有効にする] をオフにします。
7. [SFTP を有効にする] と [NFS v3 を有効にする] がオフであることを、それぞれ確認します。
8. [ネットワーク] を開きます。
9. 次の表に沿って設定します。

| 項目 | 値 |
|---|---|
| パブリック ネットワーク アクセス | 有効 |
| パブリック ネットワーク アクセス スコープ | 特定の仮想ネットワークまたは IP アドレス範囲のみ |
| IPv4 アドレス | 承認済みの社内公開 IPv4 一覧 |
| 仮想ネットワーク / プライベート エンドポイント | 本検証では使わないため追加しない |

> **画面の見え方** IPv4 欄へは `.env` の JSON 配列を丸ごと貼り付けず、公開 IP または CIDR を 1 件ずつ入力します。Storage では単一 IP は `/32` を付けずに入力し、`/31` は 2 つの単一 IP に分けます。登録された範囲を承認済み一覧と照合します。

10. [データ保護] を開き、表示された論理削除の有効／無効・保持日数・バージョン管理等の設定値を非公開の記録に残します。
11. [セキュリティ] を開きます。
12. 次の表に沿って設定します。

| 項目 | 値 |
|---|---|
| REST API 操作の安全な転送を必須にする | オン |
| 個々のコンテナーでの匿名アクセスの有効化を許可する | オフ |
| ストレージ アカウント キーへのアクセスを許可する（項目がある場合） | 無効 |
| デフォルトで Azure ポータルにおいて Microsoft Entra 認証を使用する | オン |
| TLS の最小バージョン | 1.2 |
| Defender for Storage | この章では追加で有効化しない |

13. [暗号化] で Microsoft マネージド キーを選択します。
14. [タグ] に第1章と同じ管理用タグを設定します。
15. [確認と作成] で設定を確認します。
16. 検証が成功したら [作成] を選択します。
17. デプロイ完了後、ポータル上部の検索欄で作成した Storage 名を検索し、対象リソースを開きます。
18. [セキュリティ + ネットワーク] → [ネットワーク] を選択します。
19. [リソース設定: 仮想ネットワーク、IP アドレス、例外] の [表示] を選択します。
20. IP 一覧が社内の一覧だけであることを確認します。
21. [リソース インスタンス] の現在の規則を確認します。
22. この段階では規則を追加せず、表示された一覧を非公開の作業メモに記録します。
23. [設定] > [構成] を開きます。
24. [ストレージ アカウント キーへのアクセスを許可する] を [無効] にします。
25. [保存] を選択します。
26. 保存完了後に別のメニューへ移動し、[構成] を開き直します。
27. キーアクセスが [無効] のままであることを確認します。
28. [タグ] を開き、共通タグ 4 組が保存されていることを確認します。

> **Note** 要確認: B18 — 作成ウィザード側のキーアクセス項目の有無は初回で照合します。項目があれば作成時に無効化し、無ければ作成直後・データ投入前に上記の [構成] で無効化します。

第4章で Foundry account を作成した後、[セキュリティとネットワーク] > [ネットワーク] > リソース設定の [表示] > [リソース インスタンス] に、種類 `Microsoft.CognitiveServices/accounts` と今回の Foundry account を追加します。この章ではまだ存在しない account の規則を追加しません。ネットワーク規則だけではデータ権限が付与されないため、第4章で MI のロールも確認します。

> **補足** データ保護は組織の既定を維持します。論理削除やバージョン管理で保存量が増える場合があるため、設定値を記録します。Cloud Shell が使用する既存 Storage の共有キー設定は変更しません。

> **画面の見え方** 作成後のキー設定は [設定] → [構成] にあります。[Microsoft Entra 認証を既定にする] だけではキーを無効にできません。3.4 で `allowSharedKeyAccess=false` を照合します。

### 3.3.2. Cosmos DB を作る

このドラフトでは、直下の「作成時から IP と認証を制限する portal 代替」を使用します。通常の作成ウィザードへ入力してから取り消す操作は不要です。

> **Note** 要確認: 通常ウィザードの作成時に社内 IP と Azure データセンター内許可を設定できるかは、公式資料で画面の詳細まで確認できていません。そのため、現時点では下記のテンプレート編集を作成経路にしています。実機でウィザードの制限設定を確認できたら通常の GUI 手順へ置き換えます。すでに通常ウィザードを開いている場合は [作成] を押さずに閉じます。

#### 作成時から IP と認証を制限する portal 代替

通常ウィザードの不足部分に限り、公式の [portal テンプレート編集](https://learn.microsoft.com/ja-jp/azure/azure-resource-manager/templates/deploy-portal)を使います。設定は次の JSON で確認でき、CLI によるデプロイや一括環境作成は行いません。Cosmos DB アカウント 1 個だけを作ります。

1. Azure portal の [リソースの作成] で「テンプレートのデプロイ」を検索します。
2. 検索結果の [テンプレートのデプロイ（カスタム テンプレートを使用したデプロイ）] を開き、[作成] を選択します。
3. [エディターで独自のテンプレートを作成する] を選択します。
4. エディター内の既存の内容を全選択し、次の JSON 全体に置き換えます（コードブロックの囲み記号は含めません）。

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "resourceName": {
      "type": "string"
    },
    "location": {
      "type": "string",
      "defaultValue": "japaneast"
    },
    "allowedIpRules": {
      "type": "array",
      "minLength": 1
    }
  },
  "resources": [
    {
      "type": "Microsoft.DocumentDB/databaseAccounts",
      "apiVersion": "2024-11-15",
      "name": "[parameters('resourceName')]",
      "location": "[parameters('location')]",
      "kind": "GlobalDocumentDB",
      "properties": {
        "databaseAccountOfferType": "Standard",
        "capabilities": [
          {
            "name": "EnableServerless"
          }
        ],
        "consistencyPolicy": {
          "defaultConsistencyLevel": "Session"
        },
        "locations": [
          {
            "locationName": "[parameters('location')]",
            "failoverPriority": 0,
            "isZoneRedundant": false
          }
        ],
        "disableLocalAuth": true,
        "publicNetworkAccess": "Enabled",
        "ipRules": "[parameters('allowedIpRules')]",
        "networkAclBypass": "None",
        "isVirtualNetworkFilterEnabled": false,
        "enableFreeTier": false
      }
    }
  ]
}
```
実行結果の確認ポイント: JSON の入力エラーがなく、作成対象が Cosmos DB アカウント 1 個、Serverless、キー無効であることを確認します。名前と IP の実値は次のパラメーター画面で入力します。

5. [保存] を選択します。
6. [カスタム デプロイ] の入力画面で、次の表の値を入力します。

| 項目 | 値 |
|---|---|
| サブスクリプション | 第1章で選んだ検証用サブスクリプション |
| リソース グループ | 第1章の自分専用 RG |
| Resource Name | 作成前に決めた未使用の名前 |
| Location | `japaneast` |
| Allowed Ip Rules | 社内の公開 IPv4 と Azure データセンター内許可 `0.0.0.0` の配列 |

`Allowed Ip Rules` には次の配列を入力します。`<corporate-public-ipv4-cidr>` を実際の社内 CIDR に置き換えます。この入力欄へテンプレート全体は貼りません。

```json
[{"ipAddressOrRange":"<corporate-public-ipv4-cidr>"},{"ipAddressOrRange":"0.0.0.0"}]
```
実行結果の確認ポイント: 配列に未置換のプレースホルダーが残らず、承認済みの社内 IP と `0.0.0.0` だけが含まれることを確認します。

7. IP が複数ある場合は配列内に同じ形式のオブジェクトを追加します。
8. IP 一覧が社内の許可リストと `0.0.0.0` に一致することを確認します。
9. [確認と作成] を選択します。
10. 対象 RG・リソース名・料金対象を確認します。
11. 検証が成功したら [作成] を選択します。
12. デプロイ完了を待ちます。

> **補足** 空配列・全許可の範囲・社内 LAN のプライベート IP は入力しません。テンプレートの配列長制約だけでは IP の妥当性や社内承認まで検証できません。既存リソース名を指定すると更新になるため、新規の専用名だけを使います。

#### 作成後の設定を確認する

1. ポータル上部の検索欄で作成した Cosmos DB アカウント名を検索します。
2. 対象アカウントを開き、[概要] で名前・RG・リージョンを確認します。
3. 左側メニューの [ネットワーク] を選択します。
4. [アクセスを許可する] が [選択したネットワーク] であることを確認します。
5. 許可 IP の一覧が社内公開 IPv4／CIDR と一致することを確認します。
6. [Accept connections from within Azure datacenters] がオンであることを確認します。
7. 相違があればテンプレートへの入力内容と照合し、下表の目標値へ修正して [保存] を選択します。
8. [ネットワーク] を開き直し、設定が維持されていることを確認します。
9. [タグ] を開きます。
10. 3.2 の共通タグ 4 組を入力します。
11. [適用] または [保存] を選択し、タグが残ることを確認します。
12. 3.4 の管理面の確認で Serverless・キー無効・`0.0.0.0` を照合します。

> **画面の見え方** テンプレートで設定済みのため、社内 IP を重複追加する必要はありません。特別な値 `0.0.0.0` はチェック項目側に対応します。IP の一覧表示だけで消えていると判断せず、3.4 の `ipRules` と照合します。

| 項目 | 値 |
|---|---|
| 公開ネットワーク | 選択したネットワーク。Disabled にしない |
| IP 規則 | 社内公開 CIDR と `0.0.0.0` |
| Azure データセンター内からの接続を受け入れる | オン（A11） |
| キーベースの認証 | 無効を維持 |

> **Note** 要確認: 英語項目 [Accept connections from within Azure datacenters] の日本語表示は初回に照合します。

> **補足** `0.0.0.0` は Azure データセンター内からの接続を許可する特別な値です。Azure 内の他社のサブスクリプションからも到達できますが、認証トークンは常に必須です。インターネット全公開ではないものとして採用します（A11）。この設定で Azure portal からも自動的に届くため、Data Explorer 用のミドルウェア IP を別途追加する必要はありません。ネットワーク許可とデータ面の閲覧権限は別です。

> **Note** プライベート IP を IP 許可リストに書くと作成／更新が失敗します。反映には最大15分かかります。Serverless は単一リージョンで使い、Provisioned の RU/s は入力しません。

第7章で App Service の統合サブネットを仮想ネットワーク規則として追加します。この章では追加しません（A14）。

### 3.3.3. AI Search を作る

作成ウィザードにはキー無効化の項目がないため、[通常の作成手順](https://learn.microsoft.com/ja-jp/azure/search/search-create-service-portal)で作成し、直後・データ投入前にネットワークと認証を設定します。

1. Azure portal 上部の検索欄に「Azure AI Search」と入力し、検索結果のサービス一覧を開きます。
2. [作成] を選択します。
3. [基本] に表の値を入力します。

| 項目 | 値 |
|---|---|
| サブスクリプション | 第1章の検証用サブスクリプション |
| リソース グループ | 今回の実施者専用 RG |
| サービス名 | `<search-service-name>` |
| リージョン | Japan East |
| 価格レベル | Basic |

4. [確認と作成] で対象と Basic を照合します。
5. [作成] を選択します。
6. デプロイ完了後、ポータル上部の検索で作成した Search 名を開き、[設定] > [ネットワーク] を選択します。
7. [パブリック ネットワーク アクセス] を [選択した IP アドレス] にします。
8. 社内公開 CIDR を IP 規則へ 1 件ずつ追加し、承認済み一覧と照合します。
9. [Exceptions] の [Allow Azure services on the trusted services list to access this search service] をオンにします。
10. [保存] を選択します。
11. [設定] > [キー] を開きます。
12. API アクセス制御の [ロールベースのアクセス制御] を選択します。
13. [キー] を開き直し、[両方] ではなく RBAC のみの選択が維持されていることを確認します。
14. [設定] > [スケール] を開きます。
15. レプリカ数とパーティション数がそれぞれ `1` であることを確認します。
16. [タグ] を開きます。
17. 3.2 の共通タグ 4 組を入力します。
18. [適用] または [保存] を選択し、タグが残ることを確認します。

| 項目 | 値 |
|---|---|
| パブリック ネットワーク アクセス | 選択した IP アドレス＋社内 CIDR |
| 信頼されたサービス一覧の Azure サービスからのアクセスを許可する | オン |
| API アクセス制御 | ロールベースのアクセス制御のみ。[両方] は使わない |
| レプリカ / パーティション | 1 / 1 |

> **Note** 要確認: [Exceptions] と [Allow Azure services on the trusted services list to access this search service] の日本語表示は初回に照合します。

> **補足** 信頼サービス一覧には `Microsoft.CognitiveServices`（Azure OpenAI と Foundry Tools）が含まれます。Foundry のマネージド ID と Search 上のロールが必要で、第4章で割り当てます。ネットワークの反映は最大15分、RBAC の反映は5〜10分が目安です。RBAC のみへの切替は即時で、自分がデータを操作する場合もデータ面ロールが必要です。この章ではデータを投入しません。

GUI で認証を変更できない場合だけ、Cloud Shell（Bash）で代替します。`<rg>` と `<search-service-name>` は今回の RG 名・Search 名に置き換えます。すでに RBAC のみなら実行しません。

```bash
az search service update --resource-group '<rg>' --name '<search-service-name>' --disable-local-auth true
```
実行結果の確認ポイント: 対象 Search の `disableLocalAuth` が `true` で、ネットワーク規則を維持していることを確認します。

#### 作成後の設定を確認する

1. [設定] > [キー] で [ロールベースのアクセス制御] を確認します。
2. [設定] > [ネットワーク] で社内 CIDR と信頼サービス例外がオンであることを確認します。
3. 3.4 の管理面の確認で Basic・レプリカ 1・パーティション 1・キー無効を照合します。

### 3.3.4. 次章へ渡す ID を記録する

1. ポータル上部の検索で、今回作成した Storage を開きます。
2. [概要] でリソース名・RG・サブスクリプションを照合します。
3. [JSON ビュー] を開きます。
4. リソース全体の `id`（`/subscriptions/` から始まる ARM ID）を非公開の作業メモへコピーします。
5. Cosmos DB と AI Search についても手順 1〜4 を繰り返します。
6. Cloud Shell を Bash で開きます。
7. 第1章で取得した手順リポジトリへ移動します。

```bash
cd ~/azure-agent-governance-lab
```
実行結果の確認ポイント: エラーなく移動できることを確認します。

8. 設定ファイルを開きます。

```bash
code .env
```
実行結果の確認ポイント: 第1章の値が入った既存の `.env` が開くことを確認します。

9. 次の 3 変数の既存行を探し、引用符を残したまま `=` の右側を今回の ARM ID に置き換えます。

| 項目 | 値 |
|---|---|
| `AZURE_STORAGE_ACCOUNT_RESOURCE_ID` | 今回作成した Storage の ARM ID |
| `AZURE_COSMOS_DB_ACCOUNT_RESOURCE_ID` | 今回作成した Cosmos DB の ARM ID |
| `AI_SEARCH_RESOURCE_ID` | 今回作成した Search の ARM ID |

10. Ctrl+S で保存します。
11. Ctrl+Q でエディターを閉じます。
12. 更新した設定を読み込みます。

```bash
source .env
```
実行結果の確認ポイント: 構文エラーがないことを確認します。ID の一致は次節の照合で確認します。

> **Note** 要確認: リソースの種類によって [JSON ビュー] の位置が異なる場合は初回に記録します。見つからなければ [プロパティ] のリソース ID 欄を確認します。URL エンドポイントや接続文字列を ARM ID の代わりに転記しません。

キー・接続文字列は取得しません（例外は第4章の Foundry account の 401 確認だけ）。作成画面や JSON の実値を GitHub に貼り付けません。

> **補足** D14 の App Service 統合サブネットは、第7章の App Service → Foundry 用です。Agent Service がこのサブネットから発信するわけではないため、本章のデータ基盤への到達条件は解決しません。Agent Service の経路は上記のリソース別設定と第4章 C08 で確認します。A14 のアプリ → Cosmos は別の VNet 規則で許可します。

## 3.4. 完了条件

Azure Cloud Shell の [Bash] で確認します。各コマンドの ID を、3.3.4 で記録した対象の ARM ID に置換します。すべて読み取り操作です。

### Storage

```bash
az resource show --ids "<storage-resource-id>" --api-version 2023-05-01 --query '{id:id,location:location,kind:kind,sku:sku.name,hot:properties.accessTier,sharedKey:properties.allowSharedKeyAccess,anonymousBlob:properties.allowBlobPublicAccess,https:properties.supportsHttpsTrafficOnly,tls:properties.minimumTlsVersion,publicAccess:properties.publicNetworkAccess,network:properties.networkAcls}' --output json
```
実行結果の確認ポイント: `StorageV2`・`Standard_LRS`・`Hot`・sharedKey=false・anonymousBlob=false・https=true・TLS1_2・publicAccess=Enabled・network.defaultAction=Deny・社内 IP 規則を照合し、Foundry のリソース インスタンス規則は第4章で追加することを照合します。

### Cosmos DB

```bash
az resource show --ids "<cosmos-resource-id>" --api-version 2024-11-15 --query '{id:id,location:location,kind:kind,capabilities:properties.capabilities,locations:properties.locations,consistency:properties.consistencyPolicy.defaultConsistencyLevel,disableLocalAuth:properties.disableLocalAuth,publicAccess:properties.publicNetworkAccess,ipRules:properties.ipRules,bypass:properties.networkAclBypass}' --output json
```
実行結果の確認ポイント: `GlobalDocumentDB`・EnableServerless・Japan East の1リージョン・Session・disableLocalAuth=true・publicAccess=Enabled・社内 IP と `0.0.0.0` の IP 規則を照合します。

### AI Search

```bash
az resource show --ids "<search-resource-id>" --api-version 2025-05-01 --query '{id:id,location:location,sku:sku.name,replicas:properties.replicaCount,partitions:properties.partitionCount,disableLocalAuth:properties.disableLocalAuth,publicAccess:properties.publicNetworkAccess,network:properties.networkRuleSet}' --output json
```
実行結果の確認ポイント: basic・レプリカ1・パーティション1・disableLocalAuth=true・publicAccess=Enabled・社内 IP 規則・信頼サービス例外がオンであることを照合します。

- [ ] 3 リソースが自分専用 RG に存在します。
- [ ] 3 リソースの SKU / 容量方式と認証設定が一致します。
- [ ] 社内 IP 規則を維持し、Cosmos DB には承認済みの `0.0.0.0` があります。
- [ ] Search の信頼サービス例外がオンです。
- [ ] Storage の Foundry リソース インスタンス規則は第4章で追加すると記録しました。
- [ ] 3 リソースに共通タグ 4 組が保存されています。
- [ ] 3 つの ARM ID を非公開 `.env` に記録し、保存後に読み込みました。
- [ ] 確認結果と作成日時を非公開 `evidence/` に記録しました。

期待した項目が `null` の場合は成功扱いにしません。管理面の設定確認は、ネットワーク遮断やエージェント動作の実証とは区別します。

## 3.5. うまくいかない場合

| 症状 | 最初に確認すること | 次の対応 |
|---|---|---|
| 作成できない | 対象 RG・作成権限・Policy の拒否理由 | 管理者へ対象 RG の条件を確認します |
| Japan East / Basic / Serverless が選べない | リージョン提供状況・クォータ | その場で SKU を変更せず、検証の費用と Foundry 接続条件を再確認します |
| IP の入力が拒否される | 公開 IPv4 / CIDR の形式 | Storage で単一 IP は CIDR の `/32` ではなく単一アドレスで指定します。`/31` は 2 つの単一 IP に分けます |
| 作成ウィザードに必要な項目がない | Learn と実機の UI の違い | Cosmos DB の IP は章内の portal 代替、Storage のキーは作成直後の [構成]、Search は作成直後の [キー] を使います。Foundry のキーは第4章の Cloud Shell で無効化します |
| データ参照が 403 になる | 送信元 IP・データ操作権限・反映待ち | Cosmos の `0.0.0.0`・Search の信頼サービス例外・データ面ロールを確認します。Storage の Foundry 規則は第4章で追加します |
| 設定変更後も表示が変わらない | 保存成功・対象リソース | Cosmos DB / Search のネットワーク設定は 15 分待ってから再確認します |

1. 気づいた時点で章番号・操作番号・期待と実際を共有 Excel へ記録し、詳細な証跡を非公開 `evidence/` に残します。
2. 手順修正・計画見直しが必要なら担当者が GitHub Issue へ転記します。Excel にはリンクと「GitHubで管理」を残し、実在の ID・IP・アカウント情報は Issue に書きません。
3. 誤って追加した IP や例外は、この章の目標値へ戻します。
4. 本章の完了条件を満たすまで次章へ進みません。

## 3.6. 次の操作

データ基盤を残して、第4章で Foundry を作成します。3 つの ARM ID を接続に使用します。Foundry の ID が作成された後に必要な権限とサービス間接続を設定するため、第5章を先に実行して戻る必要はありません。

> **Note** サービス到達を許す設定は Learn で確定しました。IP 制限下で 3 リソースへ実際に到達するかは第4章 C08 の初回実行で確認します。成立しない場合は Standard setup から Basic setup へ分岐し、Cosmos だけを外した Standard setup は作りません。

## 3.7. 費用

Fabric 容量の費用は既存見積りに含まれません。事前確認済みの容量を使い、利用可否・費用負担・期間は課長判断とします。金額は要見積りです。

| Excel v3 明細 No | 項目 | 通常月 USD |
|---|---|---:|
| 2 | Azure Cosmos DB / サーバーレス RU | 0.285000 |
| 3 | Azure Cosmos DB / サーバーレス Storage | 0.282500 |
| 4 | Storage account / Standard LRS Hot | 0.200000 |
| 8 | AI Search / Basic 常時分 | 0.000000 |
| 12 | AI Search / Basic 検証日分 | 4.256000 |

2026-09-15 の見積り v3 の既定値です。Japan East、原則 32h/月の検証、CSPM は既定 OFF です。No.8 と No.12 は常時／検証日の切替で、二重計上しません。No.6 は第1章/第6章の共通費です。見積り保証ではありません。

AI Search はサービスを保持している時間の課金に注意します。上の検証日分は 32 時間の想定であり、本章から第10章まで数日間残した場合の料金を保証しません。


## 3.8. 本番との差・IaC で再現する (任意)

本番では負荷・復旧要件に合わせて Search S1、Provisioned Cosmos 3000 RU/s、Storage GRS と閉域接続を設計します。[付録 B](92-appendix-production-diff.md) を参照します。

### IaC で再現する (任意)

[04_data.bicep](../infra/modules/04_data.bicep) は参考です。現在のモジュールは今回のリソース別設定と D14・D15・D16 の再現を保証するものではありません。GUI で作成済みの環境に重ねてデプロイしません。モジュールと接続条件の整合が取れるまで、既存のデプロイスクリプトの停止点を維持します。

### 出典

- 出典: [Standard setup とデータ基盤の役割](https://learn.microsoft.com/ja-jp/azure/foundry/agents/concepts/standard-agent-setup)（取得日 2026-09-15）

- 出典: [Storage のネットワーク制限事項](https://learn.microsoft.com/ja-jp/azure/storage/common/storage-network-security-limitations)（取得日 2026-09-15）
- 出典: [Storage のネットワーク例外の管理](https://learn.microsoft.com/ja-jp/azure/storage/common/storage-network-security-manage-exceptions)（取得日 2026-09-15）

- 出典: [Storage の作成](https://learn.microsoft.com/ja-jp/azure/storage/common/storage-account-create)（取得日 2026-09-20）
- 出典: [Storage の共有キー無効化](https://learn.microsoft.com/ja-jp/azure/storage/common/shared-key-authorization-prevent)（取得日 2026-09-20）
- 出典: [Storage の IP 規則](https://learn.microsoft.com/ja-jp/azure/storage/common/storage-network-security-ip-address-range)（取得日 2026-09-20）
- 出典: [Storage ARM 2023-05-01](https://learn.microsoft.com/ja-jp/azure/templates/microsoft.storage/2023-05-01/storageaccounts)（取得日 2026-09-15）
- 出典: [Cosmos DB の portal 作成](https://learn.microsoft.com/ja-jp/azure/cosmos-db/quickstart-portal)（取得日 2026-09-15）
- 出典: [Cosmos DB Serverless](https://learn.microsoft.com/ja-jp/azure/cosmos-db/serverless)（取得日 2026-09-15）
- 出典: [Cosmos DB のキー無効化と RBAC](https://learn.microsoft.com/ja-jp/azure/cosmos-db/nosql/how-to-connect-role-based-access-control)（取得日 2026-09-15）
- 出典: [Cosmos DB の IP 制御](https://learn.microsoft.com/ja-jp/azure/cosmos-db/how-to-configure-firewall)（取得日 2026-09-20）
- 出典: [Cosmos DB ARM 2024-11-15](https://learn.microsoft.com/ja-jp/azure/templates/microsoft.documentdb/2024-11-15/databaseaccounts)（取得日 2026-09-15）
- 出典: [Search の作成](https://learn.microsoft.com/ja-jp/azure/search/search-create-service-portal)（取得日 2026-09-20）
- 出典: [Search のロール認証](https://learn.microsoft.com/ja-jp/azure/search/search-security-enable-roles)（取得日 2026-09-20）
- 出典: [Search の IP 制御とサービス例外](https://learn.microsoft.com/ja-jp/azure/search/service-configure-firewall)（取得日 2026-09-20）
- 出典: [Search ARM 2025-05-01](https://learn.microsoft.com/ja-jp/azure/templates/microsoft.search/2025-05-01/searchservices)（取得日 2026-09-15）
- 出典: [portal からテンプレートをデプロイ](https://learn.microsoft.com/ja-jp/azure/azure-resource-manager/templates/deploy-portal)（取得日 2026-09-20）
- 出典: [az resource show](https://learn.microsoft.com/ja-jp/cli/azure/resource)（取得日 2026-09-15）

- 出典: [Search の信頼サービス例外](https://learn.microsoft.com/en-us/azure/search/service-configure-firewall)（取得日 2026-09-20）
- 出典: [Storage の信頼サービス](https://learn.microsoft.com/en-us/azure/storage/common/storage-network-security-trusted-azure-services)（取得日 2026-09-19）
- 出典: [Storage のリソース インスタンス規則](https://learn.microsoft.com/en-us/azure/storage/common/storage-network-security-resource-instances)（取得日 2026-09-19）
- 出典: [Cosmos DB の IP 制御](https://learn.microsoft.com/en-us/azure/cosmos-db/how-to-configure-firewall)（取得日 2026-09-20）
- 出典: [Cosmos DB のキー無効化](https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/how-to-connect-role-based-access-control)（取得日 2026-09-19）
- 出典: [Storage のキー無効化](https://learn.microsoft.com/en-us/azure/storage/common/shared-key-authorization-prevent)（取得日 2026-09-20）
- 出典: [Search の RBAC のみへの切替](https://learn.microsoft.com/en-us/azure/search/search-security-enable-roles)（取得日 2026-09-20）

- 出典: [az search service update](https://learn.microsoft.com/en-us/cli/azure/search/service?view=azure-cli-latest)（取得日 2026-09-19）

---

前へ: [Key Vault を準備する](02-key-vault.md) / 次へ: [Foundry とエージェントを作る](04-foundry-agent.md) / [トップに戻る](../README.md)
