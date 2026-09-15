// 未検証・Run 1で確定。bicep buildはこの環境で未実行。
targetScope = 'resourceGroup'

param enablePrivateNetwork bool = false
param enableApim bool = false
param enableWaf bool = false
param enableDiagnostics bool = false
param enablePolicyDefender bool = false
@maxLength(9)
param prefix string = 'lab'
param location string = 'japaneast'
param aiServices string = prefix
param firstProjectName string = 'project'
param projectDescription string = 'some description'
param displayName string = 'project'
param modelName string = 'gpt-5-mini'
param modelFormat string = 'OpenAI'
param modelVersion string
param modelSkuName string = 'GlobalStandard'
param modelCapacity int = 1
param aiSearchResourceId string = ''
param azureStorageAccountResourceId string = ''
param azureCosmosDBAccountResourceId string = ''
param projectCapHost string = 'caphostproj'
param accountCapHost string = 'caphostacc'
param deployApplicationInsights bool = false
param deploymentTimestamp string

// 41の既定App Insights接続はApiKey。認証方式解決前にtrueへ変更しない。
// enablePrivateNetwork=trueでは41でなく15が必要。VNet injectionは作成時固定。
// 15への分岐実装はRun 2で確定（要確認）。公開41へのフォールバックは禁止。
module standardSetup 'vendor/foundry-samples-58e4127567f7e9afcf0145d874df890284ca5faf/infrastructure/infrastructure-setup-bicep/41-standard-agent-setup/main.bicep' = if (!enablePrivateNetwork) {
  name: '${prefix}-standard'
  params: {
    location: location
    aiServices: aiServices
    firstProjectName: firstProjectName
    projectDescription: projectDescription
    displayName: displayName
    modelName: modelName
    modelFormat: modelFormat
    modelVersion: modelVersion
    modelSkuName: modelSkuName
    modelCapacity: modelCapacity
    aiSearchResourceId: aiSearchResourceId
    azureStorageAccountResourceId: azureStorageAccountResourceId
    azureCosmosDBAccountResourceId: azureCosmosDBAccountResourceId
    projectCapHost: projectCapHost
    accountCapHost: accountCapHost
    deployApplicationInsights: deployApplicationInsights
    deploymentTimestamp: deploymentTimestamp
  }
}

module network 'modules/03_network.bicep' = if (enablePrivateNetwork) {
  name: '${prefix}-network'
  params: {
    location: location
    prefix: prefix
  }
}
module diagnostics 'modules/06_diagnostics.bicep' = if (enableDiagnostics) {
  name: '${prefix}-diagnostics'
  params: {
    location: location
    prefix: prefix
  }
}
module gateway 'modules/07_gateway_app.bicep' = if (enableApim) {
  name: '${prefix}-gateway'
  params: {
    location: location
    prefix: prefix
    enableWaf: enableWaf
  }
}
module policyDefender 'modules/08_policy_defender.bicep' = if (enablePolicyDefender) {
  name: '${prefix}-policy'
  params: {
    prefix: prefix
  }
}

// 公式41にはトップレベルoutputsがない。実リソースIDを架空のoutputsで参照しない。
output implementationStatus string = '未検証・骨組み。Run 1/2/3で要確認を解消する'
