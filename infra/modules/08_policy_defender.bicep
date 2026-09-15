// 未検証・Run 1（Audit）/ Run 2（Deny・評価）で確定。未コンパイル。
// 定義の effect・alias・対象型は要確認。Defender のサブスクリプション課金は変更しません。
targetScope = 'resourceGroup'
param prefix string
@minLength(1)
param policyDefinitionResourceId string
@allowed(['Audit', 'Deny'])
param policyEffect string = 'Audit'
param policyParameters object = {}
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: '${prefix}-policy'
  properties: {
    policyDefinitionId: policyDefinitionResourceId
    parameters: union(policyParameters, { effect: { value: policyEffect } })
    enforcementMode: 'Default'
  }
}
output policyAssignmentResourceId string = policyAssignment.id
output defenderStatus string = '未変更。S8 で承認・現行状態・復帰方法を確認'
