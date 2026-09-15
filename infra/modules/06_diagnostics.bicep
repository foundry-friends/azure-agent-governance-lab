// 未検証・Run 1で確定。APIバージョン・カテゴリ・送信認証は要確認。未コンパイル。
// 他サービスへの診断設定はRun 1/2/3で対象typeごとに確定。LAWはS1と所有を調整。
targetScope = 'resourceGroup'
param location string
param prefix string
param foundryAccountName string = ''
param workspaceResourceId string = ''
param diagnosticLogs array = []
param applicationInsightsProperties object = {}
resource foundry 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: foundryAccountName
}
resource diagnostic 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${prefix}-diagnostic'
  scope: foundry
  properties: {
    workspaceId: workspaceResourceId
    logs: diagnosticLogs
  }
}
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${prefix}-appinsights'
  location: location
  kind: 'web'
  // Entra IDのみの送信・接続を確定するまで実行しない。
  properties: applicationInsightsProperties
}
output diagnosticResourceId string = diagnostic.id
output appInsightsResourceId string = appInsights.id
