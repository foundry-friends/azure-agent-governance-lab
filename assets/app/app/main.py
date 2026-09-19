"""1 往復の呼び出しと明示保存。Azure の認証除外パスは設定しない。"""
from contextlib import asynccontextmanager
from datetime import datetime, timezone
import html
import json
from pathlib import Path
from threading import Lock
import time
from uuid import UUID, uuid4

import httpx
from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from starlette.concurrency import run_in_threadpool

from .auth import AppError, authenticate
from .config import Config
from . import cosmos, foundry

STATIC = Path(__file__).parent / 'static'


class Duplicates:
    def __init__(self):
        self.seen = {}
        self.lock = Lock()

    def claim(self, key):
        with self.lock:
            now = time.monotonic()
            self.seen = {k: t for k, t in self.seen.items() if now - t < 30}
            if key in self.seen:
                raise AppError(409, 'duplicate', '送信済みです')
            self.seen[key] = now


def correlation_id(request):
    # 任意ヘッダー値をログに反射せず、UUID v4 だけ受け付ける。
    try:
        value = UUID(request.headers.get('x-correlation-id', ''))
        if value.version == 4:
            return str(value)
    except ValueError:
        pass
    return str(uuid4())


def create_app(config=None, foundry_client=None, cosmos_container=None):
    @asynccontextmanager
    async def lifespan(application):
        application.state.config = config if config is not None else Config.from_env()
        if foundry_client is None:
            async with httpx.AsyncClient(follow_redirects=False) as client:
                application.state.foundry_client = client
                yield
        else:
            application.state.foundry_client = foundry_client
            yield

    application = FastAPI(lifespan=lifespan, docs_url=None, redoc_url=None, openapi_url=None)
    application.state.cosmos_container = cosmos_container
    duplicates = Duplicates()

    @application.middleware('http')
    async def audit(request, call_next):
        start = time.monotonic()
        request.state.correlation_id = correlation_id(request)
        request.state.layer = None
        request.state.status_upstream = None
        response = await call_next(request)
        response.headers['Cache-Control'] = 'no-store'
        entry = {'ts': datetime.now(timezone.utc).isoformat(),
                 'correlation_id': request.state.correlation_id,
                 'route': request.url.path if request.url.path in ('/', '/api/ask', '/api/memo', '/healthz') else 'other',
                 'status': response.status_code, 'layer': request.state.layer,
                 'duration_ms': round((time.monotonic() - start) * 1000),
                 'app_version': application.state.config.app_version}
        if request.state.status_upstream is not None:
            entry['status_upstream'] = request.state.status_upstream
        print(json.dumps(entry, ensure_ascii=False), flush=True)
        return response

    @application.get('/', response_class=HTMLResponse)
    async def index():
        cfg = application.state.config
        page = (STATIC / 'index.html').read_text(encoding='utf-8')
        return HTMLResponse(page.replace('{{AGENT_NAME}}', html.escape(cfg.foundry_agent_display_name))
                            .replace('{{MAX_PROMPT_CHARS}}', str(cfg.max_prompt_chars)))

    @application.get('/healthz')
    async def health():
        return {'ok': True, 'app_version': application.state.config.app_version}

    async def post(request, memo):
        cfg = application.state.config
        cid = request.state.correlation_id
        start = time.monotonic()
        try:
            headers = request.headers
            if (headers.get('sec-fetch-site') != 'same-origin'
                    or headers.get('x-requested-with') != 'fetch'
                    or headers.get('content-type', '').split(';')[0].strip().lower() != 'application/json'):
                raise AppError(403, 'csrf', 'この操作は受け付けられません')
            duplicates.claim(cid)
            identity = authenticate(headers)
            try:
                body = await request.json()
            except (ValueError, UnicodeError):
                raise AppError(400, 'input', '入力を見直してください') from None
            if not isinstance(body, dict):
                raise AppError(400, 'input', '入力を見直してください')
            prompt = body.get('prompt')
            if not isinstance(prompt, str) or not prompt.strip() or len(prompt) > cfg.max_prompt_chars:
                raise AppError(400, 'input', '入力を見直してください')
            if memo:
                response_text = body.get('response')
                if not isinstance(response_text, str) or not response_text.strip() or len(response_text) > 20000:
                    raise AppError(400, 'input', '入力を見直してください')
                result = await run_in_threadpool(cosmos.save, cfg, identity, prompt, response_text,
                                                application.state.cosmos_container)
            else:
                result = await foundry.ask(application.state.foundry_client, cfg, identity.token, cid, prompt)
                result['duration_ms'] = round((time.monotonic() - start) * 1000)
            return JSONResponse({'ok': True, 'correlation_id': cid, **result, 'app_version': cfg.app_version})
        except AppError as exc:
            request.state.layer = exc.layer
            request.state.status_upstream = exc.status_upstream
            return JSONResponse({'ok': False, 'correlation_id': cid, 'layer': exc.layer,
                                 'reason': exc.reason, 'status_upstream': exc.status_upstream,
                                 'message': exc.message}, status_code=exc.status)
        except Exception:
            # 未知の障害でも例外本文や入力をブラウザ・サーバーログへ出さない。
            request.state.layer = 'cosmos_other' if memo else 'foundry_other'
            return JSONResponse({'ok': False, 'correlation_id': cid, 'layer': request.state.layer,
                                 'reason': None, 'status_upstream': None,
                                 'message': '保存先からエラー' if memo else 'Foundry からエラー'}, status_code=502)

    @application.post('/api/ask')
    async def ask(request: Request):
        return await post(request, False)

    @application.post('/api/memo')
    async def memo(request: Request):
        return await post(request, True)

    application.mount('/static', StaticFiles(directory=STATIC), name='static')
    return application


app = create_app()
