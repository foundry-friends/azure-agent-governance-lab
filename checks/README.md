# 「統制が効いている」検証項目（10 個）

まだ実機検証していません。初期状態は全件 Pending です。設定の存在と効果を分け、期待結果を確認できた場合だけ Pass、期待に反した場合は Fail、未実施・判断不能は Pending と記録します。

| ID | 層 | Run | セクション | 検証 | 期待結果 |
| --- | --- | --- | --- | --- | --- |
| C01 | 基盤・データ | 1 | S4・S5 | account / project の capability host と自前データ接続を確認し、prompt agent で合成入力 1 往復を実行 | host が成功し、Entra ID で応答でき、使用する Cosmos / Storage / Search / Key Vault が意図した自前リソースと一致する |
| C02 | ID・RBAC | 1 | S2 | 上位権限を持たない Consumer、User、無権限のテスト主体で呼び出しと作成・編集を試す | Consumer は呼び出しのみ、User は必要な開発操作が可能、無権限主体は拒否される。継承による権限混入がない |
| C03 | 認証方式 | 1 | S2 | ローカル認証無効設定と Entra ID 呼び出しを確認し、認証なしの呼び出しを試す。キーは取得しない | 設定でローカル認証が無効、Entra ID は成功、未認証は拒否。これだけで実キーを使った拒否試験済みとはしない |
| C04 | 診断監査 | 1 | S6 | 対象カテゴリを列挙し、合成操作後に Log Analytics で対応レコードを確認 | 必要な診断ログが到着し、本文ログとは区別できる。診断ログにプロンプト本文があることを期待しない |
| C05 | 本文・閲覧制御 | 1 | S6 | Application Insights トレースと AppGenAIContent の合成本文を確認し、閲覧許可あり／なしの主体で照会 | 許可した主体のみ本文を閲覧でき、保持 30 日を確認できる。収集未設定・Entra ID 経路未確定は Pending |
| C06 | Policy | 1 / 3 | S8 | Run 1 で Audit 割当と非準拠評価を確認。Run 3 で承認モデル限定を Deny にし非承認モデル展開を試す | Run 1 は違反を検出（公開ネットワークは意図した非準拠）、防止と扱わない。Run 3 の非承認モデルは拒否。content filter 系は Preview / Audit のみ |
| C07 | 脅威検知・態勢 | 1 | S8 | 合意した Defender CSPM / AI Services の状態を確認し、対応する安全な検知テスト方法を公式資料で確認して実施（方法は要確認） | プラン・対象・費用を確認し、検知試験をした場合は対応イベントを確認。有効化だけで検知成功とはしない。Agent 365 系は対象外 |
| C08 | ネットワーク | 2 | S3 | 閉域端末と公開側端末から同一の権限で呼び出す。名前解決・出口も確認 | 閉域は成功、公開側は拒否。Bing / Web search / SharePoint Grounding の公開経路の例外を明示 |
| C09 | Gateway・ガードレール | 3 | S5・S7 | APIM 経由をログで確認し quota 超過試験、正常入力・拒否入力、RAI ポリシー存在確認を行う | quota 超過は 403。適用ガードレールが期待どおり動き、存在しない ID の fail open を見逃さない。Preview は別に記録 |
| C10 | コスト・ライフサイクル | 1 / 2 / 3 | S1・S9（quotaはS7） | 予算通知設定、RG 削除、soft-delete、RG 外、Defender プラン、削除後の費用を確認 | RG 消失だけで完了にせず、残存と課金を確認。予算通知をハードリミットと扱わない |

## セクション別 CLI 骨子の使い方

`bash scripts/verify.sh --section N` は S1〜S9 の指定に応じてC番号を絞り、可能な設定収集を補助します。安全に推測できない API を埋めず、実操作が必要な項目を Pending と表示し、終了コード 2 を返します。取得コマンドが失敗したときはその失敗で停止します。検証合格を返す自動テストではありません。

## 証跡の書き方

各 ID に「実施日、対象Run、合成入力、期待結果、実結果、Pass / Fail / Pending、未解決点」を記録します。`evidence/` は公開対象外です。公開版には resource ID、ユーザー ID、社内ホスト名、本文、認証情報を含めません。C06 の Run 3 部分など、未実施の部分を Run 1 の完了に紛れ込ませません。

根拠と手順は [セクション一覧](../docs/sections/00_overview.md)、[Run 1](../docs/runs/run1_public_minimum.md)、[Run 2](../docs/runs/run2_private_network.md)、[Run 3](../docs/runs/run3_gateway.md)、[削除・費用](../docs/sections/09_teardown_cost.md) を参照してください。

C09の存在しないRAI IDによるfail open再現はhosted agent固有です。本編はRAIポリシーの存在・適用を確認し、実再現は付録Aの未実施分として分けます。C09全体を無条件Passにしません。評価・レッドチームはS8の補足記録で、C番号は追加しません。
