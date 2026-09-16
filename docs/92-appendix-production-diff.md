# B. 本番との差（Baseline）

本編の第0〜10章とは別の参考資料です。通常手順では開く必要はありません。

> **Note** 現在は骨組み・Azure 未実行です。コマンドはリポジトリ直下の Bash で実行する予定の手順です。

## B.1. 目的

学習用の構成と本番 Baseline の差を残します。閉域接続などの構築手順は含めません。

## B.2. 前提

README の前提と現行の設計判断（D14 を含む）が前提です。ここにある候補を追加展開する指示ではありません。

## B.3. 構築

構築はしません。次の差分を本番設計時に確認します。

| 項目 | この検証 | 本番で検討する差 |
|---|---|---|
| 閉域接続 | 人の入口は社内 IP。App Service → Foundry は送信 VNet 統合＋サービス エンドポイント | Private Endpoint・BYO VNet injection・経路・DNS |
| Firewall | 自前構築なし、ツール層の方式 A | Azure Firewall Standard と送信制御 |
| Managed VNet | CLI preview の作成手順は対象外 | GA 手順が整った段階で採否を再評価 |
| WAF | 使用しません | 入口の攻撃パターン検知と常設の要否 |
| APIM | Basic v2 はツール経路のみ。ネットワーク上は公開し Entra の許可主体で制限 | 本人経路もゲートウェイへ通す構成を別途設計。Standard v2 以上の VNet 統合や閉域経路の適合性を確認し、SKU 変更だけで成立すると扱わない |
| AI Search | Basic | 第1章、容量と可用性 |
| Cosmos DB | サーバーレス | Provisioned 3000 RU/s を起点に要件で見直し |
| 管理接続 | Bastion なし | Bastion と管理アクセス監査 |
| Storage | Standard_LRS | GRS と復旧要件 |
| BYO 到達 | 第4章 G2 が未解決なら停止。D14 では解消しない。IP 制限を外す復旧は行わない | 対応する接続方式・主体・権限を確認し、閉域接続の要否を別途設計 |

[Baseline](https://learn.microsoft.com/en-us/azure/architecture/ai-ml/architecture/baseline-microsoft-foundry-chat) の全体像を参照します。

## B.4. 確認

本番の経路、可用性、復旧、認証、監査、費用を実測して評価します。現時点では未検証です。

## B.5. うまくいかない場合

（本番設計時に記入）

> **Note** 要確認: 本番 SKU・構成の適用条件は別途確認します。検証時の公開例外をそのまま恒久化しません。

## B.6. 削除

この付録では作成しません。本番の削除・復旧・保持は変更管理に従います。

## B.7. 費用

Excel v3 No.1〜19 は今回の検証費用です。本番 Baseline 相当の約 $2,900/月は過去の概算で、現在の積算・保証ではありません。SKU・台数・通信・保持の再見積りは要確認です。

## B.8. 本番との差

本番適合性や運用受入は今回の成果に含めません。

---

前へ: [作り込み（hosted agent）の分岐 (任意)](91-appendix-hosted-agent.md) / 次へ: [概要](../README.md) / [トップに戻る](../README.md)
