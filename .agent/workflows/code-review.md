---
description: Kod inceleme ve kalite kontrol süreci
---

**Adımlar**

1. **Mimari Kontrol:**
   - Tek sorumluluk ilkesi korunuyor mu?
   - Modül sınırları net mi?
   - Çapraz bağımlılık var mı?

2. **Güvenlik Kontrolü:**
   - API key veya sır var mı?
   - PII loglanıyor mu?
   - Input validation yapılıyor mu?

3. **Performans Kontrolü:**
   - N+1 sorgu var mı?
   - Gereksiz hesaplama veya render var mı?
   - Bellek sızıntısı riski var mı?

4. **Swift/SwiftUI Best Practices:**
   - @Observable yerine ObservableObject kullanılmış mı?
   - Deprecated API'ler var mı?
   - State management doğru mu?

5. **Dokümantasyon:**
   - Fonksiyonlar dokümante edilmiş mi?
   - API değişiklikleri changelog'da mı?
