// 未検証・Run 1（Audit）/ Run 3（Deny・評価）で確定。APIバージョンは要確認。
// Defenderはsubscription scopeの課金プラン。RGモジュールで架空のplanを有効化しない。
// az security pricingのplan/subplan/extensionと承認・戻し方を確定して別途実行。
targetScope = 'resourceGroup'
param prefix string
param policyDefinitionResourceId string = ''
param policyParameters object = {}
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: '${prefix}-policy'
  properties: {
    policyDefinitionId: policyDefinitionResourceId
    parameters: policyParameters
    // effectは定義が許す値だけ。DoNotEnforceとAuditは同義ではない。
    enforcementMode: 'DoNotEnforce'
  }
}
output policyAssignmentResourceId string = policyAssignment.id
output defenderStatus string = '要確認・サブスクリプション管理者の承認と現行プラン確認が必要'
