from fastapi import APIRouter, Request, Form, Depends
from fastapi.responses import HTMLResponse, RedirectResponse, JSONResponse
from fastapi.templating import Jinja2Templates
from app.database import execute_sp, execute_query
from app.routers.auth import require_role, get_current_user

router = APIRouter(prefix="/publishers", tags=["Publishers"])
templates = Jinja2Templates(directory="app/templates")

@router.get("", response_class=HTMLResponse)
async def list_publishers(request: Request):
    user = get_current_user(request)
    if not user:
        return RedirectResponse(url="/login?msg=Vui lòng đăng nhập&msg_type=warning", status_code=303)
    
    role = user.get("Role", "Sales")
    publishers = execute_sp("dbo.sp_Publisher_GetAll", role=role)
    return templates.TemplateResponse("publishers/index.html", {
        "request": request,
        "user": user,
        "active_nav": "catalog",
        "publishers": publishers or [],
        "alert_message": request.query_params.get("msg"),
        "alert_type": request.query_params.get("msg_type", "info")
    })

@router.post("/create")
async def create_publisher_action(
    request: Request,
    publisher_name: str = Form(...),
    address: str = Form(None),
    phone: str = Form(None),
    user=Depends(require_role(["Admin", "Manager", "Inventory"]))
):
    role = user.get("Role")
    try:
        execute_sp("dbo.sp_Publisher_Insert", (publisher_name.strip(), address.strip() if address else None, phone.strip() if phone else None, None), role=role, fetch_result=False)
        return RedirectResponse(url="/publishers?msg=Thêm nhà xuất bản thành công!&msg_type=success", status_code=303)
    except Exception as e:
        return RedirectResponse(url=f"/publishers?msg=Lỗi: {str(e)}&msg_type=danger", status_code=303)

@router.post("/{publisher_id}/edit")
async def edit_publisher_action(
    publisher_id: int,
    request: Request,
    publisher_name: str = Form(...),
    address: str = Form(None),
    phone: str = Form(None),
    user=Depends(require_role(["Admin", "Manager", "Inventory"]))
):
    role = user.get("Role")
    try:
        execute_sp("dbo.sp_Publisher_Update", (publisher_id, publisher_name.strip(), address.strip() if address else None, phone.strip() if phone else None), role=role, fetch_result=False)
        return RedirectResponse(url="/publishers?msg=Cập nhật nhà xuất bản thành công!&msg_type=success", status_code=303)
    except Exception as e:
        return RedirectResponse(url=f"/publishers?msg=Lỗi: {str(e)}&msg_type=danger", status_code=303)

@router.post("/{publisher_id}/delete")
async def delete_publisher_action(
    publisher_id: int,
    request: Request,
    user=Depends(require_role(["Admin", "Manager", "Inventory"]))
):
    role = user.get("Role")
    try:
        execute_sp("dbo.sp_Publisher_Delete", (publisher_id,), role=role, fetch_result=False)
        return RedirectResponse(url="/publishers?msg=Đã xóa nhà xuất bản!&msg_type=success", status_code=303)
    except Exception as e:
        return RedirectResponse(url=f"/publishers?msg=Lỗi xóa NXB: {str(e)}&msg_type=danger", status_code=303)

@router.post("/quick-create")
async def quick_create_publisher(
    request: Request,
    publisher_name: str = Form(...),
    address: str = Form(None),
    phone: str = Form(None),
    user=Depends(require_role(["Admin", "Manager", "Inventory"]))
):
    role = user.get("Role")
    name = publisher_name.strip()
    if not name:
        return JSONResponse({"success": False, "message": "Tên nhà xuất bản không được để trống."}, status_code=400)
    try:
        sql = "DECLARE @id INT; EXEC dbo.sp_Publisher_Insert ?, ?, ?, @id OUTPUT; SELECT @id AS NewID;"
        res = execute_query(sql, (name, address.strip() if address else None, phone.strip() if phone else None), role=role)
        if res and len(res) > 0 and res[0]["NewID"]:
            return JSONResponse({"success": True, "id": res[0]["NewID"], "name": name})
        return JSONResponse({"success": False, "message": "Không thể tạo mới nhà xuất bản."}, status_code=500)
    except Exception as e:
        return JSONResponse({"success": False, "message": str(e)}, status_code=400)
