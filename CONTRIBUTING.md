# Argus'a Katkı Rehberi

Bu rehber Argus'a katkı verecek geliştiriciler için yazılmıştır. `README.md` kurulumu, `ARCHITECTURE.md` mimari kararları anlatır; bu belge **nasıl katkı verileceğini** kapsar: dal stratejisi, commit biçimi, kod beklentileri, test ve gizli bilgi hijyeni.

> 🇬🇧 **English speakers:** all conventions below apply identically. Turkish is the primary language for commits, PR descriptions and inline comments because the original maintainer writes in Turkish; English is welcome and won't be rejected. Bilingual PR descriptions (TR + EN) are preferred for broader contribution.

---

## 0. Önemli ilkeler

1. **Yatırım tavsiyesi değildir.** Argus paper-trading ve eğitim simülasyonudur. Gerçek emir gönderen kod, gerçek aracı entegrasyonu, lisanssız fiyat dağıtımı kabul edilmez. Yeni PR'larda kullanıcıya gösterilen metinlerde model belirsizliği ve veri gecikmesi açıkça belirtilmelidir (`ARCHITECTURE.md §6`).
2. **Yanıltıcı güvenlik yüzeyi yaratma.** Bağlanmamış toggle, çağrılmayan kilit modifier'ı, "şifrelenmiş" iddiasında olan sade `UserDefaults` yazımı, hepsi reddedilir.
3. **"Eksik çalışmasın."** Opsiyonel bir API anahtarı eksikse hata fırlatma; özelliği sessizce devre dışı bırakıp `README.md` "Zarif bozulma" tablosuna ek satır ekle.
4. **Tek facade, çok store.** Yeni özellik için `TradingViewModel`'e satır ekleme. `PortfolioStore` / `MarketDataStore` / yeni odaklı bir `Store` üzerinden geç (`ARCHITECTURE.md §2`).

---

## 1. Geliştirme akışı

### 1.1 Varsayılan dal

Varsayılan dal **`ui/v5-designkit`**'tir, `main` değildir. PR'lar buraya açılır.

```bash
git fetch origin
git checkout ui/v5-designkit
git pull --ff-only
git checkout -b <type>/<short-description>
```

### 1.2 Dal adı kalıbı

`<type>/<kısa-açıklama>`, kebab-case, İngilizce kabul edilir.

| Type | Ne için | Örnek |
|------|---------|-------|
| `feat`  | Yeni özellik / motor / ekran | `feat/phoenix-watchlist-export` |
| `fix`   | Hata düzeltmesi | `fix/marquee-ticker-vix-direction` |
| `chore` | Ölü kod, lint, manifest, build temizliği | `chore/remove-dead-faceid` |
| `refactor` | Davranışı korur, yapıyı değiştirir | `refactor/heimdall-fallback-engine` |
| `docs`  | Yalnızca dokümantasyon | `docs/contributing-guide` |
| `test`  | Yalnızca test ekleme/düzeltme | `test/api-key-store` |
| `perf`  | Performans odaklı | `perf/logo-cache-eviction` |
| `ci`    | GitHub Actions / build script | `ci/ios-runner-destination` |

Tek PR, tek konu. Kod refactor'ünü yeni özellikle aynı PR'a sıkıştırma; review'ı zorlaştırır ve revert riskini artırır.

### 1.3 Fork akışı

Repository sahibi değilsen:

```bash
gh repo fork ViberProDevAI/argus --remote=true --remote-name=fork
git push -u fork <type>/<short-description>
gh pr create --base ui/v5-designkit --head <github-handle>:<branch>
```

---

## 2. Commit mesajı biçimi

Tek satırlık başlık + (gerekirse) boş satır + gövde.

```
<type>: <konu>

<gövde: neden bu değişiklik gerekiyordu, davranış nasıl değişti,
hangi ölçütleri sağlıyor, hangi riskleri taşıyor>
```

- **Başlık imperatif kipte.** "remove dead Face ID code path", "fix marquee ticker direction"; geçmiş zaman değil.
- **Başlık ≤ 72 karakter.** Detay gövdeye gider.
- **Tip prefix'i** dal adıyla aynı tabloyu kullanır.
- **Türkçe / İngilizce karışık** OK; tutarlı olsun (başlık+gövde aynı dilde).
- **Co-author** kullanma; PR'da ayrı görünür, commit'te gerek yok.

### Örnekler (kabul edilen)

```
chore: remove dead Face ID code path

CHANGELOG.md "Karar bekleyen bulgular" maddesinde işaretlenen ölü kod
zinciri kaldırıldı...
```

```
feat(phoenix): add geri-dönüş candidate filter for BIST

KAP'tan gelen revize bilanço sinyali Phoenix puanına +12 ekleyen
yeni bir hesap modülü...
```

### Reddedilen kalıplar

- `WIP` / `fix stuff` / `update` (anlamsız)
- `Merge branch ...` (rebase et)
- API anahtarı, e-posta, kişisel klasör yolu içeren commit mesajı

---

## 3. Gizli bilgi ve kişisel veri

### 3.1 Asla commit edilmez

| Dosya / değer | Neden | Doğru yer |
|---------------|-------|-----------|
| `Secrets.xcconfig` | Tüm API anahtarları | `.gitignore`'da; sadece `.example` commit'lenir |
| Apple Developer Team ID | Kişisel hesap | `Scripts/personalize.sh` ile lokal enjekte |
| Bundle Identifier (kişisel) | Aynı | Aynı |
| `.bak` / `.local.swift` / `.env*` | Geçici | Asla |
| Render / Pinecone host URL'si | Abone-spesifik | `Secrets.xcconfig` |

### 3.2 Yanlışlıkla commit ettiysen

```bash
# Henüz push etmediysen:
git reset --soft HEAD~1
# Dosyayı .gitignore'a ekle, Secrets.xcconfig'e taşı, yeniden commit at.

# Push ettiysen:
# 1) Anahtarı SAĞLAYICI panelinden HEMEN revoke et (rebase yetmez).
# 2) Sonra git filter-repo veya BFG ile geçmişten temizle.
# 3) Force-push öncesi maintainer'a haber ver.
```

`README.md` "Dur-ve-sor noktaları" tablosu da bu kuralı tekrar eder.

---

## 4. Kod beklentileri

### 4.1 Loglama

```swift
// ✅ Doğru: fire-and-forget statik API
ArgusLogger.info("Pinecone upsert ok", category: "RAG")
ArgusLogger.error("FMP 429", category: "Network", error: err)

// ❌ Yanlış: yeni kod print() kullanmaz
print("[DEBUG] something")
```

`ARCHITECTURE.md §4` detayını verir. Mevcut ham `print` çağrılarını ayrı bir cleanup PR'ında dönüştürmek değerlidir; karışık değişikliklerle birlikte gönderme.

### 4.2 Bağımlılık enjeksiyonu

- **Yeni `.shared` singleton ekleme.** Yerine bir `Sendable` protokolü tanımla, üretim implementasyonunu `DIContainer` veya `DependencyValues` üzerinden bağla (`ARCHITECTURE.md §3`).
- Mevcut singleton'a referans veren bir motor eklerken bunu protokol arkasına alma fırsatı varsa al; aksi takdirde yorum bırak: `// TODO(DI): protokol arkasına alınmalı`.

### 4.3 Erişilebilirlik

- Dokunulan tüm interaktif öğeler **44×44 pt minimum tap target** (WCAG 2.5.8) sağlamalıdır:
  ```swift
  Image(systemName: "bell")
      .argusTapTarget("Bildirimler")     // 44×44 hitbox + VoiceOver label
  ```
- `ArgusIconButton` zaten 44×44 + zorunlu `accessibilityLabel` içerir; yeni icon button için onu kullan.
- Yeni veri gösteren bileşenlere `.accessibilityValue(...)` eklenmesi tercih edilir (özellikle Portfolio / DetailResults / TradeBrain ekranları).

### 4.4 SwiftUI ve durum

- **`@StateObject`** sahip olan view oluşturur; aşağı geçirilen view **`@ObservedObject`** veya `@EnvironmentObject` kullanır.
- Yeni `@Published` alanı `TradingViewModel`'e değil, ilgili `Store`'a koyulur (`ARCHITECTURE.md §2`).
- Render tarafında ağır iş yapma; `Task { ... }` ile ofloat et, sonuçları `@MainActor` üstünde uygula.

### 4.5 Modern Xcode 16 ipucu

Proje `PBXFileSystemSynchronizedRootGroup` kullanır; Xcode `argus/` klasörünü filesystem'le otomatik senkron tutar. Yeni `.swift` dosyası eklemek için manuel `pbxproj` düzenlemeye **gerek yok**. Ama:

- **`swift_files.txt` manifestini güncelle.** Repo'nun bağımsız listesi; eklediysen ekle, sildiysen çıkar.

---

## 5. Test

### 5.1 Hangi şema, nereye ekleniyor

- Test hedefi: `argusTests`
- Şema: `argus`
- Lokalde:
  ```bash
  xcodebuild test \
    -project argus.xcodeproj -scheme argus \
    -destination 'platform=iOS Simulator,name=iPhone 16' | xcpretty
  ```
- CI varsayılanı: GitHub Actions, `iPhone 16` simülatörü. Runner'da yoksa `xcodebuild -scheme argus -showdestinations` çıktısına göre `.github/workflows/ios.yml` güncellenir (`ARCHITECTURE.md §5`).

### 5.2 Hangi PR'a test gerekir?

| Değişiklik tipi | Test beklentisi |
|-----------------|-----------------|
| Saf hesap motoru / fiyatlama / validation | **Zorunlu** unit test |
| Yeni `Store` veya facade alanı | Davranışsal smoke test |
| Yeni view-only bileşen | XCTest opsiyonel; manuel doğrulama açıkla |
| Sadece kopya / metin / asset | Test gerekmez |
| `chore` / dead-code remove | Diff salt silme ise gerekmez; davranışı koruyan refactor ise koruyucu snapshot test eklenir |

Yeni bir motor entegrasyonu mock provider ile test edilmelidir; gerçek anahtar gerektiren testler **CI'da skip** olacak şekilde yazılır (`if APIKeyStore.shared.getKey(...) == nil { throw XCTSkip(...) }`).

### 5.3 Mevcut testler

`argusTests/`: `TradeValidatorTests`, `CachePolicyTests`, `SymbolMapperTests`, `MarketViewModelTests`, `TradingViewModelFacadeTests`, `PortfolioViewModelTests`, `SignalViewModelTests`, `PulsingFABViewTests`. Yeni testleri konuya göre var olan dosyaya ekle veya yeni `XYZTests.swift` aç.

---

## 6. Pull Request

### 6.1 Hedef dal

`ui/v5-designkit`, `main` değildir. (Maintainer ileride değiştirirse README "Durum" bölümü güncellenir.)

### 6.2 PR şablonu

`.github/pull_request_template.md` PR oluştururken otomatik dolar. Şu alanları doldur:

- **Özet (TR + EN, 2-4 cümle):** ne, neden, gözlemlenebilir etki.
- **Değişiklikler:** silinen / eklenen / düzenlenen dosyalar liste halinde.
- **Doğrulama:** hangi test, hangi simülatör, hangi VoiceOver / Dynamic Type taraması yapıldı.
- **Risk:** geri alma kolay mı? UserDefaults / Keychain'de orphan veri kalır mı? Hangi sağlayıcı çağrılarına etki eder?
- **CHANGELOG.md:** kullanıcıya etki eden değişiklik için ilgili numaralı bölüme bir madde ekle. "Karar bekleyen" → "Bu turda kapatılan" geçişlerini ihmal etme.
- **ARCHITECTURE.md §7 status table:** büyük PR'larda satır eklenir/güncellenir.

### 6.3 Boyut

- **<400 değişen satır** ideal: review hızlı, revert kolay.
- **>1000 satır:** gerekçesi gövdede açıklanır (büyük rename / rewrite). Mümkünse alt-PR'lara bölünür.
- Generated dosyalar (asset PNG, plist) sayım dışıdır; not düş.

### 6.4 İnceleme öncesi checklist

PR açmadan önce kendi diff'ine bakıp gör:

- [ ] Secrets / API key / kişisel Team ID yok
- [ ] `print(` çağrısı yok (yeni kod) → `ArgusLogger`
- [ ] Yeni `.shared` singleton yok → protokol + DI
- [ ] Yeni interaktif öğelerde `.argusTapTarget(_:)` veya `ArgusIconButton`
- [ ] `swift_files.txt` güncellendi (yeni/silinen Swift dosyası varsa)
- [ ] Lokal `xcodebuild build` `BUILD SUCCEEDED`
- [ ] Test eklendi/güncellendi (uygulanabilirse)
- [ ] CHANGELOG entry (uygulanabilirse)
- [ ] PR başlığı commit başlığıyla aynı kalıpta

---

## 7. Code review beklentileri

- **Reviewer'ın işi yok kabul etme.** Açıklayıcı bir gövde + kendin yaptığın doğrulama notu, geri-dönüş döngüsünü kısaltır.
- **Atomic commit'ler tutmak iyidir** ama PR merge'ünde squash genellikle tercih edilir. Maintainer karar verir.
- **Force-push** local cleanup için OK; `main` veya `ui/v5-designkit`'e asla.
- **Çakışmalar** rebase ile çözülür (`git pull --rebase origin ui/v5-designkit`), merge commit ile değil.

---

## 8. Sorular

- Yapısal soru: bir GitHub Issue aç, `question` etiketi ekle.
- Mimari karar: `ARCHITECTURE.md`'ye yansıması olan değişiklikleri PR açmadan kısa bir Issue ile tartış.
- Güvenlik bildirimi: Issue açma, maintainer'a doğrudan ulaş (`README.md`'deki iletişim).

Katkıların için teşekkürler. Argus'un ufak da olsa her iyileştirmesi 100+ aboneye dokunuyor.
