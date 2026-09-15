# 3. ネットワーク境界（IP 許可リストと送信の絞り込み）

このセクションを使う Run: Run 1／Run 2。先に要るセクション: S1。

> **Note** 現在は骨組み・Azure 未実行です。コマンドはリポジトリ直下の Bash で実行する予定の手順です。

## 3.1. 目的

統制層②として入口の IP 許可リストと、ツール層での送信の絞り込み（方式 A）を設計します。

## 3.2. 前提

S1 の専用 RG と S2 の既存 Entra 条件付きアクセスの確認が前提です。社内からの公開 IPv4 出口を確認し、許可外の試験回線も用意します。

## 3.3. 構築

### 社内 IP をローカルに保存する

1. 管理者に承認された社内の公開 IPv4 CIDR を確認します。
2. `.env` の `ALLOWED_IP_RANGES` に JSON 配列として記録します。

```text
ALLOWED_IP_RANGES='["<corporate-public-ipv4-cidr>"]'
```
実行結果の確認ポイント: placeholder を実際の値に置き換え、`.env` だけに保存します。

3. 同じ配列を `run1.local.json` または `run2.local.json` の `allowedIpRanges.value` に転記します。
4. 空配列や `0.0.0.0/0` がないことを確認します。

> **補足** `.env` とローカル JSON の一致は deploy.sh が検査します。main の既定値は `[]` ですが、空では実行しません。Cosmos / Search は空の IP 規則が無制限公開になるためです。

### 各サービスの設定を確認する

| リソース | 公開設定と既定拒否・IP 許可 | 信頼された Azure サービス例外 |
|---|---|---|
| Foundry account | `publicNetworkAccess=Enabled`、`networkAcls.defaultAction=Deny`、`networkAcls.ipRules[].value` | `networkAcls.bypass`。本例は `None`、必要性は要確認 |
| Key Vault | `publicNetworkAccess=Enabled`、`networkAcls.defaultAction=Deny`、`networkAcls.ipRules[].value` | `networkAcls.bypass=AzureServices` |
| Storage | `publicNetworkAccess=Enabled`、`networkAcls.defaultAction=Deny`、`networkAcls.ipRules[].value` | `networkAcls.bypass=AzureServices` |
| Cosmos DB | `publicNetworkAccess=Enabled`、非空の `ipRules[].ipAddressOrRange` で限定（`networkAcls.defaultAction` はありません） | `networkAclBypass=AzureServices`。適用対象は要確認 |
| AI Search | `publicNetworkAccess=enabled`、非空の `networkRuleSet.ipRules[].value` で限定（`defaultAction` はありません） | `networkRuleSet.bypass=AzureServices`。agent service の対象可否は要確認 |
| APIM | 公開ゲートウェイの API ポリシー `ip-filter action=allow` | 同等の信頼サービス自動例外なし。社内 IP 以外は拒否 |
| App Service | `publicNetworkAccess=Enabled`、`ipSecurityRestrictionsDefaultAction=Deny`、`ipSecurityRestrictions[].ipAddress` | 同等の自動例外なし。SCM にも同じ規則を適用 |

設定名は [Cosmos ARM 定義](https://learn.microsoft.com/en-us/azure/templates/microsoft.documentdb/2024-11-15/databaseaccounts)、[Search ARM 定義](https://learn.microsoft.com/en-us/azure/templates/microsoft.search/2025-05-01/searchservices)、[Foundry ARM 定義](https://learn.microsoft.com/en-us/azure/templates/microsoft.cognitiveservices/2025-06-01/accounts) を参照します。

### 方式 A で送信先を絞る

1. エージェントの [ツール] 一覧で Bing / Web search / SharePoint を追加していないことを確認します。
2. モデルを Foundry 内の承認済みモデルに限定します。
3. MCP / OpenAPI の登録先を S7 の APIM に限定します。
4. APIM の許可済みバックエンドを固定し、入力から任意 URL を指定できないようにします。
5. ツールを追加・編集できる主体を RBAC と変更手順で限定します。

> **Note** 要確認: RBAC だけで個別ツール種別を禁止できるとは断定しません。編集権限を持つ主体の迂回を確認します。方式 A は Microsoft 管理ネットワーク全体の FQDN 制御ではありません。

## 3.4. 確認

C08 を次の 4 結果に分けます。

1. 許可 IP から Entra ID で同じ合成入力を送信します。
2. 許可外 IP から同等の権限で送信し、ネットワーク拒否を確認します。
3. IP 制限下で agent service が Cosmos / Storage / Search に到達することを確認します。
4. Run 2 で未許可 MCP が失敗し、APIM 経由の許可先が成功することを確認します。

Entra のサインイン拒否だけでリソース側 IP 制限の確認を代用しません。拒否した層を特定できなければ Pending です。

```bash
bash scripts/verify.sh --section 3
```
実行結果の確認ポイント: 設定収集または案内のみで、未完了は終了コード 2 です。

[確認項目](../checks/README.md) ごとに実施日・Run・入力・期待結果・実結果・Pass / Fail / Pending を非公開の `evidence/` に記録します。未実施は Pending です。

## 3.5. うまくいかない場合

### IP 制限で agent service が到達できない場合

1. 同じ合成入力で、Cosmos / Storage / Search のどの接続が失敗するかを特定します。
2. 対象リソースの RBAC とローカル認証無効設定を確認します。
3. 変更前の IP 規則と拒否結果を非公開の `evidence/` に記録します。
4. Azure portal で当該リソースの [ネットワーク] を開きます。
5. 下表の当該リソースの設定だけを「Entra 認証のみ＋公開」に変更します。
6. 同じ合成入力を再実行します。
7. 到達結果と IP 制限を外した範囲を `evidence/` に記録します。
8. 検証後に元の IP 許可リストを戻します。

| 項目 | 値 |
|---|---|
| Cosmos の復旧設定 | `publicNetworkAccess=Enabled`、`ipRules=[]`、`isVirtualNetworkFilterEnabled=false`、`disableLocalAuth=true` を維持 |
| Storage の復旧設定 | `publicNetworkAccess=Enabled`、`networkAcls.defaultAction=Allow`、`allowSharedKeyAccess=false` を維持 |
| Search の復旧設定 | `publicNetworkAccess=enabled`、`networkRuleSet.ipRules=[]`、`disableLocalAuth=true` を維持 |
| 判定 | 接続が回復しても C08 の IP 制限下の到達は Pass にしません |

> **Note** 要確認: UI 名・反映時間・信頼サービス例外の適用は（Run 1 初回で記入）です。Run 2 の Deny が変更を拒否する場合は、S8 の対象限定例外の確認へ戻ります。

> **補足** この代替手順は N2 の例外です。ネットワーク制限を外した事実を記録し、本番では Private Endpoint が必要な差分として [付録 B](92-appendix-production-diff.md) に引き継ぎます。Foundry・Key Vault・APIM・App Service を一括で公開には戻しません。

## 3.6. 削除

1. 当日に構築したリソースと共有依存を確認します。
2. [S9](90-cleanup-cost.md) に従って専用 RG を削除します。
3. RG 外・soft-delete・Defender の設定を別々に確認します。

> **Note** 要確認: 部分削除時の依存・capability host の再作成可否は（Run 1 初回で記入）です。

## 3.7. 費用

S3 自体の追加明細はありません。IP 制限は S2/S4/S5/S7 の各リソースに設定します。APIM は Excel v3 No.11、アプリは No.13、ログは No.6 です。

## 3.8. 本番との差

| 使わないもの | 理由 |
|---|---|
| Private Endpoint・BYO VNet injection・VPN・ExpressRoute | N1 により閉域接続を構築しません |
| Azure Firewall | 自前ネットワークを作らず、方式 A でツールの送信先を絞ります |
| Managed VNet | 計画上、作成が CLI preview のため対象外です。Preview 手順は載せません |
| WAF | 社内 IP 限定の検証では追加しません |
| Bastion | 管理用の閉域接続を作りません |

本番の差分は [付録 B](92-appendix-production-diff.md) に残します。

---

前へ: [ID と権限](02-identity.md) / 次へ: [データ基盤（Standard setup の BYO）](11-data.md) / [トップに戻る](../README.md)
