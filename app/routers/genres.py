from fastapi import APIRouter, Request, Form, Depends
from fastapi.responses import HTMLResponse, RedirectResponse, JSONResponse
from fastapi.templating import Jinja2Templates
from app.database import execute_sp, execute_query
from app.routers.auth import require_role, get_current_user

router = APIRouter(prefix="/genres", tags=["Genres"])
templates = Jinja2Templates(directory="app/templates")

@router.get("", response_class=HTMLResponse)
async def list_genres(request: Request):
    user = get_current_user(request)
    if not user:
        return RedirectResponse(url="/login?msg=Vui lòng đăng nhập&msg_type=warning", status_code=303)
    
    role = user.get("Role", "Sales")
    genres = execute_sp("dbo.sp_Genres_GetAll", role=role)
    return templates.TemplateResponse("genres/index.html", {
        "request": request,
        "user": user,
        "active_nav": "catalog",
        "genres": genres or [],
        "alert_message": request.query_params.get("msg"),
        "alert_type": request.query_params.get("msg_type", "info")
    })

@router.post("/create")
async def create_genre_action(
    request: Request,
    genre_name: str = Form(...),
    user=Depends(require_role(["Admin", "Manager", "Inventory"]))
):
    role = user.get("Role")
    try:
        execute_sp("dbo.sp_Genres_Insert", (genre_name.strip(), None), role=role, fetch_result=False)
        return RedirectResponse(url="/genres?msg=Thêm thể loại thành công!&msg_type=success", status_code=303)
    except Exception as e:
        return RedirectResponse(url=f"/genres?msg=Lỗi: {str(e)}&msg_type=danger", status_code=303)

@router.post("/{genre_id}/edit")
async def edit_genre_action(
    genre_id: int,
    request: Request,
    genre_name: str = Form(...),
    user=Depends(require_role(["Admin", "Manager", "Inventory"]))
):
    role = user.get("Role")
    try:
        execute_sp("dbo.sp_Genres_Update", (genre_id, genre_name.strip()), role=role, fetch_result=False)
        return RedirectResponse(url="/genres?msg=Cập nhật thể loại thành công!&msg_type=success", status_code=303)
    except Exception as e:
        return RedirectResponse(url=f"/genres?msg=Lỗi: {str(e)}&msg_type=danger", status_code=303)

@router.post("/{genre_id}/delete")
async def delete_genre_action(
    genre_id: int,
    request: Request,
    user=Depends(require_role(["Admin", "Manager", "Inventory"]))
):
    role = user.get("Role")
    try:
        execute_sp("dbo.sp_Genres_Delete", (genre_id,), role=role, fetch_result=False)
        return RedirectResponse(url="/genres?msg=Đã xóa thể loại!&msg_type=success", status_code=303)
    except Exception as e:
        return RedirectResponse(url=f"/genres?msg=Lỗi xóa thể loại: {str(e)}&msg_type=danger", status_code=303)

@router.post("/quick-create")
async def quick_create_genre(
    request: Request,
    genre_name: str = Form(...),
    user=Depends(require_role(["Admin", "Manager", "Inventory"]))
):
    role = user.get("Role")
    name = genre_name.strip()
    if not name:
        return JSONResponse({"success": False, "message": "Tên thể loại không được để trống."}, status_code=400)
    try:
        sql = "DECLARE @id INT; EXEC dbo.sp_Genres_Insert ?, @id OUTPUT; SELECT @id AS NewID;"
        res = execute_query(sql, (name,), role=role)
        if res and len(res) > 0 and res[0]["NewID"]:
            return JSONResponse({"success": True, "id": res[0]["NewID"], "name": name})
        return JSONResponse({"success": False, "message": "Không thể tạo mới thể loại."}, status_code=500)
    except Exception as e:
        return JSONResponse({"success": False, "message": str(e)}, status_code=400)
