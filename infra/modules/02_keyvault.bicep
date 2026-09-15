// 未検証・Run 1 で確定。未コンパイル。実効 RBAC と到達は要確認。
targetScope = 'resourceGroup'
param location string
@maxLength(9)
param prefix string
@minLength(1)
param allowedIpRanges string[]
param tags object = {}
var suffix = substring(uniqueString(resourceGroup().id, prefix), 0, 11)
resource vault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: '${prefix}-kv-${suffix}'
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      ipRules: [for ip in allowedIpRanges: { value: ip }]
      virtualNetworkRules: []
    }
    accessPolicies: []
  }
}
output keyVaultResourceId string = vault.id
