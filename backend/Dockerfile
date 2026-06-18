# ---------- Stage 1: Builder ----------
FROM python:3.13-slim AS builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# ---------- Stage 2: Production ----------
FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1

WORKDIR /app

# Install runtime dependencies only
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Create non-root user
RUN groupadd -r lanwash && useradd -r -g lanwash lanwash

# Copy only runtime application code
COPY --chown=lanwash:lanwash main.py alembic.ini ./
COPY --chown=lanwash:lanwash app/ app/
COPY --chown=lanwash:lanwash db/ db/
COPY --chown=lanwash:lanwash models/ models/
COPY --chown=lanwash:lanwash schemas/ schemas/
COPY --chown=lanwash:lanwash repositories/ repositories/
COPY --chown=lanwash:lanwash core/ core/
COPY --chown=lanwash:lanwash services/ services/
COPY --chown=lanwash:lanwash tasks/ tasks/
COPY --chown=lanwash:lanwash bot/ bot/
COPY --chown=lanwash:lanwash alembic/ alembic/
COPY --chown=lanwash:lanwash scripts/ scripts/

# Switch to non-root user
USER lanwash

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health').read()" || exit 1

# Run with uvicorn (production settings)
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers", "--workers", "2"]
