# S0：この手順で作るものと得られること

骨組み・Azure 未実行。総所要時間は約70h（コア54h、最小約52h）。

## 1. この手順をやると何が得られるか

- 統制の10層を手で触って理解できる。
- お客様に提案できる Baseline 準拠の全体像を自分の言葉で持てる。
- 自分の環境で再現できる IaC と確認手順が手に入る。

以上は実施・再現確認後の到達目標です。現在の IaC は未コンパイルで、再現性を実証済みではありません。

## 2. 最終構成図

[Baseline Microsoft Foundry chat reference architecture](https://learn.microsoft.com/en-us/azure/architecture/ai-ml/architecture/baseline-microsoft-foundry-chat) を参照し、学習用に段階を分けます。Baseline 全体を最初から構築する手順ではありません。

サービス全体像（青 = Azure 内で完結、オレンジ = Agent 365 が必要、破線 = Preview）:

![サービス全体像](../../images/01_service_map.png)

構成 A（Azure 内で完結する標準構成）:

![構成 A](../../images/02_pattern_A_azure_only.png)

Run 1 は Foundry project と自前 Cosmos DB / Storage / AI Search / Key Vault、監査・権限制御を扱います。Run 2 では BYO VNet の別環境を新規作成します。Run 3 の APIM Basic v2 は公開側の別環境で検証します。Run 1 のアカウントへ VNet injection を後付けすることはできません。[ネットワーク仕様](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/networking-options)

図は最終的に理解する全体像です。青＝Azureで完結、オレンジ＝Agent 365が必要で今回対象外、破線＝Preview。Run 2の閉域とRun 3の公開ゲートウェイは別環境で検証します。

## 3. 10 層と確認項目の対応表

| 層 | 担うセクション | 確認項目 | Run |
|---|---|---|---|
| ① ID・権限 | S2・S5 | C02・C03 | 1（2・3再確認） |
| ② ネットワーク境界・送信制御 | S3 | C08 | 2 |
| ③ ゲートウェイ | S7 | C09 | 3 |
| ④ ガードレール | S5・S7 | C09 | 3（設定は1） |
| ⑤ 脅威検知・態勢 | S8 | C07 | 1 |
| ⑥ 評価・レッドチーム | S8 | C06・C07の補足（専用Cなし） | 3 |
| ⑦ 監査・トレース | S1・S6 | C04・C05 | 1（2・3再確認） |
| ⑧ データ保護 | S4・S5 | C01 | 1・2 |
| ⑨ ポリシー | S8 | C06 | 1・3 |
| ⑩ コスト・クォータ | S1・S7・S9 | C10・C09 | 1・2・3 |

C番号は [checks](../../checks/README.md) を維持します。評価・レッドチームには専用Cがないため、補足試験を記録してもC06/C07だけで評価の合格を代表させません。

## 4. セクションと Run の地図

| No | セクション | 1 行説明 |
|---|---|---|
| S0 | [この手順で作るものと得られること](00_overview.md) | 成果・図・地図・費用と全体時間 |
| S1 | [準備と土台](01_foundation.md) | 権限・RG・予算・命名・固定版 |
| S2 | [ID と権限](02_identity.md) | MI・RBAC・Key Vault・認証 |
| S3 | [ネットワーク](03_network.md) | BYO VNet・PE・DNS・Firewall |
| S4 | [データ基盤（Standard setup の BYO）](04_data.md) | 自前 Cosmos・Storage・AI Search |
| S5 | [Foundry とエージェント](05_foundry_agent.md) | モデル・capability host・prompt agent |
| S6 | [監視と監査](06_monitoring.md) | 診断ログ・本文トレース・閲覧制御 |
| S7 | [ゲートウェイと呼び出しアプリ](07_gateway_app.md) | APIM・呼び出しUI・最後にWAF |
| S8 | [ポリシー・脅威検知・評価](08_policy_defender_eval.md) | Policy・Defender・評価 |
| S9 | [削除と費用](09_teardown_cost.md) | 削除・残存・翌日の費用 |
| 付録 A | [作り込み（hosted agent）の分岐](appendix_a_hosted_agent.md) | 任意・骨子のみ |
| 付録 B | [本番との差（Baseline）](appendix_b_production_diff.md) | SKU と常設範囲の差・骨子のみ |

### 計画のセクション対応

| No | セクション | 中身（リソース） | 統制の層 | 依存 | 確認項目（リポの C 番号） | 費用（Excel 明細） | 公式テンプレとの対応 | 初めて書く Run |
|---|---|---|---|---|---|---|---|---|
| **S0** | この手順で作るものと得られること | メリット 3 つ、最終構成図（`images/01`・`02`。**閉域要素は「本番で足すもの」と注記**）、**ネットワーク前提 N1〜N3**、10 層と C01〜C10 の対応、セクションと Run の地図、費用、総所要時間 | 全体 | なし | — | — | — | Run 0 |
| **S1** | 準備と土台 | サブスク・RG・命名とタグ・予算アラート・権限確認（RG Owner / UAA、Policy 割当、Defender）・Log Analytics workspace・CLI と Bicep の固定・公式テンプレのコミット固定・**社内 IP リストの確定（`.env`）** | ⑩、⑦ の土台 | なし | C10 | LA、無償項目 | 41 の前提 | Run 1 |
| **S2** | ID と権限 | Managed Identity、Foundry RBAC（Azure AI User / Agent Consumer / Developer）、Key Vault、ローカル認証の無効化、**Entra 条件付きアクセス（既存・変更しない）と CAE の確認** | ① ID・権限 | S1 | C02、C03 | KV、無償 | 41 が MI とロール割当を含む | Run 1 |
| **S3** | ネットワーク境界（IP 許可リストと送信の絞り込み） | **閉域なし**の設計。各リソースの `publicNetworkAccess` / `networkAcls`（既定拒否＋社内 IP）、「信頼された Azure サービス」の例外、送信の方式 A（ツール許可・APIM 経由）と方式 B（Managed VNet）の比較表、使わないもの（PE・VNet injection・Firewall・Bastion） | ② ネットワーク境界・送信制御 | S1 | **C08（v2）: 許可 IP から成功・許可外 IP から拒否・agent service の到達・未許可の MCP が失敗** | — | 41 に networkAcls の param があるか要確認。無ければ後追いの `az` 設定 | Run 1（IP 制限）、Run 2（送信） |
| **S4** | データ基盤（Standard setup の BYO） | Cosmos DB（サーバーレス）、Storage、AI Search Basic。**各リソースの IP 許可リストと信頼サービス例外** | ⑧ データ保護 | S1、S3 | C01 | Cosmos、Storage、Search | 41 の BYO 部分 | Run 1 |
| **S5** | Foundry とエージェント | Foundry account / project（**networkAcls＝社内 IP**）、モデル配置（gpt-5 mini Global Standard）、capability host（Standard setup・**VNet injection なし**）、prompt agent、Guardrails、**ツール方針（公開ツール不使用・MCP は APIM 経由）** | ①〜④ の結節点 | S2、S4 | C01、C09 の一部 | Foundry、モデル、Content Safety | 41 の本体 | Run 1 |
| **S6** | 監視と監査 | App Insights、診断設定（Foundry・Cosmos・Search・KV・APIM → LA）、トレース、Activity Log、Purview Audit トグル、**ネットワーク拒否のログの所在（要確認）** | ⑦ 監査 | S1、S5 | C04、C05 | LA、App Insights | 41 の出力 + 自前 | Run 1 |
| **S7** | ゲートウェイと呼び出しアプリ | APIM Basic v2（**`ip-filter` で社内 IP のみ**、AI Gateway: token quota / content safety / LLM ログ、**MCP ツールの唯一の出口**）、App Service B1（**access restrictions＝社内 IP**、OBO）。**WAF は使わない**（付録 B へ） | ③ ゲートウェイ、⑩ 上限、② 送信 | S1、S2、S5、S6 | C09 | APIM、App Service | 自前モジュール | Run 2 |
| **S8** | ポリシー・脅威検知・評価 | Azure Policy（**「公開ネットワークアクセス無制限を拒否」「ローカル認証を拒否」**を Deny、承認モデル限定）、Defender for AI Services、Defender CSPM（課長判断）、継続評価・Red Teaming | ⑤ ⑥ ⑨ | S1、S5 | C06、C07 | Defender | 自前 | Run 1（監査）、Run 2（Deny・評価） |
| **S9** | 削除と費用 | teardown、残存確認（KV soft-delete、Cosmos、Defender プラン）、コスト分析、実績 | ⑩ | 全部 | C10 | — | 自前 | Run 1 |
| 付録 A | 作り込み（hosted agent）の分岐 | 専用 identity・egress controls・HITL と Purview middleware | D11 | S5 | — | 対象外 | — | 任意 |
| 付録 B | 本番との差（Baseline） | **閉域（PE・VNet injection・Firewall）、WAF、APIM Standard v2、AI Search S1、Cosmos 3000 RU/s、Bastion、GRS** | — | — | — | 約 $2,900/月 | — | Run 4 |

### Run の組み合わせ

| Run | 名前 | 立てるセクションとパラメータ | 確認する統制（C） | 都度構築の費用（Excel v3 既定値） | 日数 |
|---|---|---|---|---|---|
| Run 0 | 準備（机上） | S1 の権限確認・**社内 IP の確定・Entra CA と CAE の確認**・テンプレのコミット固定・パラメータ確定（**41 に networkAcls / publicNetworkAccess の param があるか**）・予算アラート。Excel v3 で上長承認 | — | $0 | 承認待ちと並行 |
| **Run 1** | 最小構成＋入口の IP 制限 | S1、S2、S3（IP 制限）、S4、S5、S6、S8（Policy 監査 + Defender AI 無料枠）、S9。`enableApim=false`、`allowedIpRanges=<社内 IP>` | C01、C02、C03、C04、C05、C06（監査）、C07、**C08（IP 制限と agent service の到達）**、C10 | 常時分 + 従量分 ≈ 月 $46 | 2 日 |
| **Run 2** | 送信の絞り込みとゲートウェイ | S1、S2、S3（方式 A）、S4、S5、S6、**S7**、S8（Deny・評価・Red Teaming）、S9。`enableApim=true`。MCP ツールを APIM 経由に統一し、未許可先を呼ぶツールが失敗することを確認 | **C09**、**C08（送信）**、C06（Deny）、C10（quota 403） | + APIM + App Service ≈ 1 日 $2 | 2 日 |
| Run 3（任意） | Managed VNet（方式 B） | 別 account を CLI（preview）で Managed VNet「承認した送信先のみ」で作成し、FQDN 許可で MCP ツールの可否を確認。戻せないので専用 RG で作って壊す | C08（方式 B） | managed Firewall 課金（単価要確認、8h で $10 前後）| 1 日 |
| Run 4 | 執筆と公開 | セクション文書の整形、要確認の消し込み、費用実績、規程 OK なら Public 化 | — | — | 1〜2 週 |
| Run 5 | 部内展開 | 勉強会（Run 1 を SE が再現）、Issue で回収 | — | — | 随時 |

Run 1 は S1・S2・S4・S5・S6・S8・S9。初回は作りながら書き、再現日は書いた手順だけで再現します。2回目が通ったセクションだけ執筆済みとし、公開前に規程を確認します。

## 5. 費用の目安

| 条件 | 費用 USD |
|---|---:|
| 既定値・通常月 | $77.13 / 月 |
| 既定値・3か月（AI Services初月無料近似） | $223.38 |
| 既定値・12か月（同上） | $917.53 |
| CSPM ON（単独切替） | 約 $128 / 月 |
| AI Search 常時（単独切替） | 約 $170 / 月 |

2026-09-15 見積り report v2。Japan East、USD、730h/月、原則32h/月の検証、WAF8h/月、CSPM既定OFF、DNS6 zone仮置き。見積り保証ではない。無料枠・契約・SKU・リージョン・税・通信・未計上従量は要確認。公式41の既定構成の料金ではなく、目標SKUを実現した場合の概算です。詳細と初期概算の履歴は [S9](09_teardown_cost.md)。

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

## 7. やらないこと

Agent 365、hosted agent の本編、閉域と APIM の結合、Bastion、Purview の有償機能、本番運用は対象外です。hosted agent は任意の付録 A、Baselineとの差は付録 B に留めます。

### 初期骨組みの将来検討項目（対象外として保持）

- Microsoft Agent 365：エージェント単位の Defender 脅威検知、Conditional Access for agents、全社台帳。本手順には含めません。2026-07-01 以降に Agent 365 が必要という前提で、ライセンスと適用範囲を確認します。[関連資料](https://learn.microsoft.com/en-us/azure/defender-for-cloud/ai-onboarding)
- Firewall Standard：Basic から見直し、必要な制御・容量・費用を評価します。
- APIM Standard v2（または Premium v2）＋ Private Endpoint：閉域 Foundry との結合を設計します。PE だけで経路・名前解決がすべて成立するとは扱いません。[接続要件](https://learn.microsoft.com/en-us/azure/foundry/configuration/enable-ai-api-management-gateway-portal)
- Microsoft Purview：データ保護の対象、ライセンス、適用範囲は要確認です。
