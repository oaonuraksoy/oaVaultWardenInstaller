#!/usr/bin/env bash
# ==============================================================================
# 🛡️ Vaultwarden (Bitwarden) Kurulum Sihirbazı - Debian & Ubuntu
# Sürüm: 1.37.1 | Uyumlu Sistemler: Debian 11/12, Ubuntu 20.04/22.04/24.04
# ==============================================================================

set -eo pipefail

# Renk Tanımlamaları
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${CYAN}${BOLD}"
echo "================================================================="
echo "   🛡️  VAULTWARDEN (BITWARDEN) DOCKER KURULUM SİHİRBAZI        "
echo "   🍥 Uyumlu Sistem: Debian & Ubuntu                             "
echo "================================================================="
echo -e "${NC}"

# 1. ROOT / SUDO YETKİ KONTROLÜ VE OTOMATİK YÜKSELTME
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}⚠️  Bu kurulum scripti sistem seviyesinde (Docker, APT, Systemd, /opt) işlem yaptığı için ROOT/SUDO yetkisi gerektirir.${NC}"
    if command -v sudo &>/dev/null; then
        echo -e "${CYAN}🔄 'sudo' yetkisi ile otomatik olarak yeniden başlatılıyor...${NC}\n"
        exec sudo bash "$0" "$@"
    else
        echo -e "${RED}❌ 'sudo' komutu bulunamadı. Lütfen doğrudan 'root' kullanıcısına geçerek çalıştırınız: su - ve ardından bash $0${NC}"
        exit 1
    fi
fi

# Gerçek kullanıcıyı tespit et (Sudo ile çağrılsa dahi asıl kullanıcı haklarını korumak için)
REAL_USER="${SUDO_USER:-$USER}"
REAL_GROUP=$(id -gn "$REAL_USER" 2>/dev/null || echo "root")


# 2. İŞLETİM SİSTEMİ KONTROLÜ (Debian / Ubuntu)
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo -e "${BLUE}ℹ️  Tespit Edilen İşletim Sistemi:${NC} ${BOLD}$PRETTY_NAME${NC}"
fi

# 3. DOCKER KURULUM VE SERVİS KONTROLÜ (APT Tabanlı)
echo -e "\n${BLUE}🔍 [1/6] Docker ve Servis Durumları Kontrol Ediliyor...${NC}"

# A) Docker Binary Kontrolü
if ! command -v docker &>/dev/null; then
    echo -e "${YELLOW}⚠️  Docker sistemi üzerinde kurulu değil.${NC}"
    read -r -p "Otomatik olarak kurulup başlatılsın mı? [E/h]: " install_docker_choice
    install_docker_choice=${install_docker_choice:-E}
    if [[ "$install_docker_choice" =~ ^[Ee]$ ]]; then
        echo -e "${CYAN}🚀 Docker CE ve Docker Compose eklentisi kuruluyor (APT)...${NC}"
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y
        apt-get install -y ca-certificates curl gnupg lsb-release
        
        # Resmi Docker Kurulum Scripti (Debian/Ubuntu için en kararlı yöntem)
        curl -fsSL https://get.docker.com | sh
        
        systemctl enable --now docker
        echo -e "${GREEN}✅ Docker başarıyla kuruldu ve aktif edildi.${NC}"
    else
        echo -e "${RED}❌ Docker olmadan kuruluma devam edilemez. Çıkılıyor.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ Docker Binary Tespit Edildi: $(docker --version)${NC}"
fi

# B) Docker Daemon / Servis Çalışma Durumu Kontrolü
echo -e "${CYAN}🔄 Docker servisinin çalışma durumu denetleniyor...${NC}"
if ! systemctl is-active --quiet docker; then
    echo -e "${YELLOW}⚠️  Docker servisi durdurulmuş (inactive) durumda! Başlatılıyor...${NC}"
    systemctl enable --now docker 2>/dev/null || systemctl start docker 2>/dev/null || true
    sleep 3
fi

# C) Docker Daemon İletişim / Soket Testi
if docker info &>/dev/null; then
    echo -e "${GREEN}✅ Docker Daemon (Servis) Aktif ve Sağlıklı Çalışıyor.${NC}"
else
    echo -e "${RED}❌ Docker servisi başlatılamadı veya Docker soketine erişilemiyor!${NC}"
    echo -e "${YELLOW}Servis Durumu:${NC}"
    systemctl status docker --no-pager || true
    echo -e "${RED}Lütfen Docker servisini kontrol edip tekrar deneyiniz.${NC}"
    exit 1
fi

# D) Docker Compose Kontrolü
if docker compose version &>/dev/null; then
    DOCKER_COMPOSE_CMD="docker compose"
elif command -v docker-compose &>/dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
else
    echo -e "${YELLOW}Docker Compose eklentisi bulunamadı. Kuruluyor...${NC}"
    apt-get update -y && apt-get install -y docker-compose-plugin 2>/dev/null || (curl -SL https://github.com/docker/compose/releases/download/v2.29.1/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose)
    DOCKER_COMPOSE_CMD="docker compose"
fi
echo -e "${GREEN}✅ Docker Compose Hazır: $($DOCKER_COMPOSE_CMD version 2>/dev/null || echo 'OK')${NC}\n"

# 4. DİNAMİK BOŞ PORT TESPİT FONKSİYONU
find_free_port() {
    local start_port=${1:-8080}
    while :; do
        if ! ss -tulpn 2>/dev/null | grep -q ":$start_port " && ! netstat -tulpn 2>/dev/null | grep -q ":$start_port "; then
            echo "$start_port"
            return 0
        fi
        ((start_port++))
    done
}

AUTO_FREE_PORT=$(find_free_port 8080)

# 5. KULLANICIDAN BİLGİ ALMA (İNTERAKTİF SORULAR)
echo -e "${BLUE}📝 [2/6] Kurulum Yapılandırması ve Parametreler:${NC}"

# Soru 1: Kurulum Dizini
DEFAULT_INSTALL_DIR="/opt/vaultwarden"
read -r -p "1. Kurulum Dizini [$DEFAULT_INSTALL_DIR]: " INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-$DEFAULT_INSTALL_DIR}

# Soru 2: Alan Adı (Domain / URL)
read -r -p "2. Vaultwarden Alan Adı (Örn: vault.ornekdomain.com): " USER_DOMAIN
while [ -z "$USER_DOMAIN" ]; do
    echo -e "${RED}⚠️ Alan adı boş bırakılamaz (Passkey/FIDO2 ve istemci uyumluluğu için gereklidir).${NC}"
    read -r -p "Vaultwarden Alan Adı: " USER_DOMAIN
done

# Domain başına https:// ekleme
if [[ ! "$USER_DOMAIN" =~ ^https?:// ]]; then
    VAULT_DOMAIN="https://$USER_DOMAIN"
else
    VAULT_DOMAIN="$USER_DOMAIN"
fi

# Soru 3: Dış Port (Host Port)
echo -e "\n   ${CYAN}ℹ️  Otomatik tespit edilen ilk boş port: ${BOLD}$AUTO_FREE_PORT${NC}"
read -r -p "3. Kullanılacak Dış (Host) Port [$AUTO_FREE_PORT]: " CHOSEN_PORT
CHOSEN_PORT=${CHOSEN_PORT:-$AUTO_FREE_PORT}

# Soru 4: Yönetici Paneli Şifresi (Admin Token)
echo -e "\n   ${CYAN}ℹ️  /admin paneli için güçlü bir şifre giriniz (Otomatik Argon2id hash üretilecektir).${NC}"
read -r -s -p "4. Admin Paneli Şifresi (Boş bırakılırsa rastgele 24 karakter üretilir): " ADMIN_PASS_INPUT
echo ""

if [ -z "$ADMIN_PASS_INPUT" ]; then
    ADMIN_PASS_INPUT=$(tr -dc A-Za-z0-9!#%_ 2>/dev/null </dev/urandom | head -c 24 || openssl rand -base64 18)
    GENERATED_RANDOM_PASS=true
else
    GENERATED_RANDOM_PASS=false
fi

echo -e "${CYAN}🔑 Argon2id hash üretiliyor (vaultwarden/server:1.37.1 kullanılarak)...${NC}"
RAW_HASH=$(echo -n "$ADMIN_PASS_INPUT" | docker run --rm -i vaultwarden/server:1.37.1 /vaultwarden hash 2>/dev/null | tr -d '\r\n')

if [ -z "$RAW_HASH" ] || [[ ! "$RAW_HASH" =~ "argon2" ]]; then
    RAW_HASH=$(echo -n "$ADMIN_PASS_INPUT" | docker run --rm -i vaultwarden/server:latest /vaultwarden hash 2>/dev/null | tr -d '\r\n')
fi

# Docker Compose için '$' karakterlerini '$$' yap
ESCAPED_ADMIN_TOKEN="${RAW_HASH//\$/\$\$}"

# Soru 5: Yeni Kayıtlara İzin Verilsin mi?
echo -e "\n5. Yeni kullanıcı kayıtları açık olsun mu?"
echo "   (Öneri: İlk hesabınızı açmak için 'Evet' yapın, hesabınızı açtıktan sonra kapatın)"
read -r -p "   Kayıtlar açık olsun mu? [E/h] (Varsayılan: Evet): " SIGNUPS_CHOICE
SIGNUPS_CHOICE=${SIGNUPS_CHOICE:-E}
if [[ "$SIGNUPS_CHOICE" =~ ^[Ee]$ ]]; then
    SIGNUPS_ALLOWED="true"
else
    SIGNUPS_ALLOWED="false"
fi

# 6. DİZİN VE DOSYA İZİNLERİNİ HAZIRLAMA
echo -e "\n${BLUE}📁 [3/6] Dizinler oluşturuluyor ve dosya izinleri ayarlanıyor...${NC}"
mkdir -p "$INSTALL_DIR/data"
mkdir -p "$INSTALL_DIR/backups"

# 7. DOCKER-COMPOSE.YML VE .ENV OLUŞTURMA
echo -e "${BLUE}⚙️  [4/6] Yapılandırma dosyaları hazırlanıyor...${NC}"

# .env Dosyası
cat <<EOF > "$INSTALL_DIR/.env"
# ==========================================
# VAULTWARDEN ORTAM DEĞİŞKENLERİ
# ==========================================

# 1. Port ve Alan Adı
HOST_PORT=$CHOSEN_PORT
DOMAIN=$VAULT_DOMAIN

# 2. Kayıt ve Kullanıcı Yönetimi
SIGNUPS_ALLOWED=$SIGNUPS_ALLOWED
INVITATIONS_ALLOWED=true
SHOW_PASSWORD_HINT=false

# 3. Yönetici Paneli Token (Argon2id Hash)
ADMIN_TOKEN=$ESCAPED_ADMIN_TOKEN

# 4. Ağ ve Proxy Ayarları
IP_HEADER=X-Forwarded-For

# 5. Veritabanı ve Performans (SQLite WAL Mode)
ENABLE_DB_WAL=true
DB_CONNECTION_RETRIES=15
ROCKET_WORKERS=10

# 6. Özellik Kontrolleri
SENDS_ALLOWED=true
EMERGENCY_ACCESS_ALLOWED=true
TRASH_AUTO_DELETE_DAYS=30

# 7. Loglama
LOG_LEVEL=info
EXTENDED_LOGGING=true
EOF

# docker-compose.yml Dosyası
cat <<EOF > "$INSTALL_DIR/docker-compose.yml"
services:
  vaultwarden:
    image: vaultwarden/server:1.37.1
    container_name: vaultwarden
    restart: unless-stopped
    env_file:
      - .env
    ports:
      # Sadece localhost (127.0.0.1) üzerine dinler; dış dünya erişimi Nginx / Proxy üzerinden sağlanır.
      - "127.0.0.1:\${HOST_PORT:-$CHOSEN_PORT}:80"
    volumes:
      - ./data:/data
    networks:
      - vaultwarden-net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:80/alive"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  vaultwarden-net:
    driver: bridge
EOF

# manage.sh Yönetim Scripti
cat <<'EOF' > "$INSTALL_DIR/manage.sh"
#!/usr/bin/env bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
cd "$DIR"

# Docker compose komutunu belirle
if docker compose version &>/dev/null; then
    DC="docker compose"
else
    DC="docker-compose"
fi

case "$1" in
    start)
        echo "🚀 Vaultwarden başlatılıyor..."
        $DC up -d
        ;;
    stop)
        echo "🛑 Vaultwarden durduruluyor..."
        $DC down
        ;;
    restart)
        echo "🔄 Vaultwarden yeniden başlatılıyor..."
        $DC restart
        ;;
    status)
        echo "📊 Vaultwarden Durumu:"
        $DC ps
        ;;
    logs)
        echo "📜 Vaultwarden Canlı Logları (Çıkmak için CTRL+C):"
        $DC logs -f --tail=100
        ;;
    update)
        echo "⬆️ Vaultwarden güncelleniyor..."
        $DC pull
        $DC up -d --remove-orphans
        echo "✅ Güncelleme tamamlandı."
        ;;
    backup)
        DATE=$(date +%Y%m%d_%H%M%S)
        mkdir -p "$DIR/backups"
        echo "💾 Yedek alınıyor..."
        if command -v sqlite3 &>/dev/null && [ -f "$DIR/data/db.sqlite3" ]; then
            sqlite3 "$DIR/data/db.sqlite3" ".backup '$DIR/backups/db_${DATE}.sqlite3'"
        fi
        tar -czf "$DIR/backups/vaultwarden_full_${DATE}.tar.gz" -C "$DIR" data .env docker-compose.yml
        echo "✅ Yedek oluşturuldu: $DIR/backups/vaultwarden_full_${DATE}.tar.gz"
        ;;
    hash)
        echo "🔑 Yeni Argon2id Admin Token Hash Üretimi:"
        docker run --rm -it vaultwarden/server:1.37.1 /vaultwarden hash
        ;;
    *)
        echo "Kullanım: $0 {start|stop|restart|status|logs|update|backup|hash}"
        exit 1
        ;;
esac
EOF
chmod +x "$INSTALL_DIR/manage.sh"

# Sahiplik ve Yetkilendirme (Sudo ile çalıştırılsa bile dosya izinlerini düzenle)
if [ "$REAL_USER" != "root" ] && id "$REAL_USER" &>/dev/null; then
    chown -R "$REAL_USER:$REAL_GROUP" "$INSTALL_DIR" 2>/dev/null || true
fi
chmod 755 "$INSTALL_DIR"
chmod 755 "$INSTALL_DIR/data"
chmod 600 "$INSTALL_DIR/.env" 2>/dev/null || true

# 8. DOCKER KONTEYNERİNİ AYAĞA KALDIRMA
echo -e "\n${BLUE}🚀 [5/6] Vaultwarden konteyneri başlatılıyor...${NC}"
cd "$INSTALL_DIR"
$DOCKER_COMPOSE_CMD up -d

# 9. AYAKTA OLMA KONTROLÜ (HEALTH CHECK)
echo -e "${BLUE}🩺 [6/6] Konteyner sağlık ve çalışma durumu kontrol ediliyor...${NC}"
sleep 4

CONTAINER_STATUS=$(docker inspect -f '{{.State.Status}}' vaultwarden 2>/dev/null || echo "not_found")

if [ "$CONTAINER_STATUS" = "running" ]; then
    echo -e "${GREEN}✅ Vaultwarden başarıyla çalışıyor! (Status: $CONTAINER_STATUS)${NC}"
else
    echo -e "${RED}⚠️ Konteyner beklenmedik bir durumda: $CONTAINER_STATUS${NC}"
    echo -e "${YELLOW}Son log kayıtları:${NC}"
    docker logs --tail 20 vaultwarden
fi

# ==============================================================================
# ÖZET VE KULLANICI BİLGİLENDİRME PANELİ
# ==============================================================================
echo -e "\n${GREEN}${BOLD}"
echo "================================================================="
echo "   🎉 VAULTWARDEN KURULUMU BAŞARIYLA TAMAMLANDI!                 "
echo "================================================================="
echo -e "${NC}"

echo -e "${BOLD}📌 Kurulum Bilgileri:${NC}"
echo -e "  • ${CYAN}Kurulum Dizini:${NC} $INSTALL_DIR"
echo -e "  • ${CYAN}Hedef Alan Adı:${NC} $VAULT_DOMAIN"
echo -e "  • ${CYAN}Dinlenen Yerel Port:${NC} 127.0.0.1:$CHOSEN_PORT (Docker içi Port: 80)"
echo -e "  • ${CYAN}Yönetici Paneli URL:${NC} $VAULT_DOMAIN/admin"
if [ "$GENERATED_RANDOM_PASS" = true ]; then
    echo -e "  • ${YELLOW}Üretilen Admin Şifresi:${NC} ${BOLD}$ADMIN_PASS_INPUT${NC} (Lütfen kaydediniz!)"
else
    echo -e "  • ${CYAN}Admin Şifresi:${NC} (Girdiğiniz şifre)"
fi
echo -e "  • ${CYAN}Yeni Kayıt Durumu:${NC} $([ "$SIGNUPS_ALLOWED" = "true" ] && echo "AÇIK (İlk hesap açıldıktan sonra kapatılması önerilir)" || echo "KAPALI")"

echo -e "\n${BOLD}🛠️  Yönetim Komutları (Kolay Aç/Kapa):${NC}"
echo -e "  • Başlatmak için:       ${BOLD}$INSTALL_DIR/manage.sh start${NC}"
echo -e "  • Durdurmak için:       ${BOLD}$INSTALL_DIR/manage.sh stop${NC}"
echo -e "  • Yeniden başlatmak:    ${BOLD}$INSTALL_DIR/manage.sh restart${NC}"
echo -e "  • Durum kontrolü:       ${BOLD}$INSTALL_DIR/manage.sh status${NC}"
echo -e "  • Canlı loglar:         ${BOLD}$INSTALL_DIR/manage.sh logs${NC}"
echo -e "  • Yedek almak için:     ${BOLD}$INSTALL_DIR/manage.sh backup${NC}"

echo -e "\n${YELLOW}${BOLD}🌐 REVERSE PROXY / YÖNLENDİRME YAPILANDIRMA NOTLARI:${NC}"
echo -e "Trafik ${BOLD}127.0.0.1:$CHOSEN_PORT${NC} adresine yönlendirilmelidir."
echo -e "Kendi tercih ettiğiniz proxy yöntemine göre aşağıdaki örnekleri kullanabilirsiniz:"

echo -e "\n${CYAN}👉 [Seçenek A] Nginx (Reverse Proxy):${NC}"
echo "--------------------------------------------------------"
cat <<NGINX_CONF
location / {
    proxy_pass http://127.0.0.1:$CHOSEN_PORT;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-Port \$server_port;

    # Canlı Bildirimler (WebSocket)
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \$http_connection;
    client_max_body_size 128M;
}
NGINX_CONF
echo "--------------------------------------------------------"

echo -e "\n${CYAN}👉 [Seçenek B] Nginx Proxy Manager (NPM):${NC}"
echo "  • Forward Hostname / IP: 127.0.0.1 (veya Host IP)"
echo "  • Forward Port: $CHOSEN_PORT"
echo "  • 'Websockets Support' ve 'Block Common Exploits' kutucuklarını işaretleyin."
echo "  • SSL sekmesinden Let's Encrypt sertifikasını aktif edin."

echo -e "\n${CYAN}👉 [Seçenek C] Cloudflare Tunnel / Port Yönlendirme:${NC}"
echo "  • Service: HTTP"
echo "  • URL: localhost:$CHOSEN_PORT"

echo -e "\n${GREEN}✨ İşlem tamamlandı. Güvenle kullanabilirsiniz!${NC}\n"
