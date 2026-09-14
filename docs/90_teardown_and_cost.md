# 削除・費用確認・予算アラート

## 構築前に予算を決める

[README の費用表](../README.md#5-費用の目安) は Japan East・2026-09-14・USD・730h/月の概算です。構築前に見積り、終了時刻、削除担当、翌日以降の費用確認を決めます。都度構築は週 1 回 × 8h で月 $100〜300 を想定しています。

[Azure portal](https://portal.azure.com/) の Cost Management + Billing で対象サブスクリプション / RG のスコープを選び、Cost analysis でサービス別・日別・RG 別に絞ります。Budgets で月予算と通知先を設定します。例として 50% / 80% / 100% と予測超過を通知候補にします。画面名、権限、通知方式、費用反映の遅延は要確認です。通知は自動停止ではありません。

共有サブスクリプションの Defender CSPM / AI Services の費用は、検証 RG の費用だけでは把握できない場合があります。変更前のプランと利用チームを確認し、合意のないプラン変更は行いません。[Defender](https://learn.microsoft.com/en-us/azure/defender-for-cloud/ai-onboarding)

## 1. 削除前に対象と証跡を確認する

- `.env` の subscription / tenant / RG が今回の専用環境であることを確認します。
- 必要な証跡は ID、本文、内部情報を除いた形で残します。生ログは公開しません。
- RG 内外のリソース、ロック、共有依存、バックアップ、Policy 割当、Defender の変更有無を確認します。
- Foundry account の名前・リージョンは、soft-delete / purge 確認に必要になるため非公開の作業記録へ控えます。

```bash
source .env
az resource list --subscription "$AZURE_SUBSCRIPTION_ID" \
  --resource-group "$AZURE_RESOURCE_GROUP" --output table
```

## 2. RG を削除する

スクリプトは `.env` の RG と引数の一致を要求します。対象 RG 内のすべてのリソースを削除するため、共有 RG では使いません。

```bash
bash scripts/teardown.sh --delete '<resource-group-name>'
```

内部で使う基本コマンドは次の形です。`--no-wait` は削除開始だけを意味します。

```bash
az group delete --subscription "$AZURE_SUBSCRIPTION_ID" \
  --name "$AZURE_RESOURCE_GROUP" --yes --no-wait
az group exists --subscription "$AZURE_SUBSCRIPTION_ID" \
  --name "$AZURE_RESOURCE_GROUP"
```

`teardown.sh` は定期的に RG 消失を確認し、待機上限でも存在すれば終了コード 2 を返します。ロックや依存関係による失敗をポータルで調べ、削除状況を再確認します。照会失敗を削除成功とは扱いません。

```bash
bash scripts/teardown.sh --status
```

## 3. Soft-delete と purge を確認する

Foundry account は RG 削除後も削除済みリソースとして残り、再作成・完全削除に purge が必要な場合があります。対象・保持条件・CLI の対応は要確認です。Key Vault 等にも削除済み状態や purge protection の確認が必要です。不可逆の purge は対象と復元不要を確認してから利用者が行い、スクリプトからは自動実行しません。

```bash
# 要確認：使用中の CLI と Foundry account 種別で対応を確認する参考例。
az cognitiveservices account list-deleted \
  --subscription "$AZURE_SUBSCRIPTION_ID" --output table
# 要確認：一覧の対象と復元不要を確認した後だけ実行する例。
az cognitiveservices account purge \
  --subscription "$AZURE_SUBSCRIPTION_ID" \
  --location '<deleted-account-location>' \
  --resource-group '<original-resource-group-name>' \
  --name '<deleted-foundry-account-name>'
```

## 4. RG 外の残存とプランを確認する

APIM、Firewall、WAF、Private Endpoint、DNS、監視、共有 Log Analytics、予算・Policy 割当等の所属先を確認します。共有リソースは勝手に削除しません。Phase 2 と Phase 3 の RG は個別に確認します。

検証のため変更した Defender プランを管理者と確認し、必要なら変更前へ戻します。RG 削除だけでサブスクリプション単位のプランが元に戻るとは扱いません。既存のプランを一律に無効化しません。

## 5. 費用の反映を確認する

```bash
bash scripts/cost_check.sh
```

スクリプトはポータルでの確認項目と、後で利用者が実行する CLI 例を表示するだけです。翌日以降も Cost analysis で費用を確認し、反映遅延がある間は終了判定を保留します。RG 消失と、残存リソース・費用確認の完了を別々に記録します。

記録項目：実施日、削除対象の匿名識別子、RG 消失確認、soft-delete 確認、RG 外の確認、Defender 変更復帰、費用の確認期間と結果。未確認がある場合は C10 を Pending にします。

Azure OpenAI の費用にハードリミットはありません。APIM の `token-quota` もすべての費目を止める機能ではありません。[APIM 制限](https://learn.microsoft.com/en-us/azure/api-management/llm-token-limit-policy)
