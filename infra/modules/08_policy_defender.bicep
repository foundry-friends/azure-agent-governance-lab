// 未検証・Run 1（Audit）/ Run 2（Deny・評価）で確定。未コンパイル。
// 定義の effect・alias・対象型は要確認。Defender のサブスクリプション課金は変更しません。
targetScope = 'resourceGroup'
@description('検証者略号。英小文字で第0章 0.4 の制約を満たす値。例 funato')
@minLength(1)
@maxLength(14)
param operatorCode string
@description('名前の2桁連番（01〜99）。Run 番号とは別に管理する')
@minLength(2)
@maxLength(2)
param nameSequence string = '01'
@minLength(1)
param policyDefinitionResourceId string
@allowed(['Audit', 'Deny'])
param policyEffect string = 'Audit'
param policyParameters object = {}
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'policy-${operatorCode}-dev-${nameSequence}'
  properties: {
    policyDefinitionId: policyDefinitionResourceId
    parameters: union(policyParameters, { effect: { value: policyEffect } })
    enforcementMode: 'Default'
  }
}
output policyAssignmentResourceId string = policyAssignment.id
output defenderStatus string = '未変更。S8 で承認・現行状態・復帰方法を確認'
