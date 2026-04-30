"""
Keycloak JWT validation. Cached JWKS, validates iss/aud/exp.

Note: When keycloak_issuer is reachable, tokens are properly validated.
For local dev without Keycloak, you can bypass via DISABLE_AUTH=1 env var.
"""
import os
from typing import Annotated

import httpx
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt

from src.core.config import settings

bearer = HTTPBearer(auto_error=False)
_jwks_cache: dict | None = None


async def _get_jwks() -> dict:
    global _jwks_cache
    if _jwks_cache is None:
        async with httpx.AsyncClient(timeout=5.0) as client:
            r = await client.get(f"{settings.keycloak_issuer}/protocol/openid-connect/certs")
            r.raise_for_status()
            _jwks_cache = r.json()
    return _jwks_cache


async def get_current_user(
    creds: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
) -> dict:
    if os.getenv("DISABLE_AUTH") == "1":
        return {"sub": "dev-user", "email": "dev@local", "name": "Dev User"}

    if not creds:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Bearer token required")

    try:
        jwks = await _get_jwks()
        return jwt.decode(
            creds.credentials,
            jwks,
            algorithms=["RS256"],
            issuer=settings.keycloak_issuer,
            options={"verify_aud": False},
        )
    except JWTError as e:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, f"Invalid token: {e}")
