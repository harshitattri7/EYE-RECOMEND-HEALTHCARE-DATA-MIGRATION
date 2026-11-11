.PHONY: help install lint test generate-data dryrun-reconcile cutover-simulate docker-up docker-down

help:
	@echo "Eye Recommend Healthcare Data Migration Pipeline - CLI Commands"
	@echo "------------------------------------------------------------------"
	@echo "make install           : Install local Python development dependencies"
	@echo "make lint              : Run ruff / flake8 syntax & style linter"
	@echo "make test              : Run unit and integration tests"
	@echo "make generate-data     : Generate synthetic clinical & Salesforce datasets"
	@echo "make dryrun-reconcile  : Execute dry-run automated reconciliation engine"
	@echo "make cutover-simulate  : Run end-to-end production cutover simulation"
	@echo "make docker-up         : Start local MariaDB, PostgreSQL and test services"
	@echo "make docker-down       : Stop all local containers and clean volumes"

install:
	pip install -r requirements.txt

lint:
	python3 -m unittest discover -s tests -p "*test*.py"

test:
	python3 -m unittest discover -v -s tests -p "*test*.py"

generate-data:
	python3 scripts/generate_synthetic_data.py --records 5000 --output data/synthetic

dryrun-reconcile:
	python3 scripts/reconciliation_engine.py --mode dryrun --output-report reports/reconciliation_report.md

cutover-simulate:
	python3 scripts/cutover_orchestrator.py --config databricks/config/pipeline_config.yaml

docker-up:
	docker compose up -d

docker-down:
	docker compose down -v
