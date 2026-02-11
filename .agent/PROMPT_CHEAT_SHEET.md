# 🚀 Antigravity iOS/Swift Prompt Cheat-Sheet

## 📱 iOS Geliştirme Promptları

### SwiftUI Bileşen Oluşturma
```
"[Bileşen adı] için SwiftUI view oluştur:
- @Observable kullan (ObservableObject değil)
- Modern API'leri tercih et (NavigationStack, foregroundStyle)
- Accessibility desteği ekle
- Dark mode uyumlu olsun"
```

### MVVM Refactoring
```
"Bu view'ı MVVM pattern'ına refactor et:
- ViewModel'i @Observable olarak oluştur
- Business logic'i View'dan ayır
- Dependency injection kullan
- Unit test yazılabilir hale getir"
```

### Performance Optimizasyonu
```
"Bu kodu performans için optimize et:
- LazyVStack/LazyHStack kullan
- Gereksiz re-render'ları önle
- State management'ı iyileştir
- Memory leak kontrolü yap"
```

---

## 🛠️ Kod Kalitesi Promptları

### Clean Code İncelemesi
```
"Bu kodu clean code prensiplerine göre incele:
- SRP (Tek Sorumluluk)
- DRY (Tekrardan Kaçın)
- KISS (Basit Tut)
- Magic number/string kontrolü"
```

### Güvenlik Kontrolü
```
"Bu kodu güvenlik açısından incele:
- API key veya sır var mı?
- Input validation yapılıyor mu?
- Keychain kullanımı doğru mu?
- Network güvenliği sağlam mı?"
```

### Debug Yardımı
```
"Bu hatayı debug et:
[Hata mesajını yapıştır]
- Kök nedeni bul
- Çözüm öner
- Gelecekte önleme stratejisi sun"
```

---

## 🏗️ Mimari Promptları

### Yeni Özellik Tasarımı
```
"[Özellik adı] için mimari tasarım yap:
- Mevcut yapıya uyumlu olsun
- Modüler ve test edilebilir olsun
- Performans etkisini değerlendir
- Bağımlılıkları belirle"
```

### Modül Çıkarma
```
"Bu kodu ayrı bir modüle çıkar:
- Bağımlılıkları analiz et
- Interface'leri tanımla
- Breaking change kontrolü yap
- Migration planı öner"
```

---

## 📝 Dokümantasyon Promptları

### Kod Açıklama
```
"Bu kodu detaylıca açıkla:
- Ne yapıyor?
- Nasıl çalışıyor?
- Neden bu şekilde yazılmış?
- İyileştirme önerileri"
```

### API Dokümantasyonu
```
"Bu fonksiyon/sınıf için dokümantasyon oluştur:
- Amaç ve kullanım
- Parametreler ve dönüş değeri
- Örnek kullanım
- Edge case'ler"
```

---

## ⚡ Hızlı Komutlar

| Komut | Açıklama |
|-------|----------|
| `/build-test` | Build al ve test çalıştır |
| `/commit` | Temiz build sonrası commit |
| `/code-review` | Kod inceleme süreci |
| `/feature-implementation` | Yeni özellik geliştirme |

---

## 🎯 Sohbet Modu İpuçları

**Sohbet moduna geçmek için:**
- Yeni bir konuda fikir sorduğunuzda
- Akıl yürütme ve beyin fırtınası yaparken
- "Ne düşünüyorsun?" gibi sorular sorduğunuzda

**Sohbet modunda:**
- Hemen işe koyulmak yerine tartışma yapılır
- Alternatifler değerlendirilir
- Kararlar birlikte alınır

---

## 📋 Checklist: Kod Yazımı Öncesi

- [ ] Konuyu araştırdım, tahmin üzerine değil
- [ ] Kullanıcıyla planı kararlaştırdım
- [ ] Mevcut yapıya etkiyi analiz ettim
- [ ] Test stratejisi belirledim

## 📋 Checklist: Kod Yazımı Sonrası

- [ ] Build success aldım
- [ ] Testler geçti
- [ ] API key/şifre yok
- [ ] Commit attım
