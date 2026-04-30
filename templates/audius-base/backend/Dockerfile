FROM python:3.12-slim
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends gcc libpq-dev && rm -rf /var/lib/apt/lists/*

COPY pyproject.toml ./
RUN pip install --no-cache-dir \
    fastapi==0.115.4 \
    "uvicorn[standard]==0.32.0" \
    "sqlalchemy[asyncio]==2.0.36" \
    asyncpg==0.30.0 \
    alembic==1.14.0 \
    pydantic==2.9.2 \
    pydantic-settings==2.6.1 \
    "python-jose[cryptography]==3.3.0" \
    httpx==0.27.2

COPY . .

EXPOSE 8000
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
