# A. 作り込み（hosted agent）の分岐 (任意)

本編の第0〜10章とは別の参考資料です。通常手順では開く必要はありません。

> **Note** 現在は骨組み・Azure 未実行です。コマンドはリポジトリ直下の Bash で実行する予定の手順です。

## A.1. 目的

prompt agent では足りない作り込みを検討する付録の骨子です。実装や実機検証は含めません。

## A.2. 前提

[D11](90-design-decisions.md) と 第4章 を先に確認します。SDK / REST / API 世代と GA 提供は要確認です。

## A.3. 構築

構築手順は未作成です。専用 identity、ツールの承認、HITL、Purview middleware、コンテナ compute を設計候補として整理します。Preview の network egress controls は対象外で GA 後に追記します。

## A.4. 確認

RAI ポリシーの存在・適用と hosted 固有の fail open を将来確認します。本編 C09 で実証したとは扱いません。

## A.5. うまくいかない場合

（任意検証の初回で記入）

> **Note** 要確認: hosted endpoint の公開制約、認証、ユーザーコンテキストと app-only の DLP の違いは別途確認します。

## A.6. 削除

構築していません。実施する場合は 第10章 の終了手順と個別 compute の残存確認を準備します。

## A.7. 費用

Excel v3 No.1 は prompt agent です。hosted compute の費用は No.1〜19 に含めず、追加見積りを要確認とします。

## A.8. 本番との差

専用 identity のライフサイクル、復旧、承認運用は別設計です。[付録 B](92-appendix-production-diff.md) を参照します。

---

前へ: [削除と費用](10-cleanup-cost.md) / 次へ: [本番との差（Baseline）](92-appendix-production-diff.md) / [トップに戻る](../README.md)
