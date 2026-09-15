# Run 0：準備（机上）

Azure未実行。今回は公式ソース取得・パラメータ照合・文書組み替えのみ実施。権限・会社承認・予算通知の設定は未実施です。

## 0. 前日まで

[S0](../sections/00_overview.md) と [設計判断](../00_design.md) を読み、上長に予算・期間・CSPM・公開規程を確認します。個人検証用の専用RGと匿名の命名・タグを計画し、実IDは.env / *.local.jsonだけに保存します。

### 部門検証環境で先に確認する権限・制約

- [ ] 対象RGのOwner、またはリソース作成権限＋User Access Administrator。公式41が記載するFoundry Account Owner / Role Based Access Administratorとの対応・実効scopeを確認。
- [ ] VNetとMicrosoft.App/environmentsへのサブネット委任、prompt agent用/27以上を作れるか。既存hub VNet・DNS・UDR・アドレス重複の会社ルール。hostedの/24は付録。
- [ ] Azure Policy割当（Resource Policy Contributor等）とeffectの可否。権限がなければ管理者の監査結果を確認する範囲へ落とし、割当済みとしない。
- [ ] Defender for Cloudプラン設定（Security Admin等）、サブスクリプション単位の費用・他チームへの影響・変更前状態・復帰方法を管理者と合意。CSPM既定OFF。
- [ ] Japan EastのFoundry Agent Service、gpt-5 mini / Global Standardのモデル版・TPMクォータ・SKU提供。
- [ ] Cost Managementの予算作成権限・月予算・通知先・50%/80%/100%と予測超過。通知の実確認はC10、予算通知は停止ではない。権限がなければ手動日次確認を合意。
- [ ] IaC/手順の公開範囲と会社名・内部情報の除去。Public化は会社規程確認後。

参照指定の「計画§2」に詳細権限リストはないため、実機検証プラン§2のリストを匿名化して補っています。上記チェックは未確認のままです。

## 1. タイムライン

| 机上作業 | 時間 |
|---|---:|
| 会社ルール・権限の確認 | 2h |
| コミット固定・パラメータ確定のレビュー | 2h |
| 組み替えたリポのレビュー | 2h |
| 合計 | 6h |

1〜2h単位で分割可、承認待ちと並行。Run 1〜3の8h枠は構築3h・検証3h・執筆1h・削除1hで、この机上Runには適用しません。

## 2. 立てるセクションと順番

Azureリソースは立てません。[S1](../sections/01_foundation.md) の準備部分を行います。

1. 権限・予算の承認状況を上のチェックリストで確認。
2. [PINNED_COMMIT](../../infra/PINNED_COMMIT.md)：mainのSHA `58e4127567f7e9afcf0145d874df890284ca5faf`、UTC `2026-09-15T05:43:04.099021+00:00`。41/15の指定パスは存在し、相対依存とLICENSEを取得済み。
3. [41_parameters](../../infra/params/41_parameters.md)：全17param、RG scope、トップレベルoutputs0件、15の31paramを確認。
4. [Run 1例](../../infra/params/run1.example.json) をlocal.jsonへ。BYOサーバーレス/Basic/LRS、Foundryローカル認証、Key Vault、Entra IDだけのApp Insightsの未解決事項をレビュー。
5. 予算アラートの値・通知先を決める。作成・通知試験は利用者の環境で実施して記録。

41のモデル・locationはparamで指定可。容量モード・Search SKU・ローカル認証のparamはなく、App Insightsの既定接続はApiKeyです。目標構成が確定したとは扱いません。bicep buildはこの環境で未実行。

## 3. 確認する C 番号

机上作業にCの合格判定はありません。C01〜C10は全てPending。予算通知の設定・実確認はRun 1のC10に引き継ぎます。

## 4. 削除と翌日の課金確認

今回はAzureを作成していないのでクラウド削除はしません。既存環境の費用がゼロと判断したことにもなりません。vendorはローカルの公開対象外コピーです。

## 5. 初回と再現日の違い

Run 0は机上準備の6h。Run 1〜3は各初回＋再現の2日で、再現日は書いた手順だけで再現し差分を直します。会社確認と未実装箇所を終えるまでRun 1へ進みません。
