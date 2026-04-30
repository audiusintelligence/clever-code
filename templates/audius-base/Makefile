.DEFAULT_GOAL := help

help:
	@echo "  make up          - alle Container starten"
	@echo "  make down        - Container stoppen"
	@echo "  make logs        - Logs aller Container"
	@echo "  make ps          - Container Status"
	@echo "  make rebuild     - neu bauen + starten"
	@echo "  make migrate m=X - neue Alembic Migration"
	@echo "  make shell-be    - Shell im Backend Container"
	@echo "  make shell-fe    - Shell im Frontend Container"
	@echo "  make psql        - psql in DB"
	@echo "  make clean       - Container + Volumes löschen"

up:
	docker compose up -d --build

down:
	docker compose down

ps:
	docker compose ps

logs:
	docker compose logs -f

rebuild:
	docker compose up -d --build --force-recreate

migrate:
	@if [ -z "$(m)" ]; then echo 'Usage: make migrate m="add foo"'; exit 1; fi
	docker compose exec backend alembic revision --autogenerate -m "$(m)"

shell-be:
	docker compose exec backend bash

shell-fe:
	docker compose exec frontend sh

psql:
	docker compose exec db psql -U audius -d audius

clean:
	docker compose down -v
