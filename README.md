# Argus

Argus — iOS üstünde çalışan, yapay zeka destekli finansal analiz uygulaması. Global ve BIST piyasalarında sinyal üretir, Alkindus öğrenme motoru ile kendini kalibre eder, Chiron ile modül ağırlıklarını öğrenir, Aether ile makro ortamı izler.

**Durum:** Aktif geliştirme. App Store'da değil. Mac + Xcode ile lokal derlenip iPhone'a kurulur.

**Kimler için bu README?** Twitter üstünden Argus abonesi olduysan kendi Mac'inde, kendi Apple Developer hesabınla, kendi API anahtarlarınla Argus'u kurmalısın. Aşağıdaki adımları **Claude Code, Antigravity, Cursor Agent veya Aider** gibi bir AI asistana verdiğinde çoğunu otomatik yapacak; sadece hassas kredansiyal anlarında (ödeme, 2FA, Keychain şifresi) sana dönecek.

---

## 🚀 AI agent'ina ver: başlangıç istemi

AI agent'ınla yeni bir oturum aç ve aşağıdaki mesajı yapıştır. Agent README'deki adımları baştan sona uygular, sadece durması gereken noktalarda sorar.

```
Ben bu repoyu (argus) Mac'ime kopyaladım. Kendi iPhone'umda Argus'u çalıştırmak istiyorum.
README.md'deki "Agent için kurulum — adım adım" bölümünü aç, komutları sırayla uygula.

Önemli: Bana ait kredansiyalleri (Apple Developer Team ID, API anahtarları, ödeme bilgileri,
2FA kodları) sen bilmiyorsun. Her adımda ihtiyacın olduğunda bana sor, ben sana vereceğim.
Tarayıcı kontrolü yapabiliyorsan (Claude in Chrome, browser MCP, Antigravity browser tool)
harici sitelere sen git, ben sadece login'de yardım ederim. Yapamıyorsan bana tam URL +
hangi butona tıklanacağını söyle, ben manuel yapıp sonucu sana aktarayım.

Argus eksik çalışmasın — opsiyonel bir özellik için anahtar yoksa README'deki
"zarif bozulma" tablosuna bak ve neyin devre dışı kalacağını bana açıkça söyle.
```

---

## 🎛️ Agent kapasitesi — iki iz (track) var

Agent'ının tarayıcı kontrol yeteneğine göre iki kurulum modundan biri kullanılır:

| | **Track A — Tarayıcı otonom** | **Track B — Kullanıcı manuel köprü** |
|---|---|---|
| Uygun agent | Claude + `claude-in-chrome` MCP, Antigravity Browser tool, bağımsız browser-use agent | Salt terminal Claude Code, Cursor Agent, Aider |
| Agent ne yapar | Siteye gider, formu doldurur, "Create API key" butonuna basar, dönen değeri okur | Kullanıcıya URL + hangi butonlara basılacağını söyler, sonucu pano üstünden alır |
| Kullanıcı ne yapar | Sadece login ve 2FA kodlarını girer | URL'yi açar, adımları takip eder, sonucu agent'a yazar |
| Hız | Hızlı (20 dk) | Yavaş (45 dk), sabır ister |

**Agent kendi yeteneğini teşhis etsin:** `mcp__Claude_in_Chrome__*` veya benzeri araçların aktif olup olmadığını kontrol ettirerek A/B kararı versin.

---

## ✋ Dur-ve-sor noktaları (hassas anlar)

Bu adımlarda agent **durmalı ve kullanıcıya dönmeli**. Otonom çalışmaya devam edip bu bilgileri uydurmaya çalışmak YASAKTIR.

| Moment | Sebep | Agent ne yapar |
|---|---|---|
| Apple ID şifresi / 2FA kodu | Güvenlik — asla bir ajanla paylaşılmamalı | "Şifreni sen gir, tamam deyince devam ederim" |
| Kredi kartı / ödeme bilgisi | Aynı | Aynı |
| Apple Developer üyeliği ($99/yıl) | Para harcama kararı | "Ücretli üyeliğe kaydolmak istiyor musun? Onay ver, senin adına ilerleyelim" |
| Bundle Identifier seçimi | Benzersiz olmalı, beraber karar verilmeli | "Önerim: `com.<senin-adin>.argus`. Onaylar mısın?" |
| API key'i repoya commit | Güvenlik — kalıcı sızıntı riski | Asla yapma. Sadece `Secrets.xcconfig` (git'e girmez) veya Keychain'e yaz |
| `git push --force` | Geri dönüşsüz | İnsan onayı olmadan asla |

---

## 📋 Ön gereksinimler (agent kontrol etsin)

```bash
# macOS 14+ olmalı
sw_vers -productVersion

# Xcode 16+ — App Store'dan kurulu olmalı
xcodebuild -version
# → Xcode 16.x veya üstü

# Python 3.11+ (BorsaPy için)
python3 --version

# Git
git --version

# Homebrew (opsiyonel ama yararlı)
brew --version || echo "Homebrew yok — yüklemek için: https://brew.sh"
```

**Bir şey eksikse:** Xcode'u kurmadan ilerleme. App Store → Xcode araması → kur → lisans sözleşmesini açmak için `sudo xcodebuild -license accept`.

---

## 🤖 Agent için kurulum — adım adım

### Adım 0 — Repo zaten klonlanmış mı?

Kullanıcı bu README'yi okuyorsa muhtemelen evet. Olmadığı durumda:

```bash
cd ~/Desktop
git clone <repo-url> argus
cd argus
git checkout ui/v5-designkit
```

### Adım 1 — Kendi Apple Developer kimliğini enjekte et

`project.pbxproj` geliştiricinin Team ID ve Bundle ID'sini içerir. Bunu değiştirmezsen Xcode "No provisioning profile" hatası verir.

**Agent ↔ kullanıcı etkileşimi:**

1. Agent sorar: "Apple Developer Team ID'ni söyler misin? 10 karakterlik (A-Z0-9). developer.apple.com → Account → Membership → 'Team ID' satırından alırsın. Üyeliğin yoksa önce ona kaydol ($99/yıl)."
2. Agent sorar: "Kullanmak istediğin Bundle Identifier nedir? Önerim: `com.<senin-adin>.argus`. Apple'da eşsiz olmalı, bu yüzden bariz olanlar (`com.argus.app`) alınmış olabilir."
3. Agent sorar (opsiyonel): "Apple Developer hesabının email'i nedir? Sadece ileride hangi hesaba bağladığımızı hatırlamak için, kimseye yollanmayacak."

Agent aldıktan sonra:

```bash
./Scripts/personalize.sh --team-id <TEAM_ID> --bundle-id <BUNDLE_ID> --apple-id <EMAIL>
```

Script tüm `DEVELOPMENT_TEAM` (4 satır) ve `PRODUCT_BUNDLE_IDENTIFIER` (2 satır) değerlerini yerinde değiştirir, değişmeden önce `.bak` yedeği alır.

**Doğrulama:**
```bash
grep -c "DEVELOPMENT_TEAM = <TEAM_ID>" argus.xcodeproj/project.pbxproj   # → 4
grep -c "PRODUCT_BUNDLE_IDENTIFIER = <BUNDLE_ID>" argus.xcodeproj/project.pbxproj   # → 2
```

Yanlış değer girildiyse geri alma:
```bash
cp argus.xcodeproj/project.pbxproj.bak argus.xcodeproj/project.pbxproj
# veya
git checkout -- argus.xcodeproj/project.pbxproj
```

### Adım 2 — `Secrets.xcconfig`'i oluştur

```bash
cp Secrets.xcconfig.example Secrets.xcconfig
```

`Secrets.xcconfig` dosyası `.gitignore`'da — commit edilemez. Gerçek API anahtarları sadece buraya yazılır.

### Adım 3 — API anahtarlarını topla

Her abone **kendi API anahtarlarını** alır. Geliştirici kendi anahtarlarını paylaşmaz (quota, güvenlik). Aşağıdaki tablo her servis için:
- **Track A** (tarayıcı otonom): Agent URL'yi açar, kullanıcı login eder, agent key'i kopyalar.
- **Track B** (manuel köprü): Agent URL'yi söyler, kullanıcı manuel alır, agent'a yapıştırır.

| Servis | Anahtar | Zorunlu mu? | Link | Ücretsiz limit |
|---|---|---|---|---|
| Google Gemini | `GEMINI_KEY` | **Evet** | https://aistudio.google.com/app/apikey | 60 req/dk (free tier) |
| FMP | `FMP_KEY` | **Evet** | https://site.financialmodelingprep.com/developer/docs | 250 req/gün |
| Twelve Data | `TWELVE_DATA_KEY` | **Evet** | https://twelvedata.com/ | 800 req/gün |
| Gemini yedek (opsiyonel) | `GEMINI_KEY_BACKUP` | Hayır | (farklı Google hesabı, aynı aistudio URL'si) | 429 quota fallback için |
| EODHD | `EODHD_KEY` | Hayır | https://eodhd.com/financial-apis/ | Geniş tarihçe + temettü |
| Tiingo | `TIINGO_KEY` | Hayır | https://www.tiingo.com/account/api/token | Alternatif hisse verisi |
| Alpha Vantage | `ALPHA_VANTAGE_KEY` | Hayır | https://www.alphavantage.co/support/#api-key | Makro indikatörler |
| FRED | `FRED_KEY` | Hayır | https://fred.stlouisfed.org/docs/api/api_key.html | US makro (Aether) |
| Groq | `GROQ_KEY` | Hayır | https://console.groq.com/keys | Hızlı LLM fallback |
| DeepSeek | `DEEPSEEK_KEY` | Hayır | https://platform.deepseek.com/api_keys | Ucuz LLM fallback |
| GLM (Zhipu) | `GLM_KEY` | Hayır | https://open.bigmodel.cn/ | Çinli LLM alternatifi |
| Pinecone | `PINECONE_KEY` + `PINECONE_BASE_URL` | Hayır | Adım 5'e bak | RAG vektör arama |
| BorsaPy | `BORSAPY_URL` + `BORSAPY_KEY` | BIST için evet | Adım 4'e bak | Kendi deploy |
| Doviz.com | `DOVIZCOM_KEY` | Hayır | https://www.doviz.com/ | TR döviz yedek |

**Agent her anahtarı aldıkça `Secrets.xcconfig`'e yazar.** Biçim:
```
GEMINI_KEY = AIzaSyABC...
FMP_KEY = 1234567890abcdef
TWELVE_DATA_KEY = xxxxx
```
Tırnak işareti kullanma, `=` etrafında boşluk yeter.

### Adım 4 — BorsaPy backend'ini deploy et (BIST kullanacaksan)

BIST (Borsa İstanbul) verisi için kendi Python microservice'ini deploy etmen gerek. Üç seçenek:

**Seçenek A — Render.com (önerilen, ücretsiz tier):**

Track A (agent tarayıcı kontrolüyle):
1. Agent https://dashboard.render.com → New → Blueprint
2. Kullanıcı login (agent durur, sor)
3. Agent repo'yu bağlar (GitHub entegrasyonu — kullanıcı izin ekranında onay verir)
4. Render `Scripts/borsapy_server/render.yaml`'ı otomatik okur
5. Deploy tamamlanınca agent URL'yi alır (`https://borsapy-server-<hash>.onrender.com`)
6. Agent **BORSAPY_TOKEN** env var'ını set etmeyi teklif eder (kullanıcı onaylarsa rastgele token üretir)

Track B (manuel):
1. Agent kullanıcıya https://dashboard.render.com/blueprints adresini söyler
2. "New Blueprint Instance" → repo bağla adımlarını anlatır
3. Deploy bitince kullanıcı URL'yi kopyalar ve agent'a verir
4. İsteğe bağlı: agent `python3 -c "import secrets; print(secrets.token_urlsafe(32))"` çalıştırır, kullanıcıya "bunu Render dashboard → Environment → BORSAPY_TOKEN olarak yapıştır" der

**Seçenek B — Lokal dev (sadece simülatörde test için):**
```bash
cd Scripts/borsapy_server
./start.sh
# Test: curl http://localhost:8899/health
# → {"status":"ok","version":"1.1.0"}
```
Bu mod gerçek iPhone'a kurulum için yetmez (iPhone localhost'u kendi cihazı sanır).

**Seçenek C — Skip:** BIST'i hiç kullanmayacaksan atla. `BORSAPY_URL`'i boş bırak.

BorsaPy detayları: `Scripts/borsapy_server/README.md` — endpoint tablosu, Bearer auth, Docker/Fly.io alternatifleri.

### Adım 5 — Pinecone index'ini oluştur (RAG için, opsiyonel)

Pinecone Argus'ta Hermes haber analizleri ve Konsey tartışmaları için geçmiş kararları vektör üstünden arar. Açmazsan motor çalışır, sadece "geçmişten öğrenme" katmanı devre dışı kalır.

Track A (agent tarayıcı):
1. Agent https://app.pinecone.io/ → signup
2. Kullanıcı login (agent durur)
3. Agent yeni index oluşturur: **name=`alkindus-argus`, dimension=`768`, metric=`cosine`, cloud=`aws`, region=`us-east-1`**
4. Agent API key'i kopyalar → `PINECONE_KEY`
5. Agent index host URL'ini kopyalar (format: `https://alkindus-argus-<hash>.svc.<region>.pinecone.io`) → `PINECONE_BASE_URL`

Track B (manuel):
1. Kullanıcı Pinecone dashboard'a girer, yukarıdaki parametrelerle index oluşturur
2. Index sayfasında sağ üstte **"Connect"** butonu — host URL oradan alınır
3. API Keys sekmesinden key alınır
4. Her ikisini agent'a verir

**Kritik:** `dimension=768` şart — Google `text-embedding-004` modeli bu boyutta çıktı verir. Farklı boyut seçersen upsert 400 hatası alır.

### Adım 6 — İlk build

```bash
xcodebuild -project argus.xcodeproj -scheme argus \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -10
```

Beklenen: `** BUILD SUCCEEDED **`

Hata alırsan:
- `No account for team <ID>` → Xcode → Preferences → Accounts → Apple ID ekle, sign in
- `No profiles for 'BUNDLE_ID' were found` → Xcode aç, target seç, Signing & Capabilities, "Automatically manage signing" işaretli olsun
- Build warning (Swift concurrency) → görmezden gel, hepsi Swift 6 geçiş uyarıları

### Adım 7 — Simülatörde çalıştır ve doğrula

```bash
xcodebuild -project argus.xcodeproj -scheme argus \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -derivedDataPath build \
  build && \
  xcrun simctl install booted "build/Build/Products/Debug-iphonesimulator/argus.app" && \
  xcrun simctl launch booted ArgusTeam.argus   # kendi bundle ID'nle değiştir
```

Simülatörde:
- [ ] Uygulama açılıyor
- [ ] Piyasa sekmesi → üst barda kayar yazı (SPY · NDX · VIX · GOLD · BTC · ETH) görünüyor
- [ ] Portföy sekmesi → karşılama ekranı
- [ ] Ayarlar → API Key Merkezi → her konfigüre edilmiş anahtarın yanında ✓ işareti
- [ ] BIST sembol ara (THYAO) → veri geliyor (BorsaPy konfigüre ettiysen)

Hepsi ✓ ise kurulum tamam. Gerçek cihaza deploy için Xcode'da iPhone'u seç, ⌘R.

---

## ⚖️ Zarif bozulma (graceful degradation) tablosu

Argus "eksik çalışmasın" ilkesine göre tasarlandı. Opsiyonel bir anahtar yoksa hata vermez; ilgili özellik sessizce devre dışı kalır ve alternatife döner. **Agent, kullanıcıya hangi özelliklerin aktif/pasif olduğunu açıkça söylemeli.**

| Eksik olan | Etki | Fallback davranışı |
|---|---|---|
| `GEMINI_KEY` | ❌ Kritik — Hermes LLM + chart pattern devre dışı | Uygulama çalışır, ama Hermes rapor üretemez; Konsey LLM tartışması yapılmaz |
| `FMP_KEY` | ❌ Kritik — temel veri yok | Diğer providerlarda (Twelve Data, EODHD) varsa onlara düşer. Hepsi boşsa quote veri yok |
| `TWELVE_DATA_KEY` | ⚠️ Orta — makro endeksler | FMP / Yahoo fallback. Quota aşımında alternatif kritik |
| `GEMINI_KEY_BACKUP` | ⚠️ Düşük — quota dayanıklılığı | Birincil key 429 alınca 1. hesap yetmez; günlük 200 req sonrası Hermes susar |
| `BORSAPY_URL` boş | 🔄 BIST kullanıcıları için kritik | BIST sembolleri Yahoo fallback'e düşer (`.IS` suffix ile, sınırlı veri) |
| `BORSAPY_KEY` boş + sunucu `BORSAPY_TOKEN` set | ❌ 401 Unauthorized | Tüm BorsaPy istekleri reddedilir; BIST Yahoo'ya düşer |
| `PINECONE_KEY` | ⚠️ RAG devre dışı | Hermes haber + Konsey geçmiş karar zenginleştirmesi yok. `AlkindusRAGEngine.isEnabled = false`, sync retry queue sessiz skip eder |
| `PINECONE_BASE_URL` boş veya geçersiz | ⚠️ RAG devre dışı | Aynı |
| `EODHD_KEY` | ℹ️ Düşük — temettü/tarihçe eksiği | Twelve Data fallback (sınırlı yıl) |
| `TIINGO_KEY` | ℹ️ Düşük | FMP/Twelve Data fallback |
| `ALPHA_VANTAGE_KEY` | ℹ️ Düşük | Aether'de bazı göstergeler boş döner, modül ağırlığı düşer |
| `FRED_KEY` | ℹ️ Düşük | US makro göstergeleri pasif, Aether Türk-ağırlıklı kararlar verir |
| `GROQ_KEY` / `DEEPSEEK_KEY` / `GLM_KEY` | ℹ️ Düşük — LLM redundancy | Gemini tek başına taşır. Gemini out ise Hermes susar |
| `DOVIZCOM_KEY` | ℹ️ Düşük | TCMB EVDS + Yahoo FX fallback |

**Agent kurulum sonunda özet ver:**
> "Argus kuruldu. Aktif özellikler: [liste]. Opsiyonel olarak pasif: [liste — neyi açmak istersen söyle]."

---

## 🏛️ Mimari Özeti

```
┌─────────────────────────────────────────┐
│     iOS App (Swift/SwiftUI, iOS 17+)    │
├─────────────────────────────────────────┤
│ Argus Motor Takımı:                     │
│   • Orion     — Teknik momentum         │
│   • Atlas     — Temel analiz            │
│   • Aether    — Makro rejim             │
│   • Hermes    — Haber & duygu (LLM)     │
│   • Athena    — Smart Beta faktörler    │
│   • Demeter   — Sektör rotasyonu        │
│   • Chiron    — Ağırlık öğrenme         │
│   • Prometheus — Fiyat projeksiyonu     │
│   • Alkindus  — Meta-zeka kalibrasyon   │
│   • Phoenix   — Geri dönüş adayları     │
├─────────────────────────────────────────┤
│ Orchestrator: ArgusGrandCouncil         │
│ Storage: SwiftData + Keychain           │
└─────────────────────────────────────────┘
            │
            ├── Global piyasa → FMP / Twelve Data / EODHD
            ├── BIST → BorsaPy microservice (Python/FastAPI, subscriber-hosted)
            ├── AI → Gemini / Groq / GLM / DeepSeek
            ├── Makro → FRED / TCMB EVDS
            └── RAG → Pinecone (subscriber-hosted, opsiyonel)
```

Detaylı modül dokümanları: `argus/Docs/Argus_Anatomy_*.md`

---

## 🔧 Sorun giderme

| Hata | Sebep | Çözüm |
|---|---|---|
| `BUILD FAILED — No signing certificate` | Xcode Signing Team seçili değil | Xcode → Target → Signing → Team seç |
| `No profiles for 'BUNDLE_ID' were found` | `personalize.sh` çalıştırılmadı veya Bundle ID çakışıyor | `personalize.sh` tekrar çalıştır; Bundle ID gerçekten benzersiz mi kontrol et |
| Simülatörde uygulama açılır ama Piyasa boş | API anahtarı eksik/yanlış | Ayarlar → API Key Merkezi → Test; log'larda "KeychainManager" satırına bak |
| BIST ekranları "Veri yok" | BorsaPy çalışmıyor veya URL yanlış | `curl $BORSAPY_URL/health` ile test; Secrets.xcconfig'teki `BORSAPY_URL` doğru mu |
| BorsaPy `401 Unauthorized` | Sunucuda `BORSAPY_TOKEN` var, iOS'ta `BORSAPY_KEY` eşleşmiyor | İki değeri birebir eşleştir (trim, büyük/küçük harf) |
| Gemini 429 "quota exceeded" | Ücretsiz 60 req/dk tükendi | `GEMINI_KEY_BACKUP` ekle (farklı Google hesabı); pool round-robin devreye girer |
| Pinecone `.notConfigured` log | `PINECONE_BASE_URL` eksik veya parse edilemiyor | URL formatı: `https://<index>-<project>.svc.<region>.pinecone.io` (path olmadan) |
| Pinecone upsert `400 dimension mismatch` | Index dimension 768 değil | Index'i sil, `dimension=768, metric=cosine` ile yeniden yarat |
| Kayar bant boş | İlk core fetch gecikti | 60 sn bekle; log'da "SmartTicker" satırı check |
| Hisse logosu gelmiyor | CDN gecikmesi | Fallback gradient + baş harfler normal; FMP/IEX/Clearbit tümü down ise yerel gradient kalır |
| BorsaPy SSL hatası | macOS Python 3.13+ CA bundle | `./start.sh` kullan (otomatik fix) |
| Xcode "Device not eligible" | iPhone Apple ID'ne kayıtlı değil | Xcode → Window → Devices → iPhone'u hesaba ekle |
| `git push` 403 | Remote izni yok (bu abonelere özel repo) | Kendi fork'unu aç, `git remote set-url origin` |

---

## 🔐 Güvenlik

- `Secrets.xcconfig` **commit edilmez** (`.gitignore` + `*.xcconfig` catch-all).
- API anahtarları uygulama içinde **Keychain**'e yazılır (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`).
- App Transport Security: sadece `localhost` exception; dış çağrılar zorunlu HTTPS.
- OWASP iOS Top 10 denetim raporu: `tasks/security-audit-2026-04-23.md`.
- Bulduğun açığı DM veya GitHub issue ile bildir.

**Agent güvenlik kuralları:**
- Anahtarları asla commit etme (git status göster, `Secrets.xcconfig` staged ise reddet).
- Kullanıcı şifresini, 2FA'sını, kredi kartını asla tekrarlama (log'a bile yazma).
- `git push --force`, `rm -rf`, `.git` silme gibi geri dönüşsüz işlemleri kullanıcı onayı olmadan yapma.

---

## 📝 Değişiklik kaydı

Sürüm bazlı değişiklikler: [CHANGELOG.md](./CHANGELOG.md)

Son büyük sprint: **2026-04 V5 Tasarım Sprinti + Çoklu kiracı hardening** — Pinecone Secrets-driven, BorsaPy bearer auth, `personalize.sh`, zarif bozulma.

---

## 🤝 Katkı

- Ana dalı korumak için doğrudan push yapma; feature branch + PR.
- `tasks/lessons.md` — tekrar eden hataların kaydı; bir hata yaşadıysan oraya bak + gerekiyorsa ekle.
- Kod standartları: `.claude/CLAUDE.md` (Türkçe kalite kuralları).

---

## 📎 İlgili dosyalar (hızlı referans)

- Personalizasyon: `Scripts/personalize.sh`
- Kurulum örneği: `Secrets.xcconfig.example`
- API Key UI: `argus/Views/Settings/APIKeyCenterView.swift`
- Secret reader: `argus/Services/Secrets.swift`
- Keychain: `argus/Services/Secrets/APIKeyStore.swift`, `argus/Services/Security/KeychainManager.swift`
- BorsaPy server: `Scripts/borsapy_server/README.md`
- Pinecone RAG: `argus/Services/Alkindus/PineconeService.swift`, `argus/Services/Alkindus/AlkindusRAGEngine.swift`
- Tasarım sistemi: `argus/DesignSystem/InstitutionalTheme.swift`, `argus/Views/Components/ArgusDesignKit+V5.swift`
- Değişiklik kaydı: `CHANGELOG.md`
- Güvenlik denetimi: `tasks/security-audit-2026-04-23.md`
