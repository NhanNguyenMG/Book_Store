from fastapi import APIRouter, Request, Form, Depends
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from app.database import execute_query, execute_sp
from app.routers.auth import require_role, get_current_user

router = APIRouter(prefix="/orders", tags=["Orders"])
templates = Jinja2Templates(directory="app/templates")

@router.get("", response_class=HTMLResponse)
async def list_orders(
    request: Request,
    status_filter: str = None,
    order_id_filter: str = None,
    user=Depends(require_role(["Admin", "Manager", "Sales"]))
):
    role = user.get("Role")
    sql = "SELECT * FROM dbo.vw_OrderSummary WHERE 1=1"
    params = []

    if status_filter and status_filter.strip():
        sql += " AND Status = ?"
        params.append(status_filter.strip())

    oid = None
    if order_id_filter and order_id_filter.strip().isdigit() and int(order_id_filter.strip()) > 0:
        oid = int(order_id_filter.strip())
        sql += " AND OrderID = ?"
        params.append(oid)

    sql += " ORDER BY OrderDate DESC"
    orders = execute_query(sql, tuple(params) if params else None, role=role)

    return templates.TemplateResponse("orders/index.html", {
        "request": request,
        "user": user,
        "active_nav": "orders",
        "orders": orders or [],
        "filters": {
            "status": status_filter or "",
            "order_id": order_id_filter or ""
        },
        "alert_message": request.query_params.get("msg"),
        "alert_type": request.query_params.get("msg_type", "info")
    })

@router.get("/create", response_class=HTMLResponse)
async def create_order_page(request: Request, user=Depends(require_role(["Sales", "Manager"]))):
    role = user.get("Role")
    # Only offer in-stock books for POS
    books = execute_query(
        "SELECT BookID, Title, Price, StockQuantity, GenreName, AuthorName "
        "FROM dbo.vw_BookCatalog WHERE StockQuantity > 0 ORDER BY Title ASC",
        role=role
    )
    customers = execute_query(
        "SELECT CustomerID, CustomerName, Phone, RewardPoints "
        "FROM dbo.Customer ORDER BY CustomerName ASC",
        role=role
    )

    return templates.TemplateResponse("orders/create.html", {
        "request": request,
        "user": user,
        "active_nav": "orders",
        "books": books or [],
        "customers": customers or [],
        "alert_message": request.query_params.get("msg"),
        "alert_type": request.query_params.get("msg_type", "info")
    })

@router.post("/create")
async def create_order_action(
    request: Request,
    customer_id: str = Form(None),
    payment_method: str = Form("Cash"),
    cart_json: str = Form(...),
    user=Depends(require_role(["Sales", "Manager"]))
):
    role = user.get("Role")
    emp_id = user.get("EmployeeID")
    
    cid = int(customer_id) if customer_id and customer_id.isdigit() and int(customer_id) > 0 else None
    pm = payment_method.strip() if payment_method in ["Cash", "Transfer"] else "Cash"

    try:
        result = execute_sp(
            "dbo.sp_CreateOrder",
            (emp_id, cid, pm, cart_json, None),
            role=role,
            employee_id=emp_id,
            fetch_result=True
        )
        new_order_id = result[0]["OrderID"] if result and len(result) > 0 else None
        if new_order_id:
            return RedirectResponse(url=f"/orders/{new_order_id}?msg=Xuất hóa đơn thành công! Tồn kho và điểm tích lũy đã được cập nhật tự động.&msg_type=success", status_code=303)
        return RedirectResponse(url="/orders?msg=Tạo hóa đơn thành công!&msg_type=success", status_code=303)
    except Exception as e:
        books = execute_query(
            "SELECT BookID, Title, Price, StockQuantity, GenreName, AuthorName "
            "FROM dbo.vw_BookCatalog WHERE StockQuantity > 0 ORDER BY Title ASC",
            role=role
        )
        customers = execute_query(
            "SELECT CustomerID, CustomerName, Phone, RewardPoints "
            "FROM dbo.Customer ORDER BY CustomerName ASC",
            role=role
        )
        return templates.TemplateResponse("orders/create.html", {
            "request": request,
            "user": user,
            "active_nav": "orders",
            "books": books or [],
            "customers": customers or [],
            "error": str(e)
        })

@router.get("/{order_id}", response_class=HTMLResponse)
async def order_detail_page(order_id: int, request: Request, user=Depends(require_role(["Admin", "Manager", "Sales"]))):
    role = user.get("Role")
    orders = execute_query(
        "SELECT * FROM dbo.vw_OrderSummary WHERE OrderID = ?",
        (order_id,),
        role=role
    )
    if not orders:
        return RedirectResponse(url="/orders?msg=Không tìm thấy hóa đơn!&msg_type=danger", status_code=303)

    items = execute_query(
        "SELECT od.OrderID, od.BookID, od.Quantity, od.UnitPrice, "
        "(od.Quantity * od.UnitPrice) AS SubTotal, b.Title, g.GenreName, a.AuthorName "
        "FROM dbo.OrderDetails od "
        "INNER JOIN dbo.Book b ON od.BookID = b.BookID "
        "INNER JOIN dbo.Genres g ON b.GenreID = g.GenreID "
        "INNER JOIN dbo.Author a ON b.AuthorID = a.AuthorID "
        "WHERE od.OrderID = ? ORDER BY od.BookID",
        (order_id,),
        role=role
    )

    return templates.TemplateResponse("orders/detail.html", {
        "request": request,
        "user": user,
        "active_nav": "orders",
        "order": orders[0],
        "items": items or [],
        "alert_message": request.query_params.get("msg"),
        "alert_type": request.query_params.get("msg_type", "info")
    })

@router.post("/{order_id}/cancel")
async def cancel_order_action(order_id: int, request: Request, user=Depends(require_role(["Admin", "Manager", "Sales"]))):
    role = user.get("Role")
    emp_id = user.get("EmployeeID")
    try:
        execute_sp("dbo.sp_CancelOrder", (order_id,), role=role, employee_id=emp_id, fetch_result=False)
        return RedirectResponse(url=f"/orders/{order_id}?msg=Đã hủy đơn hàng! Tồn kho sách và điểm thưởng đã được hoàn trả chính xác.&msg_type=warning", status_code=303)
    except Exception as e:
        return RedirectResponse(url=f"/orders/{order_id}?msg=Lỗi hủy đơn: {str(e)}&msg_type=danger", status_code=303)
