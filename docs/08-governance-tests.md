# 8. 権限・認証・ネットワークの統制を試す

進め方: README の第0〜10章を順番に実施します。第7章の完了条件を満たしてから進めます。

> **Note** 状態: 試験手順ドラフト（第7章のアプリ待ち）（Azure 未実行）。構成変更日 2026-09-15。

> **補足** この章では環境を削除しません。通常の削除は最後の第10章です。中断して片付ける場合だけ、第10章へ進みます。

## 8.1. 目的

同じ環境・エージェント・合成入力で、許可される操作と拒否される操作を比較します。必要なリソースとアプリはすでに作成済みです。

## 8.2. 前提

第7章の正常呼び出しと経由ログを確認済みです。試験ユーザー・許可 IP／許可外 IP・認証経路を記録します。ここで構築の不足が分かった場合は試験を Pending とし、完成した一周と扱いません。

## 8.3. 権限と認証を試す

### C02：主体別に同じ操作を比較する

1. 管理者と別のブラウザプロファイルで検証用ユーザーにサインインします。
2. 第4章の同じエージェントに、合成入力「検証です。こんにちはと答えてください」を送ります。
3. 対象 project の [エージェント] で [エージェントの作成] を選択します。
4. 試験専用の名前と承認モデルを指定して保存を試します。
5. 作成できた検証用エージェントの指示に「短く答えてください」を追加して保存を試します。
6. 各操作の実結果を下表と比較します。

| 主体 | 呼び出し | 作成・編集 | 判定上の注意 |
|---|---|---|---|
| Foundry User | 成功 | 成功 | モデルのデプロイや公開の権限とは別 |
| Foundry Agent Consumer | 成功 | 拒否 | 呼び出しは本人トークンを使うアプリ経路で確認 |
| 無権限ユーザー | 拒否 | 拒否 | サインイン／IP 拒否だけなら RBAC 試験は Pending |

画面に作成ボタンがない場合は「GUI 操作不可」と記録します。バックエンドの作成・編集拒否は、その操作を送れる検証経路がない限り Pending にします。別主体で作ったエージェントを編集できるかは所有関係も影響するため、新規作成と分けて記録します。

### C03 の照合値

| 対象 | 期待する設定 |
|---|---|
| Storage | `allowSharedKeyAccess=false` |
| Cosmos DB・Search・Foundry account | `disableLocalAuth=true` |

キーは表示・取得しません。設定が null の場合は無効化済みと扱いません。

```bash
az resource show --ids "<target-resource-id>" --query '{type:type,disableLocalAuth:properties.disableLocalAuth,allowSharedKeyAccess:properties.allowSharedKeyAccess}' --output json
```
実行結果の確認ポイント: リソース種別に対応する上表の値を確認します。

### C03：設定・認証成功・未認証拒否を分ける

| 試験 | 期待 | 実施できない場合 |
|---|---|---|
| 対象ごとの設定照合 | 下表の無効設定と一致 | 対象作成前／設定手段未確定は Pending |
| Entra ID による呼び出し | 権限ありの主体で成功 | 正常な呼び出し経路が利用できなければ Pending |
| 認証情報なしの呼び出し | 対象エンドポイントで拒否 | アプリのログイン画面だけ確認した場合は Foundry の試験は Pending |

認証なし試験は 第7章で確定する同一操作・同一エンドポイントの検証経路を使います。URL をブラウザで開いた結果だけでは、認証拒否と HTTP メソッド違いを区別できません。キーを使った拒否試験は本手順に含めません。

Cloud Shell の `.env` に記録済みの検証対象の `AZURE_SUBSCRIPTION_ID`、`AZURE_TENANT_ID`、`AZURE_RESOURCE_GROUP`、`FOUNDRY_ACCOUNT_RESOURCE_ID` を照合してから実行します。

```bash
bash scripts/verify.sh --section 2
```
実行結果の確認ポイント: account スコープのロールと認証設定を収集し、未実施の試験を Pending と表示します。設定不足や照会失敗はエラーになり、設定収集完了時の終了コード 2 も試験合格を意味しません。

[確認項目](../checks/README.md) ごとに、Run・手順番号・主体の区別・入力・期待・実結果・拒否した層・Pass／Fail／Pending を非公開の `evidence/` に記録します。未実施行を残したまま C02／C03 全体を Pass にしません。

## 8.4. ネットワークとゲートウェイを試す

### C08：IP 制限と送信先

C08 を次の 4 結果に分けます。

1. 許可 IP から Entra ID で同じ合成入力を送信します。
2. 許可外 IP から同等の権限で送信し、ネットワーク拒否を確認します。
3. IP 制限下で agent service が Cosmos / Storage / Search に到達することを確認します。
4. 用意済みの検証経路で未許可 MCP が失敗し、APIM 経由の許可先が成功することを確認します。

Entra のサインイン拒否だけでリソース側 IP 制限の確認を代用しません。拒否した層を特定できなければ Pending です。

```bash
bash scripts/verify.sh --section 3
```
実行結果の確認ポイント: 設定収集または案内のみで、未完了は終了コード 2 です。

[確認項目](../checks/README.md) ごとに実施日・Run・入力・期待結果・実結果・Pass / Fail / Pending を非公開の `evidence/` に記録します。未実施は Pending です。

### C09：経由・quota・ガードレール

C09: APIM 経由ログ、正常／拒否入力、quota 超過 403（レート制限とは別）、ガードレール適用を確認します。C08: 許可ツール成功、未許可ツール失敗、直接呼び出しの迂回防止を確認します。

```bash
bash scripts/verify.sh --section 7
```
実行結果の確認ポイント: 設定収集または案内のみで、未完了は終了コード 2 です。

[確認項目](../checks/README.md) ごとに実施日・Run・入力・期待結果・実結果・Pass / Fail / Pending を非公開の `evidence/` に記録します。未実施は Pending です。

### C04／C05：試験の証跡を見る

各試験の時刻で Log Analytics のログを確認します。診断ログの到着、本文トレース、本文の閲覧制御を分け、結果を記録します。ネットワーク拒否・Entra のサインイン拒否・アプリの拒否・Foundry の認可拒否を区別します。

## 8.5. うまくいかない場合

1. 対象・主体・同一入力・時刻を照合します。
2. 拒否した層が不明なら Pending にします。
3. 前提設定が欠けていた場合は作業記録に残し、試験合格とはしません。

社内 IP 制限下の BYO 到達問題は初回応答の章で切り分け済みの記録を使います。例外で公開した経路を、IP 制限が効いた成功例に数えません。

## 8.6. 完了条件と次の操作

C01〜C05・C08・C09 の実施した行について、期待・実結果・判定・未実施理由が揃ったら第9章へ進みます。失敗や Pending を隠して総合合格にしません。

## 8.7. 費用

既存環境の利用と合成リクエストの費用です。quota 試験は少量の入力と検証用の低い上限で設計します。

## 8.8. 本番との差

一回の合成試験は継続監視・運用受入の代わりにはなりません。

### 出典

- 出典: [Foundry の RBAC](https://learn.microsoft.com/ja-jp/azure/foundry/concepts/rbac-foundry)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Key Vault を portal で作成](https://learn.microsoft.com/ja-jp/azure/key-vault/general/quick-create-portal)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Azure ロールの割当](https://learn.microsoft.com/ja-jp/azure/role-based-access-control/role-assignments-portal)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Key Vault の RBAC](https://learn.microsoft.com/ja-jp/azure/key-vault/general/rbac-guide)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Key Vault のネットワーク](https://learn.microsoft.com/ja-jp/azure/key-vault/general/network-security)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Key Vault の論理削除](https://learn.microsoft.com/ja-jp/azure/key-vault/general/soft-delete-overview)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Standard setup](https://learn.microsoft.com/ja-jp/azure/foundry/agents/concepts/standard-agent-setup)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [BYO リソース](https://learn.microsoft.com/ja-jp/azure/foundry/agents/how-to/use-your-own-resources)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Search のロール認証](https://learn.microsoft.com/ja-jp/azure/search/search-security-enable-roles)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Storage 共有キーの無効化](https://learn.microsoft.com/ja-jp/azure/storage/common/shared-key-authorization-prevent)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Cosmos DB の RBAC とキー無効化](https://learn.microsoft.com/ja-jp/azure/cosmos-db/nosql/how-to-connect-role-based-access-control)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Foundry Tools のローカル認証無効化](https://learn.microsoft.com/ja-jp/azure/ai-services/disable-local-auth)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [条件付きアクセスの適用ログ](https://learn.microsoft.com/ja-jp/entra/identity/monitoring-health/how-to-view-applied-conditional-access-policies)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [継続的アクセス評価](https://learn.microsoft.com/ja-jp/entra/identity/conditional-access/concept-continuous-access-evaluation)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Easy Auth の OAuth トークン](https://learn.microsoft.com/ja-jp/azure/app-service/configure-authentication-oauth-tokens)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [APIM の Managed Identity 認証](https://learn.microsoft.com/ja-jp/azure/api-management/authentication-managed-identity-policy)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [az keyvault](https://learn.microsoft.com/ja-jp/cli/azure/keyvault)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [az role assignment](https://learn.microsoft.com/ja-jp/cli/azure/role/assignment)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [az resource](https://learn.microsoft.com/ja-jp/cli/azure/resource)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [公式テンプレート 41（固定コミット）](https://github.com/microsoft-foundry/foundry-samples/tree/58e4127567f7e9afcf0145d874df890284ca5faf/infrastructure/infrastructure-setup-bicep/41-standard-agent-setup)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Cosmos ARM 定義](https://learn.microsoft.com/en-us/azure/templates/microsoft.documentdb/2024-11-15/databaseaccounts)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Search ARM 定義](https://learn.microsoft.com/en-us/azure/templates/microsoft.search/2025-05-01/searchservices)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Foundry ARM 定義](https://learn.microsoft.com/en-us/azure/templates/microsoft.cognitiveservices/2025-06-01/accounts)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [公式 ip-filter](https://learn.microsoft.com/ja-jp/azure/api-management/ip-filter-policy)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [トークン制限](https://learn.microsoft.com/en-us/azure/api-management/llm-token-limit-policy)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）

---

前へ: [ゲートウェイと呼び出しアプリを用意する](07-gateway-app.md) / 次へ: [Policy・脅威検知・評価を試す](09-policy-defender-eval.md) / [トップに戻る](../README.md)
