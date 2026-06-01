.PHONY: test-up test-down test-seed test-clean test-run test-full help

# Use Python from virtual environment
PYTHON := $(PWD)/.venv/bin/python3

# Load variables from .env safely (handles # and special chars in values)
DATABASE_URL := $(shell $(PYTHON) -c "import re; m=re.search(r'^DATABASE_URL=(.+)$$', open('.env').read(), re.M); print(m.group(1).strip() if m else '')")
POSTGRES_USER := $(shell $(PYTHON) -c "import re; m=re.search(r'^POSTGRES_USER=(.+)$$', open('.env').read(), re.M); print(m.group(1).strip() if m else '')")
POSTGRES_PASSWORD := $(shell $(PYTHON) -c "import re; m=re.search(r'^POSTGRES_PASSWORD=(.+)$$', open('.env').read(), re.M); print(m.group(1).strip() if m else '')")
POSTGRES_DB := $(shell $(PYTHON) -c "import re; m=re.search(r'^POSTGRES_DB=(.+)$$', open('.env').read(), re.M); print(m.group(1).strip() if m else '')")

# Derive test URLs from .env DATABASE_URL
# Replace db host → localhost, db name → lanwash_test
TEST_DATABASE_URL := $(shell echo "$(DATABASE_URL)" | sed 's|/lanwash_db|/lanwash_test|' | sed 's|@db:|@localhost:|')
ADMIN_DATABASE_URL := $(shell echo "$(DATABASE_URL)" | sed 's|/lanwash_db|/postgres|' | sed 's|@db:|@localhost:|')

# ─── Test Environment ─────────────────────────────────────────────────────────

test-up:
	@echo "🚀 Starting Prometheus + Grafana..."
	docker compose -f docker-compose.test.yml up -d
	@echo ""
	@echo "  Grafana:    http://localhost:3001  (admin/admin)"
	@echo "  Prometheus: http://localhost:9091"
	@echo ""

test-down:
	@echo "🛑 Stopping test environment..."
	docker compose -f docker-compose.test.yml down -v

test-seed:
	@echo "🌱 Seeding test data into lanwash_test..."
	cd backend && DATABASE_URL="$(TEST_DATABASE_URL)" $(PYTHON) scripts/seed.py

test-clean:
	@echo "🧹 Cleaning lanwash_test database..."
	cd backend && DATABASE_URL="$(ADMIN_DATABASE_URL)" $(PYTHON) scripts/clean.py

test-run:
	@echo "🔥 Starting Locust (open http://localhost:8089)"
	@echo "Make sure backend is running on port 8000!"
	cd backend && $(PYTHON) -m locust -f locustfile.py --host http://localhost:8000

test-backend:
	@echo "🖥️  Starting backend with test database..."
	cd backend && ENVIRONMENT=testing \
		DISABLE_RATE_LIMIT=true \
		DATABASE_URL="$(TEST_DATABASE_URL)" \
		$(PYTHON) -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload

# Full cycle: clean → seed → backend → locust (run each in separate terminals)
test-full: test-clean test-seed test-up
	@echo ""
	@echo "✅ Test environment ready!"
	@echo ""
	@echo "Next steps (run in separate terminals):"
	@echo "  1. make test-backend    # start backend"
	@echo "  2. make test-run        # start Locust"
	@echo "  3. Open http://localhost:8089 and start swarming"
	@echo "  4. Watch Grafana: http://localhost:3001"
	@echo ""

help:
	@echo "LanWash Test Commands"
	@echo ""
	@echo "  make test-up       - Start Prometheus + Grafana (Docker)"
	@echo "  make test-down     - Stop Prometheus + Grafana"
	@echo "  make test-clean    - DROP + CREATE empty lanwash_test DB"
	@echo "  make test-seed     - Fill lanwash_test with fake data"
	@echo "  make test-backend  - Run backend connected to lanwash_test"
	@echo "  make test-run      - Start Locust UI (localhost:8089)"
	@echo "  make test-full     - Clean + Seed + Prometheus/Grafana"
	@echo ""
	@echo "Typical workflow:"
	@echo "  make test-full     # terminal 1"
	@echo "  make test-backend  # terminal 2"
	@echo "  make test-run      # terminal 3 → open http://localhost:8089"
	@echo ""
