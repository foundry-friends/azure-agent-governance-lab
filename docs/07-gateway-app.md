# 7. ゲートウェイと呼び出しアプリを用意する

進め方: README の第0〜10章を順番に実施します。第6章 6.6 の進行条件を満たしてから進めます。本文監査など明示した Pending は記録を引き継ぎます。

> **Note** 状態: ドラフト（Learn 2026-09 時点の記述に基づく・未実行）。更新日 2026-09-20。サービス間通信は 7.2 の案 C（2026-09-16 決定）で進めます。案 C の GUI 操作ドラフトを作成済みです。社内 PC からの CLI 配布は暫定採用済みです。アプリは実装済み（Easy Auth 転送・REST・2026-09-20 決定）。本人トークンの取得・配布・到達は初回実行で確認します。

> **補足** この章では環境を削除しません。通常の削除は最後の第10章です。中断して片付ける場合だけ、第10章へ進みます。

## 7.1. 目的

同じエージェントを利用者本人の権限で呼び出すブラウザ用アプリと、ツール経路用の APIM を用意します。本人の経路は App Service から Foundry を直接呼び、APIM は Agent Service からのツール呼び出しを通す入口にします。追加シナリオとして、アプリ専用の Cosmos DB コンテナーに会話メモを JSON で保存します（A14・D16）。利用者本人の権限で試せる入口ができてから、次の章で統制試験をします。

### なぜこの作業が必要か

開発用の画面で応答を確認するだけでは、呼び出し専用ユーザーが実際に利用する経路の統制を試せません。利用者がブラウザからエージェントを呼び出し、その本人の権限が反映される経路を用意する必要があります。

この章では、呼び出しアプリを利用者の入口として用意し、APIM を通す対象と許可する呼び出し先を整理します。アプリへのサインインと、その利用者が Foundry で操作できるかを区別して確認するための準備です。本人トークンの経路が確定してから、第8章でユーザーや接続元を変える試験に使います。

### 作業前に知っておくこと：3つの経路と使う ID

この章では、利用者の入口、会話メモの保存、ツールの入口を作ります。**アプリにサインインすること・Foundry を呼べること・Cosmos DB に保存できることは、それぞれ別の確認**です。

| 経路 | 役割と使う ID | この章で用意するもの |
|---|---|---|
| ブラウザ → App Service → Foundry | Easy Auth（App Service の組み込み認証）でサインインし、利用者本人のトークンで Foundry を呼ぶ | アプリ、サインイン設定、送信経路。本人のロールは第5章を使用 |
| App Service → Cosmos DB | [会話メモを保存] のときだけ、App Service の MI でアプリ専用コンテナーへ保存 | アプリ専用 DB／コンテナー、MI のデータ権限。Foundry の本人権限とは別 |
| Agent Service → APIM → ツール | APIM がツールへの要求を受け付け、許可するサービス主体・呼び出し先・回数を制限 | ツール用の入口。ツール仕様が未確定のため工程 8〜10 は保留条件あり |

APIM（API Management）は API の認証や呼び出し制御をまとめるサービスです。本ラボでは本人の Foundry 呼び出しは APIM を通りません。また、**VNet 統合はアプリから外へ出る通信の設定、アクセス制限はアプリへ入る通信の設定**です。片方の設定だけで両方向の制限を確認したとは扱いません。

## 7.2. 前提と作成前の停止条件

第4章の G1〜G3 の根拠と、選択した Standard／Basic の C01・C08 初回結果を記録し、同じエージェントの応答、第5章の権限設定、第6章の通常診断の設定を確認済みであることを前提とします。第6章で保留した本文監査は保留のまま引き継ぎます。

### 採用前の課題：通信の送信元を分ける

ブラウザでアプリを開いた人の IP が、後段のサービス間通信でも使われるわけではありません。次の表は採用前の APIM 中継案の課題を示します。現行の経路は下の「採用した構成（案 C）」です。実測した結果ではありません。

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
| D | Basic v2 のまま、Foundry の IP 制限を外し Entra ID 認証だけにする | Foundry のネットワーク制限を外すため不採用。復旧手順としても実施しない | 変更なし | 比較のためだけに記載 |
| E | Premium v2 の VNet インジェクションで受信・送信を分離 | 本番寄りの構成 | Basic v2 → Premium v2（+$116.16） | Learn に明記。学習用には過剰 |

単価は Azure Retail Prices API（2026-09-16 取得、USD、税別）の Basic v2 $0.20548/h、Standard v2 $0.9589/h、Premium v2 $3.83562/h、NAT ゲートウェイ $0.045/h と $0.045/GB、パブリック IP Standard $0.005/h です。案 C は採用済みです。見積り Excel v3 の資産明細への VNet／サブネット追記は未実施です。

Agent Service からツール用 APIM への経路は、上のどの案でも送信元 IP を固定できません。[MCP サーバー認証](https://learn.microsoft.com/ja-jp/azure/foundry/agents/how-to/mcp-authentication) では、プロジェクト接続に Microsoft Entra 認証（プロジェクト マネージド ID またはエージェント ID）を設定し、Agent Service がそのトークンを MCP サーバーへ渡します。ツール用 APIM 側は `ip-filter` ではなく `validate-azure-ad-token` で発行元 ID を検証する形が候補です。この場合、APIM の IP 規則は社内ブラウザからの直接試験用に限り、許可リストは APIM から先の呼び出し先（バックエンド）で管理します。

#### 採用した構成（案 C）

| 要素 | 内容 |
|---|---|
| 仮想ネットワーク | このラボ専用に 1 つ新設。閉域機能（Private Endpoint・VNet インジェクション・VPN・Firewall・Bastion）は使わない |
| 統合サブネット | App Service 専用。portal 作成時は /27 以上。委任 `Microsoft.Web/serverFarms`。サービス エンドポイント `Microsoft.CognitiveServices` と `Microsoft.AzureCosmosDB` を有効化 |
| App Service | Linux B1 のまま。[ネットワーク] の [送信トラフィックの構成] で上記サブネットに VNet 統合。[送信インターネット トラフィック] は既定のまま（サービス エンドポイント宛は既定で VNet 経由） |
| Foundry | [ネットワーク] の既定拒否＋社内 IP 規則に加え、[既存の仮想ネットワークを追加] で統合サブネットを VNet 規則に登録 |
| アプリの保存先 | Cosmos DB のアプリ専用 `<app-db>/<app-container>`。統合サブネットを Cosmos の VNet 規則で許可し、App Service MI のデータロールで認証 |
| 本人の経路 | 社内ブラウザ → App Service（社内 IP のアクセス制限）→ Foundry（VNet 規則）。APIM を通さない |
| ツールの経路 | Agent Service → APIM Basic v2 → 許可した呼び出し先。APIM は `validate-azure-ad-token` で発行元 ID を検証し、IP 規則は社内ブラウザからの直接試験用に限る |
| 追加費用 | 仮想ネットワーク・サブネット・VNet 統合・サービス エンドポイントは追加料金なし。NAT ゲートウェイは使わない |

> **Note** 要確認: Foundry の VNet 規則がプロジェクト エンドポイントの API 呼び出しにも適用されるかを Learn で確認できていません。初回実行で確認し、通らなければ停止条件へ戻します。

> **補足** D14 の APIM はツール API を保護します。ネットワーク上は公開する一方、対象テナント・audience・許可されたサービス主体を検証します。社内ブラウザ用の `ip-filter` を全 API に設定すると Agent Service も拒否されるため、直接試験用の別 API／操作に限定します。

> **補足** ツール API の呼び出し回数等の quota と、LLM のトークン quota は別です。本人経路と内部モデル呼び出しは APIM を通らないため、そのトークン量を C09 のツール試験で検証したとは扱いません。具体的な quota・集計単位・許可主体はアプリ／ツール仕様の確定時に決めます。

### 作業に使う画面と手元の情報

| 操作場所 | 用途・用意するもの |
|---|---|
| 社内 PC の Azure portal | VNet・App Service・Cosmos・APIM の設定。テナント、サブスクリプション、専用 RG、社内 CIDR、既存リソースの ARM ID |
| Microsoft Entra のアプリ登録画面 | 工程 6 のアプリ登録と API の委任許可・同意。担当者と権限を事前確認 |
| Cloud Shell（Bash） | 通常の照会、Cosmos データロール、GUI にない認証設定。第5章の対象確認を行ってから使用 |
| 社内 PC の Bash | 工程 7 の ZIP 作成・ハッシュ照合・配布。Cloud Shell とはファイルもサインイン状態も別 |
| 社内ブラウザ | 配布後のサインイン・応答・会話メモ保存。構築担当と利用試験ユーザーのセッションを分離 |

新規作成する VNet・統合サブネット・App Service・アプリ登録・アプリ専用 DB／コンテナーの名前と、承認されたアドレス範囲を非公開メモに揃えます。既存の Foundry project のエンドポイント・エージェント名、Cosmos の HTTPS エンドポイント、LAW の ID は前章の記録から取得します。URL や ID を名前から推測して入力しません。

### 開始・再開チェックリスト

第4章の G1〜G3（根拠確認済み）と C08 の初回到達確認とは別に、この章の開始条件を確認します。

- [ ] 第4章のエージェントの初回応答と C08 の到達を確認している（Basic 分岐時は対象外と失敗の記録も引き継ぐ）。
- [ ] 案 C の仮想ネットワーク・統合サブネット・サービス エンドポイント・Foundry の VNet 規則が、承認された IP 許可方針と両立する根拠を記録している。
- [ ] Foundry が利用者本人を認可する Easy Auth 転送の設定手順を確認している（工程 6）。
- [ ] 呼び出しアプリのソース、固定依存、ランタイム、設定項目、社内 PC の CLI 配布手順を確認し、工程 7 で ZIP を生成できる。
- [ ] Entra のアプリ登録と必要な同意を実施できる担当者を確認している。RG の Owner 権限だけでテナント内の操作ができるとは判断しない。
- [ ] APIM と App Service の費用、リージョン、削除予定を確認している。

> **Note** 要確認: サービス間の IP 方針は案 C で確定しましたが、7.3 は案 C の操作ドラフトです。アプリと Easy Auth 転送方式は実装・確定済みで、配布は社内 PC の CLI を暫定採用しています。本人トークンの取得・配布・到達・保存は工程 6〜7 の初回実行で確認します。チェックが揃うまで、以下の作成操作を開始しません。構成を変える場合は、その判断を反映した手順を先に確定します。IP 制限を外すことや SKU を変えることを復旧操作として実施しません。案 B・E は SKU の変更、案 A・D は許可範囲の変更を伴うため、承認前に実施しません。

## 7.3. 操作（開始条件の解決後）

以下は案 C の操作ドラフトです。7.2 のチェックが揃ってから実施します。工程 6〜7 の初回照合で成立しなければ、その箇所で停止します。工程 7 の配布限定例外を除き、確認コマンドは Cloud Shell の Bash で実行し、山括弧の値を今回のリソースに置き換えます。実値と出力は非公開の証跡だけに保存します。

### 1. 仮想ネットワークと統合サブネットを作る

1. [サブスクリプション] で検証用サブスクリプションを開きます。
2. [リソース プロバイダー] で `Microsoft.Network`・`Microsoft.Web`・`Microsoft.ApiManagement` の登録状態を確認します。
3. 未登録の場合は登録権限を持つ担当者が [登録] を選択します。
4. Azure portal の検索で [仮想ネットワーク] を開きます。
5. [作成] を選択します。
6. [基本] に下表の値を入力します。

| 項目 | 値 |
|---|---|
| サブスクリプション | 第1章の検証用 |
| リソース グループ | 第1章の実施者専用 RG |
| 名前 | `<今回のVNet名>` |
| リージョン | Japan East。App Service と同一 |
| IPv4 アドレス空間 | `<承認された専用CIDR>`。既存ネットワークとの重複を避ける |
| サブネット名 | `<App Service専用の統合サブネット名>` |
| サブネットの大きさ | `/27` 以上。アドレス空間に収まる未使用範囲 |
| サブネットの委任 | `Microsoft.Web/serverFarms` |
| サービス エンドポイント | `Microsoft.CognitiveServices` と `Microsoft.AzureCosmosDB` |
| タグ | 第1章と同じ管理用タグ |

7. [IP アドレス] で承認されたアドレス空間を設定します。
8. [サブネット] の既定の行を選択し、編集画面で名前・開始アドレス・サイズを上表に合わせます。保存後、アドレス空間内に収まっていることを確認します。
9. [セキュリティ] で Bastion・Firewall 等の対象外の追加サービスを有効にしていないことを確認します。
10. [タグ] を入力します。
11. [確認および作成] で設定を照合します。
12. [作成] を選択します。
13. 作成した VNet の [設定] → [サブネット] を開きます。
14. 統合用サブネットを選択します。
15. [サブネットをサービスに委任] で `Microsoft.Web/serverFarms` を選択します。
16. [サービス エンドポイント] で `Microsoft.CognitiveServices` と `Microsoft.AzureCosmosDB` を選択します。
17. [保存] を選択します。
18. 同じサブネットの編集画面を開き直し、委任・2 つのサービス エンドポイントを照合します。

> **画面の見え方** 作成ウィザードに委任やサービス エンドポイントの選択がない場合は、作成後のサブネット編集で設定します。統合用サブネットに VM や他サービスを配置しません。App Service の統合は送信専用で、社内 PC をこの VNet に接続する操作ではありません。

```bash
az network vnet subnet show --resource-group '<専用RG名>' --vnet-name '<今回のVNet名>' --name '<統合サブネット名>' --query '{id:id,prefix:addressPrefix,delegations:delegations[].serviceName,endpoints:serviceEndpoints[].service}' --output json
```
実行結果の確認ポイント: 専用サブネットの範囲、`Microsoft.Web/serverFarms`、`Microsoft.CognitiveServices` と `Microsoft.AzureCosmosDB` が一致することを確認します。

### 2. App Service を作り、入口を制限する

アプリ仕様のレビューと配布方式の確定後に行います。[同梱アプリ仕様](../assets/app/README.md) に記載された配布版と同じ Python ランタイムを使います。

1. Azure portal の [App Services] を開きます。
2. [作成] → [Web アプリ] を選択します。
3. [基本] に下表の値を入力します。

| 項目 | 値 |
|---|---|
| リソース グループ | 今回の専用 RG |
| 名前 | `<今回のアプリ名>` |
| 公開 | コード |
| ランタイム スタック | Python 3.12（初回の選択可否は工程 6 で照合） |
| オペレーティング システム | Linux |
| 地域 | Japan East |
| App Service プラン | 今回専用に作成。Linux B1 |
| デプロイ | この時点ではソース連携・コード配置を行わない |
| 監視 | 既存の監視資産を利用。追加作成の既定値を確認 |

4. App Service プランの新規作成欄で今回専用のプラン名を入力し、価格プランの選択画面で B1 を選びます。[確認および作成] で Linux・B1・対象 RG を照合します。
5. [作成] を選択します。
6. 対象アプリの [設定] → [ネットワーク] を開きます。
7. [受信トラフィックの構成] の [パブリック ネットワーク アクセス] を開きます。
8. [アクセス制限] の [追加] を選択します。
9. 下表の許可規則を入力します。

| 項目 | 値 |
|---|---|
| 名前 | `corporate-01` |
| アクション | 許可 |
| 優先度 | `100`。追加規則は重複させない |
| 種類 | IPv4 |
| IP アドレス ブロック | `<承認された社内CIDR>` |
| 一致しない規則のアクション | 拒否 |

10. [ルールの追加] を選択します。承認済み社内 CIDR が複数ある場合は、規則名と優先度を変えて 1 件ずつ追加します。
11. 一致しない規則のアクションを [拒否] にし、[保存] を選択します。
12. SCM（高度なツール）サイトのタブを開き、[メイン サイトルールを使用する] を選択します。
13. [保存] を選択します。
14. メインサイトと SCM の画面を開き直し、許可 CIDR・既定拒否・ルール共用を照合します。
15. [設定] → [構成]（Configuration）→ [全般設定]（General settings）で HTTPS のみ・最低 TLS バージョン 1.2 以上・FTP 無効を確認します。異なる場合は今回の値へ変更して保存します。
16. 保存後に設定を開き直し、反映結果を記録します。

> **画面の見え方** メインサイトと SCM（配布・高度なツール用サイト）は別々の入口です。VNet 統合ではこれらの受信制限は設定されません。空のアプリを作成した後、コード・資格情報を配置する前に入口を制限します。作成時から拒否を要求する組織では、この作成後設定の手順を実行せず、作成時設定の方法を先に確定します。

> **Note** 要確認: Python 3.12・起動設定は工程 6 で指定し、選択可否と起動は初回に照合します。HTTPS／TLS／FTP の設定画面の位置も初回に照合します。空の Web アプリの作成をアプリ配布の完了とは扱いません。

```bash
az webapp show --resource-group '<専用RG名>' --name '<今回のアプリ名>' --query '{name:name,location:location,kind:kind,httpsOnly:httpsOnly,publicNetworkAccess:publicNetworkAccess}' --output json
```
実行結果の確認ポイント: 対象・リージョン・Linux・HTTPS の値を照合し、IP 規則はメイン／SCM の画面で別途確認します。

### 3. App Service の送信 VNet 統合を設定する

1. アプリの [設定] → [ネットワーク] を開きます。
2. [送信トラフィックの構成] の [仮想ネットワーク統合] を開きます。
3. [仮想ネットワーク統合の追加] を選択します。
4. [新しい接続] が表示された場合は選択します。
5. 今回のサブスクリプションを選択します。
6. 今回の VNet を選択します。
7. App Service 専用の統合サブネットを選択します。
8. [接続] を選択します。
9. 接続先が今回の VNet／サブネットになったことを確認します。

| 項目 | 値 |
|---|---|
| 統合先 | 工程 1 の専用サブネット |
| 全送信トラフィックの VNet ルーティング | 有効化しない。サービス エンドポイント宛のルーティングを利用 |
| NAT Gateway | 追加しない |
| DNS | このラボでは独自 DNS を追加しない |

> **画面の見え方** 統合時にはアプリが再起動します。既存接続が候補に表示されても、他の実施者のサブネットを選びません。Learn の日本語ページには一部英語のラベルが残るため、[Networking]／[Virtual network integration] と表示される場合があります。

```bash
az webapp show --resource-group '<専用RG名>' --name '<今回のアプリ名>' --query virtualNetworkSubnetId --output tsv
```
実行結果の確認ポイント: 工程 1 で確認したサブネット ID と一致し、空欄でないことを確認します。

### 4. Foundry に統合サブネットの VNet 規則を追加する

1. Azure portal で第4章の Foundry account を開きます。
2. [ネットワーク] を開きます。
3. 選択したネットワークからのアクセスを許可する設定を確認します。
4. 既存の社内 IP 規則を確認します。
5. [既存の仮想ネットワークを追加] を選択します。
6. 今回の VNet と統合サブネットを選択します。
7. サービス エンドポイントが有効であることを確認します。
8. [追加] を選択します。
9. [保存] を選択します。
10. [ネットワーク] を開き直し、追加したサブネットと既存の社内 IP 規則を照合します。

| 項目 | 値 |
|---|---|
| 公開ネットワーク アクセス | 有効。すべてのネットワークの許可にはしない |
| 既定のアクション | 拒否 |
| IP 規則 | 既存の承認済み社内 IP を維持 |
| VNet 規則 | 今回の統合サブネットだけを追加 |
| ローカル認証 | 無効を維持 |
| 信頼サービスの例外 | この操作では追加しない |

> **画面の見え方** VNet 規則はサブネットを識別して許可します。サブネットのプライベート CIDR をインターネット用 IP 規則欄へ入力する操作ではありません。サービス エンドポイントの設定変更中は通信が一時的に中断する可能性があります。

```bash
az cognitiveservices account network-rule list --resource-group '<専用RG名>' --name '<Foundry account名>' --output json
```
実行結果の確認ポイント: 社内 IP 規則を維持したまま、今回のサブネットが VNet 規則に追加されていることを確認します。

> **Note** 要確認: Foundry Tools のアカウントに対する公式操作は確認できましたが、採用するプロジェクト／エージェント API への VNet 規則の適用は未検証です。設定の存在を到達成功とせず、アプリ配布後に同じエージェントへの応答で確認します。失敗時は IP 制限を解除せず停止します。これは Agent Service → BYO データ基盤の G2 とは別の確認です。

### 5. Cosmos DB に統合サブネットの仮想ネットワーク規則を追加する

Agent Service の保存経路とは独立した、呼び出しアプリ → Cosmos DB の経路です。VNet 規則・サービス エンドポイント・Entra 認証の GA 機能を使うため、第4章の Cosmos 接続の Preview 例外には依存しません。Basic へ分岐した場合も、第3章の Cosmos DB をアプリ用に使用します。

1. 第3章の Cosmos DB の [Networking] を開きます。
2. [Selected networks] を選択します。
3. [Virtual networks] の [Add existing Azure virtual network] を選択します。
4. 今回の VNet と App Service の統合サブネットを選択します。
5. `Microsoft.AzureCosmosDB` サービス エンドポイントの有効化を確認します。
6. [Add] を選択します。
7. [Save] を選択します。
8. 社内 IP・`0.0.0.0`・キー無効の設定が維持されていることを確認します。

> **Note** 要確認: [Networking]（ネットワーク）・[Virtual networks]（仮想ネットワーク）・[Add existing Azure virtual network]（既存の仮想ネットワークを追加）等の日本語表示は初回に照合します。

> **補足** サービス エンドポイント経由の要求には public IP がないため、IP 規則だけでは許可できません。統合サブネットを VNet 規則に追加します。プライベート CIDR を IP 規則へ入力しません。反映には最大 15 分を見込みます。

| 項目 | 値 |
|---|---|
| Cosmos DB | 第3章の Serverless account |
| 仮想ネットワーク規則 | App Service と同じ統合サブネット |
| サービス エンドポイント | `Microsoft.AzureCosmosDB` |
| IP 規則 | 社内 CIDR と `0.0.0.0` を維持 |
| キー認証 | 無効を維持 |

```bash
az resource show --ids '<cosmos-resource-id>' --api-version 2024-11-15 --query '{virtualNetworkRules:properties.virtualNetworkRules,vnetFilter:properties.isVirtualNetworkFilterEnabled,ipRules:properties.ipRules,disableLocalAuth:properties.disableLocalAuth}' --output json
```
実行結果の確認ポイント: 統合サブネットの規則・VNet フィルター有効・既存 IP 規則・キー無効が一致することを確認します。

#### アプリ専用の保存先と MI の権限を準備する

検証担当者が、キー無効のままデータベース／コンテナーを作成する権限を持つことを前提とします。作成の権限と、作成後のデータ閲覧ロールは別に確認します。

1. App Service の [Settings] > [Identity] を開きます。
2. [System assigned] の [Status] を [On] にします。
3. [Save] を選択します。
4. 保存時に有効化の確認が出た場合は対象アプリを照合して確定します。
5. [Identity] を開き直し、[Object (principal) ID] を非公開メモへ控えます。Foundry の project MI と区別します。
6. Azure portal の検索欄から第3章の Cosmos DB を開きます。
7. [Data Explorer] を選択します。
8. 同名のアプリ用 DB／コンテナーが未作成の場合だけ、[New Container] を選択します。
9. 下表の値を入力します。
10. [OK] を選択します。
11. 左側のデータベース一覧でアプリ用 DB を展開し、コンテナー名とパーティションキーを確認します。既存の場合も値を照合し、異なる設定を上書きしません。

| 項目 | 値 |
|---|---|
| Database id | [Create new] で `<app-db>`。`enterprise_memory` とは別 |
| Container id | `<app-container>` |
| Partition key | `/userId` |
| 容量 | 既存 Serverless を維持。Provisioned の RU/s を設定しない |

> **Note** 要確認: [Settings]・[Identity]・[System assigned]・[Status]・[New Container] 等の日本語表示は初回に照合します。Data Explorer の作成・閲覧は検証担当者の権限で行い、アプリ MI の割当とは分けます。管理ロールだけでデータ閲覧が可能とは扱いません。

Cosmos のデータ面ロール管理は portal 非対応のため、Azure portal 上部から Cloud Shell を開き、[Bash] を選択します。第5章の対象確認後、アプリ専用コンテナーに限定して割り当てます。App Service MI へ account 全体や Agent Service の `enterprise_memory` の権限を与えません。

```bash
az cosmosdb sql role definition list --resource-group '<rg>' --account-name '<cosmos-account>' --query "[?roleName=='Cosmos DB Built-in Data Contributor'].{id:id,roleName:roleName}" --output json
```
実行結果の確認ポイント: 組み込みのデータ面ロールの ID を確認します。

次の作成コマンドの前に、直下の `role assignment list` で既存割当を照会します。同じ App Service MI・ロール・コンテナースコープの割当があれば、作成を省略します。広い既存権限が見つかった場合は追加せず、変更前の記録と照合して保留します。

```bash
az cosmosdb sql role assignment create --resource-group '<rg>' --account-name '<cosmos-account>' --role-definition-id '<built-in-data-contributor-role-id>' --principal-id '<app-service-mi-principal-id>' --scope '/dbs/<app-db>/colls/<app-container>'
```
実行結果の確認ポイント: App Service の MI とアプリ専用コンテナーのスコープが一致することを確認します。

```bash
az cosmosdb sql role assignment list --resource-group '<rg>' --account-name '<cosmos-account>' --output json
```
実行結果の確認ポイント: 同じ MI の既存割当も確認し、`enterprise_memory` や account 全体へのデータ権限がないことを照合します。

Data Explorer で確認する担当者にもアプリ専用コンテナーのデータ閲覧権限が必要です。上記と同じ方法で Cosmos DB Built-in Data Reader を照会し、担当者へ同スコープで割り当てます。作成操作が権限不足で失敗する場合は管理面／データ面の操作を切り分け、キーを再有効化しません。

アプリ実装・配布後、社内ブラウザから合成会話の [会話メモを保存] を実行します。[Data Explorer] のアプリ専用コンテナーで JSON を確認し、Agent Service のコンテナーへ書き込まれていないことを確認します。アプリ仕様は [同梱仕様](../assets/app/README.md) に記載し、この章ではコードを実装しません。

### 6. サインインと本人トークンを設定する

Easy Auth 転送＋REST を採用します（D17・2026-09-20）。入口の署名・発行者・audience の検証は Easy Auth、下流トークンの検証は Foundry が担当し、アプリは本人ヘッダーと期限を確認します。Foundry を MI で呼ぶ代替は使いません。

> **Note** 要確認: 以下の en-us の画面名の日本語表示は初回に照合します。

1. 対象 App Service の [Settings] を開きます。
2. [Authentication] を選択します。
3. [Add identity provider] を選択します。
4. [Microsoft] を選択します。
5. [Workforce configuration (current tenant)] を選択します。
6. [Create new app registration] を選択します。
7. [Name] に下表の値を入力します。
8. [Supported account type] に下表の値を選択します。

| 項目 | 値 |
|---|---|
| [Name] | `<app-registration-name>`（今回の App Service 専用） |
| [Supported account type] | [Current tenant - Single tenant] |

9. [Configure additional checks] の [Tenant requirement] を下表の値にします。
10. [Client application requirement] の既定値を維持します。
11. [Identity requirement] の既定値を維持します。
12. [Configure authentication settings] の [Restrict access] を下表の値にします。
13. [Unauthenticated requests] を下表の値にします。
14. [Token store] をオンにします。
15. [Add] を選択します。

| 項目 | 値 |
|---|---|
| [Tenant requirement] | アプリ登録と同じテナントのみ |
| [Client application requirement] | 既定 |
| [Identity requirement] | 既定 |
| [Restrict access] | [Require authentication] |
| [Unauthenticated requests] | [HTTP 302 Found redirect] |
| [Token store] | オン |

> **補足** シークレットはアプリ設定 `MICROSOFT_PROVIDER_AUTHENTICATION_SECRET` に自動保存されます。値を見たり記録したりしないでください。アプリコードには保持しません。

16. [Authentication] で作成した ID プロバイダーの編集を開きます。
17. issuer URL を下表の値に変更します。
18. 変更を保存します。
19. [Settings] → [Environment variables] → [App settings] を開き、[Add] で `WEBSITE_AUTH_AAD_ALLOWED_TENANTS` を下表の値として登録します。既存ならその行を編集します。
20. 入力画面の [Apply]、一覧画面の [Apply] の順に選択します。再起動の確認が出た場合は確定し、反映後に設定名を確認します。

| 項目 | 値 |
|---|---|
| issuer URL | `https://login.microsoftonline.com/<tenant-id>/v2.0` |
| `WEBSITE_AUTH_AAD_ALLOWED_TENANTS` | `<tenant-id>` |

> **補足** 簡易作成時の issuer URL はレガシーの `https://sts.windows.net` になるため、現行形式へ編集します。`/healthz`・`/api/*` を含め、Easy Auth の除外パスは作りません。

21. Azure portal の検索欄から [Microsoft Entra ID] を開き、今回のテナントの [App registrations] を選択します。
22. 工程 6 で入力したアプリ登録名を検索して選択し、[Overview] の client ID を App Service の認証プロバイダー設定と照合します。
23. [API permissions] を選択します。
24. [Add a permission] を選択します。
25. API の検索欄から Foundry（`https://ai.azure.com`）に対応する API を探し、対象を選択します。
26. [Delegated permissions]（委任されたアクセス許可）を選択します。
27. 対象 API の必要な委任許可を選択し、[Add permissions] を選択します。下記の初回照合ができない場合は追加しません。
28. 同意権限のある担当者が [Grant admin consent] を選択し、対象テナント・API・委任許可を確認して確定します。
29. [API permissions] を開き直し、追加した許可が Delegated であることと同意の状態を記録します。

> **Note** 要確認: API 一覧での表示名・検索するタブ・必要な委任許可名は初回に照合します（「Azure AI Foundry」「Microsoft Foundry」「Azure Machine Learning Services」のいずれか）。見つからなければここで停止します。委任されたアクセス許可が無ければ `.default` の要求は成功しません。

#### Cloud Shell でログインスコープを設定する（GUI に無い操作）

以下は構築担当の Cloud Shell（Bash）で行います。対象アプリの名前・RG・サブスクリプションを非公開メモと照合し、全コマンドで同じ値を使います。リポジトリ外の非公開作業用ディレクトリを使い、既存の同名ファイルを上書きしません。GET が成功し、有効な JSON が保存されたことを確認してから編集・PUT へ進みます。GET した全設定を残し、`loginParameters` だけを変更します。JSON 全体をログや共有証跡へ貼らず、確認出力も当該配列に限定します。

```bash
az rest --method get --url "https://management.azure.com/subscriptions/<subscription-id>/resourceGroups/<rg>/providers/Microsoft.Web/sites/<app-name>/config/authsettingsV2?api-version=2024-11-01" --output json > authsettingsV2.json
```
実行結果の確認ポイント: 対象アプリの設定が `authsettingsV2.json` に保存されます。対象名を照合し、ファイル全文を表示しません。

```bash
python3 - <<'PY'
import json
from pathlib import Path
path = Path('authsettingsV2.json')
data = json.loads(path.read_text())
login = data['properties']['identityProviders']['azureActiveDirectory'].setdefault('login', {})
login['loginParameters'] = ['scope=openid profile email offline_access https://ai.azure.com/.default']
path.write_text(json.dumps(data))
print('loginParameters を更新しました')
PY
```
実行結果の確認ポイント: `loginParameters` 以外の設定を保持し、この配列を本人用 Foundry スコープと更新用 `offline_access` に置き換えます。既存配列に別用途の指定がある場合は、その必要性を確認するまで PUT を行いません。

```bash
az rest --method put --url "https://management.azure.com/subscriptions/<subscription-id>/resourceGroups/<rg>/providers/Microsoft.Web/sites/<app-name>/config/authsettingsV2?api-version=2024-11-01" --body @authsettingsV2.json --output none
```
実行結果の確認ポイント: 更新が成功し、設定の全文が標準出力へ出ないことを確認します。

```bash
az rest --method get --url "https://management.azure.com/subscriptions/<subscription-id>/resourceGroups/<rg>/providers/Microsoft.Web/sites/<app-name>/config/authsettingsV2?api-version=2024-11-01" --query 'properties.identityProviders.azureActiveDirectory.login.loginParameters' --output json
```
実行結果の確認ポイント: 配列が `scope=openid profile email offline_access https://ai.azure.com/.default` と一致します。

> **補足** Learn の手順は API Playground（Preview）ですが、本ラボでは同じ REST を Cloud Shell で行います。API Playground は使用しません。

#### アプリ設定と起動コマンドを登録する

1. 対象 App Service の [Settings] → [Environment variables] を開きます。
2. [App settings] を選択します。
3. [Add] を選択します。既存の項目を変更する場合は、その項目名を選択します。
4. 名前欄と値欄に、下表の 1 項目を入力します。山括弧は実値へ置き換えます。
5. 入力画面の [Apply] を選択します。
6. 他の項目も手順 3〜5 で 1 件ずつ登録します。
7. 一覧画面の [Apply] を選択し、再起動の確認が出た場合は確定します。
8. [App settings] を開き直し、登録した設定名を確認します。個別の非秘密設定だけを必要に応じて照合し、全設定の値を表示・コピーしません。

> **画面の見え方** 現行の Learn では環境変数は [Environment variables]、起動コマンド等は [Configuration] に分かれています。[Connection strings] には登録しません。日本語表示が異なる場合は各英語名と対応を照合します。

| 項目 | 値 |
|---|---|
| `FOUNDRY_PROJECT_ENDPOINT` | `https://<resource-name>.services.ai.azure.com/api/projects/<project-name>` |
| `FOUNDRY_AGENT_NAME` | `<agent-name>`（既存エージェント。英数字・`_`・`-` の 1〜64 文字） |
| `FOUNDRY_AGENT_DISPLAY_NAME` | `<agent-display-name>`（画面表示名） |
| `ENTRA_TENANT_ID` | `<tenant-id>` |
| `COSMOS_ENDPOINT` | `<cosmos-endpoint>`（作成済み Cosmos DB の HTTPS エンドポイント） |
| `COSMOS_DATABASE` | `<app-db>` |
| `COSMOS_CONTAINER` | `<app-container>`（`enterprise_memory` 禁止） |
| `APP_VERSION` | `<version>`（ZIP の版と一致） |
| `SCM_DO_BUILD_DURING_DEPLOYMENT` | `true` |

`MAX_PROMPT_CHARS` は既定 2000、`FOUNDRY_TIMEOUT_SECONDS` は既定 60 を使います。検証規則と App Service 側の設定は[同梱仕様](../assets/app/README.md#設定項目)を参照します。

9. [Settings] → [Configuration] → [General settings] を開きます。
10. [Stack] に下表の値を選択します。
11. Python のバージョン欄で 3.12 を選択します。
12. [Startup Command] に下表の値を入力します。
13. [保存] を選択し、再起動の確認が出た場合は確定します。
14. 同じ画面を開き直し、ランタイムと起動コマンドを照合します。

| 項目 | 値 |
|---|---|
| [Stack] | Python |
| [Major version] | 3.12 |
| [Startup Command] | `python -m uvicorn app.main:app --host 0.0.0.0 --port 8000` |

> **Note** 要確認: 3.12 が一覧に無ければ一覧にある最も近い 3.x を選び、[README の requires_python](../assets/app/README.md#配布物と配布方式) を満たすことを確認します。代替版は未検証です。ポート 8000 の成立も初回に [Log stream] で照合します。

15. 構築担当とは別のブラウザプロファイルで、App Service の [概要] に表示された HTTPS URL を開きます。
16. 第5章の開発用ユーザーとしてサインインします。
17. 同意画面が出た場合は対象アプリと Foundry の許可を照合します。

確認ポイント: 同意画面・`/.auth/me` の出力を証跡に貼りません。管理者同意済み等で同意画面が出ない場合、画面が無いことを成功の証拠にはせず、設定と初回要求で照合します。アプリ画面と API は工程 7 の配布後に確認します。

> **Note** 要確認: 取得したアクセス トークンの `aud` が `https://ai.azure.com` であることの確認方法（外部サイトに貼らずに確認する手段）は初回に検証チームが決めます。

| 確定したこと | 初回で照合すること |
|---|---|
| Easy Auth 転送・トークン ストア・Foundry スコープ・1 回の更新 | 委任許可の表示名、同意、本人トークンの取得と audience、`X-MS-CLIENT-PRINCIPAL-IDP` の値（アプリは `aad` を前提） |
| REST の既存エージェント Responses endpoint・1 往復 | 応答 JSON の形、Consumer の実行可否（C02） |
| Oryx・固定依存・起動コマンド・社内 PC の ZIP 配布 | Python の選択、ポート、SCM 到達・ビルド・起動 |

### 7. 同梱アプリを配布する

[同梱アプリ](../assets/app/README.md) は実装済みです。Azure への配布・本人認証・到達・保存は初回実行で確認します。

| 同梱物 | 実物と配布範囲 |
|---|---|
| サーバー | `assets/app/app/` の `__init__.py`、`main.py`、`config.py`、`auth.py`、`foundry.py`、`cosmos.py` |
| 画面 | `app/static/index.html`、`app.js`、`app.css` |
| 固定依存 | `assets/app/requirements.txt` の直接依存 5 つ。推移的依存は Oryx の pip 解決 |
| ローカル確認 | `assets/app/tests/`、`requirements-dev.txt`。ZIP には入れない |
| 配布スクリプト | `scripts/package_app.sh`。`outputs/app-<version>.zip` と SHA256 を生成 |

社内 PC の Bash でリポジトリ直下から実行します。版は英数字で開始し、英数字・`.`・`_`・`-` を使います。同じ版の上書きはしません。

1. 社内 PC のターミナルで、第1章で確認したリポジトリの保存先へ移動します。Cloud Shell にだけ取得済みの場合は、社内 PC 側にも承認された配布対象版を用意します。
2. `scripts/package_app.sh` と `assets/app/requirements.txt` があることを確認します。
3. 配布対象のコミットと `<version>` を非公開メモに記録し、工程 6 の `APP_VERSION` と揃えます。
4. 次のコマンドで ZIP を作成します。

```bash
bash scripts/package_app.sh '<version>'
```
実行結果の確認ポイント: ZIP ルート直下に `app/` と `requirements.txt` が入り、tests・README・開発依存・キャッシュは含まれません。`.zip.sha256` と標準出力のハッシュが得られます。

macOS でハッシュを照合します。

```bash
(cd outputs && shasum -a 256 -c 'app-<version>.zip.sha256')
```
実行結果の確認ポイント: 対象 ZIP が OK と表示されます。

Linux では代わりに次を使います。

```bash
(cd outputs && sha256sum -c 'app-<version>.zip.sha256')
```
実行結果の確認ポイント: 対象 ZIP が OK と表示されます。

#### なぜ配布時だけ社内 PC を使うのか

通常は、設定を理解しながら作業できる Azure portal を主線とし、コマンドはインストール不要の Cloud Shell で実行します。ただし、今回のアプリ配布では次の制約が重なります。

1. Python アプリの配置先は Linux B1 です。Linux では Kudu の ZIP デプロイ UI が使えないため、ブラウザで ZIP をドラッグする手順を採用できません。
2. ZIP 配布先の SCM は、メインサイトと同じ社内 IP 許可リストで保護します。Cloud Shell はブラウザを表示している社内 PC ではなく Azure 側で動くため、社内 PC の送信元 IP を引き継ぎません。
3. このため、SCM の制限を維持したまま ZIP を送る経路として、承認済み社内ネットワーク上の PC から Azure CLI を実行します。社内 PC でもプロキシや接続経路によって送信元が異なる場合は、許可された送信元であることを確認します。

> **補足** 2026-09-16 に、**アプリの ZIP 配布と、そのためのローカル認証・対象確認だけ**を社内 PC の Azure CLI で行う例外を暫定採用しました。リソース作成や通常の設定変更までローカル CLI に移す方針ではありません。SCM の IP 制限、Entra 認証、FTP 無効を維持し、実機検証時にこの配布方法の到達性・権限・端末要件を再評価します。方針の承認は、配布成功を確認したという意味ではありません。

#### 社内 PC から固定版 ZIP を配布する

この節だけは **Cloud Shell ではなく社内 PC の Bash** で実行します。組織で承認された Azure CLI と Bash を用意し、端末への導入方法は社内ルールに従います。工程 6 の認証・アプリ設定と、工程 7 で作った ZIP・ハッシュを照合してから実行します。

| 確認する項目 | 条件 |
|---|---|
| 接続元 | SCM が許可する社内の外向き IP を使用 |
| Azure CLI | 組織が認めるサポート中の版。Entra 配布対応の下限は 2.48.1 |
| 配布担当者 | 対象アプリへの配布権限を持つ個人アカウント。Consumer の試験主体とは区別 |
| 配布物 | 検証済みの固定版 ZIP とハッシュ。余分な最上位フォルダーや秘密値を含めない |
| 認証 | SCM／FTP の基本認証発行資格情報を無効化し、Entra 認証を使用 |
| ビルド・起動 | 配布版の仕様に合わせて portal で設定済み。ZIP 配布だけで依存関係が揃うとは扱わない |

1. Azure portal の対象アプリで [構成] → [全般設定] を開きます。
2. [SCM 基本認証発行資格情報] を無効にします。
3. [FTP 基本認証発行資格情報] を無効にします。
4. [保存] を選択します。
5. 社内 PC の Bash で Azure CLI のバージョンを確認します。

```bash
az version --query '"azure-cli"' --output tsv
```
実行結果の確認ポイント: 組織の承認版で、2.48.1 以降であることを確認します。

6. 配布担当者として対象テナントへサインインします。

```bash
az login --tenant '<対象テナントID>' --output none
```
実行結果の確認ポイント: ブラウザで対象の個人アカウント・MFA を確認し、サインインが完了することを確認します。既存の条件付きアクセスは変更しません。

7. 配布対象のサブスクリプションを確認します。

```bash
az account show --subscription '<対象サブスクリプションID>' --query '{subscription:id,tenant:tenantId,name:name}' --output json
```
実行結果の確認ポイント: 非公開の記録とテナント・サブスクリプションが一致することを確認します。

8. 固定版 ZIP を、作成済みの今回のアプリへ配布します。

```bash
az webapp deploy --subscription '<対象サブスクリプションID>' --resource-group '<専用RG名>' --name '<今回のアプリ名>' --src-path '<固定版ZIPのローカルパス>' --type zip
```
実行結果の確認ポイント: 対象アプリと配布結果を確認し、配布後の起動・社内ブラウザでの本人認証・エージェント応答を別々に確認します。ZIP 送信成功だけで 7.4 を完了にしません。

> **画面の見え方** 基本認証が無効な場合、対応する Azure CLI は Entra 認証で配布します。発行プロファイルやパスワードをダウンロードして回避しません。CLI の認証は配布担当者用で、アプリ利用者の Foundry 用トークンとは別です。

> **Note** 要確認: 方針は暫定採用済みですが、実機での SCM 到達・配布権限・ビルド・起動は未検証です。403 の場合は送信元 IP と配布権限を分けて確認し、SCM を全公開にせず停止します。工程 6 の設定と今回作成した固定版 ZIP を使って初回結果を記録します。

#### 配布後に GUI と社内ブラウザで確認する

1. 構築担当で Azure portal の対象 App Service を開き、[Deployment Center] を選択します。
2. [Logs] を選択します。

確認ポイント: Oryx がルートの `requirements.txt` を使ってビルドを完了しています。送信成功だけで起動成功にしません。

3. [Log stream] を開きます。

確認ポイント: uvicorn の起動を確認します。失敗時は設定名・Python ランタイム・ポートを照合し、例外全文や秘密値を共有証跡へ貼りません。

4. App Service の [概要] にある HTTPS URL の末尾に `/healthz` を付け、別のブラウザプロファイルで開きます。
5. 第5章の開発用ユーザーとしてサインインします。

確認ポイント: `{"ok": true, "app_version": "<version>"}` が返り、配布版と一致します。Easy Auth の除外パスは作らないため、App Service の正常性チェック機能には使えません。

6. 同じブラウザで URL の `/healthz` を外してアプリのトップ `/` を開き、対象エージェントの表示名を確認します。
7. 入力欄に合成プロンプトを入力します。
8. [送信] を選択します。

確認ポイント: 同じ既存エージェントから 1 往復の応答が返り、相関 ID が表示されます。Consumer の可否は第8章 C02 で比較します。

> **画面の見え方** 次の画像はアプリをローカルで起動した画面です（Azure 未接続・表示名と入力は架空）。1 枚目が初期画面、2 枚目は Easy Auth のヘッダーが無い状態で [送信] した実際の挙動（「失敗した層」が `entry`。相関 ID はローカルで生成した乱数）、3 枚目は応答と保存結果の表示例で、応答 JSON をブラウザ側でサンプルに差し替えて描画したものです。実機では応答本文・相関 ID・メモ ID が実際の値になります。
>
> ![初期画面](../images/07_app_01_initial.png)
>
> ![入口で拒否された画面](../images/07_app_02_entry_rejected.png)
>
> ![応答と保存結果の表示例](../images/07_app_03_response_and_memo.png)

9. [会話メモを保存] を選択します。

確認ポイント: 保存成功、メモ ID、`userId` の先頭 12 文字が表示されます。

10. メモ ID と `userId` の先頭 12 文字を非公開に控えます。
11. 構築・検証用のブラウザへ戻り、Cosmos DB の [Data Explorer] を開きます。
12. 左側で `<app-db>` → `<app-container>` → [Items] を順番に開きます。
13. 一覧を更新し、手順 10 のメモ ID に一致する項目を選択します。
14. JSON の保存先・項目・時刻を下記の確認ポイントと照合します。

確認ポイント: メモ ID と `userId` の先頭 12 文字が画面と一致し、`prompt`・`response`・`createdAt`・`appVersion` が存在します。生の oid を含まず、`enterprise_memory` には書かれていません。本文・ユーザー識別子を診断ログや共有証跡へ貼りません。

### 8. ツール経路用の APIM Basic v2 を作る

**ここから工程 10 まではツール仕様の確定待ちです。** ツールの URL・プロトコル・認証・許可操作が未確定のまま、APIM の作成やポリシー編集を始めません。工程 1〜7 の結果を記録してここで止め、7.4 全体は未完了として残します。以下は仕様確定後に使う操作ドラフトです。本人の呼び出し先として APIM を設定しません。

1. Azure portal の [リソースの作成] で [API Management] を検索します。
2. [作成] を選択します。
3. [基本] に下表の値を入力します。
4. [タグ] を入力します。
5. [レビュー + 作成] で追加サービスや SKU を照合します。
6. [作成] を選択します。
7. [概要] でオンラインになったことを確認します。

| 項目 | 値 |
|---|---|
| RG／リージョン | 今回の専用 RG／Japan East |
| リソース名 | `<今回のAPIM名>` |
| 組織名／管理者メール | 承認済みの値を portal だけに入力 |
| 価格レベル／単位 | Basic v2／1 |
| 追加ネットワーク | APIM 自体を VNet 統合しない |

> **画面の見え方** Basic と Basic v2 は別の SKU です。APIM の MI を有効化しても Agent Service の呼び出し元 ID にはなりません。

### 9. ツール API の認証・許可先・quota を設定する

本工程の前提は、承認済みの仕様でツール API を登録できていることです。API のインポート方法と完成ポリシーは未確定のため、現時点では次の操作を実行しません。

1. 対象 APIM の [APIs] → [APIs] を開きます。
2. 登録済みの対象ツール API を選択します。[All APIs] を選んで全体へ適用する操作ではありません。
3. [Design] を開き、適用対象の API／操作を照合します。
4. [Inbound processing] のコードエディターアイコン [</>] を選択します。
5. 現在のポリシーを非公開に記録し、下表を満たす確定済みポリシーを反映します。未確定の値を推測して XML を作りません。
6. [Save] を選択します。
7. [Calculate effective policy] で親から継承された規則を確認します。
8. 対象 API／操作を開き直し、許可主体・バックエンド・集計キーと、意図しない社内 IP 制限の継承がないことを照合します。

| 設定 | 確定する内容 |
|---|---|
| `validate-azure-ad-token` | 対象テナント、ツール API の audience、許可されたプロジェクト MI／エージェント ID の識別子 |
| 許可主体 | テナントが一致するだけで全主体を許可しない。実際のトークンの種類に合うアプリ ID／object ID／claim の規則 |
| バックエンド | 承認された HTTPS URL と操作だけ。ユーザー入力で接続先を変更しない |
| `ip-filter` | 社内からの直接試験用 API／操作だけ。ツール API に社内 IP のみの規則を継承させない |
| `quota-by-key` | ツール呼び出し回数、期間、上限、検証済み主体から作る集計キー |
| サブスクリプションキー | Entra 認証と拒否試験の成立後に必須設定を見直す。無効化を先行しない |

> **Note** 要確認: ツール実体・MCP の GA 接続方式・許可する主体・audience・quota の具体値が未確定です。入力値のない完成 XML や API インポート操作は載せません。MCP の接続仕様に合わない通常の REST API を置いただけでツール連携完了とはしません。

呼び出し元から渡されたヘッダーをそのまま quota の集計キーにしません。ツール quota の超過は `quota-by-key` の 403 として確認し、認証・認可・IP 拒否と区別します。429 はレート制限の結果として別に記録します。一般の MCP 応答に `llm-token-limit` を適用しません。本人経路と Foundry 内部のモデル呼び出しは APIM を通らないため、そのトークン量や費用全体はここでは制限できません。

公開ツールを追加しないこと、接続先・操作を固定すること、ツール編集権限を制限することを確認します。この運用を、Agent Service の送信ネットワーク全体を遮断する機能と説明しません。

### 10. ツール経路の診断を追加する

1. APIM の [監視] → [診断設定] を開きます。
2. 既存設定のカテゴリと送信先を確認し、同じ送信がない場合だけ [診断設定を追加する] を選択します。
3. 設定名を入力し、ゲートウェイログの個別カテゴリを選択します。
4. [Log Analytics ワークスペースへの送信] を選択し、サブスクリプション・LAW・リソース固有の保存方式を下表に合わせます。
5. [保存] を選択し、同じ設定を開き直して照合します。
6. [APIs] → [APIs] → [All APIs] → [Settings] を開きます。
7. [Diagnostic Logs] まで移動し、[Azure Monitor] タブを開きます。
8. 要求・応答本文と認証ヘッダーが収集対象でないことを確認します。変更した場合は [Save] を選択します。
9. [APIs] に戻って対象ツール API を選び、同じ [Settings] → [Diagnostic Logs] → [Azure Monitor] で個別の上書きを確認します。

| 項目 | 値 |
|---|---|
| 診断設定名 | `gateway-to-law` |
| ログ | ゲートウェイログ。表示カテゴリを照合 |
| 宛先 | 第1章の既存 Log Analytics |
| テーブル | リソース固有の `ApiManagementGatewayLogs` |
| 保持・閲覧 | 第6章の 30 日・閲覧権限と照合 |

> **画面の見え方** APIM リソースの [ログ] を開き、今回の APIM をスコープにします。ワークスペース全体のログと混同しません。アプリの本人経路は APIM に現れないため、アプリ側の相関 ID と Foundry の結果を別に記録します。

ツールを実装して合成入力を送信した後に、次の順で照会します。未実装の状態ではログを生成済みとは扱いません。

1. 対象 APIM の [監視] → [ログ] を選択します。
2. 照会スコープが今回の APIM であることを確認します。
3. 第6章と同じ方法で [KQL モード] を開き、下記のクエリを貼り付けます。
4. 試験時刻が直近 30 分以内に含まれることを確認して [実行] を選択します。
5. 対象の API・操作・相関 ID に一致する行を記録します。

```kusto
ApiManagementGatewayLogs
| where TimeGenerated > ago(30m)
| project TimeGenerated, CorrelationId, ApiId, OperationId, ResponseCode, BackendResponseCode
| order by TimeGenerated desc
| take 20
```
実行結果の確認ポイント: ツールの試験時刻・API・相関 ID・受信とバックエンドの応答を照合し、本人の Foundry 呼び出しの証拠と混同しません。

ログ到着の遅延やテーブル未作成を、拒否試験の成功としません。アプリの診断は仕様に従い、本文・トークンを除く相関 ID・成否・処理時間を対象にします。第6章の本文監査の保留を APIM の本文ログで代替しません。

### 11. Fabric の容量と検証用ワークスペースを確認する

> **Note** 状態: Fabric 工程はドラフト（Learn 2026-09 時点・未実行）。`fabric_dataagent_preview` は Cosmos 接続に続く2つ目の限定 Preview 例外です（D18）。SLA なし・本番非推奨の学習用として採用します。

工程1〜10の後に、Fabric の準備から接続までを続けます。第3章の BYO データ基盤とは用途・管理境界が異なるため、本人経路ができた本章にまとめます。最初はツールなしで応答を確認し、ゲートウェイの準備後に許可した接続だけを追加する順序を維持します。

1. 社内ブラウザで [Microsoft Fabric](https://app.fabric.microsoft.com/) を開きます。
2. 第0章で確認したテナントの開発用ユーザーでサインインします。
3. [ワークスペース]（[Workspaces]）を選択します。
4. [新しいワークスペース]（[New workspace]）を選択します。
5. 下表の名前を入力します。
6. [適用]（[Apply]）を選択します。
7. 作成したワークスペースの [ワークスペースの設定] を開きます。
8. [ワークスペースの種類]（[Workspace type]）で割り当て先容量を照合します。
9. 管理担当者から受け取った容量の SKU・リージョンと照合します。
10. データエージェントと元データをこのワークスペースに配置することを記録します。

| 項目 | 値 |
|---|---|
| ワークスペース名 | `ws-agentgov-<実施者略号>-run<N>`。専用の検証領域 |
| 容量 | 事前確認済みの有料 F2 以上、または Fabric 有効の Power BI Premium P1 以上 |
| テナント | Foundry project と同一 |
| 配置 | データエージェントと元データの容量を同一リージョンに統一 |
| 利用者 | 第5章の Fabric 許可／拒否グループ。利用者には作成用のワークスペースロールを一律付与しない |

> **Note** 要確認: 画面名の日本語訳・容量の表示位置・自動割り当て先を実機で照合します。容量が未割り当て、条件外、またはテナント設定・ライセンスが未確認なら Fabric 工程を保留します。容量は事前確認済みのものを使い、作成手順は扱いません。割り当てが違う場合は容量管理担当者に確認し、勝手に容量を変更しません。

### 12. 合成サンプルデータを用意する

主線はレイクハウスの合成データに対する「読める／読めない」の2パターンです。RLS のモデル設計を増やす前に、Foundry の呼び出し権限と Fabric のデータ権限を分離して確認するためです。この主線だけで部署別の行フィルターを検証したとは扱いません。

1. 下の内容を UTF-8 の `synthetic_sales.csv` として手元に保存します。

```csv
department,month,sales
DeptA,2026-01,100
DeptA,2026-02,150
DeptB,2026-01,200
DeptB,2026-02,250
```

確認ポイント: ヘッダーと合成データ4行だけであり、実データ・実名が含まれていません。

2. 検証用ワークスペースで [新しい項目]（[New item]）を選択します。
3. [Lakehouse] を選択します。
4. 名前に `lh_synthetic_sales` を入力します。
5. [作成]（[Create]）を選択します。
6. [Files] の下に `synthetic` フォルダーを作成します。
7. フォルダーの […] から [Upload] を選択します。
8. [Upload files] で `synthetic_sales.csv` を選択します。
9. アップロードしたファイルの […] を開きます。
10. [Load to tables] を選択します。
11. [New table] を選択します。
12. 下表の読み込み設定を照合します。
13. [Load] を選択します。
14. [Tables] の `synthetic_sales` を開きます。
15. 列名・型・4行の値を CSV と照合します。

| 項目 | 値 |
|---|---|
| テーブル | `synthetic_sales` |
| 区切り | カンマ。先頭行を列名として扱う |
| department / month | 文字列 |
| sales | 数値。架空の売上単位 |
| 正常時の照合値 | DeptA 250、DeptB 450、合計700 |

> **Note** 要確認: 読み込み設定の表示と型推論は初回で確認します。再実行時に [Append] で二重登録しません。既存表がある場合は4行と値を照合して再利用し、不一致なら原因を記録して保留します。実データを代用しません。

> **Note** 要確認の拡張 (任意): セマンティック モデルにこの合成表を用意し、部署Aグループは `department = "DeptA"`、部署Bグループは `department = "DeptB"` の RLS を適用する案です。両者にデータエージェント READ とモデル Read を付与し、同じ質問で250／450になることを確認します。モデル管理担当者が RLS の作成・利用者ロール・直接共有・ライセンスを確認してから別試験にします。RLS を迂回する管理権限や元レイクハウスへの別経路を混ぜず、指示文を行制御の代わりにしません。未実施の拡張は C11 主線と分けて Pending とします。

### 13. Fabric データエージェントを作成・公開・共有する

1. 検証用ワークスペースで [新しい項目]（[New item]）を選択します。
2. [Fabric data agent] を検索します。
3. [Fabric data agent] を選択します。
4. 名前に `synthetic-sales-agent` を入力します。
5. 作成画面を確定します。
6. OneLake カタログで `lh_synthetic_sales` を選択します。
7. [Add] を選択します。
8. [Explorer] で `synthetic_sales` だけを選択します。
9. [Data agent instructions] を開きます。
10. 下の指示文を入力します。

```text
部署別の合成売上の質問には synthetic_sales を使います。
sales は架空の売上単位です。部署別に sales を合計します。
アクセスできるデータだけで回答し、取得できない値を推測しません。
権限不足や問い合わせ失敗は失敗として伝えます。
```

確認ポイント: 指示に実データや回答の正解値を埋め込んでいません。指示文自体は権限を制限する仕組みではありません。

11. Fabric のチャットで「合成売上を部署別に合計してください。」と入力します。
12. 表の照合値と生成されたクエリを確認します。
13. [Publish] を選択します。
14. 説明に「検証用の合成売上を部署別に集計します。」と入力します。
15. 公開を確定します。
16. 公開版が利用できることを確認します。
17. データエージェントの [Share] を開きます。
18. `<fabric-allowed-group>` に READ のみを付与します。
19. レイクハウスの […] から [Share] を開きます。
20. 同じ許可グループに Read を付与します。
21. 両項目の [Manage permissions] で直接割当と継承を照合します。
22. `<fabric-denied-group>` に両項目のアクセスがないことを確認します。
23. 公開時刻・対象表・共有範囲を非公開で記録します。

> **Note** 要確認: 公開確定・共有・READ の実画面名は初回で照合します。Learn の Foundry 連携はレイクハウス Read（必要な表アクセスを含む）を最低条件としますが、SQL analytics endpoint の一般的な共有には別の読取権限もあります。Read のままで成功するかを C11 で確認し、不足時は Fabric 管理担当者が利用経路と対象表の最小権限を照合します。無差別に [Read all] やワークスペース Member を追加しません。日本語指示の解釈・クエリ生成も実機で確認します。

下書き保存と公開は異なります。構成を変えた場合は公開版へ反映したことを確認します。開発者の Fabric チャットでの成功は、App Service 利用者の本人経路の成功ではありません。

### 14. Foundry エージェントに Fabric ツールを追加する

1. 公開した Fabric データエージェントを開きます。
2. URL の `.../groups/<workspace_id>/aiskills/<artifact_id>...` から2つの GUID を非公開で控えます。
3. Foundry ポータルで既存の project を開きます。
4. 第4章で作成した既存エージェントを開きます。
5. 変更前のエージェントの版と指示文を非公開で記録します。
6. ツール追加画面で [Microsoft Fabric data agent] を選択します。
7. 下表の2つの値を入力します。
8. ツールの設定を確定します。
9. ツール構成で作成された project connection を確認します。
10. 接続 ID と接続先が今回の Fabric 資産に一致することを記録します。
11. 既存の指示文に下の内容を追記します。
12. 変更を保存します。
13. App Service が参照するエージェントの名前・版と保存先を照合します。

| 項目 | 値 |
|---|---|
| workspace_id | 検証用ワークスペースの GUID。実値はリポジトリに書かない |
| artifact_id | 公開したデータエージェントの GUID。レイクハウスの ID ではない |
| ツール | `fabric_dataagent_preview` |
| 接続 | ツール追加時に自動作成される project connection。管理センターで別に作成しない |

```text
部署別の合成売上を問われたら Microsoft Fabric data agent ツールを使用してください。
ツールが返したデータだけで回答し、失敗時は数値を推測せず失敗を伝えてください。
```

確認ポイント: 既存の指示を残し、Fabric を使う質問の範囲だけを追記しています。

> **Note** 要確認: ツール追加・保存時の UI、版の反映、D17 の既存 App Service から Fabric まで本人 ID が渡ることは第8章 C11 で確認します。Playground は開発者自身の ID で動きます。サービス プリンシパル認証は Fabric ツールで非対応のため、共有 MI へ切り替えて成功扱いにしません。Learn の `tool_choice` による強制呼び出しは切り分けの候補ですが、本手順では既存アプリのコードを変更せず、指示文で呼び出しを促します。ツール呼び出しの証拠が得られなければ Pending です。

> **補足** Basic／Standard の両 setup が対応します。Foundry のモデルはオーケストレーションと応答用で、Fabric 側の NL2SQL モデルを選ぶものではありません。REST による接続作成は主線にしません。接続作成時に権限不足なら、管理担当者が対象 project の `Microsoft.CognitiveServices/accounts/projects/connections/write` を照合します。

D18 では Foundry 組み込みの Fabric ツールを **APIM を通らない例外経路**として扱います。D14 の MCP／OpenAPI 用 APIM 経路・quota は維持します。

> **Note** 要確認（推測）: Agent Service → Fabric の送信であり Foundry 入口の IP 制限とは直接衝突しない見込みですが、Fabric 側のネットワーク制限・到達と実際の送信経路は実機で照合します。到達しない場合に既存の公開範囲や条件付きアクセスを緩めません。

## 7.4. 完了条件

- 統合サブネットの委任とサービス エンドポイントを確認した。
- App Service の統合先と Foundry／Cosmos DB の VNet 規則が一致した。
- アプリ MI のデータロールがアプリ専用コンテナーに限定され、アプリから書いた JSON が Cosmos の Data Explorer で見えた。
- Agent Service の `enterprise_memory`／コンテナーへアプリが書き込んでいないことを確認した。
- 社内ブラウザからログインし、既存エージェントを利用者本人の権限で呼び出せた。
- IP 制限された SCM を使って、固定版アプリを配布できた。
- ツールの許可主体が成功し、未認証・許可外主体が拒否された。
- ツール経路の APIM ログとアプリの本人経路の証跡を分けて記録した。
- quota・本文監査・未許可ツールの強制点の Pending 部分を明示した。

アプリは実装済みですが、本人トークンの取得・配布・到達・保存は初回実行で確認するまで未達として扱います。7.4 の完了条件を満たしてから第8章へ進みます。

Fabric 工程の完了条件は、容量割り当て・合成4行・公開版・許可／拒否の共有設定・Foundry 接続・指示文・アプリの参照版を照合したことです。C11 の本人 ID と Consumer／Foundry User の差は第8章で試験するため、この章の設定完了を Pass としません。未確定なら Fabric 工程の保留理由を残し、C11 を Pending とします。

## 7.5. うまくいかない場合

| 症状 | 切り分け | 制限内での対応 |
|---|---|---|
| `entry` | 本人ヘッダー、IDP、トークン ストア、委任スコープ、期限 | `expired` は更新後 1 回だけ再送。`no_token` が続けば管理者へ。ヘッダーやトークンを表示しない |
| `foundry_authn` | Foundry 401・audience・同意・期限（C03） | 工程 6 の設定と照合。MI で代用しない |
| `foundry_authz` | Foundry 403・本人の project スコープロール（C02） | ネットワーク規則も別途照合し、403 だけでロール不足と断定しない |
| `network` | 到達不能・タイムアウト・統合先・VNet 規則（C08） | IP 制限を維持して照合。タイムアウトを自動再送しない |
| `cosmos_authz` | Cosmos 401／403・MI のデータロールとスコープ（A14） | VNet 規則も照合。キー認証に切り替えない |
| `cosmos_network`／`cosmos_other` | Cosmos 到達・上流ステータス（A14） | 対象コンテナー・規則を確認し、本文や例外の生メッセージは記録しない |
| `csrf`／`input`／`duplicate` | 同一オリジン・入力長・相関 ID | 同梱画面から操作し、30 秒以内の同じ ID は再送しない |
| `foundry_notfound`／`foundry_other` | 対象名・URL・上流ステータス | 設定と初回応答形式を照合し、権限を広げて回避しない |
| 統合候補が表示されない | リージョン・サブネット空き・委任・操作権限 | 今回専用の設定と照合。他の実施者のサブネットは使わない |
| App Service → Foundry が 403 | 統合先・サービス エンドポイント・VNet 規則・カスタム サブドメイン・API の適用範囲 | 同じエージェントのエンドポイントを照合。ネットワークと RBAC を別々に確認 |
| アプリの Cosmos 保存が 403 | Cosmos の VNet 規則・サービス エンドポイント・App Service MI のデータロール・スコープ | キー認証や account 全体の権限へ切り替えず、アプリ専用コンテナーとの一致を確認 |
| ログイン後に 401／403 | トークンの宛先・期限・同意・本人のロール | トークンを表示せず設定を確認。MI への置換で回避しない |
| ツール用 APIM だけ拒否 | 親の ip-filter・許可主体・audience・バックエンド | 対象 API の有効なポリシーを確認。全体規則を一括解除しない |
| SCM へ接続できない | 配布元の送信 IP・SCM 規則・担当者の権限 | 承認済み社内経路を確認。Cloud Shell 用に規則を広げない |
| Linux に ZIP をドラッグできない | 使用している配布方式 | 非対応 UI を繰り返さず、工程 7 の社内 PC からの CLI 配布を確認 |
| 403／429 | 拒否した層・適用ポリシー・ログ | quota 未設定なら quota 超過とは判定しない |
| ログが 0 件 | 宛先・時間範囲・収集設定・閲覧権限 | 未到着は Pending。本文ログを追加して代替しない |

設定変更が必要なら対象と根拠を記録して設計を見直します。証跡には時刻・相関 ID・拒否層・秘密値を除いた変更点を残します。切り分けで変更した値は承認済みの値へ戻し、再確認します。IP 制限解除・リージョン全体許可・SKU 変更を復旧として実施しません。中止時の削除は第10章です。

### Fabric がうまくいかない場合

| 症状 | 切り分け | 次の対応 |
|---|---|---|
| `unauthorized` | Fabric ツール内のエラーか Foundry の RBAC 拒否かを照合 | Fabric 側ならデータエージェント READ・元データ Read・継承を確認。Foundry 側なら C11 の専用主体でロール比較 |
| `Cannot find the requested item` | 公開の有無・公開後の構成変更・対象テナント | 正しい公開版を確認して同じ接続先で再試行 |
| Artifact Id のエラー | URL の aiskills の GUID と入力値 | レイクハウスや workspace の GUID と取り違えていないか確認 |
| 応答はあるがツールが見えない | エージェントの版・指示・呼び出し記録 | 推測の応答を成功にせず C11 Pending |
| Fabric に到達しない | テナント設定・容量・リージョン・ネットワーク制限 | 管理担当者に照合を依頼し、IP 制限を緩めず Pending |

代替は正しい公開版・接続先・最小権限への修正に限定します。変更前後と結果を非公開で記録し、誤った共有・ロール変更は元の状態へ戻します。復旧できなければ停止します。通常の削除は第10章です。

## 7.6. 次の操作

7.4 の完了条件を満たしてから、第8章の本人権限・入口・ツールの比較試験へ進みます。現時点で必要なのは初回実行（工程 6〜7）の結果記録と、ツール仕様・登録手順（工程 8〜10）の確定と、Fabric の準備・接続（工程11〜14）です。工程 1〜7 だけを終えて第8章へ進む手順ではありません。第4章は G1〜G3 の根拠確認済みで、C08 の初回結果と Standard／Basic の分岐記録を引き継ぎます。第6章 C05 の保留は維持します。

## 7.7. 費用

Fabric 容量の費用は既存見積りに含まれません。事前確認済みの容量を使い、利用可否・費用負担・期間は課長判断とします。金額は要見積りです。

| Excel v3 明細 No | 項目 | 通常月 USD |
|---|---|---:|
| 11 | API Management / Basic v2 | 6.575360 |
| 13 | App Service / Linux B1 | 0.608000 |
| 未採番（明細追加予定） | VNet／サブネット／VNet 統合／従来型サービス エンドポイントの機能追加料金 | 0 |

既存 2 行は 2026-09-15 の見積り v3 の値です。Japan East、原則 32h/月の前提を維持し、SKU 変更・NAT Gateway 追加はしません。通信・ログ・サービス利用まで無料になる意味ではありません。Excel への資産明細追加は未実施です。No.6 は第1・6章の共通費で、監視リソースを二重作成しません。稼働時間・料金の保証ではありません。

## 7.8. 本番との差

本人経路もゲートウェイへ通す構成、ネットワーク分離、入口防御は [付録 B](92-appendix-production-diff.md) の本番設計で扱います。今回のツール quota を本番のモデル費用上限として扱いません。

### IaC で再現する (任意)

[07_gateway_app.bicep](../infra/modules/07_gateway_app.bicep) は D14 未対応の旧骨組みです。VNet・認可・配布の再現用にはまだ使えません。今回は Bicep を変更せず、展開スクリプトの固定停止点を維持します。

### 出典

- 出典: [レイクハウスの共有](https://learn.microsoft.com/en-us/fabric/data-engineering/lakehouse-sharing)（取得日 2026-09-24）

- 出典: [CSV のレイクハウス読み込み](https://learn.microsoft.com/en-us/fabric/data-engineering/get-started-csv-upload)（取得日 2026-09-24）

- 出典: [ワークスペースと容量割り当て](https://learn.microsoft.com/en-us/fabric/fundamentals/create-workspaces)（取得日 2026-09-24）

- 出典: [Fabric の公開と共有](https://learn.microsoft.com/en-us/fabric/data-science/data-agent-sharing)（取得日 2026-09-24）

- 出典: [Fabric データエージェントの作成](https://learn.microsoft.com/en-us/fabric/data-science/how-to-create-data-agent)（取得日 2026-09-24）

- 出典: [Foundry の Fabric ツール](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/tools/fabric)（取得日 2026-09-24）
- 出典: [Fabric から Foundry で利用する](https://learn.microsoft.com/en-us/fabric/data-science/data-agent-foundry)（取得日 2026-09-24）

- 出典: [App Service の環境変数と全般設定](https://learn.microsoft.com/en-us/azure/app-service/configure-common)（取得日 2026-09-20）

- 出典: [配布の基本認証を無効にする](https://learn.microsoft.com/en-us/azure/app-service/configure-basic-auth-disable)（取得日 2026-09-20）
- 出典: [Azure CLIの対話型サインイン](https://learn.microsoft.com/ja-jp/cli/azure/authenticate-azure-cli-interactively)（取得日 2026-09-16）
- 出典: [Cloud Shellの実行環境](https://learn.microsoft.com/en-us/azure/cloud-shell/overview)（取得日 2026-09-16）

- 出典: [仮想ネットワークの作成](https://learn.microsoft.com/en-us/azure/virtual-network/quickstart-create-virtual-network)（取得日 2026-09-20）
- 出典: [サブネットの設定](https://learn.microsoft.com/ja-jp/azure/virtual-network/virtual-network-manage-subnet)（取得日 2026-09-16）
- 出典: [VNet 統合の有効化](https://learn.microsoft.com/en-us/azure/app-service/configure-vnet-integration-enable)（取得日 2026-09-20）
- 出典: [Python アプリの作成](https://learn.microsoft.com/ja-jp/azure/app-service/quickstart-python)（取得日 2026-09-16）
- 出典: [ZIP配布のLinux制約](https://learn.microsoft.com/en-us/azure/app-service/deploy-zip)（取得日 2026-09-20）
- 出典: [Foundry SDKと既存エージェントの呼び出し](https://learn.microsoft.com/ja-jp/azure/foundry/quickstarts/get-started-code)（取得日 2026-09-16）
- 出典: [Foundry RBAC](https://learn.microsoft.com/ja-jp/azure/foundry/concepts/rbac-foundry)（取得日 2026-09-16）
- 出典: [quota-by-key](https://learn.microsoft.com/ja-jp/azure/api-management/quota-by-key-policy)（取得日 2026-09-16）
- 出典: [サービス エンドポイント](https://learn.microsoft.com/ja-jp/azure/virtual-network/virtual-network-service-endpoints-overview)（取得日 2026-09-16）
- 出典: [az network vnet subnet](https://learn.microsoft.com/en-us/cli/azure/network/vnet/subnet?view=azure-cli-latest)（取得日 2026-09-16）
- 出典: [az webapp](https://learn.microsoft.com/en-us/cli/azure/webapp?view=azure-cli-latest)（取得日 2026-09-16）
- 出典: [az cognitiveservices account network-rule](https://learn.microsoft.com/en-us/cli/azure/cognitiveservices/account/network-rule?view=azure-cli-latest)（取得日 2026-09-16）

- 出典: [APIM v2 レベル](https://learn.microsoft.com/ja-jp/azure/api-management/v2-service-tiers-overview)（取得日 2026-09-16）
- 出典: [APIM の IP アドレス](https://learn.microsoft.com/ja-jp/azure/api-management/api-management-howto-ip-addresses)（取得日 2026-09-16）
- 出典: [APIM の portal 作成](https://learn.microsoft.com/en-us/azure/api-management/get-started-create-service-instance)（取得日 2026-09-20）
- 出典: [APIM のポリシー設定](https://learn.microsoft.com/en-us/azure/api-management/set-edit-policies)（取得日 2026-09-20）
- 出典: [ip-filter](https://learn.microsoft.com/ja-jp/azure/api-management/ip-filter-policy)（取得日 2026-09-16）
- 出典: [App Service の送信 IP](https://learn.microsoft.com/ja-jp/azure/app-service/overview-inbound-outbound-ips)（取得日 2026-09-16）
- 出典: [App Service のアクセス制限](https://learn.microsoft.com/en-us/azure/app-service/app-service-ip-restrictions)（取得日 2026-09-20）
- 出典: [App Service の Entra 認証](https://learn.microsoft.com/en-us/azure/app-service/configure-authentication-provider-aad)（取得日 2026-09-20）
- 出典: [Easy Auth の OAuth トークン](https://learn.microsoft.com/en-us/azure/app-service/configure-authentication-oauth-tokens)（取得日 2026-09-20）
- 出典: [OBO フロー](https://learn.microsoft.com/ja-jp/entra/identity-platform/v2-oauth2-on-behalf-of-flow)（取得日 2026-09-16）
- 出典: [Entra トークン検証ポリシー](https://learn.microsoft.com/ja-jp/azure/api-management/validate-azure-ad-token-policy)（取得日 2026-09-16）
- 出典: [APIM の MI 認証](https://learn.microsoft.com/ja-jp/azure/api-management/authentication-managed-identity-policy)（取得日 2026-09-16）
- 出典: [トークン上限](https://learn.microsoft.com/ja-jp/azure/api-management/llm-token-limit-policy)（取得日 2026-09-16）
- 出典: [APIM の監視と診断](https://learn.microsoft.com/en-us/azure/api-management/api-management-howto-use-azure-monitor)（取得日 2026-09-20）
- 出典: [ApiManagementGatewayLogs の列](https://learn.microsoft.com/ja-jp/azure/azure-monitor/reference/tables/apimanagementgatewaylogs)（取得日 2026-09-16）
- 出典: [APIM の VNet 統合（Standard v2 / Premium v2）](https://learn.microsoft.com/ja-jp/azure/api-management/integrate-vnet-outbound)（取得日 2026-09-16）
- 出典: [APIM と Azure 仮想ネットワーク](https://learn.microsoft.com/ja-jp/azure/api-management/virtual-network-concepts)（取得日 2026-09-16）
- 出典: [App Service の VNet 統合](https://learn.microsoft.com/ja-jp/azure/app-service/overview-vnet-integration)（取得日 2026-09-16）
- 出典: [App Service の NAT ゲートウェイ統合](https://learn.microsoft.com/ja-jp/azure/app-service/overview-nat-gateway-integration)（取得日 2026-09-16）
- 出典: [Foundry Tools の仮想ネットワークを構成する](https://learn.microsoft.com/en-us/azure/ai-services/cognitive-services-virtual-networks)（取得日 2026-09-20）
- 出典: [MCP サーバー認証を設定する](https://learn.microsoft.com/ja-jp/azure/foundry/agents/how-to/mcp-authentication)（取得日 2026-09-16）
- 出典: [Azure IP Ranges and Service Tags – Public Cloud](https://www.microsoft.com/download/details.aspx?id=56519)（2026-09-14 版・取得日 2026-09-16）
- 出典: [Azure Retail Prices API](https://learn.microsoft.com/ja-jp/rest/api/cost-management/retail-prices/azure-retail-prices)（取得日 2026-09-16）

- 出典: [Cosmos DB の IP 規則とサービス エンドポイント](https://learn.microsoft.com/en-us/azure/cosmos-db/how-to-configure-firewall)（取得日 2026-09-19）
- 出典: [Cosmos DB の VNet 規則](https://learn.microsoft.com/en-us/azure/cosmos-db/how-to-configure-vnet-service-endpoint)（取得日 2026-09-20）
- 出典: [Cosmos DB のデータ面 RBAC](https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/how-to-connect-role-based-access-control)（取得日 2026-09-19）
- 出典: [Cosmos DB のコンテナー作成](https://learn.microsoft.com/en-us/azure/cosmos-db/quickstart-portal)（取得日 2026-09-20）
- 出典: [App Service のマネージド ID](https://learn.microsoft.com/en-us/azure/app-service/overview-managed-identity)（取得日 2026-09-20）

- 出典: [Cosmos DB データロール割当 CLI](https://learn.microsoft.com/en-us/cli/azure/cosmosdb/sql/role/assignment?view=azure-cli-latest)（取得日 2026-09-19）

- 出典: [Linux Python と Oryx](https://learn.microsoft.com/en-us/azure/app-service/configure-language-python)（取得日 2026-09-19）
- 出典: [Easy Auth トークンと更新](https://learn.microsoft.com/en-us/azure/app-service/configure-authentication-oauth-tokens)（取得日 2026-09-20）
- 出典: [Easy Auth ユーザー識別](https://learn.microsoft.com/en-us/azure/app-service/configure-authentication-user-identities)（取得日 2026-09-19）
- 出典: [Entra プロバイダー設定](https://learn.microsoft.com/en-us/azure/app-service/configure-authentication-provider-aad)（取得日 2026-09-20）
- 出典: [既存エージェント REST](https://learn.microsoft.com/en-us/azure/foundry/quickstarts/get-started-code)（取得日 2026-09-19）
- 出典: [ZIP 配布](https://learn.microsoft.com/en-us/azure/app-service/deploy-zip)（取得日 2026-09-20）
- 出典: [Cosmos Entra 認証](https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/how-to-connect-role-based-access-control)（取得日 2026-09-19）
- 出典: [authsettingsV2 REST](https://learn.microsoft.com/en-us/rest/api/appservice/web-apps/update-auth-settings-v-2?view=rest-appservice-2024-11-01)（取得日 2026-09-20）

---

前へ: [監視と監査を設定する](06-monitoring.md) / 次へ: [権限・認証・ネットワークの統制を試す](08-governance-tests.md) / [トップに戻る](../README.md)
