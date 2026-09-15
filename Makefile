# Kise mobile app — common tasks.

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

.PHONY: get
get: ## flutter pub get
	flutter pub get

.PHONY: test
test: ## Run the Flutter test suite
	flutter test

.PHONY: analyze
analyze: ## flutter analyze
	flutter analyze

.PHONY: env
env: ## Write env/dev.json with the Mac's LAN IP (override: make env ip=1.2.3.4 port=8000)
	@mkdir -p env
	@ip="$(ip)"; [ -n "$$ip" ] || ip=$$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null); \
	port="$(port)"; [ -n "$$port" ] || port=8000; \
	if [ -z "$$ip" ]; then echo "Could not detect a LAN IP; pass one: make env ip=1.2.3.4"; exit 1; fi; \
	printf '{\n  "KISE_API_URL": "http://%s:%s"\n}\n' "$$ip" "$$port" > env/dev.json; \
	echo "Wrote env/dev.json -> http://$$ip:$$port"

.PHONY: run
run: ## Run the app (make run d="endalk’s iPhone"); uses env/dev.json if present
	flutter run $(if $(d),-d "$(d)",) $(if $(wildcard env/dev.json),--dart-define-from-file=env/dev.json,)

.PHONY: run-ios
run-ios: ## Run on the iPhone 16 Pro simulator
	flutter run -d "iPhone 16 Pro" $(if $(wildcard env/dev.json),--dart-define-from-file=env/dev.json,)
