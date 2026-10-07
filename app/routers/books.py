from fastapi import APIRouter, Request, Form, Depends, HTTPException
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from app.database import execute_query, execute_sp
from app.routers.auth import require_role, get_current_user

router = APIRouter(prefix="/books", tags=["Books"])
templates = Jinja2Templates(directory="app/templates")

@router.get("", response_class=HTMLResponse)
async def list_books(
    request: Request,
    keyword: str = None,
    genre_id: str = None,
    author_id: str = None,
    min_price: str = None,
    max_price: str = None,
    in_stock_only: bool = False
):
    user = get_current_user(request)
    if not user:
        return RedirectResponse(url="/login?msg=Vui lòng đăng nhập&msg_type=warning", status_code=303)

    role = user.get("Role", "Sales")
    
    # Clean empty strings and parse numbers safely
    kw = keyword.strip() if keyword and keyword.strip() else None
    
    gid = None
    if genre_id and genre_id.strip().isdigit() and int(genre_id.strip()) > 0:
        gid = int(genre_id.strip())

    aid = None
    if author_id and author_id.strip().isdigit() and int(author_id.strip()) > 0:
        aid = int(author_id.strip())

    min_p = None
    if min_price and min_price.strip():
        try:
            val = float(min_price.strip())
            if val >= 0:
                min_p = val
        except ValueError:
            pass

    max_p = None
    if max_price and max_price.strip():
        try:
            val = float(max_price.strip())
            if val >= 0:
                max_p = val
        except ValueError:
            pass

    stock_flag = 1 if in_stock_only else 0

    books = execute_sp(
        "dbo.sp_SearchBooks",
        (kw, gid, aid, min_p, max_p, stock_flag),
        role=role
    )

    genres = execute_query("SELECT GenreID, GenreName FROM dbo.Genres ORDER BY GenreName", role=role)
    authors = execute_query("SELECT AuthorID, AuthorName FROM dbo.Author ORDER BY AuthorName", role=role)

    return templates.TemplateResponse("books/index.html", {
        "request": request,
        "user": user,
        "active_nav": "books",
        "books": books or [],
        "genres": genres or [],
        "authors": authors or [],
        "filters": {
            "keyword": keyword or "",
            "genre_id": genre_id,
            "author_id": author_id,
            "min_price": min_price,
            "max_price": max_price,
            "in_stock_only": in_stock_only
        },
        "alert_message": request.query_params.get("msg"),
        "alert_type": request.query_params.get("msg_type", "info")
    })

@router.get("/create", response_class=HTMLResponse)
async def create_book_page(request: Request, user=Depends(require_role(["Admin", "Manager", "Inventory"]))):
    role = user.get("Role")
    genres = execute_query("SELECT GenreID, GenreName FROM dbo.Genres ORDER BY GenreName", role=role)
    authors = execute_query("SELECT AuthorID, AuthorName FROM dbo.Author ORDER BY AuthorName", role=role)
    publishers = execute_query("SELECT PublisherID, PublisherName FROM dbo.Publisher ORDER BY PublisherName", role=role)

    return templates.TemplateResponse("books/form.html", {
        "request": request,
        "user": user,
        "active_nav": "books",
        "book": None,
        "genres": genres,
        "authors": authors,
        "publishers": publishers
    })

@router.post("/create")
async def create_book_action(
    request: Request,
    title: str = Form(...),
    genre_id: int = Form(...),
    author_id: int = Form(...),
    publisher_id: int = Form(...),
    price: float = Form(...),
    stock_quantity: int = Form(0),
    user=Depends(require_role(["Admin", "Manager", "Inventory"]))
):
    role = user.get("Role")
    emp_id = user.get("EmployeeID")
    try:
        execute_sp(
            "dbo.sp_Book_Insert",
            (title.strip(), genre_id, author_id, publisher_id, price, stock_quantity, None),
            role=role,
            employee_id=emp_id,
            fetch_result=False
        )
        return RedirectResponse(url="/books?msg=Thêm sách mới thành công!&msg_type=success", status_code=303)
    except Exception as e:
        genres = execute_query("SELECT GenreID, GenreName FROM dbo.Genres ORDER BY GenreName", role=role)
        authors = execute_query("SELECT AuthorID, AuthorName FROM dbo.Author ORDER BY AuthorName", role=role)
        publishers = execute_query("SELECT PublisherID, PublisherName FROM dbo.Publisher ORDER BY PublisherName", role=role)
        return templates.TemplateResponse("books/form.html", {
            "request": request,
            "user": user,
            "active_nav": "books",
            "book": {
                "Title": title, "GenreID": genre_id, "AuthorID": author_id,
                "PublisherID": publisher_id, "Price": price, "StockQuantity": stock_quantity
            },
            "genres": genres,
            "authors": authors,
            "publishers": publishers,
            "error": str(e)
        })

@router.get("/{book_id}/edit", response_class=HTMLResponse)
async def edit_book_page(book_id: int, request: Request, user=Depends(require_role(["Admin", "Manager", "Inventory"]))):
    role = user.get("Role")
    books = execute_sp("dbo.sp_Book_GetById", (book_id,), role=role)
    if not books or len(books) == 0:
        return RedirectResponse(url="/books?msg=Không tìm thấy sách!&msg_type=danger", status_code=303)

    genres = execute_query("SELECT GenreID, GenreName FROM dbo.Genres ORDER BY GenreName", role=role)
    authors = execute_query("SELECT AuthorID, AuthorName FROM dbo.Author ORDER BY AuthorName", role=role)
    publishers = execute_query("SELECT PublisherID, PublisherName FROM dbo.Publisher ORDER BY PublisherName", role=role)

    return templates.TemplateResponse("books/form.html", {
        "request": request,
        "user": user,
        "active_nav": "books",
        "book": books[0],
        "genres": genres,
        "authors": authors,
        "publishers": publishers
    })

@router.post("/{book_id}/edit")
async def edit_book_action(
    book_id: int,
    request: Request,
    title: str = Form(...),
    genre_id: int = Form(...),
    author_id: int = Form(...),
    publisher_id: int = Form(...),
    price: float = Form(...),
    stock_quantity: int = Form(...),
    user=Depends(require_role(["Admin", "Manager", "Inventory"]))
):
    role = user.get("Role")
    emp_id = user.get("EmployeeID")
    try:
        execute_sp(
            "dbo.sp_Book_Update",
            (book_id, title.strip(), genre_id, author_id, publisher_id, price, stock_quantity),
            role=role,
            employee_id=emp_id,
            fetch_result=False
        )
        return RedirectResponse(url="/books?msg=Cập nhật sách thành công!&msg_type=success", status_code=303)
    except Exception as e:
        genres = execute_query("SELECT GenreID, GenreName FROM dbo.Genres ORDER BY GenreName", role=role)
        authors = execute_query("SELECT AuthorID, AuthorName FROM dbo.Author ORDER BY AuthorName", role=role)
        publishers = execute_query("SELECT PublisherID, PublisherName FROM dbo.Publisher ORDER BY PublisherName", role=role)
        return templates.TemplateResponse("books/form.html", {
            "request": request,
            "user": user,
            "active_nav": "books",
            "book": {
                "BookID": book_id, "Title": title, "GenreID": genre_id, "AuthorID": author_id,
                "PublisherID": publisher_id, "Price": price, "StockQuantity": stock_quantity
            },
            "genres": genres,
            "authors": authors,
            "publishers": publishers,
            "error": str(e)
        })

@router.post("/{book_id}/delete")
async def delete_book_action(book_id: int, request: Request, user=Depends(require_role(["Admin", "Manager", "Inventory"]))):
    role = user.get("Role")
    emp_id = user.get("EmployeeID")
    try:
        execute_sp("dbo.sp_Book_Delete", (book_id,), role=role, employee_id=emp_id, fetch_result=False)
        return RedirectResponse(url="/books?msg=Đã xóa sách thành công!&msg_type=success", status_code=303)
    except Exception as e:
        return RedirectResponse(url=f"/books?msg=Lỗi khi xóa sách: {str(e)}&msg_type=danger", status_code=303)

@router.post("/{book_id}/stock")
async def update_stock_action(
    book_id: int,
    request: Request,
    delta: int = Form(...),
    user=Depends(require_role(["Admin", "Manager", "Inventory"]))
):
    role = user.get("Role")
    emp_id = user.get("EmployeeID")
    try:
        execute_sp("dbo.sp_UpdateBookStock", (book_id, delta), role=role, employee_id=emp_id, fetch_result=False)
        return RedirectResponse(url="/books?msg=Cập nhật tồn kho thành công!&msg_type=success", status_code=303)
    except Exception as e:
        return RedirectResponse(url=f"/books?msg=Lỗi cập nhật tồn kho: {str(e)}&msg_type=danger", status_code=303)
