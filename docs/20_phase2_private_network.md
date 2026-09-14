# Phase 2：閉域ネットワーク（骨子）

Azure で未実行です。ここでは見出しと確認項目までを定義します。Phase 1 と別 RG / 新しい Foundry account を使います。

## 1. 作成前に構成を確定する

- [ ] 固定 SHA の `15-private-network-standard-agent-setup` と依存 module を確認します。
- [ ] BYO VNet injection は account 作成時のみ設定でき、後付けできないことを確認します。
- [ ] Phase 1 の変更展開にしないこと、モデル・SKU の Japan East 対応を確認します（要確認）。
- [ ] RG、モデル、VNet、PE、依存データサービスの費用と削除対象を整理します。

## 2. VNet とサブネットを準備する

- [ ] サブネットを `Microsoft.App/environments` に委任し、/27 以上のアドレス空間を確保します。
- [ ] 既存ネットワークとのアドレス重複、Private DNS と名前解決、必要な経路・出口を確認します。
- [ ] 追加サブネットの必要数・用途・サイズは固定テンプレートで要確認です。

## 3. Firewall Basic と管理経路を決める

- [ ] テンプレートが Basic に対応するか、SKU 以外に必要な変更があるか要確認です。
- [ ] 必要通信、DNS、ルート、出口ルールを洗い出します。許可先は推測で列挙しません。
- [ ] Bastion を常設しません。Developer SKU または P2S VPN の条件と閉域検証端末からの接続を確認します（要確認）。

## 4. 新しい Foundry account を展開する

- [ ] 固定コミットと確定パラメータで展開します。具体的なパラメータとコマンドは要確認です。
- [ ] capability host、Entra ID 接続、private endpoint、DNS、public network 無効化を確認します。
- [ ] Phase 1 と同じログ・RBAC・Policy の検証をこの環境でも行います。

## 5. 閉域の成立と例外を確認する

- [ ] C08：私設経路では認証済み呼び出しが成功し、公開側から同じ資格情報で拒否されることを確認します。
- [ ] public network の Policy 非準拠が是正されたことを確認します。
- [ ] Bing Grounding / Web search / SharePoint Grounding は閉域でも public endpoint 経由です。利用しないか、必要な公開通信を許容するかを明示します。完全に閉域化できたと扱いません。
- [ ] 名前解決失敗、RBAC 拒否、ネットワーク拒否を切り分けます。

## 6. 次フェーズとの分離・終了

- [ ] Phase 3 の APIM Basic v2 をこの閉域 Foundry に接続しません。
- [ ] 閉域統合の参考はテンプレート 16 です。Standard v2 / Premium v2＋PE の要件、経路、差分、再作成要否は要確認です。
- [ ] [削除手順](90_teardown_and_cost.md) に従って終了します。Phase 1 用 `.env` を誤用せず、対象をその都度確認します。

根拠：[ネットワーク注入](https://learn.microsoft.com/en-us/azure/foundry/agents/concepts/networking-options)、[閉域と外部サービス](https://learn.microsoft.com/en-us/azure/foundry/how-to/configure-private-link)、[APIM 接続](https://learn.microsoft.com/en-us/azure/foundry/configuration/enable-ai-api-management-gateway-portal)。
