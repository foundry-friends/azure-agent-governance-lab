// 未検証・Run 1 で確定。未コンパイル。BYO 接続・信頼サービス例外は要確認。
// Cosmos と Search に networkAcls.defaultAction はありません。非空 IP 規則で制限します。
targetScope = 'resourceGroup'
param location string
@maxLength(9)
param prefix string
@minLength(1)
param allowedIpRanges string[]
param tags object = {}
var suffix = uniqueString(resourceGroup().id, prefix)
resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' = {
  name: '${prefix}-cosmos-${suffix}'
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
  name: '${prefix}st${suffix}'
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
  name: '${prefix}-search-${suffix}'
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
