# Policy の例

第9章の主線は Azure portal から組み込み定義を選び、実施者専用 RG に割り当てる手順です。ここにある JSON は未検証の参考例で、主線の入力ファイルではありません。

| ファイル | 用途 |
|---|---|
| [assignment.example.json](assignment.example.json) | effect パラメーターだけの例。同一環境で Audit、その後に条件を確認して Deny |
| [scope.example.json](scope.example.json) | 定義 ID と専用 RG scope の placeholder を含む割当全体の例 |
| [unrestricted-network.example.json](unrestricted-network.example.json) | Foundry の既定拒否なし公開を検出するカスタム定義の骨組み |
| [local-auth.example.json](local-auth.example.json) | Foundry のローカル認証を検出するカスタム定義の骨組み |

> **Note** 要確認: 例は JSON 構文のみ確認済みです。alias・effect・null/省略時の意味・対象 API での挙動は実機未検証です。Foundry のみを対象とする例を、他のリソース型へ流用しません。許可 IP の全許可 CIDR や複数規則による全域許可まで検出する例ではありません。

[第9章](../../docs/09-policy-defender-eval.md)で使用する組み込みのネットワーク定義（確認時 3.3.0）とキーアクセス定義（確認時 1.1.0）は、Foundry account に加えて AI Search も評価します。公式 JSON の対象型と、D14 の採用構成を照合して使います。カスタム例と組み込み定義は同一ではありません。

Cosmos / Storage / Key Vault / APIM / App Service は、この2つの組み込み定義の対象外です。ツール用 APIM は D14 のネットワーク公開＋Entra の許可主体制限であり、Foundry のネットワーク条件を転用しません。型別の適用と未実施の試験が残る間は C06 全体を Pass にしません。

モデル制限候補はデータモードの定義です。通常の ARM のモデル配置へ適用できると推定せず、対象経路・GA 範囲・識別子の確認まで保留します。Deny の設定だけで拒否試験を済ませたことにせず、安全な試験要求が未確定なら Pending とします。

- 出典: [Foundry Tools の組み込み Policy 一覧](https://learn.microsoft.com/ja-jp/azure/ai-services/policy-reference)（取得日 2026-09-17）
