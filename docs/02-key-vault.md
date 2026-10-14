# 2. Key Vault を準備する

進め方: README の第0〜10章を順番に実施します。第1章の完了条件を満たしてから進めます。

> **Note** 状態: ドラフト（Learn 2026-09 時点の記述に基づく・未実行）。操作手順の見直し日 2026-09-20。

> **補足** この章では環境を削除しません。通常の削除は最後の第10章です。中断して片付ける場合だけ、第10章へ進みます。

## 2.1. 目的

RBAC と監査の検証に使う Key Vault を用意します。この章では Foundry の作成や利用者ロール割当は行いません。

### なぜこの作業が必要か

Key Vault は、パスワードや API キーなどの秘密情報をアプリのコードから分離して保管し、アクセスできる主体を制御するサービスです。一般的な用途は、秘密情報を必要な人やサービスだけに渡し、その利用を追跡できるようにすることです。[Microsoft Learn の概要](https://learn.microsoft.com/ja-jp/azure/key-vault/general/overview)で役割を確認できます。

**今回のラボで用意する理由は、秘密情報を守るリソースの権限設定と監査を学ぶためです。** 本手順では実際のキーや接続文字列を保存せず、独立した RBAC・監査の検証対象として扱います。第5章で必要な主体の権限を確認し、第6章で診断ログの設定につなげます。Vault を作成しただけでは、データへのアクセス制御や監査が検証できたことにはなりません。

この Vault は、現在の構成で Foundry エージェントの必須接続先として使うものではありません。エージェントの接続用シークレットを保管するために必須という意味ではなく、今回のガバナンス学習の対象として準備します。

## 2.2. 前提

第1章で用意した次の値を、非公開の作業メモまたは `.env` から参照できる状態にします。

| 確認するもの | この章で使う内容 |
|---|---|
| サブスクリプションと RG | 検証用サブスクリプション、自分の `rg-<略号>-dev-01`。RG は新規作成せず一覧から選択 |
| 作成権限 | 自分の RG 内で Key Vault を作成できること。権限不足は第1章の確認担当へ依頼 |
| リソースプロバイダー | 第1章で `Microsoft.KeyVault` の登録を確認済み |
| 社内 IP | 管理者が確認した公開 IPv4 CIDR の一覧 |
| タグ | `purpose`・`run`・`operator`・`deleteAfter` の 4 組 |
| 実行環境 | 作成は社内 PC のブラウザ、読み取りコマンドは Cloud Shell の Bash |

`<key-vault-name>` はこの章で決めた名前、`<resource-group-name>` は自分の RG 名に置き換えます。山括弧は入力しません。

## 2.3. 構築

### Key Vault を作成する

1. [Azure portal](https://portal.azure.com) の [ホーム] を開き、[リソースの作成] を選択します。
2. 検索欄に `Key Vault` を入力します。
3. 検索結果の [Key Vault] を選択します。
4. [作成] を選択します。
5. [キー コンテナーの作成] の基本情報に次の値を入力します。

| 項目 | 値 |
|---|---|
| サブスクリプション | 第1章の検証用サブスクリプション |
| リソース グループ | `rg-<略号>-dev-<連番>` |
| 名前 | `<key-vault-name>`（例 `kv-funato-dev-01`。例をそのまま使わず自分の名前に変更） |
| 場所 | Japan East |
| 価格レベル | Standard |
| 論理的な削除の保持期間 | 7 日（既存の検証用 module と同じ） |
| 消去保護 | 組織で必須でなければ、有効にしない設定を選択（既存の検証用 module と同じ方針）。組織で必須なら有効化し、第10章に引き継ぐ |

> **補足** Vault 名は Azure 全体で一意な 3〜24 文字です。英数字とハイフンを使い、先頭を英字、末尾を英数字にします。連続するハイフンは使いません。使用済みの場合は名前の末尾を変えます。

6. [回復オプション] の論理削除の保持日数を `7` にします。
7. 消去保護の選択を、上表と組織のルールに合わせます。
8. アクセス許可モデルを設定する画面（[アクセス構成]／[Access configuration]）を開きます。
9. [Azure ロールベースのアクセス制御] を選択します。
10. [ネットワーク] を開きます。
11. アクセス元の選択肢で、特定の仮想ネットワークと IP アドレスからのパブリックアクセスを許可する設定を選択します。
12. [ファイアウォール] の IPv4 アドレス／CIDR の入力欄に、社内公開 CIDR を 1 件入力します。
13. 残りの CIDR も 1 件ずつ追加します。
14. 許可一覧が管理者から受け取った一覧と一致することを確認します。
15. [例外] の [信頼された Microsoft サービスによるこのファイアウォールのバイパスを許可する] を選択します。
16. [タグ] を開きます。
17. 下表の名前と値を入力します。

| 名前 | 値 |
|---|---|
| purpose | `agent-governance-lab` |
| run | 今回の Run 番号（初回は `1`） |
| operator | 自分の検証者略号 |
| deleteAfter | 第1章で決めた削除予定日（`YYYY-MM-DD`） |

18. [確認および作成] を選択します。
19. 対象サブスクリプション・自分の RG・名前・Standard・Japan East・回復設定・RBAC・ネットワーク・タグを照合します。
20. 入力の検証に成功したら [作成] を選択します。
21. デプロイが完了するまで待ちます。

> **Note** 要確認: 公式資料は作成と作成後の設定を別々に説明しており、作成ウィザードの全タブ・選択肢の表記や配置は実機未確認です。[アクセス構成] などの表示名は初回に照合します。[回復オプション] が基本情報内にある場合はそこで設定します。ネットワーク制限や信頼されたサービスの例外を作成時に設定できない場合は、作成を保留して画面の差分を記録します。制限なしで先に作成しません。

> **補足** 保持日数は作成後に変更できません。消去保護も一度有効にすると無効に戻せません。作成前に確認し、組織の必須設定で 7 日・消去保護無効と異なる場合は、実設定と理由を記録して第10章の後片付けに引き継ぎます。

> **画面の見え方** 本手順では公開エンドポイントを有効にしたうえで、許可する IP を限定します。「すべてのネットワークを許可」と「パブリックアクセスを無効」のどちらも選びません。`.env` の JSON 配列全体ではなく、CIDR の文字列を 1 件ずつ入力します。仮想ネットワーク規則と Private Endpoint はこの Vault には追加しません。

> **補足** Key Vault は本ラボの RBAC・監査の検証対象です。Foundry が自動でこの Vault を利用するとは限らず、キーや接続文字列は保存しません。信頼されたサービスの例外は Azure 全体の許可ではなく、すべての Managed Identity の通信を通す仕組みでもありません。

### 作成した設定を確認する

1. ポータル上部の検索欄に、作成した Vault 名を入力します。
2. 検索結果から対象のキーコンテナーを選択します。
3. [概要] で、サブスクリプション・RG・Vault 名が自分のものと一致することを確認します。
4. 左側メニューの [ネットワーク] を選択します。
5. [ファイアウォールと仮想ネットワーク] で、アクセス元が限定されていることを確認します。
6. 許可された IPv4／CIDR の一覧と、信頼されたサービスの例外を照合します。
7. アクセス許可モデルの画面（[アクセス構成]）で RBAC が選択されていることを確認します。
8. [タグ] を開き、4 組の値を照合します。
9. Cloud Shell を Bash で開きます。
10. 次のコマンドの 2 つのプレースホルダーを自分の値に置き換えて実行します。

> **Note** この操作は作成後の確認です。相違があれば期待値と実値を記録し、作成時の入力や組織の Policy を確認します。既存の別 Vault を RBAC に切り替える操作ではありません。

```bash
az keyvault show --name "<key-vault-name>" --resource-group "<resource-group-name>" --query '{id:id,rbac:properties.enableRbacAuthorization,publicAccess:properties.publicNetworkAccess,network:properties.networkAcls,retention:properties.softDeleteRetentionInDays,purgeProtection:properties.enablePurgeProtection}' --output json
```
実行結果の確認ポイント: 下表と照合し、実際に表示された値を非公開の証跡に記録します。

| 出力 | 期待する値 |
|---|---|
| id | 自分のサブスクリプション・RG・Vault 名を含む ARM リソース ID |
| rbac | `true` |
| publicAccess | `Enabled` |
| network.defaultAction | `Deny` |
| network.ipRules | 管理者から受け取った社内公開 IPv4 CIDR の一覧 |
| network.bypass | `AzureServices` |
| network.virtualNetworkRules | 空配列 `[]` |
| retention | `7`（組織の必須設定がある場合は合意した実値） |
| purgeProtection | 有効なら `true`。有効化していない場合は `false` または `null` の実表示を記録 |

11. `id` の値を非公開の作業メモに控えます（第6章の診断設定で参照）。
12. 保持日数と消去保護の実値を、削除時に参照できるよう同じメモに残します。
13. 手順との差があれば共有 Excel に記録します。

> **補足** これは管理面の設定確認です。シークレットを読めることの証明にはなりません。消去保護を有効にした Vault は後で無効にできず、保持期間中は完全削除できません。

## 2.4. 完了条件

- 自分の RG に、Standard・Japan East の Vault が存在する。
- RBAC、許可する社内 IP、既定の拒否、信頼されたサービスの例外が設定されている。
- タグ 4 組、論理削除の保持日数、消去保護の実値を確認した。
- Vault 名・ARM リソース ID・回復設定を非公開に記録した。

この章の完了は設定の確認です。シークレットの閲覧可否・監査ログの到着・エージェントの呼び出し試験は合格にしません。

## 2.5. うまくいかない場合

| 困ったこと | 確認する内容 | 対応 |
|---|---|---|
| Vault 名を使用できない | 文字数・使用文字・名前の重複。論理削除済みの名前も再利用できない場合がある | 名前の末尾を変え、非公開メモを更新。既存 Vault を削除して名前を空けない |
| 作成が権限エラーになる | 使用アカウント、対象サブスクリプション・RG、第1章で確認した作成権限 | 管理担当者へ依頼し、権限を確認してから再試行 |
| Policy により作成を拒否される | エラーに示された設定と、消去保護・保持日数・タグ等の必須条件 | 管理者と必須値を照合。ネットワーク全許可や RBAC 以外への変更で回避しない |
| 作成画面でネットワークを制限できない | タブ・選択肢・使用言語 | 作成を保留。画面差を共有 Excel に記録し、手順修正が必要なら Issue へ転記 |
| Vault は開けるがシークレット一覧が拒否される | 管理面の権限とデータ面のロール、接続元 IP | 本章では一覧閲覧を合格条件にしない。自分にデータ権限を追加せず、第5・6章の目的と照合 |
| Cloud Shell の照合コマンドが失敗する | プレースホルダーの置換、サブスクリプション、Vault 名・RG 名 | 第1章の対象確認に戻る。管理面の失敗だけで Vault の IP 制限が原因と判断しない |

試した操作・期待と実際・次の担当を共有 Excel に記録します。切り分けのために秘密情報を保存したり、ネットワーク制限を解除したりしません。

## 2.6. 次の操作

Vault を残したまま第3章へ進みます。

## 2.7. 費用

Fabric 容量の費用は既存見積りに含まれません。事前確認済みの容量を使い、利用可否・費用負担・期間は課長判断とします。金額は要見積りです。

| Excel v3 明細 No | 項目 | 通常月 USD |
|---|---|---:|
| 5 | Key Vault / Standard 操作 | 0.030000 |
| 9 | Entra ID / Managed Identity / RBAC / 基本機能 | 0.000000 |

[README の費用の目安](../README.md) にある 2026-09-15 の見積り v3 の既定値です。Japan East、原則 32h/月の検証を前提とし、実利用額の保証ではありません。既存の Entra 条件付きアクセスに必要なライセンスを無料とする意味ではありません。

## 2.8. 本番との差・任意の再現

本番では職務分離と ID のライフサイクル、Key Vault の消去保護と復旧を設計します。本ラボで扱わない閉域・WAF 等との差は [付録 B](92-appendix-production-diff.md) を参照します。

### IaC で再現する (任意)

[02_keyvault.bicep](../infra/modules/02_keyvault.bicep) が再現用の設定です。`location`、`prefix`、`allowedIpRanges`、`tags` を GUI の記録と照合します。GUI で作成済みの場合、異なる名前の Vault を追加しないようにします。現在の [main.bicep](../infra/main.bicep) は Key Vault の既存 ID を受け取る構成ではないため、GUI 構築後に一式を重ねて展開しません。実行条件は [IaC の説明](../infra/README.md) に従います。

### 出典

- 出典: [Azure リソースの名前付け規則](https://learn.microsoft.com/ja-jp/azure/azure-resource-manager/management/resource-name-rules#microsoftkeyvault)（取得日 2026-09-20）
- 出典: [Key Vault soft-delete（保持期間の変更制約）](https://learn.microsoft.com/en-us/azure/key-vault/general/soft-delete-overview)（取得日 2026-09-20）
- 出典: [az keyvault show](https://learn.microsoft.com/en-us/cli/azure/keyvault#az-keyvault-show)（取得日 2026-09-20）

- 出典: [Key Vault の役割と利用理由](https://learn.microsoft.com/ja-jp/azure/key-vault/general/overview)（取得日 2026-09-15）

- 出典: [Foundry の RBAC](https://learn.microsoft.com/ja-jp/azure/foundry/concepts/rbac-foundry)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Key Vault を portal で作成](https://learn.microsoft.com/ja-jp/azure/key-vault/general/quick-create-portal)（取得日 2026-09-20）
- 出典: [Azure ロールの割当](https://learn.microsoft.com/ja-jp/azure/role-based-access-control/role-assignments-portal)（既存ドラフトから引継ぎ。今回の変更は実行順の整理）
- 出典: [Key Vault の RBAC](https://learn.microsoft.com/ja-jp/azure/key-vault/general/rbac-guide)（取得日 2026-09-20）
- 出典: [Key Vault のネットワーク](https://learn.microsoft.com/ja-jp/azure/key-vault/general/network-security)（取得日 2026-09-20）
- 出典: [Key Vault の論理削除](https://learn.microsoft.com/ja-jp/azure/key-vault/general/soft-delete-overview)（取得日 2026-09-20）
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

---

前へ: [準備と土台](01-prerequisites.md) / 次へ: [データ基盤を作る](03-data.md) / [トップに戻る](../README.md)
