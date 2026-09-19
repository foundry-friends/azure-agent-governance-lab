"""本人の Bearer を既存エージェントの REST endpoint へ転送する。"""
import httpx
from .auth import AppError


async def ask(client, config, token, correlation_id, prompt):
    url = (f'{config.foundry_project_endpoint}/agents/{config.foundry_agent_name}'
           '/endpoint/protocols/openai/responses?api-version=v1')
    try:
        response = await client.post(
            url, headers={'Authorization': f'Bearer {token}',
                          'Content-Type': 'application/json', 'X-Correlation-Id': correlation_id},
            json={'input': [{'role': 'user', 'content': prompt}]},
            timeout=httpx.Timeout(config.foundry_timeout_seconds, connect=10.0))
    except httpx.RequestError:
        raise AppError(504, 'network', 'Foundry に到達できません（ネットワーク・C08）') from None
    status = response.status_code
    if not 200 <= status < 300:
        layer, message = {
            401: ('foundry_authn', 'Foundry がトークンを拒否（C03）'),
            403: ('foundry_authz', 'Foundry が権限を拒否（ロールなし・C02）'),
            404: ('foundry_notfound', 'エージェントまたはエンドポイントが見つからない（設定を確認）'),
        }.get(status, ('foundry_other', f'Foundry からエラー（ステータス {status}）'))
        raise AppError(502, layer, message, status_upstream=status)
    try:
        body = response.json()
    except ValueError:
        raise AppError(502, 'foundry_other', 'Foundry の応答形式を確認してください', status_upstream=status) from None
    if not isinstance(body, dict):
        raise AppError(502, 'foundry_other', 'Foundry の応答形式を確認してください', status_upstream=status)
    texts = []
    output = body.get('output')
    for item in output if isinstance(output, list) else []:
        if not isinstance(item, dict) or item.get('type') != 'message':
            continue
        content = item.get('content')
        for part in content if isinstance(content, list) else []:
            if (isinstance(part, dict) and part.get('type') == 'output_text'
                    and isinstance(part.get('text'), str)):
                texts.append(part['text'])
    text = ''.join(texts)
    if not text and isinstance(body.get('output_text'), str):
        text = body['output_text']
    result = {'text': text, 'downstream_id': body.get('id') if isinstance(body.get('id'), str) else None}
    if not text:
        result['note'] = 'no_output_text'
    return result
