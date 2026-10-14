// 未検証・Run 1 で確定。未コンパイル。実効 RBAC と到達は要確認。
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
resource vault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'kv-${operatorCode}-dev-${nameSequence}'
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
