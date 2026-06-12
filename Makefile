.PHONY: dev setup run swagger test tidy build

dev:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/dev.ps1

setup:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/setup.ps1

run:
	powershell -NoProfile -ExecutionPolicy Bypass -Command "& ./scripts/go.ps1 --% run ./cmd/api"

swagger:
	powershell -NoProfile -ExecutionPolicy Bypass -File scripts/swagger.ps1

test:
	powershell -NoProfile -ExecutionPolicy Bypass -Command "& ./scripts/go.ps1 --% test ./..."

tidy:
	powershell -NoProfile -ExecutionPolicy Bypass -Command "& ./scripts/go.ps1 --% mod tidy"

build:
	powershell -NoProfile -ExecutionPolicy Bypass -Command "& ./scripts/go.ps1 --% build -o tmp/lamba-api ./cmd/api"
