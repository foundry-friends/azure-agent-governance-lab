# S8：ポリシー・脅威検知・評価

このセクションを使う Run: Run 1 / Run 3｜先に要るセクション: S1・S5

## 1. 目的

統制層⑤ 脅威検知・態勢、⑥ 評価・レッドチーム、⑨ ポリシーを担当します。

## 2. 前提

Policy 割当（Resource Policy Contributor 等）と Defender のプラン設定（Security Admin 等）の可否・スコープは会社ルールと実効権限で要確認。CSPM は既定 OFF、管理者判断です。既存 D10 の「CSPM＋AI Services」は検討対象であり、両方の自動有効化の指示ではありません。

先に要るセクション：S1・S5。詳細な会社ルールは [Run 0](../runs/run0_desk.md) で確認します。

## 3. 構築

### Azure Policy を監査モードで割り当てる

まず対象 RG スコープで、ローカル認証無効・public network 制限・承認モデル限定の定義を選びます。定義 JSON の effect、対象 type、parameters を読みます。[モデル制限](https://learn.microsoft.com/en-us/azure/foundry/how-to/model-deployment-policy)、[組み込み定義一覧](https://learn.microsoft.com/en-us/azure/ai-services/policy-reference)

```bash
az policy definition list --subscription "$AZURE_SUBSCRIPTION_ID" \
  --query '[].{displayName:displayName,name:name}' --output table
# 要確認：選んだ定義の effect に Audit があることを確認し、
# 実際のパラメータ schema に合わせたローカル JSON を用意します。
# 以下のファイルはこの骨組みには同梱していません。
az policy assignment create --subscription "$AZURE_SUBSCRIPTION_ID" \
  --name '<policy-assignment-name>' \
  --scope "/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${AZURE_RESOURCE_GROUP}" \
  --policy '<policy-definition-id>' \
  --params @infra/params/policy-audit.local.json
```

**確認ポイント**：`effect=Audit` を許容する定義だけ監査として割り当てます。Audit 非対応なら勝手に Deny を割り当てず、`DoNotEnforce` 等の評価方式・結果を要確認として扱います。Audit と enforcement 無効化は同義ではありません。公開側で行う Run 1 では public network 制限の非準拠を記録し、Run 2 で是正します。

ローカル認証は監査だけで無効になりません。Foundry の認証設定または固定テンプレートの対応プロパティで**実際に無効化**します（正確な設定経路・引数は要確認）。API キーは RBAC を迂回するためです。承認モデルの定義は Deny にできますが、本段階は監査です。content filter 系の組み込み定義は Preview / Audit のみです。

**よくある失敗**：Audit 割当を防止統制と呼ぶ、effect の存在を確かめず渡す、サブスクリプション全体に割り当てて他チームへ影響させる。

### Defender を有効化する（可能なら）

[Defender for AI Services の手順](https://learn.microsoft.com/en-us/azure/defender-for-cloud/ai-onboarding) に従い、Defender for Cloud の対象サブスクリプション設定で CSPM と AI Services を確認します。サブスクリプション管理者と費用負担・適用範囲・既存プランの状態を合意してから有効化します。CLI の plan 名、subplan、extension、無料枠の適用条件は要確認のため、自動有効化コマンドは置いていません。

**確認ポイント**：変更前後のプラン状態と戻し方を記録します。有効化できなければ C07 は「未実施」とします。共有サブスクリプションでは他チームも課金対象になり得ます。Agent 365 のエージェント単位機能の検証と混同しません。

**よくある失敗**：RG だけの設定だと思う、無料枠で全費用が無料になると思う、検証終了時に既存プランまで無効化する。

### 評価・レッドチーム（Run 3）

継続評価、AI Red Teaming Agent は合成入力で確認します。評価機能の GA と個別 evaluator / UI の Preview を区別します。App Insights 接続と閲覧権限、評価対象・料金・実行上限を先に確認します。Japan East での cloud red teaming 提供は要確認で、非対応なら Pending とし、無断で別リージョンへ変更しません。Workflow / Function tool / Browser automation の対応を推測しません。新しい C 番号は増やさず、C06/C07 の補足記録として評価方法・対象・結果を残します。

`08_policy_defender.bicep` は自前骨子です。Policy 定義 JSON の effect を確認してから割り当てます。Defender は `az security pricing` の plan / subplan / extension と戻し方を確定後に操作する方針で、ここではサブスクリプション課金を自動変更しません。

当日の時間配分と実行順は該当 [Run 文書](00_overview.md#4-セクションと-run-の地図) に従います。骨組み・Azure 未実行です。

## 4. 確認

### Policy の防止効果を追加検証する

- [ ] 承認モデル限定の組み込み定義を隔離した検証スコープで Deny にして、非承認モデルの展開が拒否されることを C06 の追加試験として確認します。
- [ ] content filter 系の組み込み定義は Preview / Audit のみです。Deny で防止できると書き換えません。

対象：C06・C07。[checks](../../checks/README.md) に合成入力・期待結果・実結果・日付・Pass / Fail / Pending を記録します。未実施は Pending。公開しない証跡は `evidence/` に保存します。

```bash
bash scripts/verify.sh --section 8
```

コマンドはリポジトリ直下から実行します。設定収集だけでは合格になりません。

## 5. よくあるエラー

（Run 1 初回で記入）

S3 は Run 2、S7 と S8 の追加検証は Run 3 の初回に追記します。構築欄に引き継いだ「よくある失敗」は旧ドラフトの想定であり、この環境で経験した実測ではありません。

## 6. 削除

専用 Run 環境の終了時は [S9](09_teardown_cost.md) で RG 単位に削除します。このセクションだけの部分削除は依存・共有・capability host の再作成可否を確認後に行います（要確認）。未確定の個別削除 API は置きません。RG 外、soft-delete、Defender のサブスク設定は別確認です。

## 7. 費用

| Excel 明細 No | 項目 | 都度構築の月額 USD | 常時730hの月額 USD |
|---|---|---:|---:|
| 24 | Defender AI Services | 8.000000 | 8.000000 |
| 26 | Defender CSPM（既定 OFF） | 0.000000 | 0.000000 |

2026-09-15 見積り report v2 の条件。都度は原則32h/月、WAFのみ8h/月、DNSは6 zone・4課金日です。常時列は同じ単価の固定費を730hへ換算し、従量は同じ使用量の仮定です。No.9 と17は切替で二重計上しません。No.6は S1/S6 の共通費で一度だけ計上。No.24は通常月 $8、初月無料を1か月と近似。No.26は承認してONなら月 $51.10。実請求保証ではありません。

## 8. 本番との差

このセクションには指定された Baseline SKU の直接の差分はありません。 [付録 B](appendix_b_production_diff.md) を参照します。
