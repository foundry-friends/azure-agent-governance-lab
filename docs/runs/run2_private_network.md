# Run 2：閉域（当日手順）

骨組み・Azure未実行。初回8h＋再現8h＝16h。詳細な構築・確認・削除はセクション文書を正とします。

## 0. 前日まで

- [Run 0](run0_desk.md) の承認・会社権限・モデルクォータ・予算アラートを確認。
- [公式パラメータ](../../infra/params/41_parameters.md) と [固定コミット](../../infra/PINNED_COMMIT.md) を照合。
- `.env` のtenant/subscription/RGが今回の専用環境か確認。ローカルJSONと.envは公開しない。
- Run 1と別RG・新account。15のREADMEはVNet背後tools非対応として19を案内しています。MCP/OpenAPIの閉域挙動は要確認のまま記録し、テンプレを勝手に19へ変更しません。Bing等のpublic経路例外を記録します。Monitor用PE/DNS追加と6個想定の費用差も要確認。

```bash
# リポジトリ直下。既存 .env がある場合は上書きせず内容を確認します。
# 初回だけ: cp .env.example .env
cp infra/params/run2.example.json infra/params/run2.local.json
# placeholder・metadata・未解決事項を解消し、RUN2_PARAMETERS_REVIEWED=trueにします。
# それだけでは骨組みの固定停止点は解除されません。実装レビューが必要です。
```

## 1. タイムライン

| 時間帯 | 作業 | 時間 |
|---|---|---:|
| 0〜3h | 構築（展開待ちに執筆） | 3h |
| 3〜6h | 合成入力による検証 | 3h |
| 6〜7h | 文書・要確認・証跡を整理 | 1h |
| 7〜8h | 削除・残存確認 | 1h |

計画§4.5のセクション別初回目安：S3 2h・S4 の PE と DNS 1h・S5（injection）1.5h・検証（閉域端末の用意を含む）2.5h・S9 1h。

全体の8h枠とセクション別目安は作業を重ねる計画値で実測ではありません。Run 1のセクション別数値は合計7.5hのため残り0.5hを調整枠とします。WAF1hはRun 3再現日の最後に含め、削除枠を確保します。

## 2. 立てるセクションと順番

1. [S1：準備と土台](../sections/01_foundation.md)。
2. [S2：ID と権限](../sections/02_identity.md)。
3. [S3：ネットワーク](../sections/03_network.md)。
4. [S4：データ基盤（Standard setup の BYO）](../sections/04_data.md)。
5. [S5：Foundry とエージェント](../sections/05_foundry_agent.md)。
6. [S6：監視と監査](../sections/06_monitoring.md)。
7. [S9：削除と費用](../sections/09_teardown_cost.md)。

`enablePrivateNetwork=true`。41ではなく15への分岐をRun 2で確定（要確認）。現在のdeploy.shは停止します。

```bash
# 未確定事項と停止点を解消した後に、利用者が実行する予定の入口です。
bash scripts/deploy.sh --run 2
```

Run 1/3は自前main.bicepから公式41、Run 2のJSONは公式15専用です。現在は全Runを未完成のまま展開しない固定停止点があります。S2/S4は公式展開の前提・入力を確定する順で、41のリソース展開はS5でまとめて実施する予定です。

## 3. 確認する C 番号

C08・C01（閉域版）・C10。[checks](../../checks/README.md) の検証・期待結果は変更しません。補助スクリプトは`bash scripts/verify.sh --section N`でセクションごとに実行し、Pendingならexit 2です。

実施日・Run・セクション・合成入力・期待結果・実結果・Pass/Fail/Pendingを`evidence/`へ記録。C06は監査とDeny、C09はトークンquotaとガードレール、C10は通知と削除・費用を分けます。既存の基盤・RBAC・ログはこの環境でも再確認します。

## 4. 削除と翌日の課金確認

[S9](../sections/09_teardown_cost.md) で専用RG・ロック・共有依存を確認後に実施します。

```bash
bash scripts/teardown.sh --delete '<resource-group-name>'
bash scripts/teardown.sh --status
bash scripts/cost_check.sh
```

Runの切替は.envの対象を明示して行います。削除受付、RG消失、Key Vault/Foundryのsoft-delete、Cosmos、PE、Private DNS、RG外の共有資産、Defenderプランの復帰、翌日以降の課金を別々に確認します。未確認ならC10はPendingです。

## 5. 初回と再現日の違い

初回は公式テンプレを読み、作りながら手順と詰まった点を書きます。再現日は**書いた手順だけで再現し、差分を直す**。再現確認が通ったセクションだけ執筆済みとします。今回はどちらも未実施です。
