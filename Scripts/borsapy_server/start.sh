#!/bin/bash
# Borsapy FastAPI Backend Starter
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Virtual environment kontrolü
if [ ! -d "venv" ]; then
    echo "📦 Virtual environment oluşturuluyor..."
    python3 -m venv venv
fi

source venv/bin/activate
pip install -q -r requirements.txt

# SSL sertifika düzeltmesi (macOS + Python 3.13+)
# Python'un varsayılan SSL bağlamı macOS sistem sertifikalarını bulamayabiliyor.
export SSL_CERT_FILE=$(python3 -c "import certifi; print(certifi.where())" 2>/dev/null)
export REQUESTS_CA_BUNDLE="$SSL_CERT_FILE"

echo "🚀 Borsapy API backend başlatılıyor (port 8899)..."
uvicorn main:app --host 0.0.0.0 --port 8899 --reload
