# NiVuba developer entry points. Run `make help` for the list.
SHELL := /bin/bash
COMPOSE := docker compose

.DEFAULT_GOAL := help
.PHONY: help init up down logs ps reset test test-core test-ui smoke

help: ## List targets
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

init: ## Fetch submodules and create .env from the example (never overwrites)
	git submodule update --init
	@[ -f .env ] || { cp .env.example .env && echo "Created .env from .env.example — set real secrets before deploying."; }

up: init ## Build and start the whole stack, waiting until services are healthy
	$(COMPOSE) up -d --build --wait

down: ## Stop the stack (keeps data)
	$(COMPOSE) down

reset: ## Stop the stack and DELETE the database/redis volumes
	$(COMPOSE) down -v

logs: ## Follow logs (e.g. make logs s=nivuba-core)
	$(COMPOSE) logs -f $(s)

ps: ## Show service status
	$(COMPOSE) ps

test: test-core test-ui ## Run all offline checks (unit tests, typecheck, build)

test-core: ## nivuba-core: unit tests + build
	cd nivuba-core && npm ci --no-audit --no-fund && npm test && npm run build

test-ui: ## nivuba-ui: typecheck + production build
	cd nivuba-ui && npm ci --no-audit --no-fund && npx tsc --noEmit && npm run build

smoke: ## End-to-end check against the running stack (run `make up` first)
	./scripts/smoke.sh
