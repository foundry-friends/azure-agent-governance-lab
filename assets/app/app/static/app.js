'use strict';
const el = (id) => document.getElementById(id);
let lastExchange = null;
let busy = false;
let leaving = false;
const maxChars = Number(el('prompt').dataset.maxChars);
function updateButtons() {
  el('send').disabled = busy;
  el('save').disabled = busy || !lastExchange;
  el('prompt').disabled = busy;
}
function countInput() {
  const left = maxChars - Array.from(el('prompt').value).length;
  el('remaining').textContent = `残り ${left} 文字`;
}
function showResult(data) {
  el('correlation').textContent = data.correlation_id || '—';
  el('layer').textContent = data.layer || '—';
  el('status').textContent = data.ok ? '処理が完了しました。' : data.message;
}
async function post(path, body, refreshed = false) {
  const response = await fetch(path, {
    method: 'POST', credentials: 'same-origin', cache: 'no-store',
    headers: {'Content-Type': 'application/json', 'X-Requested-With': 'fetch',
      'X-Correlation-Id': crypto.randomUUID()},
    body: JSON.stringify(body)
  });
  // Sec-Fetch-Site はブラウザが付ける禁止リクエストヘッダー。
  if (!(response.headers.get('content-type') || '').includes('application/json')) {
    throw new Error('サインインが切れています。ページを再読み込みしてください');
  }
  const data = await response.json();
  if (leaving) return data;
  if (response.status === 401 && data.reason === 'expired' && !refreshed) {
    showResult(data);
    el('status').textContent = '再認証が必要です。認証を更新しています。';
    const refresh = await fetch('/.auth/refresh', {credentials: 'same-origin', cache: 'no-store'});
    if (!refresh.ok || refresh.redirected) {
      throw new Error('サインインが切れています。ページを再読み込みしてください');
    }
    if (!leaving) return post(path, body, true);
  }
  return data;
}
el('prompt').addEventListener('input', countInput);
el('ask-form').addEventListener('submit', async (event) => {
  event.preventDefault();
  if (busy || leaving) return;
  const prompt = el('prompt').value;
  if (!prompt.trim() || Array.from(prompt).length > maxChars) {
    el('status').textContent = '入力を見直してください';
    return;
  }
  busy = true;
  lastExchange = null;
  el('response').textContent = '';
  el('memo-result').textContent = '';
  el('correlation').textContent = '—';
  el('layer').textContent = '—';
  el('status').textContent = '応答を待っています。';
  updateButtons();
  try {
    const data = await post('/api/ask', {prompt});
    if (leaving) return;
    showResult(data);
    if (data.ok) {
      el('response').textContent = data.text;
      if (data.text) lastExchange = {prompt, response: data.text};
      if (data.note === 'no_output_text') el('status').textContent = '応答本文なし（初回は応答形式を照合してください）。';
    }
  } catch (error) {
    if (!leaving) el('status').textContent = error instanceof TypeError ? '通信に失敗しました。接続を確認してください。' : error.message;
  } finally {
    busy = false;
    updateButtons();
  }
});
el('save').addEventListener('click', async () => {
  if (busy || !lastExchange || leaving) return;
  busy = true;
  updateButtons();
  el('memo-result').textContent = '';
  try {
    const data = await post('/api/memo', lastExchange);
    if (leaving) return;
    showResult(data);
    if (data.ok) {
      el('memo-result').textContent = `保存しました。userId の先頭 12 文字: ${data.user_id_prefix} ／ メモ ID: ${data.memo_id}`;
    }
  } catch (error) {
    if (!leaving) el('status').textContent = error instanceof TypeError ? '通信に失敗しました。接続を確認してください。' : error.message;
  } finally {
    busy = false;
    updateButtons();
  }
});
el('logout').addEventListener('click', () => {
  leaving = true;
  lastExchange = null;
  el('prompt').value = '';
  for (const id of ['response', 'status', 'memo-result', 'correlation', 'layer']) el(id).textContent = '';
  countInput();
});
countInput();
