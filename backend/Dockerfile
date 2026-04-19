FROM python:3.12-slim

# WeasyPrint system deps + Inter font
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcairo2 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libgdk-pixbuf-2.0-0 \
    libffi-dev \
    shared-mime-info \
    fonts-inter \
    fonts-dejavu \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy source first — pip install needs the `app/` package dir present.
# Railway build context is the repo root; Containerfile lives in backend/.
# Copy only the backend subdirectory so pyproject.toml lands at /app/pyproject.toml.
COPY backend/ /app/

RUN pip install --no-cache-dir --upgrade pip setuptools wheel \
    && pip install --no-cache-dir .

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONPATH=/app

EXPOSE 8000

COPY backend/start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
