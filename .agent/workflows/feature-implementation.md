---
description: Yeni özellik geliştirme süreci
---

**Adımlar**

1. **Araştırma (Önce düşün!):**
   - Konuyu araştır, tahmin üzerine çözüm üretme
   - Mevcut koda etki analizi yap
   - Kullanıcıyla sohbet modunda planı kararlaştır

2. **Planlama:**
   - implementation_plan.md oluştur
   - UI değişiklikleri için kullanıcıyla onay al
   - Bağımlılıkları belirle

3. **Uygulama:**
   - Küçük, atomik değişiklikler yap
   - Her değişiklik sonrası build al
   - Hataları düzeltmeden devam etme

4. **Test:**
   - Unit test ekle
   - UI test ekle (kritik akışlar için)
   - Manuel test yap

5. **Doğrulama:**
   - Build success al
   - Test success al
   - Commit at

**Kurallar**
- Her yeni model arayüzde yer bulmalı
- Uzun satır sayıları oluşturma
- Magic number/string kullanma
