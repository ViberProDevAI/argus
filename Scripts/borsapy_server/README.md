# BorsaPy Server

BIST (Borsa İstanbul) için FastAPI microservice. `borsapy` Python kütüphanesini REST API olarak sunar; Argus iOS uygulaması bu servise bağlanır.

## Ne zaman gerekli?

- ✓ BIST portföyü / BIST piyasa ekranlarını / temettü takibini kullanacaksan
- ✗ Sadece global piyasalara (S&P, NASDAQ, crypto) bakıyorsan **gerekmez** — Argus BIST provider'ı devre dışı kalır, iOS tarafı Yahoo fallback'e düşer

## Lokal çalıştırma (macOS / Linux)

```bash
cd Scripts/borsapy_server
./start.sh
```

`start.sh` otomatik yapar:
1. `venv/` yoksa oluşturur
2. `pip install -r requirements.txt`
3. macOS + Python 3.13+ için SSL CA bundle düzeltmesi
4. `uvicorn main:app --host 0.0.0.0 --port 8899 --reload`

Test:
```bash
curl http://localhost:8899/health
# → {"status":"ok","version":"1.1.0"}

curl http://localhost:8899/ticker/THYAO.IS/quote
# → { "symbol": "THYAO.IS", "last": 274.50, "change": 3.35, ... }
```

iOS uygulamada `Secrets.xcconfig`:
```
BORSAPY_URL = http://localhost:8899
BORSAPY_KEY =
```

> **Simülatör** `localhost`'u kendi sandbox'ı gibi algılar — `http://localhost:8899` çalışır.
>
> **Gerçek cihaz** `localhost`'u kendi cihazı olarak yorumlar; Mac'e bağlanması gerekir. Bu durumda Mac'inin IP'sini ver:
> ```
> BORSAPY_URL = http://192.168.1.XX:8899
> ```
> (Mac ve iPhone aynı Wi-Fi'de olmalı.)

## Bulut deploy

### Render (önerilen — ücretsiz tier)

1. [render.com](https://render.com) → New → Blueprint
2. Kendi fork'unu bağla
3. Render `render.yaml`'ı otomatik okur → `borsapy-server` adlı web service başlar
4. Deploy tamamlanınca URL: `https://borsapy-server-<hash>.onrender.com`
5. İsteğe bağlı: Render dashboard'dan Environment → `BORSAPY_TOKEN` ekle (aşağıdaki Güvenlik bölümüne bak)
6. iOS `Secrets.xcconfig`'teki `BORSAPY_URL` değerini bu URL ile değiştir

**Free tier uyarısı:** 15 dakika inaktifse servis uyur, ilk istekte ~30 sn cold start. Starter plan ($7/ay) bunu kaldırır. iOS tarafında `warmUp()` açılışta `/health` çağırarak backend'i önden uyandırır.

### Docker (Fly.io / Railway / Cloud Run / App Runner)

```bash
# Lokal test
docker build -t borsapy-server -f Scripts/borsapy_server/Dockerfile .
docker run -p 8899:8899 borsapy-server
curl http://localhost:8899/health
```

**Fly.io:**
```bash
cd Scripts/borsapy_server
fly launch --dockerfile Dockerfile --name borsapy-server
fly deploy
```

**Railway:**
- Repo bağla → Root directory: `Scripts/borsapy_server`
- Start command otomatik Dockerfile'dan algılanır

**Google Cloud Run:**
```bash
cd Scripts/borsapy_server
gcloud run deploy borsapy-server --source . --region europe-west1 --allow-unauthenticated
```

## API Endpoint'leri

Sunucu çalıştıktan sonra FastAPI auto-gen dokümantasyon: `http://localhost:8899/docs`

Hepsi GET. Sembol path'in içine yazılır (query parametresi değil).

| Endpoint | Örnek path | Açıklama |
|---|---|---|
| `/health` | `/health` | Sağlık + versiyon |
| `/ticker/{symbol}/quote` | `/ticker/THYAO.IS/quote` | Anlık fiyat + değişim |
| `/ticker/{symbol}/history` | `/ticker/ASELS.IS/history?period=1mo&interval=1d` | OHLCV tarihçe |
| `/ticker/{symbol}/financials` | `/ticker/GARAN.IS/financials?quarterly=false` | Bilanço + gelir tablosu |
| `/ticker/{symbol}/dividends` | `/ticker/KCHOL.IS/dividends` | Temettü geçmişi |
| `/ticker/{symbol}/splits` | `/ticker/THYAO.IS/splits` | Bedelli/bedelsiz geçmişi |
| `/fx/{pair}` | `/fx/USDTRY` | Döviz paritesi |
| `/gold/{type}` | `/gold/GRAM` | Altın / Brent |

> **iOS → backend path'leri source-of-truth**: Argus `BorsaPyProvider` bu path şemasını bekler. Python tarafındaki route'lar bunlarla birebir aynı olmalı; aksi halde quote/history sessizce boş döner ve BIST sembolleri Yahoo fallback'e geçer.

## Güvenlik

BorsaPy backend **salt okunur** (GET-only) ve BIST verisi halka açık — kritik veri sızdırmıyor. Buna rağmen her abonenin kendi Render deploy'unu token ile koruması şiddetle tavsiye edilir:

1. **Ucuza kötüye kullanım önler**: Public URL'yi tarayıcıda keşfeden biri ücretsiz tier'ın 750 saat/ay kotasını yiyebilir
2. **Bot trafiğini filtreler**: Arama motorları ve tarama botları 401 alıp vazgeçer

### Bearer token nasıl ayarlanır?

**Sunucu tarafı (Render / Docker / Fly.io):**

Environment variable olarak `BORSAPY_TOKEN` ekle. Rastgele bir string yeterli — örn:
```bash
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
# → "7f3Jk9vPq_Bx2mN8rYw5LgHa1cEtS6dU-Oi4zXW0nMQ"
```

Render dashboard: Environment → Add Environment Variable → `BORSAPY_TOKEN` = `<yukarıdaki string>`

**iOS tarafı (Secrets.xcconfig):**

```
BORSAPY_KEY = 7f3Jk9vPq_Bx2mN8rYw5LgHa1cEtS6dU-Oi4zXW0nMQ
```

Argus her isteğe `Authorization: Bearer <BORSAPY_KEY>` header'ı ekler.

### Davranış

| Sunucu `BORSAPY_TOKEN` | iOS `BORSAPY_KEY` | Sonuç |
|---|---|---|
| Unset | Boş | ✓ Auth devre dışı (lokal dev / açık public) |
| Set | Boş | ✗ 401 Unauthorized — tüm istekler reddedilir |
| Set | Set (eşleşiyor) | ✓ İstekler kabul edilir |
| Set | Set (eşleşmiyor) | ✗ 401 Unauthorized |
| Unset | Set | ✓ Header gelir, sunucu görmezden gelir (gelecekte token eklemeyi unutmaya karşı güvenli) |

`/health`, `/docs`, `/openapi.json`, `/redoc` her zaman public — auth-korumalı değil (FastAPI auto-docs'u ve warm-up'ı bozmamak için).

### Manuel test

```bash
# Tokensız istek → 401
curl -i https://your-backend.onrender.com/ticker/THYAO.IS/quote
# HTTP/1.1 401 Unauthorized

# Bearer ile istek → 200
curl -i -H "Authorization: Bearer 7f3Jk9vPq_..." https://your-backend.onrender.com/ticker/THYAO.IS/quote
# HTTP/1.1 200 OK
```

### CORS

`allow_origins=["*"]` ayarlı — iOS app için sorun değil; tarayıcıdan herkese açık erişim istemiyorsan origins listesini kısıtla (`main.py` içinde).

## Sorun giderme

**Hata: `SSL: CERTIFICATE_VERIFY_FAILED`**
→ macOS + Python 3.13+'ta yaygın. `start.sh` bunu otomatik çözer. Manuel:
```bash
export SSL_CERT_FILE=$(python3 -c "import certifi; print(certifi.where())")
export REQUESTS_CA_BUNDLE="$SSL_CERT_FILE"
```

**Hata: `ModuleNotFoundError: No module named 'borsapy'`**
→ `venv` aktif değil veya kurulu değil:
```bash
source venv/bin/activate
pip install -r requirements.txt
```

**Hata: iOS cihaz `BORSAPY_URL`'e bağlanamıyor**
→ Simülatörde `http://localhost:8899` çalışır. Gerçek cihazda Mac'inin IP'si gerekir: `ifconfig | grep "inet " | grep -v 127.0.0.1`

**Hata: iOS 401 Unauthorized alıyor**
→ Sunucudaki `BORSAPY_TOKEN` ile iOS'taki `BORSAPY_KEY` birebir eşleşmeli (trim, baş/son boşluk önemli). Eşleşmiyorsa iOS loglarında `BorsaPyError.missingApiKey` görünür.

**Hata: Render deploy hiç tamamlanmıyor**
→ `requirements.txt`'teki `borsapy` sürümü Python 3.12 ile uyumlu değilse build fail eder. `render.yaml`'da `PYTHON_VERSION` değerini 3.11'e indir.

**BIST sembolleri iOS'ta hiç çalışmıyor**
→ `BORSAPY_URL` boşsa iOS cihazda hardcoded fallback yok; BIST Yahoo'ya düşer. `Secrets.xcconfig`'e kendi backend URL'ini ekle ve Xcode'da clean build yap.
