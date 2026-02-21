# Argus

Argus, iOS uzerinde calisan finansal veri, makro veri ve yapay zeka destekli analiz uygulamasidir.

## Baslarken

Bu bolumun amaci, projeyi ilk kez klonlayan birinin API key engeline takilmadan uygulamayi ayaga kaldirabilmesidir.

### 1) Gereksinimler

- Xcode (guncel surum)
- iOS Simulator
- Git

### 2) Projeyi ac

```bash
git clone <REPO_URL>
cd argus
open argus.xcodeproj
```

### 3) Secrets dosyasini olustur

```bash
cp Secrets.xcconfig.example Secrets.xcconfig
```

`Secrets.xcconfig` sadece lokal makinede kalmalidir. Bu dosyayi commit etmeyin.

### 4) API key'leri nereye girecegim?

Iki secenek var:

1. Uygulama ici: `Ayarlar > API Key Merkezi` (onerilen)
2. Gelistirme fallback: `Secrets.xcconfig`

Not: Uygulama anahtarlari once `API Key Merkezi` (Keychain), sonra `Secrets.xcconfig`/Info.plist fallback ile okur.

### 5) Hangi API key nereden alinacak?

Asagidaki tablo uygulamada gorunen servis adlariyla birebir eslestirilmistir.

| Servis | Projedeki Anahtar Adi | Girecegin Yer | Oncelik | API Key Alma Linki |
|---|---|---|---|---|
| Financial Modeling Prep | `FMP_KEY` | API Key Merkezi veya `Secrets.xcconfig` | Yuksek (onerilen) | [FMP Developer Docs](https://site.financialmodelingprep.com/developer/docs) |
| Twelve Data | `TWELVE_DATA_KEY` | API Key Merkezi veya `Secrets.xcconfig` | Yuksek (onerilen) | [Twelve Data Docs](https://twelvedata.com/docs) |
| EODHD | `EODHD_KEY` | API Key Merkezi veya `Secrets.xcconfig` | Orta | [EODHD API](https://eodhd.com/financial-apis/) |
| Tiingo | `TIINGO_KEY` | API Key Merkezi veya `Secrets.xcconfig` | Orta | [Tiingo API Token](https://www.tiingo.com/account/api/token) |
| Alpha Vantage | `ALPHA_VANTAGE_KEY` | API Key Merkezi veya `Secrets.xcconfig` | Orta | [Alpha Vantage API Key](https://www.alphavantage.co/support/#api-key) |
| MarketStack | `MARKETSTACK_KEY` | API Key Merkezi veya `Secrets.xcconfig` | Opsiyonel | [MarketStack Dashboard](https://marketstack.com/dashboard) |
| FRED | `FRED_KEY` | API Key Merkezi veya `Secrets.xcconfig` | Opsiyonel (makro veri) | [FRED API Key](https://fred.stlouisfed.org/docs/api/api_key.html) |
| Gemini | `GEMINI_KEY` | API Key Merkezi veya `Secrets.xcconfig` | Yuksek (AI ozellikleri) | [Google AI Studio API Keys](https://aistudio.google.com/app/apikey) |
| Groq | `GROQ_KEY` | API Key Merkezi veya `Secrets.xcconfig` | Opsiyonel (AI alternatifi) | [Groq Console Keys](https://console.groq.com/keys) |
| GLM | `GLM_KEY` | API Key Merkezi veya `Secrets.xcconfig` | Opsiyonel (AI alternatifi) | [Zhipu GLM Platform](https://open.bigmodel.cn/) |
| DeepSeek | `DEEPSEEK_KEY` | API Key Merkezi veya `Secrets.xcconfig` | Opsiyonel (AI alternatifi) | [DeepSeek API Keys](https://platform.deepseek.com/api_keys) |
| Pinecone | `PINECONE_KEY` | API Key Merkezi veya `Secrets.xcconfig` | Opsiyonel (vektor ozellikleri) | [Pinecone API Keys](https://app.pinecone.io/) |
| TCMB EVDS | `tcmb_evds_api_key` | API Key Merkezi | Opsiyonel (TR makro) | [TCMB EVDS](https://evds2.tcmb.gov.tr/index.php?/evds/login) |
| CollectAPI | `collectapi_key` | API Key Merkezi | Opsiyonel | [CollectAPI](https://collectapi.com/) |
| Massive | `massive` (API Key Store) | API Key Merkezi | Opsiyonel | [Massive](https://massive.com/) |

Legacy/ek anahtarlar sadece `Secrets.xcconfig` uzerinden yonetilir:

| Servis | Projedeki Anahtar Adi | Girecegin Yer | Oncelik | API Key Alma Linki |
|---|---|---|---|---|
| Finnhub | `FINNHUB_KEY` | `Secrets.xcconfig` | Opsiyonel | [Finnhub Dashboard](https://finnhub.io/dashboard) |
| SimFin | `SIMFIN_KEY` | `Secrets.xcconfig` | Opsiyonel | [SimFin API](https://simfin.com/data/api) |
| Doviz.com | `DOVIZCOM_KEY` | `Secrets.xcconfig` | Opsiyonel | [Doviz.com](https://www.doviz.com/) |
| BorsaPy | `BORSAPY_KEY` | `Secrets.xcconfig` | Opsiyonel | [BorsaPy Server (lokal)](./Scripts/borsapy_server) |
| BorsaPy URL | `BORSAPY_URL` | `Secrets.xcconfig` | Opsiyonel | [BorsaPy Server (lokal)](./Scripts/borsapy_server) |

### 6) Minimum calisan kurulum (hizli)

Ilk kurulumda en az su 3 anahtari girmeniz tavsiye edilir:

1. `FMP_KEY`
2. `TWELVE_DATA_KEY`
3. `GEMINI_KEY` (AI ozellikleri kullanacaksaniz)

### 7) Dogrulama (API key sorunu kalmamasi icin)

1. Uygulamayi acin.
2. `Ayarlar > API Key Merkezi` ekranina gidin.
3. Her girdide `Kaydet` deyin, sonra `Test` butonunu calistirin.
4. Basarisiz anahtarlari panelde duzeltip tekrar test edin.

### 8) Siklikla yapilan hata

- `Secrets.xcconfig` dosyasini olusturmadan build almak
- Key degerini boslukla yapistirmak (basta/sonda whitespace)
- Anahtari yanlis servise girmek (ornegin Gemini key'ini Groq alanina)
- Commit'e gizli anahtar eklemek

## BorsaPy Backend (BIST Verileri)

BIST (Borsa Istanbul) verileri icin Argus, `borsapy` Python kutuphanesini kullanan bir FastAPI microservice'e baglanir.

### Secenekler

**A) Lokal Sunucu (Gelistirme icin)**

```bash
cd Scripts/borsapy_server
./start.sh
```

Bu komut:
- Virtual environment olusturur
- Gereken paketleri yukler (`borsapy`, `fastapi`, `uvicorn`)
- `http://localhost:8899` uzerinde API baslatir

Sonra `Secrets.xcconfig` dosyaniza ekleyin:
```
BORSAPY_URL = http://localhost:8899
BORSAPY_KEY =
```

**B) Kendi Sunucunuza Deploy (Production)**

`Scripts/borsapy_server/` dizinini Render, Railway, Fly.io gibi herhangi bir platforma deploy edebilirsiniz. Sonra `BORSAPY_URL` degerini kendi sunucu adresinizle degistirin.

> Not: BorsaPy opsiyoneldir. Olmadan da uygulama calismaya devam eder, sadece BIST-spesifik ozellikler devre disi kalir.

## Guvenlik Notu

- Gercek API key'leri sadece lokal cihazda tutun.
- `Secrets.xcconfig` ve benzeri dosyalari repoya commit etmeyin.
- PR acmadan once degisiklikleri kontrol edin.

## Katki

Katki rehberi icin [CONTRIBUTING.md](CONTRIBUTING.md) dosyasina bakin.

## Ilgili Dosyalar

- `Secrets.xcconfig.example`
- `argus/Views/Settings/APIKeyCenterView.swift`
- `argus/Services/Secrets.swift`
- `argus/Services/Secrets/APIKeyStore.swift`
- `Scripts/borsapy_server/` (BIST backend)
