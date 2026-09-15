# AGENTS.md — このリポジトリで手順書を執筆する AI エージェントへの指示

このファイルは、Codex（または他の AI エージェント）がこのリポジトリで**手順書のドラフトを書く**ときの共通ルールです。Codex はリポジトリ直下のこのファイルを自動で読みます。依頼者（たかし）からの個別の依頼は、このファイルのルールの上に重ねて解釈してください。

## 1. このリポジトリは何か

- 部内の SE が、部門で共有する Azure 検証環境に「ガバナンス付きエージェント環境（Microsoft Foundry・構成 A・Agent 365 なし）」を再現するための手順集。
- **前提（変更しない）**: 閉域接続なし（Private Endpoint・VNet injection・VPN・Firewall・Bastion を使わない）／インターネット全公開はしない（各リソースの公開エンドポイントに社内 IP の許可リスト。Entra 条件付きアクセスは既存設定で変更しない）／アウトバウンドは最低限（公開ツール不使用、MCP / OpenAPI は APIM 経由の許可リストのみ）／WAF なし／**Preview 機能の手順は載せない**／prompt agent（ノーコード）が主線、hosted agent は付録／データ基盤は BYO（自前 Bicep で目標 SKU＋IP 制限＋ローカル認証無効で作り、公式テンプレ 41 に ID を渡す。設計判断 D12）。
- 全体像・セクション・Run・所要時間・費用は [README.md](README.md)。設計判断は [docs/00_design.md](docs/00_design.md)。検証項目は [checks/README.md](checks/README.md)。
- **状態**: 骨組みとドラフト。**Azure は未実行**。この Mac では Azure に触れないため、正しさは**検証チームが実際に実行して確認する**（§4）。

## 2. 執筆の進め方（チーム検証モデル）

1. ドラフトは **Microsoft Learn の該当ページ（クイックスタート・How-to・ARM テンプレートリファレンス）を取りに行って**書く。自分の記憶だけで画面名・パラメータ名・API バージョンを書かない。取れなかったものは `> **Note** 要確認: …` と書く。
2. 各ページ冒頭の状態行を必ず置く: `> **Note** 状態: ドラフト（Learn YYYY-MM 時点の記述に基づく・未実行）`。検証チームが通したら `状態: 検証済み（YYYY-MM-DD・Run N）` に更新する（更新は依頼者が指示する）。
3. ページ末尾の「前へ／次へ／トップ」の**直前**に「出典」の箇条書きを置く: `- 出典: [ページ名](URL)（取得日 YYYY-MM-DD）`。Learn 以外（Architecture Center・公式 GitHub の foundry-samples・Azure 料金ページ）も可。ブログ・Q&A・個人記事は出典にしない。
4. 実機で確認していないことを、確認したように書かない。「（Run 1 初回で記入）」の置き場所は残してよい。
5. 1 回の依頼で扱う範囲は原則 **1 セクション（docs の 1 ファイル）**。関連する Bicep module・params・scripts・checks の同じセクション分は一緒に直してよい。他セクションは触らない。
6. 書き終えたら §6 のセルフチェックを実施し、結果を依頼者に返す。

## 3. 手順書の型（参考: takujis/copilot-agent-hands-on）

- **ファイル**: `docs/01-prerequisites.md`（S1）、`02-identity.md`（S2）、`10-network-boundary.md`（S3）、`11-data.md`（S4）、`12-foundry-agent.md`（S5）、`13-monitoring.md`（S6）、`14-gateway-app.md`（S7）、`15-policy-defender-eval.md`（S8）、`90-cleanup-cost.md`（S9）、`91-appendix-hosted-agent.md`、`92-appendix-production-diff.md`、`docs/runs/run0.md`〜`run2.md`。ファイルの追加・改名はしない。
- **見出し**: `# N. タイトル` → 1 行「このセクションを使う Run: …。先に要るセクション: …」→ 状態行 → 固定 8 見出し `## N.1. 目的`／`## N.2. 前提`／`## N.3. 構築`／`## N.4. 確認`／`## N.5. うまくいかない場合`／`## N.6. 削除`／`## N.7. 費用`／`## N.8. 本番との差`。小見出しは `###`。
- **手順**: 1 操作 1 文、です／ます、UI 要素は [角括弧]（例「1. 左側のナビゲーションから [ネットワーク] を選択し、[選択したネットワークと IP アドレス] をオンにします。」）。入力値は「| 項目 | 値 |」の表。貼り付ける文字列と Bash は言語指定のコードブロックで **1 コマンド 1 ブロック**、直後に「実行結果の確認ポイント: …」を 1 文。Bash 以外のシェルは書かない。
- **注意書き**は 3 種だけ: `> **Note**`（前提・所要時間・要確認）、`> **画面の見え方**`（UI の説明）、`> **補足**`（理由・背景）。
- **「うまくいかない場合」**（N.5）: 詰まったときの切り分け → 代替手順 → 記録 → 元に戻す、の順。例は [docs/10-network-boundary.md](docs/10-network-boundary.md) の 3.5。
- **費用**（N.7）: 見積り Excel v3 の明細 No（1〜19）と月額で書く。数字の出所は README「費用の目安」。
- **本番との差**（N.8）: Baseline（閉域・WAF・APIM Standard v2・AI Search S1・Cosmos 3000 RU/s・Bastion・GRS）との差だけ。
- **末尾**: 出典 → `---` → 「前へ: [x](…) / 次へ: [y](…) / [トップに戻る](../README.md)」（Run ページは `../../README.md`）。
- **任意**の手順はタイトルに「(任意)」。
- **言語**: 日本語のみ。製品名・コマンド・パラメータ名は原語。英語版は作らない。

## 4. 検証チームと共有環境のルール（手順に織り込む）

- Azure 検証環境は**部門で 1 つを共有、アカウントは個人別**。
  - リソースグループは**実施者ごと**に分ける: `rg-agentgov-<実施者略号>-run<N>`。同じ RG を複数人で同時に触らない。
  - **予算アラートと Azure Policy の割当は RG スコープ**。サブスクリプションスコープにしない（他チームに影響する）。
  - **Defender CSPM はサブスクリプション全体に課金**が乗るので、手順では「(任意)・課長判断」とし、既定は有効化しない。Defender for AI Services はリソース単位で有効化できるか要確認と書く。
  - Foundry account 名の接頭辞（最大 9 文字）に実施者略号を含める。
- 社内 IP の許可リストは全員共通。`.env` と `*.local.json` は各自のローカルに置き、**コミットしない**（.gitignore 済み）。
- 実在の ID・テナント・サブスクリプション・社内ホスト名・個人名は**どのファイルにも書かない**。placeholder は `<angle-brackets>`。
- 検証結果の記録は非公開の `evidence/`（.gitignore 済み）。手順の誤りは GitHub Issue（セクション番号・手順番号・実行コマンド・期待と実際・修正案）→ develop への PR で直す。

## 5. IaC・スクリプトのルール

- 公式テンプレは `infra/PINNED_COMMIT.md` のコミットに固定。`infra/vendor/` は取得物で**改変しない**（.gitignore 済み。無ければ infra/README.md の手順で取得）。
- `infra/main.bicep` は 41 の薄いラッパ＋自前 module（`02_keyvault`・`04_data`・`03_network_acls`・`06_diagnostics`・`07_gateway_app`・`08_policy_defender`）。Run の切り替えは `enableApim` などのフラグと `allowedIpRanges`。テンプレ 15（閉域）は呼ばない。
- Bicep の properties と API バージョンは ARM テンプレートリファレンス（`learn.microsoft.com/azure/templates/...`）で確認して書く。**この Mac には Bicep CLI がある**ので、module を直したら `bicep build infra/main.bicep` を通す（§7）。Azure へのデプロイはしない。
- `scripts/deploy.sh` の固定停止点（未確定の設定を展開しない）は、該当セクションの手順と params が確定するまで外さない。
- スクリプトは Bash、`set -euo pipefail`、`bash -n` で構文確認。Azure CLI のコマンドは Learn のリファレンスで引数を確認する。

## 6. セルフチェック（依頼のたびに実施し、結果を返す）

1. 状態行・固定 8 見出し・出典・末尾ナビがある。
2. 相対リンクが全部存在する（`python3` で `\[...\]\((相対パス)\)` を抽出して確認）。
3. 「Phase」「閉域」「Private Endpoint」「Firewall」「WAF」「Managed VNet」「Preview」が、「使わないものと理由」「本番との差」「対象外」以外の文脈で残っていない。
4. 実在 ID・接続文字列・キーのパターン（GUID、`AccountKey=`、`sig=` など）が無い。
5. 手順の各コマンドに「実行結果の確認ポイント」がある。UI 手順は [角括弧] で 1 操作 1 文。
6. Bicep を触ったら `bicep build` が通る（警告は列挙して依頼者に報告）。スクリプトを触ったら `bash -n` が通る。
7. 「要確認」の件数（`grep -o 要確認 | wc -l`）の増減と理由を報告する。

## 7. 依頼者が最初に頼む予定の作業（参考・順番の目安）

1. **`bicep build` は 2026-09-15 に通過済み**（エラー 0・警告は vendor 側 1 件。詳細は `infra/README.md` の「bicep build の状態」節）。module を直すたびに再実行して通過を維持する。`az`/Azure には触れない。
2. **記録の型を用意する**: `evidence/TEMPLATE.md`（実施日・Run・セクション・手順番号・合成入力・期待・実結果・Pass/Fail/Pending・未解決点）と `.github/ISSUE_TEMPLATE/procedure-diff.md`（手順と実際の差分報告）。README に「検証状況」の一覧表（セクション × 状態）を追加。
3. **Run 1 の経路をセクション単位で細かくする**: S1 → S2 → S3 → S4 → S5 → S6 → S8（監査部分）→ S9。CLI で完結する部分（RG・予算アラート・RBAC・Policy 割当・削除）はコマンドと引数まで確定。ポータル操作は Learn のクイックスタートの画面名で書き、状態行に「未実行」を残す。
4. **Run 2 の経路**: S7 → S8（Deny・評価）。
5. 付録 A・B は骨子のままでよい（依頼があれば）。

## 8. やってはいけないこと

- git の commit / push / branch 操作（依頼者が行う）。
- `infra/vendor/` の改変、`.env`・`*.local.json`・`evidence/` のコミット対象化。
- Preview 機能の手順の追加（Managed VNet、エージェント guardrails の Preview 介入点、Tool call 介入、Task Adherence、AI Gateway 統合の Preview 部分）。「GA 後に追記」と注記して止める。
- セクション名・番号・確認項目 C01〜C10 の番号の変更。
- Azure を実行したように書くこと。出典の無い画面名・パラメータ名の断定。
- 依頼された範囲外のファイルの変更。
