# 設計判断 D1〜D11

構成 A（Azure 内で完結、Agent 365 なし）の検証用判断です。SKU の利用可否・クォータは要確認です。

| ID | 判断 | 理由 | 本番で変えること |
| --- | --- | --- | --- |
| D1 | Japan East | 検証リージョンを揃え、比較しやすくします。 | モデル提供、データ所在地、可用性要件に応じて再選定します。 |
| D2 | Standard setup、Cosmos DB Serverless | データ保存先を自前で管理し、小規模検証の固定費を抑えます。 | 負荷計測で容量方式を再評価し、SLA・復旧要件を設計します。 |
| D3 | BYO VNet injection、テンプレート 15 → 16 を参照 | 最初に閉域を検証し、後でゲートウェイ統合を設計します。アカウント作成時のみ設定可能です。 | 本番用ネットワークを作成前に確定します。15 から 16 へのインプレース更新を保証する矢印ではありません。 |
| D4 | Firewall Basic | 学習用の費用を抑えます。テンプレートが Basic を選べるか、経路を含め要確認です。 | Firewall Standard を前提に必要機能・冗長性・費用を見直します。 |
| D5 | APIM Basic v2 を公開側で検証 | Run 2 の閉域環境と分離してゲートウェイの効果を確認します。 | 閉域との結合には Standard v2 または Premium v2＋Private Endpoint を使い、経路・DNS も設計します。 |
| D6 | App Gateway WAF は Run 3 最終回のみ | 短い検証期間に限定して費用を抑えます。 | 外部公開要件とアプリの入口に応じて常設・ルールを設計します。 |
| D7 | Bastion なし | 常設の管理用アクセス費を抑えます。Developer SKU または P2S VPN を代替候補とし、提供条件・接続方式は要確認です。 | 管理アクセスの監査、認証、可用性に合う方式を選びます。 |
| D8 | 都度構築 | 週 1 回 × 8h を想定し、置きっぱなしを防ぎます。 | 継続稼働、変更管理、バックアップ、災害復旧を整備します。 |
| D9 | ログ保持 30 日 | 学習に必要な証跡と保管費を両立します。 | 法令・業務要件と機微情報の扱いを踏まえて保持・閲覧権限を定義します。 |
| D10 | Defender CSPM＋AI Services | Azure 側の検知・態勢管理を検証します。共有サブスクリプションの他チームへの課金に注意します。 | 適用スコープと費用負担を合意し、Agent 365 が必要な機能を追加評価します。 |
| D11 | エージェントの作り方は prompt agent を既定とし、hosted agent は付録 A | ポータルでノーコードの手順を短く再現し、コンテナ compute を本編へ持ち込みません。S0＋9セクション、Run 3回×初回・再現の2日、日本語・Bashを採用します。 | 作り込みが必要なら専用 identity、/24、private ACR、RAI fail open、egress controls、HITL、Purview middlewareを別途設計します。 |

Standard setup の前提は RG の Owner または User Access Administrator（別途リソース作成権限が必要）です。Cosmos DB は 3000 RU/s 以上の要件があり、Provisioned / Serverless の両方に対応します。Serverless に Provisioned の RU/s パラメータをそのまま設定しません。具体的な容量指定は固定テンプレートで要確認です。capability host は作成後に変更できません。[Standard setup](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/standard-agent-setup)

Run 1 の公開アカウントを Run 2 に流用しません。ネットワーク注入は作成時に固定し、サブネットは `Microsoft.App/environments` に委任、/27 以上のアドレス空間（例：/26 も含む）を確保します。[ネットワーク](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/networking-options)

閉域結合の SKU 条件は [APIM 接続要件](https://learn.microsoft.com/en-us/azure/foundry/configuration/enable-ai-api-management-gateway-portal)、D10 は [Defender 有効化](https://learn.microsoft.com/en-us/azure/defender-for-cloud/ai-onboarding) を参照します。Agent 365 のエージェント単位機能まで検証したことにはしません。


## D11 の適用範囲

prompt agent は publish 前に共有 agent identity、publish 後は専用 identity と RBAC 再割当を確認します。APIM 背後の BYO model は prompt agent 主線で検証します。hosted agent はコードから APIM を呼ぶ設計が別途必要です。prompt agent の MCP / OpenAPI 実行前承認と OBO の具体的な構成は要確認。Responses API 直接呼び出しは Foundry に agent リソースが残らない別方式、Copilot Studio は別製品です。

D10 は検討対象の保存であり、現行予算の CSPM は既定 OFF・管理者判断です。41 の実装は D2 のサーバーレス、Search Basic、Entra ID のみ、Key Vault の要件をそのまま満たしません。[Run 0 調査](../infra/params/41_parameters.md) の差分を解消するまでは未実行です。
