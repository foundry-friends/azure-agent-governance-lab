# 1. 準備と土台

進め方: 第0章のサインイン・ロール・命名の確認後、この章を上から実施します。

この章では、①ポータルと Cloud Shell の準備 → ②権限・利用条件の確認 → ③設定ファイル → ④リソースグループ → ⑤Log Analytics → ⑥予算アラートの順に進めます。各手順の「確認」で期待する状態になったことを確かめてから次へ進みます。

> **画面の見え方** 「ポータル上部の検索」は Azure 全体のサービスを探す欄、「一覧の検索」は開いた画面内の対象を絞る欄です。左側メニューが折りたたまれている場合は展開してから項目を探します。手順中の `<略号>` などは自分の値に置き換え、山括弧は入力しません。画面と手順が違って進めない場合は、[1.5](#15-うまくいかない場合) に従って差分を記録します。

> **Note** 状態: ドラフト（Learn 2026-09 時点の記述に基づく・未実行）

> **Note** 所要時間の目安: RG・Log Analytics・予算の作成部分は 0.5h の参考値です。Cloud Shell の準備・権限確認・リソースプロバイダーの登録・モデルの登録も、初回の定例で順に確認します。メンバーの前日までの作業は前提にせず、終わらなければ次回へ引き継ぎます。記録先は検証チームから案内された共有 Excel です。

> **Note** このリポジトリでは、リソースの作成と設定変更は **Azure portal の GUI** で行います。登録する設定を自分の目で確かめながら進めるためです。コマンドは **Azure Cloud Shell（Bash）** で実行し、用途は設定の確認・照合と、GUI に無い操作の代替に限ります（[1.2](#実行環境)）。

## 1.1. 目的

統制層⑩（コスト・クォータ）と⑦（監査）の土台を作ります。具体的には、実施者ごとの専用リソースグループ、命名とタグ、予算アラート、Log Analytics ワークスペース、確認用の実行環境（Cloud Shell）と公式テンプレートの版の固定です。この章で作る土台は第2章以降で参照します。Azure Policy・Defender・診断設定はここでは作らず、第6章と第9章で扱います。

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

1. ブラウザで [Azure portal](https://portal.azure.com) を開きます。
2. 第0章で確認した検証用の個人アカウントでサインインします。
3. [第0章 0.2](00-before-start.md#02-azure-portal-にサインインしid-を控える) で日本語表示にしたことを確認します。

> **補足** Cloud Shell のコンテナーは Microsoft のネットワークで動き、**送信元 IP は社内 IP ではありません**。リソースの作成や設定の照合（ARM）は影響を受けませんが、社内 IP 許可リストを付けたリソースのデータ面（Blob の読み書き・Key Vault のシークレット取得）は Cloud Shell からは拒否されます。D14 のツール用 APIM は ID で制限するため、Cloud Shell からの拒否を IP 制限の結果と決めつけません。データ面の試験は社内 PC のブラウザ（ポータル・Foundry ポータル・第7章の呼び出しアプリ）から行います。各リソースの許可リストには、事前に確認した社内公開 IP を使います。

### Cloud Shell の準備（事前確認）

1. 社内ネットワークから Azure portal にサインインします。
2. 上部ナビゲーションの [Cloud Shell] アイコンを選択します。
3. 初回のシェル選択画面で [Bash] を選択します。
4. ストレージ選択画面で [ストレージ アカウントのマウント] を選択します。
5. サブスクリプションの一覧で検証用サブスクリプションを選択します。
6. [適用] を選択します。
7. 部門で自動作成を使うと決めた場合は、[ストレージ アカウントを作成します] を選択します。
8. [次へ] を選択します。
9. 作成処理が終わり、Cloud Shell にコマンドを入力できる Bash のプロンプトが表示されるまで待ちます。

> **Note** すでに Cloud Shell を利用している場合は、初回のストレージ選択画面が出ないことがあります。既存ストレージを作り直さず、シェルが Bash であることを確認して下の版確認へ進みます。PowerShell の場合はシェル切替メニューから [Bash] を選択します。既存ストレージを使う運用の場合は、下の配置先の確認を先に済ませます。

> **画面の見え方** ストレージをマウントすると、Cloud Shell がストレージ アカウントとファイル共有（5 GB）を作り、`$HOME` の内容を次回以降も保持します。このストレージ アカウントには `ms-resource-usage:azure-cloud-shell` のタグが付き、Run の RG とは別のリソースグループに作られます。Run 終了時に削除しません。

> **Note** 要確認: 部門共有サブスクリプションで Cloud Shell のストレージをどのリソースグループに置くか（既定の自動作成か、[既存のストレージ アカウントを選択] で `rg-<略号>-shell-01`（[第0章 0.4](00-before-start.md#名前の制約と例外) の例外）（検証用 RG と重複しない連番の例）に自前で作るか）は事前確認で決めます。Azure Policy でストレージ作成が拒否される（`403 RequestDisallowedByPolicy`）場合は [ストレージ アカウントは不要]（エフェメラル）で進めますが、セッション終了でファイルが消えるため `.env` を毎回作り直します。

10. Cloud Shell の入力欄に次のコマンドを貼り付け、Enter を押します。

```bash
az version
```
実行結果の確認ポイント: `azure-cli` の版が表示されることを確認し、`evidence/` に記録します（Cloud Shell は月次更新のため）。

11. ポータル上部の検索に「サブスクリプション」と入力します。
12. 検索結果の [サブスクリプション] を選択します。
13. 一覧から検証用サブスクリプションを選択します。
14. [概要] に表示されたサブスクリプション ID を非公開の作業メモに控えます。
15. Cloud Shell に戻り、`<subscription-id>` を控えた ID に置き換えて次を実行します。

```bash
az account set --subscription "<subscription-id>"
```
実行結果の確認ポイント: エラーが出ないことを確認します。設定は `~/.azure/azureProfile.json` に保存され、次のセッションでも有効です。

16. 次のコマンドで既定のサブスクリプションとテナントを照合します。

```bash
az account show --output table
```
実行結果の確認ポイント: 表示されたサブスクリプションとテナントが検証用のものと一致することを確認します。

> **Note** Cloud Shell は自動でサインイン済みのため `az login` は不要です。`Audience ... is not a supported MSI token audience` というエラーが出るコマンドだけ、`az login --use-device-code` で再サインインします。Cloud Shell はアイドル 20 分でセッションが切れます。

> **Note** 要確認: Learn には「デバイス準拠やハイブリッド参加を要求する条件付きアクセスは Cloud Shell では非対応」と記載があります。社内の条件付きアクセスがネームドロケーション（IP）だけであれば影響しない想定ですが、事前確認で Cloud Shell が開けることを確認します。

### 手順リポジトリの取得

1. ブラウザでチームから案内された GitHub の手順リポジトリを開きます。
2. URL の `github.com/` の次の部分から所有者名を確認します（以下の `<owner>` に使用）。
3. Private の場合は、Cloud Shell で次を実行します（Public の場合は手順6へ進みます）。

```bash
gh auth login --hostname github.com --git-protocol https --web
```
実行結果の確認ポイント: ブラウザ認証の案内と一時コードが表示されることを確認します。Git の認証にも使うか質問された場合は Yes を選択します。

4. ターミナルが案内した URL をブラウザで開き、一時コードを入力して GitHub の認証を完了します。
5. Cloud Shell に戻り、認証成功の表示を確認します。
6. 取得先を Cloud Shell のホームディレクトリに移します。

```bash
cd ~
```
実行結果の確認ポイント: エラーなくプロンプトに戻ることを確認します。

7. `<owner>` を手順2で確認した所有者名に置き換えて実行します。

```bash
git clone --branch develop "https://github.com/<owner>/azure-agent-governance-lab.git"
```
実行結果の確認ポイント: ファイルの取得が完了し、認証エラーや `Repository not found` が出ていないことを確認します。

8. 取得したディレクトリへ移動します。

```bash
cd ~/azure-agent-governance-lab
```
実行結果の確認ポイント: エラーなく移動できることを確認します。以降のコマンドはこのディレクトリで実行します。

9. 手順書の版を確認します。

```bash
git status --short --branch
```
実行結果の確認ポイント: ブランチが `develop` であることを確認します。

10. 検証に使うコミットを控えます。

```bash
git rev-parse HEAD
```
実行結果の確認ポイント: 表示された SHA を非公開の証跡に記録し、検証チームの指定版と照合します。

> **Note** すでに同名ディレクトリがある場合は再度 clone せず、手順8から版と変更の有無を確認します。指定版と異なる場合は担当者に確認してから進めます。自分の `.env` や証跡を削除して取り直しません。

### 権限

必要なロールは [第0章 0.3](00-before-start.md#03-自分のロールを確認する) で確認済みです。RG を作った後に [1.3 RG スコープの権限の再確認](#rg-スコープの権限の再確認) で RG スコープを確認します。

### リソースプロバイダー

| 名前空間 | 使うセクション | 出典 |
|---|---|---|
| Microsoft.CognitiveServices | 第4章（Foundry） | Foundry の BYO ページ |
| Microsoft.KeyVault | 第2章 | 同上 |
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
4. 該当行の登録状態を確認します。
5. 未登録の場合は、その行を選択します（登録済みの場合は手順 8 へ進みます）。
6. 上部の [登録] を選択します。
7. [更新] を選択して状態を再確認します。
8. 検索欄を次の名前空間に入れ替え、初回で使う上表の名前空間（第7章・第9章の行を除く）について手順 3〜7 を繰り返します。

> **画面の見え方** 状態の列が [登録解除] から「登録中」に変わり、数分で [登録済み] になります。登録はリージョンごとに順に進むため、「登録中」のままでも次の作業を止める必要はありません。

> **補足** 登録には `/register/action` 権限が必要で、共同作成者と所有者に含まれます。テンプレートのデプロイ時に使う名前空間は自動登録されますが、監視やセキュリティのように「テンプレートに書かれていない補助リソース」の名前空間は手動で登録します。Learn は「使う準備ができてから登録する」ことを勧めているため、第7章・第9章の名前空間は該当セクションで登録します。

9. Cloud Shell で登録状態を照合します。

```bash
az provider list --query "[?registrationState!='Registered'].{Provider:namespace, Status:registrationState}" --output table
```
実行結果の確認ポイント: 上表の初回の名前空間が表示されない（すべて `Registered`）ことを確認します。

### モデルとクォータ

このリポジトリのモデルは gpt-5-mini（バージョン 2025-08-07・Global Standard）です。Learn のリージョン別提供表で Japan East（`japaneast`）の Global Standard に提供があります。

1. 別のブラウザタブで [Microsoft Foundry](https://ai.azure.com) を開きます。
2. 検証用アカウントでサインインします。
3. [New Foundry] のトグルがオンであることを確認します。
4. 検証用サブスクリプションの既存プロジェクトを利用できる場合は、左上のプロジェクト名で対象が正しいことを確認します。
5. **右上**のナビゲーションから [Manage] を選択します。
6. 左側メニューの [Quota] を選択します。
7. [Token per minute] タブを選択します。
8. Japan East・gpt-5-mini・Global Standard に対応する割当と使用量を確認します。
9. 利用可能な残量を非公開の証跡に控えます。

> **Note** この GUI 手順の公式前提には Foundry project が含まれます。初回でまだプロジェクトがなく、作成画面が表示される場合は、確認のためだけに新規作成せず、下の Cloud Shell でサブスクリプションのクォータを確認します。GUI の照合は第4章のプロジェクト作成後に行います。画面に出ないだけでクォータなしとは判断しません。

> **Note** gpt-5 系のモデルは Learn に「登録（registration）が必要」と明記されています。事前確認で登録の要否と手続きを確認し、間に合わない場合は第4章の「うまくいかない場合」で代替モデルを選びます。

10. Cloud Shell で使用量と上限を照合します。

```bash
az cognitiveservices usage list --location japaneast --output table
```
実行結果の確認ポイント: gpt-5-mini の Global Standard に相当する行があり、上限（limit）と使用量を確認します。上限が 0 でなくても使い切っていれば追加デプロイできないため、必要な残量があるかを確認します。

> **Note** 要確認: この出力で gpt-5-mini を表す `name.value` の形式は Learn に例がありません。初回で実物を記録します。

### 社内 IP と Entra の確認（事前確認）

#### 既存の Entra 条件付きアクセスを確認する

この操作は、サインイン ログと条件付きアクセスポリシーの両方を閲覧できる管理担当者が行います。Learn では両方を閲覧できる最小の組み込みロールとして [セキュリティ閲覧者] が示されています。Azure RG の Owner 権限だけでは閲覧できない場合があります。

1. 実施者が直前に Azure portal へサインインした時刻と使用アカウントを管理担当者に伝えます。
2. 管理担当者が [Microsoft Entra 管理センター](https://entra.microsoft.com) にサインインします。
3. 対象が [第0章 0.2](00-before-start.md#02-azure-portal-にサインインしid-を控える) で控えたテナント ID の検証用テナントであることを確認します。
4. 左側メニューの [Entra ID] を開きます。
5. [監視と正常性]（[Monitoring & health]。日本語資料では「監視とヘルス」の表記もあります）を開きます。
6. [サインイン ログ] を選択します。
7. 日付の範囲を、手順 1 のサインイン時刻を含む期間に絞ります。
8. ユーザーのフィルターで検証用ユーザーを指定します。
9. 時刻・ユーザー・対象アプリケーションを照合し、該当するサインインの行を選択します。
10. 詳細画面の [条件付きアクセス] タブを選択します。
11. 適用されたポリシー名と、それぞれの結果を確認します。
12. 管理担当者に、対象ユーザー・対象リソース・場所・MFA・端末条件を既存ポリシーと照合してもらいます。
13. 管理担当者に CAE の適用条件を確認します。
14. 下表の内容を手元の非公開メモに記録します。
15. 条件付きアクセスや CAE の設定は変更せずに検証することをチームで共有します。

| 記録項目 | 確認する内容 |
|---|---|
| 対象イベント | 確認日時とタイムゾーン、ユーザー、対象アプリケーション／リソース |
| サインイン | 成功／失敗と、表示された失敗理由 |
| 条件付きアクセス | 各ポリシーの適用結果。未適用やレポート専用を強制適用と取り違えない |
| 既存の利用条件 | 許可する接続元、MFA、端末要件、Cloud Shell 利用への制約 |
| 確認者と保留 | 管理担当者の確認日、分からなかった点と次の確認日 |

> **Note** 要確認: 実環境の表示名と閲覧可否は初回で照合します。ログが見つからない場合は、テナント・期間・ユーザー・アプリケーションを見直します。ポリシー欄が空でも「制限なし」とせず、管理担当者に確認します。閲覧できない実施者は、管理担当者の確認結果を受け取ればよく、全員がこの管理画面を開く必要はありません。

> **補足** 既存ポリシーと CAE の設定は変更しません。CAE（継続的アクセス評価）は対象サービスとクライアントに依存します。サインインが成功したことだけをもって、Foundry のトークン失効やリソース側の IP 制限を確認できたとは見なしません。ネットワーク境界・送信先の確認（C08）の動作試験は、アプリまで作成した後の第8章で行います。

#### ネットワークの方針を揃える

1. ネットワーク担当者から、検証用 PC が Azure へ接続するときの公開 IPv4 CIDR を受け取ります。
2. PC 内のプライベート IP ではなく、会社の出口に相当する公開 IP であることを担当者に確認します。
3. プロキシ等により出口が複数ある場合は、今回の接続で使う範囲を確認します。
4. 第8章で使う許可外接続元を、会社の利用ルールに沿って担当者と決めます。
5. 同じユーザー・同じ対象・同じ操作で接続元だけを比較できるか確認します。
6. CIDR・接続元・利用条件を手元の非公開メモに記録します。

> **Note** 許可外接続元で既存の条件付きアクセスによりサインイン自体が拒否される場合は、その事実を記録します。それだけでは対象リソースの IP 制限による拒否を確認できません。比較経路が用意できない場合は C08 の該当試験を Pending とし、既存ポリシーを緩めません。

[1.3 で `.env` を用意するとき](#設定ファイルenv) に、CIDR を `ALLOWED_IP_RANGES` へ JSON 配列で転記します。この段階では、未作成のリソースに対する設定や呼び出し試験は行いません。各リソースの IP 制限と認証は、それぞれを作成する章で設定します。

| 方針 | 適用 |
|---|---|
| 人の入口 | 社内 IP に限定。認証は Entra ID |
| App Service → Foundry | 第7章で送信 VNet 統合＋サービス エンドポイントを追加。Foundry は社内 IP 規則と統合サブネットの VNet 規則を併用 |
| ツール用 APIM | ネットワーク上は公開し、Entra の許可主体で制限。社内 IP のみの規則をツール API 全体に適用しない |
| エージェントのツール | 第4章ではツールなし。第7章で許可先だけを追加 |
| サービス間通信 | 社内 PC の IP と異なるため、各経路を確認 |
| 変更できない前提 | Agent 365 なし、既存の条件付きアクセスを変更しない |

> **Note** 要確認: 第4章では Cosmos DB 接続の Preview 例外と、BYO への接続設定の根拠を確認済みですが、実機の到達は未確認です。第3・4・7章に残る到達・認証の確認事項は各章の条件に従います。事前確認だけで「全章が通る」とせず、資料上の保留と自分の権限不足を区別して記録します。

## 1.3. 構築

### 命名と入力値

このセクションで入力する値を先に決めます。実在の ID・メールアドレス・社内 IP は `.env` にだけ書き、公開ファイルには書きません。

| 項目 | 値 |
|---|---|
| 検証者略号 | 英小文字で、[第0章 0.4](00-before-start.md#04-命名規則を決める) の名前の制約を満たす長さ（例 `funato`） |
| リソースグループ名 | `rg-<略号>-dev-01` |
| リージョン | Japan East |
| Log Analytics ワークスペース名 | `log-<略号>-dev-01` |
| 予算名 | `budget-<略号>-dev-01` |
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

3. エディターで、下表に対応する変数の `=` の右側を自分の値に置き換えます。
4. 値を囲む引用符を残し、`=` の前後に空白を入れていないことを確認します。
5. Ctrl+S で保存します。
6. Ctrl+Q でエディターを閉じます。

| 項目 | 値 |
|---|---|
| AZURE_SUBSCRIPTION_ID・AZURE_TENANT_ID | 前述の手順で実行した `az account show` の ID と TenantId。ポータルで確認した検証用サブスクリプションと照合済みの値 |
| OPERATOR_CODE | 検証者略号 |
| AZURE_RESOURCE_GROUP | `rg-<略号>-dev-01` |
| AZURE_LOCATION | `japaneast` |
| AZURE_DEPLOYMENT_NAME | デプロイ名（例 `deploy-<略号>-dev-01`） |
| LOG_ANALYTICS_WORKSPACE_NAME | `log-<略号>-dev-01` |
| LOG_ANALYTICS_RESOURCE_ID | 今はプレースホルダーを残し、ワークスペース作成後に既存行を置換 |
| BUDGET_AMOUNT_USD・BUDGET_CONTACT_EMAIL・BUDGET_START_DATE | 作成する予算の値 |
| DELETE_AFTER | 削除予定日（`YYYY-MM-DD`） |
| ALLOWED_IP_RANGES | 社内公開 IPv4 CIDR の JSON 配列（例 `'["203.0.113.0/24"]'`。全許可は不可） |

> **補足** まだ作成していないリソースの ID はプレースホルダーのまま残します。作成する工程で追記します。

7. Cloud Shell のターミナルで設定を読み込みます。

```bash
source .env
```
実行結果の確認ポイント: 構文エラーが表示されないことを確認します。API キーや接続文字列は記入しません。

8. 読み込んだ RG 名を確認します。

```bash
echo "$AZURE_RESOURCE_GROUP"
```
実行結果の確認ポイント: 自分の `rg-<略号>-dev-01` が表示され、プレースホルダーが残っていないことを確認します。

> **Note** `.env` と `*.local.json` は `.gitignore` 済みで、コミットしません。

### リソースグループ

1. Azure portal で [リソース グループ] を検索して選択します。
2. [作成] を選択します。
3. [基本] タブで下表の値を入力します。

| 項目 | 値 |
|---|---|
| サブスクリプション | 検証用サブスクリプション |
| リソース グループ | `rg-<略号>-dev-01` |
| リージョン | Japan East |

4. [確認および作成] を選択します。
5. 確認画面でサブスクリプション・RG 名・リージョンを照合します。
6. 検証に成功したら [作成] を選択します。
7. ポータル上部の検索から [リソース グループ] を開きます。
8. 一覧上部の [更新] を選択します。
9. 作成した `rg-<略号>-dev-01` を選択します。
10. [概要] で名前・サブスクリプション・リージョンを確認します。
11. [概要] の [タグの追加] を選択します。
12. 下表の名前と値を 1 組ずつ入力します。

| 名前 | 値 |
|---|---|
| purpose | `agent-governance-lab` |
| run | `1` |
| operator | 自分の検証者略号 |
| deleteAfter | 合意した削除予定日（`YYYY-MM-DD`） |

13. [保存] を選択します。
14. [概要] に戻り、4 つのタグが表示されることを確認します。

> **Note** 組織の Policy で作成時のタグが必須の場合は、作成画面の [タグ] で上表を入力してから [確認および作成] へ進みます。作成時の画面に該当欄がなく拒否される場合は、エラーを記録して管理者へ相談します。

### RG スコープの権限の再確認

1. 作成したリソースグループの左側のナビゲーションから [アクセス制御 (IAM)] を選択します。
2. [アクセスの確認] タブを選択します。
3. [マイ アクセスの表示] を選択します。
4. RG 内の作成・ロール割り当てに必要な権限を、[第0章 0.3 の権限表](00-before-start.md#03-自分のロールを確認する) と照合します。サブスクリプションだけで確認するクォータ閲覧権限とは分けて判定します。`roleAssignments/write` を持つロールが無い場合は次の章に進まず [1.5](#15-うまくいかない場合) に従います。

### Log Analytics ワークスペース

1. Azure portal の検索ボックスに「ログ分析」と入力し、[Log Analytics ワークスペース] を選択します。
2. [作成] を選択します。
3. [基本] タブで下表の値を入力します。

| 項目 | 値 |
|---|---|
| サブスクリプション | 検証用サブスクリプション |
| リソース グループ | `rg-<略号>-dev-01` |
| 名前 | `log-<略号>-dev-01` |
| リージョン | Japan East |

4. [タグ] タブを開きます。
5. RG と同じ `purpose`・`run`・`operator` の 3 組を入力します。
6. [確認と作成] を選択します。
7. 対象が自分の RG、リージョンが Japan East であることを確認します。
8. [作成] を選択します。
9. デプロイが完了するまで待ちます。
10. ポータル上部の検索から [Log Analytics ワークスペース] を開きます。
11. 一覧から `log-<略号>-dev-01` を選択します。
12. 左側メニューの [設定] にある [使用とコストの見積もり] を選択します。
13. ページ上部の [データ保持] を選択します。
14. 日数が 30 日であることを確認します（異なる場合はスライダーを 30 日に合わせます）。
15. [OK] を選択します。
16. 再度 [データ保持] を開き、30 日が保存されていることを確認します。

> **補足** 既定の従量課金制（Analytics Logs）は 31 日分の保持が取り込み価格に含まれるため、30 日未満にしても費用は下がりません。既定の 30 日のままにします。第6章では診断設定と Application Insights がこのワークスペースを参照します。

17. Cloud Shell で次の読み取りコマンドを実行します。

```bash
az monitor log-analytics workspace show --resource-group "$AZURE_RESOURCE_GROUP" --workspace-name "$LOG_ANALYTICS_WORKSPACE_NAME" --query id --output tsv
```
実行結果の確認ポイント: `/subscriptions/` から始まり、末尾が自分のワークスペース名であるリソース ID が 1 行表示されることを確認します。ワークスペース ID（GUID）とは別の値です。

18. Cloud Shell で設定ファイルを開きます。

```bash
code .env
```
実行結果の確認ポイント: 作成済みの `.env` が開くことを確認します。

19. `LOG_ANALYTICS_RESOURCE_ID` の既存行の値を、手順 17 のリソース ID に置き換えます。
20. Ctrl+S で保存します。
21. Ctrl+Q でエディターを閉じます。
22. 更新した値をターミナルに読み込みます。

```bash
source .env
```
実行結果の確認ポイント: エラーが出ないことを確認します。値の一致は [1.4](#14-確認) で照合します。

### 予算アラート

予算は RG スコープに作り、実績 50%・80%・100% と予測 100% でメール通知します。

1. ポータル上部の検索から [リソース グループ] を開きます。
2. 一覧から自分の `rg-<略号>-dev-01` を選択します。
3. 左側メニューの [予算] を選択します。
4. ページ上部のスコープが自分の RG であることを確認します。
5. [追加] を選択します。
6. [予算を作成する] で、スコープが変わっていないことを確認します。
7. 下表の値を入力します。

| 項目 | 値 |
|---|---|
| スコープ | `rg-<略号>-dev-01`（自動で入る） |
| 名前 | `budget-<略号>-dev-01` |
| リセット期間 | 月 |
| 作成日 | 当月 1 日 |
| 有効期限 | 検証期間の終了月末（例 3 か月後） |
| 予算額 | 画面に表示された通貨で上長と合意した月予算 |
| フィルター | 追加しない（自分の RG 全体を対象にする） |

> **Note** 入力前に予算額欄の通貨を確認します。見積りと `.env` の `BUDGET_AMOUNT_USD` は USD です。画面が JPY などの場合は USD の数値をそのまま入力せず、担当者とその通貨の予算額を決めて非公開に記録します。USD 用の変数へ JPY 額を入れません。

8. [次へ] を選択します。
9. アラート条件の 1 行目で実績に相当する種類を選択します。
10. しきい値に `50` を入力します（`0.5` ではありません）。
11. 続く行にも種類としきい値を入力し、下表の 4 条件にします。

| 種類 | 予算の % |
|---|---|
| 実績（Actual） | 50 |
| 実績（Actual） | 80 |
| 実績（Actual） | 100 |
| 予測（Forecasted） | 100 |

12. 通知先メールアドレスの入力欄に、合意した実施者のメールアドレスを入力します。
13. 通知先が 4 条件に適用されることを確認します。
14. 通知メールの言語で [日本語] を選択します。
15. スコープ・予算額・期間・4 条件・通知先を見直します。
16. [作成] を選択します。
17. [予算] の一覧に作成した予算名が表示されることを確認します。
18. 作成した予算名を選択し、保存された金額・期間・アラート設定を照合します。

> **画面の見え方** 通知先はアラートの種類・割合とは別の入力欄です。行ごとにメールアドレスを入力する画面とは限りません。Action Group の選択欄が表示されても、この章ではメール通知だけを設定します。

> **画面の見え方** [予算] の一覧に作成した予算が表示されます。作成直後は評価前のため、現在の支出は 0 または空欄です。コストは通常 8〜24 時間で反映され、予算は 24 時間ごとに評価されます。しきい値を超えると評価後 1 時間以内にメールが届きます。

> **補足** 予算はハードリミットではなく、しきい値を超えても消費は止まりません。D14 では本人の呼び出しが App Service → Foundry を直接通るため、ツール経路の APIM quota はモデルのトークン量や Azure 全体の費用上限にはなりません。第7章で扱うツール呼び出しの制限と、予算通知・稼働時間・削除予定を分けて管理します。通知メールは `azure-noreply@microsoft.com` から届くため、迷惑メールに振り分けられない設定にします。

> **Note** 要確認: 予算フォームの項目名（[作成日]・[有効期限]・[予算額]・[種類]・[予算の %]）は Learn の本文に引用が無く、画面の想定表記です。初回で実際の表示名に合わせます。

## 1.4. 確認

このセクションで確認するのは 費用・後片付けの確認（C10）のうち「予算通知が設定されていること」です。通知の実受信は、検証中に通知条件を満たした場合の結果を記録し、第10章へ引き継ぎます。条件に達していない場合は未発火と記録し、受信試験のために費用を増やしません。削除後の残存・費用は [第10章](10-cleanup-cost.md) で確認します。

1. リソースグループの左側のナビゲーションから [予算] を選択します。
2. 一覧から自分の予算名を選択します。
3. 予算名・通貨・金額・リセット期間・アラート条件 4 行と通知先を [1.3](#予算アラート) の入力内容と照合します。
4. 自分のリソースグループの画面へ戻ります。
5. 左側メニューの [コスト分析] を選択します。
6. 表示されたスコープが自分の RG になっていることを確認します。

> **画面の見え方** [コスト分析] は [累積コスト] のビューで開きます。作成直後はコストが未反映の場合があります。0 円とデータなしを区別し、第10章の反映待ちの扱いに沿って日別・サービス別の推移を確認します。

7. Cloud Shell で RG の設定を照合します。

```bash
az group show --name "$AZURE_RESOURCE_GROUP" --query '{name:name,location:location,tags:tags}' --output json
```
実行結果の確認ポイント: `location` が `japaneast`、タグ 4 つが入力どおりであることを確認します。

8. Log Analytics の保持期間を照合します。

```bash
az monitor log-analytics workspace show --resource-group "$AZURE_RESOURCE_GROUP" --workspace-name "$LOG_ANALYTICS_WORKSPACE_NAME" --query '{id:id,retentionInDays:retentionInDays,sku:sku.name}' --output json
```
実行結果の確認ポイント: `retentionInDays` が `30`、`sku` が `PerGB2018`、`id` が `.env` の値と一致することを確認します。

9. 確認スクリプトの現在の判定状態を確認します。

```bash
bash scripts/verify.sh --section 1
```
実行結果の確認ポイント: 現在は C10 が Pending であることを表示し、終了コード 2 で終わります（自動判定はしません）。

[確認項目](../checks/README.md) ごとに実施日・Run・入力・期待結果・実結果・Pass / Fail / Pending を非公開の `evidence/` に記録します。未実施は Pending です。

### この章の完了条件

| 確認対象 | 次へ進める状態 |
|---|---|
| 社内接続 | 社内公開 IPv4 CIDR と既存のアクセス条件を確認済み。未確定なら依存する作成・試験を停止 |
| 許可外接続元 | 比較条件を確認済み、または手配担当と期限を記録済み。未手配の C08 試験は Pending とし、構築とは分けて管理 |
| Cloud Shell と手順の版 | Bash で開ける。検証用サブスクリプション・テナント・指定コミットを照合済み |
| 権限・プロバイダー | 直後の工程に必要な権限と登録状態を確認済み。不足は対象工程を停止して記録済み |
| モデル | クォータを確認済み、または特定できない理由・担当・第4章着手前の確認事項を記録済み |
| リソースグループ | 自分の RG が Japan East に存在し、タグ 4 つが一致 |
| Log Analytics | 自分の RG に存在し、保持 30 日・従量課金制・リソース ID が一致 |
| 予算 | 自分の RG スコープで金額・通貨・期間・4 条件・通知先が保存済み |
| 記録 | 実施結果と保留事項を記録済み。未実施を Pass にしていない |

## 1.5. うまくいかない場合

1. **ポータルにサインインできない、または Cloud Shell が開かない**: 切り分け＝社内 IP からか、MFA を完了したか、ブラウザが `*.console.azure.com` と `*.servicebus.windows.net` に接続できるか。代替＝社内ネットワークから再試行し、ブラウザを変えます。記録＝エラーコードと接続元。元に戻す＝なし（Entra の設定は変更しません）。
2. **画面の項目名が本手順と違う**: 切り分け＝ポータルの表示言語が日本語か（[1.2](#実行環境)）。代替＝日本語に切り替えて再確認し、それでも違う場合は実際の表示名を非公開の `evidence/` に残し、共有 Excel に記録します。手順修正が必要なら GitHub Issue へ転記します。記録＝画面名・項目名の差分。元に戻す＝なし。
3. **リソースプロバイダーが「登録中」のまま**: 切り分け＝[リソース プロバイダー] の状態列、または `az provider show --namespace <名前空間> --query registrationState --output tsv`。代替＝登録は非同期のため数分待って再確認します。記録＝待った時間。元に戻す＝なし。
4. **`roleAssignments/write` を持つロールが無い**: 切り分け＝[第0章 0.3 の権限表](00-before-start.md#03-自分のロールを確認する) のどの行が欠けるか。代替＝管理者に RG スコープで所有者かユーザー アクセス管理者の付与を依頼します。付与されるまで次の章には進みません。記録＝依頼日と付与されたロールとスコープ。元に戻す＝Run 終了時に付与を解除するかを管理者と決めます。
5. **予算の作成に失敗する、または [予算] に表示されない**: 切り分け＝(a) サブスクリプション作成から 48 時間以内か (b) 作成日が月初か (c) 通知先メールが空でないか (d) Cost Management のデータ反映待ち（最大 48 時間）か。代替＝(a)〜(c) は値を直して再作成、(d) は翌日に再確認します。記録＝エラーメッセージと再確認日。元に戻す＝なし（RG 削除で予算も消えます）。
6. **Cloud Shell のセッションが切れた（20 分無操作）**: 切り分け＝実行中のコマンドがあったか。代替＝再接続して `cd ~/azure-agent-governance-lab && source .env` を再実行します。記録＝切れた時刻と再開手順。元に戻す＝なし。
7. **Cloud Shell のストレージのマウントが `403 RequestDisallowedByPolicy` で失敗する**: 切り分け＝サブスクリプションの Azure Policy がタグ `ms-resource-usage:azure-cloud-shell` のストレージ作成を拒否しているか。代替＝[ストレージ アカウントは不要]（エフェメラル）で開き、`git clone` と `.env` の作成を毎セッション行います。記録＝拒否した Policy 名。元に戻す＝なし。

8. **Entra のログを開けない**: 切り分け＝テナントとログ・ポリシーの閲覧権限。代替＝Entra 管理担当者へ確認を依頼します。記録＝担当者の確認結果を非公開で受領します。元に戻す＝なし（既存ポリシーは変更しません）。
9. **CIDR・許可外接続元が未確定**: 切り分け＝[社内 IP と Entra の確認](#社内-ip-と-entra-の確認事前確認) の比較条件。代替＝ネットワーク担当者へ照合・手配を依頼し、独立した準備だけ進めます。記録＝担当・期限と依存する構築の保留、C08 の Pending。元に戻す＝なし（既存のアクセス制限は変更しません）。

## 1.6. 次の操作

専用 RG・予算・Log Analytics を残したまま、第2章へ進みます。通常の削除は第10章で一度だけ行います。途中で終了する場合は [削除と費用](10-cleanup-cost.md) を使います。

## 1.7. 費用

Fabric 容量の費用は既存見積りに含まれません。事前確認済みの容量を使い、利用可否・費用負担・期間は課長判断とします。金額は要見積りです。

| Excel v3 明細 No | 項目 | 通常月 USD |
|---|---|---:|
| 6 | Log Analytics / Analytics Logs 取り込み | 10.020000 |
| 9 | Entra ID / Managed Identity / RBAC / 基本機能 | 0.000000 |
| 10 | Azure Policy / Cost Management 予算アラート / Activity Log / 基本機能 | 0.000000 |
| 18 | Log Analytics / 保持（30 日既定） | 0.000000 |

2026-09-15 の見積り v3 の既定値です。Japan East、原則 32h/月の検証、CSPM は既定 OFF です。No.8 と No.12 は常時／検証日の切替で、二重計上しません。No.6 は第1章/第6章の共通費です。Cloud Shell のストレージ（5 GB 共有）は明細に含まれておらず、月数十円程度の追加です。見積り保証ではありません。

## 1.8. 本番との差

保持期間・可用性・予算運用は本番要件で決めます。本番の予算はサブスクリプションまたは管理グループのスコープに置き、メール通知ではなく Action Group（運用ツールへの連携）で受けます。本番の Log Analytics では、保持期間と閲覧権限を業務要件で定義します。本番の構築はポータル操作ではなく IaC と CI/CD で行い、実行環境は Cloud Shell ではなく閉域接続された踏み台やパイプラインになります。[付録 B](92-appendix-production-diff.md) を参照します。

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


### 出典

- 出典: [継続的アクセス評価](https://learn.microsoft.com/ja-jp/entra/identity/conditional-access/concept-continuous-access-evaluation)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [条件付きアクセスの適用ログ](https://learn.microsoft.com/ja-jp/entra/identity/monitoring-health/how-to-view-applied-conditional-access-policies)（取得日 2026-09-20）
- 出典: [App Service VNet 統合](https://learn.microsoft.com/ja-jp/azure/app-service/overview-vnet-integration)（取得日 2026-09-16。D14 に伴う整合修正の根拠）
- 出典: [Entra アクティビティログへのアクセス](https://learn.microsoft.com/ja-jp/entra/identity/monitoring-health/howto-access-activity-logs)（取得日 2026-09-20）
- 出典: [Azure Cloud Shell エディターの使用](https://learn.microsoft.com/ja-jp/azure/cloud-shell/using-cloud-shell-editor)（取得日 2026-09-19）
- 出典: [GitHub CLI: gh auth login](https://cli.github.com/manual/gh_auth_login)（取得日 2026-09-19）
- 出典: [Azure リソース プロバイダー](https://learn.microsoft.com/ja-jp/azure/azure-resource-manager/management/resource-providers-and-types)（取得日 2026-09-19）
- 出典: [LLM トークン制限](https://learn.microsoft.com/ja-jp/azure/api-management/llm-token-limit-policy)（取得日 2026-09-16。D14 に伴う整合修正の根拠）
- 出典: [Azure portal でリソース グループを管理する](https://learn.microsoft.com/ja-jp/azure/azure-resource-manager/management/manage-resource-groups-portal)（取得日 2026-09-19）
- 出典: [Azure portal を使用してリソースにタグを付ける](https://learn.microsoft.com/ja-jp/azure/azure-resource-manager/management/tag-resources-portal)（取得日 2026-09-19）
- 出典: [Azure リソース プロバイダーと種類](https://learn.microsoft.com/ja-jp/azure/azure-resource-manager/management/resource-providers-and-types)（取得日 2026-09-19）
- 出典: [Resource providers for Azure services](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-services-resource-providers)（取得日 2026-09-15）
- 出典: [Azure portal でユーザーのアクセスを確認する](https://learn.microsoft.com/ja-jp/azure/role-based-access-control/check-access)（取得日 2026-09-19）
- 出典: [Azure built-in roles for Privileged](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/privileged)（取得日 2026-09-15）
- 出典: [Azure built-in roles for Management and governance](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/management-and-governance)（取得日 2026-09-15）
- 出典: [Foundry Agent Service: environment setup](https://learn.microsoft.com/en-us/azure/foundry/agents/environment-setup)（取得日 2026-09-15）
- 出典: [Standard agent setup](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/standard-agent-setup)（取得日 2026-09-15）
- 出典: [Use your own resources](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/use-your-own-resources)（取得日 2026-09-15）
- 出典: [Role-based access control for Microsoft Foundry](https://learn.microsoft.com/en-us/azure/foundry/concepts/rbac-foundry)（取得日 2026-09-15）
- 出典: [Model availability by region](https://learn.microsoft.com/en-us/azure/foundry/foundry-models/concepts/models-sold-directly-by-azure-region-availability)（取得日 2026-09-15）
- 出典: [Foundry Agent Service limits, quotas, and regions](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/limits-quotas-regions)（取得日 2026-09-15）
- 出典: [Manage and increase quotas](https://learn.microsoft.com/en-us/azure/foundry/how-to/quota)（取得日 2026-09-19）
- 出典: [az cognitiveservices usage](https://learn.microsoft.com/en-us/cli/azure/cognitiveservices/usage)（取得日 2026-09-15）
- 出典: [Log Analytics ワークスペースを作成する](https://learn.microsoft.com/ja-jp/azure/azure-monitor/logs/quick-create-workspace)（取得日 2026-09-19）
- 出典: [データ保持期間を構成する](https://learn.microsoft.com/ja-jp/azure/azure-monitor/logs/data-retention-configure)（取得日 2026-09-19）
- 出典: [Log Analytics ワークスペースの削除と復旧](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/delete-workspace)（取得日 2026-09-15）
- 出典: [Azure Monitor Logs cost calculations and pricing](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/cost-logs)（取得日 2026-09-15）
- 出典: [az monitor log-analytics workspace](https://learn.microsoft.com/en-us/cli/azure/monitor/log-analytics/workspace)（取得日 2026-09-15）
- 出典: [チュートリアル: 予算を作成して管理する](https://learn.microsoft.com/ja-jp/azure/cost-management-billing/costs/tutorial-acm-create-budgets)（取得日 2026-09-19）
- 出典: [クイック スタート: コスト分析を使用する](https://learn.microsoft.com/ja-jp/azure/cost-management-billing/costs/quick-acm-cost-analysis)（取得日 2026-09-15）
- 出典: [Microsoft.Consumption/budgets（ARM テンプレートリファレンス）](https://learn.microsoft.com/en-us/azure/templates/microsoft.consumption/budgets)（取得日 2026-09-15）
- 出典: [az consumption budget](https://learn.microsoft.com/en-us/cli/azure/consumption/budget)（取得日 2026-09-15）
- 出典: [Azure portal の設定を管理する](https://learn.microsoft.com/ja-jp/azure/azure-portal/set-preferences)（取得日 2026-09-19）
- 出典: [Azure Cloud Shell overview](https://learn.microsoft.com/en-us/azure/cloud-shell/overview)（取得日 2026-09-15）
- 出典: [Azure Cloud Shell features and tools](https://learn.microsoft.com/en-us/azure/cloud-shell/features)（取得日 2026-09-15）
- 出典: [Azure Cloud Shell の使用を開始する（エフェメラル）](https://learn.microsoft.com/ja-jp/azure/cloud-shell/get-started/ephemeral)（取得日 2026-09-15）
- 出典: [Get started with Azure Cloud Shell (new storage)](https://learn.microsoft.com/en-us/azure/cloud-shell/get-started/new-storage)（取得日 2026-09-19）
- 出典: [Persist files in Azure Cloud Shell](https://learn.microsoft.com/en-us/azure/cloud-shell/persisting-shell-storage)（取得日 2026-09-15）
- 出典: [Azure Cloud Shell FAQ and troubleshooting](https://learn.microsoft.com/en-us/azure/cloud-shell/faq-troubleshooting)（取得日 2026-09-15）
- 出典: [Deploy Cloud Shell in a virtual network（標準の Cloud Shell が Microsoft ネットワークで動く記述）](https://learn.microsoft.com/en-us/azure/cloud-shell/vnet/overview)（取得日 2026-09-15）
- 出典: [Sign in with Azure CLI（Cloud Shell の自動サインイン・MFA）](https://learn.microsoft.com/en-us/cli/azure/authenticate-azure-cli)（取得日 2026-09-15）
- 出典: [Sign in to a Linux VM with Microsoft Entra ID（Cloud Shell と条件付きアクセスの記述）](https://learn.microsoft.com/en-us/entra/identity/devices/howto-vm-sign-in-azure-ad-linux)（取得日 2026-09-15）
- 出典: [foundry-samples 41-standard-agent-setup README（固定コミット）](https://github.com/microsoft-foundry/foundry-samples/blob/58e4127567f7e9afcf0145d874df890284ca5faf/infrastructure/infrastructure-setup-bicep/41-standard-agent-setup/README.md)（取得日 2026-09-15）


---

前へ: [Azure へのサインインと命名規則](00-before-start.md) / 次へ: [Key Vault を準備する](02-key-vault.md) / [トップに戻る](../README.md)
