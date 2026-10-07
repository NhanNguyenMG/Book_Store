import os
from dotenv import load_dotenv
from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from starlette.middleware.sessions import SessionMiddleware

from app.routers.auth import get_current_user
from app.routers import auth, books, orders, customers, employees, genres, publishers, authors, reports
from app.database import execute_query

load_dotenv()

app = FastAPI(title="Hệ Thống Quản Lý Nhà Sách", description="Hệ thống quản lý vận hành và bán hàng nhà sách")

# Cấu hình Secret Key cho SessionMiddleware
SECRET_KEY = os.getenv("SESSION_SECRET_KEY", "bookstore_super_secret_key_dbms_2026")
app.add_middleware(SessionMiddleware, secret_key=SECRET_KEY, max_age=86400)

# Mount thư mục Static files (CSS, JS)
app.mount("/static", StaticFiles(directory="app/static"), name="static")

# Jinja2 Templates
templates = Jinja2Templates(directory="app/templates")

# Đăng ký toàn bộ Router
app.include_router(auth.router)
app.include_router(books.router)
app.include_router(orders.router)
app.include_router(customers.router)
app.include_router(employees.router)
app.include_router(genres.router)
app.include_router(publishers.router)
app.include_router(authors.router)
app.include_router(reports.router)

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

    stats = {
        "total_books": 0,
        "total_orders": 0,
        "total_customers": 0,
        "low_stock_count": 0
    }
    recent_orders = []
    low_stock_books = []

    try:
        role = user.get("Role", "Sales")
        emp_id = user.get("EmployeeID")
        
        b_res = execute_query("SELECT COUNT(*) AS cnt FROM dbo.Book", role=role, employee_id=emp_id)
        if b_res:
            stats["total_books"] = b_res[0].get("cnt", 0)
            
        o_res = execute_query("SELECT COUNT(*) AS cnt FROM dbo.Orders", role=role, employee_id=emp_id)
        if o_res:
            stats["total_orders"] = o_res[0].get("cnt", 0)
            
        c_res = execute_query("SELECT COUNT(*) AS cnt FROM dbo.Customer", role=role, employee_id=emp_id)
        if c_res:
            stats["total_customers"] = c_res[0].get("cnt", 0)
            
        ls_res = execute_query("SELECT COUNT(*) AS cnt FROM dbo.Book WHERE StockQuantity <= 5", role=role, employee_id=emp_id)
        if ls_res:
            stats["low_stock_count"] = ls_res[0].get("cnt", 0)

        recent_orders = execute_query(
            "SELECT TOP 5 OrderID, OrderDate, CustomerName, PaymentMethod, TotalAmount, Status FROM dbo.vw_OrderSummary ORDER BY OrderDate DESC",
            role=role, employee_id=emp_id
        )
        low_stock_books = execute_query(
            "SELECT TOP 5 Title, StockQuantity, Price FROM dbo.Book WHERE StockQuantity <= 5 ORDER BY StockQuantity ASC",
            role=role, employee_id=emp_id
        )
    except Exception as e:
        # Nếu xảy ra lỗi ngoài ý muốn, in ra console để dễ debug
        print(f"[Dashboard Query Error]: {e}")

    return templates.TemplateResponse("home.html", {
        "request": request,
        "user": user,
        "active_nav": "home",
        "stats": stats,
        "recent_orders": recent_orders,
        "low_stock_books": low_stock_books
    })