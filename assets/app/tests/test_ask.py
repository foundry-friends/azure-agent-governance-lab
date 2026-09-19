import json
from uuid import uuid4
import httpx
import pytest


@pytest.mark.parametrize('body,text,note', [
    ({'id': 'test-response-id', 'output': [{'type': 'message', 'content': [
        {'type': 'output_text', 'text': '合成'}, {'type': 'output_text', 'text': '応答'}]}]}, '合成応答', None),
    ({'output_text': '代替応答'}, '代替応答', None), ({}, '', 'no_output_text')])
def test_response_and_request(clients, config, headers, body, text, note):
    cid = str(uuid4())
    headers['X-Correlation-Id'] = cid
    def handler(request):
        assert str(request.url) == config.foundry_project_endpoint + '/agents/test-agent/endpoint/protocols/openai/responses?api-version=v1'
        assert request.headers['authorization'] == 'Bearer ' + headers['X-MS-TOKEN-AAD-ACCESS-TOKEN']
        assert request.headers['x-correlation-id'] == cid
        assert request.headers['content-type'] == 'application/json'
        assert json.loads(request.content) == {'input': [{'role': 'user', 'content': '合成入力'}]}
        assert request.extensions['timeout']['connect'] == 10
        assert request.extensions['timeout']['read'] == 60
        return httpx.Response(200, json=body)
    result = clients(handler).post('/api/ask', headers=headers, json={'prompt': '合成入力'})
    assert result.status_code == 200
    data = result.json()
    assert data['text'] == text
    assert data.get('note') == note
    assert data['downstream_id'] == body.get('id')
    assert data['correlation_id'] == cid
    assert data['duration_ms'] >= 0


@pytest.mark.parametrize('status,layer', [(401, 'foundry_authn'), (403, 'foundry_authz'),
    (404, 'foundry_notfound'), (429, 'foundry_other'), (500, 'foundry_other'), (400, 'foundry_other')])
def test_upstream_errors(clients, headers, status, layer):
    client = clients(lambda request: httpx.Response(status, text='UPSTREAM-PRIVATE-BODY'))
    result = client.post('/api/ask', headers=headers, json={'prompt': '合成入力'})
    assert result.status_code == 502
    assert result.json()['layer'] == layer
    assert result.json()['status_upstream'] == status
    assert 'UPSTREAM-PRIVATE-BODY' not in result.text


@pytest.mark.parametrize('error', [httpx.ConnectError, httpx.ReadTimeout])
def test_network(clients, headers, error):
    def handler(request):
        raise error('PRIVATE-EXCEPTION', request=request)
    result = clients(handler).post('/api/ask', headers=headers, json={'prompt': '合成入力'})
    assert result.status_code == 504
    assert result.json()['layer'] == 'network'
    assert 'PRIVATE-EXCEPTION' not in result.text


@pytest.mark.parametrize('prompt', ['', '  ', 'x' * 2001, None, 12])
def test_input(clients, headers, prompt):
    result = clients().post('/api/ask', headers=headers, json={'prompt': prompt})
    assert result.status_code == 400
    assert result.json()['layer'] == 'input'


def test_safe_logs(clients, headers, capsys):
    client = clients()
    client.post('/api/ask', headers=headers, json={'prompt': 'PRIVATE-SYNTHETIC-PROMPT'})
    output = capsys.readouterr().out
    for private in ('PRIVATE-SYNTHETIC-PROMPT', '合成応答', headers['X-MS-TOKEN-AAD-ACCESS-TOKEN'], headers['X-MS-CLIENT-PRINCIPAL-ID']):
        assert private not in output
    row = json.loads(output.strip())
    assert row['route'] == '/api/ask'
    assert row['status'] == 200


def test_health_and_html(clients):
    client = clients()
    assert client.get('/healthz').json() == {'ok': True, 'app_version': 'test'}
    result = client.get('/')
    assert result.status_code == 200
    assert 'test-agent' in result.text
    assert '{{' not in result.text
    assert result.headers['cache-control'] == 'no-store'
