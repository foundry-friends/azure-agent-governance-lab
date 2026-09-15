# 付録 A：作り込み（hosted agent）の分岐

骨子のみ・Azure 未実行。Run 3 の後の任意検証で、先に S3・S5 を確認します。

- デプロイ時の専用 Entra agent identity と最小権限。
- セッションごとの IP 消費、/24 推奨サブネット、private ACR（2026-06-25以降の project 条件）。hosted endpoint の public 制約の現状は要確認。
- `rai_config.rai_policy_name` に存在しない ID を指定した fail open は hosted agent 固有。C09 の本編と区別して合成入力で存在・適用・挙動を確認する予定。
- Network egress controls（Preview）、Agent Framework の HITL / tool approval と Purview middleware。
- app-only 呼び出しでの DLP とユーザーコンテキストによる DLP の違い。prompt agent の MCP / OpenAPI 承認設定は要確認。
- コンテナ compute は本編の見積りに含めない。SDK/REST/API世代と提供条件は実施前に確認する。

[設計判断 D11](../00_design.md) と [S5](05_foundry_agent.md) を参照します。本編で hosted agent の fail open を実証したとは扱いません。
