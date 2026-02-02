#!/bin/bash
echo "🚀 Argus Build & Commit Başlatılıyor..."
cd "$(dirname "$0")"

# Git Ekleme ve Commit
echo "📦 Değişiklikler git'e ekleniyor..."
git add .
git commit -m "feat: Wisdom Quotes - Loading ve Empty state entegrasyonu tamamlandı" || echo "⚠️ Commit yapılamadı veya değişiklik yok."

# Build İşlemi
echo "🛠 Build alınıyor..."
# Simulator ID'si veya ismi değişebilir, genel bir build deniyoruz
xcodebuild -workspace argus.xcworkspace -scheme argus -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

if [ $? -eq 0 ]; then
    echo "✅ BUILD SUCCESS! Harika iş."
else
    echo "❌ BUILD FAILED. Lütfen yukarıdaki hataları kontrol edin."
fi
