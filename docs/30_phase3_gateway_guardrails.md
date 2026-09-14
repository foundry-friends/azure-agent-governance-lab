# Phase 3：ゲートウェイとガードレール（骨子）

Azure で未実行です。Phase 2 から分離した公開側の環境で APIM Basic v2 を検証します。Entra ID 認証を維持し、API キーや APIM subscription key を必要とする設計は使いません。

## 1. 公開側の検証環境を用意する

- [ ] Phase 1 相当の別 RG / Foundry account を用意し、モデルと managed identity のアクセス権限を確認します。
- [ ] Foundry ポータルの AI Gateway 設定で APIM Basic v2 を作成・関連付けします。Entra ID の認証構成と実際の UI は要確認です。
- [ ] 新規・既存 project の関連付けと、実際の呼び出し経路を確認します。
- [ ] 閉域結合が目的の場合は Standard v2 / Premium v2＋Private Endpoint が必要です。テンプレート `16-private-network-standard-agent-apim-setup` を参考に別途設計します。Basic v2 をそのまま閉域へ接続しません。

## 2. トークン制限を設定する

- [ ] `llm-token-limit` の `token-quota`、期間、集計キーを決めます。XML 属性・期間の値・配置場所は要確認です。
- [ ] C09：小さな検証用 quota を設定して超過時 403 を確認します。レート超過と混同しません。
- [ ] APIM ログで実際に経由したことを確認します。バックエンドへの直接呼び出しで迂回できない権限設計は要確認です。
- [ ] Azure OpenAI に費用のハードリミットはありません。quota はトークン制御であり、インフラ課金・全経路の費用停止を保証しません。

## 3. モデルとエージェントのガードレールを分ける

- [ ] モデル向け（GA）の正常入力・拒否入力を合成データで検証します。
- [ ] エージェント向け guardrails、Tool call / Tool response 介入点、Task Adherence は Preview と明記します。
- [ ] 使用する RAI ポリシー ID の存在と対象への適用を確認します。具体的な参照 API / プロパティは要確認です。
- [ ] hosted agent の存在しない RAI ポリシー ID は fail open になるため、デプロイ成功だけで合格にしません。合成入力による挙動まで検証します。

## 4. APIM の LLM ログと本文の保護を確認する

- [ ] 本文を記録する必要性を決め、LLM ログの有効化・対象フィールド・マスキング・閲覧権限を確認します（要確認）。
- [ ] Foundry 診断ログと本文ログを区別し、Application Insights の `AppGenAIContent` と重複収集するかを決めます。
- [ ] 30 日保持、機微属性へのアクセス制限、収集停止手順、従量費を確認します。

## 5. Policy の防止効果を追加検証する

- [ ] 承認モデル限定の組み込み定義を隔離した検証スコープで Deny にして、非承認モデルの展開が拒否されることを C06 の追加試験として確認します。
- [ ] content filter 系の組み込み定義は Preview / Audit のみです。Deny で防止できると書き換えません。

## 6. 最終回だけ App Gateway WAF を追加する

- [ ] 保護するアプリの入口、バックエンド、Entra ID 認証、WAF ルール・検証入力を先に確定します（要確認）。
- [ ] WAF を置いただけで Foundry のすべての呼び出しを保護したことにしません。
- [ ] 当日構築・当日削除を計画し、約 $392/月相当の入力単価を費用表へ反映します。

## 7. 検証・終了

- [ ] C09 と C10 を実施し、Phase 1 相当の C01〜C07 もこの環境で再確認します。
- [ ] [削除・費用](90_teardown_and_cost.md) を実施します。Gateway の関連付け解除だけで APIM 本体が削除されたと判断しません。

根拠：[AI Gateway](https://learn.microsoft.com/en-us/azure/foundry/configuration/enable-ai-api-management-gateway-portal)、[トークン制限](https://learn.microsoft.com/en-us/azure/api-management/llm-token-limit-policy)、[ガードレール](https://learn.microsoft.com/en-us/azure/foundry/guardrails/guardrails-overview)、[モデル Policy](https://learn.microsoft.com/en-us/azure/foundry/how-to/model-deployment-policy)、[組み込み Policy](https://learn.microsoft.com/en-us/azure/ai-services/policy-reference)、[本文トレース](https://learn.microsoft.com/en-us/azure/foundry/observability/how-to/traces-sensitive-content)。
