// 未検証・Run 1 / Run 2 で確定。未コンパイル・Azure 未実行。
// 公式 41 に Preview API が含まれるため GA 機能との適合レビューまで固定停止します。
targetScope = 'resourceGroup'
param allowedIpRanges string[] = []
param allowedIpAddressRanges array = []
param enableApim bool = false
param enableDiagnostics bool = false
param enablePolicyDefender bool = false
@maxLength(9)
param prefix string = 'lab'
@description('検証者略号。英小文字で第0章 0.4 の制約を満たす値。例 funato')
@minLength(1)
@maxLength(14)
param operatorCode string
@description('名前の2桁連番（01〜99）。Run 番号とは別に管理する')
@minLength(2)
@maxLength(2)
param nameSequence string = '01'
param location string = 'japaneast'
@maxLength(9)
param aiServices string = prefix
param firstProjectName string = 'project'
param projectDescription string = 'エージェント統制の個人検証'
param displayName string = 'エージェント統制検証'
param modelName string = 'gpt-5-mini'
param modelFormat string = 'OpenAI'
param modelVersion string
param modelSkuName string = 'GlobalStandard'
param modelCapacity int = 1
param projectCapHost string = 'caphostproj'
param accountCapHost string = 'caphostacc'
@allowed([false])
param deployApplicationInsights bool = false
param deploymentTimestamp string
param tags object = { purpose: 'agent-governance-lab' }
param workspaceResourceId string = ''
param publisherEmail string = ''
param publisherName string = ''
param policyDefinitionResourceId string = ''
@allowed(['Audit', 'Deny'])
param policyEffect string = 'Audit'
param policyParameters object = {}

module keyVault 'modules/02_keyvault.bicep' = {
  name: '${prefix}-keyvault'
  params: {
    location: location
    operatorCode: operatorCode
    nameSequence: nameSequence
    allowedIpRanges: allowedIpRanges
    tags: tags
  }
}
module data 'modules/04_data.bicep' = {
  name: '${prefix}-data'
  params: {
    location: location
    operatorCode: operatorCode
    nameSequence: nameSequence
    allowedIpRanges: allowedIpRanges
    tags: tags
  }
}
module standardSetup 'vendor/foundry-samples-58e4127567f7e9afcf0145d874df890284ca5faf/infrastructure/infrastructure-setup-bicep/41-standard-agent-setup/main.bicep' = {
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
    aiSearchResourceId: data.outputs.aiSearchResourceId
    azureStorageAccountResourceId: data.outputs.azureStorageAccountResourceId
    azureCosmosDBAccountResourceId: data.outputs.azureCosmosDBAccountResourceId
    projectCapHost: projectCapHost
    accountCapHost: accountCapHost
    deployApplicationInsights: deployApplicationInsights
    deploymentTimestamp: deploymentTimestamp
  }
}
// 41 のトップレベル outputs はありません。固定版と同じ名前の式を使い、S5 で実物照合します。
var foundrySuffix = substring(uniqueString('${resourceGroup().id}-${deploymentTimestamp}'), 0, 4)
module networkAcls 'modules/03_network_acls.bicep' = {
  name: '${prefix}-network-acls'
  params: {
    foundryAccountName: toLower('${aiServices}${foundrySuffix}')
    allowedIpRanges: allowedIpRanges
  }
  dependsOn: [standardSetup]
}
module diagnostics 'modules/06_diagnostics.bicep' = if (enableDiagnostics) {
  name: '${prefix}-diagnostics'
  params: {
    location: location
    operatorCode: operatorCode
    nameSequence: nameSequence
    workspaceResourceId: workspaceResourceId
    tags: tags
  }
}
module gateway 'modules/07_gateway_app.bicep' = if (enableApim) {
  name: '${prefix}-gateway'
  params: {
    location: location
    operatorCode: operatorCode
    nameSequence: nameSequence
    allowedIpRanges: allowedIpRanges
    allowedIpAddressRanges: allowedIpAddressRanges
    publisherEmail: publisherEmail
    publisherName: publisherName
    tags: tags
  }
}
module policyDefender 'modules/08_policy_defender.bicep' = if (enablePolicyDefender) {
  name: '${prefix}-policy'
  params: {
    operatorCode: operatorCode
    nameSequence: nameSequence
    policyDefinitionResourceId: policyDefinitionResourceId
    policyEffect: policyEffect
    policyParameters: policyParameters
  }
}
output implementationStatus string = '未検証。S5 の後追い更新・S6 の接続・S7 の認証経路・S8 の型別定義は未完了'
