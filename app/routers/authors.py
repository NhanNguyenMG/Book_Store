from fastapi import APIRouter, Request, Form, Depends
from fastapi.responses import HTMLResponse, RedirectResponse, JSONResponse
from fastapi.templating import Jinja2Templates
from app.database import execute_sp, execute_query
from app.routers.auth import require_role, get_current_user

router = APIRouter(prefix="/authors", tags=["Authors"])
templates = Jinja2Templates(directory="app/templates")

@router.get("", response_class=HTMLResponse)
async def list_authors(request: Request):
    user = get_current_user(request)
    if not user:
        return RedirectResponse(url="/login?msg=Vui lòng đăng nhập&msg_type=warning", status_code=303)
    
    role = user.get("Role", "Sales")
    authors = execute_sp("dbo.sp_Author_GetAll", role=role)
    return templates.TemplateResponse("authors/index.html", {
        "request": request,
        "user": user,
        "active_nav": "catalog",
        "authors": authors or [],
        "alert_message": request.query_params.get("msg"),
        "alert_type": request.query_params.get("msg_type", "info")
    })

@router.post("/create")
async def create_author_action(
    request: Request,
    author_name: str = Form(...),
    yob: int = Form(None),
    nationality: str = Form(None),
    user=Depends(require_role(["Admin", "Manager", "Inventory"]))
):
    role = user.get("Role")
    try:
        execute_sp("dbo.sp_Author_Insert", (author_name.strip(), yob, nationality.strip() if nationality else None, None), role=role, fetch_result=False)
        return RedirectResponse(url="/authors?msg=Thêm tác giả thành công!&msg_type=success", status_code=303)
    except Exception as e:
        return RedirectResponse(url=f"/authors?msg=Lỗi: {str(e)}&msg_type=danger", status_code=303)

@router.post("/{author_id}/edit")
async def edit_author_action(
    author_id: int,
    request: Request,
    author_name: str = Form(...),
    yob: int = Form(None),
    nationality: str = Form(None),
    user=Depends(require_role(["Admin", "Manager", "Inventory"]))
):
    role = user.get("Role")
    try:
        execute_sp("dbo.sp_Author_Update", (author_id, author_name.strip(), yob, nationality.strip() if nationality else None), role=role, fetch_result=False)
        return RedirectResponse(url="/authors?msg=Cập nhật tác giả thành công!&msg_type=success", status_code=303)
    except Exception as e:
        return RedirectResponse(url=f"/authors?msg=Lỗi: {str(e)}&msg_type=danger", status_code=303)

@router.post("/{author_id}/delete")
async def delete_author_action(
    author_id: int,
    request: Request,
    user=Depends(require_role(["Admin", "Manager", "Inventory"]))
):
    role = user.get("Role")
    try:
        execute_sp("dbo.sp_Author_Delete", (author_id,), role=role, fetch_result=False)
        return RedirectResponse(url="/authors?msg=Đã xóa tác giả!&msg_type=success", status_code=303)
    except Exception as e:
        return RedirectResponse(url=f"/authors?msg=Lỗi xóa tác giả: {str(e)}&msg_type=danger", status_code=303)

@router.post("/quick-create")
async def quick_create_author(
    request: Request,
    author_name: str = Form(...),
    yob: int = Form(None),
    nationality: str = Form(None),
    user=Depends(require_role(["Admin", "Manager", "Inventory"]))
):
    role = user.get("Role")
    name = author_name.strip()
    if not name:
        return JSONResponse({"success": False, "message": "Tên tác giả không được để trống."}, status_code=400)
    try:
        sql = "DECLARE @id INT; EXEC dbo.sp_Author_Insert ?, ?, ?, @id OUTPUT; SELECT @id AS NewID;"
        res = execute_query(sql, (name, yob, nationality.strip() if nationality else None), role=role)
        if res and len(res) > 0 and res[0]["NewID"]:
            return JSONResponse({"success": True, "id": res[0]["NewID"], "name": name})
        return JSONResponse({"success": False, "message": "Không thể tạo mới tác giả."}, status_code=500)
    except Exception as e:
        return JSONResponse({"success": False, "message": str(e)}, status_code=400)
