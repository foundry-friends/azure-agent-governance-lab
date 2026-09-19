"""Easy Auth が保護した入口でのみ信頼できるヘッダーを読む。"""
from dataclasses import dataclass
from datetime import datetime, timezone
from hashlib import sha256


class AppError(Exception):
    def __init__(self, status, layer, message, reason=None, status_upstream=None):
        super().__init__(layer)  # 生の例外・トークンを保持しない
        self.status = status
        self.layer = layer
        self.message = message
        self.reason = reason
        self.status_upstream = status_upstream


@dataclass(frozen=True, repr=False)
class Identity:
    token: str
    user_id: str


def authenticate(headers, now=None):
    headers = {k.lower(): v for k, v in headers.items()}
    principal = headers.get('x-ms-client-principal-id')
    if not principal or headers.get('x-ms-client-principal-idp') != 'aad':
        raise AppError(401, 'entry', 'サインインし直してください')
    token = headers.get('x-ms-token-aad-access-token')
    if not token:
        raise AppError(401, 'entry', '再サインインしても続く場合は管理者へ（トークン ストア／委任スコープ）', 'no_token')
    try:
        expires = datetime.fromisoformat(headers.get('x-ms-token-aad-expires-on', '').replace('Z', '+00:00'))
        if expires.tzinfo is None:
            expires = None
    except ValueError:
        expires = None
    if expires is not None and expires < (now or datetime.now(timezone.utc)):
        raise AppError(401, 'entry', '再認証が必要です', 'expired')
    return Identity(token, sha256(principal.encode('utf-8')).hexdigest())
