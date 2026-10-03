# Backward compatibility for Starlette Jinja2Templates across versions
from starlette.templating import Jinja2Templates

_original_template_response = Jinja2Templates.TemplateResponse

def _safe_template_response(self, *args, **kwargs):
    if args and isinstance(args[0], str):
        name = args[0]
        context = args[1] if len(args) > 1 else kwargs.get("context", {})
        request = context.get("request") if isinstance(context, dict) else kwargs.get("request")
        status_code = kwargs.get("status_code", 200)
        headers = kwargs.get("headers")
        media_type = kwargs.get("media_type")
        background = kwargs.get("background")
        return _original_template_response(
            self,
            request=request,
            name=name,
            context=context,
            status_code=status_code,
            headers=headers,
            media_type=media_type,
            background=background
        )
    return _original_template_response(self, *args, **kwargs)

Jinja2Templates.TemplateResponse = _safe_template_response
