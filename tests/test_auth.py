
from fastapi.testclient import TestClient

from app.main import app
from app.routers import auth
from app.security import hash_password


def test_login_page_returns_success():
    """Trang đăng nhập phải hiển thị thành công."""
    with TestClient(app) as client:
        response = client.get("/login", follow_redirects=False)

    assert response.status_code == 200
    assert "Đăng Nhập".encode() in response.content


def test_login_rejects_unknown_user(monkeypatch):
    """Tài khoản không tồn tại phải bị từ chối."""
    monkeypatch.setattr(
        auth,
        "execute_sp",
        lambda *args, **kwargs: []
    )

    with TestClient(app) as client:
        response = client.post(
            "/login",
            data={
                "username": "unknown_user",
                "password": "WrongPassword123"
            },
            follow_redirects=False
        )

    assert response.status_code == 200
    assert "không chính xác" in response.text


def test_login_rejects_wrong_password(monkeypatch):
    """Mật khẩu sai phải bị từ chối."""
    monkeypatch.setattr(
        auth,
        "execute_sp",
        lambda *args, **kwargs: [{
            "EmployeeID": 1,
            "FullName": "Test User",
            "Username": "test_user",
            "Role": "Sales",
            "Password": hash_password("CorrectPassword123")
        }]
    )

    with TestClient(app) as client:
        response = client.post(
            "/login",
            data={
                "username": "test_user",
                "password": "WrongPassword123"
            },
            follow_redirects=False
        )

    assert response.status_code == 200
    assert "không chính xác" in response.text


def test_login_success_creates_session(monkeypatch):
    """Đăng nhập hợp lệ phải chuyển đến trang chủ."""
    monkeypatch.setattr(
        auth,
        "execute_sp",
        lambda *args, **kwargs: [{
            "EmployeeID": 1,
            "FullName": "Test User",
            "Username": "test_user",
            "Role": "Sales",
            "Password": hash_password("CorrectPassword123")
        }]
    )

    with TestClient(app) as client:
        response = client.post(
            "/login",
            data={
                "username": "test_user",
                "password": "CorrectPassword123"
            },
            follow_redirects=False
        )

        assert response.status_code == 303
        assert response.headers["location"] == "/home"

        home_response = client.get(
            "/home",
            follow_redirects=False
        )

    assert home_response.status_code == 200


def test_logout_clears_session():
    """Đăng xuất phải xóa session và yêu cầu đăng nhập lại."""
    with TestClient(app) as client:
        client.cookies.set(
            "session",
            ""
        )

        response = client.get(
            "/logout",
            follow_redirects=False
        )

        home_response = client.get(
            "/home",
            follow_redirects=False
        )

    assert response.status_code == 303
    assert response.headers["location"].startswith("/login")
    assert home_response.status_code == 303
    assert home_response.headers["location"] == "/login"
