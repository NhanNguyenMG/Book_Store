from fastapi import APIRouter, Request, Form, HTTPException, status
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from app.database import execute_sp
from app.security import verify_password

router = APIRouter()
templates = Jinja2Templates(directory="app/templates")

def get_current_user(request: Request) -> dict | None:
    return request.session.get("user")

from urllib.parse import quote

def require_role(roles: list[str]):
    def dependency(request: Request):
        user = get_current_user(request)
        if not user:
            msg = quote("Vui lòng đăng nhập để tiếp tục")
            raise HTTPException(
                status_code=status.HTTP_303_SEE_OTHER,
                headers={"Location": f"/login?msg={msg}&msg_type=warning"}
            )
        if user.get("Role") not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Bạn không có quyền truy cập vào chức năng này."
            )
        return user
    return dependency

@router.get("/login", response_class=HTMLResponse)
async def login_page(request: Request):
    user = get_current_user(request)
    if user:
        return RedirectResponse(url="/home", status_code=303)
    
    alert_message = request.query_params.get("msg")
    alert_type = request.query_params.get("msg_type", "info")
    return templates.TemplateResponse("login.html", {
        "request": request,
        "user": None,
        "alert_message": alert_message,
        "alert_type": alert_type
    })

@router.post("/login", response_class=HTMLResponse)
async def login_action(
    request: Request,
    username: str = Form(...),
    password: str = Form(...)
):
    try:
        user_rows = execute_sp("dbo.sp_Login", (username.strip(),), role="AUTH")
        if not user_rows or len(user_rows) == 0:
            return templates.TemplateResponse("login.html", {
                "request": request,
                "user": None,
                "error": "Tên đăng nhập hoặc mật khẩu không chính xác."
            })

        user_data = user_rows[0]
        stored_hash = user_data.get("Password")

        if not verify_password(password, stored_hash):
            return templates.TemplateResponse("login.html", {
                "request": request,
                "user": None,
                "error": "Tên đăng nhập hoặc mật khẩu không chính xác."
            })

        request.session["user"] = {
            "EmployeeID": user_data["EmployeeID"],
            "FullName": user_data["FullName"],
            "Username": user_data["Username"],
            "Role": user_data["Role"]
        }
        return RedirectResponse(url="/home", status_code=303)

    except Exception as e:
        return templates.TemplateResponse("login.html", {
            "request": request,
            "user": None,
            "error": f"Lỗi hệ thống: {str(e)}"
        })

@router.get("/logout")
async def logout_action(request: Request):
    request.session.clear()
    return RedirectResponse(url="/login?msg=Đã đăng xuất thành công&msg_type=success", status_code=303)
