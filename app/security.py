import bcrypt
import hashlib
import hmac

def hash_password(raw_password: str) -> str:
    """Băm mật khẩu bằng thuật toán bcrypt với salt tự động sinh ngẫu nhiên."""
    salt = bcrypt.gensalt(rounds=12)
    return bcrypt.hashpw(raw_password.encode("utf-8"), salt).decode("utf-8")

def verify_password(raw_password: str, stored_password: str) -> bool:
    """
    Xác thực mật khẩu người dùng nhập với chuỗi hash trong CSDL.
    Hỗ trợ chuẩn bcrypt ($2a$, $2b$, $2y$) và cơ chế tương thích ngược cho hash cũ (PBKDF2).
    """
    if not stored_password:
        return False
    try:
        # 1. Xác thực bằng chuẩn bcrypt
        if stored_password.startswith(("$2a$", "$2b$", "$2y$")):
            return bcrypt.checkpw(raw_password.encode("utf-8"), stored_password.encode("utf-8"))

        # 2. Cơ chế tương thích ngược (fallback) cho hash cũ PBKDF2 (format: salt$hash)
        if "$" in stored_password:
            salt, original_hash = stored_password.split("$", 1)
            test_hash = hashlib.pbkdf2_hmac(
                "sha256",
                raw_password.encode("utf-8"),
                salt.encode("utf-8"),
                100000
            ).hex()
            return hmac.compare_digest(test_hash, original_hash)

        return False
    except Exception:
        return False
