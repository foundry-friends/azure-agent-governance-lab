from hashlib import sha256
from datetime import datetime
from uuid import UUID
import pytest
from azure.core.exceptions import ServiceRequestError
from azure.cosmos.exceptions import CosmosHttpResponseError
from .conftest import FakeContainer


def test_document(clients, headers, capsys):
    container = FakeContainer()
    result = clients(container=container).post('/api/memo', headers=headers,
        json={'prompt': 'PRIVATE-PROMPT', 'response': 'PRIVATE-RESPONSE', 'userId': 'untrusted-user'})
    assert result.status_code == 200
    document = container.documents[0]
    derived = sha256(headers['X-MS-CLIENT-PRINCIPAL-ID'].encode()).hexdigest()
    assert document['userId'] == derived
    assert len(derived) == 64
    assert result.json()['user_id_prefix'] == derived[:12]
    assert result.json()['memo_id'] == document['id']
    assert UUID(document['id']).version == 4
    assert datetime.fromisoformat(document['createdAt']).utcoffset().total_seconds() == 0
    assert set(document) == {'id', 'userId', 'createdAt', 'prompt', 'response', 'appVersion'}
    output = capsys.readouterr().out
    for private in ('PRIVATE-PROMPT', 'PRIVATE-RESPONSE', derived, headers['X-MS-CLIENT-PRINCIPAL-ID'], headers['X-MS-TOKEN-AAD-ACCESS-TOKEN']):
        assert private not in output


@pytest.mark.parametrize('upstream,status,layer', [(401, 502, 'cosmos_authz'),
    (403, 502, 'cosmos_authz'), (500, 502, 'cosmos_other'), (None, 504, 'cosmos_network')])
def test_cosmos_errors(clients, headers, upstream, status, layer):
    class Refused:
        def upsert_item(self, document):
            if upstream is None:
                raise ServiceRequestError('PRIVATE-ERROR')
            raise CosmosHttpResponseError(status_code=upstream, message='PRIVATE-ERROR')
    result = clients(container=Refused()).post('/api/memo', headers=headers, json={'prompt': '合成', 'response': '応答'})
    assert result.status_code == status
    assert result.json()['layer'] == layer
    assert 'PRIVATE-ERROR' not in result.text


@pytest.mark.parametrize('body', [{'prompt': '', 'response': '合成'},
    {'prompt': 'x' * 2001, 'response': '合成'}, {'prompt': '合成', 'response': 'x' * 20001},
    {'prompt': '合成', 'response': ''}])
def test_memo_limits(clients, headers, body):
    assert clients().post('/api/memo', headers=headers, json=body).status_code == 400
