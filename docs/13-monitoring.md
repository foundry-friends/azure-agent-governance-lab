# 6. 監視と監査

このセクションを使う Run: Run 1／Run 2。先に要るセクション: S1・S5。

> **Note** 現在は骨組み・Azure 未実行です。コマンドはリポジトリ直下の Bash で実行する予定の手順です。

## 6.1. 目的

統制層⑦として、診断監査・本文トレース・Activity Log と閲覧制御を分けて確認します。

## 6.2. 前提

S1 の既存 Log Analytics workspace と S5 が必要です。本文閲覧を許可する主体と許可しない主体を用意します。

## 6.3. 構築

### Application Insights を接続する

1. S1 の `LOG_ANALYTICS_RESOURCE_ID` を確認します。
2. [06_diagnostics.bicep](../infra/modules/06_diagnostics.bicep) で既存 LAW に接続する Application Insights を準備します。
3. Foundry project の [監視] でトレース接続を確認します。
4. Entra ID による送信経路を確認できた場合だけ本文収集を設定します。

> **Note** 要確認: 41 の App Insights 接続は ApiKey / ConnectionString のため使いません。Entra ID のみの接続・SDK・必要ロール・本文収集方法は（Run 1 初回で記入）です。接続文字列を貼る方法に切り替えず、未解決なら C05 を Pending にします。

### 診断ログを設定する

1. Foundry の診断カテゴリを列挙します。

```bash
az monitor diagnostic-settings categories list --subscription "$AZURE_SUBSCRIPTION_ID" --resource "$FOUNDRY_ACCOUNT_RESOURCE_ID" --output table
```
実行結果の確認ポイント: 実在カテゴリとログ種別を確認します。

2. 各リソースの [診断設定] を開きます。
3. 下表の対象で実在するカテゴリを選択します。
4. 送信先に S1 の Log Analytics を指定します。
5. [保存] を選択します。
6. 合成操作を発生させます。
7. [ログ] で対応レコードを確認します。

| 項目 | 値 |
|---|---|
| 対象 | Foundry・Cosmos・AI Search・Key Vault・Run 2 の APIM |
| カテゴリ | 対象ごとに列挙した監査・操作・拒否ログだけ |
| 保持 | 30 日（LAW と各テーブルを確認） |
| 本文 | トレースの `AppGenAIContent` と閲覧権限を別確認 |

8. [アクティビティ ログ] で構成変更の記録を確認します。
9. Foundry の Purview Audit トグルの利用条件を確認します。

> **Note** 要確認: ネットワーク拒否ログの所在、反映時間、Purview Audit の GA・権限・利用条件は（Run 1 初回で記入）です。有償 Purview 機能は追加しません。

> **補足** 診断ログにはプロンプト本文があることを期待しません。[機微なトレース内容](https://learn.microsoft.com/en-us/azure/foundry/observability/how-to/traces-sensitive-content) とモデル呼び出しの記録を区別します。

## 6.4. 確認

C04: 必要な診断ログの到着を確認します。C05: 合成本文の到着、閲覧許可／拒否、30 日保持を確認します。project MI に広い本文閲覧権限を付与する場合は実効スコープも確認します。

```bash
bash scripts/verify.sh --section 6
```
実行結果の確認ポイント: 設定収集または案内のみで、未完了は終了コード 2 です。

[確認項目](../checks/README.md) ごとに実施日・Run・入力・期待結果・実結果・Pass / Fail / Pending を非公開の `evidence/` に記録します。未実施は Pending です。

## 6.5. うまくいかない場合

（Run 1 初回で記入）

1. 診断カテゴリ・送信先・反映待ちを確認します。
2. 本文がなければトレース収集と Entra ID 経路を確認します。
3. 本文閲覧権限を広げて解決したことにせず、必要主体だけに限定します。

## 6.6. 削除

1. 当日に構築したリソースと共有依存を確認します。
2. [S9](90-cleanup-cost.md) に従って専用 RG を削除します。
3. RG 外・soft-delete・Defender の設定を別々に確認します。

> **Note** 要確認: 部分削除時の依存・capability host の再作成可否は（Run 1 初回で記入）です。

## 6.7. 費用

| Excel v3 明細 No | 項目 | 通常月 USD |
|---|---|---:|
| 6 | Log Analytics / Analytics Logs 取り込み | 10.020000 |
| 7 | Application Insights / Workspace-based | 0.000000 |
| 18 | Log Analytics / 保持（30日既定） | 0.000000 |

2026-09-15 の見積り v3 の既定値です。Japan East、原則 32h/月の検証、CSPM は既定 OFF です。No.8 と No.12 は常時／検証日の切替で、二重計上しません。No.6 は S1/S6 の共通費です。見積り保証ではありません。

## 6.8. 本番との差

保持・マスキング・監査担当の職務分離は本番要件に合わせます。[付録 B](92-appendix-production-diff.md) を参照します。

---

前へ: [Foundry とエージェント](12-foundry-agent.md) / 次へ: [ゲートウェイと呼び出しアプリ](14-gateway-app.md) / [トップに戻る](../README.md)
