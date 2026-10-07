from fastapi import APIRouter, Request, Form, Depends
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from app.database import execute_sp
from app.security import hash_password
from app.routers.auth import require_role, get_current_user

router = APIRouter(prefix="/employees", tags=["Employees"])
templates = Jinja2Templates(directory="app/templates")

@router.get("", response_class=HTMLResponse)
async def list_employees(request: Request, user=Depends(require_role(["Admin", "Manager"]))):
    role = user.get("Role")
    employees = execute_sp("dbo.sp_Employee_GetAll", role=role)
    return templates.TemplateResponse("employees/index.html", {
        "request": request,
        "user": user,
        "active_nav": "employees",
        "employees": employees or [],
        "alert_message": request.query_params.get("msg"),
        "alert_type": request.query_params.get("msg_type", "info")
    })

@router.get("/create", response_class=HTMLResponse)
async def create_employee_page(request: Request, user=Depends(require_role(["Admin"]))):
    return templates.TemplateResponse("employees/form.html", {
        "request": request,
        "user": user,
        "active_nav": "employees",
        "employee": None,
        "roles": ["Admin", "Manager", "Sales", "Inventory"]
    })

@router.post("/create")
async def create_employee_action(
    request: Request,
    full_name: str = Form(...),
    username: str = Form(...),
    password: str = Form(...),
    role_name: str = Form(...),
    user=Depends(require_role(["Admin"]))
):
    role = user.get("Role")
    emp_id = user.get("EmployeeID")
    try:
        hashed_pwd = hash_password(password.strip())
        execute_sp(
            "dbo.sp_Employee_Insert",
            (full_name.strip(), role_name.strip(), username.strip(), hashed_pwd, None),
            role=role,
            employee_id=emp_id,
            fetch_result=False
        )
        return RedirectResponse(url="/employees?msg=Thêm nhân viên mới thành công!&msg_type=success", status_code=303)
    except Exception as e:
        return templates.TemplateResponse("employees/form.html", {
            "request": request,
            "user": user,
            "active_nav": "employees",
            "employee": {"FullName": full_name, "Username": username, "Role": role_name},
            "roles": ["Admin", "Manager", "Sales", "Inventory"],
            "error": str(e)
        })

@router.get("/{employee_id}/edit", response_class=HTMLResponse)
async def edit_employee_page(employee_id: int, request: Request, user=Depends(require_role(["Admin"]))):
    role = user.get("Role")
    emp_list = execute_sp("dbo.sp_Employee_GetById", (employee_id,), role=role)
    if not emp_list:
        return RedirectResponse(url="/employees?msg=Không tìm thấy nhân viên!&msg_type=danger", status_code=303)

    return templates.TemplateResponse("employees/form.html", {
        "request": request,
        "user": user,
        "active_nav": "employees",
        "employee": emp_list[0],
        "roles": ["Admin", "Manager", "Sales", "Inventory"]
    })

@router.post("/{employee_id}/edit")
async def edit_employee_action(
    employee_id: int,
    request: Request,
    full_name: str = Form(...),
    role_name: str = Form(...),
    password: str = Form(None),
    user=Depends(require_role(["Admin"]))
):
    role = user.get("Role")
    emp_id = user.get("EmployeeID")
    try:
        hashed_pwd = hash_password(password.strip()) if password and password.strip() else None
        execute_sp(
            "dbo.sp_Employee_Update",
            (employee_id, full_name.strip(), role_name.strip(), hashed_pwd),
            role=role,
            employee_id=emp_id,
            fetch_result=False
        )
        return RedirectResponse(url="/employees?msg=Cập nhật nhân viên thành công!&msg_type=success", status_code=303)
    except Exception as e:
        return templates.TemplateResponse("employees/form.html", {
            "request": request,
            "user": user,
            "active_nav": "employees",
            "employee": {"EmployeeID": employee_id, "FullName": full_name, "Role": role_name},
            "roles": ["Admin", "Manager", "Sales", "Inventory"],
            "error": str(e)
        })

@router.post("/{employee_id}/delete")
async def delete_employee_action(
    employee_id: int,
    request: Request,
    user=Depends(require_role(["Admin"]))
):
    role = user.get("Role")
    emp_id = user.get("EmployeeID")
    try:
        execute_sp("dbo.sp_Employee_Delete", (employee_id,), role=role, employee_id=emp_id, fetch_result=False)
        return RedirectResponse(url="/employees?msg=Đã xóa nhân viên!&msg_type=success", status_code=303)
    except Exception as e:
        return RedirectResponse(url=f"/employees?msg=Lỗi xóa nhân viên: {str(e)}&msg_type=danger", status_code=303)
