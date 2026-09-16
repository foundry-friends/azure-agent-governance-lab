# 設計判断 D1〜D14

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
| D12 | データ基盤は BYO | GUI で目標 SKU・IP 制限・ローカル認証無効を設定し、作成済みの 3 ID を接続に使います。Bicep は任意の再現資料です。41 の新規作成は SKU・認証が固定です。 | 本番は負荷・復旧・閉域要件を別途設計します。 |

| D13 | 第0〜10章の一本道 | 同一環境を作り、統制を加え、最後に一度だけ削除します。再現確認は任意の二周目。 | 本番の変更・運用手順は別途設計します。 |
| D14 | 本人の経路は App Service → Foundry 直接（App Service の VNet 統合＋サービス エンドポイントを Foundry の VNet 規則に登録）。APIM Basic v2 はツール経路に限定 | v2 レベルの APIM は送信 IP が固定できず、リージョン範囲の許可は Foundry の IP 規則上限 100 件を超えます。案 C は SKU 変更も追加費用も無く、両側の手順が Learn にあります（第7章 7.2 の比較）。仮想ネットワークの操作を学ぶ機会にもなります。 | 本番は Standard v2 以上の VNet 統合や閉域経路で本人の経路もゲートウェイに通し、quota・本文ログを一元化します。 |

Standard setup の前提は RG の Owner または User Access Administrator（別途リソース作成権限が必要）です。Cosmos DB の Provisioned には 3000 RU/s 以上の要件を確認します。Serverless も検証対象です。Serverless に Provisioned の RU/s パラメータをそのまま設定しません。04_data.bicep は EnableServerless を設定します。実機での適合性は要確認です。capability host は作成後に変更できません。[Standard setup](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/standard-agent-setup)

以下の v2.1 の Run 記述は旧計画の背景です。現在の実行順には使いません。

v2.1 は閉域接続なし・社内 IP 限定・送信最小です。Run 1 は最小構成と IP 制限、Run 2 は方式 A と APIM Basic v2 / App Service の検証です。D3〜D7 の旧ネットワーク・入口構成は採用しません。Basic v2 自体は Run 2 で使います。

閉域結合の SKU 条件は [APIM 接続要件](https://learn.microsoft.com/en-us/azure/foundry/configuration/enable-ai-api-management-gateway-portal)、D10 は [Defender 有効化](https://learn.microsoft.com/en-us/azure/defender-for-cloud/ai-onboarding) を参照します。Agent 365 のエージェント単位機能まで検証したことにはしません。


## D11 の適用範囲

prompt agent は publish 前に共有 agent identity、publish 後は専用 identity と RBAC 再割当を確認します。APIM 背後の BYO model は prompt agent 主線で検証します。hosted agent はコードから APIM を呼ぶ設計が別途必要です。prompt agent の MCP / OpenAPI 実行前承認と OBO の具体的な構成は要確認。Responses API 直接呼び出しは Foundry に agent リソースが残らない別方式、Copilot Studio は別製品です。

D10 は検討対象の保存であり、現行予算の CSPM は既定 OFF・管理者判断です。41 の新規作成の不足を D12 と自前 Key Vault で補います。Foundry の後追いと App Insights の Entra ID 接続は未解決です。[Run 0 調査](../infra/params/41_parameters.md) の差分を解消するまでは未実行です。

## D12 の責任分担

| 項目 | v2.1 の担当 | 状態 |
|---|---|---|
| Serverless / Search Basic / Storage LRS | 04_data.bicep | コード化・未検証 |
| データのローカル認証無効・IP 制限 | 04_data.bicep | コード化・未検証 |
| Key Vault・RBAC 認可 | 02_keyvault.bicep | コード化・未検証 |
| タグ | 自前 module と S5 後追い | 41 の全対象への反映は要確認 |
| Foundry の認証・IP 制限 | 03_network_acls.bicep の目標値＋S5 の更新 | 更新未実施 |
| App Insights | 06_diagnostics.bicep＋S6 | Entra ID の接続が要確認 |

> **Note** 要確認: 固定版 41 の Preview API、初期公開期間、後追い更新と Deny の競合は未解決です。D14 の通信方針は採用済みですが、任意の IaC は未対応で、ツール API の認可・本人経路の適用確認も未完了です。vendor を変更せず停止点を維持します。

---

前へ: [概要](../README.md) / 次へ: [準備と土台](01-prerequisites.md) / [トップに戻る](../README.md)
