"""設定を起動時に検証する。値はエラーにもログにも含めない。"""
from dataclasses import dataclass
import math
import os
import re
from urllib.parse import urlsplit


@dataclass(frozen=True)
class Config:
    foundry_project_endpoint: str
    foundry_agent_name: str
    foundry_agent_display_name: str
    entra_tenant_id: str
    cosmos_endpoint: str
    cosmos_database: str
    cosmos_container: str
    app_version: str
    max_prompt_chars: int
    foundry_timeout_seconds: float

    @classmethod
    def from_env(cls):
        def required(name):
            value = os.environ.get(name, '').strip()
            if not value:
                raise ValueError(f'{name}: 設定が必要です')
            return value

        def endpoint(name):
            value = required(name)
            try:
                parsed = urlsplit(value)
                valid = (parsed.scheme == 'https' and parsed.hostname
                         and not parsed.username and not parsed.password
                         and not parsed.query and not parsed.fragment
                         and parsed.port in (None, 443))
            except ValueError:
                valid = False
            if not valid:
                raise ValueError(f'{name}: HTTPS URL の形式が不正です')
            return value.rstrip('/'), parsed

        foundry, parsed = endpoint('FOUNDRY_PROJECT_ENDPOINT')
        if (not parsed.hostname.endswith('.services.ai.azure.com')
                or not parsed.path.startswith('/api/projects/')
                or not parsed.path[len('/api/projects/'):].strip('/')):
            raise ValueError('FOUNDRY_PROJECT_ENDPOINT: ホストまたはパスが不正です')
        agent = required('FOUNDRY_AGENT_NAME')
        if not re.fullmatch(r'[A-Za-z0-9_-]{1,64}', agent):
            raise ValueError('FOUNDRY_AGENT_NAME: 形式が不正です')
        cosmos, _ = endpoint('COSMOS_ENDPOINT')
        container = required('COSMOS_CONTAINER')
        if container == 'enterprise_memory':
            raise ValueError('COSMOS_CONTAINER: Agent Service の保存先は使えません')
        try:
            maximum = int(os.environ.get('MAX_PROMPT_CHARS', '2000'))
            timeout = float(os.environ.get('FOUNDRY_TIMEOUT_SECONDS', '60'))
            if maximum <= 0 or not math.isfinite(timeout) or timeout <= 0:
                raise ValueError
        except ValueError:
            raise ValueError('入力上限とタイムアウトには正の数が必要です') from None
        return cls(foundry, agent, os.environ.get('FOUNDRY_AGENT_DISPLAY_NAME') or agent,
                   required('ENTRA_TENANT_ID'), cosmos, required('COSMOS_DATABASE'),
                   container, os.environ.get('APP_VERSION', 'dev'), maximum, timeout)
