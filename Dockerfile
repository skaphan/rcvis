# Stage 1: Build frontend assets (webpack)
FROM node:20-slim AS frontend-builder
WORKDIR /app
COPY package.json package-lock.json ./
COPY static/settings/package.json static/settings/package-lock.json static/settings/
COPY static/datatable/package.json static/datatable/package-lock.json static/datatable/
RUN npm ci
COPY static/ static/
RUN npm run build

# Stage 2: Python application
FROM python:3.13-slim

WORKDIR /app

# Install system deps needed by pillow
RUN apt-get update && apt-get install -y --no-install-recommends \
    libjpeg62-turbo-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt infra/requirements-core.txt infra/
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Copy built frontend assets from stage 1
COPY --from=frontend-builder /app/node_modules/ ./node_modules/
COPY --from=frontend-builder /app/static/settings/dist/ ./static/settings/dist/
COPY --from=frontend-builder /app/static/datatable/dist/ ./static/datatable/dist/

# Environment defaults for offline/container mode
ENV RCVIS_DEBUG=False \
    OFFLINE_MODE=True \
    RCVIS_HOST=localhost \
    DJANGO_SETTINGS_MODULE=rcvis.settings

# Compress templates and collect static files at build time
RUN RCVIS_SECRET_KEY=build-placeholder python manage.py compress --force \
    && RCVIS_SECRET_KEY=build-placeholder python manage.py collectstatic --noinput

# Create directories for runtime data
RUN mkdir -p /app/media /tmp/django_rcvis_cache

EXPOSE 8000

ENTRYPOINT ["./docker-entrypoint.sh"]
CMD ["gunicorn", "rcvis.wsgi", "--bind", "0.0.0.0:8000", "--workers", "2"]
