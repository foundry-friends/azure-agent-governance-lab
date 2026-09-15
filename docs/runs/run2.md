# Run 2. 送信の絞り込みとゲートウェイ

このセクションを使う Run: Run 2。先に要るセクション: Run 0（Run 2 は Run 1 の結果）。

> **Note** 骨組み・Azure 未実行です。

## 2.1. 目的

送信の絞り込みとゲートウェイを初回と再現の 2 日で検証します。

## 2.2. 前提

[Run 0](run0.md) の承認・権限・社内 IP・モデルクォータ・予算を確認します。 Run 1 の到達結果と公開復旧の例外も引き継ぎます。

## 2.3. 構築

### 当日の配分

| 時間帯 | 作業 | 時間 |
|---|---|---:|
| 0〜3h | 構築（待ち時間に執筆） | 3h |
| 3〜6h | 合成入力の検証 | 3h |
| 6〜7h | 文書と証跡を整理 | 1h |
| 7〜8h | 削除と残存確認 | 1h |

初回 8h＋再現 8h＝16h です。初回は作りながら書き、再現日は書いた手順だけで再現します。再現が通ったセクションだけ執筆済みとします。

セクションごとの初回目安: S7 の APIM と App Service 2.5h・S3 の方式 A 1h・S8 の Deny と評価 1.5h・検証 2h・S9 1h。 上表とは区分が異なる同じ 8h の内訳で、実測ではありません。

### セクションの順番

1. [S1: 準備と土台](../01-prerequisites.md) を進めます。
2. [S2: ID と権限](../02-identity.md) を進めます。
3. [S3: ネットワーク境界（IP 許可リストと送信の絞り込み）](../10-network-boundary.md) を進めます。
4. [S4: データ基盤（Standard setup の BYO）](../11-data.md) を進めます。
5. [S5: Foundry とエージェント](../12-foundry-agent.md) を進めます。
6. [S6: 監視と監査](../13-monitoring.md) を進めます。
7. [S7: ゲートウェイと呼び出しアプリ](../14-gateway-app.md) を進めます。
8. [S8: ポリシー・脅威検知・評価](../15-policy-defender-eval.md) を進めます。
9. [S9: 削除と費用](../90-cleanup-cost.md) を進めます。

### パラメータと入口

| 項目 | 値 |
|---|---|
| 入力例 | [run2.example.json](../../infra/params/run2.example.json) |
| enableApim | true |
| allowedIpRanges | `.env` と同じ社内 IP |
| Policy | Deny・評価 |
| 公式テンプレ | 41（BYO は自前 data outputs） |

1. パラメータ例をローカルにコピーします。

```bash
cp infra/params/run2.example.json infra/params/run2.local.json
```
実行結果の確認ポイント: 既存ファイルを上書きしていないことを確認します。

2. placeholder・metadata・未解決事項を確認します。
3. 実行入口を確認します。

```bash
bash scripts/deploy.sh --run 2
```
実行結果の確認ポイント: 現在は固定停止点で止まり、Azure へ送信しません。

> **Note** 要確認: 41 の初期設定・後追い更新・GA 適合性・サービス発信経路・S6 の接続を確定するまでは実行可能な完成手順ではありません。

## 2.4. 確認

C09・C08（送信）・C06（Deny）・C10（quota 403 と費用）。C01〜C07 の基盤も再確認します を [checks](../../checks/README.md) で確認します。期待結果・実結果・日付・Run・セクションを `evidence/` に記録します。未実施は Pending です。

## 2.5. うまくいかない場合

（Run 2 初回で記入）

1. agent service が BYO に届かない場合は [S3 の代替手順](../10-network-boundary.md) を使います。
2. 当該データだけ Entra 認証のみ＋公開に戻した結果を例外として記録します。
3. Run 2 の APIM 経路や Deny が競合する場合は S7/S8 へ戻ります。

## 2.6. 削除

1. [S9](../90-cleanup-cost.md) で対象を照合します。
2. 専用 RG を削除します。
3. RG 消失・soft-delete・RG 外・Defender 復帰を確認します。
4. 翌日以降の費用を確認します。

削除受付と課金停止は分けて記録します。

## 2.7. 費用

計画の目安は APIM＋App Service 追加で約 $2/日です。全体の Excel v3 既定は月 $57.56 です。Run 単独の厳密な積算ではありません。各セクションの v3 明細と実稼働時間を照合します。

## 2.8. 本番との差

[付録 B](../92-appendix-production-diff.md) に本番との差を残します。最小コースで Run 2 の再現日を省く場合は再現未確認と明記します。

---

前へ: [Run 1](run1.md) / 次へ: [削除と費用](../90-cleanup-cost.md) / [トップに戻る](../../README.md)
