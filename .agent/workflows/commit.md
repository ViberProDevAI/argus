---
description: Temiz build sonrası GitHub commit
---

**Adımlar**

1. Değişiklikleri kontrol et:
   ```bash
   git status
   ```

2. Tüm değişiklikleri stage'le:
   ```bash
   git add .
   ```

3. Anlamlı bir commit mesajı ile commit at:
   ```bash
   git commit -m "[Feature/Fix/Refactor]: Kısa açıklama"
   ```

4. Remote'a push et:
   ```bash
   git push origin main
   ```

**Kurallar**
- API key, şifre veya kişisel bilgi ASLA commit edilmemeli
- Commit mesajları Türkçe ve açıklayıcı olmalı
- Her temiz build sonrası commit zorunlu
