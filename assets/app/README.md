# 呼び出しアプリの仕様（レビュー用）

> **Note** 状態: 仕様ドラフト（Learn 2026-09 時点の記述に基づく・未実装・Azure 未実行）。アプリコード・配布ZIP・固定依存関係はまだありません。仕様を確認してから実装します。

## 目的と範囲

第4章で作成した同じエージェントを、各利用者本人の権限で呼ぶ最小の Python／FastAPI アプリです。D14 の App Service Linux B1、送信 VNet 統合、Foundry VNet 規則を使います。本人経路は APIM を通りません。追加シナリオ A14 として、アプリ専用 Cosmos DB に合成会話メモを JSON で保存する機能を含めます。エージェントの作成・編集、任意 URL への送信、管理者権限への切替は実装しません。

## 1画面の操作

| 項目 | 仕様案 |
|---|---|
| サインイン | Easy Auth で同一テナントへログイン。画面にはログイン済み状態だけを表示 |
| 対象 | サーバー設定で固定したエージェントの表示名。利用者は変更不可 |
| 入力 | 合成プロンプト1件。暫定上限2,000文字。実データを入力しない旨を表示 |
| 送信 | 1回の操作につき1リクエスト。処理中は二重送信を防止 |
| 応答 | テキストとして表示し、HTMLとして解釈しない |
| 結果 | 成功／失敗、失敗した層、相関ID、再認証等の次の操作 |
| 履歴 | 画面内の直近1往復だけ。自動保存と localStorage は使用しない |
| 会話メモを保存 | 利用者が明示的に操作した合成会話1往復だけを、アプリ専用 Cosmos DB へ JSON で保存。成功／失敗を表示 |
| 終了 | サインアウト時に画面の入力・応答を消去 |

最大入力長と60秒のタイムアウトは本アプリの仕様案で、Azureのサービス上限ではありません。タイムアウト時に下流処理が停止したと断定せず、自動再送しません。

## 認証の契約

- App Serviceの入口で認証を要求します。ユーザー間でトークンや会話を共有しません。
- Cosmos 保存だけは App Service のシステム割り当て MI を使います。これは Foundry 呼び出しの MI フォールバックではありません。
- サーバーは利用者本人のアクセストークンでFoundryを呼びます。IDトークン、Graph宛トークン、アプリMIで代用しません。
- Easy Authから受け取る方式では、同サービスを通過した要求ヘッダーだけを信頼します。トークンの宛先・テナント・有効期限を確認する処理と、署名等を含む検証の責任分担を実装前に確定します。
- トークンの不足・期限切れ・同意不足は再認証または担当者への確認を案内します。MIへのフォールバックはしません。
- 状態を変更する送信にはCSRF対策を適用し、他オリジンからの送信を受け付けません。
- アプリ自身の拒否とFoundryが返した拒否を区別します。UIのログイン画面だけでC03を合格にしません。

| 候補 | 採用前の確認 |
|---|---|
| Easy AuthがFoundry用の本人トークンを取得し、アプリが転送 | 委任権限と同意、ログインパラメータ、実トークンの宛先・claim、更新方法 |
| 中間API用の本人トークンをOBOで交換 | 入力audienceが当該中間APIであること、委任権限・同意・サーバー資格情報の管理 |

> **Note** 要確認: どちらを採用するかは未確定です。公式例の `https://ai.azure.com/.default` はスコープ確認の材料で、カスタムアプリの同意・委任設定が完成した証拠ではありません。

## 呼び出す API の契約

公式クイックスタートには、プロジェクトのモデル直接呼び出しと既存エージェントの呼び出しが別々に載っています。本アプリは後者だけを対象にします。参照形式は以下です（実行コマンドではありません）。

| 項目 | 参照形式 |
|---|---|
| HTTP メソッド | POST |
| エージェントの応答 | `https://<account>.services.ai.azure.com/api/projects/<project>/agents/<agent-name>/endpoint/protocols/openai/responses?api-version=v1` |
| 認証 | 利用者本人の Bearer アクセストークン |
| 入力 | 合成入力のみ。モデル名や任意ツールを画面から指定しない |
| ネットワーク | App Serviceの統合サブネットから。社内ブラウザが直接Foundryを呼ぶ設計にはしない |

> **Note** 要確認: 第4章のエージェントと、公式資料の新しいAPI世代との適合性、GA範囲、Consumerでの実行可否、固定版／エージェントバージョンの指定方法を実装前に確認します。資料にPython例があることだけで他の言語・APIもGAと判定しません。モデル直接応答を既存エージェントの呼び出し成功としません。

## 追加機能：会話メモを JSON で保存する（A14・D16）

Agent Service の状態保存とは独立した GA のデータ操作です。Standard／Basic のどちらでも使い、第4章の Cosmos 接続の Preview は使いません。

| 項目 | 仕様 |
|---|---|
| 経路 | App Service の送信 VNet 統合 → `Microsoft.AzureCosmosDB` サービス エンドポイント → Cosmos の統合サブネット VNet 規則 |
| 認証 | App Service のシステム割り当て MI。キー・接続文字列は使わない |
| データロール | Cosmos DB Built-in Data Contributor を `/dbs/<app-db>/colls/<app-container>` だけに付与 |
| 保存先 | Agent Service の `enterprise_memory` と別の `<app-db>/<app-container>` |
| パーティション キー | `/userId` |
| JSON の項目 | `id`、`userId`、`createdAt`、`prompt`、`response`。合成会話だけを保存 |
| ユーザー境界 | サーバーで認証済み主体から導いたアプリ内識別子を `userId` に使う。ブラウザが指定した他人のIDを信用しない |
| 保存操作 | 明示的な [会話メモを保存] のみ。認証・CSRF・入力上限・二重送信防止を適用 |
| 権限の分担 | Cosmos は共有 MI を認可するため、ユーザーごとの保存先制限はアプリが保証。Foundry の本人 RBAC 試験とは別 |
| 禁止する保存先 | Agent Service のコンテナーには書かない。接続先／DB／コンテナーを利用者入力で変更しない |

例は保存形式だけを示すもので、実在の個人識別子を含めません。

```json
{"id":"<memo-id>","userId":"<app-user-id>","createdAt":"<utc-timestamp>","prompt":"架空の会議メモを整理してください。","response":"架空の会議メモの要約です。"}
```
実行結果の確認ポイント: 明示操作後にアプリ専用コンテナーで JSON が見え、`/userId` と認証済み利用者の対応が一致することを確認します。

保存本文やユーザー識別子は診断ログへ出しません。Data Explorer での確認は許可された検証担当者だけが行います。サインアウトでは画面だけを消去し、保存データの後片付けは第10章の環境削除に含めます。読出し一覧・メモ編集等の機能は今回追加しません。

## 設定項目案

名称は本アプリの予定名です。実値はApp Serviceの保護された設定等へ登録し、このリポジトリへ保存しません。

| 項目 | 用途・扱い |
|---|---|
| `FOUNDRY_PROJECT_ENDPOINT` | 管理者が設定したHTTPSエンドポイント。許可ホスト・パスを検査 |
| `FOUNDRY_AGENT_NAME` | 固定の既存エージェント。利用者入力から上書き不可 |
| `ENTRA_TENANT_ID` | 許可テナント |
| 認証アプリID・資格情報 | 認証方式の確定後に命名・保管方法を確定。ZIPへ含めない |
| 下流スコープ・audience | 認証方式とAPIの確定後に固定。画面から変更不可 |
| `COSMOS_ENDPOINT` | 第3章の Cosmos HTTPS エンドポイント。管理者が固定 |
| `COSMOS_DATABASE` / `COSMOS_CONTAINER` | `<app-db>` / `<app-container>` を固定。`enterprise_memory` は指定不可 |
| `APP_VERSION` | 配布版の識別子 |
| 入力上限・タイムアウト | レビュー後に固定。上限超過をサーバー側でも拒否 |

## ログと証跡

記録するのは、アプリが生成した相関ID、UTC時刻、処理時間、成功／失敗、HTTPステータス、拒否した層、配布版だけです。下流の要求IDは、返された場合に限り別欄で扱い、同じIDが全サービスへ自動伝播すると仮定しません。

プロンプト・応答本文・氏名・メール・生のユーザーID・トークン・Cookie・Authorization・環境変数の一覧・例外の生データをログへ出しません。APMやHTTPクライアントのデバッグログも同じ条件で制限します。画面の応答表示と永続ログは別です。Foundry側の保存・監査・保持は第4・6章の設定に従い、明示操作によるアプリ専用 JSON 保存と区別します。画面を消しても保存済みメモを削除したことにはなりません。

## 配布物と配布方式

配布時にはソース、固定した依存関係、Pythonランタイム、FastAPI起動設定、リリースZIP、ハッシュ、設定手順を揃えます。現時点ではいずれも未作成です。

配布は社内 PC の Azure CLI を使う方式を暫定採用しました（2026-09-16）。LinuxではKuduのZIPデプロイUIが使えず、Azure側で動くCloud Shellは社内PCの送信元IPを引き継がないためです。SCMの社内IP制限を維持できる経路として、配布時だけローカルCLIを使います。例外は配布とその認証・対象確認に限定します。

具体的な理由・前提・コマンドは[第7章の配布手順](../../docs/07-gateway-app.md#なぜ配布時だけ社内-pc-を使うのか)にまとめます。配布担当者のEntra認証と、アプリ利用者のFoundry用認証は別です。実機検証で到達性と権限を再評価し、必要なら手順を見直します。

> **Note** 要確認: 配布方式は暫定採用済みですが、SCM到達・配布の実機成立、依存関係のビルド場所、起動設定、Pythonの固定版は未確認です。ネットワーク制限やFTP無効を緩めて配布を成立させません。

## 実装後の受入条件

| 試験 | 期待結果 |
|---|---|
| 社内／社外から入口へ接続 | 社内の認証済みユーザーが使用でき、許可外IPは入口で拒否 |
| Consumer／User／無権限 | 第5・8章の本人ごとの権限に沿う。共有MIの権限で成功しない |
| 期限切れ・宛先不一致 | 再認証または拒否。トークンを画面・ログへ出さない |
| セッション分離 | 別ユーザーへ応答・トークン・会話を渡さない |
| 入力・出力 | 上限、二重送信、CSRF、HTML文字列の扱いを確認 |
| 到達性 | 統合先とVNet規則を照合し、対象エージェントから応答を得る |
| デプロイ | SCM制限下で同じ固定版を配置・起動できる |
| Cosmos 保存 | 明示操作した JSON がアプリ専用コンテナーの Data Explorer で見え、Agent Service のコンテナーに書かれない |
| Cosmos 認可・分離 | キー無しの MI 認証、コンテナースコープ、他人の `userId` を指定できないことを確認 |
| ログ | 合成入力で本文・トークンが診断ログに記録されないことを確認 |

### 出典

- 出典: [Foundry SDK クイックスタート](https://learn.microsoft.com/ja-jp/azure/foundry/quickstarts/get-started-code)（取得日 2026-09-16）
- 出典: [Foundry RBAC](https://learn.microsoft.com/ja-jp/azure/foundry/concepts/rbac-foundry)（取得日 2026-09-16）
- 出典: [Easy Auth のトークン](https://learn.microsoft.com/ja-jp/azure/app-service/configure-authentication-oauth-tokens)（取得日 2026-09-16）
- 出典: [OBO](https://learn.microsoft.com/ja-jp/entra/identity-platform/v2-oauth2-on-behalf-of-flow)（取得日 2026-09-16）
- 出典: [Python Web アプリ](https://learn.microsoft.com/ja-jp/azure/app-service/quickstart-python)（取得日 2026-09-16）
- 出典: [ZIP デプロイとLinux制約](https://learn.microsoft.com/ja-jp/azure/app-service/deploy-zip)（取得日 2026-09-16）

- 出典: [Cosmos DB の IP 規則とサービス エンドポイント](https://learn.microsoft.com/en-us/azure/cosmos-db/how-to-configure-firewall)（取得日 2026-09-19）
- 出典: [Cosmos DB の VNet 規則](https://learn.microsoft.com/en-us/azure/cosmos-db/how-to-configure-vnet-service-endpoint)（取得日 2026-09-19）
- 出典: [Cosmos DB のデータ面 RBAC](https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/how-to-connect-role-based-access-control)（取得日 2026-09-19）

---

[第7章に戻る](../../docs/07-gateway-app.md) / [トップ](../../README.md)
