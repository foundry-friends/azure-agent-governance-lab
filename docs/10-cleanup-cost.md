# 10. 削除と費用を確認する

進め方: README の第0〜10章を順番に実施します。第9章の完了条件を満たしてから進めます。

> **Note** 状態: 構成ドラフト・操作の詳細は未確定（Azure 未実行）。構成変更日 2026-09-15。

## 10.1. 目的

構築と検証の最後に、環境の削除・残存・費用を確認します。途中章の末尾で削除は行いません。

### なぜこの作業が必要か

検証が終わっても、作成したリソースや追加した権限・設定が残ると、継続費用や次の利用者への影響が残ります。共有環境を次の検証に使える状態へ戻すことまでが、このラボの作業範囲です。

この章では、必要な証跡を保存してから自分の検証資産を削除し、リソースグループ外の変更も確認します。削除の受付、リソースの消失、論理削除による保持、費用への反映は分けて確認します。最後に未確認項目も記録することで、次の実施者が検証できた範囲を正しく引き継げるようにします。

## 10.2. 削除前の確認

1. 第1章の予算通知と終了時刻を確認します。
2. 当日に作成したリソース一覧を照合します。D14 の専用 VNet・統合サブネットと Foundry の VNet 規則も対象に含めます。
3. 必要な合成証跡を保存します。
4. 公開用の証跡から実 ID・本文・内部情報を除きます。

今回追加した利用者ロール、Policy、Defender の変更前後、RG 外のリソースも確認します。既存のユーザーやグループは削除しません。

## 10.3. 復帰と削除

1. この検証で変更した Defender 設定を、管理者と合意した変更前の状態へ戻します。
2. 今回追加した RG 外のロール割当・Policy があれば、対象を確認して片付けます。
3. Azure portal で自分の専用 RG を開きます。
4. リソース一覧と保存済みの証跡を確認します。
5. RG の削除操作で対象名を照合して削除します。

> **Note** 要確認: GUI の削除画面、Log Analytics の論理削除と同名再作成への対応、Key Vault の完全削除条件を詳しい操作として確定する必要があります。削除前の判断を終えてから実行します。

### スクリプトで削除する (任意)

GUI で削除した後に再実行する手順ではありません。スクリプトを使う場合だけ、以下を代替経路として使います。

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
6. Cosmos・Storage・Search・APIM・App Service・App Service プラン・専用 VNet の残存を確認します。
7. RG 外の監視資産と Policy 割当を確認します。
8. 第9章で変更した Defender プランの復帰を確認します。
9. 翌日以降の [コスト分析] でサービス別・RG 別・サブスクリプション全体の費用を確認します。

> **Note** 要確認: soft-delete と purge の保持・権限・再作成への影響は（初回で記入）です。削除済みデータの完全消去や請求停止を RG 消失だけで保証しません。

## 10.4. 削除後の確認

費用・後片付けの確認（C10）: RG 消失・soft-delete・RG 外・Defender 復帰・翌日以降の費用を別々に記録します。未確認があれば Pending です。

```bash
bash scripts/verify.sh --section 9
```
実行結果の確認ポイント: 設定収集または案内のみで、未完了は終了コード 2 です。

[確認項目](../checks/README.md) ごとに実施日・Run・入力・期待結果・実結果・Pass / Fail / Pending を非公開の `evidence/` に記録します。未実施は Pending です。

```bash
bash scripts/cost_check.sh
```
実行結果の確認ポイント: ポータル確認の案内だけです。実際の請求取得・確定ではありません。

## 10.5. うまくいかない場合

（初回で記入）

1. 削除待ち上限に達したら状態を再確認します。
2. ロックと共有依存を確認します。
3. 費用反映が遅れている間は完了判定を保留します。

## 10.6. 一周の完了条件

- 専用 RG の消失を確認した。
- 論理削除、RG 外、Defender の状態を確認した。
- 翌日以降の費用を確認した。未反映なら C10 は Pending。
- C01〜C10 の実施結果と未実施理由を記録した。

これで一周です。再現確認は任意で、改めて第0章から最後まで一周します。途中章へ戻ることを通常手順にはしません。

## 10.7. 費用

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

2026-09-15 の見積り v3 の既定値です。Japan East、原則 32h/月の検証、CSPM は既定 OFF です。No.8 と No.12 は常時／検証日の切替で、二重計上しません。No.6 は 第1章/第6章の共通費です。見積り保証ではありません。

D14 の VNet／サブネットは削除対象です。VNet 統合・従来型サービス エンドポイントの機能追加料金はありませんが、アプリ・APIM 等の既存課金は続きます。Excel v3 の資産明細への追記は未実施です。

既定で通常月 $57.56／3 か月 $164.67／12 か月 $682.68、CSPM ON は月 $108.66、AI Search 常時は月 $150.39 です。第10章 自体の追加明細はありません。原則 32h/月という見積り条件と初回・再現の作業時間は別です。実際の稼働時間・削除待ち・無料枠で費用は変わります。

## 10.8. 本番との差

常時稼働の参考は [付録 B](92-appendix-production-diff.md) に分けます。

### 出典

- 出典: [App Service VNet 統合](https://learn.microsoft.com/ja-jp/azure/app-service/overview-vnet-integration)（取得日 2026-09-16。D14 に伴う整合修正の根拠）

この章は既存手順の実行順と判定条件を整理したものです。機能の詳細は各作成章の出典を参照します。

---

前へ: [Policy・脅威検知・評価を試す](09-policy-defender-eval.md) / 次へ: [完了・概要へ](../README.md) / [トップに戻る](../README.md)
