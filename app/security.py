import bcrypt

def hash_password(raw_password: str) -> str:
    pwd_bytes = raw_password.encode("utf-8")
    if len(pwd_bytes) > 72:
        raise ValueError("Mật khẩu không được vượt quá 72 bytes.")
    salt = bcrypt.gensalt(rounds=12)
    return bcrypt.hashpw(pwd_bytes, salt).decode("utf-8")

def verify_password(raw_password: str, stored_password: str) -> bool:
    if not stored_password:
        return False
    try:
        if not stored_password.startswith(("$2a$", "$2b$", "$2y$")):
            return False
        return bcrypt.checkpw(raw_password.encode("utf-8"), stored_password.encode("utf-8"))
    except Exception:
        return False
