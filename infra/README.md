# 公式テンプレートと自前 Bicep の利用方法

## 対象と固定版

Run 1 / Run 2 は固定版の 41-standard-agent-setup を自前 main.bicep から呼びます。15 は使いません。[PINNED_COMMIT](PINNED_COMMIT.md) と [41 の調査](params/41_parameters.md) を参照します。vendor は変更していません。

1. 固定版の相対依存と LICENSE があることを確認します。
2. 取得済みの vendor がない場合だけ固定 SHA のアーカイブを取得します。

```bash
curl --fail --location --output /tmp/foundry-samples.zip 'https://github.com/microsoft-foundry/foundry-samples/archive/58e4127567f7e9afcf0145d874df890284ca5faf.zip'
```
実行結果の確認ポイント: PINNED_COMMIT のアーカイブハッシュと照合します。

```bash
shasum -a 256 /tmp/foundry-samples.zip
```
実行結果の確認ポイント: 固定版と一致することを確認します。

```bash
unzip /tmp/foundry-samples.zip -d infra/vendor
```
実行結果の確認ポイント: 既存取得物を上書きせず、相対依存と LICENSE を保持します。

## モジュールの責任分担

| 担当 | 内容 | 未完了 |
|---|---|---|
| 02_keyvault | RBAC 認可・社内 IP・信頼サービス例外・タグ | 実機 RBAC と到達 |
| 04_data | Serverless Cosmos・LRS Storage・Basic Search・認証・IP・タグ | agent service の到達 |
| 41 | BYO ID を受け取り account/project/モデル/MI/接続/host を作成 | GA 適合性・実機動作 |
| 03_network_acls | existing account 参照と更新目標 | S5 の後追いコマンド実行 |
| 06_diagnostics | 既存 LAW に接続する App Insights | Foundry 接続・診断設定・本文 |
| 07_gateway_app | Basic v2・B1・IP 制限 | OBO・JWT・許可済みツール・quota・アプリ配布 |
| 08_policy_defender | effect を指定した Policy 割当 | 定義 alias と型別対応・Defender は手動 |

`existing` は更新操作ではありません。03 モジュールを配置しただけで C08 が完了したと扱わず、[S5](../docs/12-foundry-agent.md) の明示的な更新を行います。41 にトップレベル outputs はありません。account 名の式を固定ソースから合わせていますが、実物との一致を確認します。ラッパは実 ID や接続文字列を一括出力しません。

## パラメータを確定する

1. Run に合う example.json を対応する local.json にコピーします。
2. main.bicep と項目を照合します。
3. `.env` と JSON の `allowedIpRanges` を一致させます。
4. Run 2 は `allowedIpAddressRanges` に CIDR ごとの開始・終了アドレスを設定します。
5. すべての placeholder と metadata を解消します。
6. `.env` の該当 `RUNN_PARAMETERS_REVIEWED` を true にします。

| 項目 | 値 |
|---|---|
| Run 1 | `enableApim=false` |
| Run 2 | `enableApim=true` |
| 社内 IP | 非空の公開 IPv4 CIDR、全許可は禁止 |
| APIM IP 範囲 | `from` / `to`（CIDR との一致をスクリプトで検査） |
| 41 のデータ ID | data module の outputs を自動で渡す |
| `deployApplicationInsights` | 必ず false、S6 で後追い |
| 監視・Policy | false は保留。必要パラメータと手順を確定してから有効化 |

監視を有効化する場合は S1 の LAW ID を `workspaceResourceId` に指定します。Policy を有効化する場合は定義 ID・effect・parameters を指定します。単一の割当骨子で全対象型を覆ったことにはなりません。

## 固定停止点と未検証事項

**未コンパイル・Azure 未実行です。** この環境には az / bicep がありません。deploy.sh はローカル入力検査後に固定停止し、レビュー済みフラグだけでは Azure へ送信しません。

> **Note** 要確認: 41 内部の Preview API が GA 機能の呼び出しに限られるか、「Preview 手順なし」と両立するかは未確定です。vendor を変えず、現物レビューまで停止点を残します。

> **Note** 要確認: 41 が Foundry を既定 Allow・ローカル認証有効で作るため、S5 後追いまでの時間と Run 2 Deny の競合が残ります。APIM 社内 IP 制限とサービスからの発信経路、BYO 到達、S6 の Entra ID 接続も未確定です。

実行を完成させるときは、Bicep build、対象環境での validate / what-if、上記未解決の実装レビューを行います。deploy.sh の固定停止点除去はその後です。停止点の後ろの Azure 経路は骨子として保存してあり、現在は到達しません。後追い更新はスクリプトに自動化していません。

## 再実行

同じ RG・固定 SHA・deploymentTimestamp・prefix を再使用します。41 再実行時の設定巻き戻りや capability host の冪等性は要確認です。変更できると仮定せず、当日手順と S9 の削除を使います。

---

前へ: [準備](../docs/01-prerequisites.md) / 次へ: [データ基盤](../docs/11-data.md) / [トップに戻る](../README.md)
