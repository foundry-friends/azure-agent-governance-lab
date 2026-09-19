from uuid import uuid4
import pytest


@pytest.mark.parametrize('route', ['/api/ask', '/api/memo'])
@pytest.mark.parametrize('name,value', [('Sec-Fetch-Site', None), ('Sec-Fetch-Site', 'cross-site'),
    ('X-Requested-With', None), ('Content-Type', 'text/plain')])
def test_csrf(clients, headers, route, name, value):
    if value is None:
        headers.pop(name)
    else:
        headers[name] = value
    result = clients().post(route, headers=headers, json={'prompt': '合成', 'response': '応答'})
    assert result.status_code == 403
    assert result.json()['layer'] == 'csrf'


def test_duplicate(clients, headers):
    client = clients()
    headers['X-Correlation-Id'] = str(uuid4())
    assert client.post('/api/ask', headers=headers, json={'prompt': '合成'}).status_code == 200
    result = client.post('/api/ask', headers=headers, json={'prompt': '合成'})
    assert result.status_code == 409
    assert result.json()['layer'] == 'duplicate'


def test_expired_then_refresh_uses_new_id(clients, headers):
    client = clients()
    headers['X-Correlation-Id'] = str(uuid4())
    headers['X-MS-TOKEN-AAD-EXPIRES-ON'] = '2000-01-01T00:00:00Z'
    assert client.post('/api/ask', headers=headers, json={'prompt': '合成'}).status_code == 401
    headers['X-MS-TOKEN-AAD-EXPIRES-ON'] = '2999-01-01T00:00:00Z'
    headers['X-Correlation-Id'] = str(uuid4())
    assert client.post('/api/ask', headers=headers, json={'prompt': '合成'}).status_code == 200


def test_missing_content_type(clients, headers):
    headers.pop('Content-Type')
    result = clients().post('/api/ask', headers=headers, content='{"prompt":"synthetic"}')
    assert result.status_code == 403
    assert result.json()['layer'] == 'csrf'
