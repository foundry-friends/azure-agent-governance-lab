# 2. ID と権限

このセクションを使う Run: Run 1／Run 2。先に要るセクション: S1。

> **Note** 現在は骨組み・Azure 未実行です。コマンドはリポジトリ直下の Bash で実行する予定の手順です。

## 2.1. 目的

統制層①として、Managed Identity、RBAC、Key Vault と Entra ID のみの認証を準備します。

## 2.2. 前提

1. [S1](01-prerequisites.md) の作成・ロール割当権限を確認します。
2. Entra 管理センターで [保護] の [条件付きアクセス] を開きます。
3. 既存ポリシーの対象ユーザー・対象リソース・ネームドロケーションを読み取ります。
4. [サインイン ログ] の検証用サインインで適用された条件付きアクセスを確認します。
5. 対応するクライアントとリソースの CAE 適用状況を確認します。
6. 設定を変更せず、結果を Run 0 に記録します。

> **Note** 要確認: CAE は対象サービス・クライアント・トークンに依存します。画面の表示項目と Foundry 呼び出しへの適用範囲を記録し、Entra 設定だけで全データプレーンが IP 制限されたとは扱いません。

> **Note** 要確認: Azure AI User / Agent Consumer / Developer と現行ロール名・権限の対応を確認します。Owner を使って最小権限試験をしません。

## 2.3. 構築

1. [02_keyvault.bicep](../infra/modules/02_keyvault.bicep) の設定を下表と照合します。
2. S5 のラッパ展開時に Key Vault を自前モジュールで作成します。
3. 41 が作る account / project の system-assigned MI を確認します。
4. 検証用の Consumer / User / 無権限主体を用意します。
5. [アクセス制御 (IAM)] で必要なスコープだけにロールを割り当てます。
6. publish 後は専用 agent identity と RBAC を再確認します。

| 項目 | 値 |
|---|---|
| Key Vault 認可 | `enableRbacAuthorization=true` |
| Key Vault ネットワーク | 公開エンドポイント、既定 Deny、社内 IP、`bypass=AzureServices` |
| 用途 | RBAC・監査の検証（API キー保管による代用はしません） |
| データ認証 | S4 のローカル認証無効＋41 の MI 接続 |
| Foundry 認証 | S5 の後追いで `disableLocalAuth=true` |
| App Service MI | S7 で作成 |

> **Note** 要確認: Key Vault の信頼サービス例外はすべての Azure 発信元を許可する設定ではありません。利用主体の到達と権限は実機で確認します。

## 2.4. 確認

C02: 呼び出し・作成・編集を主体別に試し、継承権限の混入を確認します。C03: ローカル認証無効、Entra ID 成功、未認証拒否を分けて記録します。キーは取得しません。

```bash
bash scripts/verify.sh --section 2
```
実行結果の確認ポイント: 設定収集または案内のみで、未完了は終了コード 2 です。

[確認項目](../checks/README.md) ごとに実施日・Run・入力・期待結果・実結果・Pass / Fail / Pending を非公開の `evidence/` に記録します。未実施は Pending です。

## 2.5. うまくいかない場合

（Run 1 初回で記入）

1. ネットワーク拒否と RBAC 拒否を切り分けます。
2. データ基盤への到達失敗は [S4 の代替手順](11-data.md) で扱います。
3. Key Vault は用途・権限を再確認し、無条件公開へ変更しません。

## 2.6. 削除

1. 当日に構築したリソースと共有依存を確認します。
2. [S9](90-cleanup-cost.md) に従って専用 RG を削除します。
3. RG 外・soft-delete・Defender の設定を別々に確認します。

> **Note** 要確認: 部分削除時の依存・capability host の再作成可否は（Run 1 初回で記入）です。

## 2.7. 費用

| Excel v3 明細 No | 項目 | 通常月 USD |
|---|---|---:|
| 5 | Key Vault / Standard 操作 | 0.030000 |
| 9 | Entra ID / Managed Identity / RBAC / 基本機能 | 0.000000 |

2026-09-15 の見積り v3 の既定値です。Japan East、原則 32h/月の検証、CSPM は既定 OFF です。No.8 と No.12 は常時／検証日の切替で、二重計上しません。No.6 は S1/S6 の共通費です。見積り保証ではありません。

## 2.8. 本番との差

本番は職務分離と identity のライフサイクルを設計します。[付録 B](92-appendix-production-diff.md) を参照します。

---

前へ: [準備と土台](01-prerequisites.md) / 次へ: [ネットワーク境界（IP 許可リストと送信の絞り込み）](10-network-boundary.md) / [トップに戻る](../README.md)
