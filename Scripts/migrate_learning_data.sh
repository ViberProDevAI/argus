#!/bin/bash

# ============================================
# LEARNING DATA MIGRATION SCRIPT
# Algo-Trading → Argus
# ============================================

ALGO_DOCS="/Users/erenkapak/Library/Developer/CoreSimulator/Devices/6024487F-6BAC-437D-9880-9D37D80E2800/data/Containers/Data/Application/C33AF206-282B-4B25-BA53-589EDA2EFCCA/Documents"

echo "🔍 Argus uygulamasını arıyorum..."

# En son değiştirilen argus Documents klasörünü bul
ARGUS_DOCS=$(find ~/Library/Developer/CoreSimulator/Devices -type d -name "Documents" 2>/dev/null | while read dir; do
    if ls "$dir" 2>/dev/null | grep -q "argus\|Argus"; then
        echo "$dir"
    fi
done | head -1)

# Alternatif: Bundle ID ile ara
if [ -z "$ARGUS_DOCS" ]; then
    for plist in $(find ~/Library/Developer/CoreSimulator/Devices -name ".com.apple.mobile_container_manager.metadata.plist" 2>/dev/null); do
        if plutil -p "$plist" 2>/dev/null | grep -qi "argus"; then
            ARGUS_DOCS="$(dirname "$plist")/Documents"
            if [ -d "$ARGUS_DOCS" ]; then
                break
            fi
        fi
    done
fi

echo ""
echo "📊 Kaynak Veriler (Algo-Trading):"
echo "================================="
sqlite3 "$ALGO_DOCS/ArgusScience_V1.sqlite" "
SELECT 'events' as tablo, COUNT(*) as kayit FROM events
UNION ALL SELECT 'blobs', COUNT(*) FROM blobs
UNION ALL SELECT 'trades', COUNT(*) FROM trades
UNION ALL SELECT 'lessons', COUNT(*) FROM lessons
UNION ALL SELECT 'weight_history', COUNT(*) FROM weight_history;
" 2>/dev/null || echo "SQLite bulunamadı"

echo ""
if [ -n "$ARGUS_DOCS" ] && [ -d "$ARGUS_DOCS" ]; then
    echo "✅ Argus Documents bulundu: $ARGUS_DOCS"
    echo ""
    echo "📋 Kopyalama başlıyor..."
    
    # SQLite veritabanını kopyala
    if [ -f "$ALGO_DOCS/ArgusScience_V1.sqlite" ]; then
        cp "$ALGO_DOCS/ArgusScience_V1.sqlite" "$ARGUS_DOCS/"
        echo "  ✓ ArgusScience_V1.sqlite kopyalandı"
    fi
    
    # Alkindus memory klasörünü kopyala
    if [ -d "$ALGO_DOCS/alkindus_memory" ]; then
        cp -R "$ALGO_DOCS/alkindus_memory" "$ARGUS_DOCS/"
        echo "  ✓ alkindus_memory/ kopyalandı"
    fi
    
    # ChironDataLake klasörünü kopyala
    if [ -d "$ALGO_DOCS/ChironDataLake" ]; then
        cp -R "$ALGO_DOCS/ChironDataLake" "$ARGUS_DOCS/"
        echo "  ✓ ChironDataLake/ kopyalandı"
    fi
    
    echo ""
    echo "🎉 Veri aktarımı tamamlandı!"
    echo ""
    echo "📁 Argus Documents içeriği:"
    ls -la "$ARGUS_DOCS"
else
    echo "❌ Argus Documents bulunamadı!"
    echo ""
    echo "👉 Çözüm: Xcode'da argus projesini açın ve simülatörde bir kez çalıştırın."
    echo "   Sonra bu scripti tekrar çalıştırın."
fi
