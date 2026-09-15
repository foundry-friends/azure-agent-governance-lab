# 7. ゲートウェイと呼び出しアプリ

このセクションを使う Run: Run 2。先に要るセクション: S1・S2・S5・S6。

> **Note** 現在は骨組み・Azure 未実行です。コマンドはリポジトリ直下の Bash で実行する予定の手順です。

## 7.1. 目的

統制層③・⑩と②の送信制御として、APIM Basic v2 と App Service B1 の呼び出し経路を準備します。

## 7.2. 前提

S1・S2・S5・S6 の準備が必要です。キーを使わず、Entra ID / MI とユーザーコンテキストを設計します。

> **Note** 要確認: 社内 IP 限定の APIM は agent service や App Service からの呼び出しも拒否し得ます。許可 IP の観測値と認証主体を確認し、両立できなければ C08/C09 を Pending にします。社内 IP 以外へ許可を勝手に追加しません。

## 7.3. 構築

### ゲートウェイとアプリを準備する

1. `run2.local.json` の `enableApim=true` を確認します。
2. [07_gateway_app.bicep](../infra/modules/07_gateway_app.bicep) の設定を確認します。
3. APIM の [API] で許可済みバックエンドだけを登録します。
4. 対象 API の [サブスクリプションが必要] をオフにします。
5. API の [ポリシー] に Entra トークン検証を設定します。
6. バックエンドに対する MI の必要な権限を設定します。
7. App Service の [認証] で利用者の Entra ID 認証を設定します。
8. OBO によるユーザーコンテキストの伝達を確認します。

| 項目 | 値 |
|---|---|
| APIM SKU | `BasicV2` |
| APIM 入口 | `ip-filter action=allow`、社内 IP のみ |
| App Service | Linux B1、HTTPS のみ |
| アプリの入口 | `ipSecurityRestrictionsDefaultAction=Deny`、社内 IP のみ |
| SCM | メインサイトと同じ IP 規則 |
| ツールの出口 | MCP / OpenAPI は APIM の許可済み API のみ |
| モデル | Foundry 内の承認済みモデル |

> **Note** 要確認: Bicep はリソースと IP 制限の骨組みです。アプリコード、OBO、JWT audience / scope、許可済みバックエンド、MI 認証、アプリ配布は未実装です。AI Gateway 統合の Preview 部分は対象外です。

### IP ポリシーを設定する

1. [API] の [すべての API] の [ポリシー] を確認します。
2. 社内 IP の CIDR を開始・終了アドレスへ変換した規則を確認します。
3. 下位スコープで規則を迂回できないことを確認します。

```xml
<ip-filter action="allow">
  <address-range from="192.0.2.1" to="192.0.2.1" />
</ip-filter>
```
実行結果の確認ポイント: 文書用アドレスを社内の承認値へ置き換えます。CIDR を `<address>` に直接入れません。

[公式 ip-filter](https://learn.microsoft.com/ja-jp/azure/api-management/ip-filter-policy) に従います。Bicep は `allowedIpRanges` と変換済み `allowedIpAddressRanges` を受け取り、対応は deploy.sh が検査します。

### ツールの許可先とトークン上限を設定する

1. エージェントの [ツール] に許可済み APIM URL だけを登録します。
2. バックエンド URL が入力で変更できないことを確認します。
3. 公開ツールを追加できる編集主体を制限します。
4. `llm-token-limit` の quota・期間・集計キーを設定します。
5. content safety と LLM ログの GA 対応範囲を確認します。
6. 本文ログの収集範囲・マスキング・30 日保持・閲覧権限を設定します。

> **Note** 要確認: [トークン制限](https://learn.microsoft.com/en-us/azure/api-management/llm-token-limit-policy) の対応モデル・配置・属性と、content safety / LLM ログの Basic v2 対応を確認します。Preview に依存する統合は GA 後に追記します。token quota はインフラ費用全体の停止機能ではありません。

## 7.4. 確認

C09: APIM 経由ログ、正常／拒否入力、quota 超過 403（レート制限とは別）、ガードレール適用を確認します。C08: 許可ツール成功、未許可ツール失敗、直接呼び出しの迂回防止を確認します。

```bash
bash scripts/verify.sh --section 7
```
実行結果の確認ポイント: 設定収集または案内のみで、未完了は終了コード 2 です。

[確認項目](../checks/README.md) ごとに実施日・Run・入力・期待結果・実結果・Pass / Fail / Pending を非公開の `evidence/` に記録します。未実施は Pending です。

## 7.5. うまくいかない場合

（Run 2 初回で記入）

1. APIM が観測する送信元 IP と認証拒否を切り分けます。
2. App Service → APIM、agent service → APIM、APIM → Foundry の各経路を分けて確認します。
3. 社内 IP 限定と両立しない経路は要確認として記録します。
4. データ基盤の到達だけが失敗する場合は [S4 の代替手順](11-data.md) を使います。

## 7.6. 削除

1. 当日に構築したリソースと共有依存を確認します。
2. [S9](90-cleanup-cost.md) に従って専用 RG を削除します。
3. RG 外・soft-delete・Defender の設定を別々に確認します。

> **Note** 要確認: 部分削除時の依存・capability host の再作成可否は（Run 1 初回で記入）です。

## 7.7. 費用

| Excel v3 明細 No | 項目 | 通常月 USD |
|---|---|---:|
| 11 | API Management / Basic v2 | 6.575360 |
| 13 | App Service / Linux B1 | 0.608000 |

2026-09-15 の見積り v3 の既定値です。Japan East、原則 32h/月の検証、CSPM は既定 OFF です。No.8 と No.12 は常時／検証日の切替で、二重計上しません。No.6 は S1/S6 の共通費です。見積り保証ではありません。

## 7.8. 本番との差

本番の接続・SKU・入口防御の差は [付録 B](92-appendix-production-diff.md) を参照します。

---

前へ: [監視と監査](13-monitoring.md) / 次へ: [ポリシー・脅威検知・評価](15-policy-defender-eval.md) / [トップに戻る](../README.md)
