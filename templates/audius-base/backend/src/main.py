from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from src.core.config import settings
from src.core.db import engine
from src.api import items, me


@asynccontextmanager
async def lifespan(_app: FastAPI):
    yield
    await engine.dispose()


app = FastAPI(
    title=settings.solution_name,
    description=settings.solution_description,
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(me.router)
app.include_router(items.router)


@app.get("/health")
async def health():
    return {"status": "ok", "solution": settings.solution_name}


@app.get("/")
async def root():
    return {"name": settings.solution_name, "version": "0.1.0"}
