# 4. Foundry とエージェントを作る

進め方: README の第0〜10章を順番に実施します。第3章の完了条件を満たしてから進めます。

> **Note** 状態: ドラフト（Learn 2026-09 時点の記述に基づく・未実行）。接続の提供範囲・通信経路・作成時認証の確認待ち。更新日 2026-09-15。

> **補足** この章では環境を削除しません。通常の削除は最後の第10章です。中断して片付ける場合だけ、第10章へ進みます。

## 4.1. 目的

作成済みのデータ基盤に接続する Foundry account／project と prompt agent を作り、最初の応答を確認します。

### なぜこの作業が必要か

後の章で統制の効果を比較するには、まず正常に応答するエージェントが必要です。動作を確認する前に設定を増やすと、応答しない原因がモデル・データ接続・権限・ネットワークのどこにあるか切り分けにくくなります。

この章では、作成済みのデータ基盤と Foundry を接続し、最初の応答を比較の基準として記録します。初期の認証と IP 制限を保った状態で動くことを目指し、その後に利用者別の権限、監査、呼び出しアプリを加えていきます。接続条件の未解決点は本文の停止条件として扱います。

## 4.2. 前提

第3章の Storage・Cosmos DB・AI Search の ARM ID、認証設定、社内公開 IP の許可リストを非公開の記録で確認します。構築担当には Foundry account/project の作成権限と、接続用ロールを割り当てる権限が必要です。利用担当の Foundry User と、構築担当の管理権限を混同しません。

### 作成前の停止条件

> **Note** 要確認: 以下の3条件が未解決です。現時点では4.3の設定内容を確認するところまでとし、[作成] やモデルのデプロイには進みません。通し実行できる完成手順とは扱いません。

| 条件 | 公式資料で確認できたこと | 再開に必要な確認 |
|---|---|---|
| G1: Cosmos DB 接続の提供範囲 | Standard setup は Cosmos DB を使用します。一方、接続一覧は Cosmos DB 接続を Preview・コードからのみ作成可能としています | 今回の Standard setup の BYO 接続がその対象か、GA の方法があるかを Microsoft の説明で確定すること |
| G2: サービス間の通信経路 | 社内 PC → Foundry の受信制限と、Agent Service → データ基盤の送信経路は別です | 全公開・閉域接続を使わず、第3章の3リソースに到達できるサポート対象の経路を特定すること |
| G3: 作成時の認証 | `disableLocalAuth=true` を ARM/Bicep または Policy で設定する方法は文書化されています | GUI 主線で、作成時からローカル認証を無効にする方法と接続・権限の作成順を確定すること |

G1 は [接続の種類](https://learn.microsoft.com/ja-jp/azure/foundry/how-to/connections-add) と [Standard setup](https://learn.microsoft.com/ja-jp/azure/foundry/agents/concepts/standard-agent-setup) の適用範囲の確認です。安定版の管理 API が存在しても、接続機能の GA を意味するとは限りません。Preview の接続作成手順は掲載しません。

G2 は RBAC だけでは解決しません。社内 IP を許可しても Azure 上のサービスの送信元を許可したことにはなりません。G3 を回避する目的で、キー認証を有効にしたまま作成して後から無効化する手順にも進みません。

### 作業開始・再開前のチェックリスト

実施者は次の項目を非公開の作業記録へコピーし、根拠を確認できた項目だけチェックします。**注意点を読んだだけでは、停止条件を解消したことにはなりません。**

- [ ] G1: 今回使用する Cosmos DB 接続が GA の対象である根拠を確認した。
- [ ] G2: 社内 IP 制限を維持したまま、Agent Service から3つの接続先へ到達する方式を確認した。
- [ ] G3: 作成時からキー認証を無効にする方法と、接続・host・権限の作成順を確認した。
- [ ] 確認結果に合わせて、この章の未確定の作成手順が補完されている。
- [ ] 操作対象の RG・リソースと、変更前の設定を確認した。

> **Note** 1つでも未確認なら、[作成]・モデル配置・後続の実行には進みません。IP 制限の解除、キー認証への切替、対象外の機能の利用によってチェックを埋めないでください。

停止・再開の判断は、次の書式で非公開の `evidence/` に記録します。GitHub 上の手順書には実在 ID・社内 IP・認証情報を書き込みません。

| 記録項目 | 記入する内容 |
|---|---|
| 確認日・対象条件 | G1 / G2 / G3 のどれを確認したか |
| 根拠 | 公式資料の URL・該当箇所、またはサポート回答の非公開の保管先 |
| 対象構成との一致 | 今回の接続方式・認証・ネットワーク条件に適用できる理由 |
| 判断 | 未解決で保留 / 根拠確認済みで手順補完待ち / 手順補完済みで実行へ |
| 実行結果 | 未実施 / 実施日時と結果。設定確認と動作確認を分ける |

## 4.3. 構築

### 1. 作成画面で入力内容を確認する

以下は [Azure portal で Foundry リソースを作成する資料](https://learn.microsoft.com/ja-jp/azure/ai-services/multi-service-resource) に基づく入力準備です。**停止条件が解決するまでは確認だけにとどめます。**

1. 社内ネットワークの PC から [Foundry の作成画面](https://portal.azure.com/#create/Microsoft.CognitiveServicesAIFoundry) を開きます。
2. [基本] で対象のサブスクリプションと第1章のリソースグループを選びます。
3. リージョンと Foundry リソース名を入力します。
4. [ネットワーク] の [Inbound Access] で選択したネットワークからのアクセスを選びます。
5. 社内公開 IPv4 の許可リストを入力します。
6. [ID] でシステム割り当てマネージド ID の設定を確認します。
7. [ストレージ] の [Agent service] で [リソースの選択] を開きます。
8. 第3章で作成した3リソースを選びます。
9. 確認画面で下表と照合します。

| 項目 | 値・確認内容 |
|---|---|
| サブスクリプション / RG | 今回の実施者専用の対象 |
| リージョン | Japan East。モデルの利用可否は別に確認 |
| Foundry 名 | 実施者略号を含む命名規則に従う値 |
| 受信アクセス | 社内公開 IP のみ。全ネットワークを選ばない |
| Agent service のリソース | 第3章の Cosmos DB / Storage / AI Search の ARM ID と一致 |
| Credential storage and application logging | 第2章の Key Vault と Application Insights を自動接続されたものとして扱わない |
| 暗号化 | このラボでは Microsoft 管理のキー |

> **画面の見え方** 新しい Foundry 向けの資料に基づきます。表示言語により英語の項目が残る場合があります。選択肢がない、リソースが選べない、別のリソースが新規作成される場合は、その画面と想定との差を非公開に記録します。

[ストレージ] 内の資格情報用ストレージと、[Agent service] のデータ基盤は別の設定です。第2章の Key Vault は独立した監査の学習対象です。カスタム Key Vault を接続しない場合の Foundry の資格情報管理は Microsoft 管理の仕組みを使います。

> **Note** 要確認: この画面で BYO リソースを選択できることは、G1〜G3 の解決を示しません。ローカル認証無効化の GUI 項目、初期 project、接続、capability host、ロール割当の自動作成範囲は確定していません。作成操作の確定はここで保留します。

### 2. 作成後の account・project を照合する（停止条件の解決後）

ここから先は、G1〜G3 を解決し、作成手順を補完してデプロイが成功した後の確認用ドラフトです。

1. Azure portal で作成した Foundry リソースを開きます。
2. リソースの JSON 表示で以下の値を照合します。
3. account と project の ARM ID を非公開の記録に残します。
4. project のマネージド ID と account のマネージド ID を区別して記録します。

| account の項目 | 期待する値 |
|---|---|
| `publicNetworkAccess` | `Enabled` |
| `disableLocalAuth` | `true` |
| `networkAcls.defaultAction` | `Deny` |
| `networkAcls.ipRules` | 社内公開 IP の許可リスト |
| `networkAcls.bypass` | `None`。例外の追加は承認済みの通信設計が必要 |

ローカル認証設定の反映には時間がかかる場合があります。管理画面の設定値とデータ面への反映を同一視せず、キーの表示・取得は行いません。

### 3. BYO 接続と capability host を確認する

capability host は、Agent Service が使うデータ基盤を関連付ける設定です。接続が一覧にあるだけでは、その接続をエージェントが使っている証明にはなりません。

1. [Microsoft Foundry](https://ai.azure.com) で対象の project を選びます。
2. [管理] を開きます。
3. [Project details] を開きます。
4. [接続されているリソース] で接続名・接続先・認証方式を確認します。
5. account と project の capability host の設定を照合します。

| 対象 | 照合する内容 |
|---|---|
| Cosmos DB 接続 | 第3章の account を参照し、Entra ID の認証であること |
| Storage 接続 | 第3章の account を参照し、キー認証でないこと |
| AI Search 接続 | 第3章の service を参照し、キー認証でないこと |
| account の capability host | `capabilityHostKind` が `Agents` であること |
| project の capability host | `capabilityHostKind` が `Agents`、以下の3種類の接続名が一致すること |
| `threadStorageConnections` | Cosmos DB の接続名 |
| `storageConnections` | Storage の接続名 |
| `vectorStoreConnections` | AI Search の接続名 |

接続名と ARM ID は異なります。上の3つの配列に入るのは接続名です。[capability host の資料](https://learn.microsoft.com/ja-jp/azure/foundry/agents/concepts/capability-hosts) は管理 REST API `2025-06-01` を例示していますが、ここでは作成コマンドを追加しません。host が存在しない状態の初回応答を、BYO 接続の成功と扱いません。

### 4. サービス接続用の権限を確認する

接続の認証とネットワークの許可に加え、データ操作の権限が必要です。下表は Standard setup 資料にある **project のマネージド ID** 向けの権限です。個人の操作アカウントに同じ権限を付ける表ではありません。

| 対象・スコープ | 公式資料のロール |
|---|---|
| Cosmos DB account | Cosmos DB Operator |
| Storage account | Storage Account Contributor |
| AI Search service | Search Index Data Contributor / Search Service Contributor |
| project 用 blobstore コンテナー | Storage Blob Data Contributor |
| project 用 agent コンテナー | Storage Blob Data Owner |
| Cosmos DB の `enterprise_memory` データベース | Cosmos DB Built-in Data Contributor |

Azure の管理ロールと Cosmos DB のデータロールは別です。最後の行は Cosmos DB のネイティブなデータ権限であり、Azure の [アクセス制御 (IAM)] の Contributor で代用しません。実際に作成されたコンテナーとスコープを照合し、サブスクリプション全体への広い権限割当で回避しません。

> **Note** 要確認: GUI 作成で割り当てられるロールと、データベース・コンテナー生成前後の追加割当の順序は G3 の確認対象です。表は照合用であり、未作成のスコープへの割当手順を確定したものではありません。

この権限はエージェントの稼働に必要な構築設定です。第5章の利用者別の権限設定へ先に進んで戻る必要はありません。Cosmos DB は第3章の Serverless 構成を維持し、別構成の RU/s の数値をそのまま設定しません。

### 5. モデルを配置する

1. 対象 project の [検出] を開きます。
2. [モデル] を開きます。
3. `gpt-5-mini` を検索します。
4. [配置] で提示される構成を確認します。
5. 下表の条件を満たす場合だけ配置を確定します。
6. 配置名とモデルのバージョンを非公開の記録に残します。

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
8. プレイグラウンドのチャットに合成入力を送ります。
9. 応答と、再度開いたときに保持されている設定を記録します。

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

## 4.4. 完了条件

次のすべてを非公開の `evidence/` に記録して C01 を判定します。未確認は Pass にしません。

- G1〜G3 の根拠と、確定した作成方法が記録されている。
- account/project と project のマネージド ID を特定できる。
- 社内 IP 制限と Entra ID 認証を維持している。
- account/project の capability host と3つの接続先が一致する。
- 必要なスコープで接続用権限を確認できる。
- 社内 PC のブラウザから Entra ID で利用し、合成入力への応答が返る。
- モデル配置名、バージョン、指示、結果、実施時刻を記録している。

テキストの1往復だけでは、ファイル格納や AI Search の検索動作を検証したことにはなりません。BYO の設定確認と、実際に実施した動作を分けて記録します。第2章の Key Vault を自動接続済みとは扱いません。

## 4.5. うまくいかない場合

### 停止条件を解決するための確認事項

構築担当から Microsoft のサポート等へ確認する場合は、以下の条件と質問をまとめます。公開 Issue に実在 ID や社内 IP を掲載しません。

| 条件 | 確認したい質問 |
|---|---|
| G1 | 接続一覧の Cosmos DB の Preview 表記は、Standard setup の BYO にも適用されるか。GA の接続方式があるなら、その公式手順はどれか |
| G2 | 閉域接続なし・全公開なし・ローカル認証なしで、Agent Service から3つの BYO リソースへアクセスするサポート対象の設定はあるか。送信元または例外の対象主体を限定できるか |
| G3 | 作成時から `disableLocalAuth=true` を保証する GUI 主線の方法は何か。project、接続、host、ロールの作成順と自動設定範囲は何か |

### 接続が失敗した場合の切り分け

1. エラーが account 作成・host 作成・モデル配置・チャットのどの操作で起きたかを記録します。
2. 対象リソース、時刻、エラーコード、相関 ID を非公開に記録します。
3. 接続先 ID と認証主体が想定どおりか確認します。
4. 管理権限とデータ権限を分けて確認します。
5. 各リソースのネットワーク設定と拒否記録を確認します。
6. 原因が特定できない場合は、現在の制限を維持したまま実行を保留します。

| 症状 | 確認する内容 |
|---|---|
| 401 / 403 | トークンの対象、利用者と project MI の違い、ロール、ネットワーク拒否を切り分ける |
| リソースが選択できない | テナント・サブスクリプション・表示権限・対象構成の対応範囲 |
| host の作成失敗 | 接続名、接続先 ARM ID、ロール、到達性 |
| host の 409 | 同じスコープに既存 host がないか。重複作成しない |
| モデル配置失敗 | リージョン、提供バージョン、配置の種類、クォータ |
| 設定を変えても結果が変わらない | 権限・認証設定の反映待ちと、実際に試した主体・時刻 |

capability host は更新非対応と説明されています。修正が必要でも既存 host を即座に削除せず、依存関係と再作成の影響を確認して手順を確定します。

社内 IP の制限を外す代替手順は使いません。Cosmos DB の Azure 全体を許可する設定は、今回の Foundry だけへの許可ではありません。Storage や Search の「信頼されたサービス」の例外も、対象の主体と通信が適用対象かを確認せず有効化しません。既存の条件付きアクセスも変更しません。

切り分けで変更した設定がある場合は変更前後を記録し、許可された範囲で元の値に戻します。環境を廃棄する場合だけ第10章の削除手順を使います。

## 4.6. 次の操作

C01 の完了条件をすべて満たしてから、同じエージェントを残して第5章へ進みます。停止条件が残っている場合は、第5章以降を先に実施せず、この章で保留します。

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

固定した [公式テンプレートの説明](../infra/PINNED_COMMIT.md) と [IaC の停止条件](../infra/README.md) は参考資料です。GUI で作成済みのリソースを含めて一式を再展開しません。旧 CLI 主線の後追い変更を GUI 手順の代用として実行しません。Preview API を含むテンプレートの扱いは未解決のため、固定停止点を維持します。

### 出典

- 出典: [Foundry リソースの GUI 作成](https://learn.microsoft.com/ja-jp/azure/ai-services/multi-service-resource)（取得日 2026-09-15）
- 出典: [接続の種類と作成](https://learn.microsoft.com/ja-jp/azure/foundry/how-to/connections-add)（取得日 2026-09-15）
- 出典: [Standard setup](https://learn.microsoft.com/ja-jp/azure/foundry/agents/concepts/standard-agent-setup)（取得日 2026-09-15）
- 出典: [環境セットアップ](https://learn.microsoft.com/ja-jp/azure/foundry/agents/environment-setup)（取得日 2026-09-15）
- 出典: [ローカル認証の無効化](https://learn.microsoft.com/ja-jp/azure/ai-services/disable-local-auth)（取得日 2026-09-15）
- 出典: [capability host](https://learn.microsoft.com/ja-jp/azure/foundry/agents/concepts/capability-hosts)（取得日 2026-09-15）
- 出典: [ネットワークの選択肢](https://learn.microsoft.com/ja-jp/azure/foundry/agents/concepts/networking-options)（取得日 2026-09-15）
- 出典: [Cosmos DB の IP 制限](https://learn.microsoft.com/ja-jp/azure/cosmos-db/how-to-configure-firewall)（取得日 2026-09-15）
- 出典: [Storage ネットワークの制限事項](https://learn.microsoft.com/ja-jp/azure/storage/common/storage-network-security-limitations)（取得日 2026-09-15）
- 出典: [AI Search の IP 制限](https://learn.microsoft.com/ja-jp/azure/search/service-configure-firewall)（取得日 2026-09-15）
- 出典: [Foundry リソースとモデル配置](https://learn.microsoft.com/ja-jp/azure/foundry/tutorials/quickstart-create-foundry-resources)（取得日 2026-09-15）
- 出典: [最初のエージェント](https://learn.microsoft.com/ja-jp/azure/foundry/quickstarts/get-started-code)（取得日 2026-09-15）
- 出典: [プレイグラウンド](https://learn.microsoft.com/ja-jp/azure/foundry/concepts/concept-playgrounds)（取得日 2026-09-15）
- 出典: [Foundry の GA 範囲](https://learn.microsoft.com/ja-jp/azure/foundry/concepts/general-availability)（取得日 2026-09-15）

---

前へ: [データ基盤を作る](03-data.md) / 次へ: [人とサービスの権限を設定する](05-identity.md) / [トップに戻る](../README.md)
