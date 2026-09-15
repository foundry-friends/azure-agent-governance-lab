# 1. 準備と土台

このセクションを使う Run: Run 1／Run 2。先に要るセクション: なし（Run 0 で事前確認）。

> **Note** 現在は骨組み・Azure 未実行です。コマンドはリポジトリ直下の Bash で実行する予定の手順です。

## 1.1. 目的

統制層⑩と⑦の土台として、専用 RG、命名、予算通知、Log Analytics と実行ツールを準備します。

## 1.2. 前提

1. [Run 0](runs/run0.md) の権限・予算・公開規程を確認します。
2. RG Owner、またはリソース作成権限と User Access Administrator の実効スコープを確認します。
3. Policy 割当と Defender 設定の権限を確認します。
4. Japan East のモデル提供・クォータを確認します。

> **Note** 要確認: Azure CLI 2.50 以上という既存の最低条件だけで対応を保証せず、固定テンプレートに対応する CLI / Bicep の版を Run 0 で記録します。

## 1.3. 構築

### ローカル設定を準備する

1. 既存の `.env` がないことを確認します。
2. 設定例をコピーします。

```bash
cp .env.example .env
```
実行結果の確認ポイント: 既存設定を上書きしていないことを確認します。

3. エディターで下表の値を入力します。

| 項目 | 値 |
|---|---|
| サブスクリプション・テナント・RG | 検証専用の値を `.env` だけに保存 |
| AZURE_LOCATION | `japaneast` |
| ALLOWED_IP_RANGES | 承認された社内 IPv4 CIDR の JSON 配列を引用符で囲む（S3） |
| deploymentTimestamp | 同じ RG の再実行で固定する文字列 |
| タグ | 匿名の `purpose=agent-governance-lab`、Run、削除予定 |

4. 信頼できるローカル設定を読み込みます。

```bash
source .env
```
実行結果の確認ポイント: API キー・接続文字列を追加していないことを確認します。

5. 現在のテナントを照合します。

```bash
az account show --subscription "$AZURE_SUBSCRIPTION_ID" --query '{subscription:id,tenant:tenantId}' --output table
```
実行結果の確認ポイント: `.env` の対象と一致することを確認します。

### 土台を準備する

1. Azure portal <https://portal.azure.com> に移動します。
2. [リソース グループ] で専用 RG を作成します。
3. [Log Analytics ワークスペース] で専用ワークスペースを作成します。
4. ワークスペースの [使用量と推定コスト] で保持を 30 日に設定します。
5. ワークスペースの ARM ID を `.env` の `LOG_ANALYTICS_RESOURCE_ID` に記録します。
6. [コストの管理] の [予算] で月予算と通知先を設定します。
7. [固定版](../infra/PINNED_COMMIT.md) と [パラメータ](../infra/params/41_parameters.md) を照合します。

| 項目 | 値 |
|---|---|
| 予算通知候補 | 50% / 80% / 100% と予測超過 |
| 月予算 | 合意した上限（見積り v3 を参照） |
| LAW 所有 | S1 で作成し、S6 で既存 ID を参照 |

> **Note** 要確認: 41 には tags param がありません。自前リソースのタグは Bicep に設定し、41 管理リソースのタグは S5 で後追いします。

## 1.4. 確認

C10: 通知先・しきい値・通知の実確認を記録します。予算通知を自動停止とは扱いません。

```bash
bash scripts/verify.sh --section 1
```
実行結果の確認ポイント: 設定収集または案内のみで、未完了は終了コード 2 です。

[確認項目](../checks/README.md) ごとに実施日・Run・入力・期待結果・実結果・Pass / Fail / Pending を非公開の `evidence/` に記録します。未実施は Pending です。

## 1.5. うまくいかない場合

（Run 1 初回で記入）

1. 権限不足の場合は実効スコープを確認します。
2. クォータ不足の場合は展開を保留します。
3. 別テナントの場合は対象を修正してから再確認します。

## 1.6. 削除

1. 当日に構築したリソースと共有依存を確認します。
2. [S9](90-cleanup-cost.md) に従って専用 RG を削除します。
3. RG 外・soft-delete・Defender の設定を別々に確認します。

> **Note** 要確認: 部分削除時の依存・capability host の再作成可否は（Run 1 初回で記入）です。

## 1.7. 費用

| Excel v3 明細 No | 項目 | 通常月 USD |
|---|---|---:|
| 6 | Log Analytics / Analytics Logs 取り込み | 10.020000 |
| 9 | Entra ID / Managed Identity / RBAC / 基本機能 | 0.000000 |
| 10 | Azure Policy / Cost Management 予算アラート / Activity Log / 基本機能 | 0.000000 |
| 18 | Log Analytics / 保持（30日既定） | 0.000000 |

2026-09-15 の見積り v3 の既定値です。Japan East、原則 32h/月の検証、CSPM は既定 OFF です。No.8 と No.12 は常時／検証日の切替で、二重計上しません。No.6 は S1/S6 の共通費です。見積り保証ではありません。

## 1.8. 本番との差

保持期間・可用性・予算運用は本番要件で決めます。[付録 B](92-appendix-production-diff.md) を参照します。

---

前へ: [概要](../README.md) / 次へ: [ID と権限](02-identity.md) / [トップに戻る](../README.md)
