from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    solution_name: str = "__SOLUTION_NAME__"
    solution_description: str = "__SOLUTION_DESCRIPTION__"

    database_url: str = "postgresql+asyncpg://audius:audius@db:5432/audius"

    keycloak_issuer: str = "https://id.clevercompany.ai/realms/solutions"
    keycloak_audience: str = "solution-__SOLUTION_NAME__"

    cors_origins: list[str] = ["http://localhost:3000"]


settings = Settings()
