# 6. 監視と監査を設定する

進め方: README の第0〜10章を順番に実施します。第5章の完了条件を満たしてから進めます。

> **Note** 状態: 構成ドラフト・操作の詳細は未確定（Azure 未実行）。構成変更日 2026-09-15。

> **補足** この章では環境を削除しません。通常の削除は最後の第10章です。中断して片付ける場合だけ、第10章へ進みます。

## 6.1. 目的

統制層⑦として、診断監査・本文トレース・Activity Log と閲覧制御を分けて確認します。

## 6.2. 前提

Log Analytics、Foundry、データ基盤、Key Vault が存在します。本文を読むユーザーと読ませないユーザーを区別します。

## 6.3. 設定

### Application Insights を接続する

> **Note** 要確認: 作成ウィザードの GUI 手順と入力項目を確定する必要があります。[06_diagnostics.bicep](../infra/modules/06_diagnostics.bicep) は任意の再現資料です。

1. 第1章の `LOG_ANALYTICS_RESOURCE_ID` を確認します。
2. Azure portal で既存 Log Analytics に接続する Application Insights を準備します。
3. Foundry project の [監視] でトレース接続を確認します。
4. Entra ID による送信経路を確認できた場合だけ本文収集を設定します。

> **Note** 要確認: 41 の App Insights 接続は ApiKey / ConnectionString のため使いません。Entra ID のみの接続・SDK・必要ロール・本文収集方法は（初回で記入）です。接続文字列を貼る方法に切り替えず、未解決なら C05 を Pending にします。

### 診断ログを設定する

1. Foundry の診断カテゴリを列挙します。

```bash
az monitor diagnostic-settings categories list --subscription "$AZURE_SUBSCRIPTION_ID" --resource "$FOUNDRY_ACCOUNT_RESOURCE_ID" --output table
```
実行結果の確認ポイント: 実在カテゴリとログ種別を確認します。

2. 各リソースの [診断設定] を開きます。
3. 下表の対象で実在するカテゴリを選択します。
4. 送信先に 第1章の Log Analytics を指定します。
5. [保存] を選択します。
6. 合成操作を発生させます。
7. [ログ] で対応レコードを確認します。

| 項目 | 値 |
|---|---|
| 対象 | Foundry・Cosmos・AI Search・Key Vault（APIM は第7章で作成時に追加） |
| カテゴリ | 対象ごとに列挙した監査・操作・拒否ログだけ |
| 保持 | 30 日（LAW と各テーブルを確認） |
| 本文 | トレースの `AppGenAIContent` と閲覧権限を別確認 |

8. [アクティビティ ログ] で構成変更の記録を確認します。
9. Foundry の Purview Audit トグルの利用条件を確認します。

> **Note** 要確認: ネットワーク拒否ログの所在、反映時間、Purview Audit の GA・権限・利用条件は（初回で記入）です。有償 Purview 機能は追加しません。

> **補足** 診断ログにはプロンプト本文があることを期待しません。[機微なトレース内容](https://learn.microsoft.com/en-us/azure/foundry/observability/how-to/traces-sensitive-content) とモデル呼び出しの記録を区別します。

## 6.4. 完了条件

C04: 必要な診断ログの到着を確認します。C05: 合成本文の到着、閲覧許可／拒否、30 日保持を確認します。project MI に広い本文閲覧権限を付与する場合は実効スコープも確認します。

```bash
bash scripts/verify.sh --section 6
```
実行結果の確認ポイント: 設定収集または案内のみで、未完了は終了コード 2 です。

[確認項目](../checks/README.md) ごとに実施日・Run・入力・期待結果・実結果・Pass / Fail / Pending を非公開の `evidence/` に記録します。未実施は Pending です。

この章の合成操作でログの到着を確認します。第8章では新たな統制試験を行い、その試験のログを確認します。過去の章の未実施作業をやり直す流れではありません。

## 6.5. うまくいかない場合

（初回で記入）

1. 診断カテゴリ・送信先・反映待ちを確認します。
2. 本文がなければトレース収集と Entra ID 経路を確認します。
3. 本文閲覧権限を広げて解決したことにせず、必要主体だけに限定します。

## 6.6. 次の操作

監視設定を維持して第7章へ進みます。本文トレースの経路が未確定なら C05 は Pending と記録します。

## 6.7. 費用

| Excel v3 明細 No | 項目 | 通常月 USD |
|---|---|---:|
| 6 | Log Analytics / Analytics Logs 取り込み | 10.020000 |
| 7 | Application Insights / Workspace-based | 0.000000 |
| 18 | Log Analytics / 保持（30日既定） | 0.000000 |

2026-09-15 の見積り v3 の既定値です。Japan East、原則 32h/月の検証、CSPM は既定 OFF です。No.8 と No.12 は常時／検証日の切替で、二重計上しません。No.6 は 第1章/第6章の共通費です。見積り保証ではありません。

## 6.8. 本番との差

保持・マスキング・監査担当の職務分離は本番要件に合わせます。[付録 B](92-appendix-production-diff.md) を参照します。

### 出典

- 出典: [機微なトレース内容](https://learn.microsoft.com/en-us/azure/foundry/observability/how-to/traces-sensitive-content)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）

---

前へ: [人とサービスの権限を設定する](05-identity.md) / 次へ: [ゲートウェイと呼び出しアプリを用意する](07-gateway-app.md) / [トップに戻る](../README.md)
