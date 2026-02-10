#!/bin/bash
set -euo pipefail

# ============================================
# LEARNING DATA MIGRATION SCRIPT
# Algo-Trading → Argus
# ============================================

find_source_docs() {
    find "$HOME/Library/Developer/CoreSimulator/Devices" -type d -name "Documents" 2>/dev/null | while read -r dir; do
        if [ -f "$dir/ArgusScience_V1.sqlite" ]; then
            printf "%s\n" "$dir"
        fi
    done | head -1
}

find_target_docs() {
    find "$HOME/Library/Developer/CoreSimulator/Devices" -type d -name "Documents" 2>/dev/null | while read -r dir; do
        if ls "$dir" 2>/dev/null | grep -qiE "argus"; then
            printf "%s\n" "$dir"
        fi
    done | head -1
}

ALGO_DOCS="${ALGO_DOCS:-$(find_source_docs)}"
ARGUS_DOCS="${ARGUS_DOCS:-$(find_target_docs)}"

echo "🔍 Argus uygulamasını arıyorum..."

# Alternatif: Bundle ID ile ara
if [ -z "$ARGUS_DOCS" ]; then
    for plist in $(find "$HOME/Library/Developer/CoreSimulator/Devices" -name ".com.apple.mobile_container_manager.metadata.plist" 2>/dev/null); do
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
if [ -n "$ALGO_DOCS" ] && [ -f "$ALGO_DOCS/ArgusScience_V1.sqlite" ]; then
    sqlite3 "$ALGO_DOCS/ArgusScience_V1.sqlite" "
    SELECT 'events' as tablo, COUNT(*) as kayit FROM events
    UNION ALL SELECT 'blobs', COUNT(*) FROM blobs
    UNION ALL SELECT 'trades', COUNT(*) FROM trades
    UNION ALL SELECT 'lessons', COUNT(*) FROM lessons
    UNION ALL SELECT 'weight_history', COUNT(*) FROM weight_history;
    " 2>/dev/null || echo "SQLite sorgusu calistirilamadi"
else
    echo "❌ Kaynak veritabanı bulunamadı."
fi

echo ""
if [ -n "$ALGO_DOCS" ] && [ -d "$ALGO_DOCS" ] && [ -n "$ARGUS_DOCS" ] && [ -d "$ARGUS_DOCS" ]; then
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
    echo "❌ Kaynak veya hedef Documents klasörü bulunamadı!"
    echo ""
    echo "👉 Cozum:"
    echo "   1) Eski uygulamayi ve Argus'u simulator'da bir kez acin."
    echo "   2) Gerekirse manuel yol verin:"
    echo "      ALGO_DOCS=\"/path/to/source/Documents\" ARGUS_DOCS=\"/path/to/target/Documents\" ./Scripts/migrate_learning_data.sh"
fi
