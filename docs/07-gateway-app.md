# 7. ゲートウェイと呼び出しアプリを用意する

進め方: README の第0〜10章を順番に実施します。第6章の完了条件を満たしてから進めます。

> **Note** 状態: 構成ドラフト・操作の詳細は未確定（Azure 未実行）。構成変更日 2026-09-15。

> **補足** この章では環境を削除しません。通常の削除は最後の第10章です。中断して片付ける場合だけ、第10章へ進みます。

## 7.1. 目的

同じエージェントを呼び出すブラウザ用アプリと APIM を用意します。利用者本人の権限で試せる入口ができてから、次の章で統制試験をします。

## 7.2. 前提

エージェント、利用者ロール、監視の土台を設定済みです。社内 PC・App Service・Agent Service・APIM の送信元を区別します。

> **Note** 要確認: 社内 IP 限定の APIM／Foundry にサービス発信が到達する設計は未確定です。送信元の観測と許可方針を確定するまで無断で許可範囲を広げません。

## 7.3. 構築

### ゲートウェイとアプリを準備する

1. 自分の専用 RG 内に APIM Basic v2 と App Service B1 を作成します。
2. 下表の目標設定と作成済みリソースを照合します。
3. APIM の [API] で許可済みバックエンドだけを登録します。
4. 対象 API の [サブスクリプションが必要] をオフにします。
5. API の [ポリシー] に Entra トークン検証を設定します。
6. 利用者の委任トークンを保つ経路と、サービスの MI を使う経路を分けて設定します。
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

> **Note** 要確認: 作成ウィザードの GUI 手順も未確定です。Bicep はリソースと IP 制限の骨組みです。アプリコード、OBO、JWT audience / scope、許可済みバックエンド、MI 認証、アプリ配布は未実装です。AI Gateway 統合の Preview 部分は対象外です。

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

### 呼び出しアプリの認証要件

この章で用意するアプリは次の条件を満たす必要があります。実装と GUI デプロイ手順が未完了なら、この章で停止します。

| 経路 | 第7章で確定すること |
|---|---|
| ブラウザ → アプリ | Easy Auth のサインイン主体、対象テナント、未認証時の拒否 |
| アプリ → APIM → Foundry | ユーザーの委任トークンで呼ぶ経路と、サービスの MI で呼ぶ経路の区別 |
| C02 の利用者試験 | Foundry がテストユーザー本人を認可すること。全員を同じ MI に置き換えないこと |
| トークン取得 | Foundry が要求する audience／scope、同意、転送または OBO の必要性 |
| 証跡 | 主体・対象・成功／拒否・拒否した層を記録し、トークン本文は保存しないこと |

> **補足** Easy Auth でログインできても下流 API 用トークンの取得は別設定です。APIM の `authentication-managed-identity` は APIM の ID で下流トークンを取得するため、その経路だけでは利用者本人の Foundry RBAC を検証できません。

> **Note** 要確認: 利用者の委任認証を保った呼び出しアプリは未実装です。Consumer の管理画面アクセス失敗を呼び出し拒否と取り違えず、実行経路ができるまで対応する C02／C03 は Pending とします。

### 方式 A で送信先を絞る

1. エージェントの [ツール] 一覧で Bing / Web search / SharePoint を追加していないことを確認します。
2. モデルを Foundry 内の承認済みモデルに限定します。
3. MCP / OpenAPI の登録先を 第7章の APIM に限定します。
4. APIM の許可済みバックエンドを固定し、入力から任意 URL を指定できないようにします。
5. ツールを追加・編集できる主体を RBAC と変更手順で限定します。

> **Note** 要確認: RBAC だけで個別ツール種別を禁止できるとは断定しません。編集権限を持つ主体の迂回を確認します。方式 A は Microsoft 管理ネットワーク全体の FQDN 制御ではありません。

### APIM のログをここで追加する

APIM を作成したこの章で、診断設定の送信先を既存の Log Analytics にします。対象カテゴリと GA のログ方式を確認し、正常呼び出しの経由ログを確認します。まだ存在しなかった APIM の設定を第6章へ戻って行いません。

> **Note** 要確認: APIM ログのカテゴリ・画面・利用者トークン経路を確定して、用意済みアプリの GUI デプロイ手順を同梱する必要があります。

## 7.4. 完了条件

- ブラウザで検証用アプリを開ける。
- 権限ありの本人トークンで同じエージェントから応答が返る。
- APIM 経由と認可された主体を確認できる。
- ログを確認できる。トークン本文は保存しない。

アプリ未実装のまま次章の試験を実施可能とは扱いません。現時点ではこの完了条件は未達です。

## 7.5. うまくいかない場合

（ゲートウェイ追加後 初回で記入）

1. APIM が観測する送信元 IP と認証拒否を切り分けます。
2. App Service → APIM、agent service → APIM、APIM → Foundry の各経路を分けて確認します。
3. 社内 IP 限定と両立しない経路は要確認として記録します。
4. データ基盤の到達だけが失敗する場合は 接続時の拒否結果と今回の結果を照合し、認証とネットワークを切り分けます。

## 7.6. 次の操作

環境をそのまま使い、第8章で権限・認証・IP・ツール・quota の差を試します。

## 7.7. 費用

| Excel v3 明細 No | 項目 | 通常月 USD |
|---|---|---:|
| 11 | API Management / Basic v2 | 6.575360 |
| 13 | App Service / Linux B1 | 0.608000 |

2026-09-15 の見積り v3 の既定値です。Japan East、原則 32h/月の検証、CSPM は既定 OFF です。No.8 と No.12 は常時／検証日の切替で、二重計上しません。No.6 は 第1章/第6章の共通費です。見積り保証ではありません。

## 7.8. 本番との差・IaC で再現する (任意)

本番の接続・SKU・入口防御の差は [付録 B](92-appendix-production-diff.md) を参照します。

[07_gateway_app.bicep](../infra/modules/07_gateway_app.bicep) は再現用の骨組みです。一式の再展開を主線には使いません。

### 出典

- 出典: [Foundry の RBAC](https://learn.microsoft.com/ja-jp/azure/foundry/concepts/rbac-foundry)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Key Vault を portal で作成](https://learn.microsoft.com/ja-jp/azure/key-vault/general/quick-create-portal)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Azure ロールの割当](https://learn.microsoft.com/ja-jp/azure/role-based-access-control/role-assignments-portal)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Key Vault の RBAC](https://learn.microsoft.com/ja-jp/azure/key-vault/general/rbac-guide)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Key Vault のネットワーク](https://learn.microsoft.com/ja-jp/azure/key-vault/general/network-security)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Key Vault の論理削除](https://learn.microsoft.com/ja-jp/azure/key-vault/general/soft-delete-overview)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Standard setup](https://learn.microsoft.com/ja-jp/azure/foundry/agents/concepts/standard-agent-setup)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [BYO リソース](https://learn.microsoft.com/ja-jp/azure/foundry/agents/how-to/use-your-own-resources)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Search のロール認証](https://learn.microsoft.com/ja-jp/azure/search/search-security-enable-roles)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Storage 共有キーの無効化](https://learn.microsoft.com/ja-jp/azure/storage/common/shared-key-authorization-prevent)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Cosmos DB の RBAC とキー無効化](https://learn.microsoft.com/ja-jp/azure/cosmos-db/nosql/how-to-connect-role-based-access-control)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Foundry Tools のローカル認証無効化](https://learn.microsoft.com/ja-jp/azure/ai-services/disable-local-auth)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [条件付きアクセスの適用ログ](https://learn.microsoft.com/ja-jp/entra/identity/monitoring-health/how-to-view-applied-conditional-access-policies)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [継続的アクセス評価](https://learn.microsoft.com/ja-jp/entra/identity/conditional-access/concept-continuous-access-evaluation)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Easy Auth の OAuth トークン](https://learn.microsoft.com/ja-jp/azure/app-service/configure-authentication-oauth-tokens)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [APIM の Managed Identity 認証](https://learn.microsoft.com/ja-jp/azure/api-management/authentication-managed-identity-policy)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [az keyvault](https://learn.microsoft.com/ja-jp/cli/azure/keyvault)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [az role assignment](https://learn.microsoft.com/ja-jp/cli/azure/role/assignment)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [az resource](https://learn.microsoft.com/ja-jp/cli/azure/resource)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [公式テンプレート 41（固定コミット）](https://github.com/microsoft-foundry/foundry-samples/tree/58e4127567f7e9afcf0145d874df890284ca5faf/infrastructure/infrastructure-setup-bicep/41-standard-agent-setup)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [公式 ip-filter](https://learn.microsoft.com/ja-jp/azure/api-management/ip-filter-policy)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [トークン制限](https://learn.microsoft.com/en-us/azure/api-management/llm-token-limit-policy)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）

---

前へ: [監視と監査を設定する](06-monitoring.md) / 次へ: [権限・認証・ネットワークの統制を試す](08-governance-tests.md) / [トップに戻る](../README.md)
