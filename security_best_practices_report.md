# Security Best Practices Report

## Executive Summary
Bu denetim, `argus` projesinin repoya açılmadan önce sır/PII sızıntısı ve API key yönetimi açısından gözden geçirilmesi için yapıldı. Çalışma sonunda **repo içinde gerçek API key veya kişisel isim/yol izi kalmadı** (tarama kapsamı: takip edilen dosyalar), API key depolama **UserDefaults -> Keychain** olarak güçlendirildi ve dağınık/çift API key ekranı tek merkeze indirildi.

Bununla birlikte, **Release build ayarlarında Info.plist'e key enjekte eden yapı** halen açık; bu, repoyu değil ama üretilen uygulama paketini tersine mühendislik açısından zayıflatır.

## Critical Findings

### SBP-001 (Remediated): API key’lerin düz metin saklanma riski
**Impact:** Cihaz yedeği / forensic senaryolarında API key’lerin çıkarılabilmesine yol açabilir.

- Önceki risk davranışı: API key kayıtlarının `UserDefaults` üzerinde tutulması.
- Uygulanan düzeltme:
  - Sağlayıcı key’leri ve özel key’ler Keychain’e taşındı.
  - Legacy `UserDefaults` değerleri otomatik migrate ediliyor.
  - Placeholder/değer filtresi eklendi.
- Kanıt:
  - `argus/Services/Secrets/APIKeyStore.swift:43`
  - `argus/Services/Secrets/APIKeyStore.swift:70`
  - `argus/Services/Secrets/APIKeyStore.swift:194`
  - `argus/Services/Data/TCMBDataService.swift:16`

## High Findings

### SBP-002 (Open): Build-time secret injection Info.plist’e yazılıyor (Debug + Release)
**Impact:** Uygulama binary’si içinden key değerleri çıkarılabilir (repo güvenli olsa bile dağıtım artefaktı riski).

- Mevcut durum:
  - Key build değişkenleri `INFOPLIST_KEY_*` ile Info.plist’e basılıyor.
- Kanıt:
  - `argus.xcodeproj/project.pbxproj:261`
  - `argus.xcodeproj/project.pbxproj:278`
  - `argus.xcodeproj/project.pbxproj:317`
  - `argus.xcodeproj/project.pbxproj:334`
- Öneri:
  - Release konfigürasyonunda `INFOPLIST_KEY_*` kullanımını kaldırın.
  - Üretimde yalnızca runtime kullanıcı girişi + Keychain akışını bırakın.

## Medium Findings

### SBP-003 (Remediated): API key yönetiminde çift ekran/dağınık yüzey
**Impact:** Yanlış ekranlardan farklı depolara yazma ve operasyonel karışıklık.

- Uygulanan düzeltme:
  - Heimdall anahtar ekranı merkezi ekrana yönlendirildi.
- Kanıt:
  - `argus/Views/Heimdall/HeimdallKeysView.swift:3`
  - `argus/Views/Settings/APIKeyCenterView.swift:21`

### SBP-004 (Remediated): Takip edilen dosyalarda kişisel mutlak yol izleri
**Impact:** Repo yayınlandığında kullanıcı adı/makine yolu ifşası.

- Uygulanan düzeltme:
  - Kişisel path’ler doküman ve scriptlerden temizlendi/genelleştirildi.
- Kanıt:
  - `Scripts/migrate_learning_data.sh:9`
  - `docs/plans/2026-02-03-ui-redesign-glassmorphic-tabbar.md:102`
  - `.gemini/settings.json:3`

## Validation Performed
- Tracked dosyalarda PII ve secret pattern taraması yapıldı (`/Users/erenkapak`, isim varyasyonları, yaygın API key desenleri).
- `Secrets.xcconfig` dosyasının takip edilmediği doğrulandı.
- Derleme doğrulaması alındı: `BUILD SUCCEEDED`.
- Test doğrulaması: şema test aksiyonu tanımlı değil (`Scheme argus is not currently configured for the test action`).

## Recommended Next Actions
1. Release build’de `INFOPLIST_KEY_*` secret injection’ını kaldır.
2. `xcodebuild test` için şemaya test action + en az smoke test hedefi ekle.
3. İstersen bu rapordaki **SBP-002** maddesini de aynı turda kod/config değişikliğiyle kapatabilirim.
