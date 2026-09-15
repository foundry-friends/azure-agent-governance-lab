// 未検証・Run 3で確定。APIバージョン・必須propertiesは要確認。未コンパイル。
targetScope = 'resourceGroup'
param location string
param prefix string
param enableWaf bool = false
param apimProperties object = {}
param appProperties object = {}
param wafProperties object = {}
resource apim 'Microsoft.ApiManagement/service@2024-05-01' = {
  name: '${prefix}-apim'
  location: location
  sku: {
    name: 'BasicV2'
    capacity: 1
  }
  // publisher・Entra ID・バックエンド・token quota・LLMログは要確認。
  properties: apimProperties
}
resource appPlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: '${prefix}-plan'
  location: location
  kind: 'linux'
  sku: {
    name: 'B1'
  }
  properties: {
    reserved: true
  }
}
resource app 'Microsoft.Web/sites@2023-12-01' = {
  name: '${prefix}-app'
  location: location
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  // serverFarmId=appPlan.id、OBO・認証・アプリ配布はRun 3で確定。
  properties: union(appProperties, { serverFarmId: appPlan.id })
}
resource waf 'Microsoft.Network/applicationGateways@2024-05-01' = if (enableWaf) {
  name: '${prefix}-waf'
  location: location
  // WAF_v2、専用subnet、listener、証明書、バックエンドは要確認。
  properties: wafProperties
}
output apimResourceId string = apim.id
output appResourceId string = app.id
output wafRequested bool = enableWaf
