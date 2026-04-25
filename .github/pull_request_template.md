<!--
  PR şablonu — tüm bölümleri doldur. Doldurulmamış başlıklar review'ı yavaşlatır.
  PR açmadan önce CONTRIBUTING.md §6.4 checklist'i kendi diff'ine uygula.
-->

## Özet (TR)

<!-- 2-4 cümle. Ne değişti, neden gerekiyordu, kullanıcı hangi farkı görür. -->

## Summary (EN)

<!-- Optional but encouraged. Same content, briefly, in English. -->

## Değişiklikler

<!-- Markdown listesi. "Silinen / Eklenen / Düzenlenen" gruplarını kullan. -->

**Eklenen:**
- 

**Düzenlenen:**
- 

**Silinen:**
- 

## Doğrulama

<!-- Hangi test çalıştı, hangi simülatörde, hangi senaryoyu manuel denedin? -->

- [ ] `xcodebuild build` lokalde `BUILD SUCCEEDED`
- [ ] `xcodebuild test -scheme argus` (varsa ilgili test eklendi/güncellendi)
- [ ] iPhone 16 simulator manuel smoke (uygulama açılıyor, etkilenen ekran çalışıyor)
- [ ] VoiceOver / Dynamic Type taraması (UI değişikliği ise)
- [ ] Sızıntı taraması: `git diff` üzerinde API key / Team ID / kişisel yol yok

## Risk ve geri alma

<!-- Geri alma kolay mı? UserDefaults / Keychain'de orphan veri kalır mı?
     Hangi API sağlayıcıyı etkiler? Down-stream PR'ları kırar mı? -->

**Risk seviyesi:** düşük / orta / yüksek

**Geri alma planı:** 

## CHANGELOG.md

<!-- Kullanıcıya etki eden değişiklik mi? İlgili bölüme satır ekle ve buraya da iliştir. -->

- [ ] CHANGELOG güncellendi
- [ ] Gerek yok (sadece test / docs / dahili refactor)

## ARCHITECTURE.md

<!-- Mimari karar değişiyor mu? §7 status table satırı eklendi/güncellendi mi? -->

- [ ] ARCHITECTURE.md güncellendi
- [ ] Gerek yok

## Bağlantılı issue / önceki PR

<!-- "Closes #123" / "Fixes #45" / "Refs #78" -->
