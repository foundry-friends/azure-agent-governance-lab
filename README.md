# Azure でガバナンス付きエージェント運用環境を作る手順

## 1. これは何か

部内の SE メンバーが、それぞれの Azure 検証環境にガバナンス付きエージェント環境を再現するための手順集です。Microsoft Foundry（旧 Azure AI Foundry）の Foundry Agent Service（Responses API ベースの新ランタイム、2026-03 GA）を使います。**構成 A：Azure 内で完結、Microsoft Agent 365 なし**が対象です。現在は骨組みと未実行のドラフトであり、Azure での構築・動作確認はまだ行っていません。

## 2. 対象読者と前提

- Azure の RG、RBAC、ネットワークの基本を理解している SE を対象にします。
- 自分の検証用サブスクリプション、RG を作成する権限、対象 RG の Owner（またはリソース作成権限と User Access Administrator）が必要です。
- Azure CLI 2.50 以上、Bicep、Bash、Python 3（パラメータのローカル検査用）、Japan East で利用するモデルの提供状況・クォータを確認します。
- Entra ID のみで認証し、API キーや接続文字列は使いません。hub-based project は新ポータルに対応しないため、Foundry project を使います。
- 「要確認」を解消してから実行します。現行 CLI と固定したテンプレートの対応は未検証です。

## 3. 全体像

[Baseline Microsoft Foundry chat reference architecture](https://learn.microsoft.com/en-us/azure/architecture/ai-ml/architecture/baseline-microsoft-foundry-chat) を参照し、学習用に段階を分けます。Baseline 全体を最初から構築する手順ではありません。

サービス全体像（青 = Azure 内で完結、オレンジ = Agent 365 が必要、破線 = Preview）:

![サービス全体像](images/01_service_map.png)

構成 A（Azure 内で完結する標準構成）:

![構成 A](images/02_pattern_A_azure_only.png)

Phase 1 は Foundry project と自前 Cosmos DB / Storage / AI Search / Key Vault、監査・権限制御を扱います。Phase 2 では BYO VNet の別環境を新規作成します。Phase 3 の APIM Basic v2 は公開側の別環境で検証します。Phase 1 のアカウントへ VNet injection を後付けすることはできません。[ネットワーク仕様](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/networking-options)

## 4. フェーズと所要時間

時間は作業計画上の仮置きです。実測ではなく、権限・クォータ申請や提供待ちを含みません。

| フェーズ | 内容 | 作業時間の目安 | 手順の状態 |
| --- | --- | --- | --- |
| Phase 1 | Standard setup、ID、ログ、Policy、Defender、prompt agent | 3〜4 時間 | [ドラフト](docs/10_phase1_minimum.md) |
| Phase 2 | BYO VNet、Firewall Basic、Private Endpoint | 4〜6 時間 | [見出しと確認項目](docs/20_phase2_private_network.md) |
| Phase 3 | 公開側 APIM、ガードレール、最後に WAF | 3〜5 時間 | [骨子](docs/30_phase3_gateway_guardrails.md) |
| 各回の終了 | 削除、残存・課金確認 | 30〜60 分＋非同期削除待ち | [終了手順](docs/90_teardown_and_cost.md) |

## 5. 費用の目安

**Japan East・2026-09-14・USD・730h/月**の入力単価です。提供された調査値を転記した概算で、見積り保証ではありません。実際の契約・SKU・リージョン・課金単位・税・通信量・無料枠は実行前に要確認です。

| サービス | 月額または従量単価 |
| --- | --- |
| Firewall Basic / Standard | $288 / $913 |
| APIM Basic v2 / Standard v2 | $150 / $700 |
| App Gateway WAF v2 | 約 $392 |
| AI Search Basic / S1 | $97 / $324 |
| Cosmos DB 3000 RU/s | $197（Serverless は小規模検証なら数ドルという想定。従量で変動） |
| Bastion Basic | $139 |
| Private Endpoint | $7.3 / 個 |
| App Service B1 | $14 |
| Log Analytics | $3.34 / GB |
| gpt-5 mini | 入力 $0.45 / 出力 $3.60、各 1M トークン |

| シナリオ | 概算月額 | 前提 |
| --- | --- | --- |
| 都度構築 | $100〜300 | 週 1 回 × 8h、各回削除。全費目が時間比例するとは限りません |
| 低コスト常時稼働 | 約 $700（WAF 込み約 $1,100） | Firewall Basic 288＋APIM Basic v2 150＋AI Search Basic 97＋Cosmos Serverless 約 5＋PE 6 個 44＋App Service B1 14＋Defender CSPM 約 51＋ログ 10＋guardrails 8＋モデル 20＋雑費 5 ≈ 692。App Gateway WAF v2 を足すと＋392。実構成の総額は要確認 |
| Baseline 相当の常時稼働 | 約 $2,900 | 提供された概算。全 SKU・台数の積上げと従量費は要確認 |

低コスト比較は費目の足し算であり、Basic v2 と閉域 Foundry の結合を示すものではありません。Phase 2 と Phase 3 は別環境です。同時稼働させれば両方に課金されます。

Defender for Cloud はサブスクリプション単位の従量課金プランです。CSPM は $0.007 / 課金対象リソース / 時、AI Services は $0.0008 / 1K トークン、30 日無料枠という前提です。対象・適用条件は要確認で、共有サブスクリプションでは他チームにも課金が及びます。[Defender の有効化](https://learn.microsoft.com/en-us/azure/defender-for-cloud/ai-onboarding)

Azure OpenAI に費用のハードリミットはありません。予算アラートは通知であり停止ではありません。Phase 3 の `llm-token-limit` の `token-quota`（超過時 403）でトークン使用量を制限しますが、インフラ費用や迂回経路は別途管理します。[APIM ポリシー](https://learn.microsoft.com/en-us/azure/api-management/llm-token-limit-policy)

## 6. 使い方（Phase 1 まで）

1. [設計判断](docs/00_design.md) と [削除・費用](docs/90_teardown_and_cost.md) を読みます。
2. [公式テンプレートの固定取得・パラメータ確認](infra/README.md) を行います。
3. `.env.example` をコピーし、プレースホルダーを自分の環境の値に置き換えます。`.env` は公開しません。

```bash
cp .env.example .env
cp infra/params/phase1.example.json infra/params/phase1.local.json
# infra/README.md に従って main.bicep と照合し、ローカル JSON を完成させます。
# 要確認を解消後、.env の PHASE1_PARAMETERS_REVIEWED=true を設定します。
bash scripts/deploy_phase1.sh
```

4. [Phase 1](docs/10_phase1_minimum.md) の Application Insights、診断設定、Policy、Defender、agent 作成を手動で進めます。展開スクリプトだけでは統制設定は完了しません。
5. `bash scripts/verify_phase1.sh` と [10 個の検証項目](checks/README.md) で確認します。CLI 骨子は未検証項目を残して終了コード 2 を返します。
6. 作業後に `bash scripts/teardown.sh --delete '<resource-group-name>'`、続いて `bash scripts/teardown.sh --status` で削除を確認します。

このリポジトリを作成した時点では、上記コマンドは一度も Azure に対して実行していません。

## 7. 安全ルールと免責

個人の検証手順であり、所属組織の公式見解ではありません。運用・セキュリティ要件への適合は各自が確認します。実在の ID、組織名、社内ホスト名、API キー、接続文字列、実データを公開しません。サンプルには架空の入力のみを使います。

モデル向けガードレールは GA ですが、エージェント向け guardrails、Tool call / Tool response 介入点、Task Adherence は Preview です。本番の唯一の防御にしません。hosted agent は存在しない RAI ポリシー ID を指定するとフィルタなしで動く（fail open）ため、存在と適用結果を検証します。[ガードレール](https://learn.microsoft.com/en-us/azure/foundry/guardrails/guardrails-overview)

各回の終了時に削除・残存リソース・翌日以降の費用を確認します。ログや削除済みリソース、サブスクリプションの課金プランは RG 削除と分けて確認します。

## 8. 本番で足すもの

- Microsoft Agent 365：エージェント単位の Defender 脅威検知、Conditional Access for agents、全社台帳。本手順には含めません。2026-07-01 以降に Agent 365 が必要という前提で、ライセンスと適用範囲を確認します。[関連資料](https://learn.microsoft.com/en-us/azure/defender-for-cloud/ai-onboarding)
- Firewall Standard：Basic から見直し、必要な制御・容量・費用を評価します。
- APIM Standard v2（または Premium v2）＋ Private Endpoint：閉域 Foundry との結合を設計します。PE だけで経路・名前解決がすべて成立するとは扱いません。[接続要件](https://learn.microsoft.com/en-us/azure/foundry/configuration/enable-ai-api-management-gateway-portal)
- Microsoft Purview：データ保護の対象、ライセンス、適用範囲は要確認です。

## 9. ライセンス

この手順集は [MIT License](LICENSE) です。公式テンプレートは別途取得し、配布元のライセンスと著作権表示を保持します。[利用表記](NOTICE.md) を参照してください。
