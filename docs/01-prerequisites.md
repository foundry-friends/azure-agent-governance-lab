# 1. 準備と土台

進め方: 第0章の事前確認後、この章を上から実施します。

> **Note** 状態: ドラフト（Learn 2026-09 時点の記述に基づく・未実行）

> **Note** 所要時間の目安: Run 当日は 0.5h（RG・Log Analytics・予算の作成）。Cloud Shell の準備・権限確認・リソースプロバイダーの登録・モデルの登録は 事前確認（前日まで）に済ませておきます。

> **Note** このリポジトリでは、リソースの作成と設定変更は **Azure portal の GUI** で行います。登録する設定を自分の目で確かめながら進めるためです。コマンドは **Azure Cloud Shell（Bash）** で実行し、用途は設定の確認・照合と、GUI に無い操作の代替に限ります（[1.2](#実行環境)）。

## 1.1. 目的

統制層⑩（コスト・クォータ）と⑦（監査）の土台を作ります。具体的には、実施者ごとの専用リソースグループ、命名とタグ、予算アラート、Log Analytics ワークスペース、確認用の実行環境（Cloud Shell）と公式テンプレートの版の固定です。このセクションで作るものは 第5章 以降のすべてのセクションが参照します。Azure Policy・Defender・診断設定はここでは作らず、第6章 と 第9章で扱います。

### なぜこの作業が必要か

この後に作るリソースを、誰の検証用か分かる単位で管理するために土台を用意します。専用リソースグループとタグは、操作対象・費用・削除対象を整理するために使います。権限やモデルの利用条件も先に確認し、構築途中で進めなくなる原因を減らします。

予算アラートは費用の増加に気づくため、Log Analytics は後で監査ログを集めるために準備します。ここでは受け皿を作り、第6章で各サービスからログを送る設定につなげます。予算通知を作ることと、リソースを停止して費用を抑えることは別の作業です。

## 1.2. 前提

### 実行環境

| 項目 | 値 |
|---|---|
| 作成・設定変更 | Azure portal <https://portal.azure.com>（日本語表示） |
| 確認・照合のコマンド | Azure Cloud Shell（Bash）。ポータル上部ナビゲーションから起動。Azure CLI・Bicep CLI・Git・GitHub CLI・Python 3 同梱、月次更新 |
| ブラウザ | Microsoft Edge・Google Chrome・Mozilla Firefox・Apple Safari（プライベートモード不可） |
| 接続元 | 社内ネットワーク（Entra 条件付きアクセスで許可された IP） |

1. Azure portal の右上にある [設定]（歯車のアイコン）を選択します。
2. [Language + region] で言語に [日本語] を選択し、[適用] を選択します。

> **補足** 本手順の画面名と項目名は、Microsoft Learn 日本語版の表記（2026-09 時点）に合わせています。ポータルの表示言語が英語のままだと項目名が一致しないため、最初に日本語に揃えます。

> **補足** Cloud Shell のコンテナーは Microsoft のネットワークで動き、**送信元 IP は社内 IP ではありません**。リソースの作成や設定の照合（ARM）は影響を受けませんが、社内 IP 許可リストを付けたリソースのデータ面（Blob の読み書き・Key Vault のシークレット取得）は Cloud Shell からは拒否されます。D14 のツール用 APIM は ID で制限するため、Cloud Shell からの拒否を IP 制限の結果と決めつけません。データ面の試験は社内 PC のブラウザ（ポータル・Foundry ポータル・第7章の呼び出しアプリ）から行います。この値を各リソースの作成時に使います。

### Cloud Shell の準備（事前確認）

1. 社内ネットワークから Azure portal にサインインします。
2. 上部ナビゲーションの [Cloud Shell] アイコンを選択します。
3. [Bash] を選択します。すでに PowerShell で開いている場合は [Switch to Bash] を選択します。
4. [使用を開始する] で [ストレージ アカウントのマウント] を選択し、検証用サブスクリプションを選んで [適用] を選択します。
5. [ストレージ アカウントを作成します] を選択し、[次へ] を選択します。

> **画面の見え方** ストレージをマウントすると、Cloud Shell がストレージアカウントとファイル共有（5 GB）を作り、`$HOME` の内容を次回以降も保持します。このストレージアカウントには `ms-resource-usage:azure-cloud-shell` のタグが付き、Run の RG とは別のリソースグループに作られます。Run 終了時に削除しません。

> **Note** 要確認: 部門共有サブスクリプションで Cloud Shell のストレージをどのリソースグループに置くか（既定の自動作成か、[既存のストレージ アカウントを選択] で `rg-agentgov-<略号>-shell` に自前で作るか）は 事前確認 で決めます。Azure Policy でストレージ作成が拒否される（`403 RequestDisallowedByPolicy`）場合は [ストレージ アカウントは不要]（エフェメラル）で進めますが、セッション終了でファイルが消えるため `.env` を毎回作り直します。

6. 版を確認します。

```bash
az version
```
実行結果の確認ポイント: `azure-cli` の版が表示されることを確認し、`evidence/` に記録します（Cloud Shell は月次更新のため）。

7. 検証用サブスクリプションを既定にします。

```bash
az account set --subscription "<subscription-id>"
```
実行結果の確認ポイント: エラーが出ないことを確認します。設定は `~/.azure/azureProfile.json` に保存され、次のセッションでも有効です。

8. 既定のサブスクリプションとテナントを照合します。

```bash
az account show --output table
```
実行結果の確認ポイント: 表示されたサブスクリプションとテナントが検証用のものと一致することを確認します。

> **Note** Cloud Shell は自動でサインイン済みのため `az login` は不要です。`Audience ... is not a supported MSI token audience` というエラーが出るコマンドだけ、`az login --use-device-code` で再サインインします。Cloud Shell はアイドル 20 分でセッションが切れます。

> **Note** 要確認: Learn には「デバイス準拠やハイブリッド参加を要求する条件付きアクセスは Cloud Shell では非対応」と記載があります。社内の条件付きアクセスがネームドロケーション（IP）だけであれば影響しない想定ですが、事前確認 で Cloud Shell が開けることを確認します。

9. このリポジトリを Cloud Shell の `$HOME` に取得します。

```bash
git clone https://github.com/<owner>/azure-agent-governance-lab.git
```
実行結果の確認ポイント: `azure-agent-governance-lab` ディレクトリができることを確認します。以降のコマンドはすべてこのディレクトリで実行します（`cd ~/azure-agent-governance-lab`）。

> **Note** リポジトリが Private の間は、`gh auth login --web` で GitHub にサインインしてから `git clone` します。Public 化後は不要です。

### 権限

Standard setup の公式テンプレート 41 を展開する実施者には、次のロールが必要です。

| 何をするか | 要るロール |
|---|---|
| Foundry account と project の作成 | **Foundry Account Owner**（旧名 Azure AI Account Owner。ID と権限は改名前後で同じ） |
| Standard setup で Cosmos DB・AI Search・Storage に RBAC を付与 | `Microsoft.Authorization/roleAssignments/write` を持つロール。**所有者**・**ユーザー アクセス管理者**・**ロールベースのアクセス制御管理者** のいずれか |
| Azure Policy の割当（第9章） | **Resource Policy Contributor** または所有者。共同作成者では定義・割当を作れません |
| 予算アラートの作成（このセクション） | 所有者。共同作成者と Cost Management 共同作成者は自分が作った予算のみ操作できます |
| モデルのクォータ閲覧 | **Cognitive Services Usages Reader**（サブスクリプション スコープ）。増枠要求は所有者か共同作成者 |

1. Azure portal で [サブスクリプション] を検索して選択し、検証用サブスクリプションを開きます。
2. 左側のナビゲーションから [アクセス制御 (IAM)] を選択します。
3. [アクセスの確認] タブで [マイ アクセスの表示] を選択します。
4. 表示された割り当てに上表のロールが含まれることを確認します。

> **画面の見え方** このスコープでの割り当てと、上位（管理グループ）から継承した割り当てが一覧に出ます。下位（リソースグループ）だけに付いた割り当ては出ません。リソースグループを作った後に、RG のスコープでも同じ手順で確認します（[1.3](#rg-スコープの権限の再確認)）。

> **Note** 要確認: 必要ロールのスコープは Learn のページで表現が揺れます（環境セットアップのページは「Foundry Account Owner をサブスクリプション スコープで」、Standard setup の概念ページは「リソースグループの所有者かユーザー アクセス管理者」、公式テンプレート 41 の README は「Foundry Account Owner と Role Based Access Administrator」）。初回で実際に通った組み合わせを記録して確定します。

> **補足** Foundry のロールは 2026 年に改名されました。Foundry User・Foundry Owner・Foundry Account Owner・Foundry Project Manager は、それぞれ旧 Azure AI User・Azure AI Owner・Azure AI Account Owner・Azure AI Project Manager です。ポータルで旧名しか見つからない場合も同じロールです。

### リソースプロバイダー

| 名前空間 | 使うセクション | 出典 |
|---|---|---|
| Microsoft.CognitiveServices | 第4章（Foundry） | Foundry の BYO ページ |
| Microsoft.KeyVault | 第5章 | 同上 |
| Microsoft.Storage | 第3章 | 同上 |
| Microsoft.Search | 第3章 | 同上 |
| Microsoft.MachineLearningServices | 第4章（Foundry project の内部依存） | 同上 |
| Microsoft.App | 第4章（同ページが登録を求める。prompt agent 本編では使わない見込み） | 同上 |
| Microsoft.ContainerService | 第4章（同上） | 同上 |
| Microsoft.DocumentDB | 第3章（Cosmos DB） | このリポジトリの追加 |
| Microsoft.OperationalInsights | 第1章・第6章（Log Analytics） | 同上 |
| Microsoft.Insights | 第6章（Application Insights・診断設定） | 同上 |
| Microsoft.ManagedIdentity | 第5章 | 同上 |
| Microsoft.CloudShell | 第1章（Cloud Shell） | Cloud Shell の Learn ページ |
| Microsoft.ApiManagement・Microsoft.Web・Microsoft.Network | 第7章（APIM・App Service・VNet を作成する前に登録状態を確認） | このリポジトリの追加（D14） |
| Microsoft.PolicyInsights・Microsoft.Security | 第9章（使う直前に登録） | 同上 |

`Microsoft.Consumption`（予算）・`Microsoft.Resources`・`Microsoft.Authorization` は既定で登録済みです。`Microsoft.Bing` は Bing ツールを使う場合だけ必要で、このリポジトリでは登録しません。

1. [サブスクリプション] で検証用サブスクリプションを開きます。
2. 左側のナビゲーションの [設定] から [リソース プロバイダー] を選択します。
3. 検索ボックスに名前空間（例 `Microsoft.CognitiveServices`）を入力します。
4. 該当行を選択し、[登録] を選択します。
5. 初回 で使う上表の名前空間（第7章・第9章の行を除く）について 3〜4 を繰り返します。

> **画面の見え方** 状態の列が [登録解除] から「登録中」に変わり、数分で [登録済み] になります。登録はリージョンごとに順に進むため、「登録中」のままでも次の作業を止める必要はありません。

> **補足** 登録には `/register/action` 権限が必要で、共同作成者と所有者に含まれます。テンプレートのデプロイ時に使う名前空間は自動登録されますが、監視やセキュリティのように「テンプレートに書かれていない補助リソース」の名前空間は手動で登録します。Learn は「使う準備ができてから登録する」ことを勧めているため、第7章・第9章の名前空間は該当セクションで登録します。

6. Cloud Shell で登録状態を照合します。

```bash
az provider list --query "[?registrationState!='Registered'].{Provider:namespace, Status:registrationState}" --output table
```
実行結果の確認ポイント: 上表の 初回 の名前空間が表示されない（すべて `Registered`）ことを確認します。

### モデルとクォータ

このリポジトリのモデルは gpt-5-mini（バージョン 2025-08-07・Global Standard）です。Learn のリージョン別提供表で Japan East（`japaneast`）の Global Standard に提供があります。

1. Microsoft Foundry ポータル <https://ai.azure.com> に移動し、[New Foundry] のトグルがオンであることを確認します。
2. 左側のナビゲーションから [Manage] を選択し、[Quota] を開きます。
3. [Token per minute] のタブで Japan East の gpt-5-mini の割当を確認します。

> **Note** gpt-5 系のモデルは Learn に「登録（registration）が必要」と明記されています。事前確認 で登録の要否と手続きを確認し、間に合わない場合は 第4章の「うまくいかない場合」で代替モデルを選びます。

4. Cloud Shell で使用量と上限を照合します。

```bash
az cognitiveservices usage list --location japaneast --output table
```
実行結果の確認ポイント: gpt-5-mini の Global Standard に相当する行があり、上限（limit）が 0 でないことを確認します。

> **Note** 要確認: この出力で gpt-5-mini を表す `name.value` の形式は Learn に例がありません。初回で実物を記録します。

### 社内 IP と Entra の確認（事前確認）

1. 社内の公開 IPv4 アドレス範囲（CIDR）の一覧をネットワーク担当者から入手します。
2. 入手した CIDR を `.env` の `ALLOWED_IP_RANGES` に JSON 配列で書きます（[1.3](#設定ファイルenv)）。
3. 既存の Entra 条件付きアクセスと継続的アクセス評価（CAE）の設定内容を確認し、変更しないことをチームで共有します。

設計と各リソースへの適用は [第0章](00-before-start.md) を参照します。

## 1.3. 構築

### 命名と入力値

このセクションで入力する値を先に決めます。実在の ID・メールアドレス・社内 IP は `.env` にだけ書き、公開ファイルには書きません。

| 項目 | 値 |
|---|---|
| 実施者略号 | 英小文字 2〜4 文字（例 `tf`） |
| リソースグループ名 | `rg-agentgov-<略号>-run1` |
| リージョン | Japan East |
| Log Analytics ワークスペース名 | `law-agentgov-<略号>-run1` |
| 予算名 | `budget-agentgov-<略号>-run1` |
| 月予算（USD） | 上長と合意した値（目安は [README](../README.md#費用の目安)） |
| 予算の通知先 | 実施者のメールアドレス |
| タグ | `purpose` = `agent-governance-lab`、`run` = `1`、`operator` = `<略号>`、`deleteAfter` = `<YYYY-MM-DD>` |

> **補足** 部門で共有するサブスクリプションでは、RG を実施者ごとに分け、同じ RG を複数人で同時に触りません。予算アラートと Policy 割当はこの RG スコープに閉じます（サブスクリプション スコープにすると他チームに影響します）。

### 設定ファイル（.env）

`.env` は Cloud Shell の確認コマンドと `scripts/` が参照します。Cloud Shell の `$HOME` 配下（`~/azure-agent-governance-lab/.env`）に置き、ストレージをマウントしていれば次のセッションでも残ります。

1. 設定例をコピーします。

```bash
cp -n .env.example .env
```
実行結果の確認ポイント: 既存の `.env` を上書きしていないことを確認します（`-n` は既存ファイルを上書きしません）。

2. Cloud Shell のエディターで開きます。

```bash
code .env
```
実行結果の確認ポイント: 画面上部にエディターが開くことを確認します。保存は Ctrl+S、閉じるのは Ctrl+Q です。

3. 下表の値を入力して保存します。

| 項目 | 値 |
|---|---|
| AZURE_SUBSCRIPTION_ID・AZURE_TENANT_ID | 検証用サブスクリプションとテナントの ID（[サブスクリプション] の [概要] で確認） |
| OPERATOR_CODE | 実施者略号 |
| AZURE_RESOURCE_GROUP | `rg-agentgov-<略号>-run1` |
| AZURE_LOCATION | `japaneast` |
| AZURE_DEPLOYMENT_NAME | デプロイ名（例 `agentgov-run1`） |
| LOG_ANALYTICS_WORKSPACE_NAME・LOG_ANALYTICS_RESOURCE_ID | 作成予定の名前。ID は作成後にこのファイルへ追記 |
| BUDGET_AMOUNT_USD・BUDGET_CONTACT_EMAIL・BUDGET_START_DATE | 作成する予算の値 |
| DELETE_AFTER | 削除予定日（`YYYY-MM-DD`） |
| ALLOWED_IP_RANGES | 社内公開 IPv4 CIDR の JSON 配列（例 `'["203.0.113.0/24"]'`。全許可は不可） |

> **補足** まだ作成していないリソースの ID はプレースホルダーのまま残します。作成する工程で追記します。

4. 設定を読み込みます。

```bash
source .env
```
実行結果の確認ポイント: `echo "$AZURE_RESOURCE_GROUP"` で入力した RG 名が表示されることを確認します。API キーや接続文字列を書いていないことも確認します。

> **Note** `.env` と `*.local.json` は `.gitignore` 済みで、コミットしません。

### リソースグループ

1. Azure portal で [リソース グループ] を検索して選択します。
2. [作成] を選択します。
3. [基本] タブで下表の値を入力します。

| 項目 | 値 |
|---|---|
| サブスクリプション | 検証用サブスクリプション |
| リソース グループ | `rg-agentgov-<略号>-run1` |
| リージョン | Japan East |

4. [次へ: タグ] を選択し、[命名と入力値](#命名と入力値) のタグ 4 つを名前と値で入力します。
5. [確認および作成] を選択し、検証に成功したら [作成] を選択します。
6. 上部の [通知]（ベルのアイコン）から [リソース グループに移動] を選択します。

> **画面の見え方** リソースグループの [概要] にリージョンとタグが表示されます。タグを付け忘れた場合は [概要] の [タグの追加] から名前と値を入力し [保存] を選択します。

> **Note** 要確認: 作成ウィザードの [タグ] タブの手順は Learn に記載がありません（Learn は作成後の [タグの追加] を案内）。初回で実際の画面に合わせます。

### RG スコープの権限の再確認

1. 作成したリソースグループの左側のナビゲーションから [アクセス制御 (IAM)] を選択します。
2. [アクセスの確認] タブで [マイ アクセスの表示] を選択します。
3. [1.2 の権限表](#権限) のロールが継承を含めて表示されることを確認します。`roleAssignments/write` を持つロールが無い場合は 次の章に進まず [1.5](#15-うまくいかない場合) に従います。

### Log Analytics ワークスペース

1. Azure portal の検索ボックスに「ログ分析」と入力し、[Log Analytics ワークスペース] を選択します。
2. [作成] を選択します。
3. [基本] タブで下表の値を入力します。

| 項目 | 値 |
|---|---|
| サブスクリプション | 検証用サブスクリプション |
| リソース グループ | `rg-agentgov-<略号>-run1` |
| 名前 | `law-agentgov-<略号>-run1` |
| リージョン | Japan East |

4. [次へ: タグ] を選択し、タグ 3 つ（`purpose`・`run`・`operator`）を入力します。
5. [確認と作成] を選択し、[作成] を選択します。
6. 作成後にワークスペースを開き、左側のナビゲーションの [設定] から [使用とコストの見積もり] を選択します。
7. 上部の [データ保持] を選択し、保持期間が 30 日であることを確認して [OK] を選択します。

> **補足** 既定の従量課金制（Analytics Logs）は 31 日分の保持が取り込み価格に含まれるため、30 日未満にしても費用は下がりません。既定の 30 日のままにします。第6章では診断設定と Application Insights がこのワークスペースを参照します。

8. ワークスペースの [概要] にある [要点] の [JSON ビュー] を選択し、上部に表示されるリソース ID を控えます。
9. 控えた ID を `.env` の `LOG_ANALYTICS_RESOURCE_ID` に記録します（作成済みの `.env` に追記）。

### 予算アラート

予算は RG スコープに作り、実績 50%・80%・100% と予測 100% でメール通知します。

1. リソースグループの左側のナビゲーションから [予算] を選択します。
2. [追加] を選択します。
3. [予算を作成する] で下表の値を入力します。

| 項目 | 値 |
|---|---|
| スコープ | `rg-agentgov-<略号>-run1`（自動で入る） |
| 名前 | `budget-agentgov-<略号>-run1` |
| リセット期間 | 月 |
| 作成日 | 当月 1 日 |
| 有効期限 | 検証期間の終了月末（例 3 か月後） |
| 予算額 | 月予算（USD） |

4. [次へ] を選択し、アラート条件を 4 行入力します。

| 種類 | 予算の % | 通知先 |
|---|---|---|
| 実績 | 50 | 実施者のメールアドレス |
| 実績 | 80 | 同上 |
| 実績 | 100 | 同上 |
| 予測 | 100 | 同上 |

5. 言語に [日本語] を選択し、[作成] を選択します。

> **画面の見え方** [予算] の一覧に作成した予算が表示されます。作成直後は評価前のため、現在の支出は 0 または空欄です。コストは通常 8〜24 時間で反映され、予算は 24 時間ごとに評価されます。しきい値を超えると評価後 1 時間以内にメールが届きます。

> **補足** 予算はハードリミットではなく、しきい値を超えても消費は止まりません。D14 では本人の呼び出しが App Service → Foundry を直接通るため、ツール経路の APIM quota はモデルのトークン量や Azure 全体の費用上限にはなりません。第7章で扱うツール呼び出しの制限と、予算通知・稼働時間・削除予定を分けて管理します。通知メールは `azure-noreply@microsoft.com` から届くため、迷惑メールに振り分けられない設定にします。

> **Note** 要確認: 予算フォームの項目名（[作成日]・[有効期限]・[予算額]・[種類]・[予算の %]）は Learn の本文に引用が無く、画面の想定表記です。初回で実際の表示名に合わせます。

## 1.4. 確認

このセクションで確認するのは 費用・後片付けの確認（C10）のうち「予算通知が設定されていること」です。通知の実受信と、削除後の残存・費用は [第10章](10-cleanup-cost.md) で確認します。

1. リソースグループの左側のナビゲーションから [予算] を選択します。
2. 予算名・金額・リセット期間・アラート条件 4 行と通知先が [1.3](#予算アラート) の表と一致することを確認します。
3. 左側のナビゲーションから [コスト分析] を選択し、スコープがこの RG になっていることを確認します。

> **画面の見え方** [コスト分析] は [累積コスト] のビューで開きます。作成直後はコストが反映されていないため 0 です。翌日以降に日別・サービス別の推移が見えます。

4. Cloud Shell で RG の設定を照合します。

```bash
az group show --name "$AZURE_RESOURCE_GROUP" --query '{name:name,location:location,tags:tags}' --output json
```
実行結果の確認ポイント: `location` が `japaneast`、タグ 4 つが入力どおりであることを確認します。

5. Log Analytics の保持期間を照合します。

```bash
az monitor log-analytics workspace show --resource-group "$AZURE_RESOURCE_GROUP" --workspace-name "$LOG_ANALYTICS_WORKSPACE_NAME" --query '{id:id,retentionInDays:retentionInDays,sku:sku.name}' --output json
```
実行結果の確認ポイント: `retentionInDays` が `30`、`sku` が `PerGB2018`、`id` が `.env` の値と一致することを確認します。

```bash
bash scripts/verify.sh --section 1
```
実行結果の確認ポイント: 現在は C10 が Pending であることを表示し、終了コード 2 で終わります（自動判定はしません）。

[確認項目](../checks/README.md) ごとに実施日・Run・入力・期待結果・実結果・Pass / Fail / Pending を非公開の `evidence/` に記録します。未実施は Pending です。

## 1.5. うまくいかない場合

1. **ポータルにサインインできない、または Cloud Shell が開かない**: 切り分け＝社内 IP からか、MFA を完了したか、ブラウザが `*.console.azure.com` と `*.servicebus.windows.net` に接続できるか。代替＝社内ネットワークから再試行し、ブラウザを変えます。記録＝エラーコードと接続元。元に戻す＝なし（Entra の設定は変更しません）。
2. **画面の項目名が本手順と違う**: 切り分け＝ポータルの表示言語が日本語か（[1.2](#実行環境)）。代替＝日本語に切り替えて再確認し、それでも違う場合は実際の表示名を `evidence/` に記録して Issue で報告します。記録＝画面名・項目名の差分。元に戻す＝なし。
3. **リソースプロバイダーが「登録中」のまま**: 切り分け＝[リソース プロバイダー] の状態列、または `az provider show --namespace <名前空間> --query registrationState --output tsv`。代替＝登録は非同期のため数分待って再確認します。記録＝待った時間。元に戻す＝なし。
4. **`roleAssignments/write` を持つロールが無い**: 切り分け＝[1.2 の権限表](#権限) のどの行が欠けるか。代替＝管理者に RG スコープで所有者かユーザー アクセス管理者の付与を依頼します。付与されるまで次の章には進みません。記録＝依頼日と付与されたロールとスコープ。元に戻す＝Run 終了時に付与を解除するかを管理者と決めます。
5. **予算の作成が失敗する、または [予算] に表示されない**: 切り分け＝(a) サブスクリプション作成から 48 時間以内か (b) 作成日が月初か (c) 通知先メールが空でないか (d) Cost Management のデータ反映待ち（最大 48 時間）か。代替＝(a)〜(c) は値を直して再作成、(d) は翌日に再確認します。記録＝エラーメッセージと再確認日。元に戻す＝なし（RG 削除で予算も消えます）。
6. **Cloud Shell のセッションが切れた（20 分無操作）**: 切り分け＝実行中のコマンドがあったか。代替＝再接続して `cd ~/azure-agent-governance-lab && source .env` を再実行します。記録＝切れた時刻と再開手順。元に戻す＝なし。
7. **Cloud Shell のストレージのマウントが `403 RequestDisallowedByPolicy` で失敗する**: 切り分け＝サブスクリプションの Azure Policy がタグ `ms-resource-usage:azure-cloud-shell` のストレージ作成を拒否しているか。代替＝[ストレージ アカウントは不要]（エフェメラル）で開き、`git clone` と `.env` の作成を毎セッション行います。記録＝拒否した Policy 名。元に戻す＝なし。

## 1.6. 次の操作

専用 RG・予算・Log Analytics を残したまま、第2章へ進みます。通常の削除は第10章で一度だけ行います。途中で終了する場合は [削除と費用](10-cleanup-cost.md) を使います。

## 1.7. 費用

| Excel v3 明細 No | 項目 | 通常月 USD |
|---|---|---:|
| 6 | Log Analytics / Analytics Logs 取り込み | 10.020000 |
| 9 | Entra ID / Managed Identity / RBAC / 基本機能 | 0.000000 |
| 10 | Azure Policy / Cost Management 予算アラート / Activity Log / 基本機能 | 0.000000 |
| 18 | Log Analytics / 保持（30日既定） | 0.000000 |

2026-09-15 の見積り v3 の既定値です。Japan East、原則 32h/月の検証、CSPM は既定 OFF です。No.8 と No.12 は常時／検証日の切替で、二重計上しません。No.6 は 第1章/第6章の共通費です。Cloud Shell のストレージ（5 GB 共有）は明細に含まれておらず、月数十円程度の追加です。見積り保証ではありません。

## 1.8. 本番との差

保持期間・可用性・予算運用は本番要件で決めます。本番の予算はサブスクリプションまたは管理グループのスコープに置き、メール通知ではなく Action Group（運用ツールへの連携）で受けます。Log Analytics は本番では保持期間と閲覧権限を業務要件で定義します。本番の構築はポータル操作ではなく IaC と CI/CD で行い、実行環境は Cloud Shell ではなく閉域接続された踏み台やパイプラインになります。[付録 B](92-appendix-production-diff.md) を参照します。

### 公式テンプレートの固定 (任意)

1. Cloud Shell で固定コミットを確認します。

```bash
cat infra/PINNED_COMMIT.md
```
実行結果の確認ポイント: `FOUNDRY_SAMPLES_COMMIT` と同じ 40 桁の SHA が書かれていることを確認します。

2. 固定版の 41 が取得済みであることを確認します。

```bash
ls "infra/vendor/foundry-samples-${FOUNDRY_SAMPLES_COMMIT}/infrastructure/infrastructure-setup-bicep/41-standard-agent-setup/main.bicep"
```
実行結果の確認ポイント: パスが表示されることを確認します。無い場合は [infra/README.md](../infra/README.md) の取得手順（curl → sha256sum → unzip）で取得します。

### IaC で再現する (任意)

GUI で作ったものと同じ RG 内のリソースを、再現日や 2 回目以降に Cloud Shell から作り直す場合の代替です。本文の主線ではありません。

| 対象 | 代替 |
|---|---|
| Log Analytics ワークスペース | `az monitor log-analytics workspace create --resource-group "$AZURE_RESOURCE_GROUP" --workspace-name "$LOG_ANALYTICS_WORKSPACE_NAME" --location "$AZURE_LOCATION" --sku PerGB2018 --retention-time 30` |
| 予算アラート | [infra/modules/01_budget.bicep](../infra/modules/01_budget.bicep)（`Microsoft.Consumption/budgets@2024-08-01`・RG スコープ）を `az deployment group create --resource-group "$AZURE_RESOURCE_GROUP" --template-file infra/modules/01_budget.bicep --parameters budgetName=... amount=... startDate=... contactEmails=...` で展開 |

> **Note** 要確認: Azure CLI の `az consumption budget` はコマンド群全体が Preview のため使いません。Bicep を RG 直下（`targetScope = 'resourceGroup'`）に配置する完成例は Learn に無く、ARM テンプレートリファレンスの記載に基づいています。任意の再現時に実機確認します。


- 出典: [Azure リソース プロバイダー](https://learn.microsoft.com/ja-jp/azure/azure-resource-manager/management/resource-providers-and-types)（取得日 2026-09-16。D14 に伴う整合修正の根拠）
- 出典: [LLM トークン制限](https://learn.microsoft.com/ja-jp/azure/api-management/llm-token-limit-policy)（取得日 2026-09-16。D14 に伴う整合修正の根拠）
- 出典: [Azure portal でリソース グループを管理する](https://learn.microsoft.com/ja-jp/azure/azure-resource-manager/management/manage-resource-groups-portal)（取得日 2026-09-15）
- 出典: [Azure portal を使用してリソースにタグを付ける](https://learn.microsoft.com/ja-jp/azure/azure-resource-manager/management/tag-resources-portal)（取得日 2026-09-15）
- 出典: [Azure リソース プロバイダーと種類](https://learn.microsoft.com/ja-jp/azure/azure-resource-manager/management/resource-providers-and-types)（取得日 2026-09-15）
- 出典: [Resource providers for Azure services](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-services-resource-providers)（取得日 2026-09-15）
- 出典: [Azure portal でユーザーのアクセスを確認する](https://learn.microsoft.com/ja-jp/azure/role-based-access-control/check-access)（取得日 2026-09-15）
- 出典: [Azure built-in roles for Privileged](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged)（取得日 2026-09-15）
- 出典: [Azure built-in roles for Management and governance](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/management-and-governance)（取得日 2026-09-15）
- 出典: [Foundry Agent Service: environment setup](https://learn.microsoft.com/en-us/azure/foundry/agents/environment-setup)（取得日 2026-09-15）
- 出典: [Standard agent setup](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/standard-agent-setup)（取得日 2026-09-15）
- 出典: [Use your own resources](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/use-your-own-resources)（取得日 2026-09-15）
- 出典: [Role-based access control for Microsoft Foundry](https://learn.microsoft.com/en-us/azure/foundry/concepts/rbac-foundry)（取得日 2026-09-15）
- 出典: [Model availability by region](https://learn.microsoft.com/en-us/azure/foundry/foundry-models/concepts/models-sold-directly-by-azure-region-availability)（取得日 2026-09-15）
- 出典: [Foundry Agent Service limits, quotas, and regions](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/limits-quotas-regions)（取得日 2026-09-15）
- 出典: [Manage and increase quotas](https://learn.microsoft.com/en-us/azure/foundry/how-to/quota)（取得日 2026-09-15）
- 出典: [az cognitiveservices usage](https://learn.microsoft.com/en-us/cli/azure/cognitiveservices/usage)（取得日 2026-09-15）
- 出典: [Log Analytics ワークスペースを作成する](https://learn.microsoft.com/ja-jp/azure/azure-monitor/logs/quick-create-workspace)（取得日 2026-09-15）
- 出典: [データ保持期間を構成する](https://learn.microsoft.com/ja-jp/azure/azure-monitor/logs/data-retention-configure)（取得日 2026-09-15）
- 出典: [Log Analytics ワークスペースの削除と復旧](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/delete-workspace)（取得日 2026-09-15）
- 出典: [Azure Monitor Logs cost calculations and pricing](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/cost-logs)（取得日 2026-09-15）
- 出典: [az monitor log-analytics workspace](https://learn.microsoft.com/en-us/cli/azure/monitor/log-analytics/workspace)（取得日 2026-09-15）
- 出典: [チュートリアル: 予算を作成して管理する](https://learn.microsoft.com/ja-jp/azure/cost-management-billing/costs/tutorial-acm-create-budgets)（取得日 2026-09-15）
- 出典: [クイック スタート: コスト分析を使用する](https://learn.microsoft.com/ja-jp/azure/cost-management-billing/costs/quick-acm-cost-analysis)（取得日 2026-09-15）
- 出典: [Microsoft.Consumption/budgets（ARM テンプレートリファレンス）](https://learn.microsoft.com/en-us/azure/templates/microsoft.consumption/budgets)（取得日 2026-09-15）
- 出典: [az consumption budget](https://learn.microsoft.com/en-us/cli/azure/consumption/budget)（取得日 2026-09-15）
- 出典: [Azure portal の設定を管理する](https://learn.microsoft.com/ja-jp/azure/azure-portal/set-preferences)（取得日 2026-09-15）
- 出典: [Azure Cloud Shell overview](https://learn.microsoft.com/en-us/azure/cloud-shell/overview)（取得日 2026-09-15）
- 出典: [Azure Cloud Shell features and tools](https://learn.microsoft.com/en-us/azure/cloud-shell/features)（取得日 2026-09-15）
- 出典: [Azure Cloud Shell の使用を開始する（エフェメラル）](https://learn.microsoft.com/ja-jp/azure/cloud-shell/get-started/ephemeral)（取得日 2026-09-15）
- 出典: [Get started with Azure Cloud Shell (new storage)](https://learn.microsoft.com/en-us/azure/cloud-shell/get-started/new-storage)（取得日 2026-09-15）
- 出典: [Persist files in Azure Cloud Shell](https://learn.microsoft.com/en-us/azure/cloud-shell/persisting-shell-storage)（取得日 2026-09-15）
- 出典: [Azure Cloud Shell FAQ and troubleshooting](https://learn.microsoft.com/en-us/azure/cloud-shell/faq-troubleshooting)（取得日 2026-09-15）
- 出典: [Deploy Cloud Shell in a virtual network（標準の Cloud Shell が Microsoft ネットワークで動く記述）](https://learn.microsoft.com/en-us/azure/cloud-shell/vnet/overview)（取得日 2026-09-15）
- 出典: [Sign in with Azure CLI（Cloud Shell の自動サインイン・MFA）](https://learn.microsoft.com/en-us/cli/azure/authenticate-azure-cli)（取得日 2026-09-15）
- 出典: [Sign in to a Linux VM with Microsoft Entra ID（Cloud Shell と条件付きアクセスの記述）](https://learn.microsoft.com/en-us/entra/identity/devices/howto-vm-sign-in-azure-ad-linux)（取得日 2026-09-15）
- 出典: [foundry-samples 41-standard-agent-setup README（固定コミット）](https://github.com/microsoft-foundry/foundry-samples/blob/58e4127567f7e9afcf0145d874df890284ca5faf/infrastructure/infrastructure-setup-bicep/41-standard-agent-setup/README.md)（取得日 2026-09-15）


---

前へ: [事前確認](00-before-start.md) / 次へ: [Key Vault を準備する](02-key-vault.md) / [トップに戻る](../README.md)
