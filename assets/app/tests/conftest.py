from contextlib import ExitStack
import httpx
import pytest
from fastapi.testclient import TestClient
from app.config import Config
from app.main import create_app


@pytest.fixture
def config(monkeypatch):
    values = {
        'FOUNDRY_PROJECT_ENDPOINT': 'https://test-resource.services.ai.azure.com/api/projects/test-project',
        'FOUNDRY_AGENT_NAME': 'test-agent', 'ENTRA_TENANT_ID': 'test-tenant',
        'COSMOS_ENDPOINT': 'https://cosmos.invalid', 'COSMOS_DATABASE': 'test-db',
        'COSMOS_CONTAINER': 'test-container', 'APP_VERSION': 'test',
        'MAX_PROMPT_CHARS': '2000', 'FOUNDRY_TIMEOUT_SECONDS': '60',
    }
    for key, value in values.items():
        monkeypatch.setenv(key, value)
    return Config.from_env()


@pytest.fixture
def headers():
    return {'Sec-Fetch-Site': 'same-origin', 'X-Requested-With': 'fetch',
            'Content-Type': 'application/json', 'X-MS-CLIENT-PRINCIPAL-ID': 'test-principal-id',
            'X-MS-CLIENT-PRINCIPAL-IDP': 'aad', 'X-MS-TOKEN-AAD-ACCESS-TOKEN': 'test-token-not-a-credential'}


class FakeContainer:
    def __init__(self):
        self.documents = []

    def upsert_item(self, document):
        self.documents.append(document)
        return document


@pytest.fixture
def clients(config):
    with ExitStack() as stack:
        def make(handler=None, container=None):
            def default(request):
                return httpx.Response(200, json={'output_text': '合成応答'})
            http = httpx.AsyncClient(transport=httpx.MockTransport(handler or default))
            client = stack.enter_context(TestClient(create_app(config, http, container or FakeContainer())))
            # AsyncClient は MockTransport 専用。実ネットワークのクライアントを作らない。
            stack.callback(lambda: client.portal.call(http.aclose))
            return client
        yield make
