from datetime import datetime, timezone
from typing import Any

from google.cloud.firestore import SERVER_TIMESTAMP
from google.api_core.exceptions import AlreadyExists


def _resolve(value: Any) -> Any:
    if value is SERVER_TIMESTAMP:
        return datetime.now(timezone.utc)
    return value


class FakeSnapshot:
    def __init__(self, data: Any, doc_id: str = ""):
        self._data = data
        self.id = doc_id

    @property
    def exists(self) -> bool:
        return self._data is not None

    def to_dict(self) -> dict[str, Any]:
        return dict(self._data) if self._data else {}


class FakeDocumentRef:
    def __init__(self, store: dict[str, Any], path: list[str]):
        self._store = store
        self._path = path

    @property
    def _key(self) -> str:
        return "/".join(self._path)

    def collection(self, name: str) -> "FakeCollectionRef":
        return FakeCollectionRef(self._store, self._path + [name])

    def get(self) -> FakeSnapshot:
        return FakeSnapshot(self._store.get(self._key), self._path[-1])

    def set(self, payload: dict[str, Any], merge: bool = False) -> None:
        resolved = {key: _resolve(value) for key, value in payload.items()}
        if merge:
            current = dict(self._store.get(self._key) or {})
            current.update(resolved)
            self._store[self._key] = current
        else:
            self._store[self._key] = resolved

    def create(self, payload: dict[str, Any]) -> None:
        if self._key in self._store:
            raise AlreadyExists("Document already exists.")
        self.set(payload)

    def update(self, payload: dict[str, Any]) -> None:
        current = dict(self._store.get(self._key) or {})
        current.update({key: _resolve(value) for key, value in payload.items()})
        self._store[self._key] = current

    def delete(self) -> None:
        self._store.pop(self._key, None)


class FakeCollectionRef:
    def __init__(self, store: dict[str, Any], path: list[str]):
        self._store = store
        self._path = path

    def document(self, name: str) -> FakeDocumentRef:
        return FakeDocumentRef(self._store, self._path + [name])

    def where(
        self,
        field: str | None = None,
        op: str | None = None,
        value: Any = None,
        **kwargs: Any,
    ) -> "FakeCollectionRef":
        if isinstance(field, str):
            return _FilteredCollectionRef(self._store, self._path, field, value)
        return _FilteredCollectionRef(self._store, self._path, None, None)

    def limit(self, count: int) -> "FakeCollectionRef":
        return self

    def order_by(self, field: str, direction: Any = None) -> "FakeCollectionRef":
        return self

    def get(self) -> list[FakeSnapshot]:
        prefix = "/".join(self._path) + "/"
        results: list[FakeSnapshot] = []
        for key, value in self._store.items():
            if not key.startswith(prefix) or not isinstance(value, dict):
                continue
            results.append(FakeSnapshot(value, key[len(prefix):]))
        return results


class _FilteredCollectionRef(FakeCollectionRef):
    def __init__(
        self,
        store: dict[str, Any],
        path: list[str],
        field: str | None,
        expected: Any,
    ):
        super().__init__(store, path)
        self._field = field
        self._expected = expected

    def get(self) -> list[FakeSnapshot]:
        prefix = "/".join(self._path) + "/"
        results: list[FakeSnapshot] = []
        for key, value in self._store.items():
            if not key.startswith(prefix) or not isinstance(value, dict):
                continue
            if self._field and value.get(self._field) != self._expected:
                continue
            results.append(FakeSnapshot(value, key[len(prefix):]))
        return results


class FakeFirestore:
    def __init__(self) -> None:
        self.store: dict[str, Any] = {}

    def collection(self, name: str) -> FakeCollectionRef:
        return FakeCollectionRef(self.store, [name])

    def document(self, name: str) -> FakeDocumentRef:
        return FakeDocumentRef(self.store, [name])

    def seed(self, path: str, payload: dict[str, Any]) -> None:
        self.store[path] = dict(payload)
