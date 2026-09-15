# 9. 削除と費用

このセクションを使う Run: Run 1／Run 2。先に要るセクション: 当日に構築した全セクション。

> **Note** 現在は骨組み・Azure 未実行です。コマンドはリポジトリ直下の Bash で実行する予定の手順です。

## 9.1. 目的

統制層⑩として、削除受付、RG 消失、残存、課金停止の確認を分けて記録します。

## 9.2. 前提

専用 RG の対象、ロック、共有依存、削除予定を確認します。実 ID と内部情報は非公開記録だけに保存します。

## 9.3. 構築

1. S1 の予算通知と終了時刻を確認します。
2. 当日に作成したリソース一覧を照合します。
3. 必要な合成証跡を保存します。
4. 公開用の証跡から実 ID・本文・内部情報を除きます。

## 9.4. 確認

C10: RG 消失・soft-delete・RG 外・Defender 復帰・翌日以降の費用を別々に記録します。未確認があれば Pending です。

```bash
bash scripts/verify.sh --section 9
```
実行結果の確認ポイント: 設定収集または案内のみで、未完了は終了コード 2 です。

[確認項目](../checks/README.md) ごとに実施日・Run・入力・期待結果・実結果・Pass / Fail / Pending を非公開の `evidence/` に記録します。未実施は Pending です。

```bash
bash scripts/cost_check.sh
```
実行結果の確認ポイント: ポータル確認の案内だけです。実際の請求取得・確定ではありません。

## 9.5. うまくいかない場合

（Run 1 初回で記入）

1. 削除待ち上限に達したら状態を再確認します。
2. ロックと共有依存を確認します。
3. 費用反映が遅れている間は完了判定を保留します。

## 9.6. 削除

1. `.env` のテナント・サブスクリプション・専用 RG を照合します。
2. RG 内の全リソースを削除してよいことを確認します。
3. 削除スクリプトを実行します。

```bash
bash scripts/teardown.sh --delete "$AZURE_RESOURCE_GROUP"
```
実行結果の確認ポイント: 削除受付と RG 消失を区別します。

4. 状態を確認します。

```bash
bash scripts/teardown.sh --status
```
実行結果の確認ポイント: RG が存在する場合は終了コード 2 です。

5. Key Vault と Foundry の soft-delete / purge 状態を確認します。
6. Cosmos・Storage・Search・APIM・App Service の残存を確認します。
7. RG 外の監視資産と Policy 割当を確認します。
8. S8 で変更した Defender プランの復帰を確認します。
9. 翌日以降の [コスト分析] でサービス別・RG 別・サブスクリプション全体の費用を確認します。

> **Note** 要確認: soft-delete と purge の保持・権限・再作成への影響は（Run 1 初回で記入）です。削除済みデータの完全消去や請求停止を RG 消失だけで保証しません。

## 9.7. 費用

| Excel v3 明細 No | 項目 | 通常月 USD |
|---|---|---:|
| 1 | Microsoft Foundry リソース / project / prompt agent | 0.000000 |
| 2 | Azure Cosmos DB / サーバーレス RU | 0.285000 |
| 3 | Azure Cosmos DB / サーバーレス Storage | 0.282500 |
| 4 | Storage account / Standard LRS Hot | 0.200000 |
| 5 | Key Vault / Standard 操作 | 0.030000 |
| 6 | Log Analytics / Analytics Logs 取り込み | 10.020000 |
| 7 | Application Insights / Workspace-based | 0.000000 |
| 8 | AI Search / Basic 常時分 | 0.000000 |
| 9 | Entra ID / Managed Identity / RBAC / 基本機能 | 0.000000 |
| 10 | Azure Policy / Cost Management 予算アラート / Activity Log / 基本機能 | 0.000000 |
| 11 | API Management / Basic v2 | 6.575360 |
| 12 | AI Search / Basic 検証日分 | 4.256000 |
| 13 | App Service / Linux B1 | 0.608000 |
| 14 | gpt-5 mini / Global Standard 入力 | 9.000000 |
| 15 | gpt-5 mini / Global Standard 出力 | 10.800000 |
| 16 | Content Safety / Standard テキストレコード | 7.500000 |
| 17 | Defender for AI Services / Standard | 8.000000 |
| 18 | Log Analytics / 保持（30日既定） | 0.000000 |
| 19 | Defender CSPM / Standard | 0.000000 |

2026-09-15 の見積り v3 の既定値です。Japan East、原則 32h/月の検証、CSPM は既定 OFF です。No.8 と No.12 は常時／検証日の切替で、二重計上しません。No.6 は S1/S6 の共通費です。見積り保証ではありません。

既定で通常月 $57.56／3 か月 $164.67／12 か月 $682.68、CSPM ON は月 $108.66、AI Search 常時は月 $150.39 です。S9 自体の追加明細はありません。原則 32h/月という見積り条件と初回・再現の作業時間は別です。実際の稼働時間・削除待ち・無料枠で費用は変わります。

## 9.8. 本番との差

常時稼働の参考は [付録 B](92-appendix-production-diff.md) に分けます。

---

前へ: [ポリシー・脅威検知・評価](15-policy-defender-eval.md) / 次へ: [作り込み（hosted agent）の分岐 (任意)](91-appendix-hosted-agent.md) / [トップに戻る](../README.md)
