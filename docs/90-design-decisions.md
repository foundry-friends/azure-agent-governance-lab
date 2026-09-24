# 設計判断 D1〜D18

通常手順ではなく設計の参考資料です。実行順は [README](../README.md) が正です。

構成 A（Azure 内で完結、Agent 365 なし）の検証用判断です。SKU の利用可否・クォータは要確認です。

| ID | 判断 | 理由 | 本番で変えること |
| --- | --- | --- | --- |
| D1 | Japan East | 検証リージョンを揃え、比較しやすくします。 | モデル提供、データ所在地、可用性要件に応じて再選定します。 |
| D2 | Standard setup、Cosmos DB Serverless | データ保存先を自前で管理し、小規模検証の固定費を抑えます。 | 負荷計測で容量方式を再評価し、SLA・復旧要件を設計します。 |
| D3 | **v2.1 で対象外（旧判断）** BYO VNet injection、テンプレート 15 → 16 を参照 | 最初に閉域を検証し、後でゲートウェイ統合を設計します。アカウント作成時のみ設定可能です。 | 本番用ネットワークを作成前に確定します。15 から 16 へのインプレース更新を保証する矢印ではありません。 |
| D4 | **v2.1 で対象外（旧判断）** Firewall Basic | 学習用の費用を抑えます。テンプレートが Basic を選べるか、経路を含め要確認です。 | Firewall Standard を前提に必要機能・冗長性・費用を見直します。 |
| D5 | **v2.1 で対象外（旧判断）** APIM Basic v2 を公開側で検証 | Run 2 の閉域環境と分離してゲートウェイの効果を確認します。 | 閉域との結合には Standard v2 または Premium v2＋Private Endpoint を使い、経路・DNS も設計します。 |
| D6 | **v2.1 で対象外（旧判断）** App Gateway WAF は旧ゲートウェイ検証の最終回のみ | 短い検証期間に限定して費用を抑えます。 | 外部公開要件とアプリの入口に応じて常設・ルールを設計します。 |
| D7 | **v2.1 で対象外（旧判断）** Bastion なし | 常設の管理用アクセス費を抑えます。現行は代替の閉域接続も作りません。 | 管理アクセスの監査、認証、可用性に合う方式を選びます。 |
| D8 | 都度構築 | 週 1 回 × 8h を想定し、置きっぱなしを防ぎます。 | 継続稼働、変更管理、バックアップ、災害復旧を整備します。 |
| D9 | ログ保持 30 日 | 学習に必要な証跡と保管費を両立します。 | 法令・業務要件と機微情報の扱いを踏まえて保持・閲覧権限を定義します。 |
| D10 | Defender CSPM＋AI Services | Azure 側の検知・態勢管理を検証します。共有サブスクリプションの他チームへの課金に注意します。 | 適用スコープと費用負担を合意し、Agent 365 が必要な機能を追加評価します。 |
| D11 | エージェントの作り方は prompt agent を既定とし、hosted agent は付録 A | ポータルでノーコードの手順を短く再現し、コンテナ compute を本編へ持ち込みません。実行順は D13 へ改訂。日本語・Cloud Shell Bash を採用します。 | 作り込みが必要なら専用 identity、/24、private ACR、RAI fail open、egress controls、HITL、Purview middlewareを別途設計します。 |
| D12 | データ基盤は BYO | GUI で目標 SKU・IP 制限・ローカル認証無効を設定し、作成済みの 3 ID を接続に使います。Bicep は任意の再現資料です。41 の新規作成は SKU・認証が固定です。Agent Service 用に Search の信頼サービス例外・Storage の Foundry リソース インスタンス規則・Cosmos の `0.0.0.0` を設定します（D15）。 | 本番は負荷・復旧・閉域要件を別途設計します。 |
| D13 | 第0〜10章の一本道 | 同一環境を作り、統制を加え、最後に一度だけ削除します。再現確認は任意の二周目。 | 本番の変更・運用手順は別途設計します。 |
| D14 | 本人の経路は App Service → Foundry 直接（App Service の VNet 統合＋サービス エンドポイントを Foundry の VNet 規則に登録）。APIM Basic v2 はツール経路に限定 | v2 レベルの APIM は送信 IP が固定できず、リージョン範囲の許可は Foundry の IP 規則上限 100 件を超えます。案 C は SKU 変更がなく、VNet 統合・サービス エンドポイント自体の追加料金はありません。サービス利用・通信・ログは別で、両側の手順が Learn にあります（第7章 7.2 の比較）。仮想ネットワークの操作を学ぶ機会にもなります。 | 本番は Standard v2 以上の VNet 統合や閉域経路で本人の経路もゲートウェイに通し、quota・本文ログを一元化します。 |
| D15 | G1〜G3 の根拠確認と例外（2026-09-19・A10〜A13）。主線 Standard、G2 が初回で成立しなければ別 account の Basic | Cosmos 接続だけ Preview を承認。Cosmos の `0.0.0.0` は Azure 内許可でトークン必須、インターネット全公開ではないとして採用。GUI にないキー無効化は Cloud Shell を許可し、Foundry は作成直後 PowerShell → 古いキー401 → モデル配置。到達は C08 で確定 | Cosmos 接続の SLA なし・本番非推奨を受け入れた学習用例外。他の Preview へ拡張しない。本番は GA 範囲と許可主体・経路を再評価 |
| D16 | アプリ → Cosmos DB に JSON の会話メモを保存（2026-09-19・A14） | App Service 統合サブネットに `Microsoft.AzureCosmosDB` を追加し Cosmos VNet 規則で許可。システム割り当て MI のデータロールをアプリ専用 `<app-db>/<app-container>` に限定。`enterprise_memory` に書かない。GA の経路で Basic 分岐後も独立して使える | 利用者ごとのアプリ認可・保持・消去・容量を本番要件で設計。共有 MI の成功を本人の Foundry RBAC の証拠にしない |
| D17 | 本人トークンは Easy Auth 転送、Foundry は REST（httpx）で 1 往復、Cosmos は MI、Python 3.12 と直接依存 5 つの固定版・Oryx ビルド、CSRF・拒否層の区別（2026-09-20・D-A1〜D-A6） | Easy Auth のトークン ストアを使い API 公開・MSAL・シークレット管理を増やさない。既存エージェントの REST は Bearer と input だけで呼べ、SDK 用の資格情報ラッパーや conversation が不要。Cosmos はキー無し MI の公式経路、ソース ZIP と Oryx で配布 PC の Python を不要にする。Consumer は第5章の project スコープを維持 | OBO／MSAL、トークンの署名検証、多インスタンス時の重複検知の外部化を再評価する |
| D18 | Fabric データエージェントを本編のツールに採用（2026-09-24・依頼者決定）。Preview 例外・OBO・APIM を通らない別経路 | 本人 ID が Foundry → Fabric まで届き、利用者の権限で見えるデータが変わることを C11 で体験します。第7章で準備・公開・接続、第8章で比較。容量は事前確認済みのものを使用 | `fabric_dataagent_preview` に限定した2つ目の Preview 例外。SLA なし・本番非推奨。権限・ネットワーク・監査・費用・提供条件を本番では再評価 |


Standard setup の前提は RG の Owner または User Access Administrator（別途リソース作成権限が必要）です。Cosmos DB の Provisioned には 3000 RU/s 以上の要件を確認します。Serverless も検証対象です。Serverless に Provisioned の RU/s パラメータをそのまま設定しません。04_data.bicep は EnableServerless を設定します。実機での適合性は要確認です。capability host は作成後に変更できません。[Standard setup](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/standard-agent-setup)

以下の v2.1 の Run 記述は旧計画の背景です。現在の実行順には使いません。

v2.1 は閉域接続なし・社内 IP 限定・送信最小です。Run 1 は最小構成と IP 制限、Run 2 は方式 A と APIM Basic v2 / App Service の検証です。D3〜D7 の旧ネットワーク・入口構成は採用しません。Basic v2 自体は Run 2 で使います。

閉域結合の SKU 条件は [APIM 接続要件](https://learn.microsoft.com/en-us/azure/foundry/configuration/enable-ai-api-management-gateway-portal)、D10 は [Defender 有効化](https://learn.microsoft.com/en-us/azure/defender-for-cloud/ai-onboarding) を参照します。Agent 365 のエージェント単位機能まで検証したことにはしません。


## D11 の適用範囲

2026-09-17 の提供条件の確認は [付録A](91-appendix-hosted-agent.md) を参照します。hosted のサービス、SDK、機能ごとの GA／Preview を区別します。D11 の /24・private ACR・egress controls 等は別設計の候補であり、本編の必須条件や今回の構築指示ではありません。旧 Preview の compute 管理を現行手順へ流用しません。

prompt agent は publish 前に共有 agent identity、publish 後は専用 identity と RBAC 再割当を確認します。現行の D14 では APIM はツール経路に限定します。APIM 背後の BYO model は本編の検証対象に含めません。hosted agent はコードから APIM を呼ぶ設計が別途必要です。prompt agent の MCP / OpenAPI 実行前承認と OBO の具体的な構成は要確認。Responses API 直接呼び出しは Foundry に agent リソースが残らない別方式、Copilot Studio は別製品です。

D10 は検討対象の保存であり、現行予算の CSPM は既定 OFF・管理者判断です。41 の新規作成の不足を D12 と自前 Key Vault で補います。GUI 主線の Foundry キー無効化は D15 で確定しました。旧 IaC の後追いと App Insights の Entra ID 接続は未解決です。[Run 0 調査](../infra/params/41_parameters.md) の差分を解消するまでは未実行です。

## D12 の責任分担

次表は旧 IaC の実装状況です。S5／S6 は旧番号であり、現在の章順や GUI 手順の実行指示には使いません。GUI 主線の到達点は第3・4・6・7章と README を参照します。

| 項目 | v2.1 の担当 | 状態 |
|---|---|---|
| Serverless / Search Basic / Storage LRS | 04_data.bicep | コード化・未検証 |
| データのローカル認証無効・IP 制限 | 04_data.bicep | コード化・未検証 |
| Key Vault・RBAC 認可 | 02_keyvault.bicep | コード化・未検証 |
| タグ | 自前 module と S5 後追い | 41 の全対象への反映は要確認 |
| Foundry の認証・IP 制限 | 03_network_acls.bicep の目標値＋S5 の更新 | 更新未実施 |
| App Insights | 06_diagnostics.bicep＋S6 | Entra ID の接続が要確認 |

> **Note** 要確認: 固定版 41 の Preview API、初期公開期間、後追い更新と Deny の競合は未解決です。D14 の通信方針は採用済みですが、任意の IaC は未対応で、ツール API の認可・本人経路の適用確認も未完了です。vendor を変更せず停止点を維持します。

## D15・D16 の適用範囲

G1〜G3 は根拠を確認済みで、Azure 実行済みという意味ではありません。G2 には IP 制限付き BYO での成功を明言する Learn の文がないため、C08 の初回結果で成立を判定します。Standard は3リソース同時 BYO が必要で、Cosmos だけを外す分岐はありません。Basic では capability host を作らず、Standard と同じ account に混ぜません。元の失敗証跡と費用対象を残し、削除は第10章で行います。

A13 の設定値とデータ面の反映は別です。キーの値を取得・記録せず、既存の安全な試験経路で古いキーの401を確認します。経路がなければ C03 の実キー行は Pending、モデル配置前で保留します。B17（ウィザードの自動作成範囲）と B18（Storage の作成時キー項目）は初回照合です。`infra/` の旧停止点は変更しません。

## D18 の適用範囲と D14・D17 との関係

D1〜D17 の既存判断は維持します。D15 の Cosmos 接続とは別に、D18 で Fabric ツール `fabric_dataagent_preview` の採用を承認しました。他の Preview 機能・IaC API に例外を拡張しません。Fabric は Azure サブスクリプション外の SaaS として図示し、容量の契約・課金先は別に照合します。

D14 の本人経路は App Service → Foundry、MCP／OpenAPI のツール経路は APIM のままです。Fabric は Foundry 組み込みツールとして APIM を通らない例外経路とし、APIM quota・ログの統制対象には含めません。D17 の Easy Auth 転送と、Foundry → Fabric の identity passthrough（OBO）は異なる区間です。アプリに OBO／MSAL を実装済みと読み替えません。サービス プリンシパル認証で代用しません。

> **Note** 要確認: Learn は Foundry User 以上を要求します。Consumer のまま試行して結果を記録し、必要時だけ Fabric 専用主体に Foundry User を付与して比較します。C02 の呼び出し専用主体を昇格させません。D17 の既存アプリで OBO が成立するか、ツール呼び出し・拒否層・本人を追跡できるかは C11 で確認します。

> **Note** 要確認（推測）: Foundry → Fabric の送信は Foundry 入口の IP 制限と直接衝突しない見込みですが、Fabric 側のネットワーク制限・到達を実機で確認します。容量・ライセンス・テナント設定・監査の条件は未確定のまま記録し、容量作成・停止・削除は本手順の対象外とします。


### 出典

- 出典: [Foundry の Fabric ツール](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/tools/fabric)（取得日 2026-09-24）
- 出典: [Fabric から Foundry で利用する](https://learn.microsoft.com/en-us/fabric/data-science/data-agent-foundry)（取得日 2026-09-24）

- 出典: [Foundry 作成ウィザード](https://learn.microsoft.com/en-us/azure/ai-services/multi-service-resource)（取得日 2026-09-19）
- 出典: [接続の種類](https://learn.microsoft.com/en-us/azure/foundry/how-to/connections-add)（取得日 2026-09-19）
- 出典: [Standard setup と権限](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/standard-agent-setup)（取得日 2026-09-19）
- 出典: [公開 Standard setup](https://learn.microsoft.com/en-us/azure/foundry/agents/environment-setup)（取得日 2026-09-19）
- 出典: [capability host と Basic](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/capability-hosts)（取得日 2026-09-19）
- 出典: [キー無効化](https://learn.microsoft.com/en-us/azure/ai-services/disable-local-auth)（取得日 2026-09-19）
- 出典: [Cosmos DB の IP 制御](https://learn.microsoft.com/en-us/azure/cosmos-db/how-to-configure-firewall)（取得日 2026-09-19）
- 出典: [Storage リソース インスタンス規則](https://learn.microsoft.com/en-us/azure/storage/common/storage-network-security-resource-instances)（取得日 2026-09-19）
- 出典: [Search 信頼サービス例外](https://learn.microsoft.com/en-us/azure/search/service-configure-firewall)（取得日 2026-09-19）
- 出典: [Cosmos DB のデータ面 RBAC](https://learn.microsoft.com/en-us/azure/cosmos-db/nosql/how-to-connect-role-based-access-control)（取得日 2026-09-19）

---

前へ: [概要](../README.md) / 次へ: [準備と土台](01-prerequisites.md) / [トップに戻る](../README.md)
