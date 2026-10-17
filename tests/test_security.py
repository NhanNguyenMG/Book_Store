
import pytest

from app.security import hash_password, verify_password


def test_hash_password_creates_hash():
    """Mật khẩu sau khi băm không được lưu dưới dạng văn bản gốc."""
    password = "TestPassword123"

    hashed_password = hash_password(password)

    assert hashed_password != password
    assert "$" in hashed_password


def test_verify_password_with_correct_password():
    """Mật khẩu chính xác phải được xác nhận."""
    password = "TestPassword123"
    hashed_password = hash_password(password)

    assert verify_password(password, hashed_password) is True


def test_verify_password_with_wrong_password():
    """Mật khẩu sai phải bị từ chối."""
    hashed_password = hash_password("TestPassword123")

    assert verify_password("WrongPassword123", hashed_password) is False


def test_hash_password_uses_different_salts():
    """Cùng mật khẩu nhưng mỗi lần băm phải có salt khác nhau."""
    password = "TestPassword123"

    first_hash = hash_password(password)
    second_hash = hash_password(password)

    assert first_hash != second_hash
    assert verify_password(password, first_hash) is True
    assert verify_password(password, second_hash) is True


@pytest.mark.parametrize(
    "invalid_hash",
    [
        "",
        None,
        "invalid-format",
        "salt$",
        "$invalid-hash",
    ],
)
def test_verify_password_rejects_invalid_hash(invalid_hash):
    """Dữ liệu hash không hợp lệ phải bị từ chối an toàn."""
    assert verify_password("TestPassword123", invalid_hash) is False
