"""プロセス共通の遅延クライアント。コンテナーはテストから差し替え可能。"""
from datetime import datetime, timezone
from threading import Lock
from uuid import uuid4
from azure.core.exceptions import ServiceRequestError, ServiceResponseError
from azure.cosmos import CosmosClient
from azure.cosmos.exceptions import CosmosHttpResponseError
from azure.identity import DefaultAzureCredential
from .auth import AppError

_lock = Lock()
_client = None
_credential = None
_container = None


def get_container(config):
    global _client, _credential, _container
    with _lock:
        if _client is None:
            if _credential is None:
                _credential = DefaultAzureCredential()
            _client = CosmosClient(url=config.cosmos_endpoint, credential=_credential)
        if _container is None:
            _container = _client.get_database_client(config.cosmos_database).get_container_client(config.cosmos_container)
        return _container


def save(config, identity, prompt, response, container=None):
    memo_id = str(uuid4())
    document = {'id': memo_id, 'userId': identity.user_id,
                'createdAt': datetime.now(timezone.utc).isoformat(),
                'prompt': prompt, 'response': response, 'appVersion': config.app_version}
    try:
        target = container if container is not None else get_container(config)
        target.upsert_item(document)
    except CosmosHttpResponseError as exc:
        status = exc.status_code
        if status in (401, 403):
            raise AppError(502, 'cosmos_authz', '保存先が拒否（MI のロール・A14）', status_upstream=status) from None
        raise AppError(502, 'cosmos_other', '保存先からエラー', status_upstream=status) from None
    except (ServiceRequestError, ServiceResponseError, ConnectionError, TimeoutError):
        raise AppError(504, 'cosmos_network', '保存先に到達できません（VNet 規則）') from None
    except Exception:
        raise AppError(502, 'cosmos_other', '保存先からエラー') from None
    return {'memo_id': memo_id, 'user_id_prefix': identity.user_id[:12]}
