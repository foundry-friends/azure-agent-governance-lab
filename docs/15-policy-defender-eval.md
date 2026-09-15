# 8. ポリシー・脅威検知・評価

このセクションを使う Run: Run 1／Run 2。先に要るセクション: S1・S5。

> **Note** 現在は骨組み・Azure 未実行です。コマンドはリポジトリ直下の Bash で実行する予定の手順です。

## 8.1. 目的

統制層⑤・⑥・⑨として、Policy の監査と拒否、Defender、合成入力による評価を分けて確認します。

## 8.2. 前提

S1・S5 と Policy 割当権限が必要です。Defender はサブスクリプション単位の課金・変更前状態・復帰方法を管理者と合意します。CSPM は既定 OFF です。

## 8.3. 構築

### Policy を割り当てる

1. [Policy] の [定義] で対象リソース型と許容 effect を確認します。
2. [パラメータ例](../assets/policy/assignment.example.json) をローカル設定へコピーします。
3. Run 1 は `effect=Audit` に設定します。
4. 対象を専用 RG に限定して [割り当て] を作成します。
5. [コンプライアンス] で非準拠と理由を確認します。
6. Run 2 は下表の拒否対象を個別にレビューします。
7. 定義が対応する場合だけ `effect=Deny` に変更します。

| 項目 | 値 |
|---|---|
| 無制限公開の拒否 | 公開が Enabled かつ既定 Allow／IP 規則なし等を型別に評価（公開 Enabled 自体は禁止しません） |
| ローカル認証の拒否 | Foundry / Cosmos / Search の `disableLocalAuth`、Storage の `allowSharedKeyAccess` を型別に評価 |
| モデル制限 | 承認モデル限定 |
| Run 1 | Audit、違反を記録 |
| Run 2 | Deny、許可構成の成功と違反構成の拒否を確認 |

> **Note** 要確認: [定義例](../assets/policy/unrestricted-network.example.json) と [認証例](../assets/policy/local-auth.example.json) は Foundry のみの骨組みです。alias・型別の条件・空配列の意味・対応 effect を確認し、他の 6 リソースに対応したとは扱いません。Audit と `DoNotEnforce` は同義ではありません。41 の初期設定や S3 の復旧と Deny が競合する点も未解決です。

### Defender for AI Services を確認する

1. [Defender for Cloud] の [環境設定] で対象サブスクリプションを選択します。
2. [Defender プラン] で変更前状態を記録します。
3. 合意した AI Services のプランだけを設定します。
4. [セキュリティ アラート] で安全な公式検証に対応したイベントを確認します。

> **Note** 要確認: 現行の plan / subplan / extension、無料枠、安全な検知試験は（Run 1 初回で記入）です。有効化だけで検知成功とは扱いません。Agent 365 のエージェント単位機能は対象外です。

### Defender CSPM (任意)

1. 管理者が費用と対象範囲を承認した場合だけ CSPM を有効化します。
2. 変更前後の状態と対象範囲を記録します。

### 評価・レッドチーム

1. [合成プロンプト](../assets/prompts/README.md) で評価対象と期待結果を決めます。
2. GA の評価機能だけを使って実結果を記録します。
3. Japan East で GA の Red Teaming を利用できるか確認します。
4. 利用条件を確認できない機能は未実施として記録します。

> **Note** 要確認: 継続評価 UI・個別 evaluator・Red Teaming の提供・課金・上限は Run 2 で確認します。Preview 機能の操作は載せず、GA 後に追記します。新しい C 番号は追加しません。

## 8.4. 確認

C06: Audit の検出と Deny の拒否を別 Run として記録します。C07: プラン状態・費用・実イベントを区別します。評価・レッドチームは C06/C07 の補足証跡に残します。

```bash
bash scripts/verify.sh --section 8
```
実行結果の確認ポイント: 設定収集または案内のみで、未完了は終了コード 2 です。

[確認項目](../checks/README.md) ごとに実施日・Run・入力・期待結果・実結果・Pass / Fail / Pending を非公開の `evidence/` に記録します。未実施は Pending です。

## 8.5. うまくいかない場合

（Run 1 初回で記入）

1. 割当スコープと定義の effect を確認します。
2. Deny が BYO の復旧を妨げる場合は、当該リソース・期間・理由を限定した例外を管理者と確認します。
3. 例外の手続きが未確定なら復旧の変更を保留します。
4. 他リソースまで一括で Deny を解除しません。

## 8.6. 削除

1. この検証で追加した Policy 割当を確認します。
2. 専用 RG を S9 に従って削除します。
3. Defender の設定を合意した変更前状態へ戻します。
4. 既存プランを一律に無効化していないことを確認します。

## 8.7. 費用

| Excel v3 明細 No | 項目 | 通常月 USD |
|---|---|---:|
| 10 | Azure Policy / Cost Management 予算アラート / Activity Log / 基本機能 | 0.000000 |
| 17 | Defender for AI Services / Standard | 8.000000 |
| 19 | Defender CSPM / Standard | 0.000000 |

2026-09-15 の見積り v3 の既定値です。Japan East、原則 32h/月の検証、CSPM は既定 OFF です。No.8 と No.12 は常時／検証日の切替で、二重計上しません。No.6 は S1/S6 の共通費です。見積り保証ではありません。

No.17 は通常月 $8、累計は初月無料を 1 か月と近似します。No.19 は ON の場合に月 $51.10 を追加し、全体で月 $108.66 です。

## 8.8. 本番との差

本番は例外の期限・承認・監査と継続評価を運用化します。[付録 B](92-appendix-production-diff.md) を参照します。

---

前へ: [ゲートウェイと呼び出しアプリ](14-gateway-app.md) / 次へ: [削除と費用](90-cleanup-cost.md) / [トップに戻る](../README.md)
