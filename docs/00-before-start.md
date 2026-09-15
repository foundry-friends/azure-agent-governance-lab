# 0. 事前確認と検証の進め方

進め方: README の第0〜10章を順番に実施します。この章から開始します。

> **Note** 状態: 手順ドラフト（Azure 未実行）。構成変更日 2026-09-15。

> **補足** この章では環境を削除しません。通常の削除は最後の第10章です。中断して片付ける場合だけ、第10章へ進みます。

## 0.1. 目的

一つの環境を作り、同じエージェントに統制を加えながら、最後に削除する一周の流れを確認します。章の途中で別章の作業を済ませて戻る進め方は使いません。

### なぜこの作業が必要か

部門で共有する環境では、作業者ごとに対象・権限・費用の範囲を決めておかないと、他の人のリソースを変更したり、想定外の範囲まで権限を付けたりするおそれがあります。また、「誰が、どの接続元から、何をできれば合格か」が決まっていないと、後で応答が返ってもガバナンスを確認したことにはなりません。

この章では、検証の範囲と比較に使うユーザー・接続元を揃えます。ここで決めた条件を、以後の構築と第8・9章の試験で共通の判断基準として使います。

## 0.2. 始める前に決めること

| 項目 | 用意するもの |
|---|---|
| 検証対象 | 部門共有サブスクリプションと実施者専用 RG の命名 |
| 費用と期間 | 月予算、通知先、終了予定日。既存見積りは参考値 |
| 入口 | 許可する社内公開 IPv4 CIDR、許可外の試験接続元 |
| ユーザー | 構築用・開発用・呼び出し用・無権限のテスト主体 |
| モデル | Japan East の利用可否、登録、クォータを第1章で確認 |
| Defender | CSPM は既定 OFF。サブスクリプション変更は管理者と合意 |
| 記録 | 実 ID・社内 IP・実名は非公開の記録だけに保存 |

## 0.3. 主体と既存の条件付きアクセスを確認する

1. 検証に使うテナントとサブスクリプションを確認します。
2. 部門管理者に、専用 RG の作成と対象スコープでのロール割当を行えることを確認します。
3. 検証チーム内で、次のテスト主体を選びます。

| 主体 | 役割 | 注意点 |
|---|---|---|
| 構築担当 | リソース作成・ロール割当 | 最小権限試験の主体にはしません |
| 開発用ユーザー | Foundry User | 対象 project に限定します |
| 呼び出し用ユーザー | Foundry Agent Consumer | エージェントとの対話専用です |
| 無権限ユーザー | 対象へのロール割当なし | サインイン可能な検証用ユーザーを使います |

> **Note** 要確認: 検証用ユーザーの手配と既存のグループ／上位スコープからの継承は、部門管理者と確認します。適切な主体を用意できなければ ユーザー別の権限確認（C02）を Pending にします。既存の管理者権限を削除して試験用ユーザーに作り替えません。

### 既存の Entra 条件付きアクセスを確認する

1. Microsoft Entra 管理センターで対象テナントを開きます。
2. [監視と正常性] のサインインログを開きます。
3. 検証用ユーザーの該当サインインを選択します。
4. [条件付きアクセス] で適用ポリシーと結果を確認します。
5. ポリシーの対象リソース、対象ユーザー、許可する場所を管理者と照合します。
6. 確認結果を非公開の `evidence/` に記録します。

> **Note** 要確認: メニューの日本語表記は 事前確認 の画面で照合します。ログとポリシーの閲覧には Entra 側の権限が必要です。Azure RG の Owner だけで閲覧できるとは限りません。閲覧できなければ管理者に確認を依頼します。

> **補足** 既存ポリシーは変更しません。CAE（継続的アクセス評価）は対象サービスとクライアントに依存します。サインイン成功だけで Foundry のトークン失効やリソース側の IP 制限を確認したとは扱いません。ネットワーク境界・送信先の確認（C08）の動作試験は、アプリまで作成した後の第8章で行います。

### ネットワークの方針を揃える

1. 管理者から社内公開 IPv4 CIDR の一覧を受け取ります。
2. 同等権限で比較できる許可外接続元を用意します。
3. 値を非公開の記録に残します。

第1章で `.env` を用意するときにこの値を転記します。ここでは未作成のリソースの設定や呼び出し試験を要求しません。各リソースは作成する章で IP 制限と認証を設定します。

| 方針 | 適用 |
|---|---|
| 公開エンドポイントの入口 | 社内 IP に限定。認証は Entra ID |
| エージェントのツール | 第4章ではツールなし。第7章で許可先だけを追加 |
| サービス間通信 | 社内 PC の IP と異なるため、各経路を確認 |
| 変更できない前提 | Agent 365 なし、既存の条件付きアクセスを変更しない |

> **Note** 要確認: Cosmos DB と APIM のサービス発信経路には未解決点があります。資料が途中段階であることと、自分の Azure 権限不足を混同しません。第3・4・7章の停止条件を解消してから通し実行します。

## 0.4. 完了条件

- 対象・予算・期間・社内 IP・試験ユーザーを確認できた。
- 管理者に確認が必要な項目と担当が明確になった。
- まだ C01〜C10 を合格にはしていない。

## 0.5. うまくいかない場合

会社の承認や試験主体が用意できなければ、構築開始を保留します。章の不足は手順の課題として記録します。

## 0.6. 次の操作

第1章で専用 RG、予算、Log Analytics を実際に作ります。

## 0.7. 費用

この章は確認のみです。既存契約の費用がゼロという意味ではありません。

## 0.8. 対象外

閉域接続・Private Endpoint・VNet injection・Azure Firewall・WAF・Bastion は作りません。Managed VNet と Preview 機能の操作も対象外です。本番向けの差は [付録 B](92-appendix-production-diff.md) にまとめます。

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

---

前へ: [概要](../README.md) / 次へ: [準備と土台](01-prerequisites.md) / [トップに戻る](../README.md)
