# 公式41の実パラメータとRun 1の適合性

固定版：`58e4127567f7e9afcf0145d874df890284ca5faf`。採用日と取得物は [PINNED_COMMIT](../PINNED_COMMIT.md)。これはソースの机上確認で、Azure実行・bicep buildはしていません。

## 1. 全param（17件）

[main.bicep](https://github.com/microsoft-foundry/foundry-samples/tree/58e4127567f7e9afcf0145d874df890284ca5faf/infrastructure/infrastructure-setup-bicep/41-standard-agent-setup/main.bicep) と [README](https://github.com/microsoft-foundry/foundry-samples/tree/58e4127567f7e9afcf0145d874df890284ca5faf/infrastructure/infrastructure-setup-bicep/41-standard-agent-setup/README.md) を照合しました。READMEには全paramの一覧がないため、用途・既定・allowedは宣言と依存moduleから補完しています。

| 名前 | 型 | 既定値 | allowed | 必須か | 用途（README／不足分は宣言・依存module） | Run 1 の設定 |
|---|---|---|---|---|---|---|
| `location` | `string` | `'eastus'` | australiaeast, canadaeast, eastus, eastus2, francecentral, japaneast, koreacentral, norwayeast, polandcentral, southindia, swedencentral, switzerlandnorth, uaenorth, uksouth, westus, westus2, westus3, westeurope, southeastasia, brazilsouth, germanywestcentral, italynorth, southafricanorth, southcentralus | 省略可（既定あり） | リソースとprojectのリージョン | `japaneast` |
| `aiServices` | `string` | `'foundy'` | 制約なし | 省略可（既定あり） | account名の接頭辞（41は最大9文字） | `lab`（ラッパの命名prefixと一致） |
| `firstProjectName` | `string` | `'project'` | 制約なし | 省略可（既定あり） | project名の接頭辞 | `project` |
| `projectDescription` | `string` | `'some description'` | 制約なし | 省略可（既定あり） | projectの説明 | `エージェント統制の個人検証` |
| `displayName` | `string` | `'project'` | 制約なし | 省略可（既定あり） | projectの表示名 | `エージェント統制検証` |
| `modelName` | `string` | `'gpt-4.1'` | 制約なし | 省略可（既定あり） | 配置するモデル名 | `gpt-5-mini`（提供確認前） |
| `modelFormat` | `string` | `'OpenAI'` | 制約なし | 省略可（既定あり） | モデルの提供元 | `OpenAI` |
| `modelVersion` | `string` | `'2025-04-14'` | 制約なし | 省略可（既定あり） | 配置するモデルの版 | `<model-version>`：要確認。gpt-4.1の既定版を流用しない |
| `modelSkuName` | `string` | `'GlobalStandard'` | 制約なし | 省略可（既定あり） | モデル配置のSKU | `GlobalStandard` |
| `modelCapacity` | `int` | `40` | 制約なし | 省略可（既定あり） | モデル配置容量（README/descriptionはTPM、単位・クォータ換算は要確認） | `1`は型を示す例。必要TPM・割当単位は要確認 |
| `aiSearchResourceId` | `string` | `''` | 制約なし | 省略可（既定あり） | 既存AI Searchの完全ARM ID。空なら新規作成 | Basic・ローカル認証無効の既存IDをlocal.jsonへ（04_data.bicep で作成・実機は未検証） |
| `azureStorageAccountResourceId` | `string` | `''` | 制約なし | 省略可（既定あり） | 既存Storageの完全ARM ID。空なら新規作成 | LRS・Shared Key無効の既存IDをlocal.jsonへ（04_data.bicep で作成・実機は未検証） |
| `azureCosmosDBAccountResourceId` | `string` | `''` | 制約なし | 省略可（既定あり） | 既存Cosmosの完全ARM ID。空なら新規作成 | サーバーレスの既存IDをlocal.jsonへ（04_data.bicep で作成・実機は未検証） |
| `projectCapHost` | `string` | `'caphostproj'` | 制約なし | 省略可（既定あり） | project capability host名（READMEに個別説明なし、コードで確認） | `caphostproj` |
| `accountCapHost` | `string` | `'caphostacc'` | 制約なし | 省略可（既定あり） | account capability host名（READMEに個別説明なし、コードで確認） | `caphostacc` |
| `deployApplicationInsights` | `bool` | `true` | 制約なし | 省略可（既定あり） | LAW・App Insights・接続とproject MI読取ロールの作成を切替 | 例は `false`。目標はApp Insightsありだが、公式のApiKey接続を使わずS6で方式確定（要確認） |
| `deploymentTimestamp` | `string` | `utcNow('yyyyMMddHHmmss')` | 制約なし | 省略可（既定あり） | 命名suffixに混ぜる時刻文字列（READMEに個別説明なし、コードで確認） | `20260915000000`は非秘密の固定例。同じRGで再実行しても変更しない |


`aiServices`にはmaxLength(9)制約があります。全paramは既定値を持ち構文上は省略可ですが、目標構成のためにBYO ID・モデル版・固定時刻を確定する必要があります。`utcNow()`の既定を使うと毎回suffixが変わります。

## 2. Run 1の目標構成との対応

| Run 1の目標 | 41で設定できるか | 根拠・代替 |
|---|---|---|
| Japan East | paramで設定可 | locationのallowedにjapaneast。モデル提供・クォータは要確認 |
| Cosmosサーバーレス | 容量モードは41では設定不可・要確認 | 新規作成にEnableServerlessなし。既存サーバーレスをazureCosmosDBAccountResourceIdで渡す（04_data.bicep を使用）。後から容量方式だけ変えられるとは扱わない |
| AI Search Basic | SKUは41では設定不可・要確認 | 新規はstandard固定。事前作成BasicをaiSearchResourceIdで渡す（04_data.bicep を使用） |
| gpt-5 mini Global Standard | paramで名前・版・SKU・容量を指定可 | modelName=gpt-5-mini、modelSkuName=GlobalStandard。modelVersion・実提供は要確認 |
| ローカル認証無効 | 41では設定不可・要確認 | Foundry/Searchはfalse固定、Cosmosはtrue、StorageはShared Key無効。04_data.bicep の設定＋S5 の Foundry 後追い設定 |
| App Insightsあり | 有無のparamはあるが目標の認証方式は不可 | deployApplicationInsights=trueはApiKey/ConnectionString接続。Entra IDのみの経路は41では設定不可・要確認。falseで停止しS6 の後追い接続を検討（06_diagnostics.bicep は本体のみ） |
| Storage LRS | SKUは41では設定不可・要確認 | Japan Eastの既定はStandard_ZRS。既存LRSをazureStorageAccountResourceIdで渡す（04_data.bicep を使用） |
| Key Vault | 41では設定不可・要確認 | 作成resourceもparamもない。S2 の 02_keyvault.bicep で RBAC 認可・IP 制限を設定。キー保管で代用しない |
| 命名・タグ | 接頭辞・時刻は設定可、tagsなし | deploymentTimestampを固定。タグは41では設定不可・要確認。自前 module と S5 の後追い適用で補う |


新規データ接続はAADですが、ローカル認証を無効化したことと同義ではありません。C01〜C05をPassにする根拠は実機試験で残します。例JSONのApp Insights=falseは目標の削除ではなく、未解決の接続を展開しないための保留です。

## 3. deployment scope・必要ロール・既存リソース

- `targetScope`の明記はなくBicep既定のresourceGroup。READMEも`az deployment group create`を使用。ラッパは`targetScope = 'resourceGroup'`を明記。
- 固定41のREADMEは Foundry Account Owner と Role Based Access Administrator を要求。計画側はRG Ownerまたはリソース作成権限＋User Access Administrator。名称の対応・必要なデータ面権限・会社の実効権限は要確認で、片方の記載だけで十分と断定しません。
- 必須の既存リソースは展開先RG。Search / Storage / Cosmos のIDは任意だが、渡す場合は既存実体・アクセス可能なscopeが必要。今回の目標SKUではこれらのBYO事前準備が必要（04_data.bicep）。
- ID指定時には他RG/他subscriptionへロール割当するmoduleもあるため、全スコープの権限を確認。実IDは非公開local.jsonに保存。
- CosmosのREADMEはProvisioned/Serverless対応と3000RU/sの注意を併記。接続はAADかつmetadata.ResourceId必須。ServerlessへProvisionedのRU/s指定をそのまま渡さない。
- 41はKey Vault、予算、Policy、Defenderプランを作成しない。S1/S2/S8で別途扱う。

## 4. outputs

**41のmain.bicepトップレベルoutputsは0件。** ラッパから `standardSetup.outputs.appInsightsId` 等を参照できると捏造しません。

依存module内にはaccountName/accountID/accountTarget/accountPrincipalId、projectName/projectId/projectPrincipalId/projectWorkspaceIdと接続名、データリソース名/ID/scope、App Insights名/ID/AppIdとlogAnalyticsIdがあります。これらはトップレベルへ再公開されていません。詳細一覧：

- `ai-account-identity.bicep`：`accountName: string`, `accountID: string`, `accountTarget: string`, `accountPrincipalId: string`。
- `ai-project-identity.bicep`：`projectName: string`, `projectId: string`, `projectPrincipalId: string`, `projectWorkspaceId: string`, `cosmosDBConnection: string`, `azureStorageConnection: string`, `aiSearchConnection: string`。
- `application-insights.bicep`：`appInsightsName: string`, `appInsightsId: string`, `appInsightsAppId: string`, `logAnalyticsId: string`。
- `format-project-workspace-id.bicep`：`projectWorkspaceIdGuid: string`。
- `standard-dependent-resources.bicep`：`aiSearchName: string`, `aiSearchID: string`, `aiSearchServiceResourceGroupName: string`, `aiSearchServiceSubscriptionId: string`, `azureStorageName: string`, `azureStorageId: string`, `azureStorageResourceGroupName: string`, `azureStorageSubscriptionId: string`, `cosmosDBName: string`, `cosmosDBId: string`, `cosmosDBResourceGroupName: string`, `cosmosDBSubscriptionId: string`。
- `validate-existing-resources.bicep`：`aiSearchExists: bool`, `cosmosDBExists: bool`, `azureStorageExists: bool`, `aiSearchServiceSubscriptionId: string`, `aiSearchServiceResourceGroupName: string`, `cosmosDBSubscriptionId: string`, `cosmosDBResourceGroupName: string`, `azureStorageSubscriptionId: string`, `azureStorageResourceGroupName: string`。

出力の一括ダンプはせず、必要IDだけポータルで照合して.envに記録します。outputs未確認という旧ドラフトの要確認は「トップレベル0件」と机上解消しましたが、値の取得手順・新ランタイム対応・実機冪等性は要確認です。

## 5. 使用しないテンプレート15の全param（保存用の机上調査）

> **Note** v2.1 では 15 を使いません。この節は過去の机上調査の保存で、展開手順ではありません。

同じ固定SHAの15を机上確認。scopeはresourceGroup、トップレベルoutputsは0件。READMEはFoundry Account Owner、OwnerまたはRole Based Access Administrator、操作用Foundry Userを記載。会社権限は要確認です。

| 名前 | 型 | 既定値 | allowed | 必須か | 用途（README／不足分は宣言・依存module） | 旧設定（非採用） |
|---|---|---|---|---|---|---|
| `location` | `string` | `'eastus'` | westus, eastus, eastus2, japaneast, francecentral, spaincentral, uaenorth, southcentralus, italynorth, germanywestcentral, brazilsouth, southafricanorth, australiaeast, swedencentral, canadaeast, canadacentral, westeurope, westus3, uksouth, southindia, koreacentral, polandcentral, switzerlandnorth, norwayeast | 省略可（既定あり） | リソースとprojectのリージョン | `japaneast` |
| `aiServices` | `string` | `'aiservices'` | 制約なし | 省略可（既定あり） | account名の接頭辞（41は最大9文字） | `lab`（ラッパの命名prefixと一致） |
| `modelName` | `string` | `'gpt-4.1'` | 制約なし | 省略可（既定あり） | 配置するモデル名 | `gpt-5-mini`（提供確認前） |
| `modelFormat` | `string` | `'OpenAI'` | 制約なし | 省略可（既定あり） | モデルの提供元 | `OpenAI` |
| `modelVersion` | `string` | `'2025-04-14'` | 制約なし | 省略可（既定あり） | 配置するモデルの版 | `<model-version>`：要確認。gpt-4.1の既定版を流用しない |
| `modelSkuName` | `string` | `'GlobalStandard'` | 制約なし | 省略可（既定あり） | モデル配置のSKU | `GlobalStandard` |
| `modelCapacity` | `int` | `30` | 制約なし | 省略可（既定あり） | モデル配置容量（README/descriptionはTPM、単位・クォータ換算は要確認） | `1`は型を示す例。必要TPM・割当単位は要確認 |
| `firstProjectName` | `string` | `'project'` | 制約なし | 省略可（既定あり） | project名の接頭辞 | `project` |
| `projectDescription` | `string` | `'A project for the AI Foundry account with network secured deployed Agent'` | 制約なし | 省略可（既定あり） | projectの説明 | `エージェント統制の個人検証` |
| `displayName` | `string` | `'network secured agent project'` | 制約なし | 省略可（既定あり） | projectの表示名 | `エージェント統制検証` |
| `vnetName` | `string` | `''` | 制約なし | 省略可（既定あり） | 新規VNet名。既存IDを指定した場合はID側を優先 | `lab-vnet`（例） |
| `agentSubnetName` | `string` | `'agent-subnet'` | 制約なし | 省略可（既定あり） | agent用サブネット名 | 既定値を確認。環境依存値はlocal.jsonで要確認 |
| `peSubnetName` | `string` | `'pe-subnet'` | 制約なし | 省略可（既定あり） | PE用サブネット名 | 既定値を確認。環境依存値はlocal.jsonで要確認 |
| `existingVnetResourceId` | `string` | `''` | 制約なし | 省略可（既定あり） | 既存VNetの完全ARM ID | 既定値を確認。環境依存値はlocal.jsonで要確認 |
| `vnetAddressPrefix` | `string` | `''` | 制約なし | 省略可（既定あり） | 新規VNetのアドレス範囲 | `<vnet-cidr>`：会社ネットワークと重複しない範囲を要確認 |
| `agentSubnetPrefix` | `string` | `''` | 制約なし | 省略可（既定あり） | agentサブネット範囲 | `<agent-subnet-cidr>`：/27以上、会社ルールは要確認 |
| `peSubnetPrefix` | `string` | `''` | 制約なし | 省略可（既定あり） | PEサブネット範囲 | `<pe-subnet-cidr>`：必要PE数を確認 |
| `reuseExistingSubnets` | `bool` | `false` | 制約なし | 省略可（既定あり） | 既存VNet指定時、構成済みsubnetの変更を抑止 | 新規はfalse。既存再利用時の会社承認は要確認 |
| `existingAiFoundryAccountResourceId` | `string` | `''` | 制約なし | 省略可（既定あり） | 既存Foundry accountを参照（公開accountへの後付けinjectionは不可） | 空文字。Run 1とは別accountを新規作成 |
| `skipModelDeployment` | `bool` | `false` | 制約なし | 省略可（既定あり） | 既存配置を使う場合のモデル配置省略 | 既定値を確認。環境依存値はlocal.jsonで要確認 |
| `enableContainerRegistry` | `bool` | `true` | 制約なし | 省略可（既定あり） | Premium ACRとPE作成。prompt agent本編はfalse | `false`（本編にACRを追加しない） |
| `developerIpCidr` | `string` | `''` | 制約なし | 省略可（既定あり） | ACR push用の許可元CIDR | 既定値を確認。環境依存値はlocal.jsonで要確認 |
| `createAccountCapabilityHost` | `bool` | `false` | 制約なし | 省略可（既定あり） | 明示的なaccount caphost作成。新規injection時の自動作成と重複させない | `false`（自動生成との重複回避） |
| `aiSearchResourceId` | `string` | `''` | 制約なし | 省略可（既定あり） | 既存AI Searchの完全ARM ID。空なら新規作成 | Basic・ローカル認証無効の既存IDをlocal.jsonへ（04_data.bicep で作成・実機は未検証） |
| `azureStorageAccountResourceId` | `string` | `''` | 制約なし | 省略可（既定あり） | 既存Storageの完全ARM ID。空なら新規作成 | LRS・Shared Key無効の既存IDをlocal.jsonへ（04_data.bicep で作成・実機は未検証） |
| `azureCosmosDBAccountResourceId` | `string` | `''` | 制約なし | 省略可（既定あり） | 既存Cosmosの完全ARM ID。空なら新規作成 | サーバーレスの既存IDをlocal.jsonへ（04_data.bicep で作成・実機は未検証） |
| `dnsZonesSubscriptionId` | `string` | `''` | 制約なし | 省略可（既定あり） | 既存DNSのsubscription。空は現在のsubscription | 既定値を確認。環境依存値はlocal.jsonで要確認 |
| `existingDnsZones` | `object` | `{   'privatelink.services.ai.azure.com': ''   'privatelink.openai.azure.com': ''   'privatelink.cognitiveservices.azure.com': ''                  'privatelink.search.windows.net': ''              'privatelink.blob.core.windows.net': ''                               'privatelink.documents.azure.com': ''                          'privatelink.azurecr.io': '' }` | 制約なし | 省略可（既定あり） | 各Private DNS zone名→既存RG、空値なら作成 | 既定値を確認。環境依存値はlocal.jsonで要確認 |
| `existingMonitorDnsZones` | `object` | `{   'privatelink.monitor.azure.com': ''   'privatelink.oms.opinsights.azure.com': ''   'privatelink.ods.opinsights.azure.com': ''   'privatelink.agentsvc.azure-automation.net': '' }` | 制約なし | 省略可（既定あり） | Azure Monitor用Private DNS zone名→既存RG、空値なら作成 | 既定値を確認。環境依存値はlocal.jsonで要確認 |
| `dnsZoneNames` | `array` | `[   'privatelink.services.ai.azure.com'   'privatelink.openai.azure.com'   'privatelink.cognitiveservices.azure.com'   'privatelink.search.windows.net'   'privatelink.blob.core.windows.net'   'privatelink.documents.azure.com'   'privatelink.azurecr.io' ]` | 制約なし | 省略可（既定あり） | 既存Private DNSの検証対象zone名配列 | 既定値を確認。環境依存値はlocal.jsonで要確認 |
| `projectCapHost` | `string` | `'caphostproj'` | 制約なし | 省略可（既定あり） | project capability host名（READMEに個別説明なし、コードで確認） | `caphostproj` |


配列とobjectの既定値も上表に全文を掲載。全31paramが既定を持ちますが、新規VNetではvnetNameと各CIDRを埋める必要があります。READMEは [VNet背後のagent tools非対応](https://github.com/microsoft-foundry/foundry-samples/tree/58e4127567f7e9afcf0145d874df890284ca5faf/infrastructure/infrastructure-setup-bicep/15-private-network-standard-agent-setup/README.md) とし19を案内しているため、MCP/OpenAPI閉域の検証範囲は要確認。15 の分岐は作成しません。

旧検討では15のACR Premium既定trueに対してfalseを想定していました。Azure Monitor Private Link Scope・追加DNS・PEとApp Insightsを作成するため、旧見積りの6PE/6zoneとの差は要確認。新規accountのcapability hostは自動作成されるため、createAccountCapabilityHostはfalseを維持します。既存公開accountへの後付けinjectionには利用しません。

## 6. 元の仮パラメータからの移行

- `location`：要確認だった名前とallowedを確認し、実名のまま採用。
- `cosmosDbCapacityMode`：要確認の仮名を削除。対応する容量paramはなく、BYO用`azureCosmosDBAccountResourceId`を使用する方針。
- `aiSearchSku`：要確認の仮名を削除。SKU paramはなく、BYO用`aiSearchResourceId`を使用する方針。
- RG scope・outputs・ファイル存在の机上確認は完了。BYO のコード化は完了。Foundry 後追いと Entra ID のみの App Insights 接続は未確定。


## 7. v2.1 の適用方法

公式 41 の 17 param の調査結果を保存しています。run1/run2.example.json は公式へ直接渡す JSON ではなく、自前 main.bicep の入力です。41 の BYO ID は 04_data.bicep の 3 outputs から渡します。SKU 3 件・データ認証・Key Vault・自前タグをコード化しましたが、実機で解消を確認したわけではありません。

41 には networkAcls / publicNetworkAccess / disableLocalAuth の入力 param がありません。03_network_acls.bicep は既存 account の参照と更新目標を返し、S5 の az resource update で後追いします。Foundry と 41 管理のタグ、agent service 到達、App Insights 接続、Preview API の GA 機能適合性は要確認です。
