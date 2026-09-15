# Policy の例

| ファイル | 用途 |
|---|---|
| [assignment.example.json](assignment.example.json) | effect パラメータだけの例。Run 1 は Audit、Run 2 は対応確認後に Deny |
| [scope.example.json](scope.example.json) | 定義 ID と専用 RG scope の placeholder を含む割当全体の例 |
| [unrestricted-network.example.json](unrestricted-network.example.json) | Foundry の既定拒否なし公開を検出する定義の骨組み |
| [local-auth.example.json](local-auth.example.json) | Foundry のローカル認証を検出する定義の骨組み |

> **Note** 要確認: JSON 構文だけを確認した未検証例です。alias・effect・null/省略時の意味を照合します。社内 IP を許可した公開は拒否対象にしません。IP 規則の全許可 CIDR や複数規則による全域許可までこの例では検出しません。

Cosmos / Storage / Search / Key Vault / APIM / App Service は設定名と Policy alias が違います。この例を流用せず、型別の組み込み定義またはカスタム条件を確認します。特に APIM の XML ポリシー内の IP 判定を一般的な ARM プロパティ検査で覆ったと扱いません。対象を拡張するまで C06 全体は未完了です。

[S8](../../docs/09-policy-defender-eval.md) で Audit と Deny の期待結果を別々に記録します。Deny は S5 の後追い設定や BYO の公開復旧と競合し得るため、スコープと例外を確認します。
