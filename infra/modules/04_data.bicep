// 未検証・Run 1 で確定。未コンパイル。BYO 接続・信頼サービス例外は要確認。
// Cosmos と Search に networkAcls.defaultAction はありません。非空 IP 規則で制限します。
targetScope = 'resourceGroup'
param location string
@description('検証者略号。英小文字で第0章 0.4 の制約を満たす値。例 funato')
@minLength(1)
@maxLength(14)
param operatorCode string
@description('名前の2桁連番（01〜99）。Run 番号とは別に管理する')
@minLength(2)
@maxLength(2)
param nameSequence string = '01'
@minLength(1)
param allowedIpRanges string[]
param tags object = {}
resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' = {
  name: 'cosno-${operatorCode}-dev-${nameSequence}'
  location: location
  kind: 'GlobalDocumentDB'
  tags: tags
  properties: {
    databaseAccountOfferType: 'Standard'
    capabilities: [ { name: 'EnableServerless' } ]
    locations: [ {
      locationName: location
      failoverPriority: 0
    } ]
    consistencyPolicy: { defaultConsistencyLevel: 'Session' }
    disableLocalAuth: true
    publicNetworkAccess: 'Enabled'
    ipRules: [for ip in allowedIpRanges: { ipAddressOrRange: ip }]
    isVirtualNetworkFilterEnabled: false
    networkAclBypass: 'AzureServices'
  }
}
resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'st${operatorCode}dev${nameSequence}'
  location: location
  kind: 'StorageV2'
  tags: tags
  sku: { name: 'Standard_LRS' }
  properties: {
    accessTier: 'Hot'
    allowSharedKeyAccess: false
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      ipRules: [for ip in allowedIpRanges: {
        value: ip
        action: 'Allow'
      }]
      virtualNetworkRules: []
    }
  }
}
resource search 'Microsoft.Search/searchServices@2025-05-01' = {
  name: 'srch-${operatorCode}-dev-${nameSequence}'
  location: location
  tags: tags
  sku: { name: 'basic' }
  identity: { type: 'SystemAssigned' }
  properties: {
    replicaCount: 1
    partitionCount: 1
    disableLocalAuth: true
    publicNetworkAccess: 'enabled'
    networkRuleSet: {
      bypass: 'AzureServices'
      ipRules: [for ip in allowedIpRanges: { value: ip }]
    }
  }
}
output aiSearchResourceId string = search.id
output azureStorageAccountResourceId string = storage.id
output azureCosmosDBAccountResourceId string = cosmos.id
