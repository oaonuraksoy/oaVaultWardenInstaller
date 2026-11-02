# 🛡️ oaVaultWardenInstaller

[![OS - AlmaLinux & RHEL](https://img.shields.io/badge/OS-AlmaLinux%208%20%7C%20Rocky%208%20%7C%20RHEL%208-blue.svg)](https://almalinux.org/)
[![OS - Debian & Ubuntu](https://img.shields.io/badge/OS-Debian%2011%2F12%20%7C%20Ubuntu%2020.04%2B-red.svg)](https://www.debian.org/)
[![Vaultwarden](https://img.shields.io/badge/Vaultwarden-v1.37.1-orange.svg)](https://github.com/dani-garcia/vaultwarden)
[![Docker](https://img.shields.io/badge/Docker-Engine%20%26%20Compose-2496ED.svg)](https://www.docker.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**oaVaultWardenInstaller**, kurumsal Linux dağıtımları üzerinde [Vaultwarden](https://github.com/dani-garcia/vaultwarden) (Bitwarden uyumlu açık kaynaklı parola yöneticisi) sunucusunu Docker ile **otomatik, güvenli, çakışmasız ve tek komutla** kurmak için tasarlanmış interaktif kurulum sihirbazıdır.

---

## ⚡ Hızlı Başlangıç (Tek Satırda Kurulum)

İşletim sisteminize uygun olan tek satırlık komutu terminalde çalıştırmanız yeterlidir:

### 🐧 1. AlmaLinux 8 / Rocky Linux 8 / RHEL 8 İçin:
```bash
curl -fsSL https://raw.githubusercontent.com/oaonuraksoy/oaVaultWardenInstaller/main/install-vaultwarden-almalinux8.sh -o install-vaultwarden-almalinux8.sh \
  && chmod +x install-vaultwarden-almalinux8.sh \
  && sudo ./install-vaultwarden-almalinux8.sh
```

### 🍥 2. Debian 11/12 & Ubuntu 20.04/22.04/24.04 İçin:
```bash
curl -fsSL https://raw.githubusercontent.com/oaonuraksoy/oaVaultWardenInstaller/main/install-vaultwarden-debian.sh -o install-vaultwarden-debian.sh \
  && chmod +x install-vaultwarden-debian.sh \
  && sudo ./install-vaultwarden-debian.sh
```

---

## 📥 Manuel Kurulum Adımları

### AlmaLinux 8 / RHEL 8:
```bash
curl -fsSL https://raw.githubusercontent.com/oaonuraksoy/oaVaultWardenInstaller/main/install-vaultwarden-almalinux8.sh -o install-vaultwarden-almalinux8.sh
chmod +x install-vaultwarden-almalinux8.sh
sudo ./install-vaultwarden-almalinux8.sh
```

### Debian / Ubuntu:
```bash
curl -fsSL https://raw.githubusercontent.com/oaonuraksoy/oaVaultWardenInstaller/main/install-vaultwarden-debian.sh -o install-vaultwarden-debian.sh
chmod +x install-vaultwarden-debian.sh
sudo ./install-vaultwarden-debian.sh
```

---

## 🎯 Sihirbaz Hangi Soruları Sorar?

Script çalıştırıldığında sizden yalnızca temel parametreleri ister:
1. **Kurulum Dizini:** Varsayılan `/opt/vaultwarden` (Enter ile geçilebilir).
2. **Alan Adı (Domain):** Passkey/FIDO2 ve istemci senkronizasyonu için hedef URL (Örn: `vault.domaininiz.com`).
3. **Dış Port (Host Port):** Sunucudaki aktif portlar taranarak bulunan **ilk boş port** önerilir (Örn: `8080`). İsterseniz değiştirebilirsiniz.
4. **Admin Paneli Şifresi:** `/admin` paneli için belirleyeceğiniz şifre. Script bu şifreyi otomatik olarak **Argon2id** ile hash'ler. (Boş bırakılırsa güçlü rastgele 24 haneli şifre üretir).
5. **Kayıt Durumu (`SIGNUPS_ALLOWED`):** İlk hesabınızı açmak için açık/kapalı seçimi.

---

## 🌟 Öne Çıkan Özellikler

* 🔍 **Docker ve Servis Otomasyonu:** Sistemde Docker'ın kurulu olup olmadığını, `docker.service` ve daemon'ın çalışıp çalışmadığını (`systemctl is-active`, `docker info`) denetler; servis durmuşsa otomatik olarak başlatır ve etkinleştirir (`enable --now`).
* 🔌 **Dinamik Port Mimarisi:** Konteyner iç portu her zaman `80` kalırken, host portu sunucudaki boş portlardan otomatik seçilir (`127.0.0.1:${HOST_PORT}:80`). Çakışma yaşanmaz.
* 🔒 **Sıkılaştırılmış Güvenlik (Argon2id):** Düz metin token kullanılmaz. Vaultwarden v1.37.1 standartlarına uygun Argon2id hash üretimi yapılır.
* 🛡️ **İzin & Sudo Koruması:** `sudo` ile çalıştırılsa bile dosyaların sahipliği çağıran kullanıcıya (`SUDO_USER`) göre ayarlanır; Docker konteynerinin veri yazma izinleri (`755`) güvenceye alınır.
* ⚡ **Tek Port Canlı Bildirim (WebSocket):** Vaultwarden v1.37+ tek port üzerinden canlı eşitleme (live sync) destekler.
* 🚀 **SQLite WAL Modu:** Eşzamanlı okuma/yazma performansı için Write-Ahead Logging açık gelir.


---

## 🛠️ Kolay Yönetim (`manage.sh`)

Kurulum tamamlandığında `/opt/vaultwarden/manage.sh` scripti otomatik oluşturulur:

```bash
# Servisi Başlatma
sudo /opt/vaultwarden/manage.sh start

# Servisi Durdurma
sudo /opt/vaultwarden/manage.sh stop

# Yeniden Başlatma
sudo /opt/vaultwarden/manage.sh restart

# Çalışma ve Konteyner Durumu
sudo /opt/vaultwarden/manage.sh status

# Canlı Logları İzleme
sudo /opt/vaultwarden/manage.sh logs

# Tek Komutla SQLite + Veri Yedeği Alma
sudo /opt/vaultwarden/manage.sh backup

# Yeni Vaultwarden Sürümüne Güncelleme
sudo /opt/vaultwarden/manage.sh update

# Yeni Argon2id Token Hash'i Üretme
sudo /opt/vaultwarden/manage.sh hash
```

---

## 🌐 Reverse Proxy (Ters Vekil) Kurulum Kılavuzu

Vaultwarden sadece `127.0.0.1:<PORT>` üzerinden dinler. Dış dünya erişimi ve HTTPS için aşağıdaki proxy yapılandırmalarından birini kullanabilirsiniz:

### 1. Plesk Obsidian (Nginx)
Plesk'te **Domains > [Domaininiz] > Apache & Nginx Settings > Additional nginx directives** alanına ekleyin:

```nginx
location / {
    proxy_pass http://127.0.0.1:8080; # Belirlediğiniz HOST_PORT
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Port $server_port;

    # WebSocket Canlı Bildirim Desteği
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $http_connection;
    client_max_body_size 128M;
}
```

### 2. Nginx Proxy Manager (NPM)
* **Forward Hostname / IP:** `127.0.0.1`
* **Forward Port:** `8080` (Seçtiğiniz Port)
* **Websockets Support:** ✅ Açık
* **Block Common Exploits:** ✅ Açık
* **SSL:** Let's Encrypt (Force SSL + HTTP/2 Destekli)

### 3. Cloudflare Tunnel
* **Service Type:** `HTTP`
* **URL:** `localhost:8080`

---

## 📋 Dosya Hiyerarşisi

```text
/opt/vaultwarden/
├── docker-compose.yml   # Konteyner tanımı
├── .env                 # Ortam değişkenleri ve Argon2id token (600 izinli)
├── manage.sh            # Pratik yönetim scripti
├── data/                # Veritabanı (db.sqlite3), RSA anahtarları, ekler
└── backups/             # Otomatik alınan yedekler (.tar.gz ve .sqlite3)
```

---

## 📄 Lisans

Bu proje [MIT Lisansı](LICENSE) ile lisanslanmıştır.


---

## 👨‍💻 Mimari & Geliştirici / Architected by Onur Aksoy

Bu proje **Onur Aksoy** (*Kıdemli Yazılım Mimarı & Yapay Zeka Yerel Geliştirici — a.k.a. Hackonomist*) tarafından tasarlanmış ve geliştirilmiştir.

- 🌐 **Resmi Web Sitesi & Mimari Vaka Analizleri:** [https://onuraksoy.com.tr](https://onuraksoy.com.tr)
- 🇬🇧 **English Portfolio & Architecture Case Studies:** [https://onuraksoy.com.tr/en/](https://onuraksoy.com.tr/en/)
- 💼 **LinkedIn:** [linkedin.com/in/oaonuraksoy](https://linkedin.com/in/oaonuraksoy) • **GitHub:** [@oaonuraksoy](https://github.com/oaonuraksoy)
