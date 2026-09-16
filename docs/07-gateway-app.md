# 7. ゲートウェイと呼び出しアプリを用意する

進め方: README の第0〜10章を順番に実施します。第6章の完了条件を満たしてから進めます。

> **Note** 状態: ドラフト（Learn 2026-09 時点の記述に基づく・未実行）。取得日 2026-09-16。サービス間通信は 7.2 の案 C（2026-09-16 決定）で進めます。案 C に合わせた操作手順の書き直しとアプリの配布が未完のため、現時点では作成前に停止します。

> **補足** この章では環境を削除しません。通常の削除は最後の第10章です。中断して片付ける場合だけ、第10章へ進みます。

## 7.1. 目的

同じエージェントを利用者本人の権限で呼び出すブラウザ用アプリと、ツール経路用の APIM を用意します。本人の経路は App Service から Foundry を直接呼び、APIM は Agent Service からのツール呼び出しを通す入口にします。利用者本人の権限で試せる入口ができてから、次の章で統制試験をします。

### なぜこの作業が必要か

開発用の画面で応答を確認するだけでは、呼び出し専用ユーザーが実際に利用する経路の統制を試せません。利用者がブラウザからエージェントを呼び出し、その本人の権限が反映される経路を用意する必要があります。

この章では、呼び出しアプリを利用者の入口として用意し、APIM を通す対象と許可する呼び出し先を整理します。アプリへのサインインと、その利用者が Foundry で操作できるかを区別して確認するための準備です。本人トークンの経路が確定してから、第8章でユーザーや接続元を変える試験に使います。

## 7.2. 前提と作成前の停止条件

第4章の接続条件を解決し、同じエージェントの応答、第5章の権限設定、第6章の通常診断の設定を確認済みであることを前提とします。第6章で保留した本文監査は保留のまま引き継ぎます。

### 通信の送信元を分ける

ブラウザでアプリを開いた人の IP が、後段のサービス間通信でも使われるわけではありません。次の表は現在の目標構成に公式仕様を当てはめた設計上の判断です。実測した結果ではありません。

| 通信 | 受信側が制限する送信元 | 現在の前提との関係 |
|---|---|---|
| 社内ブラウザ → App Service | 社内の外向き IP | 社内 IP の許可規則を適用する入口です |
| App Service → APIM | App Service の送信 IP 群 | APIM が社内 IP だけを許可すると、この経路を許可できません |
| APIM Basic v2 → Foundry | APIM が使用する Azure 側の送信 IP | Basic v2 に専用の固定送信 IP はありません。社内 IP の許可規則では許可できません。リージョン範囲の許可も Foundry の IP 規則上限（100 件）を超えるため登録できません |
| Agent Service → ツール用 APIM | Agent Service 側の送信元 | 社内 PC の IP と同一ではなく、固定 IP の公開仕様もありません。APIM の SKU を変えても変わらないため、IP ではなく発行元 ID で絞る方式を下の比較に含めます |

[APIM の IP 仕様](https://learn.microsoft.com/ja-jp/azure/api-management/api-management-howto-ip-addresses) は、Basic v2 の送信元を許可する方法としてリージョンの IP 範囲を案内しています。しかし、リージョン全体を許可することは、このラボの「社内 IP 限定」と異なります。加えて、[Foundry のネットワーク規則](https://learn.microsoft.com/ja-jp/azure/ai-services/cognitive-services-virtual-networks) は IP 規則を最大 100 件までしか受け付けず、サービスタグ JSON（2026-09-14 版）の `AzureCloud.japaneast` は IPv4 だけで 274 プレフィックスあるため、登録自体ができません。通常手順に追加しません。一度観測した IP を固定値とみなす方法も採用しません。

[App Service の IP 仕様](https://learn.microsoft.com/ja-jp/azure/app-service/overview-inbound-outbound-ips) では、アプリからの送信に複数の IP を使用します。入口のアクセス制限を設定しても、アプリの送信元が社内 IP に変わることはありません。転送ヘッダーに社内 IP を入れても、受信側のネットワーク許可の代わりにはなりません。

### 送信元を固定する案の比較（案 C を採用・2026-09-16）

サービス間通信の送信元を「社内 IP 限定」の許可リストに載せられる形にする案を比較します。どの案も公式仕様と単価から机上で整理したもので、実測していません。2026-09-16 に案 C を採用しました（設計判断 D14）。案 B・E の SKU 変更と案 A・D の許可範囲の変更は行いません。

| 案 | 内容 | 前提との関係 | SKU と追加費用（32h/月・Japan East） | 公式資料の裏付け |
|---|---|---|---|---|
| A | Basic v2 のまま、Foundry に Japan East のリージョン範囲を許可 | リージョン全体の許可は未承認。IP 規則上限 100 件に対し IPv4 274 プレフィックス | 変更なし | 成立しない |
| B | Standard v2 に変更し VNet 統合。App Service も同じ VNet に統合し、共通の NAT ゲートウェイの静的 IP を Foundry と APIM の許可リストに追加 | 閉域機能は使わないが、VNet・NAT ゲートウェイ・パブリック IP を新設 | Basic v2 → Standard v2（+$24.11）、NAT +$1.44、パブリック IP +$0.16。常時稼働なら Standard v2 $700/月 | App Service → NAT は [Learn に明記](https://learn.microsoft.com/ja-jp/azure/app-service/overview-nat-gateway-integration)。APIM v2 の統合サブネットで NAT が効くかは Learn に記述なし |
| C | 利用者本人の経路は App Service → Foundry 直接。App Service を VNet 統合し、統合サブネットのサービス エンドポイントを Foundry の VNet 規則に登録。APIM Basic v2 はツール経路と quota 試験に限定 | VNet を新設するが閉域機能は使わない。本人経路が APIM を通らない | 変更なし。VNet 統合は追加料金なし。NAT を使う場合のみ +$1.60 | [App Service のサービス エンドポイント到達](https://learn.microsoft.com/ja-jp/azure/app-service/overview-vnet-integration) と [Foundry の VNet 規則](https://learn.microsoft.com/ja-jp/azure/ai-services/cognitive-services-virtual-networks) の両方が Learn に明記。プロジェクト エンドポイントへの適用は要確認 |
| D | Basic v2 のまま、Foundry の IP 制限を外し Entra ID 認証だけにする | 「社内 IP 限定」に反する。7.5 の代替扱いのまま | 変更なし | 比較のためだけに記載 |
| E | Premium v2 の VNet インジェクションで受信・送信を分離 | 本番寄りの構成 | Basic v2 → Premium v2（+$116.16） | Learn に明記。学習用には過剰 |

単価は Azure Retail Prices API（2026-09-16 取得、USD、税別）の Basic v2 $0.20548/h、Standard v2 $0.9589/h、Premium v2 $3.83562/h、NAT ゲートウェイ $0.045/h と $0.045/GB、パブリック IP Standard $0.005/h です。見積り Excel v3 には未反映で、採用案が決まってから明細を追加します。

Agent Service からツール用 APIM への経路は、上のどの案でも送信元 IP を固定できません。[MCP サーバー認証](https://learn.microsoft.com/ja-jp/azure/foundry/agents/how-to/mcp-authentication) では、プロジェクト接続に Microsoft Entra 認証（プロジェクト マネージド ID またはエージェント ID）を設定し、Agent Service がそのトークンを MCP サーバーへ渡します。ツール用 APIM 側は `ip-filter` ではなく `validate-azure-ad-token` で発行元 ID を検証する形が候補です。この場合、APIM の IP 規則は社内ブラウザからの直接試験用に限り、許可リストは APIM から先の呼び出し先（バックエンド）で管理します。

#### 採用した構成（案 C）

| 要素 | 内容 |
|---|---|
| 仮想ネットワーク | このラボ専用に 1 つ新設。閉域機能（Private Endpoint・VNet インジェクション・VPN・Firewall・Bastion）は使わない |
| 統合サブネット | App Service 専用。portal 作成時は /27 以上。委任 `Microsoft.Web/serverFarms`。サービス エンドポイント `Microsoft.CognitiveServices` を有効化 |
| App Service | Linux B1 のまま。[ネットワーク] の [送信トラフィックの構成] で上記サブネットに VNet 統合。[送信インターネット トラフィック] は既定のまま（サービス エンドポイント宛は既定で VNet 経由） |
| Foundry | [ネットワーク] の既定拒否＋社内 IP 規則に加え、[既存の仮想ネットワークを追加] で統合サブネットを VNet 規則に登録 |
| 本人の経路 | 社内ブラウザ → App Service（社内 IP のアクセス制限）→ Foundry（VNet 規則）。APIM を通さない |
| ツールの経路 | Agent Service → APIM Basic v2 → 許可した呼び出し先。APIM は `validate-azure-ad-token` で発行元 ID を検証し、IP 規則は社内ブラウザからの直接試験用に限る |
| 追加費用 | 仮想ネットワーク・サブネット・VNet 統合・サービス エンドポイントは追加料金なし。NAT ゲートウェイは使わない |

> **Note** 要確認: Foundry の VNet 規則がプロジェクト エンドポイントの API 呼び出しにも適用されるかを Learn で確認できていません。初回実行で確認し、通らなければ停止条件へ戻します。

### 開始・再開チェックリスト

第4章の G1〜G3（接続・通信・認証の停止条件）とは別に、この章の開始条件を確認します。

- [ ] 第4章の停止条件を解決し、エージェントの初回応答を確認している。
- [ ] 案 C の仮想ネットワーク・統合サブネット・サービス エンドポイント・Foundry の VNet 規則が、承認された IP 許可方針と両立する根拠を記録している。
- [ ] Foundry が利用者本人を認可するトークン経路を確定している。
- [ ] 呼び出しアプリのソース、固定した配布版、ランタイム、設定項目、GUI デプロイ手順がリポジトリに揃っている。
- [ ] Entra のアプリ登録と必要な同意を実施できる担当者を確認している。RG の Owner 権限だけでテナント内の操作ができるとは判断しない。
- [ ] APIM と App Service の費用、リージョン、削除予定を確認している。

> **Note** 要確認: サービス間の IP 方針は案 C で確定しましたが、7.3 の操作はまだ案 C に合わせて書き直していません。委任認証を保つアプリも未実装です。チェックが揃うまで、以下の作成操作を開始しません。構成を変える場合は、その判断を反映した手順を先に確定します。IP 制限を外すことや SKU を変えることを復旧操作として実施しません。案 B・E は SKU の変更、案 A・D は許可範囲の変更を伴うため、承認前に実施しません。

## 7.3. 操作（開始条件の解決後）

> **Note** 要確認: 以下は案 C の採用前に書いた操作案です。仮想ネットワークと統合サブネットの作成、App Service の VNet 統合、Foundry の VNet 規則、ツール経路に限定した APIM の設定へ書き直す予定です。書き直しまでは作成操作を開始しません。

### APIM Basic v2 を作成する

以下は [portal の作成手順](https://learn.microsoft.com/ja-jp/azure/api-management/get-started-create-service-instance) に基づく操作案です。

1. Azure portal の [リソースの作成] を選択します。
2. [API Management] を検索します。
3. [作成] を選択します。
4. [基本] に下表の値を入力します。

| 項目 | 値 |
|---|---|
| サブスクリプション | 第1章で確認した部門検証用 |
| リソース グループ | 第1章で作成した実施者専用 RG |
| リージョン | Japan East。Basic v2 の提供状況を作成前に確認 |
| リソース名 | `<実施者略号を含む一意の名前>` |
| 組織名 | `<検証用の承認済み表示名>` |
| 管理者の電子メール | `<承認済み通知先>`。実値は portal のみに入力 |
| 価格レベル | Basic v2。Basic とは区別 |
| 単位 | 1 |

5. [監視 + セキュリティで保護] で追加サービスを新規作成しない設定を選択します。
6. [ネットワーク] でこのラボの対象外のネットワーク機能を選択していないことを確認します。
7. [マネージド ID] の選択を確認します。
8. [タグ] に第1章と同じ管理用タグを入力します。
9. [レビュー + 作成] を選択します。
10. 表示された SKU と費用を確認します。
11. [作成] を選択します。
12. 作成後の [概要] でサービスがオンラインになったことを確認します。

> **補足** Managed Identity（MI）はサービス自身の ID です。MI を有効にしても、利用者本人の認証にはなりません。この段階では APIM の MI に利用者の代理となる Foundry ロールを付与しません。

### API を登録する前に IP 規則を設定する

1. APIM の [API] を開きます。
2. [すべての API] を選択します。
3. [デザイン] の [受信処理] でポリシーのコード エディターを開きます。
4. `inbound` 内に承認済み送信元の `ip-filter` を設定します。
5. [保存] を選択します。

以下は XML の書式例です。文書用 IP をそのまま保存しません。社内ブラウザ用の許可規則だけでは、前節のサービス間通信は通りません。

```xml
<ip-filter action="allow">
  <address-range from="192.0.2.1" to="192.0.2.1" />
</ip-filter>
```
実行結果の確認ポイント: 開始・終了 IP を承認値と照合し、未一致を拒否する `allow` 規則として保存されていることを確認します。

6. API と操作を追加した後、それぞれのポリシーで親の規則を継承する `<base />` を確認します。
7. [有効なポリシーの計算] で適用結果を確認します。

> **補足** `ip-filter` は v2 ゲートウェイに対応しています。CIDR は `<address>` に直接入れず、開始・終了アドレスに変換します。これは API 呼び出しの制限であり、管理プレーン全体の接続制限ではありません。

### 呼び出しアプリの配布を確定する

アプリは事前同梱し、読者がその場で実装しなくても配置できる形にします。次の表が揃うまでは、App Service の作成・アプリ登録・デプロイの操作を確定済みとして掲載しません。

| 同梱するもの | 執筆・実装時の確認内容 |
|---|---|
| アプリのソースと配布版 | どの版を配置したか追跡でき、依存関係とランタイムが固定されている |
| ブラウザ画面 | 合成プロンプトを送信でき、応答と相関 ID を確認できる |
| 認証処理 | サインイン、下流トークン取得、同意不足・期限切れの処理が揃っている |
| 呼び出し先 | APIM の固定 URL と許可された操作だけを使い、利用者入力から任意 URL を指定できない |
| 設定一覧 | テナント、アプリ登録、対象プロジェクト・エージェント等の項目と設定場所を示す。秘密値を同梱しない |
| GUI 配布手順 | IP 制限された SCM に到達できる配布経路を確認し、配布のために制限を解除しない |
| 確認方法 | Consumer／User／無権限の本人で成否を比較でき、トークンを表示・保存しない |

> **Note** 要確認: ランタイム・配布方式・下流トークン取得の実装は未確定です。空の App Service を作っただけで「用意済みアプリのデプロイ」が完了したとは扱いません。

### App Service の入口を制限する

アプリ配布手順の確定後、Linux B1 の App Service を作成する工程に、次の設定を含めます。業務データや認証情報を配置する前に制限を確認します。

1. 対象アプリの [設定] から [ネットワーク] を開きます。
2. [受信トラフィックの構成] の [パブリック ネットワーク アクセス] を選択します。
3. [アクセス制限] の [追加] を選択します。
4. 下表の許可規則を入力します。

| 項目 | 値 |
|---|---|
| 名前 | `corporate-01` |
| アクション | 許可 |
| 優先度 | `100`。複数規則では重複を避ける |
| 種類 | IPv4 |
| IP アドレス ブロック | `<社内の承認済みCIDR>` |
| 一致しない規則のアクション | 拒否 |

5. [ルールの追加] を選択します。
6. [保存] を選択します。
7. SCM サイトのアクセス制限で [メイン サイトルールを使用する] を選択します。
8. [保存] を選択します。

> **画面の見え方** SCM は高度なツールや配布で使うサイトです。公式資料ではメインサイトと SCM の規則を別に管理できます。このラボでは同じ規則を使います。Cloud Shell や外部のビルド実行環境が社内 IP から接続するとは限りません。

HTTPS のみ、TLS 1.2 以上、FTP 無効も配布前の確認項目とします。これらの値と IP 規則の骨組みは任意の IaC にありますが、アプリ配布の代わりにはなりません。

### サインインと下流の認可を設定する

1. 対象アプリの [設定] から [認証] を開きます。
2. [ID プロバイダーの追加] を選択します。
3. ID プロバイダーに [Microsoft] を選択します。
4. 現在の従業員テナントを選択します。
5. アプリ実装と対応する専用のアプリ登録を選択します。
6. 下表と照合します。
7. [追加] を選択します。

| 項目 | 値 |
|---|---|
| アカウントの種類 | 現在のテナントのシングルテナント |
| アクセス | 認証を要求 |
| 未認証の要求 | ブラウザの入口では Microsoft へのサインインに誘導。API の応答方法はアプリ実装で確定 |
| トークンの宛先 | 入口用と Foundry 用を分け、実装で必要な audience／scope と一致させる |
| アプリ資格情報 | portal の保護された設定で管理し、ソースや証跡に値を保存しない |

Easy Auth のログイン成功だけでは、Foundry 用アクセストークンを取得したことになりません。OBO（利用者の代わりに下流 API 用トークンを取得する処理）は、必要なトークンの宛先が変わる場合の方式です。すべての経路で OBO が必須とは決めつけません。

| 経路の設計 | 実装前に確定すること |
|---|---|
| アプリが Foundry 用の本人トークンを取得し APIM が転送 | APIM が同じ宛先・発行テナントを検証し、Authorization を MI のトークンで上書きしない |
| 中間 API 用トークンから OBO で下流用を取得 | 入力トークンの宛先が中間 API と一致し、委任権限と必要な同意が設定されている |
| MI で下流を呼ぶ別のサービス処理 | サービス主体の試験として区別し、C02（利用者別権限）の成功証跡には使わない |

> **Note** 要確認: 採用する Foundry API の audience／scope、委任権限、同意、トークン取得方法は未確定です。ID トークンを API 用アクセストークンの代わりに転送しません。Easy Auth の公式資料にある API Playground の Preview 操作は、本手順の対象外です。

APIM の `validate-azure-ad-token` は v2 でも使用できます。対象テナント、audience、必要な claim を確定した後に設定します。検証するだけでは下流用トークンは生成されません。認証ポリシーを保存し、未認証が拒否されることを確認してから、対象 API のサブスクリプションキー必須設定を解除します。入力値が未確定のポリシーを完成例として掲載しません。

### ツールとトークン上限の適用対象を決める

| 対象 | この章での扱い |
|---|---|
| エージェント呼び出し用 API | 利用者本人の認可と経由ログを確認する対象 |
| ツール用 API | 許可したバックエンド・操作に固定。GA の接続方式と Agent Service の到達を確認するまでツールを追加しない |
| モデル推論 API | `llm-token-limit` の対応スキーマと実際の `usage` を確認する対象 |

`llm-token-limit` は Basic v2 に対応し、OpenAI の Chat Completions／Responses 等のモデル API スキーマを対象にします。レート超過は 429、期間内 quota 超過は 403 です。ゲートウェイを通らない内部モデル呼び出しまで計測できるとは判断しません。

> **Note** 要確認: このラボのエージェント呼び出しで、どの応答の `usage` を計測できるかは未検証です。C09（quota・ガードレール）の quota 部分は、対応する経路、期間、上限、集計キーを確定するまで Pending とします。サブスクリプションキーを使わない API で `context.Subscription.Id` を集計キーにしません。

公開ツールを追加しないこと、許可先を固定すること、ツールを編集できる人を限定することを確認します。この運用だけで、Microsoft 管理ネットワーク全体の送信先を技術的に制限したとは扱いません。AI Gateway 統合の Preview 部分は対象外です。content safety と LLM 本文ログの追加手順も、この章では確定していません。

### APIM の診断を既存 Log Analytics に接続する

1. APIM の [監視] から [診断設定] を開きます。
2. [診断設定を追加する] を選択します。
3. 下表の値を入力します。

| 項目 | 値 |
|---|---|
| 診断設定名 | `gateway-to-law` |
| カテゴリ | API Management ゲートウェイのログ。表示名と実カテゴリを照合 |
| 宛先 | 第1章で作成した既存 Log Analytics ワークスペース |
| 宛先テーブル | リソース固有。`ApiManagementGatewayLogs` を使用 |

4. [保存] を選択します。
5. [API] の [すべての API] を選択します。
6. [設定] の [診断ログ] で [Azure Monitor] を開きます。
7. 要求・応答本文と認証ヘッダーを収集対象に追加していないことを確認します。
8. 個別 API の設定に意図しない上書きがないことを確認します。

通常のゲートウェイ診断を使い、本文ログで第6章の保留を代替しません。保持は既存ワークスペースと対象テーブルの設定を照合して 30 日に揃えます。ログ閲覧者も第6章で設定した範囲と照合します。

アプリ配布後、社内ブラウザから合成入力を1回送り、APIM の [監視] → [ログ] で次を実行します。対象は今回の APIM リソースに絞ります。

```kusto
ApiManagementGatewayLogs
| where TimeGenerated > ago(30m)
| project TimeGenerated, CorrelationId, ApiId, OperationId, ResponseCode, BackendResponseCode
| order by TimeGenerated desc
| take 20
```
実行結果の確認ポイント: 試験時刻・対象 API・相関 ID・応答コードを照合し、APIM の受信とバックエンドの応答を区別します。

> **補足** ログの到着には遅延があります。0件やテーブル未作成を「拒否に成功」としません。このクエリだけで Foundry が利用者本人を認可したことは証明できないため、本人ごとの権限比較も必要です。

## 7.4. 完了条件

- 社内ブラウザで用意済みアプリを開き、対象テナントでサインインできる。
- 権限を持つ利用者本人として、同じエージェントから応答を取得できる。
- APIM 経由をログで確認し、バックエンドへ伝える主体を確認できる。
- サービス間通信が承認された IP 方針と両立している。
- 本文とトークンを保存せず、試験の時刻・相関 ID・成否を記録できる。
- 第8章で試せる項目と、本文監査・quota・ツール等の Pending 部分が明確である。

現在は未達です。リソースの作成、Easy Auth の成功、APIM の MI による成功のいずれか一つで、この章を完了にしません。

## 7.5. うまくいかない場合

まず拒否した層を切り分けます。同じ 403 でも原因が異なるため、状態コードだけで試験項目を Pass にしません。

| 症状 | 照合するもの | 次の対応 |
|---|---|---|
| アプリを開く前に 403 | App Service のアクセス制限と接続元 | 社内の承認済み経路から再試行。規則は広げない |
| サインインや同意が失敗 | 対象テナント、アプリ登録、既存の条件付きアクセス | 担当者へ設定差分を確認。既存ポリシーは変更しない |
| サインインできるが APIM に届かない | アプリの送信元と APIM の許可規則 | 社内 IP 限定との不整合なら停止条件へ戻す |
| APIM で 401 | 検証対象のテナント・audience・有効期限・claim | トークン本文を記録せず、アプリ設定と照合 |
| APIM を通るが Foundry が拒否 | 下流のネットワーク制限、本人トークン、RBAC | ネットワークと認可を分けて記録。MI に置き換えて成功扱いにしない |
| 403／429 | IP 規則、認可、quota／レートのどの層か | ポリシーとログを照合。quota 未設定なら quota 超過としない |
| デプロイだけ失敗 | SCM の制限と配布元の送信 IP | 承認済み配布経路を確認。Cloud Shell や外部 CI のために公開しない |
| ログが見つからない | 診断の宛先・カテゴリ・時間範囲・閲覧権限 | 収集未設定と未到着を分け、Pending として記録 |

代替は、同じ制限内の経路での再試行か、根拠を付けた設計の見直しとします。非公開の証跡には変更前後の設定、時刻、拒否層、結果を記録し、秘密値は含めません。切り分けで変更した設定は承認済みの値へ戻して再確認します。途中で終了する場合の削除は第10章で行います。

## 7.6. 次の操作

7.4 の完了条件を満たした場合だけ、同じ環境で第8章の統制試験に進みます。現在は、サービス間の IP 方針とアプリの認証・配布を確定する段階です。C02／C03 のアプリ経路、C08 のツール経路、C09 の quota は、それぞれの未解決点を引き継ぎます。

## 7.7. 費用

| Excel v3 明細 No | 項目 | 通常月 USD |
|---|---|---:|
| 11 | API Management / Basic v2 | 6.575360 |
| 13 | App Service / Linux B1 | 0.608000 |

2026-09-15 の見積り v3 の既定値です。Japan East、原則 32h/月の検証、CSPM は既定 OFF です。案 C（仮想ネットワーク・VNet 統合・サービス エンドポイント）は追加料金なしで、Excel には金額 0 の明細を追加する予定です。No.8 と No.12 は常時／検証日の切替で、二重計上しません。No.6 は 第1章/第6章の共通費です。見積り保証ではありません。

## 7.8. 本番との差・IaC で再現する (任意)

本番の接続・SKU・入口防御の差は [付録 B](92-appendix-production-diff.md) を参照します。

[07_gateway_app.bicep](../infra/modules/07_gateway_app.bicep) は再現用の骨組みです。一式の再展開を主線には使いません。

### 出典

- 出典: [APIM v2 レベル](https://learn.microsoft.com/ja-jp/azure/api-management/v2-service-tiers-overview)（取得日 2026-09-16）
- 出典: [APIM の IP アドレス](https://learn.microsoft.com/ja-jp/azure/api-management/api-management-howto-ip-addresses)（取得日 2026-09-16）
- 出典: [APIM の portal 作成](https://learn.microsoft.com/ja-jp/azure/api-management/get-started-create-service-instance)（取得日 2026-09-16）
- 出典: [APIM のポリシー設定](https://learn.microsoft.com/ja-jp/azure/api-management/set-edit-policies)（取得日 2026-09-16）
- 出典: [ip-filter](https://learn.microsoft.com/ja-jp/azure/api-management/ip-filter-policy)（取得日 2026-09-16）
- 出典: [App Service の送信 IP](https://learn.microsoft.com/ja-jp/azure/app-service/overview-inbound-outbound-ips)（取得日 2026-09-16）
- 出典: [App Service のアクセス制限](https://learn.microsoft.com/ja-jp/azure/app-service/app-service-ip-restrictions)（取得日 2026-09-16）
- 出典: [App Service の Entra 認証](https://learn.microsoft.com/ja-jp/azure/app-service/configure-authentication-provider-aad)（取得日 2026-09-16）
- 出典: [Easy Auth の OAuth トークン](https://learn.microsoft.com/ja-jp/azure/app-service/configure-authentication-oauth-tokens)（取得日 2026-09-16）
- 出典: [OBO フロー](https://learn.microsoft.com/ja-jp/entra/identity-platform/v2-oauth2-on-behalf-of-flow)（取得日 2026-09-16）
- 出典: [Entra トークン検証ポリシー](https://learn.microsoft.com/ja-jp/azure/api-management/validate-azure-ad-token-policy)（取得日 2026-09-16）
- 出典: [APIM の MI 認証](https://learn.microsoft.com/ja-jp/azure/api-management/authentication-managed-identity-policy)（取得日 2026-09-16）
- 出典: [トークン上限](https://learn.microsoft.com/ja-jp/azure/api-management/llm-token-limit-policy)（取得日 2026-09-16）
- 出典: [APIM の監視と診断](https://learn.microsoft.com/ja-jp/azure/api-management/api-management-howto-use-azure-monitor)（取得日 2026-09-16）
- 出典: [ApiManagementGatewayLogs の列](https://learn.microsoft.com/ja-jp/azure/azure-monitor/reference/tables/apimanagementgatewaylogs)（取得日 2026-09-16）
- 出典: [APIM の VNet 統合（Standard v2 / Premium v2）](https://learn.microsoft.com/ja-jp/azure/api-management/integrate-vnet-outbound)（取得日 2026-09-16）
- 出典: [APIM と Azure 仮想ネットワーク](https://learn.microsoft.com/ja-jp/azure/api-management/virtual-network-concepts)（取得日 2026-09-16）
- 出典: [App Service の VNet 統合](https://learn.microsoft.com/ja-jp/azure/app-service/overview-vnet-integration)（取得日 2026-09-16）
- 出典: [App Service の NAT ゲートウェイ統合](https://learn.microsoft.com/ja-jp/azure/app-service/overview-nat-gateway-integration)（取得日 2026-09-16）
- 出典: [Foundry Tools の仮想ネットワークを構成する](https://learn.microsoft.com/ja-jp/azure/ai-services/cognitive-services-virtual-networks)（取得日 2026-09-16）
- 出典: [MCP サーバー認証を設定する](https://learn.microsoft.com/ja-jp/azure/foundry/agents/how-to/mcp-authentication)（取得日 2026-09-16）
- 出典: [Azure IP Ranges and Service Tags – Public Cloud](https://www.microsoft.com/download/details.aspx?id=56519)（2026-09-14 版・取得日 2026-09-16）
- 出典: [Azure Retail Prices API](https://learn.microsoft.com/ja-jp/rest/api/cost-management/retail-prices/azure-retail-prices)（取得日 2026-09-16）

---

前へ: [監視と監査を設定する](06-monitoring.md) / 次へ: [権限・認証・ネットワークの統制を試す](08-governance-tests.md) / [トップに戻る](../README.md)
