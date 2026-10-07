from datetime import datetime, date, timedelta
from fastapi import APIRouter, Request, Depends
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from app.database import execute_query, execute_sp
from app.routers.auth import require_role

router = APIRouter(prefix="/reports", tags=["Reports"])
templates = Jinja2Templates(directory="app/templates")

@router.get("/revenue", response_class=HTMLResponse)
async def revenue_report_page(
    request: Request,
    from_date: str = None,
    to_date: str = None,
    user=Depends(require_role(["Admin", "Manager"]))
):
    role = user.get("Role")
    today = date.today()
    
    # Default range: 30 days ago to today
    if not from_date:
        from_date = (today - timedelta(days=30)).strftime("%Y-%m-%d")
    if not to_date:
        to_date = today.strftime("%Y-%m-%d")

    # Monthly revenue aggregate from vw_MonthlyRevenue
    monthly_data = execute_query(
        "SELECT Year, Month, TotalOrders, TotalRevenue "
        "FROM dbo.vw_MonthlyRevenue "
        "ORDER BY Year DESC, Month DESC",
        role=role
    )

    # Detailed period report via sp_GetRevenueReport
    period_summary = None
    try:
        from_dt_str = f"{from_date} 00:00:00"
        to_dt_str = f"{to_date} 23:59:59"
        res = execute_sp(
            "dbo.sp_GetRevenueReport",
            (from_dt_str, to_dt_str),
            role=role,
            fetch_result=True
        )
        if res and len(res) > 0:
            period_summary = res[0]
    except Exception as e:
        period_summary = {"TotalOrders": 0, "TotalBooksSold": 0, "TotalRevenue": 0, "error": str(e)}

    # Daily breakdown in current period
    daily_breakdown = execute_query(
        "SELECT CAST(o.OrderDate AS DATE) AS OrderDate, "
        "       COUNT(DISTINCT o.OrderID) AS OrderCount, "
        "       SUM(od.Quantity) AS BooksSold, "
        "       SUM(od.Quantity * od.UnitPrice) AS DailyRevenue "
        "FROM dbo.Orders o "
        "INNER JOIN dbo.OrderDetails od ON o.OrderID = od.OrderID "
        "WHERE o.Status = 'Completed' "
        "  AND o.OrderDate >= ? AND o.OrderDate <= ? "
        "GROUP BY CAST(o.OrderDate AS DATE) "
        "ORDER BY OrderDate DESC",
        (f"{from_date} 00:00:00", f"{to_date} 23:59:59"),
        role=role
    )

    return templates.TemplateResponse("reports/revenue.html", {
        "request": request,
        "user": user,
        "active_nav": "reports",
        "monthly_data": monthly_data or [],
        "period_summary": period_summary or {"TotalOrders": 0, "TotalBooksSold": 0, "TotalRevenue": 0},
        "daily_breakdown": daily_breakdown or [],
        "from_date": from_date,
        "to_date": to_date
    })

@router.get("/top-selling", response_class=HTMLResponse)
async def top_selling_report_page(
    request: Request,
    user=Depends(require_role(["Admin", "Manager"]))
):
    role = user.get("Role")
    # Query view vw_TopSellingBooks
    top_books = execute_query(
        "SELECT BookID, Title, GenreName, TotalQuantitySold, TotalRevenue "
        "FROM dbo.vw_TopSellingBooks "
        "ORDER BY TotalQuantitySold DESC, TotalRevenue DESC",
        role=role
    )

    return templates.TemplateResponse("reports/top_selling.html", {
        "request": request,
        "user": user,
        "active_nav": "reports",
        "top_books": top_books or []
    })

@router.get("/low-stock", response_class=HTMLResponse)
async def low_stock_report_page(
    request: Request,
    threshold: str = "10",
    user=Depends(require_role(["Admin", "Manager", "Inventory"]))
):
    role = user.get("Role")
    try:
        t_val = int(threshold.strip()) if threshold and threshold.strip().isdigit() else 10
    except (ValueError, AttributeError):
        t_val = 10
    if t_val < 1:
        t_val = 10

    # Query inline table function fn_GetLowStockBooks
    low_books = execute_query(
        "SELECT BookID, Title, GenreName, StockQuantity, Price "
        "FROM dbo.fn_GetLowStockBooks(?) "
        "ORDER BY StockQuantity ASC, Title ASC",
        (t_val,),
        role=role
    )

    return templates.TemplateResponse("reports/low_stock.html", {
        "request": request,
        "user": user,
        "active_nav": "reports",
        "threshold": t_val,
        "low_books": low_books or []
    })

@router.get("/audit-logs", response_class=HTMLResponse)
async def audit_logs_page(
    request: Request,
    table_name: str = None,
    action_type: str = None,
    user=Depends(require_role(["Admin"]))
):
    role = user.get("Role")
    sql = "SELECT TOP 100 LogID, TableName, ActionType, RecordID, ChangedBy, ChangedDate, OldData, NewData FROM dbo.AuditLog WHERE 1=1"
    params = []

    if table_name and table_name.strip():
        sql += " AND TableName = ?"
        params.append(table_name.strip())

    if action_type and action_type.strip():
        sql += " AND ActionType = ?"
        params.append(action_type.strip())

    sql += " ORDER BY ChangedDate DESC"
    logs = execute_query(sql, tuple(params) if params else None, role=role)

    return templates.TemplateResponse("reports/audit_logs.html", {
        "request": request,
        "user": user,
        "active_nav": "reports",
        "logs": logs or [],
        "filters": {
            "table_name": table_name or "",
            "action_type": action_type or ""
        }
    })
