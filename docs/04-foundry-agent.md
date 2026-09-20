# 4. Foundry とエージェントを作る

進め方: README の第0〜10章を順番に実施します。第3章の完了条件を満たしてから進めます。

> **Note** 状態: ドラフト（Learn 2026-09 時点の記述に基づく・未実行）。G1〜G3 の根拠確認済み・C08 の到達は初回実行で確認。更新日 2026-09-20。

> **Note** Preview: Azure Cosmos DB 接続は 2026-09 時点で Preview（SLA なし・本番非推奨）。本手順では NoSQL に触れる体験を優先して採用します（AGENTS.md「Preview は載せない」の唯一の例外）。

> **補足** この章では環境を削除しません。通常の削除は最後の第10章です。中断して片付ける場合だけ、第10章へ進みます。

## 4.1. 目的

作成済みのデータ基盤に接続する Foundry account／project と prompt agent を作り、最初の応答を確認します。

### なぜこの作業が必要か

後の章で統制の効果を比較するには、まず正常に応答するエージェントが必要です。動作を確認する前に設定を増やすと、応答しない原因がモデル・データ接続・権限・ネットワークのどこにあるか切り分けにくくなります。

この章では、作成済みのデータ基盤と Foundry を接続し、最初の応答を比較の基準として記録します。初期の認証と IP 制限を保った状態で動くことを目指し、その後に利用者別の権限、監査、呼び出しアプリを加えていきます。主線は Standard setup です。設定根拠と実機の到達を分け、C08 の初回実行で成立しなかった場合だけ Basic setup へ切り替えます。

### 作業前に知っておくこと：Standard setup と Basic setup

Setup は、Foundry Agent Service でエージェントを動かすための**環境構成方式**です。特に、会話履歴・アップロードしたファイル・検索用のベクトルデータを「どこに保存し、誰が保存先を管理するか」が異なります。どちらも Foundry account／project とモデルを使ってエージェントを動かします。

**Basic setup** は Microsoft が管理する保存先を利用する方式です。エージェント用の保存基盤を自分たちで用意する作業を減らせます。**Standard setup** は、自分たちの Azure リソースを保存先として接続する方式です。このように自分たちのリソースを持ち込むことを **BYO（Bring Your Own）** と呼びます。

| 比較する点 | Basic setup | Standard setup（本ラボの主線） |
|---|---|---|
| 保存先の管理主体 | Microsoft が管理する保存先を利用 | 自分たちの Azure リソースを接続・管理 |
| 会話履歴・エージェントの状態 | サービス側の保存先 | 自分たちの Azure Cosmos DB |
| アップロードしたファイル | サービス側の保存先 | 自分たちの Azure Storage |
| 検索用のベクトルデータ | サービス側の保存先 | 自分たちの Azure AI Search |
| 作業前に用意する保存基盤 | 上記3リソースをエージェントの保存先として用意する必要はない | 上記3リソースと、Foundry から利用する接続・権限が必要。本ラボは第3章のリソースを再利用 |
| 自分たちで設定・確認する範囲 | Foundry のアクセス権やエージェント設定など。サービス側の保存基盤を直接設定する作業はない | 左記に加え、保存先のアクセス権・ネットワーク制限・ログなどを設定・確認 |
| 構築・運用の手間 | 保存基盤の準備が少なく、動作確認を始めやすい | 保存基盤と接続の管理が増えるが、データの保存先を自分たちで統制できる |
| このラボでの位置づけ | 承認済み設定でも Standard の到達が成立しないと分かった場合の代替 | データの保存先・認証・通信・監査を自分たちで設定し、統制を学ぶために採用 |

Storage は「ファイル」、Cosmos DB は「会話や状態」、AI Search は「検索用データ」を受け持ちます。**第3章で作った3リソースを、本章でエージェントの保存基盤として結び付ける**のが Standard setup の作業です。Basic に分岐した場合、この3リソースを使った統制の検証は同じ形では行えないため、Standard の成功として記録しません。

> **補足** Standard setup のネットワーク構成には公開ネットワークを使う方式と、専用の仮想ネットワークを持ち込む方式があります。本ラボは前者を前提に、社内 IP とリソースごとの許可設定で通信を制限します。「公開ネットワーク」は全 IP の接続を許可する意味ではありません。後者の閉域構成は本ラボの対象外です。今回の制限下でサービス間通信が成立するかは C08 で確認します。

Basic への切り替えは、4.5 の切り分けと分岐手順に従います。単なる設定待ちやログ未到着で切り替えず、既存環境の保存先をその場で変更する操作とも考えません。

この比較は [環境構成方式の公式比較](https://learn.microsoft.com/en-us/azure/foundry/agents/environment-setup) と [Standard setup のリソース別の役割](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/standard-agent-setup) に基づきます。本ラボでの採用理由・分岐条件は、この手順書の方針です。

## 4.2. 前提

第3章の Storage・Cosmos DB・AI Search の ARM ID、認証設定、社内公開 IP の許可リストを非公開の記録で確認します。構築担当には Foundry account/project の作成権限と、接続用ロールを割り当てる権限が必要です。利用担当の Foundry User と、構築担当の管理権限を混同しません。

| 手元に用意する情報 | 確認元 |
|---|---|
| 検証用サブスクリプション ID・専用 RG・社内 CIDR | 第1章の `.env` と非公開の作業メモ |
| Storage・Cosmos DB・AI Search の名前と ARM ID | 第3章で保存した3つの ID |
| Log Analytics ワークスペース（LAW）の名前と ARM ID | 第1章。応答試験前の診断設定の宛先 |
| Foundry account 名 | 今回用の未使用の名前。以下の `<account>` をこの名前へ置換 |
| 初期 project 名と MI の principal ID | 作成後に工程2で確認。作成前に推測して記入しない |

> **画面の見え方** Azure portal（`portal.azure.com`）はリソースの作成・ネットワーク・IAM、Microsoft Foundry（`ai.azure.com`）は接続・モデル・エージェントに使います。別タブで開き、画面を切り替えるたびに対象 account／project を確認します。Bash と PowerShell の変数・選択サブスクリプションは共有される前提にしません。

### 作成前に確認した根拠

G1〜G3 は従来の停止条件の管理番号です。2026-09-19 の判断 A10〜A13（D15）により、次の根拠を確認して作成へ進みます。実機の到達を確認済みとする番号ではありません。

| 条件 | 判断 | 確認できたこと（2026-09-19・Learn） |
|---|---|---|
| G1: Cosmos DB 接続の提供範囲 | Cosmos 接続だけ Preview を承認（A10） | 接続一覧は Preview・接続作成はコードのみとしています。一方、Azure portal の Foundry 作成ウィザード [Storage] > [Agent service] > [Select Resources] で3リソースを束ねる Standard setup の GUI 手順があります（Learn 2026-07-09）。Foundry portal から Cosmos 接続を後付けする手順とは別です |
| G2: サービス間の通信経路 | 設定根拠を確認・成立見込み（A11） | 比較表に Standard Setup with Public Networking があります。第3章の Search 信頼サービス例外、Storage の Foundry リソース インスタンス規則、Cosmos の `0.0.0.0` と MI の権限で到達を試します |
| G3: 作成時の認証 | GUI と限定した Cloud Shell を併用（A12・A13） | Cosmos は作成時、Storage は項目があれば作成時／無ければ直後、Search は作成直後の GUI でキー無効。Foundry account はウィザード作成直後に Cloud Shell（PowerShell）で無効化します |

> **Note** 「IP 制限付き BYO で公開 Standard setup が動く」と明言する Learn の文はありません。G2 は設定の根拠を確認した段階で、到達は本章 C08 の初回実行で確定します。D14 の App Service 送信 VNet 統合では Agent Service 自体の送信経路は変わりません。

Standard setup は3リソース同時 BYO が必須です。[ネットワーク構成資料のエラー説明](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/virtual-networks)は “You can't create a secured standard agent in Foundry without all three resources provided.” としています。Cosmos だけを外す構成は採用しません。

| リソース | GUI でのキー無効化 | Cloud Shell の扱い |
|---|---|---|
| Cosmos DB | 現行の第3章は portal テンプレート編集で作成時にキー無効を指定 | 第3章の設定を照合。通常ウィザードの作成時ネットワーク設定は保留 |
| Storage | ウィザードに項目があれば無効。無ければ作成直後 [設定] > [構成] | Cloud Shell 用 Storage は別に維持。B18 はウィザードの項目有無の初回照合 |
| Search | 作成直後 [設定] > [キー] > [ロールベースのアクセス制御] | GUI が使えない場合だけ第3章の代替 |
| Foundry account | 作成ウィザードにキー無効化の項目なし | 作成直後 `Set-AzCognitiveServicesAccount -DisableLocalAuth $true`。401 確認後にモデル配置 |

Learn の手動作成順は「基盤 → account・project・接続 → 管理ロール → account／project の capability host → データロール → 開発者の権限」です。本章はウィザードが束ねた範囲を照合し、A13 の無効化をモデル配置より前に置きます。モデルの配置順だけは Learn の手動手順をそのまま流用しません。

### 作業開始・再開前のチェックリスト

- [ ] G1: Cosmos 接続の Preview 例外と、Standard setup の作成ウィザードの根拠を読んだ。
- [ ] G2: 第3章のリソース別設定と、到達を C08 で確認する方針を読んだ。
- [ ] G3: GUI／Cloud Shell の分担と、作成直後・モデル配置前のキー無効化の順序を読んだ。
- [ ] 第3章の完了条件、操作対象の RG・リソース・変更前設定を確認した。
- [ ] ロール割当権限を確認し、A13 の401試験の実施条件と、秘密値の取得・記録をしない方針を読んだ。

根拠を読んだ項目はチェックできます。到達の合格は作成後の C08 で別に判定します。根拠 URL・対象条件・実行日時・設定と動作の結果は非公開の `evidence/` に記録し、キーの値は含めません。

## 4.3. 構築

### 1. 作成画面に入力する

1. 社内 PC のブラウザで [Foundry の作成画面](https://portal.azure.com/#create/Microsoft.CognitiveServicesAIFoundry) を開きます。
2. [Basics] に下表の基本情報を入力します。
3. [Network] を開き、[Inbound Access] で [Selected networks] を選択します。
4. 社内公開 CIDR を1件ずつ入力し、承認済み一覧と照合します。
5. [Identity] でシステム割り当てマネージド ID をオンにします。
6. [Encryption] で Microsoft マネージド キーを選択します。
7. [Storage] の [Agent service] で [Select Resources] を選択します。
8. 各リソースの選択欄で第3章の名前を選び、サブスクリプション・RG・ARM ID を非公開メモと照合します。新規リソースの作成は選びません。
9. [Storage] 上段の Key Vault／Application Insights が下表の方針と一致することを確認します。
10. [Review + create] を開き、下表の値と選択済み3リソースを照合します。
11. [Create] を選択します。
12. デプロイが完了するまで待ちます。
13. ポータル上部の検索欄で作成した Foundry 名を検索し、対象リソースの [概要] を開きます。
14. 自分のサブスクリプション・RG・Foundry 名であることを確認し、直下のキー無効化へ進みます。

| 項目 | 値 |
|---|---|
| サブスクリプション / RG | 今回の実施者専用の対象 |
| リージョン | Japan East |
| Foundry 名 | `<prefix>-<account-suffix>`。接頭辞は実施者略号を含み最大9文字 |
| 受信アクセス | 選択したネットワーク＋社内 CIDR。第7章で統合サブネットの VNet 規則を追加 |
| システム割り当てマネージド ID | オン |
| 暗号化 | Microsoft マネージド キー |
| Agent service のリソース | 第3章で記録した3つの ARM ID と一致 |
| 資格情報用 Key Vault | 第2章の Vault は独立した監査対象。ここではカスタム接続せず Microsoft 管理の仕組みを使用 |
| Application Insights | 作成・接続しない。第6章の本文監査／Entra 接続の保留を維持 |

> **Note** 要確認: 根拠資料が英語のため [Basics]（基本）・[Network]（ネットワーク）・[Identity]（ID）・[Encryption]（暗号化）・[Storage]・[Review + create]・[Create] と配下の項目の日本語表示は初回に照合します。想定外のリソース作成や Application Insights 接続が必須になる場合は確定せず記録します。

> **Note** 所要時間は初回で記録します。Learn の30〜45分は手動作成手順全体の値であり、ウィザードの完了時間の保証ではありません。

#### 作成直後に Foundry account のキーを無効化する（A13）

モデル配置とデータ投入より前に行います。この操作と直後の設定確認だけは Azure Cloud Shell の [PowerShell] を使います。山括弧を今回の対象に置き換え、次の順で操作します。

1. Azure portal 上部の [Cloud Shell] を開きます。
2. Cloud Shell のシェル切替メニューで [PowerShell] を選択します。
3. PowerShell のプロンプトが表示されるまで待ちます。
4. 次のコマンドで、今回のテナントとサブスクリプションを選択します。

```powershell
Set-AzContext -Tenant '<tenant-id>' -Subscription '<subscription-id>'
```
実行結果の確認ポイント: 表示された Tenant と Subscription が第1章の対象と一致することを確認します。

5. 対象を照合できたら、キーを無効にします。

```powershell
Set-AzCognitiveServicesAccount -ResourceGroupName '<rg>' -Name '<account>' -DisableLocalAuth $true
```
実行結果の確認ポイント: 今回の Foundry account の更新が成功したことを確認し、まだデータ面に反映済みとは扱いません。

6. 更新後の設定を読み取ります。

```powershell
(Get-AzCognitiveServicesAccount -ResourceGroupName '<rg>' -Name '<account>').DisableLocalAuth
```
実行結果の確認ポイント: `DisableLocalAuth` が `True` であることを確認します。

> **Note** 反映は数分〜数時間かかります。Learn は「古いキーでデータ面を呼び、HTTP 401（`Access denied due to invalid subscription key or wrong API endpoint`）が返るまで無効化完了と扱わない」としています。キー無しの 401 や無効な文字列の 401 で代替しません。

**古いキーで 401 を確認する（公式手順に準ずる例外・2026-09-19 承認）**

この確認だけは、構築担当が実キーを 1 回使います。値は表示したまま放置せず、ファイル・`evidence/`・チャット・スクリーンショットに残しません。Cloud Shell のセッションを閉じれば変数は消えます。

1. Azure portal で今回の Foundry account を開き、[リソース管理] > [キーとエンドポイント] を選択します。
2. [キー 1] の [コピー] を選択します（画面に値を表示しません）。
3. Cloud Shell のシェル切替メニューで [Bash] を選択します。
4. Bash のプロンプトが表示されたことを確認します。
5. 次の入力待ちコマンドを実行します。

```bash
read -s -p "old key: " OLD_KEY
```
実行結果の確認ポイント: `old key:` の後で入力待ちになることを確認します。ここに手順2でコピーしたキーを貼り付け、Enter を押します。入力内容は表示されません。

6. `<account>` を今回の account 名に置き換え、下の HTTP ステータス確認を実行します。

```bash
curl -s -o /dev/null -w "%{http_code}\n" -H "api-key: ${OLD_KEY}" "https://<account>.openai.azure.com/openai/models?api-version=2024-10-21"
```
実行結果の確認ポイント: HTTP ステータスを確認します。`200` は反映待ち、`401` は下記の理由照合が必要です。`403`・`404` 等や通信失敗はキー無効化の成功にしません。

7. 結果にかかわらず、キーを変数から消します。

```bash
unset OLD_KEY
```
実行結果の確認ポイント: エラーなくプロンプトに戻ることを確認します。

8. 変数が残っていないことを確認します。

```bash
echo "${OLD_KEY:-cleared}"
```
実行結果の確認ポイント: `cleared` と表示されることを確認します。

> **Note** 要確認: 呼び出す GA データ面 API と URL は、作成した account の [キーとエンドポイント] の表示に合わせて初回に照合します。上のコマンドは本文を捨てるため、HTTP 401 の理由文までは確認できません。正しい API／URL と当該 account の実キーで呼び、公式の拒否理由に対応することを別途照合する必要があります。その方法が未確定、または理由を確認できない場合は C03 を Pending とし、401 の数字だけでモデル配置へ進みません。

9. C03 の証跡には、対象 account 名・時刻・HTTP ステータス・確認した API・拒否理由を照合できたかと判定だけを残します。キーの値・ヘッダー全文・コマンド履歴は残しません。

#### Storage に Foundry account のリソース インスタンス規則を追加する

1. 第3章の Storage の [セキュリティとネットワーク] > [ネットワーク] を開きます。
2. リソース設定の [View] を選択します。
3. [Resource instances] を開きます。
4. [Resource type] に `Microsoft.CognitiveServices/accounts` を選択します。
5. [Instance name] に今作成した Foundry account だけを選択します。テナント・サブスクリプション・RG 内の全インスタンスを許可する選択肢は使いません。
6. [保存] を選択します。
7. [ネットワーク] を開き直し、今回の Foundry account の規則が保存されていることを確認します。
8. 社内 IP 規則を照合します。
9. [設定] > [構成] でキーアクセスが [無効] のままであることを確認します。

> **Note** 要確認: [View]・[Resource instances]・[Resource type]・[Instance name] の日本語表示は初回に照合します。Learn の信頼サービス一覧には `Microsoft.CognitiveService/accounts` という表記がありますが、実際のリソース種類は `Microsoft.CognitiveServices/accounts` と照合します。

### 2. 作成後の account・project を照合する

1. Azure portal で今回の Foundry account の [概要] を開きます。
2. [JSON ビュー] を選択します。
3. `id` と `identity.principalId` を、それぞれ「account ARM ID」「account MI principal ID」として非公開メモに控えます。
4. 下表と account の設定を照合します。
5. 別タブで [Microsoft Foundry](https://ai.azure.com) を開きます。
6. [New Foundry] がオンであることを確認します。
7. プロジェクト選択画面で、今回の account に作られた初期 project を選択します。
8. project の詳細で、名前と親 account を確認します。
9. Azure portal で対応する project のリソースを開き、[JSON ビュー] の `id` と `identity.principalId` を控えます。
10. 下の対応表で ID を区別して保存します。

| 記録名 | 用途 |
|---|---|
| account ARM ID | account のネットワーク・capability host・Storage のインスタンス規則 |
| project ARM ID | project の接続・capability host・利用者権限のスコープ |
| account MI principal ID | account 自身のマネージド ID の識別 |
| project MI principal ID | BYO リソースへ割り当てる project のマネージド ID の識別 |

> **Note** 要確認: 初期 project の作成有無と、portal から project のリソース／JSON 表示へ移る導線は初回に照合します。見つからない場合は B17 に記録します。ARM ID・principal ID・project endpoint は別の値で、互いに代用しません。account ARM ID は第1章の編集方法で `.env` の `FOUNDRY_ACCOUNT_RESOURCE_ID` に保存します。

| 項目 | 値 |
|---|---|
| `publicNetworkAccess` | `Enabled` |
| `disableLocalAuth` | `true`（401試験は別） |
| `networkAcls.defaultAction` | `Deny` |
| `networkAcls.ipRules` | 社内公開 IP の許可リスト |
| account / project | 今回専用の対象。MI を取り違えない |

第7章の統合サブネットはまだ作りません。ウィザードの作成結果に project がない場合は B17 に記録し、別世代の project を推測で追加しません。

### 3. BYO 接続と capability host を確認する

1. [Microsoft Foundry](https://ai.azure.com) で対象 project を選びます。
2. 右上の [Manage] を選択します。
3. [Project details] を開きます。
4. [Connected resources] を選択します。
5. 接続一覧から Cosmos DB・Storage・AI Search の各接続を1本ずつ開きます。
6. 接続名・対象リソース・認証方式を下表と照合します。
7. 接続名と第3章の ARM ID の対応を非公開メモに記録します。

> **Note** 詳細画面で `authType` 等の生のプロパティを確認できない場合は、表示された項目と照合できなかった項目を B17 に残します。画面上の名称だけから AAD 接続だと推測しません。

> **Note** 要確認: [Manage]・[Project details]・[Connected resources] の日本語表示は初回に照合します。B17 — ウィザードが自動作成する接続・capability host・ロール割当の範囲は Learn に列挙がないため、以下の期待値を初回に照合します。

| 対象 | 期待値 |
|---|---|
| Cosmos DB 接続 | 第3章の account。`authType=AAD`、`category=AzureCosmosDb` |
| Storage 接続 | 第3章の account。`authType=AAD`、`category=AzureStorageAccount` |
| AI Search 接続 | 第3章の service。`authType=AAD`、`category=CognitiveSearch` |
| 各接続の `target` / `metadata.ResourceId` | 対象エンドポイント / 第3章の ARM ID |
| account の capability host | `capabilityHostKind=Agents`、状態 `Succeeded` |
| project の capability host | `capabilityHostKind=Agents`、状態 `Succeeded` |
| `threadStorageConnections` | Cosmos DB の接続名 |
| `storageConnections` | Storage の接続名 |
| `vectorStoreConnections` | AI Search の接続名 |

接続の認証方式だけを確認し、資格情報を表示する操作は行いません。capability host は GUI に管理操作がないため、Cloud Shell の [Bash] に切り替えて REST の GET で確認します。配列へ入るのは ARM ID ではなく接続名です。以下の `<subscription-id>`・`<rg>`・`<account>`・`<project>` は、工程2の記録から置き換えます。初期値のまま実行しません。

Bash へ戻った後、まず対象サブスクリプションを選択します。

```bash
az account set --subscription '<subscription-id>'
```
実行結果の確認ポイント: エラーなく完了することを確認します。

```bash
az account show --output table
```
実行結果の確認ポイント: テナントとサブスクリプションが今回の対象と一致することを確認します。

```bash
az rest --method get --url 'https://management.azure.com/subscriptions/<subscription-id>/resourceGroups/<rg>/providers/Microsoft.CognitiveServices/accounts/<account>/capabilityHosts?api-version=2025-06-01'
```
実行結果の確認ポイント: 今回の account の host が1つ存在し、種類 `Agents`・状態 `Succeeded` であることを確認します。

```bash
az rest --method get --url 'https://management.azure.com/subscriptions/<subscription-id>/resourceGroups/<rg>/providers/Microsoft.CognitiveServices/accounts/<account>/projects/<project>/capabilityHosts?api-version=2025-06-01'
```
実行結果の確認ポイント: 今回の project の host が成功し、3種類の配列が接続名と一致することを確認します。

接続や host が不足する場合は B17 の差異として4.5で切り分けます。IAM の追加では接続や host を作れません。Cosmos 接続の後付け GUI を想定せず、ウィザードの選択・作成結果を確認します。

### 4. サービス接続用の権限を確認する

下表をウィザードの結果と照合します。管理面のロールとデータ面のロール、account MI と project MI、利用者の権限を区別します。

| 対象・スコープ | 主体 | 期待するロール／生成物 |
|---|---|---|
| Cosmos DB account | project SMI | Cosmos DB Operator |
| Storage account | project SMI | Storage Account Contributor |
| AI Search service | project SMI＋利用する UMI | Search Index Data Contributor / Search Service Contributor |
| `<workspaceId>-azureml-blobstore` | project SMI＋利用する UMI | 生成済み Blob コンテナーと Storage Blob Data Contributor |
| `<workspaceId>-azureml-agent` | project SMI＋利用する UMI | 生成済み Blob コンテナーと Storage Blob Data Owner |
| Cosmos DB `enterprise_memory` | project SMI＋利用する UMI | Cosmos DB Built-in Data Contributor（ネイティブなデータ面ロール） |
| Foundry project | 構築・開発担当者 | Foundry User。第5章の比較用主体とは分ける |

SMI はシステム割り当て MI、UMI はユーザー割り当て MI です。実際の project に関連付けられた主体だけを対象とし、不要な UMI を新設しません。`workspaceId` と project の対応を作成結果で照合します。

不足する Azure RBAC ロールは、表のリソース／コンテナーのスコープで追加します。

1. Azure portal で下表の入口から対象のリソースまたはコンテナーを開きます。
2. [アクセス制御 (IAM)] を選択します。

| 割当スコープ | IAM を開く入口 |
|---|---|
| Cosmos DB account / Storage account / AI Search | ポータル上部でリソース名を検索 → 対象を選択 → [アクセス制御 (IAM)] |
| Storage の Blob コンテナー | 対象 Storage → [データ ストレージ] → [コンテナー] → 対象コンテナー → [アクセス制御 (IAM)] |
| Foundry project | 工程2で特定した project の Azure リソース → [アクセス制御 (IAM)] |


3. [ロールの割り当て] タブで既存の主体・ロール・スコープを照合します。
4. 不足がある場合だけ [追加] > [ロールの割り当ての追加] を選択します。
5. ロール名で検索し、上の期待値表のロールを選択します。
6. [次へ] で [メンバー] へ進みます。
7. MI の行は [アクセスの割り当て先] で [マネージド ID] を選択します（Foundry User の行はユーザーを選択）。
8. [メンバーを選択する] を開きます。
9. サブスクリプションと対象 MI を選択し、[選択] を押します。
10. 表示された主体を、工程2で控えた principal ID と照合します。
11. [レビューと割り当て] を選択します。
12. 確認画面でロール・主体・スコープを見直します。
13. 再度 [レビューと割り当て] を選択します。
14. [ロールの割り当て] に戻り、追加した割り当てを確認します。

> **Note** project MI が候補に出ない場合は、表示名だけで似た account MI を選ばず、対象 project・principal ID・割当権限を確認します。未生成のコンテナーや特定できない主体は B17 として保留します。

> **補足** Cosmos DB のデータ面 RBAC は Azure portal では管理できません。`enterprise_memory` のロールだけは IAM で代用せず、GUI にない操作として Cloud Shell（Bash）を使います。データベース／Blob コンテナーが未生成なら架空のスコープに割り当てず、host の失敗を4.5で確認します。

```bash
az cosmosdb sql role definition list --resource-group '<rg>' --account-name '<cosmos-account>' --query "[?roleName=='Cosmos DB Built-in Data Contributor'].{id:id,roleName:roleName}" --output json
```
実行結果の確認ポイント: 対象 account の組み込みデータロールの ID を確認します。

```bash
az cosmosdb sql role assignment list --resource-group '<rg>' --account-name '<cosmos-account>' --output json
```
実行結果の確認ポイント: project MI に `enterprise_memory` スコープの割当が存在するか照合します。

不足がない場合は次の作成コマンドを飛ばします。不足時は上で取得したロール定義 ID と project MI の principal ID を置換します。

```bash
az cosmosdb sql role assignment create --resource-group '<rg>' --account-name '<cosmos-account>' --role-definition-id '<built-in-data-contributor-role-id>' --principal-id '<project-mi-principal-id>' --scope '/dbs/enterprise_memory'
```
実行結果の確認ポイント: 不足時だけ実施し、対象 MI と `/dbs/enterprise_memory` の割当が作成されたことを確認します。

同じ一覧コマンドで再照合します。Search RBAC の反映には5〜10分を見込みます。Cosmos DB は Serverless を維持し、Provisioned の RU/s 値を設定しません。

#### C08 用の最小診断設定を応答試験前に準備する

第6章を先に実行する必要はありません。ここで第1章の専用 LAW に Storage／Search の要求ログを送り、第6章で既存設定として引き継ぎます。本文トレースや Application Insights 接続は追加しません。

```bash
az monitor diagnostic-settings categories list --resource '<target-resource-id>' --output json
```
実行結果の確認ポイント: Storage の `<storage-resource-id>/blobServices/default` と Search の ARM ID に対して個別に実行し、利用できるログカテゴリを確認します。

1. Azure portal で第3章の Storage を開きます。
2. [監視] > [診断設定] を開きます。
3. Blob service の診断設定を選択します。
4. 既存設定のログカテゴリと送信先 LAW を確認します。
5. 同じ送信設定がなければ [診断設定の追加] を選択します。
6. 設定名に `diag-agentgov-law` を入力します。
7. 下表の Storage のログカテゴリを選択します。
8. [Log Analytics ワークスペースへの送信] をオンにします。
9. 検証用サブスクリプションと第1章の専用 LAW を選択します。
10. [保存] を選択します。
11. 設定を開き直し、カテゴリと送信先を照合します。
12. 第3章の AI Search を開き、[監視] > [診断設定] で同じ流れを繰り返します（ログは下表の Search 用を選択）。

| 項目 | 値 |
|---|---|
| 診断設定名 | `diag-agentgov-law` |
| Storage Blob のログ | 実在を確認した StorageRead / StorageWrite / StorageDelete |
| Search のログ | 実在を確認した OperationLogs |
| 宛先 | [Log Analytics ワークスペースへの送信] で第1章の専用 LAW |
| 保存形式 | 選択できる場合は [リソース固有]。実際の保存先を記録 |

### 5. モデルを配置する

1. Microsoft Foundry の左上で今回の project を確認します。
2. 右上の [検出] を選択し、左側の [モデル] を開きます。
3. `gpt-5-mini` を検索します。
4. 検索結果の `gpt-5-mini` を開き、[配置] で提示される構成を確認します。
5. 下表の条件を満たす場合だけ配置を確定します。
6. 配置の完了を待ち、配置名とモデルのバージョンを非公開の記録に残します。

| 項目 | 値・確認内容 |
|---|---|
| モデル | `gpt-5-mini` |
| 配置の種類 | `GlobalStandard` |
| バージョン | 対象環境で提供される GA のバージョンを記録 |
| リージョン・クォータ | 対象の配置条件を満たすこと |
| コンテンツフィルター | 適用設定を記録し、無効化しない |

公式クイックスタートは [配置] → [既定の設定] を案内しますが、既定値がこのラボの値と一致するとは限りません。一致しない、クォータが足りない、対象モデルがない場合は配置を保留します。

### 6. prompt agent を作り、合成データで応答を確認する

1. 対象 project の [ビルド] を開きます。
2. [エージェント] を開きます。
3. [エージェントの作成] を選びます。
4. 名前に `governance-lab-agent` を指定します。
5. エージェントのモデルに前項の配置を選びます。
6. 指示欄に下記の文字列を入力します。
7. ツールが追加されていないことを確認します。
8. 設定を保存した状態でエージェント一覧へ戻り、`governance-lab-agent` を開き直します。
9. 名前・モデル配置・指示・ツールなしの状態が保持されていることを確認します。
10. プレイグラウンドのチャット入力欄に、下の2つ目のコードブロックにある架空の会議メモを貼り付けます。
11. 送信ボタンを選択します。
12. 応答を待ち、日時と議題が入力内容に沿っていることを確認します。
13. 試験時刻・project・エージェント名・配置名・結果を非公開の証跡に記録します。

> **Note** 要確認: エージェント設定の保存が自動か、保存ボタンを押す方式かは初回に照合します。未保存の表示が残る場合は一覧に戻らず、表示された保存操作を済ませます。保存操作とエージェントの公開は別で、本章では公開を行いません。

```text
合成データだけを扱う検証用アシスタントです。登録した許可済みツール以外を使わず、不明な内容は不明と回答してください。
```
実行結果の確認ポイント: 指示が設定に保持され、ツールが追加されていないことを確認します。

```text
これは架空の会議メモです。火曜日10時30分から、検証結果の確認と次回の担当分担を話します。日時と議題を簡潔に整理してください。
```
実行結果の確認ポイント: 入力した日時と議題に沿った応答が返ることを確認し、文章の完全一致は求めません。

指示文は権限制御の代わりにはなりません。この章では正常応答の基準を作ります。拒否試験や利用者ごとの差の判定は第8章で行います。エージェント向けの Preview の guardrails や介入機能は対象外です。

プレイグラウンドの評価機能は有効な場合に追加費用が発生し得ます。この章では評価を必須にせず、[メトリック] に表示される評価の有効状態を確認して不要な評価を解除します。

### 7. C08 の初回到達を確認する

応答確認の直後に、試験時刻と対象 project を照合します。Data Explorer の閲覧権限は、直下の確認を済ませてから開きます。

**Data Explorer を開く前の準備**

工程4の Cosmos DB データロール定義の照会で、ロール名を `Cosmos DB Built-in Data Reader` として ID を確認します。既存割当を確認し、不足時だけ同工程の割当方法で検証担当者に `/dbs/enterprise_memory` の閲覧ロールを付与します。この場合の principal ID は人のユーザーのオブジェクト ID です。project MI の ID や Data Contributor を流用しません。

1. Azure portal で第3章の Cosmos DB アカウントを開きます。
2. 左側メニューの [Data Explorer] を選択します。
3. データベース一覧で `enterprise_memory` を展開し、下表のコンテナーの生成と今回の project との対応を確認します。
4. ポータル上部の検索から第1章の LAW を開きます。
5. 左側メニューの [ログ] を選択します。
6. クエリ編集画面で、保存先テーブルと試験時刻を確認します。
7. 下のクエリ例で Storage と Search の要求を個別に確認します。
8. 対象リソース・操作・認証主体を照合し、Foundry からの要求の成功／拒否を記録します。
9. 許可外 IP 試験の API・有効な認証・比較条件が確定している場合だけ、Cloud Shell から対象の Foundry データ面を呼びます。未確定の場合は実行せず該当行を Pending にします。

クエリの `<log-table-name>` は実在するテーブル名、`<target-resource-id>` はログに記録された対象リソース ID に置換します。Storage は Blob service の ID で記録される場合があるため、account の ID と混同しません。

```kusto
table("<log-table-name>")
| where TimeGenerated > ago(2h)
| where _ResourceId =~ "<target-resource-id>"
| order by TimeGenerated desc
| take 20
```
実行結果の確認ポイント: [実行] を選択し、今回の試験時刻のレコードを確認します。件数だけでは成功にせず、結果コードと Foundry MI の主体情報を照合します。2時間より前の試験は期間を調整します。

> **Note** 要確認: ログ画面のクエリ編集モードへの切替、実際のテーブル名・結果列・主体列は初回に照合します。テーブルがない、対応する要求がない、主体を特定できない場合は Pending です。

| 対象 | 初回到達の証拠 |
|---|---|
| 許可 IP | 社内ブラウザで Entra 認証の応答成功 |
| 許可外 IP | Cloud Shell から同等権限で Foundry に接続した際のリソース側のネットワーク拒否 |
| Cosmos DB | `enterprise_memory` 内の project 対応コンテナー生成。新ランタイムの `agent-definitions-v1`／`run-state-v1` は初回呼び出し時に動的作成されるため、実名と project の対応を記録 |
| Storage / Search | StorageBlobLogs / AzureDiagnostics 等の実際の保存先で、Foundry の MI に対応する要求と成功結果を確認 |

> **Note** Data Explorer は検証担当者にもデータ面の閲覧権限が必要です。工程4と同じデータロール照会・割当方法で Cosmos DB Built-in Data Reader を対象データベースへ割り当てます。MI 向けの書き込み権限を人へ流用しません。日本語表示とコンテナー接頭辞の実際の形式は初回で照合します。

> **Note** 要確認: 許可外 IP 試験で呼ぶ GA データ面 API は、今回作成したエージェントの API 世代と照合して初回に確定します。管理面の GET、認証なしの401、条件付きアクセスでの拒否ではネットワーク拒否を証明できません。

テキスト1往復では Storage／Search の実要求が発生するとは限りません。ログがないだけで到達不能とは判定せず、収集開始・遅延・操作発生を確認します。要求を発生させる GA のファイル操作／検索の手順が未確定なら、その行は Pending として必要な試験を確定します。未許可のツールを追加したり、本文ログを代用したりしません。到達拒否が確認された場合は4.5で切り分けます。

## 4.4. 完了条件

C01（初回接続）と C08 の初回接続部分を対象別に記録します。後の章のツール試験まで Pass にしません。

- G1〜G3 の根拠と A10〜A13 の適用を記録した。
- account／project／project MI と接続3本を特定した。
- 社内 IP 制限・Entra 認証・Foundry のキー無効設定と古いキーの401を確認した。
- account と project の capability host が成功し、接続名が一致した。
- 必要な管理ロール・データロールを必要なスコープで確認した。
- 社内ブラウザで合成入力に応答し、モデル配置名・バージョン・指示・時刻を記録した。
- Cosmos のコンテナー生成、Storage／Search の Foundry 要求ログ、許可外 IP の拒否を対象別に記録した。

不足する証拠は Pending、到達の期待に反する結果は Fail とします。BYO 設定と実際の動作を区別し、第2章の Key Vault を自動接続済みとは扱いません。

## 4.5. うまくいかない場合

### C08 で届かない場合の切り分け

1. account 作成・host 作成・モデル配置・チャットのどの操作で失敗したかを記録します。
2. 接続先 ID・MI・対象時刻・エラーコード・相関 ID を非公開で照合します。
3. 第3章のネットワーク設定と工程4のロールを照合します。
4. Cosmos／Search の最大15分の設定反映、Search RBAC の5〜10分の反映を待って再試験します。
5. 対象ごとの要求ログと成否から、ネットワーク拒否・認証拒否・未実施を区別します。

| 症状 | 確認と対応 |
|---|---|
| Storage 到達失敗 | リソース インスタンス規則が今回の Foundry account を指すか、project MI のコンテナー別データロールがあるか |
| Search の403 / SearchIndexNotFound | 信頼サービス例外がオンか、project MI の Search Index Data Contributor と Search Service Contributor があるか |
| Cosmos 到達失敗 | 社内 CIDR と `0.0.0.0`、公開ネットワーク Enabled、キー無効、`enterprise_memory` のデータロールを照合 |
| `CapabilityHostProvisioningFailed` / host が Failed | Cosmos の RU 上限不足が典型原因。Learn の合計3000 RU/s以上という要件とアカウント制限を確認。Serverless を維持し、勝手に Provisioned や SKU を変更しない |
| 3リソース不足のエラー | 接続3本と host の参照を照合。Cosmos だけを外さない |
| B17: 接続・host がない | ウィザードの [Storage] > [Agent service] の選択と作成結果を確認。ロール不足は工程4で補うが、接続／host の後付け GUI は推測しない |
| host の409 | 1スコープ1つの制約と進行中の作成を確認。重複作成しない |
| モデル配置失敗 | リージョン・GAバージョン・配置の種類・クォータを確認 |
| キー無効設定が True でも実キーが 200 を返す | 反映待ち。時間を置いて 401 確認を再実行。再有効化はしない。401 を確認するまでモデル配置に進まない |
| Storage／Search ログがない | 収集設定・時間範囲・閲覧権限・実要求の発生を確認。空ログだけで Basic へ分岐しない |

### Standard setup が成立しない場合だけ Basic setup に切り替える

G2 の初回試験で、承認済みの設定と権限を満たしても3リソースへの到達が成立しないと分かった場合の代替です。B17 の照合待ち、ログ未到着、モデルクォータ不足だけでは切り替えません。ネットワークを全許可にする復旧は行いません。

1. C08 の対象別の失敗結果と切り分け内容を非公開に記録します。
2. 元の account／project の利用を止めます。
3. 4.3工程1と同じ Azure portal ウィザードを、新しい Foundry account 名で開きます。
4. 同じ専用 RG・Japan East・社内 CIDR・システム割り当て MI・Microsoft マネージド キーを設定します。
5. [Storage] > [Agent service] では BYO の [Select Resources] を設定しません。
6. Key Vault／Application Insights の未接続方針を維持します。
7. [Review + create] で別 account であることを確認します。
8. [Create] を選択します。
9. 作成直後に工程1の PowerShell でキーを無効化します。
10. 古いキーの401を確認してから工程5・6でモデルと prompt agent を新規作成します。
11. account／project／agent の参照を新しい対象へ更新します。

Basic setup では capability host を作りません。Learn の “Creating capability hosts isn't required” に従い、Microsoft 管理の保存先を使います。Standard と Basic を同じ account に混ぜないという推奨に従うため、元の account 内に Basic project を足す手順ではありません。

| 判定項目 | Basic へ分岐した場合 |
|---|---|
| C01 | Basic の応答結果と構成を記録。BYO host／接続の行は対象外の理由を明記し、Standard の成功へ読み替えない |
| C08 | 人の入口の許可／拒否は継続。Standard の3リソース到達の失敗を残し、Basic の BYO 行は対象外として別記。全体を無条件 Pass にしない |
| 第3章のリソース | この章では削除しない。第7章のアプリ用 Cosmos は引き続き使用可能。残存費用を記録 |
| 後続章 | 第5章以降は新 account／project／agent を対象にする。Agent Service の自前保存を確認したとは書かない |

分岐前後の対象・設定・費用と判断を記録します。切り分けで変更した値は承認済みの設定に戻します。元の構成へ戻す場合は元の対象と到達を再確認し、host の即時削除や更新で切り替えません。削除は第10章だけで行います。

## 4.6. 次の操作

Standard は4.4の完了条件を満たして第5章へ進みます。Basic に分岐した場合は4.5の対象外・失敗の記録を残し、Basic の応答と人の入口の制限、キー無効化を確認して進みます。証拠不足の Pending を合格へ変更しません。C08 のツール部分は第7・8章、本文監査 C05 は第6章の保留条件で別に扱います。

## 4.7. 費用

| Excel v3 明細 No | 項目 | 通常月 USD |
|---|---|---:|
| 1 | Microsoft Foundry リソース / project / prompt agent | 0.000000 |
| 14 | gpt-5 mini / Global Standard 入力 | 9.000000 |
| 15 | gpt-5 mini / Global Standard 出力 | 10.800000 |
| 16 | Content Safety / Standard テキストレコード | 7.500000 |

2026-09-15 の見積り v3 の既定値です。Japan East、原則 32h/月の検証、CSPM は既定 OFF です。No.8 と No.12 は常時／検証日の切替で、二重計上しません。No.6 は 第1章/第6章の共通費です。見積り保証ではありません。

## 4.8. 本番との差・IaC で再現する (任意)

本番ではモデル変更管理と可用性を設計します。[付録 B](92-appendix-production-diff.md) を参照します。

固定した [公式テンプレートの説明](../infra/PINNED_COMMIT.md) と [IaC の停止条件](../infra/README.md) は参考資料です。GUI で作成済みのリソースを含めて一式を再展開しません。旧 CLI 主線の後追い変更を GUI 手順の代用として実行しません。`infra/` は旧停止点のままで D14・D15・D16 は未反映です。Cosmos 接続の例外はテンプレート内の他の Preview API を承認するものではなく、固定停止点を維持します。

### 出典

- 出典: [Cloud Shell のシェル切替](https://learn.microsoft.com/en-us/azure/cloud-shell/use-the-shell-window)（取得日 2026-09-20）
- 出典: [Set-AzContext](https://learn.microsoft.com/en-us/powershell/module/az.accounts/set-azcontext)（取得日 2026-09-20）
- 出典: [Log Analytics の操作](https://learn.microsoft.com/ja-jp/azure/azure-monitor/logs/log-analytics-tutorial)（取得日 2026-09-20）

- 出典: [Foundry リソースの GUI 作成](https://learn.microsoft.com/ja-jp/azure/ai-services/multi-service-resource)（取得日 2026-09-20）
- 出典: [接続の種類と作成](https://learn.microsoft.com/ja-jp/azure/foundry/how-to/connections-add)（取得日 2026-09-20）
- 出典: [Standard setup](https://learn.microsoft.com/ja-jp/azure/foundry/agents/concepts/standard-agent-setup)（取得日 2026-09-20）
- 出典: [環境セットアップ](https://learn.microsoft.com/ja-jp/azure/foundry/agents/environment-setup)（取得日 2026-09-15）
- 出典: [ローカル認証の無効化](https://learn.microsoft.com/ja-jp/azure/ai-services/disable-local-auth)（取得日 2026-09-20）
- 出典: [capability host](https://learn.microsoft.com/ja-jp/azure/foundry/agents/concepts/capability-hosts)（取得日 2026-09-15）
- 出典: [ネットワークの選択肢](https://learn.microsoft.com/ja-jp/azure/foundry/agents/concepts/networking-options)（取得日 2026-09-15）
- 出典: [Cosmos DB の IP 制限](https://learn.microsoft.com/ja-jp/azure/cosmos-db/how-to-configure-firewall)（取得日 2026-09-15）
- 出典: [Storage ネットワークの制限事項](https://learn.microsoft.com/ja-jp/azure/storage/common/storage-network-security-limitations)（取得日 2026-09-15）
- 出典: [AI Search の IP 制限](https://learn.microsoft.com/ja-jp/azure/search/service-configure-firewall)（取得日 2026-09-15）
- 出典: [Foundry リソースとモデル配置](https://learn.microsoft.com/ja-jp/azure/foundry/tutorials/quickstart-create-foundry-resources)（取得日 2026-09-20）
- 出典: [最初のエージェント](https://learn.microsoft.com/ja-jp/azure/foundry/quickstarts/get-started-code)（取得日 2026-09-20）
- 出典: [プレイグラウンド](https://learn.microsoft.com/ja-jp/azure/foundry/concepts/concept-playgrounds)（取得日 2026-09-15）
- 出典: [Foundry の GA 範囲](https://learn.microsoft.com/ja-jp/azure/foundry/concepts/general-availability)（取得日 2026-09-15）

- 出典: [Foundry 作成ウィザード](https://learn.microsoft.com/en-us/azure/ai-services/multi-service-resource)（取得日 2026-09-20）
- 出典: [接続の種類](https://learn.microsoft.com/en-us/azure/foundry/how-to/connections-add)（取得日 2026-09-20）
- 出典: [Standard setup の作成順と権限](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/standard-agent-setup)（取得日 2026-09-20）
- 出典: [Basic／Standard の比較と公開 Standard setup](https://learn.microsoft.com/en-us/azure/foundry/agents/environment-setup)（取得日 2026-09-20）
- 出典: [capability host の確認と Basic の分離](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/capability-hosts)（取得日 2026-09-19）
- 出典: [キー無効化と反映の確認](https://learn.microsoft.com/en-us/azure/ai-services/disable-local-auth)（取得日 2026-09-20）
- 出典: [Storage のリソース インスタンス規則](https://learn.microsoft.com/en-us/azure/storage/common/storage-network-security-resource-instances)（取得日 2026-09-20）
- 出典: [Cosmos DB のネットワーク規則](https://learn.microsoft.com/en-us/azure/cosmos-db/how-to-configure-firewall)（取得日 2026-09-19）
- 出典: [Search の信頼サービス例外](https://learn.microsoft.com/en-us/azure/search/service-configure-firewall)（取得日 2026-09-19）
- 出典: [Cosmos DB のデータ面 RBAC](https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/how-to-connect-role-based-access-control)（取得日 2026-09-20）
- 出典: [Azure Monitor の診断設定](https://learn.microsoft.com/en-us/azure/azure-monitor/platform/diagnostic-settings)（取得日 2026-09-20）

- 出典: [Azure portal のロール割当](https://learn.microsoft.com/ja-jp/azure/role-based-access-control/role-assignments-portal)（取得日 2026-09-20・第6章の既存根拠を引継ぎ）
- 出典: [Blob service のログカテゴリ](https://learn.microsoft.com/ja-jp/azure/azure-monitor/reference/supported-logs/microsoft-storage-storageaccounts-blobservices-logs)（取得日 2026-09-15・第6章の既存根拠を引継ぎ）
- 出典: [Search のログカテゴリ](https://learn.microsoft.com/ja-jp/azure/azure-monitor/reference/supported-logs/microsoft-search-searchservices-logs)（取得日 2026-09-15・第6章の既存根拠を引継ぎ）

- 出典: [3リソース必須のエラー説明（ネットワーク構成資料。閉域の構築手順は対象外）](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/virtual-networks)（取得日 2026-09-19）
- 出典: [Cosmos DB データロール割当 CLI](https://learn.microsoft.com/en-us/cli/azure/cosmosdb/sql/role/assignment?view=azure-cli-latest)（取得日 2026-09-19）

---

前へ: [データ基盤を作る](03-data.md) / 次へ: [人とサービスの権限を設定する](05-identity.md) / [トップに戻る](../README.md)
