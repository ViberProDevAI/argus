# 🏗️ Argus Projesi - Mimarı Güvenliği Rehberi

Argus iOS projesinde mimarı kaliteyi yüksek tutmak için oluşturulan kapsamlı rehberleri burada bulacaksınız.

## 📚 Dosyalar

### 1. **CLAUDE.md** (912 satır) - KAPSAMLI REHBER
**Tüm kuralları, standartları ve sorunları içerir.**

Bölümler:
- Proje özeti
- 10 kod standartları bölümü
- ⚠️ **7 KRITIK MİMARİ SORUNU** (detaylı)
  - God Objects
  - Multiple Sources of Truth
  - Navigation kayboluşu
  - Tight Coupling
  - State Management Chaos
  - Ölü kod ve deprecated API'lar
  - Bağlantısız modüller
- Git iş akışı
- Test ve kalite
- Mimarî karar ağacı
- Red flags ve best practices
- Kalite metrikleri

**Ne zaman oku?**
- Yeni projeye katıldığında
- Mimarî sorunlarla karşılaştığında
- Best practices'i öğrenmek istediğinde

---

### 2. **MIMARI_OZET.md** (210 satır) - HIZLI REFERANS
**CLAUDE.md'nin kısa özeti - 5 dakikada**

İçerir:
- 7 kritik sorunun özeti
- Çözüm stratejisi (priority sırası)
- Before/While/After kontrol listesi
- Red flags tablosu
- Best practices örnekleri
- Kalite metrikleri
- Başlama adımları

**Ne zaman oku?**
- Hızlı bir problemi çözmek istediğinde
- Kontrol listesini gerçekleştirmek istediğinde
- Metrikler hakkında düşünmek istediğinde

---

### 3. **ARCHITECTURE_CHECKLIST.md** (281 satır) - PRATIK KONTROL LİSTESİ
**Her feature yazarken kullanılmalı!**

İçerir:
- Before Code: Tasarım aşaması (kontrol listesi)
- While Coding: Geliştirme aşaması (her 50 satırda kontrol)
- After Coding: Review aşaması (son kontrol)
- Red flags tablosu
- Mimarî karar ağacı
- God Object test
- Coupling test
- Kalite metrikleri hedefleri

**Ne zaman oku?**
- **HER YENİ FEATURE YAZARKEN** ✅
- Code review yaparken
- Refactor yaparken

---

## 🎯 HIZLI BAŞLAMA

### İlk Defa Mı?
1. CLAUDE.md'nin "Mimarî Güvenliği" bölümünü oku (1 saat)
2. MIMARI_OZET.md'yi gözden geçir (15 dakika)
3. ARCHITECTURE_CHECKLIST.md'yi bookmark'la

### Yeni Feature Yazacak Mısın?
1. ARCHITECTURE_CHECKLIST.md'yi aç
2. **BEFORE CODE** bölümünü tamamla
3. Tasarım dokümantasyonu yaz
4. Kodlarken **WHILE CODING** kontrol listesini kullan
5. **AFTER CODING** ile bitir

### Mimarî Sorunla Karşılaşırsan?
1. MIMARI_OZET.md'deki "7 Kritik Sorun" bölümüne bak
2. İlgili sorunun çözümünü CLAUDE.md'de oku
3. ARCHITECTURE_CHECKLIST.md'deki Red Flags kontrol et

---

## 🚨 7 KRITIK SORUN (Özet)

| # | Sorun | Dosya | Satır |
|---|-------|-------|-------|
| 1 | God Objects | TradingViewModel | 1,459 |
| 2 | Multiple SSOT | UnifiedDataStore | 383 |
| 3 | Navigation kayboluşu | DeepLinkManager | 41 |
| 4 | Tight Coupling | ArgusDecisionEngine | 866 |
| 5 | State Management Chaos | UnifiedDataStore observers | 7 sink |
| 6 | Ölü kod & Deprecated | 50 dosya | 121 TODO |
| 7 | Bağlantısız modüller | Orphaned Labs | 108/103 view |

**Çözüm Önceliği:**
1. ⚠️ UnifiedDataStore kaldır (SSOT konsodlasyonu)
2. ⚠️ TradingViewModel'i böl (GOD OBJECT)
3. ⚠️ Navigation router oluştur (103 orphaned view)
4. 🟡 ArgusDecisionEngine'i böl (500-line function)
5. 🟡 Singleton → DI (testability)
6. 🟢 Deprecated API migration
7. 🟢 TODO'ları backlog'a taşı

---

## ✅ KONTROL LİSTESİ ÖZET

### Before Feature:
```
- [ ] ViewModel 300+ satırı geçecek mi?
- [ ] 3+ service'e bağlanıyor mu?
- [ ] Aynı veri başka yerde tutulmuş mu?
- [ ] Navigation path'ı ekledim mi?
- [ ] Dependency injection yapacak mıyım?
```

### While Feature:
```
- [ ] ViewModel 300+ satırı geçti mi?
- [ ] 5+ .shared instance var mı?
- [ ] objectWillChange.send() tüm veriyi broadcast'liyor mu?
- [ ] Modal state var ama trigger yok mu?
- [ ] Test yazabiliyorum mu?
```

### After Feature:
```
- [ ] Başka ViewModel'i observe ediyorum mu?
- [ ] Deprecated API kullandığı var mı?
- [ ] TODO koydum mu?
- [ ] Placeholder kod var mı?
```

---

## 🎓 TEMEL KURALLAR

### 1. **Bir ViewModel = BİR Görev**
```
❌ TradingViewModel (30 @Published, 54 fonksiyon)
✅ PortfolioViewModel (sadece portfolio)
   MarketViewModel (sadece market)
   SignalViewModel (sadece signals)
```

### 2. **SSOT - Single Source of Truth**
```
❌ PortfolioStore + UnifiedDataStore.portfolio (duplicate)
✅ PortfolioStore (true source)
   Views PortfolioStore'u observe et
```

### 3. **Dependency Injection**
```
❌ ChironRegimeEngine.shared (hard-coded)
✅ init(regimeEngine: RegimeEngine) { ... }
```

### 4. **Granular State Updates**
```
❌ objectWillChange.send() // tüm app re-render
✅ @Published var quotes = [] // sadece quotes update
   @Published var portfolio = Portfolio() // sadece portfolio
```

### 5. **Navigation = Enum Mapping**
```
❌ DeepLinkManager (3 fonksiyon, 103 orphaned)
✅ enum NavigationDestination { case home, market, ... }
   // tüm 108 view
```

---

## 📊 KALİTE HEDEFLERİ

| Metrik | Hedef | Şu Anki | Durum |
|--------|-------|--------|-------|
| Max ViewModel satırı | 300 | 1,459 | 🔴 |
| Max Service satırı | 500 | 866 | 🟡 |
| Service dependencies | < 3 | 5+ | 🔴 |
| SSOT per domain | 1 | 3-4 | 🔴 |
| Test coverage | > 60% | ? | ❓ |
| Deprecated API usage | 0% | 3 | 🔴 |
| TODO count | < 20 | 121 | 🔴 |
| Navigation accessible | 100% | 5% | 🔴 |

---

## 🛠️ KULLANLAN KOMUTLAR

```bash
# Dosyaları kontrol et
ls -la *.md

# CLAUDE.md'deki mimarî bölümü oku
grep -A 20 "MİMARİ GÜVENLİĞİ" CLAUDE.md

# Tüm TODO'ları listele
git grep "TODO:" --line-number | wc -l

# God object'leri bul (300+ satır ViewModel)
find . -name "*ViewModel.swift" -exec wc -l {} + | sort -rn | head -10
```

---

## 🚀 SONRAKI ADIMLAR

### İmmediately (Bu hafta):
- [ ] CLAUDE.md'nin Mimarî Güvenliği bölümünü tüm takım okudu
- [ ] ARCHITECTURE_CHECKLIST.md'yi bookmark'la
- [ ] Kendi profilinde RED FLAGS'i gözüne al

### Short Term (Bu ay):
- [ ] Yeni feature'lar ARCHITECTURE_CHECKLIST.md ile yazılsın
- [ ] Code review'ler Red Flags kontrol listesi ile yapılsın
- [ ] Deprecated API'ları yeni sürümlerine geç

### Medium Term (Bu çeyrek):
- [ ] UnifiedDataStore'u kaldır (Priority 1)
- [ ] TradingViewModel'i böl (Priority 2)
- [ ] Navigation router oluştur (Priority 3)

### Long Term (Bu yıl):
- [ ] Tüm göds object'leri refactor et
- [ ] Singleton'ları dependency injection'a çevir
- [ ] Test coverage > 60%'e çıkar
- [ ] Tüm metrikleri 🟢 yap

---

## 📞 Sorular?

Eğer mimarî hakkında sorulan var:
1. CLAUDE.md'de ara
2. MIMARI_OZET.md kontrol et
3. ARCHITECTURE_CHECKLIST.md'deki Red Flags bak
4. Hala emin değilsen, CLAUDE.md'nin "Mimarî Karar Ağacı" bölümünü kullan

---

## 📝 Son Not

Bu rehberlerin amacı:
- ✅ God object'lerden kaçınmak
- ✅ Veri sync hatalarını önlemek
- ✅ Navigation kayboluşunu çözmek
- ✅ Test edilebilir kod yazılmasını sağlamak
- ✅ Refactor'lanabilir mimarı
- ✅ Takım içinde tutarlı kalite

**Kendinize sorun:**
- "Bu ViewModel 1 sorumluluk mü taşıyor?"
- "Bu veri başka yerde mi tutulmuş?"
- "Bunu test edebilir miyim?"
- "5+ `.shared` instance mi var?"

Eğer hayır dersen, tasarım hatalı. Dur ve gözden geçir!

---

**Yazıldı**: Şubat 2, 2026
**Versiyon**: 1.0
**Durum**: 🟢 Aktif kullanım
