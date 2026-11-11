FROM python:3.10-slim

WORKDIR /workspace

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/workspace

# Install system dependencies including OpenJDK for local PySpark execution and Postgres client tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    default-jre-headless \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /workspace/
RUN pip install --no-cache-dir -r requirements.txt

COPY . /workspace/

CMD ["python", "scripts/reconciliation_engine.py", "--mode", "demo"]
