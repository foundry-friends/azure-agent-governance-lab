# 公式テンプレートの固定コミット

- リポジトリ：`microsoft-foundry/foundry-samples`（名称変更なし）
- main の取得時点の SHA：`58e4127567f7e9afcf0145d874df890284ca5faf`
- 取得日時（UTC）：`2026-09-15T05:43:04.099021+00:00`
- 取得元：[GitHub API commits/main](https://api.github.com/repos/microsoft-foundry/foundry-samples/commits/main)
- アーカイブ SHA-256：`c491f4d98ef7d35b2b2757c9cbfb58d1b722f43b7bb525c8e5203a99e6f38957`
- 実在確認：[41-standard-agent-setup](https://github.com/microsoft-foundry/foundry-samples/tree/58e4127567f7e9afcf0145d874df890284ca5faf/infrastructure/infrastructure-setup-bicep/41-standard-agent-setup)、[15-private-network-standard-agent-setup](https://github.com/microsoft-foundry/foundry-samples/tree/58e4127567f7e9afcf0145d874df890284ca5faf/infrastructure/infrastructure-setup-bicep/15-private-network-standard-agent-setup)
- 16 の参考パスは `16-private-network-standard-agent-apim-setup`。初期ドラフトの名称と一致。15のREADMEにある末尾preview付きリンクは固定版では404で、GitHub contents APIと実ファイルのHTTP取得で末尾なしのパスを確認。今回16を展開しません。
- 取得先：`infra/vendor/foundry-samples-58e4127567f7e9afcf0145d874df890284ca5faf/infrastructure/infrastructure-setup-bicep/`。41/15 の main・README・相対依存ファイル、および配布元 LICENSE を保持。vendor は .gitignore 対象です。

アーカイブは固定SHAから取得し、今回必要な41/15とライセンスだけ展開先に保持しました。ソースは改変していません。Git操作・Azure実行はしていません。`az` / `bicep` はこの環境にありません。**bicep build はこの環境で未実行**。取得日は実機検証日ではありません。
