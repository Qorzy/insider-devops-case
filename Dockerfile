# syntax=docker/dockerfile:1.7

# ============================================================
# Stage 1: builder
# Python dependencies'i ayrı bir stage'de kuruyoruz, böylece
# pip cache ve build araçları final image'a girmiyor.
# ============================================================
FROM python:3.12-slim AS builder

# Build-time argument: CI'da git SHA inject edilecek
ARG BUILD_SHA=dev

# pip optimizasyonları
ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /build

# Önce sadece requirements.txt kopyala (cache layer)
# Kod değiştiğinde deps yeniden kurulmasın diye
COPY requirements.txt .

# Deps'i kullanıcı home'una kur (final stage'e taşıyacağız)
RUN pip install --user --no-cache-dir -r requirements.txt


# ============================================================
# Stage 2: runtime
# Sadece çalışmak için gerekenler. Non-root user.
# ============================================================
FROM python:3.12-slim AS runtime

ARG BUILD_SHA=dev

# Runtime environment
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH=/home/appuser/.local/bin:$PATH \
    BUILD_SHA=${BUILD_SHA}

# Non-root user oluştur (root'ta çalışmak güvenlik açığı)
# UID 10001: yüksek numara, host UID'leriyle çakışma riski düşük
RUN groupadd --system --gid 10001 appuser && \
    useradd --system --uid 10001 --gid appuser --home /home/appuser --create-home appuser

WORKDIR /app

# builder stage'inden kurulu paketleri kopyala
COPY --from=builder --chown=appuser:appuser /root/.local /home/appuser/.local

# App kodunu kopyala (chown ile non-root sahipliği)
COPY --chown=appuser:appuser app/ ./app/

# Non-root user'a geç
USER appuser

EXPOSE 8080

# HEALTHCHECK: Docker'ın kendisi container sağlığını kontrol etsin
# K8s probe'ları Day 2'de ayrı tanımlayacağız ama bu standalone docker run için yararlı
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request, sys; \
        sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8080/healthz', timeout=2).status == 200 else 1)"

# uvicorn'u doğrudan çalıştır (shell wrapper yok → daha az PID, sinyaller doğru iletilir)
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]