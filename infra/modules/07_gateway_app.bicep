// 未検証・Run 2 で確定。未コンパイル。経路・OBO・JWT・quota・アプリ配布は要確認。
// ip-filter のみで Entra 認証やバックエンド許可を実装したとは扱いません。
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
@minLength(1)
param allowedIpAddressRanges array
param publisherEmail string
param publisherName string
param tags object = {}
var ipElements = [for range in allowedIpAddressRanges: '<address-range from="${range.from}" to="${range.to}" />']
resource apim 'Microsoft.ApiManagement/service@2024-05-01' = {
  name: 'apim-${operatorCode}-dev-${nameSequence}'
  location: location
  tags: tags
  identity: { type: 'SystemAssigned' }
  sku: {
    name: 'BasicV2'
    capacity: 1
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    publicNetworkAccess: 'Enabled'
  }
}
resource ipPolicy 'Microsoft.ApiManagement/service/policies@2024-05-01' = {
  parent: apim
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: '<policies><inbound><ip-filter action="allow">${join(ipElements, '')}</ip-filter></inbound><backend><forward-request /></backend><outbound /><on-error /></policies>'
  }
}
resource appPlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: 'asp-${operatorCode}-dev-${nameSequence}'
  location: location
  kind: 'linux'
  tags: tags
  sku: { name: 'B1' }
  properties: { reserved: true }
}
resource app 'Microsoft.Web/sites@2023-12-01' = {
  name: 'app-${operatorCode}-dev-${nameSequence}'
  location: location
  kind: 'app,linux'
  tags: tags
  identity: { type: 'SystemAssigned' }
  properties: {
    serverFarmId: appPlan.id
    httpsOnly: true
    publicNetworkAccess: 'Enabled'
    siteConfig: {
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      ipSecurityRestrictionsDefaultAction: 'Deny'
      scmIpSecurityRestrictionsUseMain: true
      scmIpSecurityRestrictionsDefaultAction: 'Deny'
      ipSecurityRestrictions: [for (ip, index) in allowedIpRanges: {
        ipAddress: ip
        action: 'Allow'
        priority: 100 + index
        name: 'corporate-${index}'
      }]
    }
  }
}
output apimResourceId string = apim.id
output appResourceId string = app.id
output implementationStatus string = 'IP 制限だけ。社内 IP 以外のサービス発信経路・認証・ツール出口は未検証'
