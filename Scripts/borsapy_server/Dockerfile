# BorsaPy FastAPI backend — platform-agnostic Docker image.
# Fly.io, Railway, Google Cloud Run, AWS App Runner vb. hepsinde çalışır.
#
# Lokal test:
#   docker build -t borsapy-server -f Scripts/borsapy_server/Dockerfile .
#   docker run -p 8899:8899 borsapy-server
#   curl http://localhost:8899/health
#
# Fly.io deploy:
#   cd Scripts/borsapy_server
#   fly launch --dockerfile Dockerfile --name borsapy-server
#   fly deploy
#
FROM python:3.12-slim

# Sistem paketleri — borsapy bazı kütüphanelerin C extension'larını gerektirebilir
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Requirements'ı önce kopyala ki katman cache'i işe yarasın
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# Uygulama kodu
COPY main.py /app/

# SSL bundle — Python ortamında certifi kullanılır
ENV SSL_CERT_FILE=/usr/local/lib/python3.12/site-packages/certifi/cacert.pem
ENV REQUESTS_CA_BUNDLE=/usr/local/lib/python3.12/site-packages/certifi/cacert.pem
ENV PYTHONUNBUFFERED=1

# Varsayılan port. Platform PORT env var inject ederse (Render/Railway/Cloud Run)
# uvicorn onu kullansın diye shell form kullanıyoruz.
EXPOSE 8899
CMD uvicorn main:app --host 0.0.0.0 --port ${PORT:-8899}
