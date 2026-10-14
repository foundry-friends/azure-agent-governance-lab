// 未検証・Run 1 で確定。未コンパイル。Entra ID のみの Foundry 接続は要確認。
// LAW は S1 の所有です。診断カテゴリ・個別リソースへの設定は S6 の portal 手順で確定します。
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
param workspaceResourceId string
param tags object = {}
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-${operatorCode}-dev-${nameSequence}'
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspaceResourceId
    DisableLocalAuth: true
  }
}
output appInsightsResourceId string = appInsights.id
output implementationStatus string = 'App Insights 本体だけ。Foundry 接続・診断設定・本文収集は S6 で未完了'
