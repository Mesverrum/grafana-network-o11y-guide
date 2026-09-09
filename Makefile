.PHONY: up down logs check

up:
	docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f alloy

check:
	@test -f .env || (echo "copy .env.sample to .env" && exit 1)
	@test -f alloy/config.alloy || (echo "copy alloy/config.alloy.sample to alloy/config.alloy" && exit 1)
	@test -f alloy/auths.yml || (echo "copy alloy/auths.example.yml to alloy/auths.yml" && exit 1)
	docker compose config -q
	@echo "ok"
