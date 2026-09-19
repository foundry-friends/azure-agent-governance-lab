import pytest
from fastapi.testclient import TestClient
from app.main import create_app
from app.config import Config


@pytest.mark.parametrize('missing,reason', [
    ('X-MS-CLIENT-PRINCIPAL-ID', None), ('X-MS-TOKEN-AAD-ACCESS-TOKEN', 'no_token')])
def test_missing(clients, headers, missing, reason):
    headers.pop(missing)
    result = clients().post('/api/ask', headers=headers, json={'prompt': '合成入力'})
    assert result.status_code == 401
    assert result.json()['layer'] == 'entry'
    assert result.json()['reason'] == reason


def test_wrong_idp(clients, headers):
    headers['X-MS-CLIENT-PRINCIPAL-IDP'] = 'other'
    assert clients().post('/api/ask', headers=headers, json={'prompt': '合成入力'}).status_code == 401


@pytest.mark.parametrize('expiry,status,reason', [
    ('2000-01-01T00:00:00.123Z', 401, 'expired'), ('not-a-date', 200, None),
    ('2999-01-01T00:00:00Z', 200, None)])
def test_expiry(clients, headers, expiry, status, reason):
    headers['X-MS-TOKEN-AAD-EXPIRES-ON'] = expiry
    result = clients().post('/api/ask', headers=headers, json={'prompt': '合成入力'})
    assert result.status_code == status
    assert result.json().get('reason') == reason


def test_case_insensitive(clients, headers):
    assert clients().post('/api/ask', headers={k.lower(): v for k, v in headers.items()}, json={'prompt': '合成入力'}).status_code == 200


@pytest.mark.parametrize('name,value', [
    ('COSMOS_CONTAINER', 'enterprise_memory'),
    ('FOUNDRY_PROJECT_ENDPOINT', 'http://test-resource.services.ai.azure.com/api/projects/test'),
    ('FOUNDRY_PROJECT_ENDPOINT', 'https://example.invalid/api/projects/test'),
    ('FOUNDRY_PROJECT_ENDPOINT', 'https://test-resource.services.ai.azure.com/other'),
    ('FOUNDRY_AGENT_NAME', '../other'), ('MAX_PROMPT_CHARS', '0'),
    ('FOUNDRY_TIMEOUT_SECONDS', 'nan')])
def test_startup_rejects(config, monkeypatch, name, value):
    monkeypatch.setenv(name, value)
    with pytest.raises(ValueError):
        with TestClient(create_app()):
            pass


def test_defaults(config, monkeypatch):
    for key in ('APP_VERSION', 'MAX_PROMPT_CHARS', 'FOUNDRY_TIMEOUT_SECONDS', 'FOUNDRY_AGENT_DISPLAY_NAME'):
        monkeypatch.delenv(key, raising=False)
    result = Config.from_env()
    assert (result.app_version, result.max_prompt_chars, result.foundry_timeout_seconds) == ('dev', 2000, 60)
    assert result.foundry_agent_display_name == result.foundry_agent_name


def test_all_easy_auth_headers_missing(clients, headers):
    headers = {key: value for key, value in headers.items() if not key.startswith('X-MS-')}
    result = clients().post('/api/ask', headers=headers, json={'prompt': '合成入力'})
    assert result.status_code == 401
    assert result.json()['layer'] == 'entry'
