from fastapi import APIRouter, Request, Form, Depends
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from app.database import execute_query, execute_sp
from app.routers.auth import require_role, get_current_user

router = APIRouter(prefix="/customers", tags=["Customers"])
templates = Jinja2Templates(directory="app/templates")

@router.get("", response_class=HTMLResponse)
async def list_customers(request: Request, search: str = None, user=Depends(require_role(["Admin", "Manager", "Sales"]))):
    role = user.get("Role")
    if search and search.strip():
        term = f"%{search.strip()}%"
        customers = execute_query(
            "SELECT CustomerID, CustomerName, Phone, RewardPoints, dbo.fn_GetCustomerTier(CustomerID) AS Tier "
            "FROM dbo.Customer WHERE CustomerName LIKE ? OR Phone LIKE ? ORDER BY CustomerName ASC",
            (term, term),
            role=role
        )
    else:
        customers = execute_sp("dbo.sp_Customer_GetAll", role=role)

    return templates.TemplateResponse("customers/index.html", {
        "request": request,
        "user": user,
        "active_nav": "customers",
        "customers": customers or [],
        "search": search or "",
        "alert_message": request.query_params.get("msg"),
        "alert_type": request.query_params.get("msg_type", "info")
    })

@router.get("/create", response_class=HTMLResponse)
async def create_customer_page(request: Request, user=Depends(require_role(["Admin", "Manager", "Sales"]))):
    return templates.TemplateResponse("customers/form.html", {
        "request": request,
        "user": user,
        "active_nav": "customers",
        "customer": None
    })

@router.post("/create")
async def create_customer_action(
    request: Request,
    customer_name: str = Form(...),
    phone: str = Form(...),
    reward_points: int = Form(0),
    user=Depends(require_role(["Admin", "Manager", "Sales"]))
):
    role = user.get("Role")
    try:
        execute_sp("dbo.sp_Customer_Insert", (customer_name.strip(), phone.strip(), reward_points, None), role=role, fetch_result=False)
        return RedirectResponse(url="/customers?msg=Thêm khách hàng thành công!&msg_type=success", status_code=303)
    except Exception as e:
        return templates.TemplateResponse("customers/form.html", {
            "request": request,
            "user": user,
            "active_nav": "customers",
            "customer": {"CustomerName": customer_name, "Phone": phone, "RewardPoints": reward_points},
            "error": str(e)
        })

@router.get("/{customer_id}", response_class=HTMLResponse)
async def customer_detail(customer_id: int, request: Request, user=Depends(require_role(["Admin", "Manager", "Sales"]))):
    role = user.get("Role")
    cust_list = execute_query(
        "SELECT * FROM dbo.vw_CustomerSummary WHERE CustomerID = ?",
        (customer_id,),
        role=role
    )
    if not cust_list:
        return RedirectResponse(url="/customers?msg=Không tìm thấy khách hàng!&msg_type=danger", status_code=303)

    orders = execute_query(
        "SELECT * FROM dbo.vw_OrderSummary WHERE CustomerID = ? ORDER BY OrderDate DESC",
        (customer_id,),
        role=role
    )

    return templates.TemplateResponse("customers/detail.html", {
        "request": request,
        "user": user,
        "active_nav": "customers",
        "customer": cust_list[0],
        "orders": orders or []
    })

@router.get("/{customer_id}/edit", response_class=HTMLResponse)
async def edit_customer_page(customer_id: int, request: Request, user=Depends(require_role(["Admin", "Manager", "Sales"]))):
    role = user.get("Role")
    cust = execute_sp("dbo.sp_Customer_GetById", (customer_id,), role=role)
    if not cust:
        return RedirectResponse(url="/customers?msg=Không tìm thấy khách hàng!&msg_type=danger", status_code=303)

    return templates.TemplateResponse("customers/form.html", {
        "request": request,
        "user": user,
        "active_nav": "customers",
        "customer": cust[0]
    })

@router.post("/{customer_id}/edit")
async def edit_customer_action(
    customer_id: int,
    request: Request,
    customer_name: str = Form(...),
    phone: str = Form(...),
    user=Depends(require_role(["Admin", "Manager", "Sales"]))
):
    role = user.get("Role")
    try:
        execute_sp("dbo.sp_Customer_Update", (customer_id, customer_name.strip(), phone.strip()), role=role, fetch_result=False)
        return RedirectResponse(url=f"/customers?msg=Cập nhật khách hàng thành công!&msg_type=success", status_code=303)
    except Exception as e:
        return templates.TemplateResponse("customers/form.html", {
            "request": request,
            "user": user,
            "active_nav": "customers",
            "customer": {"CustomerID": customer_id, "CustomerName": customer_name, "Phone": phone},
            "error": str(e)
        })

@router.post("/{customer_id}/delete")
async def delete_customer_action(
    customer_id: int,
    request: Request,
    user=Depends(require_role(["Admin", "Manager"]))
):
    role = user.get("Role")
    try:
        execute_sp("dbo.sp_Customer_Delete", (customer_id,), role=role, fetch_result=False)
        return RedirectResponse(url="/customers?msg=Đã xóa khách hàng!&msg_type=success", status_code=303)
    except Exception as e:
        return RedirectResponse(url=f"/customers?msg=Lỗi xóa khách hàng: {str(e)}&msg_type=danger", status_code=303)
