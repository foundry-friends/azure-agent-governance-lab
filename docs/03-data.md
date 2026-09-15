# 3. データ基盤を作る

進め方: README の第0〜10章を順番に実施します。第2章の完了条件を満たしてから進めます。

> **Note** 状態: ドラフト（Learn 2026-09 時点の記述に基づく・未実行）

> **補足** この章では環境を削除しません。通常の削除は最後の第10章です。中断して片付ける場合だけ、第10章へ進みます。

## 3.1. 目的

Foundry に渡す Storage・Cosmos DB・AI Search を、この順に作ります。各リソースの認証と IP 制限を設定してから次へ進みます。この章の到達点はデータ基盤の準備です。エージェントの応答確認は第4章で行います。

## 3.2. 前提

- 第2章が完了し、自分専用の RG が存在します。
- 第1章で確認したリソース作成権限があります。
- 社内の公開 IPv4 の許可リストがあります。
- 各自の非公開 `.env` と `evidence/` を用意しています。
- 同じ RG・Japan East に3リソースを作ります。選択できない場合は別リージョンへ変更せず、3.5で切り分けます。

| 対象 | 今回の設定 | 名前の入力例（置換必須） |
|---|---|---|
| Storage | 汎用 v2 / Standard LRS / Hot | `<storage-account-name>`（英小文字・数字、3〜24文字） |
| Cosmos DB | for NoSQL / Serverless / 単一リージョン | `<cosmos-account-name>` |
| AI Search | Basic / レプリカ1 / パーティション1 | `<search-service-name>`（英小文字・数字・ハイフン、2〜60文字） |

> **補足** 公開エンドポイントを有効にすることと、全 IP を許可することは別です。本章は社内 IP のみを許可します。ネットワークの許可があっても、データ操作には別途 Entra ID の権限が必要です。Cloud Shell の送信元は社内 IP ではないため、ここでは管理面の設定確認だけに使います。

## 3.3. 構築

### 3.3.1. Storage を作る

[Storage 作成手順](https://learn.microsoft.com/ja-jp/azure/storage/common/storage-account-create)に沿って、作成時に認証と IP を設定します。

1. Azure portal で [ストレージ アカウント] を開きます。
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

10. [データ保護] の設定値を非公開の記録に残します。
11. [セキュリティ] を開きます。
12. 次の表に沿って設定します。

| 項目 | 値 |
|---|---|
| REST API 操作の安全な転送を必須にする | オン |
| 個々のコンテナーでの匿名アクセスの有効化を許可する | オフ |
| ストレージ アカウント キーへのアクセスを有効にする | オフ |
| デフォルトで Azure ポータルにおいて Microsoft Entra 認証を使用する | オン |
| TLS の最小バージョン | 1.2 |
| Defender for Storage | この章では追加で有効化しない |

13. [暗号化] で Microsoft マネージド キーを選択します。
14. [タグ] に第1章と同じ管理用タグを設定します。
15. [確認と作成] で設定を確認します。
16. 検証が成功したら [作成] を選択します。
17. デプロイ完了後にリソースを開きます。
18. [セキュリティ + ネットワーク] → [ネットワーク] を選択します。
19. [リソース設定: 仮想ネットワーク、IP アドレス、例外] の [表示] を選択します。
20. IP 一覧が社内の一覧だけであることを確認します。
21. [例外] のチェックをすべて外します。
22. リソースインスタンスの許可が追加されていないことを確認します。
23. [保存] を選択します。

> **補足** データ保護は組織の既定を維持します。論理削除やバージョン管理で保存量が増える場合があるため、設定値を記録します。Cloud Shell が使用する既存 Storage の共有キー設定は変更しません。

> **画面の見え方** 作成後のキー設定は [設定] → [構成] にあります。[Microsoft Entra 認証を既定にする] だけではキーを無効にできません。3.4で `allowSharedKeyAccess=false` を照合します。

### 3.3.2. Cosmos DB を作る

1. Azure portal で [Azure Cosmos DB] を開きます。
2. [作成] から [Azure Cosmos DB for NoSQL] を選択します。
3. [基本] に自分専用 RG・アカウント名・Japan East を入力します。
4. 容量の選択で [サーバーレス] を選択します。
5. [セキュリティ] の [キーベースの認証] を [無効] にします。
6. 作成前のネットワーク設定で、社内 IP だけの許可リストを指定できるか確認します。

> **Note** 要確認: Learn では作成後の [ネットワーク] と IP 規則は確認できましたが、作成ウィザードで社内 IP を指定する画面の詳細までは裏付けを取れていません。未設定のまま [作成] を押しません。現時点のドラフトではウィザードをキャンセルし、直下の portal 代替で作成します。実機で作成時の制限を確認できたら、この分岐を通常の GUI 手順へ置き換えます。

#### 作成時から IP と認証を制限する portal 代替

通常ウィザードの不足部分に限り、公式の [portal テンプレート編集](https://learn.microsoft.com/ja-jp/azure/azure-resource-manager/templates/deploy-portal)を使います。設定は次の JSON で確認でき、CLI によるデプロイや一括環境作成は行いません。Cosmos DB アカウント1個だけを作ります。

1. Azure portal の [リソースの作成] で [テンプレートのデプロイ] を検索します。
2. [作成] を選択します。
3. [エディターで独自のテンプレートを作成する] を選択します。
4. エディターの内容を次の JSON に置き換えます。

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

5. [保存] を選択します。
6. 表の値を入力します。

| 項目 | 値 |
|---|---|
| サブスクリプション | 第1章で選んだ検証用サブスクリプション |
| リソース グループ | 第1章の自分専用 RG |
| Resource Name | 作成前に決めた未使用の名前 |
| Location | `japaneast` |
| Allowed Ip Rules | 下の形式で社内の公開 IPv4 を入力した配列 |

```json
[{"ipAddressOrRange":"<corporate-public-ipv4-cidr>"}]
```

7. IP が複数ある場合は配列内に同じ形式のオブジェクトを追加します。
8. IP 一覧が承認済みの一覧と一致することを確認します。
9. [確認と作成] を選択します。
10. 対象 RG・リソース名・料金対象を確認します。
11. 検証が成功したら [作成] を選択します。
12. デプロイ完了を待ちます。

> **補足** 空配列・全許可の範囲・社内 LAN のプライベート IP は入力しません。テンプレートの配列長制約だけでは IP の妥当性や社内承認まで検証できません。既存リソース名を指定すると更新になるため、新規の専用名だけを使います。

#### 作成後の設定を確認する

1. 作成した Cosmos DB を開きます。
2. [ネットワーク] を選択します。
3. [アクセスを許可する] が [選択したネットワーク] であることを確認します。
4. 許可 IP が社内の一覧だけであることを確認します。
5. Azure データセンター内からの接続許可がオフであることを確認します。
6. Azure portal ミドルウェア IP が追加されていないことを確認します。
7. [タグ] に第1章と同じ管理用タグを設定します。
8. 3.4の管理面の確認で Serverless とキー無効を照合します。

> **補足** Azure データセンターからの許可は、特定の Foundry だけを許可する設定ではありません。Azure portal ミドルウェア IP の追加も社内 IP 以外への例外になるため、この章では追加しません。データ エクスプローラーが開けなくても、確認のためにこれらをオンにしません。Serverless は単一リージョンで使い、プロビジョニングする RU/s は入力しません。

### 3.3.3. AI Search を作る

[通常の作成手順](https://learn.microsoft.com/ja-jp/azure/search/search-create-service-portal)では作成後に認証を変更します。本検証では作成時から `disableLocalAuth=true` と社内 IP 一覧を指定するため、Cosmos DB と同じ portal のテンプレート編集を使います。Search サービス1個だけを作ります。

> **Note** 要確認: 通常の Search 作成ウィザードで、作成時に IP 制限とキー無効を同時に設定する画面の詳細は未確認です。以下は GA の ARM プロパティに基づく代替ドラフトであり、portal でのデプロイ成功は未検証です。

1. Azure portal の [リソースの作成] で [テンプレートのデプロイ] を検索します。
2. [作成] を選択します。
3. [エディターで独自のテンプレートを作成する] を選択します。
4. エディターの内容を次の JSON に置き換えます。

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
      "type": "Microsoft.Search/searchServices",
      "apiVersion": "2025-05-01",
      "name": "[parameters('resourceName')]",
      "location": "[parameters('location')]",
      "identity": {
        "type": "SystemAssigned"
      },
      "sku": {
        "name": "basic"
      },
      "properties": {
        "replicaCount": 1,
        "partitionCount": 1,
        "disableLocalAuth": true,
        "publicNetworkAccess": "Enabled",
        "networkRuleSet": {
          "bypass": "None",
          "ipRules": "[parameters('allowedIpRules')]"
        }
      }
    }
  ]
}
```

5. [保存] を選択します。
6. 表の値を入力します。

| 項目 | 値 |
|---|---|
| サブスクリプション | 第1章で選んだ検証用サブスクリプション |
| リソース グループ | 第1章の自分専用 RG |
| Resource Name | 作成前に決めた未使用の名前 |
| Location | `japaneast` |
| Allowed Ip Rules | 下の形式で社内の公開 IPv4 を入力した配列 |

```json
[{"value":"<corporate-public-ipv4-cidr>"}]
```

7. IP が複数ある場合は配列内に同じ形式のオブジェクトを追加します。
8. IP 一覧が承認済みの一覧と一致することを確認します。
9. [確認と作成] を選択します。
10. 対象 RG・リソース名・料金対象を確認します。
11. 検証が成功したら [作成] を選択します。
12. デプロイ完了を待ちます。

> **補足** 空配列・全許可の範囲・社内 LAN のプライベート IP は入力しません。テンプレートの配列長制約だけでは IP の妥当性や社内承認まで検証できません。既存リソース名を指定すると更新になるため、新規の専用名だけを使います。

#### 作成後の設定を確認する

1. 作成した Search を開きます。
2. [設定] → [キー] を選択します。
3. [ロールベースのアクセス制御] であることを確認します。
4. [設定] → [ネットワーク] を選択します。
5. [パブリック ネットワーク アクセス] が [選択した IP アドレス] であることを確認します。
6. 許可 IP が社内の一覧だけであることを確認します。
7. 信頼された Azure サービスの例外がオフであることを確認します。
8. [設定] → [スケール] でレプリカ1・パーティション1を確認します。
9. [タグ] に第1章と同じ管理用タグを設定します。

> **補足** [両方] は API キーも許可する設定なので使いません。Basic は IP 制限に対応します。この章ではインデックスやサンプルデータを作りません。データ操作権限をまだ割り当てていないため、検索できることを完了条件にしません。

### 3.3.4. 次章へ渡す ID を記録する

1. 各リソースの [JSON ビュー] で ARM ID を確認します。
2. 各自の非公開 `.env` の次の項目へ転記します。

| 項目 | 値 |
|---|---|
| `AZURE_STORAGE_ACCOUNT_RESOURCE_ID` | 今回作成した Storage の ARM ID |
| `AZURE_COSMOS_DB_ACCOUNT_RESOURCE_ID` | 今回作成した Cosmos DB の ARM ID |
| `AI_SEARCH_RESOURCE_ID` | 今回作成した Search の ARM ID |

キー・接続文字列は取得しません。作成画面や JSON の実値を GitHub に貼り付けません。

## 3.4. 完了条件

Azure Cloud Shell の [Bash] で確認します。各コマンドの ID を、3.3.4で記録した対象の ARM ID に置換します。すべて読み取り操作です。

### Storage

```bash
az resource show --ids "<storage-resource-id>" --api-version 2023-05-01 --query '{id:id,location:location,kind:kind,sku:sku.name,hot:properties.accessTier,sharedKey:properties.allowSharedKeyAccess,anonymousBlob:properties.allowBlobPublicAccess,https:properties.supportsHttpsTrafficOnly,tls:properties.minimumTlsVersion,publicAccess:properties.publicNetworkAccess,network:properties.networkAcls}' --output json
```
実行結果の確認ポイント: `StorageV2`・`Standard_LRS`・`Hot`・sharedKey=false・anonymousBlob=false・https=true・TLS1_2・publicAccess=Enabled・network.defaultAction=Deny・network.bypass=None・社内 IP のみを照合します。

### Cosmos DB

```bash
az resource show --ids "<cosmos-resource-id>" --api-version 2024-11-15 --query '{id:id,location:location,kind:kind,capabilities:properties.capabilities,locations:properties.locations,consistency:properties.consistencyPolicy.defaultConsistencyLevel,disableLocalAuth:properties.disableLocalAuth,publicAccess:properties.publicNetworkAccess,ipRules:properties.ipRules,bypass:properties.networkAclBypass}' --output json
```
実行結果の確認ポイント: `GlobalDocumentDB`・EnableServerless・Japan East の1リージョン・Session・disableLocalAuth=true・publicAccess=Enabled・社内 IP のみ・bypass=None を照合します。

### AI Search

```bash
az resource show --ids "<search-resource-id>" --api-version 2025-05-01 --query '{id:id,location:location,sku:sku.name,replicas:properties.replicaCount,partitions:properties.partitionCount,disableLocalAuth:properties.disableLocalAuth,publicAccess:properties.publicNetworkAccess,network:properties.networkRuleSet,identity:identity.type}' --output json
```
実行結果の確認ポイント: basic・レプリカ1・パーティション1・disableLocalAuth=true・publicAccess=Enabled・社内 IP のみ・network.bypass=None・SystemAssigned を照合します。

- [ ] 3リソースが自分専用 RG に存在します。
- [ ] 3リソースの SKU / 容量方式と認証設定が一致します。
- [ ] IP 一覧に空欄や全許可がなく、社内 IP だけになっています。
- [ ] Storage のサービス例外とリソースインスタンス例外が空で、Search / Cosmos DB の bypass が None です。
- [ ] 3つの ARM ID を非公開 `.env` に記録しました。
- [ ] 確認結果と作成日時を非公開 `evidence/` に記録しました。

期待した項目が `null` の場合は成功扱いにしません。管理面の設定確認は、ネットワーク遮断やエージェント動作の実証とは区別します。

## 3.5. うまくいかない場合

| 症状 | 最初に確認すること | 次の対応 |
|---|---|---|
| 作成できない | 対象 RG・作成権限・Policy の拒否理由 | 管理者へ対象 RG の条件を確認します |
| Japan East / Basic / Serverless が選べない | リージョン提供状況・クォータ | その場で SKU を変更せず、検証の費用と Foundry 接続条件を再確認します |
| IP の入力が拒否される | 公開 IPv4 / CIDR の形式 | Storage で単一 IP は CIDR の `/32` ではなく単一アドレスで指定します。`/31` は2つの単一 IP に分けます |
| 作成ウィザードに必要な項目がない | Learn と実機の UI の違い | Cosmos DB / Search は章内の portal 代替を使います。代替も検証エラーなら止めます |
| データ参照が403になる | 送信元 IP・データ操作権限・反映待ち | この章では3.4の管理面の確認を先に行います |
| 設定変更後も表示が変わらない | 保存成功・対象リソース | Cosmos DB / Search のネットワーク設定は15分待ってから再確認します |

1. 解消しない場合は章番号・操作番号・期待値・エラーを非公開 `evidence/` に記録します。
2. GitHub Issue にする場合は実在の ID・IP・アカウント情報を伏せます。
3. 誤って追加した IP や例外は、この章の目標値へ戻します。
4. 本章の完了条件を満たすまで次章へ進みません。

## 3.6. 次の操作

データ基盤を残して、第4章で Foundry を作成します。3つの ARM ID を接続に使用します。Foundry の ID が作成された後に必要な権限とサービス間接続を設定するため、第5章を先に実行して戻る必要はありません。

> **Note** 要確認: 社内 IP 制限下で Foundry Agent Service が3リソースへ接続する経路は未検証です。同じ Azure リージョン内のサービスから Storage への接続は、公開 IP 規則だけでは制御できません。Storage / Search の信頼されたサービス例外は各サービスの対応範囲と ID・権限を確認する必要があります。Cosmos DB の Azure 全体許可を代用して解決済みにはしません。第4章で解決できなければ、現行の制約のままエージェントまで動くとは宣言できません。

## 3.7. 費用

| Excel v3 明細 No | 項目 | 通常月 USD |
|---|---|---:|
| 2 | Azure Cosmos DB / サーバーレス RU | 0.285000 |
| 3 | Azure Cosmos DB / サーバーレス Storage | 0.282500 |
| 4 | Storage account / Standard LRS Hot | 0.200000 |
| 8 | AI Search / Basic 常時分 | 0.000000 |
| 12 | AI Search / Basic 検証日分 | 4.256000 |

2026-09-15 の見積り v3 の既定値です。Japan East、原則 32h/月の検証、CSPM は既定 OFF です。No.8 と No.12 は常時／検証日の切替で、二重計上しません。No.6 は 第1章/第6章の共通費です。見積り保証ではありません。


AI Search はサービスを保持している時間の課金に注意します。上の検証日分は32時間の想定であり、本章から第10章まで数日間残した場合の料金を保証しません。

## 3.8. 本番との差・IaC で再現する (任意)

本番では負荷・復旧要件に合わせて Search S1、Provisioned Cosmos 3000 RU/s、Storage GRS と閉域接続を設計します。[付録 B](92-appendix-production-diff.md) を参照します。

### IaC で再現する (任意)

[04_data.bicep](../infra/modules/04_data.bicep) は参考です。現在のモジュールはサービス例外を有効にする設定を含み、この章の例外なしの初期状態とは一致しません。GUI 作成済みの環境に重ねてデプロイしません。モジュールと接続条件の整合が取れるまで、既存のデプロイスクリプトの停止点を維持します。

### 出典

- 出典: [Storage のネットワーク制限事項](https://learn.microsoft.com/ja-jp/azure/storage/common/storage-network-security-limitations)（取得日 2026-09-15）
- 出典: [Storage のネットワーク例外の管理](https://learn.microsoft.com/ja-jp/azure/storage/common/storage-network-security-manage-exceptions)（取得日 2026-09-15）

- 出典: [Storage の作成](https://learn.microsoft.com/ja-jp/azure/storage/common/storage-account-create)（取得日 2026-09-15）
- 出典: [Storage の共有キー無効化](https://learn.microsoft.com/ja-jp/azure/storage/common/shared-key-authorization-prevent)（取得日 2026-09-15）
- 出典: [Storage の IP 規則](https://learn.microsoft.com/ja-jp/azure/storage/common/storage-network-security-ip-address-range)（取得日 2026-09-15）
- 出典: [Storage ARM 2023-05-01](https://learn.microsoft.com/ja-jp/azure/templates/microsoft.storage/2023-05-01/storageaccounts)（取得日 2026-09-15）
- 出典: [Cosmos DB の portal 作成](https://learn.microsoft.com/ja-jp/azure/cosmos-db/quickstart-portal)（取得日 2026-09-15）
- 出典: [Cosmos DB Serverless](https://learn.microsoft.com/ja-jp/azure/cosmos-db/serverless)（取得日 2026-09-15）
- 出典: [Cosmos DB のキー無効化と RBAC](https://learn.microsoft.com/ja-jp/azure/cosmos-db/nosql/how-to-connect-role-based-access-control)（取得日 2026-09-15）
- 出典: [Cosmos DB の IP 制御](https://learn.microsoft.com/ja-jp/azure/cosmos-db/how-to-configure-firewall)（取得日 2026-09-15）
- 出典: [Cosmos DB ARM 2024-11-15](https://learn.microsoft.com/ja-jp/azure/templates/microsoft.documentdb/2024-11-15/databaseaccounts)（取得日 2026-09-15）
- 出典: [Search の作成](https://learn.microsoft.com/ja-jp/azure/search/search-create-service-portal)（取得日 2026-09-15）
- 出典: [Search のロール認証](https://learn.microsoft.com/ja-jp/azure/search/search-security-enable-roles)（取得日 2026-09-15）
- 出典: [Search の IP 制御とサービス例外](https://learn.microsoft.com/ja-jp/azure/search/service-configure-firewall)（取得日 2026-09-15）
- 出典: [Search ARM 2025-05-01](https://learn.microsoft.com/ja-jp/azure/templates/microsoft.search/2025-05-01/searchservices)（取得日 2026-09-15）
- 出典: [portal からテンプレートをデプロイ](https://learn.microsoft.com/ja-jp/azure/azure-resource-manager/templates/deploy-portal)（取得日 2026-09-15）
- 出典: [az resource show](https://learn.microsoft.com/ja-jp/cli/azure/resource)（取得日 2026-09-15）

---

前へ: [Key Vault を準備する](02-key-vault.md) / 次へ: [Foundry とエージェントを作る](04-foundry-agent.md) / [トップに戻る](../README.md)
