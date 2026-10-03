import hashlib
import hmac
import os

ITERATIONS = 100000

def hash_password(raw_password: str) -> str:
    salt = os.urandom(16).hex()
    dk = hashlib.pbkdf2_hmac(
        'sha256',
        raw_password.encode('utf-8'),
        salt.encode('utf-8'),
        ITERATIONS
    ).hex()
    return f"{salt}${dk}"

def verify_password(raw_password: str, stored_password: str) -> bool:
    if not stored_password or '$' not in stored_password:
        return False
    try:
        salt, original_hash = stored_password.split('$', 1)
        test_hash = hashlib.pbkdf2_hmac(
            'sha256',
            raw_password.encode('utf-8'),
            salt.encode('utf-8'),
            ITERATIONS
        ).hex()
        return hmac.compare_digest(test_hash, original_hash)
    except Exception:
        return False
