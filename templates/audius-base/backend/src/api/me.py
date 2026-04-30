from typing import Annotated
from fastapi import APIRouter, Depends

from src.core.auth import get_current_user

router = APIRouter(prefix="/api/v1", tags=["auth"])


@router.get("/me")
async def me(user: Annotated[dict, Depends(get_current_user)]):
    return {
        "sub": user.get("sub"),
        "email": user.get("email"),
        "name": user.get("name") or user.get("preferred_username"),
    }
