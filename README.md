# Azure でガバナンス付きエージェント運用環境を作る手順

## 1. これは何か

部内の SE メンバーが、それぞれの Azure 検証環境にガバナンス付きエージェント環境を再現するための手順集です。Microsoft Foundry（旧 Azure AI Foundry）の Foundry Agent Service（Responses API ベースの新ランタイム、2026-03 GA）を使います。**構成 A：Azure 内で完結、Microsoft Agent 365 なし**が対象です。現在は骨組みと未実行のドラフトであり、Azure での構築・動作確認はまだ行っていません。

**総所要時間は約70h、Run 0〜3のコアは54h、最小コースは約52h。** 詳細は §6。承認待ち・提供待ちは含みません。

## 2. まず読む

[S0：この手順で作るものと得られること](docs/sections/00_overview.md) で、作るものと確認できる統制を理解してから進みます。[設計判断 D1〜D11](docs/00_design.md) も参照してください。

![サービス全体像](images/01_service_map.png)

## 3. 対象読者と前提

- Azure の RG、RBAC、ネットワークの基本を理解している SE を対象にします。
- 自分の検証用サブスクリプション、RG を作成する権限、対象 RG の Owner（またはリソース作成権限と User Access Administrator）が必要です。
- Azure CLI 2.50 以上、Bicep、Bash、Python 3（パラメータのローカル検査用）、Japan East で利用するモデルの提供状況・クォータを確認します。
- Entra ID のみで認証し、API キーや接続文字列は使いません。hub-based project は新ポータルに対応しないため、Foundry project を使います。
- 「要確認」を解消してから実行します。現行 CLI と固定したテンプレートの対応は未検証です。

## 4. セクション一覧

| No | セクション | 1 行説明 |
|---|---|---|
| S0 | [この手順で作るものと得られること](docs/sections/00_overview.md) | 成果・図・地図・費用と全体時間 |
| S1 | [準備と土台](docs/sections/01_foundation.md) | 権限・RG・予算・命名・固定版 |
| S2 | [ID と権限](docs/sections/02_identity.md) | MI・RBAC・Key Vault・認証 |
| S3 | [ネットワーク](docs/sections/03_network.md) | BYO VNet・PE・DNS・Firewall |
| S4 | [データ基盤（Standard setup の BYO）](docs/sections/04_data.md) | 自前 Cosmos・Storage・AI Search |
| S5 | [Foundry とエージェント](docs/sections/05_foundry_agent.md) | モデル・capability host・prompt agent |
| S6 | [監視と監査](docs/sections/06_monitoring.md) | 診断ログ・本文トレース・閲覧制御 |
| S7 | [ゲートウェイと呼び出しアプリ](docs/sections/07_gateway_app.md) | APIM・呼び出しUI・最後にWAF |
| S8 | [ポリシー・脅威検知・評価](docs/sections/08_policy_defender_eval.md) | Policy・Defender・評価 |
| S9 | [削除と費用](docs/sections/09_teardown_cost.md) | 削除・残存・翌日の費用 |
| 付録 A | [作り込み（hosted agent）の分岐](docs/sections/appendix_a_hosted_agent.md) | 任意・骨子のみ |
| 付録 B | [本番との差（Baseline）](docs/sections/appendix_b_production_diff.md) | SKU と常設範囲の差・骨子のみ |

## 5. Run 一覧

| Run | 名前 | 立てるセクションとパラメータ | 確認する統制（C） | 都度構築の費用（Excel v3 既定値） | 日数 |
|---|---|---|---|---|---|
| Run 0 | 準備（机上） | S1 の権限確認・**社内 IP の確定・Entra CA と CAE の確認**・テンプレのコミット固定・パラメータ確定（**41 に networkAcls / publicNetworkAccess の param があるか**）・予算アラート。Excel v3 で上長承認 | — | $0 | 承認待ちと並行 |
| **Run 1** | 最小構成＋入口の IP 制限 | S1、S2、S3（IP 制限）、S4、S5、S6、S8（Policy 監査 + Defender AI 無料枠）、S9。`enableApim=false`、`allowedIpRanges=<社内 IP>` | C01、C02、C03、C04、C05、C06（監査）、C07、**C08（IP 制限と agent service の到達）**、C10 | 常時分 + 従量分 ≈ 月 $46 | 2 日 |
| **Run 2** | 送信の絞り込みとゲートウェイ | S1、S2、S3（方式 A）、S4、S5、S6、**S7**、S8（Deny・評価・Red Teaming）、S9。`enableApim=true`。MCP ツールを APIM 経由に統一し、未許可先を呼ぶツールが失敗することを確認 | **C09**、**C08（送信）**、C06（Deny）、C10（quota 403） | + APIM + App Service ≈ 1 日 $2 | 2 日 |
| Run 3（任意） | Managed VNet（方式 B） | 別 account を CLI（preview）で Managed VNet「承認した送信先のみ」で作成し、FQDN 許可で MCP ツールの可否を確認。戻せないので専用 RG で作って壊す | C08（方式 B） | managed Firewall 課金（単価要確認、8h で $10 前後）| 1 日 |
| Run 4 | 執筆と公開 | セクション文書の整形、要確認の消し込み、費用実績、規程 OK なら Public 化 | — | — | 1〜2 週 |
| Run 5 | 部内展開 | 勉強会（Run 1 を SE が再現）、Issue で回収 | — | — | 随時 |

当日手順：[Run 0](docs/runs/run0_desk.md)／[Run 1](docs/runs/run1_public_minimum.md)／[Run 2](docs/runs/run2_private_network.md)／[Run 3](docs/runs/run3_gateway.md)。Run 4・5は将来の執筆・展開活動で、今回専用文書は作成しません。

## 6. 総所要時間

| Run | 内訳 | 時間 | 分割できるか |
|---|---|---|---|
| Run 0 準備（机上） | 会社ルール・権限・社内 IP・CA の確認 2h、テンプレ固定とパラメータ確定のレビュー 2h、組み替えたリポのレビュー 2h | **6h** | 1〜2h 単位で可 |
| Run 1 最小構成＋IP 制限 | 初回 8h（構築 3・検証 3・執筆 1・削除 1）＋ 再現 8h | **16h** | 1 日は 8h 連続が理想。取れなければ 4h × 2 に分け、間は壊さず置く（1 日置いても数ドル） |
| Run 2 送信の絞り込みとゲートウェイ | 初回 8h ＋ 再現 8h | **16h** | 同上 |
| Run 3 Managed VNet（任意） | 1 日 | **8h** | 任意。やらなくても公開できる |
| Run 4 執筆と公開 | 整形・要確認の消し込み・費用実績・公開規程（Codex 支援、たかしはレビュー中心） | **8〜12h** | 1〜2h 単位で可 |
| Run 5 部内展開 | 準備 4h ＋ 実施 2h | **6h** | 可 |
| **合計** | | **約 55〜60h（任意の Run 3 を除く。コア＝Run 0〜2 で 38h）** | |

**最小コース**: 再現日を Run 1 だけにする → 6 + 16 + 8 + 8 + 6 ＝ **約 44h**。公開時に Run 2 のセクションは「再現未確認」と明記。

計画値であり実測ではありません。表の約70hは70〜74hの丸め表現です。

## 7. 費用の目安

| 条件 | 費用 USD |
|---|---:|
| 既定値・通常月 | $77.13 / 月 |
| 既定値・3か月（AI Services初月無料近似） | $223.38 |
| 既定値・12か月（同上） | $917.53 |
| CSPM ON（単独切替） | 約 $128 / 月 |
| AI Search 常時（単独切替） | 約 $170 / 月 |

2026-09-15 見積り report v2。Japan East、USD、730h/月、原則32h/月の検証、WAF8h/月、CSPM既定OFF、DNS6 zone仮置き。見積り保証ではない。無料枠・契約・SKU・リージョン・税・通信・未計上従量は要確認。公式41の既定構成の料金ではなく、目標SKUを実現した場合の概算です。詳細と初期概算の履歴は [S9](docs/sections/09_teardown_cost.md)。

## 8. 公開時の安全ルール

実在の ID、組織名、社内ホスト名、API キー、接続文字列、実データを公開しません。サンプルには架空の入力のみを使います。

モデル向けガードレールは GA ですが、エージェント向け guardrails、Tool call / Tool response 介入点、Task Adherence は Preview です。本番の唯一の防御にしません。hosted agent は存在しない RAI ポリシー ID を指定するとフィルタなしで動く（fail open）ため、存在と適用結果を検証します。[ガードレール](https://learn.microsoft.com/en-us/azure/foundry/guardrails/guardrails-overview)

各回の終了時に削除・残存リソース・翌日以降の費用を確認します。ログや削除済みリソース、サブスクリプションの課金プランは RG 削除と分けて確認します。

## 9. 免責

個人の検証手順であり、所属組織の公式見解ではありません。運用・セキュリティ要件への適合は各自が確認します。

この手順集は [MIT License](LICENSE) です。公式テンプレートは別途取得し、配布元のライセンスと著作権表示を保持します。[利用表記](NOTICE.md) を参照してください。
