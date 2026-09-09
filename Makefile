help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

build: ## [host] build l'image
	docker-compose build

up: ## [host] lance failover + un faux "web" de test
	docker-compose up -d

down: ## [host] arrête l'environnement de test
	docker-compose down

logs: ## [host] logs du healthcheck / nginx
	docker-compose logs -f failover

stop-web: ## [host] simule une panne de web
	docker-compose stop web

start-web: ## [host] relève web
	docker-compose start web

curl: ## [host] interroge le failover (voir la bascule proxy/maintenance)
	@curl -s -o /dev/null -w "http_code=%{http_code}\n" http://localhost:18082/
