# Azure でガバナンス付きエージェント環境を作る（Microsoft Foundry・構成 A）

## 概要

Microsoft Foundry の prompt agent を主線として、Azure 内で統制付きエージェント環境を作る手順です。構成 A（Agent 365 なし）を扱います。閉域接続は作らず、入口は社内 IP の許可リストに限定し、送信は公開ツール不使用と APIM 経由の許可先に絞ります。各 Run で作成・検証・削除し、初回の手順を再現日に確かめます。

> [!IMPORTANT]
> 本手順はベストプラクティスを示すものではなく、統制を手で触って理解する学習用サンプルです。

> [!IMPORTANT]
> **現在は骨組み・Azure 未実行です。** IaC は未コンパイルで、再現性を実証した完成手順ではありません。固定停止点を残しています。

> [!IMPORTANT]
> 個人の検証手順であり、所属組織の公式見解ではありません。

## この手順で得られること

- 統制の 10 層を手で触って理解できます。
- 提案で使える Baseline 準拠の全体像を理解できます。
- 自分の環境で再現できる IaC と確認手順を整えられます。

以上は実施・再現確認後の到達目標です。[設計判断 D1〜D12](docs/00_design.md) と合わせて読みます。

## 最終構成図

![構成 A](images/02_pattern_A_azure_only.png)

図の閉域要素（PE・VNet・Firewall）と WAF は本手順では作りません。本番で足すものとして [付録 B](docs/92-appendix-production-diff.md) で扱います。

<details>
<summary>サービス全体像</summary>

![サービス全体像](images/01_service_map.png)

青は Azure 内、オレンジは対象外の Agent 365、破線は Preview を含む全体像です。図中の全機能を構築する手順ではありません。

</details>

## ネットワークの前提

| # | 前提 | Azure での実装 | どのセクション |
|---|---|---|---|
| N1 | **閉域接続はしない** | Private Endpoint・BYO VNet injection・VPN・ExpressRoute・Bastion・Azure Firewall（自前）は使わない。すべて公開エンドポイント | S3 で「使わないもの」として明記。付録 B（本番との差）に閉域 Baseline を残す |
| N2 | **インターネット全公開はしない（入口を社内 IP に絞る）** | (a) **Entra 側**: 既存の条件付きアクセス（ネームドロケーション＝社内 IP）でサインインを制限。**既存設定・このリポでは変更しない**。継続的アクセス評価（CAE）が有効かを Run 0 で確認 (b) **リソース側（多層防御）**: Foundry account・Key Vault・Storage・Cosmos DB・AI Search・APIM・App Service の公開エンドポイントに「選択したネットワークと IP」＝既定拒否＋社内 IP の許可リスト。社内 IP は `.env` に置きコミットしない | S3（設計）、S4・S5・S7（各リソースの設定） |
| N3 | **アウトバウンドは最低限に絞る** | エージェントは Microsoft 管理ネットワークから送信するので、自前 Firewall では絞れない。方式は 2 つ。**方式 A（ツール層で絞る・Run 1〜2）**: Bing / Web search / SharePoint 等の公開ツールを使わない（作れないように RBAC と手順で縛る）、MCP / OpenAPI ツールは **APIM 経由の許可リストのみ**、モデルは Foundry 内のみ。**方式 B（Managed VNet）は対象外**（v2.1）: 機能は 2026-05 GA だが作成は CLI preview のみで「Preview 手順は載せない」方針に反する。S3 に「使わない理由」として 1 段落だけ残す | S3（方式 A の設計と、B を使わない理由）、S7（APIM） |

> **Note** 要確認: agent service が IP 制限下の BYO リソースに到達できるかは C08 で確認します。失敗時は S3/S4/S5 の「うまくいかない場合」を使い、例外を記録します。

## 10 層と確認項目の対応

| 層 | 担うセクション | C 番号 | Run |
|---|---|---|---|
| ① ID・権限 | S2・S5 | C02・C03 | 1（2 で再確認） |
| ② ネットワーク境界・送信制御 | S3 | C08 | 1・2 |
| ③ ゲートウェイ | S7 | C09 | 2 |
| ④ ガードレール | S5・S7 | C09 | 1（設定）・2 |
| ⑤ 脅威検知・態勢 | S8 | C07 | 1・2 |
| ⑥ 評価・レッドチーム | S8 | C06・C07 の補足（専用 C なし） | 2 |
| ⑦ 監査・トレース | S1・S6 | C04・C05 | 1（2 で再確認） |
| ⑧ データ保護 | S4・S5 | C01 | 1・2 |
| ⑨ ポリシー | S8 | C06 | 1（Audit）・2（Deny） |
| ⑩ コスト・クォータ | S1・S7・S9 | C10・C09 | 1・2 |

評価の補足試験は C06/C07 の合格だけで代表させません。[確認項目](checks/README.md) は全件 Pending から始めます。

## ハンズオン

### Run 0: 準備（机上）

1. [準備と土台](docs/01-prerequisites.md)
2. [ID と権限](docs/02-identity.md)
3. [Run 0 の当日手順](docs/runs/run0.md)

### Run 1: 最小構成＋入口の IP 制限

1. [ネットワーク境界（IP 許可リストと送信の絞り込み）](docs/10-network-boundary.md)
2. [データ基盤（Standard setup の BYO）](docs/11-data.md)
3. [Foundry とエージェント](docs/12-foundry-agent.md)
4. [監視と監査](docs/13-monitoring.md)
5. [ポリシー・脅威検知・評価（監査部分）](docs/15-policy-defender-eval.md)
6. [削除と費用](docs/90-cleanup-cost.md)
7. [Run 1 の当日手順](docs/runs/run1.md)

### Run 2: 送信の絞り込みとゲートウェイ

1. [ゲートウェイと呼び出しアプリ](docs/14-gateway-app.md)
2. [ポリシー・脅威検知・評価（Deny・評価）](docs/15-policy-defender-eval.md)
3. [Run 2 の当日手順](docs/runs/run2.md)

### 後作業

1. [削除と費用](docs/90-cleanup-cost.md)

### 付録

1. [作り込み（hosted agent）の分岐 (任意)](docs/91-appendix-hosted-agent.md)
2. [本番との差（Baseline）](docs/92-appendix-production-diff.md)

## 所要時間

| Run | 内訳 | 時間 | 分割できるか |
|---|---|---|---|
| Run 0 準備（机上） | 会社ルール・権限・社内 IP・CA の確認 2h、テンプレ固定とパラメータ確定のレビュー 2h、組み替えたリポのレビュー 2h | **6h** | 1〜2h 単位で可 |
| Run 1 最小構成＋IP 制限 | 初回 8h（構築 3・検証 3・執筆 1・削除 1）＋ 再現 8h | **16h** | 1 日は 8h 連続が理想。取れなければ 4h × 2 に分け、間は壊さず置く（1 日置いても数ドル） |
| Run 2 送信の絞り込みとゲートウェイ | 初回 8h ＋ 再現 8h | **16h** | 同上 |
| Run 3 執筆と公開 | 整形・要確認の消し込み・費用実績・公開規程（Codex 支援、たかしはレビュー中心） | **8〜12h** | 1〜2h 単位で可 |
| Run 4 部内展開 | 準備 4h ＋ 実施 2h | **6h** | 可 |
| **合計** | | **約 55〜60h（コア＝Run 0〜2 で 38h）** | |

**最小コース**: 再現日を Run 1 だけにする → 6 + 16 + 8 + 8 + 6 ＝ **約 44h**。公開時に Run 2 のセクションは「再現未確認」と明記。

計画値であり実測ではありません。Run 3・4 は執筆・展開活動で、構築用の当日手順は作りません。

## 費用の目安

| 条件 | USD |
|---|---:|
| 既定・通常月 | $57.56 |
| 既定・3 か月 | $164.67 |
| 既定・12 か月 | $682.68 |
| CSPM ON（単独切替） | $108.66 / 月 |
| AI Search 常時（単独切替） | $150.39 / 月 |

2026-09-15 の見積り Excel v3 に基づきます。Japan East、原則 32h/月、CSPM 既定 OFF、累計には Defender AI の初月無料近似を含みます。見積り保証ではありません。明細 No.1〜19 は [S9](docs/90-cleanup-cost.md) を参照します。

## 対象読者と前提

- Azure の RG、RBAC、ネットワークの基本を理解している SE を対象にします。
- 自分の検証用サブスクリプション、RG を作成する権限、対象 RG の Owner（またはリソース作成権限と User Access Administrator）が必要です。
- **リソースの作成と設定変更は Azure portal の GUI で行います**（登録する設定を自分の目で確かめるため）。設定の確認・照合に使うコマンドは Azure portal の Azure Cloud Shell（Bash）で実行し、ローカル PC には何も入れません。`infra/` の Bicep は再現用（任意）です。Japan East で利用するモデルの提供状況・クォータを確認します。
- Entra ID のみで認証し、API キーや接続文字列は使いません。hub-based project は新ポータルに対応しないため、Foundry project を使います。
- 「要確認」を解消してから実行します。現行 CLI と固定したテンプレートの対応は未検証です。


## 公開時の安全ルール

実在の ID、組織名、社内ホスト名、API キー、接続文字列、実データを公開しません。サンプルには架空の入力のみを使います。`.env`・`*.local.json`・`evidence/` は公開対象外です。

各回の終了時に削除・残存リソース・翌日以降の費用を確認します。ログや削除済みリソース、サブスクリプションの課金プランは RG 削除と分けて確認します。ガードレールの存在だけで有効とせず、合成入力で効果を確認します。

## 注意事項

本資料は実際の操作を通じて理解を深めるための学習資料です。記載内容は作成時点の情報に基づき、機能や画面、操作手順は変更される場合があります。特定の環境や要件に対する設計・実装を保証しません。**Preview 機能の手順は含めない**方針です。エージェント guardrails の Preview 介入点、Tool call / Tool response、Task Adherence、AI Gateway 統合の Preview 部分は対象外で、GA 後に追記します。

## ライセンス

[MIT License](LICENSE) です。公式テンプレートの配布元のライセンスと著作権表示を保持します。[NOTICE](NOTICE.md) を参照してください。
