// 未検証・Run 1 で確定。bicep build は通過（2026-09-15）。後追い更新の API 適合性は要確認。
// existing は変更しません。S5 の az resource update で下記目標値を適用します。
// 41 の初期公開・ローカル認証有効期間と再展開の巻き戻りは未解決です。
targetScope = 'resourceGroup'
param foundryAccountName string
@minLength(1)
param allowedIpRanges string[]
resource account 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = {
  name: foundryAccountName
}
var ipRules = [for ip in allowedIpRanges: { value: ip }]
output foundryAccountResourceId string = account.id
output desiredProperties object = {
  publicNetworkAccess: 'Enabled'
  disableLocalAuth: true
  networkAcls: {
    defaultAction: 'Deny'
    bypass: 'None'
    ipRules: ipRules
    virtualNetworkRules: []
  }
}
output implementationStatus string = '参照と目標値のみ。S5 の後追い更新・C03/C08 は未実施'
