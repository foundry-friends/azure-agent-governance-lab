# S3：ネットワーク

このセクションを使う Run: Run 2｜先に要るセクション: S1

## 1. 目的

Azure で未実行です。ここでは見出しと確認項目までを定義します。Run 1 と別 RG / 新しい Foundry account を使います。

## 2. 前提

### 作成前に構成を確定する

- [ ] 固定 SHA の `15-private-network-standard-agent-setup` と依存 module を確認します。
- [ ] BYO VNet injection は account 作成時のみ設定でき、後付けできないことを確認します。
- [ ] Run 1 の変更展開にしないこと、モデル・SKU の Japan East 対応を確認します（要確認）。
- [ ] RG、モデル、VNet、PE、依存データサービスの費用と削除対象を整理します。

先に要るセクション：S1。詳細な会社ルールは [Run 0](../runs/run0_desk.md) で確認します。

## 3. 構築

### VNet とサブネットを準備する

- [ ] サブネットを `Microsoft.App/environments` に委任し、/27 以上のアドレス空間を確保します。
- [ ] 既存ネットワークとのアドレス重複、Private DNS と名前解決、必要な経路・出口を確認します。
- [ ] 追加サブネットの必要数・用途・サイズは固定テンプレートで要確認です。

### Firewall Basic と管理経路を決める

- [ ] テンプレートが Basic に対応するか、SKU 以外に必要な変更があるか要確認です。
- [ ] 必要通信、DNS、ルート、出口ルールを洗い出します。許可先は推測で列挙しません。
- [ ] Bastion を常設しません。Developer SKU または P2S VPN の条件と閉域検証端末からの接続を確認します（要確認）。

agent 用 /27、PE 用、APIM 用予備、App Gateway 用のサブネットを用途別に計画し、NSG・Private DNS・UDR と Firewall Basic の FQDN 許可を扱います。公式 15 が担う VNet / PE / DNS と自前 `03_network.bicep` の Firewall / UDR を重複作成しないよう Run 2 で確定します。

**固定版 15 の README は VNet 背後の agent tools 非対応と明記し、19 を案内しています。** MCP / OpenAPI が閉域で使えると断定せず、Run 2 の検証範囲・19 採否は要確認。今回は 15 から勝手に切り替えません。

当日の時間配分と実行順は該当 [Run 文書](00_overview.md#4-セクションと-run-の地図) に従います。骨組み・Azure 未実行です。

## 4. 確認

### 閉域の成立と例外を確認する

- [ ] C08：私設経路では認証済み呼び出しが成功し、公開側から同じ資格情報で拒否されることを確認します。
- [ ] public network の Policy 非準拠が是正されたことを確認します。
- [ ] Bing Grounding / Web search / SharePoint Grounding は閉域でも public endpoint 経由です。利用しないか、必要な公開通信を許容するかを明示します。完全に閉域化できたと扱いません。
- [ ] 名前解決失敗、RBAC 拒否、ネットワーク拒否を切り分けます。

対象：C08。[checks](../../checks/README.md) に合成入力・期待結果・実結果・日付・Pass / Fail / Pending を記録します。未実施は Pending。公開しない証跡は `evidence/` に保存します。

```bash
bash scripts/verify.sh --section 3
```

コマンドはリポジトリ直下から実行します。設定収集だけでは合格になりません。

## 5. よくあるエラー

（Run 1 初回で記入）

S3 は Run 2、S7 と S8 の追加検証は Run 3 の初回に追記します。構築欄に引き継いだ「よくある失敗」は旧ドラフトの想定であり、この環境で経験した実測ではありません。

## 6. 削除

### 次フェーズとの分離・終了

- [ ] Run 3 の APIM Basic v2 をこの閉域 Foundry に接続しません。
- [ ] 閉域統合の参考はテンプレート 16 です。Standard v2 / Premium v2＋PE の要件、経路、差分、再作成要否は要確認です。
- [ ] [削除手順](09_teardown_cost.md) に従って終了します。Run 1 用 `.env` を誤用せず、対象をその都度確認します。

根拠：[ネットワーク注入](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/networking-options)、[閉域と外部サービス](https://learn.microsoft.com/en-us/azure/foundry/how-to/configure-private-link)、[APIM 接続](https://learn.microsoft.com/en-us/azure/foundry/configuration/enable-ai-api-management-gateway-portal)。

専用 Run 環境の終了時は [S9](09_teardown_cost.md) で RG 単位に削除します。このセクションだけの部分削除は依存・共有・capability host の再作成可否を確認後に行います（要確認）。未確定の個別削除 API は置きません。RG 外、soft-delete、Defender のサブスク設定は別確認です。

## 7. 費用

| Excel 明細 No | 項目 | 都度構築の月額 USD | 常時730hの月額 USD |
|---|---|---:|---:|
| 8 | Private DNS（6 zone 仮置き） | 0.394521 | 3.000000 |
| 12 | Firewall Basic 固定 | 12.640000 | 288.350000 |
| 13 | Firewall データ処理 | 0.325000 | 0.325000 |
| 14 | Private Endpoint（6 個） | 1.920000 | 43.800000 |
| 15 | VNet / NSG / 委任 基本 | 0.000000 | 0.000000 |

2026-09-15 見積り report v2 の条件。都度は原則32h/月、WAFのみ8h/月、DNSは6 zone・4課金日です。常時列は同じ単価の固定費を730hへ換算し、従量は同じ使用量の仮定です。No.9 と17は切替で二重計上しません。No.6は S1/S6 の共通費で一度だけ計上。No.24は通常月 $8、初月無料を1か月と近似。No.26は承認してONなら月 $51.10。実請求保証ではありません。

## 8. 本番との差

Firewall Basic → Standard、管理用 Bastion の追加。 [付録 B](appendix_b_production_diff.md) を参照します。
