# =========================
# Stage 1: dependencies
# =========================
FROM python:3.13-slim AS builder

WORKDIR /build

COPY app/requirements.txt .

RUN pip wheel \
    --no-cache-dir \
    --wheel-dir /wheels \
    -r requirements.txt


# =========================
# Stage 2: application
# =========================
FROM python:3.13-slim

WORKDIR /app

COPY --from=builder /wheels /wheels
COPY app/requirements.txt .

RUN pip install \
    --no-cache-dir \
    --no-index \
    --find-links=/wheels \
    -r requirements.txt && \
    rm -rf /wheels

COPY app/ .

RUN useradd \
    --create-home \
    --uid 10001 \
    appuser && \
    chown -R appuser:appuser /app

USER appuser

ENV PYTHONUNBUFFERED=1

EXPOSE 8000

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--access-logfile", "-", "--error-logfile", "-", "app:app"]
