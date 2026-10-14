// S1 予算アラート（RG スコープ）。ドラフト・Azure 未実行。
// RG 直下（targetScope = 'resourceGroup'）での配置は ARM テンプレートリファレンスの「Resource groups」対応に基づく。
// Learn の Bicep 完成例は subscription スコープのみ。要確認: Run 1 初回で実機確認する。
// 参照: https://learn.microsoft.com/en-us/azure/templates/microsoft.consumption/budgets （取得日 2026-09-15）
targetScope = 'resourceGroup'

@description('予算の名前。例: budget-<略号>-dev-01')
param budgetName string

@description('月予算（USD・整数）。上長と合意した値を .env の BUDGET_AMOUNT_USD から渡す')
@minValue(1)
param amount int

@description('開始日。必ず月初（YYYY-MM-01）。将来日付は 12 か月以内')
param startDate string

@description('終了日（YYYY-MM-DD）。空なら省略し ARM の既定（開始日から 10 年）に任せる')
param endDate string = ''

@description('通知先メールアドレス。RG スコープでは contactEmails か contactGroups のどちらかが必須')
@minLength(1)
param contactEmails string[]

@description('実績しきい値 1（%）')
param actualThresholdLow int = 50

@description('実績しきい値 2（%）')
param actualThresholdMid int = 80

@description('実績しきい値 3（%）')
param actualThresholdHigh int = 100

@description('予測しきい値（%）')
param forecastedThreshold int = 100

var timePeriod = empty(endDate) ? {
  startDate: startDate
} : {
  startDate: startDate
  endDate: endDate
}

resource budget 'Microsoft.Consumption/budgets@2024-08-01' = {
  name: budgetName
  properties: {
    category: 'Cost'
    amount: amount
    timeGrain: 'Monthly'
    timePeriod: timePeriod
    notifications: {
      Actual50: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: actualThresholdLow
        thresholdType: 'Actual'
        contactEmails: contactEmails
        locale: 'ja-jp'
      }
      Actual80: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: actualThresholdMid
        thresholdType: 'Actual'
        contactEmails: contactEmails
        locale: 'ja-jp'
      }
      Actual100: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: actualThresholdHigh
        thresholdType: 'Actual'
        contactEmails: contactEmails
        locale: 'ja-jp'
      }
      Forecast100: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: forecastedThreshold
        thresholdType: 'Forecasted'
        contactEmails: contactEmails
        locale: 'ja-jp'
      }
    }
  }
}

output budgetName string = budget.name
