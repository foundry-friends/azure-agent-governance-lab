# 7. ゲートウェイと呼び出しアプリを用意する

進め方: README の第0〜10章を順番に実施します。第6章 6.6 の進行条件を満たしてから進めます。本文監査など明示した Pending は記録を引き継ぎます。

> **Note** 状態: ドラフト（Learn 2026-09 時点の記述に基づく・未実行）。取得日 2026-09-16。サービス間通信は 7.2 の案 C（2026-09-16 決定）で進めます。案 C のGUI操作ドラフトとアプリ仕様を作成済みです。社内PCからのCLI配布は暫定採用済みです。本人の委任認証・配布の実機成立・APIへのVNet規則の適用が未確定で、現時点では作成前に停止します。

> **補足** この章では環境を削除しません。通常の削除は最後の第10章です。中断して片付ける場合だけ、第10章へ進みます。

## 7.1. 目的

同じエージェントを利用者本人の権限で呼び出すブラウザ用アプリと、ツール経路用の APIM を用意します。本人の経路は App Service から Foundry を直接呼び、APIM は Agent Service からのツール呼び出しを通す入口にします。利用者本人の権限で試せる入口ができてから、次の章で統制試験をします。

### なぜこの作業が必要か

開発用の画面で応答を確認するだけでは、呼び出し専用ユーザーが実際に利用する経路の統制を試せません。利用者がブラウザからエージェントを呼び出し、その本人の権限が反映される経路を用意する必要があります。

この章では、呼び出しアプリを利用者の入口として用意し、APIM を通す対象と許可する呼び出し先を整理します。アプリへのサインインと、その利用者が Foundry で操作できるかを区別して確認するための準備です。本人トークンの経路が確定してから、第8章でユーザーや接続元を変える試験に使います。

## 7.2. 前提と作成前の停止条件

第4章の接続条件を解決し、同じエージェントの応答、第5章の権限設定、第6章の通常診断の設定を確認済みであることを前提とします。第6章で保留した本文監査は保留のまま引き継ぎます。

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
| 統合サブネット | App Service 専用。portal 作成時は /27 以上。委任 `Microsoft.Web/serverFarms`。サービス エンドポイント `Microsoft.CognitiveServices` を有効化 |
| App Service | Linux B1 のまま。[ネットワーク] の [送信トラフィックの構成] で上記サブネットに VNet 統合。[送信インターネット トラフィック] は既定のまま（サービス エンドポイント宛は既定で VNet 経由） |
| Foundry | [ネットワーク] の既定拒否＋社内 IP 規則に加え、[既存の仮想ネットワークを追加] で統合サブネットを VNet 規則に登録 |
| 本人の経路 | 社内ブラウザ → App Service（社内 IP のアクセス制限）→ Foundry（VNet 規則）。APIM を通さない |
| ツールの経路 | Agent Service → APIM Basic v2 → 許可した呼び出し先。APIM は `validate-azure-ad-token` で発行元 ID を検証し、IP 規則は社内ブラウザからの直接試験用に限る |
| 追加費用 | 仮想ネットワーク・サブネット・VNet 統合・サービス エンドポイントは追加料金なし。NAT ゲートウェイは使わない |

> **Note** 要確認: Foundry の VNet 規則がプロジェクト エンドポイントの API 呼び出しにも適用されるかを Learn で確認できていません。初回実行で確認し、通らなければ停止条件へ戻します。

> **補足** D14 の APIM はツール API を保護します。ネットワーク上は公開する一方、対象テナント・audience・許可されたサービス主体を検証します。社内ブラウザ用の `ip-filter` を全 API に設定すると Agent Service も拒否されるため、直接試験用の別 API／操作に限定します。

> **補足** ツール API の呼び出し回数等の quota と、LLM のトークン quota は別です。本人経路と内部モデル呼び出しは APIM を通らないため、そのトークン量を C09 のツール試験で検証したとは扱いません。具体的な quota・集計単位・許可主体はアプリ／ツール仕様の確定時に決めます。

### 開始・再開チェックリスト

第4章の G1〜G3（接続・通信・認証の停止条件）とは別に、この章の開始条件を確認します。

- [ ] 第4章の停止条件を解決し、エージェントの初回応答を確認している。
- [ ] 案 C の仮想ネットワーク・統合サブネット・サービス エンドポイント・Foundry の VNet 規則が、承認された IP 許可方針と両立する根拠を記録している。
- [ ] Foundry が利用者本人を認可するトークン経路を確定している。
- [ ] 呼び出しアプリのソース、固定した配布版、ランタイム、設定項目、GUI デプロイ手順がリポジトリに揃っている。
- [ ] Entra のアプリ登録と必要な同意を実施できる担当者を確認している。RG の Owner 権限だけでテナント内の操作ができるとは判断しない。
- [ ] APIM と App Service の費用、リージョン、削除予定を確認している。

> **Note** 要確認: サービス間の IP 方針は案 C で確定しましたが、7.3 は案 C の操作ドラフトです。配布は社内PCのCLIを暫定採用し、委任認証と配布の実機成立は未確定で、アプリは仕様レビュー前・未実装です。チェックが揃うまで、以下の作成操作を開始しません。構成を変える場合は、その判断を反映した手順を先に確定します。IP 制限を外すことや SKU を変えることを復旧操作として実施しません。案 B・E は SKU の変更、案 A・D は許可範囲の変更を伴うため、承認前に実施しません。

## 7.3. 操作（開始条件の解決後）

以下は案 C の操作ドラフトです。7.2 のチェックが揃ってから実施します。認証・配布の未確定部分を飛ばして作成を開始しません。工程6の配布限定例外を除き、確認コマンドは Cloud Shell の Bash で実行し、山括弧の値を今回のリソースに置き換えます。実値と出力は非公開の証跡だけに保存します。

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
| サービス エンドポイント | `Microsoft.CognitiveServices` |
| タグ | 第1章と同じ管理用タグ |

7. [IP アドレス] で承認されたアドレス空間を設定します。
8. 統合用サブネットを設定します。
9. [セキュリティ] で Bastion・Firewall 等の対象外の追加サービスを有効にしていないことを確認します。
10. [タグ] を入力します。
11. [確認および作成] で設定を照合します。
12. [作成] を選択します。
13. 作成した VNet の [設定] → [サブネット] を開きます。
14. 統合用サブネットを選択します。
15. [サブネットをサービスに委任] で `Microsoft.Web/serverFarms` を選択します。
16. [サービス エンドポイント] で `Microsoft.CognitiveServices` を選択します。
17. [保存] を選択します。

> **画面の見え方** 作成ウィザードに委任やサービス エンドポイントの選択がない場合は、作成後のサブネット編集で設定します。統合用サブネットに VM や他サービスを配置しません。App Service の統合は送信専用で、社内PCをこの VNet に接続する操作ではありません。

```bash
az network vnet subnet show --resource-group '<専用RG名>' --vnet-name '<今回のVNet名>' --name '<統合サブネット名>' --query '{id:id,prefix:addressPrefix,delegations:delegations[].serviceName,endpoints:serviceEndpoints[].service}' --output json
```
実行結果の確認ポイント: 専用サブネットの範囲、`Microsoft.Web/serverFarms`、`Microsoft.CognitiveServices` が一致することを確認します。

### 2. App Service を作り、入口を制限する

アプリ仕様のレビューと配布方式の確定後に行います。[同梱アプリ仕様](../assets/app/README.md) に書く配布版と同じ Python ランタイムを使います。

1. Azure portal の [App Services] を開きます。
2. [作成] → [Web アプリ] を選択します。
3. [基本] に下表の値を入力します。

| 項目 | 値 |
|---|---|
| リソース グループ | 今回の専用 RG |
| 名前 | `<今回のアプリ名>` |
| 公開 | コード |
| ランタイム スタック | Python。配布版で検証したバージョンに固定（未確定） |
| オペレーティング システム | Linux |
| 地域 | Japan East |
| App Service プラン | 今回専用に作成。Linux B1 |
| デプロイ | この時点ではソース連携・コード配置を行わない |
| 監視 | 既存の監視資産を利用。追加作成の既定値を確認 |

4. [確認および作成] で Linux B1 と対象 RG を照合します。
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

10. [ルールの追加] を選択します。
11. [保存] を選択します。
12. SCM サイトで [メイン サイトルールを使用する] を選択します。
13. [保存] を選択します。
14. アプリの設定で HTTPS のみ・TLS 1.2 以上・FTP 無効を照合します。

> **画面の見え方** メインサイトと SCM（配布・高度なツール用サイト）は別々の入口です。VNet 統合ではこれらの受信制限は設定されません。空のアプリを作成した後、コード・資格情報を配置する前に入口を制限します。作成時から拒否を要求する組織では、この作成後設定の手順を実行せず、作成時設定の方法を先に確定します。

> **Note** 要確認: Python の固定バージョン・起動設定は配布版の検証後に確定します。HTTPS／TLS／FTP の設定画面の位置も初回に照合します。空の Web アプリの作成をアプリ配布の完了とは扱いません。

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
| 統合先 | 工程1の専用サブネット |
| 全送信トラフィックの VNet ルーティング | 有効化しない。サービス エンドポイント宛のルーティングを利用 |
| NAT Gateway | 追加しない |
| DNS | このラボでは独自 DNS を追加しない |

> **画面の見え方** 統合時にはアプリが再起動します。既存接続が候補に表示されても、他の実施者のサブネットを選びません。Learn の日本語ページには一部英語のラベルが残るため、[Networking]／[Virtual network integration] と表示される場合があります。

```bash
az webapp show --resource-group '<専用RG名>' --name '<今回のアプリ名>' --query virtualNetworkSubnetId --output tsv
```
実行結果の確認ポイント: 工程1で確認したサブネット ID と一致し、空欄でないことを確認します。

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

### 5. サインインと本人トークンの設定を詰める

次の設定は入口の認証です。下流トークンの方式が確定してから、アプリ仕様と合わせて保存します。

1. アプリの [設定] → [認証] を開きます。
2. [ID プロバイダーの追加] を選択します。
3. [Microsoft] を選択します。
4. 現在の従業員テナントを選択します。
5. 今回専用のアプリ登録を選択します。
6. 下表の値を照合します。
7. [追加] を選択します。

| 項目 | 値 |
|---|---|
| アカウントの種類 | シングルテナント |
| アクセス | 認証を要求 |
| 未認証の要求 | ブラウザ入口はサインインへ誘導。アプリ API の応答は実装仕様で確定 |
| アプリ資格情報 | 保護された設定で管理。ソース・ZIP・証跡に含めない |
| トークン ストア | Easy Auth からプロバイダートークンを受け取る方式で必要。採用時に設定を確認 |

> **画面の見え方** Easy Auth のサインイン成功は、Foundry が受け付ける本人アクセストークンを取得できた証拠ではありません。`X-MS-TOKEN-AAD-ACCESS-TOKEN` の存在だけでも宛先は保証されません。`/.auth/me` の出力やヘッダーを証跡に貼り付けません。

| 確認対象 | 今回裏付けられたこと | まだ確定しないこと |
|---|---|---|
| Foundry 用スコープ | 公式 SDK クイックスタートに `https://ai.azure.com/.default` の例がある | カスタムアプリの委任権限の選択、同意、Easy Auth のログイン設定との組み合わせ |
| 呼び出す API | 同じ資料に既存エージェント専用の Responses 経路がある | 第4章で作成するエージェントとの世代・API・GA の適合性 |
| 本人の権限 | 第5章の Consumer／User／無権限主体を継続使用 | ロールの名前だけで全操作の成否を断定しない |
| OBO | 中間 API 宛の本人アクセストークンを下流用へ交換する方式 | Easy Auth から Foundry 用トークンを直接得る方式で足りるか、OBO が必要か |

> **Note** 要確認: 委任権限・同意・実トークンの audience と scope／claim・期限切れ時の扱いを確定するまで、認証設定を完成例として扱いません。`.default` の文字列だけでは本人の委任権限の取得は証明できません。OBO には中間 API 自身を audience とするアクセストークンが必要で、Graph 用トークンや ID トークンでは代用しません。APIM／App Service の MI に置き換えて C02 を成功扱いにしません。API Playground の Preview 操作は対象外です。

### 6. 同梱アプリの仕様と配布経路を確定する

[アプリ仕様](../assets/app/README.md) はレビュー用です。現時点ではアプリコード・配布 ZIP はありません。

| 同梱するもの | 配布前に揃える内容 |
|---|---|
| 最小画面 | サインイン状態、合成入力、送信、応答、相関 ID、失敗した層 |
| ソースと固定版 | Python／FastAPI、固定依存関係、起動設定、配布版とハッシュ |
| 認証 | 利用者本人の下流トークン。期限切れ・同意不足は停止し再認証を案内 |
| 設定 | 固定の Foundry エンドポイントと対象エージェント。任意 URL を入力させない |
| 秘密値の扱い | トークン・Cookie・ヘッダー・本文をアプリログへ出さない |
| 配布 | Linux B1・SCM 社内 IP 制限を維持できる方法 |

**計画にあったブラウザからの ZIP ドラッグ配布は掲載しません。** Learn「ファイルの展開」は Kudu の ZIP デプロイ UI が App Service on Linux で動作しないと明記しています。Python のために Windows へ切り替えることもしません。

| 方法 | 本ラボでの判断 |
|---|---|
| Kudu の ZIP デプロイ UI | Linux では使用不可 |
| Cloud Shell から ZIP 配布 | SCM の社内 IP 制限と両立するとは扱わない |
| 社内 PC から Azure CLI で ZIP 配布 | 暫定採用（2026-09-16）。配布とその認証・対象確認だけをローカルで実施し、実機検証で再評価 |
| 外部 CI・FTP | 自動採用しない。SCM の制限解除・FTP 有効化を回避策にしない |

#### なぜ配布時だけ社内 PC を使うのか

通常は、設定を理解しながら作業できる Azure portal を主線とし、コマンドはインストール不要の Cloud Shell で実行します。ただし、今回のアプリ配布では次の制約が重なります。

1. Python アプリの配置先は Linux B1 です。Linux では Kudu の ZIP デプロイ UI が使えないため、ブラウザで ZIP をドラッグする手順を採用できません。
2. ZIP 配布先の SCM は、メインサイトと同じ社内 IP 許可リストで保護します。Cloud Shell はブラウザを表示している社内 PC ではなく Azure 側で動くため、社内 PC の送信元 IP を引き継ぎません。
3. このため、SCM の制限を維持したまま ZIP を送る経路として、承認済み社内ネットワーク上の PC から Azure CLI を実行します。社内 PC でもプロキシや接続経路によって送信元が異なる場合は、許可された送信元であることを確認します。

> **補足** 2026-09-16 に、**アプリの ZIP 配布と、そのためのローカル認証・対象確認だけ**を社内 PC の Azure CLI で行う例外を暫定採用しました。リソース作成や通常の設定変更までローカル CLI に移す方針ではありません。SCM の IP 制限、Entra 認証、FTP 無効を維持し、実機検証時にこの配布方法の到達性・権限・端末要件を再評価します。方針の承認は、配布成功を確認したという意味ではありません。

#### 社内 PC から固定版 ZIP を配布する（配布物の完成後）

この節だけは **Cloud Shell ではなく社内 PC の Bash** で実行します。組織で承認された Azure CLI と Bash を用意し、端末への導入方法は社内ルールに従います。アプリ仕様・固定版 ZIP・依存関係のビルド方法・起動設定が揃うまでは実行しません。

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
実行結果の確認ポイント: ブラウザで対象の個人アカウント・MFAを確認し、サインインが完了することを確認します。既存の条件付きアクセスは変更しません。

7. 配布対象のサブスクリプションを確認します。

```bash
az account show --subscription '<対象サブスクリプションID>' --query '{subscription:id,tenant:tenantId,name:name}' --output json
```
実行結果の確認ポイント: 非公開の記録とテナント・サブスクリプションが一致することを確認します。

8. 固定版 ZIP を、作成済みの今回のアプリへ配布します。

```bash
az webapp deploy --subscription '<対象サブスクリプションID>' --resource-group '<専用RG名>' --name '<今回のアプリ名>' --src-path '<固定版ZIPのローカルパス>' --type zip
```
実行結果の確認ポイント: 対象アプリと配布結果を確認し、配布後の起動・社内ブラウザでの本人認証・エージェント応答を別々に確認します。ZIP送信成功だけで7.4を完了にしません。

> **画面の見え方** 基本認証が無効な場合、対応する Azure CLI は Entra 認証で配布します。発行プロファイルやパスワードをダウンロードして回避しません。CLIの認証は配布担当者用で、アプリ利用者のFoundry用トークンとは別です。

> **Note** 要確認: 方針は暫定採用済みですが、実機での SCM 到達・配布権限・ビルド・起動は未検証です。403の場合は送信元IPと配布権限を分けて確認し、SCMを全公開にせず停止します。固定版 ZIP と起動設定が完成した段階で、この操作案を検証します。

### 7. ツール経路用の APIM Basic v2 を作る

ツールの URL・プロトコル・認証・許可操作を確定してから行います。本人の呼び出し先として APIM を設定しません。

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

### 8. ツール API の認証・許可先・quota を設定する

1. APIM の [API] で対象のツール API を開きます。
2. [デザイン] の [受信処理] でポリシーのコード エディターを開きます。
3. 下表に従い、確定済みの入力値でトークン検証と quota を設定します。
4. [保存] を選択します。
5. [有効なポリシーの計算] で親から継承された規則を確認します。

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

### 9. ツール経路の診断を追加する

1. APIM の [監視] → [診断設定] を開きます。
2. [診断設定を追加する] を選択します。
3. 下表の宛先を設定します。
4. [保存] を選択します。
5. [API] → [すべての API] → [設定] の [診断ログ] で [Azure Monitor] の設定を開きます。
6. 要求・応答本文と認証ヘッダーが収集対象でないことを確認します。
7. 個別 API の上書きを確認します。

| 項目 | 値 |
|---|---|
| 診断設定名 | `gateway-to-law` |
| ログ | ゲートウェイログ。表示カテゴリを照合 |
| 宛先 | 第1章の既存 Log Analytics |
| テーブル | リソース固有の `ApiManagementGatewayLogs` |
| 保持・閲覧 | 第6章の30日・閲覧権限と照合 |

> **画面の見え方** APIM リソースの [ログ] を開き、今回の APIM をスコープにします。ワークスペース全体のログと混同しません。アプリの本人経路は APIM に現れないため、アプリ側の相関 ID と Foundry の結果を別に記録します。

ツールを実装して合成入力を送信した後に、次を照会します。

```kusto
ApiManagementGatewayLogs
| where TimeGenerated > ago(30m)
| project TimeGenerated, CorrelationId, ApiId, OperationId, ResponseCode, BackendResponseCode
| order by TimeGenerated desc
| take 20
```
実行結果の確認ポイント: ツールの試験時刻・API・相関 ID・受信とバックエンドの応答を照合し、本人の Foundry 呼び出しの証拠と混同しません。

ログ到着の遅延やテーブル未作成を、拒否試験の成功としません。アプリの診断は仕様に従い、本文・トークンを除く相関 ID・成否・処理時間を対象にします。第6章の本文監査の保留を APIM の本文ログで代替しません。

## 7.4. 完了条件

- 統合サブネットの委任とサービス エンドポイントを確認した。
- App Service の統合先と Foundry の VNet 規則が一致した。
- 社内ブラウザからログインし、既存エージェントを利用者本人の権限で呼び出せた。
- IP 制限された SCM を使って、固定版アプリを配布できた。
- ツールの許可主体が成功し、未認証・許可外主体が拒否された。
- ツール経路の APIM ログとアプリの本人経路の証跡を分けて記録した。
- quota・本文監査・未許可ツールの強制点の Pending 部分を明示した。

現在は未達です。設定確認だけでは到達・本人認可・配布の成立を証明できません。完成したように扱って第8章へ進みません。

## 7.5. うまくいかない場合

| 症状 | 切り分け | 制限内での対応 |
|---|---|---|
| 統合候補が表示されない | リージョン・サブネット空き・委任・操作権限 | 今回専用の設定と照合。他の実施者のサブネットは使わない |
| App Service → Foundry が403 | 統合先・サービス エンドポイント・VNet 規則・カスタム サブドメイン・API の適用範囲 | 同じエージェントのエンドポイントを照合。ネットワークとRBACを別々に確認 |
| ログイン後に401／403 | トークンの宛先・期限・同意・本人のロール | トークンを表示せず設定を確認。MIへの置換で回避しない |
| ツール用 APIM だけ拒否 | 親の ip-filter・許可主体・audience・バックエンド | 対象 API の有効なポリシーを確認。全体規則を一括解除しない |
| SCM へ接続できない | 配布元の送信 IP・SCM 規則・担当者の権限 | 承認済み社内経路を確認。Cloud Shell 用に規則を広げない |
| Linux に ZIP をドラッグできない | 使用している配布方式 | 非対応UIを繰り返さず、工程6の社内PCからのCLI配布を確認 |
| 403／429 | 拒否した層・適用ポリシー・ログ | quota未設定ならquota超過とは判定しない |
| ログが0件 | 宛先・時間範囲・収集設定・閲覧権限 | 未到着はPending。本文ログを追加して代替しない |

設定変更が必要なら対象と根拠を記録して設計を見直します。証跡には時刻・相関 ID・拒否層・秘密値を除いた変更点を残します。切り分けで変更した値は承認済みの値へ戻し、再確認します。IP 制限解除・リージョン全体許可・SKU変更を復旧として実施しません。中止時の削除は第10章です。

## 7.6. 次の操作

7.4 の完了条件を満たしてから、第8章の本人権限・入口・ツールの比較試験へ進みます。現時点の次工程は、[アプリ仕様](../assets/app/README.md) のレビュー、本人トークンの方式の確定、アプリの実装、暫定採用した社内PCからのCLI配布の実機検証です。第4章 G1〜G3 と第6章 C05 の保留も維持します。

## 7.7. 費用

| Excel v3 明細 No | 項目 | 通常月 USD |
|---|---|---:|
| 11 | API Management / Basic v2 | 6.575360 |
| 13 | App Service / Linux B1 | 0.608000 |
| 未採番（明細追加予定） | VNet／サブネット／VNet 統合／従来型サービス エンドポイントの機能追加料金 | 0 |

既存2行は2026-09-15の見積り v3 の値です。Japan East、原則32h/月の前提を維持し、SKU変更・NAT Gateway追加はしません。通信・ログ・サービス利用まで無料になる意味ではありません。Excelへの資産明細追加は未実施です。No.6は第1・6章の共通費で、監視リソースを二重作成しません。稼働時間・料金の保証ではありません。

## 7.8. 本番との差

本人経路もゲートウェイへ通す構成、ネットワーク分離、入口防御は [付録 B](92-appendix-production-diff.md) の本番設計で扱います。今回のツール quota を本番のモデル費用上限と扱いません。

### IaC で再現する (任意)

[07_gateway_app.bicep](../infra/modules/07_gateway_app.bicep) は D14 未対応の旧骨組みです。VNet・認可・配布の再現用にはまだ使えません。今回 Bicep は変更せず、展開スクリプトの固定停止点を維持します。

### 出典

- 出典: [配布の基本認証を無効にする](https://learn.microsoft.com/ja-jp/azure/app-service/configure-basic-auth-disable)（取得日 2026-09-16）
- 出典: [Azure CLIの対話型サインイン](https://learn.microsoft.com/ja-jp/cli/azure/authenticate-azure-cli-interactively)（取得日 2026-09-16）
- 出典: [Cloud Shellの実行環境](https://learn.microsoft.com/en-us/azure/cloud-shell/overview)（取得日 2026-09-16）

- 出典: [仮想ネットワークの作成](https://learn.microsoft.com/ja-jp/azure/virtual-network/quickstart-create-virtual-network)（取得日 2026-09-16）
- 出典: [サブネットの設定](https://learn.microsoft.com/ja-jp/azure/virtual-network/virtual-network-manage-subnet)（取得日 2026-09-16）
- 出典: [VNet 統合の有効化](https://learn.microsoft.com/ja-jp/azure/app-service/configure-vnet-integration-enable)（取得日 2026-09-16）
- 出典: [Python アプリの作成](https://learn.microsoft.com/ja-jp/azure/app-service/quickstart-python)（取得日 2026-09-16）
- 出典: [ZIP配布のLinux制約](https://learn.microsoft.com/ja-jp/azure/app-service/deploy-zip)（取得日 2026-09-16）
- 出典: [Foundry SDKと既存エージェントの呼び出し](https://learn.microsoft.com/ja-jp/azure/foundry/quickstarts/get-started-code)（取得日 2026-09-16）
- 出典: [Foundry RBAC](https://learn.microsoft.com/ja-jp/azure/foundry/concepts/rbac-foundry)（取得日 2026-09-16）
- 出典: [quota-by-key](https://learn.microsoft.com/ja-jp/azure/api-management/quota-by-key-policy)（取得日 2026-09-16）
- 出典: [サービス エンドポイント](https://learn.microsoft.com/ja-jp/azure/virtual-network/virtual-network-service-endpoints-overview)（取得日 2026-09-16）
- 出典: [az network vnet subnet](https://learn.microsoft.com/en-us/cli/azure/network/vnet/subnet?view=azure-cli-latest)（取得日 2026-09-16）
- 出典: [az webapp](https://learn.microsoft.com/en-us/cli/azure/webapp?view=azure-cli-latest)（取得日 2026-09-16）
- 出典: [az cognitiveservices account network-rule](https://learn.microsoft.com/en-us/cli/azure/cognitiveservices/account/network-rule?view=azure-cli-latest)（取得日 2026-09-16）

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
