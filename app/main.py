import os
from dotenv import load_dotenv
from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from starlette.middleware.sessions import SessionMiddleware

from app.routers.auth import get_current_user
from app.routers import auth

load_dotenv()

app = FastAPI(title="Hệ Thống Quản Lý Nhà Sách", description="Dự án học phần Hệ Quản Trị Cơ Sở Dữ Liệu")

# Cấu hình Secret Key cho SessionMiddleware
SECRET_KEY = os.getenv("SESSION_SECRET_KEY", "bookstore_super_secret_key_dbms_2026")
app.add_middleware(SessionMiddleware, secret_key=SECRET_KEY, max_age=86400)

# Mount thư mục Static files (CSS, JS)
app.mount("/static", StaticFiles(directory="app/static"), name="static")

# Jinja2 Templates
templates = Jinja2Templates(directory="app/templates")

# Đăng ký Router xác thực
app.include_router(auth.router)

@app.get("/", response_class=RedirectResponse)
async def root_redirect(request: Request):
    user = get_current_user(request)
    if user:
        return RedirectResponse(url="/home", status_code=303)
    return RedirectResponse(url="/login", status_code=303)

@app.get("/home", response_class=HTMLResponse)
async def home_dashboard(request: Request):
    user = get_current_user(request)
    if not user:
        return RedirectResponse(url="/login", status_code=303)

    return templates.TemplateResponse("home.html", {
        "request": request,
        "user": user,
        "active_nav": "home",
        "stats": {
            "total_books": 0,
            "total_orders": 0,
            "total_customers": 0,
            "low_stock_count": 0
        },
        "recent_orders": [],
        "low_stock_books": []
    })