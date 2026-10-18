
from fastapi.testclient import TestClient

from app.main import app
from app.routers import books


client = TestClient(app)


def mock_database(monkeypatch, ket_qua_sach=None):
    """Giả lập các truy vấn database cho router books."""
    if ket_qua_sach is None:
        ket_qua_sach = []

    monkeypatch.setattr(
        books,
        "execute_sp",
        lambda *args, **kwargs: ket_qua_sach,
    )

    def gia_lap_truy_van(sql, *args, **kwargs):
        if "Genres" in sql:
            return []
        if "Author" in sql:
            return []
        return []

    monkeypatch.setattr(books, "execute_query", gia_lap_truy_van)


def test_list_books_redirects_when_not_logged_in(monkeypatch):
    monkeypatch.setattr(books, "get_current_user", lambda request: None)

    response = client.get("/books", follow_redirects=False)

    assert response.status_code == 303
    assert response.headers["location"].startswith("/login")


def test_list_books_returns_success_when_logged_in(monkeypatch):
    monkeypatch.setattr(
        books,
        "get_current_user",
        lambda request: {"Role": "Sales", "EmployeeID": 1},
    )
    mock_database(monkeypatch)

    response = client.get("/books")

    assert response.status_code == 200


def test_list_books_passes_clean_filters_to_stored_procedure(monkeypatch):
    monkeypatch.setattr(
        books,
        "get_current_user",
        lambda request: {"Role": "Sales", "EmployeeID": 1},
    )

    tham_so_da_goi = {}

    def gia_lap_stored_procedure(sql, params=None, **kwargs):
        tham_so_da_goi["sql"] = sql
        tham_so_da_goi["params"] = params
        tham_so_da_goi["kwargs"] = kwargs
        return []

    monkeypatch.setattr(books, "execute_sp", gia_lap_stored_procedure)
    monkeypatch.setattr(books, "execute_query", lambda *args, **kwargs: [])

    response = client.get(
        "/books",
        params={
            "keyword": "  python  ",
            "genre_id": "2",
            "author_id": "3",
            "min_price": "abc",
            "max_price": "-5",
            "in_stock_only": "true",
        },
    )

    assert response.status_code == 200
    assert tham_so_da_goi["sql"] == "dbo.sp_SearchBooks"
    assert tham_so_da_goi["params"] == (
        "python", 2, 3, None, None, 1
    )
    assert tham_so_da_goi["kwargs"]["role"] == "Sales"


def test_list_books_ignores_invalid_filter_values(monkeypatch):
    monkeypatch.setattr(
        books,
        "get_current_user",
        lambda request: {"Role": "Sales", "EmployeeID": 1},
    )

    tham_so_da_goi = {}

    def gia_lap_stored_procedure(sql, params=None, **kwargs):
        tham_so_da_goi["params"] = params
        return []

    monkeypatch.setattr(books, "execute_sp", gia_lap_stored_procedure)
    monkeypatch.setattr(books, "execute_query", lambda *args, **kwargs: [])

    response = client.get(
        "/books",
        params={
            "genre_id": "-1",
            "author_id": "abc",
            "min_price": "-100",
            "max_price": "khong-phai-so",
        },
    )

    assert response.status_code == 200
    assert tham_so_da_goi["params"] == (
        None, None, None, None, None, 0
    )
