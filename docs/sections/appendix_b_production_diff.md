# 付録 B：本番との差（Baseline）

骨子のみ。Run 4 で整形する比較であり、本番運用の承認・試験はしていません。

| 項目 | この検証 | Baselineとの差 |
|---|---|---|
| Firewall | Basic・検証日 | Standard |
| APIM | Basic v2・公開側 | Standard v2 + PE・閉域との経路とDNSを設計 |
| WAF | Run 3再現日の最後のみ | 常設 |
| AI Search | Basic・検証日 | S1 |
| Cosmos DB | サーバーレスを希望 | 3000 RU/s |
| 管理接続 | Bastionなし | Bastion |
| Storage | LRSを希望 | GRS |

Baseline相当は初期概算で約 $2,900/月。構成・SKU・台数と従量の積上げは要確認。[Baseline](https://learn.microsoft.com/en-us/azure/architecture/ai-ml/architecture/baseline-microsoft-foundry-chat) と [S9の概算履歴](09_teardown_cost.md) を参照します。
