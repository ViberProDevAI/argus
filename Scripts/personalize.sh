#!/usr/bin/env bash
# Scripts/personalize.sh
# -----------------------------------------------------------------------------
# Argus'u kendi Apple Developer hesabına bağlar.
#
# Her abonenin kendi Team ID'si ve Bundle Identifier'ı olduğu için
# project.pbxproj'da geliştiricinin şahsi değerleri hardcoded durur. Bu script
# onları aboneninkilerle değiştirir; yanlış kişinin Team ID'si ile derleme
# yaparsan Xcode "No provisioning profile" hatası verir.
#
# Kullanım (iki mod):
#
#   1) İnteraktif (insan kullanımı için):
#        ./Scripts/personalize.sh
#      Script sana sırasıyla Team ID ve Bundle ID sorar.
#
#   2) Argüman-tabanlı (AI agent / CI kullanımı için):
#        ./Scripts/personalize.sh \
#          --team-id ABCD123456 \
#          --bundle-id com.yourname.argus \
#          [--apple-id you@example.com]   # opsiyonel, sadece yazdırılır
#
#   --dry-run ile hangi değişikliklerin yapılacağını görebilirsin:
#        ./Scripts/personalize.sh --team-id ABCD123456 --bundle-id com.x.y --dry-run
#
# Güvenlik: script project.pbxproj'u yerinde düzenler, önce
# `.xcodeproj/project.pbxproj.bak` dosyasına yedek alır. Yanlış değer
# girdiysen `.bak` dosyasını geri kopyala veya `git checkout --` ile geri al.
# -----------------------------------------------------------------------------

set -euo pipefail

# --- Renkler (TTY varsa) ---
if [[ -t 1 ]]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[0;33m'
    BLUE=$'\033[0;34m'
    BOLD=$'\033[1m'
    RESET=$'\033[0m'
else
    RED=""; GREEN=""; YELLOW=""; BLUE=""; BOLD=""; RESET=""
fi

err()   { printf "%s[hata]%s %s\n" "$RED" "$RESET" "$1" >&2; }
warn()  { printf "%s[uyarı]%s %s\n" "$YELLOW" "$RESET" "$1"; }
info()  { printf "%s[bilgi]%s %s\n" "$BLUE" "$RESET" "$1"; }
ok()    { printf "%s[tamam]%s %s\n" "$GREEN" "$RESET" "$1"; }

usage() {
    cat <<'EOF'
Kullanım:
  Scripts/personalize.sh [--team-id TEAM_ID] [--bundle-id BUNDLE_ID] [--apple-id EMAIL] [--dry-run] [-h|--help]

Argümanlar:
  --team-id TEAM_ID      Apple Developer Team ID (10 karakter, A-Z0-9).
                         Bulma: developer.apple.com → Account → Membership → Team ID.
  --bundle-id BUNDLE_ID  Reverse-DNS form (ör: com.yourname.argus).
                         Benzersiz olmalı; Apple'da aynı bundle ID iki kere register edilemez.
  --apple-id EMAIL       (Opsiyonel) Apple Developer hesabının email'i. project.pbxproj'a
                         yazılmaz — sadece doğrulama çıktısında gösterilir. Apple ID
                         aslında Xcode Preferences → Accounts'tan yönetilir.
  --dry-run              Hiçbir şey yazma, sadece değişecekleri göster.
  -h, --help             Bu yardımı göster.

Argüman verilmezse script interaktif modda çalışır ve sorar.
EOF
}

# --- Parametre parse ---
TEAM_ID=""
BUNDLE_ID=""
APPLE_ID=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --team-id)   TEAM_ID="${2:-}"; shift 2 ;;
        --bundle-id) BUNDLE_ID="${2:-}"; shift 2 ;;
        --apple-id)  APPLE_ID="${2:-}"; shift 2 ;;
        --dry-run)   DRY_RUN=1; shift ;;
        -h|--help)   usage; exit 0 ;;
        *)           err "Bilinmeyen argüman: $1"; usage; exit 2 ;;
    esac
done

# --- Proje kökü tespiti ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PBXPROJ="$PROJECT_ROOT/argus.xcodeproj/project.pbxproj"

if [[ ! -f "$PBXPROJ" ]]; then
    err "argus.xcodeproj/project.pbxproj bulunamadı."
    err "Bu script'i repo kökünden çalıştırdığından emin ol: $PROJECT_ROOT"
    exit 1
fi

# --- Mevcut değerleri oku ---
# project.pbxproj'da `DEVELOPMENT_TEAM = XXXXXXXXXX;` ve
# `PRODUCT_BUNDLE_IDENTIFIER = xxx.yyy.zzz;` satırları bulunur.
# İlk eşleşmeyi alırız (Debug ve Release'de aynı değerdir beklenen).
current_team=$(grep -m1 -E '^[[:space:]]*DEVELOPMENT_TEAM = ' "$PBXPROJ" \
                 | sed -E 's/^[[:space:]]*DEVELOPMENT_TEAM = ([^;]+);.*$/\1/' \
                 | tr -d '"' | tr -d '[:space:]' || true)
current_bundle=$(grep -m1 -E '^[[:space:]]*PRODUCT_BUNDLE_IDENTIFIER = ' "$PBXPROJ" \
                   | sed -E 's/^[[:space:]]*PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);.*$/\1/' \
                   | tr -d '"' | tr -d '[:space:]' || true)

if [[ -z "$current_team" || -z "$current_bundle" ]]; then
    err "project.pbxproj içinde DEVELOPMENT_TEAM veya PRODUCT_BUNDLE_IDENTIFIER bulunamadı."
    err "Repo bozulmuş olabilir. 'git status' kontrol et."
    exit 1
fi

info "Şu anki değerler:"
info "  DEVELOPMENT_TEAM          = $current_team"
info "  PRODUCT_BUNDLE_IDENTIFIER = $current_bundle"

# --- İnteraktif mod (argüman yoksa sor) ---
is_interactive() {
    [[ -t 0 && -t 1 ]]
}

prompt_if_empty() {
    local var_name="$1"
    local label="$2"
    local hint="$3"
    if [[ -z "${!var_name}" ]]; then
        if ! is_interactive; then
            err "$label verilmedi ve script TTY'siz (non-interactive) çalışıyor."
            err "Agent/CI ortamında --team-id ve --bundle-id argümanlarını açıkça ver."
            exit 2
        fi
        printf "\n%s%s%s\n" "$BOLD" "$label" "$RESET"
        printf "  %s\n" "$hint"
        printf "  Değer: "
        IFS= read -r value || true
        value="${value//[[:space:]]/}"
        printf -v "$var_name" '%s' "$value"
    fi
}

prompt_if_empty TEAM_ID \
    "Apple Developer Team ID" \
    "10 karakter büyük harf + rakam. developer.apple.com → Account → Membership → Team ID"

prompt_if_empty BUNDLE_ID \
    "Bundle Identifier" \
    "Reverse-DNS. Örn: com.senin-adın.argus (benzersiz olmalı)"

# Apple ID opsiyonel — sadece interaktif'te sor, boş geçilebilir
if [[ -z "$APPLE_ID" ]] && is_interactive; then
    printf "\n%sApple ID (opsiyonel)%s\n" "$BOLD" "$RESET"
    printf "  Enter'a basarak atlayabilirsin. Sadece doğrulama çıktısında gösterilir.\n"
    printf "  Email: "
    IFS= read -r APPLE_ID || true
fi

# --- Validasyon ---
validate_team_id() {
    if [[ ! "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]; then
        err "Team ID geçersiz: '$TEAM_ID'"
        err "Beklenen: 10 karakter, yalnızca A-Z ve 0-9 (büyük harf)."
        err "Örnek: ABCD123456"
        return 1
    fi
}

validate_bundle_id() {
    # Reverse-DNS: en az iki parça nokta ile ayrılmış, her parça harf/rakam/tire
    # Apple kuralı: ASCII, nokta ile ayrılmış, her segment [a-zA-Z0-9-]
    if [[ ! "$BUNDLE_ID" =~ ^[a-zA-Z][a-zA-Z0-9-]*(\.[a-zA-Z][a-zA-Z0-9-]*)+$ ]]; then
        err "Bundle ID geçersiz: '$BUNDLE_ID'"
        err "Beklenen reverse-DNS: en az iki bileşen, her biri harfle başlar."
        err "Örnek: com.yourname.argus"
        return 1
    fi
}

validate_apple_id() {
    # Boşsa OK (opsiyonel). Doluysa çok temel email kontrolü.
    if [[ -z "$APPLE_ID" ]]; then
        return 0
    fi
    if [[ ! "$APPLE_ID" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]; then
        err "Apple ID email formatı geçersiz: '$APPLE_ID'"
        return 1
    fi
}

validate_team_id
validate_bundle_id
validate_apple_id

# --- Değişiklik özeti ---
printf "\n%sUygulanacak değişiklikler:%s\n" "$BOLD" "$RESET"
printf "  DEVELOPMENT_TEAM           %s  →  %s\n" "$current_team"   "$TEAM_ID"
printf "  PRODUCT_BUNDLE_IDENTIFIER  %s  →  %s\n" "$current_bundle" "$BUNDLE_ID"
if [[ -n "$APPLE_ID" ]]; then
    printf "  Apple ID (info only)       %s\n" "$APPLE_ID"
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
    warn "--dry-run: hiçbir dosya değiştirilmedi."
    exit 0
fi

# Aynı değerler → değişikliğe gerek yok
if [[ "$current_team" == "$TEAM_ID" && "$current_bundle" == "$BUNDLE_ID" ]]; then
    ok "Değerler zaten güncel, değişiklik yapılmadı."
    exit 0
fi

# İnteraktif modda onay al
if is_interactive; then
    printf "\nOnaylıyor musun? [e/H] "
    IFS= read -r confirm || true
    case "$confirm" in
        e|E|y|Y|yes|YES|evet|EVET) ;;
        *) warn "İptal edildi."; exit 0 ;;
    esac
fi

# --- Yedek al ---
BACKUP="$PBXPROJ.bak"
cp "$PBXPROJ" "$BACKUP"
info "Yedek: $BACKUP"

# --- sed ile değiştir ---
# BSD sed (macOS) ve GNU sed (Linux) arasında `-i` davranışı farklı: macOS -i ''
# gerektirir, GNU gerektirmez. Portable yol: -i.tmp kullan, sonra .tmp'yi sil.
sed -E \
    -e "s|^([[:space:]]*DEVELOPMENT_TEAM = )[^;]+;|\1$TEAM_ID;|g" \
    -e "s|^([[:space:]]*PRODUCT_BUNDLE_IDENTIFIER = )[^;]+;|\1$BUNDLE_ID;|g" \
    -i.tmp "$PBXPROJ"
rm -f "$PBXPROJ.tmp"

# --- Doğrula ---
new_team=$(grep -m1 -E '^[[:space:]]*DEVELOPMENT_TEAM = ' "$PBXPROJ" \
             | sed -E 's/^[[:space:]]*DEVELOPMENT_TEAM = ([^;]+);.*$/\1/')
new_bundle=$(grep -m1 -E '^[[:space:]]*PRODUCT_BUNDLE_IDENTIFIER = ' "$PBXPROJ" \
               | sed -E 's/^[[:space:]]*PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);.*$/\1/')

if [[ "$new_team" != "$TEAM_ID" || "$new_bundle" != "$BUNDLE_ID" ]]; then
    err "sed değişikliği beklendiği gibi uygulanmadı."
    err "Yedekten geri yükleniyor..."
    mv "$BACKUP" "$PBXPROJ"
    exit 1
fi

# Değişikliklerin tüm occurrence'larda uygulandığını doğrula
team_count=$(grep -cE "^[[:space:]]*DEVELOPMENT_TEAM = $TEAM_ID;" "$PBXPROJ" || true)
bundle_count=$(grep -cE "^[[:space:]]*PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID;" "$PBXPROJ" || true)

ok "DEVELOPMENT_TEAM değiştirildi ($team_count occurrence)"
ok "PRODUCT_BUNDLE_IDENTIFIER değiştirildi ($bundle_count occurrence)"

printf "\n%sSonraki adımlar:%s\n" "$BOLD" "$RESET"
cat <<EOF
  1) Xcode → Preferences (⌘,) → Accounts → Apple ID'ni ekle${APPLE_ID:+ ($APPLE_ID)}
  2) Proje navigator → argus target → Signing & Capabilities sekmesi
     • Team: listeden senin Team ID'n ($TEAM_ID) seçili olmalı
     • "Automatically manage signing" işaretli kalsın
  3) Xcode provisioning profile'ı otomatik oluşturacak. Bunun için:
     • Cihazı Mac'e bağla (ilk sefer USB gerekli, sonra Wi-Fi yeter)
     • Cihaz Apple ID'ne kayıtlı olmalı (ücretsiz account'ta 3 cihaz limiti)
  4) Secrets.xcconfig'i düzenle (kopyala: Secrets.xcconfig.example)
  5) Xcode'da Product → Build (⌘B) — derleme başarılı olmalıysa
     Product → Run (⌘R) — cihazda başlatır

Yanlış değer girdiysen geri almak için:
  cp $BACKUP $PBXPROJ

Veya git ile:
  git checkout -- argus.xcodeproj/project.pbxproj
EOF

ok "Argus, $BUNDLE_ID bundle kimliği ile Team $TEAM_ID'ye bağlandı."
