import os
import re
import pyodbc
from dotenv import load_dotenv

load_dotenv()

DB_SERVER = os.getenv("DB_SERVER", r".\SQLEXPRESS")
DB_NAME = os.getenv("DB_NAME", "BookStore")
DB_DRIVER = os.getenv("DB_DRIVER", "ODBC Driver 18 for SQL Server")
DB_TRUST_SERVER_CERT = os.getenv("DB_TRUST_SERVER_CERT", "yes")
DB_AUTH_MODE = os.getenv("DB_AUTH_MODE", "WINDOWS_AUTH").upper()

CREDENTIALS = {
    "ADMIN": (os.getenv("DB_USER_ADMIN", "login_admin"), os.getenv("DB_PASS_ADMIN", "BookStore@Admin123")),
    "MANAGER": (os.getenv("DB_USER_MANAGER", "login_manager"), os.getenv("DB_PASS_MANAGER", "BookStore@Manager123")),
    "SALES": (os.getenv("DB_USER_SALES", "login_sales"), os.getenv("DB_PASS_SALES", "BookStore@Sales123")),
    "INVENTORY": (os.getenv("DB_USER_INVENTORY", "login_inventory"), os.getenv("DB_PASS_INVENTORY", "BookStore@Inventory123")),
    "AUTH": (os.getenv("DB_USER_AUTH", "login_auth"), os.getenv("DB_PASS_AUTH", "BookStore@Auth123")),
}

def clean_error_message(err: Exception) -> str:
    msg = str(err)
    clean = re.sub(r'\[Microsoft\]\[ODBC Driver \d+ for SQL Server\]\[SQL Server\]', '', msg)
    clean = re.sub(r'\(\d+\)\s*\(SQLExecDirectW\)', '', clean)
    clean = re.sub(r'\(\d+\)\s*\(SQLDriverConnect\)', '', clean)
    clean = clean.strip(" ()'\"")
    return clean if clean else "Đã xảy ra lỗi khi xử lý cơ sở dữ liệu."

def get_connection_string(role: str = "AUTH") -> str:
    role_key = role.upper() if role else "AUTH"
    if DB_AUTH_MODE == "SQL_LOGIN":
        uid, pwd = CREDENTIALS.get(role_key, CREDENTIALS["AUTH"])
        return (
            f"DRIVER={{{DB_DRIVER}}};"
            f"SERVER={DB_SERVER};"
            f"DATABASE={DB_NAME};"
            f"UID={uid};"
            f"PWD={pwd};"
            f"TrustServerCertificate={DB_TRUST_SERVER_CERT};"
        )
    return (
        f"DRIVER={{{DB_DRIVER}}};"
        f"SERVER={DB_SERVER};"
        f"DATABASE={DB_NAME};"
        f"Trusted_Connection=yes;"
        f"TrustServerCertificate={DB_TRUST_SERVER_CERT};"
    )

def get_connection(role: str = "AUTH", employee_id: int = None):
    conn_str = get_connection_string(role)
    conn = pyodbc.connect(conn_str)
    if employee_id is not None:
        try:
            cursor = conn.cursor()
            cursor.execute("EXEC sp_set_session_context @key=N'EmployeeID', @value=?", employee_id)
            cursor.close()
        except Exception:
            pass
    return conn

def execute_query(sql: str, params: tuple = None, role: str = "AUTH", employee_id: int = None) -> list[dict]:
    conn = get_connection(role, employee_id)
    try:
        cursor = conn.cursor()
        if params:
            cursor.execute(sql, params)
        else:
            cursor.execute(sql)
        if cursor.description:
            columns = [column[0] for column in cursor.description]
            results = [dict(zip(columns, row)) for row in cursor.fetchall()]
        else:
            results = []
        conn.commit()
        return results
    except Exception as e:
        conn.rollback()
        raise
    finally:
        conn.close()

def execute_one(sql: str, params: tuple = None, role: str = "AUTH", employee_id: int = None) -> dict | None:
    results = execute_query(sql, params, role, employee_id)
    return results[0] if results else None

def execute_sp(sp_name: str, params: tuple = None, role: str = "AUTH", employee_id: int = None, fetch_result: bool = True):
    conn = get_connection(role, employee_id)
    try:
        cursor = conn.cursor()
        param_placeholders = ""
        if params:
            param_placeholders = " " + ", ".join(["?"] * len(params))
        call_sql = f"EXEC {sp_name}{param_placeholders}"
        
        if params:
            cursor.execute(call_sql, params)
        else:
            cursor.execute(call_sql)
        
        results = None
        if fetch_result:
            try:
                if cursor.description:
                    columns = [column[0] for column in cursor.description]
                    results = [dict(zip(columns, row)) for row in cursor.fetchall()]
            except pyodbc.ProgrammingError:
                results = None
                
        conn.commit()
        return results
    except pyodbc.Error as e:
        conn.rollback()
        raise ValueError(clean_error_message(e))
    finally:
        conn.close()
