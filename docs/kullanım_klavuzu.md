# 📘 Keenetic Zapret Manager — Tam Kullanım Kılavuzu

Bu doküman betikte bulunan **tüm ana menüleri ve alt menüleri** eksiksiz şekilde açıklar.

Yeni kullanıcılar için olduğu kadar ileri seviye kullanıcılar için de referans niteliğindedir.

---
## 🚀 Kurulum — 30 Saniyede Kurulum

Keenetic Zapret Manager, DPI engellerini minimum yapılandırma ile aşmanızı sağlar.

Kurulum düşündüğünüzden çok daha kolaydır. SSH ile router’a bağlanın ve betiği aşağıdaki komut ile indirin:


```bash
curl -fsSL https://raw.githubusercontent.com/RevolutionTR/keenetic-zapret-manager/main/keenetic_zapret_otomasyon_ipv6_ipset.sh \
-o /opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh

chmod +x /opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh
/opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh
```


---

# 🧭 Ana Menü Haritası


| Menü | Açıklama |
|--------|------------|
| 1 | Zapret Kur |
| 2 | Zapret'i Kaldır |
| 3 | DPI Profil Yönetimi |
| 4 | Kapsam Modu |
| 5 | Hostlist Yönetimi |
| 6 | Autohostlist |
| 7 | NFQWS / Paket Motoru |
| 8 | IPSet Yönetimi |
| 9 | Tanılama Araçları |
| 10 | Betik Güncelleme |
| 11 | Domain Araçları |
| 12 | IP Araçları |
| 13 | Liste Görüntüleme |
| 14 | Yedek / Temizlik |
| 15 | Betik Araçları |
| 16 | Sağlık Monitörü |
| U | Tam Temiz Kaldırma |

---

# 🔹 Menü 1 — Zapret Kurulumu

Router’a Zapret DPI bypass motorunu kurar.

### Ne yapar?

✔ Zapret bileşenlerini indirir  
✔ Firewall kurallarını oluşturur  
✔ NFQWS motorunu hazırlar  
✔ Varsayılan DPI profilini uygular  

👉 İlk kurulumda **tek yapılması gereken budur.**

**Kurulum sonrası router yeniden başlatılabilir.**

---

# 🔹 Menü 2 — Zapret’i Kaldır

Zapret’i sistemden güvenli şekilde kaldırır.

### Kaldırılanlar:

✔ Firewall kuralları  
✔ NFQWS  
✔ Zapret servisleri  

### Kaldırılmayanlar:

✔ Manager (ZKM)  
✔ Health Monitor  
✔ Telegram ayarları  

👉 Zapret’i yeniden kurmak isteyen kullanıcılar için idealdir.

**Tam temiz kaldırma değildir.**

---

# 🔹 Menü 3 — DPI Profil Yönetimi

DPI bypass yöntemini değiştirir.

### Alt Menü:

✔ Aktif profil seç  
✔ Mevcut profili görüntüle  
✔ Varsayılana dön  

### Profil Türleri:

- TTL spoof  
- Fake paket  
- Signature gizleme  
- ISP özel ayarlar  

⚠️ Yanlış profil internet sorununa neden olabilir.

👉 Emin değilsen varsayılanı kullan.

---

# 🔹 Menü 4 — Kapsam Modu (Global / Akıllı)

Bypass’ın uygulanacağı alanı belirler.

---

## 🌐 Global

Tüm ağa uygulanır.

✔ Maksimum uyumluluk  
❗ Biraz daha fazla CPU  

👉 Yeni kullanıcılar için güvenlidir.

---

## 🧠 Akıllı Mod (Autohostlist)

Sadece engellenen hostlara uygulanır.

✔ Daha az CPU  
✔ Daha temiz trafik  
✔ Daha stabil routing  

👉 Uzun vadede önerilen mod.

---

# 🔹 Menü 5 — Hostlist Yönetimi

Manuel engelli domain listesi.

### Alt Menü:

✔ Domain ekle  
✔ Domain sil  
✔ Çoklu domain ekle  
✔ Listeyi temizle  
✔ Listeyi görüntüle  

👉 Autohostlist’in yakalayamadığı servislerde kullanılır.

---

# 🔹 Menü 6 — Autohostlist

Engellenen servisleri otomatik öğrenir.

### Alt Menü:

✔ Aç / Kapat  
✔ Listeyi sıfırla  
✔ Manuel liste ile birleştir  

👉 Zamanla optimize bypass listesi oluşturur.

**Kur → unut özelliğidir.**

---

# 🔹 Menü 7 — NFQWS / Paket Motoru

Zapret’in paket manipülasyon ayarları.

### Örnek ayarlar:

- TTL değeri  
- Fake paket sayısı  
- Queue parametreleri  

⚠️ İleri seviye kullanıcılar içindir.

Yanlış ayarlar performansı düşürebilir.

---

# 🔹 Menü 8 — IPSet Yönetimi

Bypass uygulanacak cihazları belirler.

### Alt Menü:

✔ IP ekle  
✔ IP kaldır  
✔ Aktif listeyi gör  
✔ Listeyi temizle  

### Kullanım senaryosu:

Bypass sadece şu cihazlarda çalışsın:

- Smart TV  
- Oyun konsolu  
- Apple TV  
- Android Box  

👉 Router CPU’sunu korur.

---

# 🔹 Menü 9 — Tanılama Araçları

Sistem sağlığını analiz eder.

### Kontroller:

✔ DPI Health Score  
✔ DNS tutarlılığı  
✔ TLS erişimi  
✔ UDP 443 kontrolü  
✔ Varsayılan rota  

👉 Bir şey çalışmıyorsa ilk buraya bak.

---

# 🔹 Menü 10 — Betik Güncelleme

Manager betiğini GitHub üzerinden günceller.

### Güvenlik Mekanizması:

| Durum | Davranış |
|--------|------------|
| Yerel < GitHub | Günceller |
| Yerel = GitHub | Atlar |
| Yerel > GitHub | Atlar |

✔ Downgrade engellenir  
✔ Version loop oluşmaz  

---

# 🔹 Menü 11 — Domain Araçları

Domain bazlı işlemleri hızlandırır.

### Alt Menü:

✔ Çoklu domain ekleme  
✔ Toplu silme  
✔ Liste doğrulama  

👉 Büyük hostlist yönetenler için idealdir.

---

# 🔹 Menü 12 — IP Araçları

IP bazlı kontrol ve analiz araçları.

### Alt Menü:

✔ IP listesini göster  
✔ Aktif IPSet üyelerini gör  
✔ Çakışma kontrolü  

👉 Ağ yöneten ileri kullanıcılar içindir.

---

# 🔹 Menü 13 — Liste Görüntüleme

Tüm aktif listeleri tek ekranda gösterir.

✔ Hostlist  
✔ Autohostlist  
✔ IPSet  
✔ Aktif profiller  

👉 Sistem snapshot gibidir.

---

# 🔹 Menü 14 — Yedek & Temizlik

Artık dosyaları temizler.

### Temizlenenler:

✔ Eski backup dosyaları  
✔ Blockcheck raporları  
✔ Geçici test çıktıları  

👉 Disk alanını korur.

---

# 🔹 Menü 15 — Betik Araçları

Manager için yardımcı araçlar.

### İçerik:

✔ Self-test  
✔ Konfigürasyon doğrulama  
✔ Kurulum yolu kontrolü  

👉 Sorun giderirken çok değerlidir.

---

# 🔹 Menü 16 — Sağlık Monitörü

Arka planda çalışan otomasyon motorudur.

### İzlenenler:

✔ CPU  
✔ RAM  
✔ Disk  
✔ WAN  
✔ Zapret  
✔ DNS  

### Özellikler:

✔ Telegram bildirimleri  
✔ Auto restart  
✔ Güncelleme kontrolü  

👉 Açık tutulması **şiddetle önerilir.**

---

# 💾 B — Backup Yönetimi

Script yedeklerini yönetir.

İçerir:

✔ Script backup listesi  
✔ Geri yükleme  
✔ Eski sürüme dönüş  

👉 Güncelleme sonrası hayat kurtarır.

---

# 📜 L — Log Görüntüleme

Health Monitor ve script loglarını gösterir.

Özellikle şu durumlarda kritik:

- Güncelleme hataları  
- Servis durmaları  
- WAN kopmaları  

👉 Support öncesi ilk bakılacak yer.

---

# 🔥 Menü U — Tam Temiz Kaldırma

⚠️ Geri alınamaz işlemdir.

Router’ı ZKM kurulum öncesi hale getirir.

---

## İşlem Aşamaları

### ✔ 1. Zapret kaldırılır  
(Mevcut güvenli kaldırma rutini çalışır)

### ✔ 2. Manager kalıntıları temizlenir

Silinenler:

- Health Monitor  
- Telegram config  
- Init servisleri  
- Log dosyaları  
- State dosyaları  
- Backup dosyaları  

---

## Güvenlik Tasarımı

👉 Betik dosyası **bilerek silinmez.**

Amaç:

✔ Kullanıcının kilitlenmesini önlemek  
✔ Tekrar kopyalama ihtiyacını azaltmak  

İsteyen kullanıcı manuel silebilir.

---

# ⭐ ÖNERİLEN KULLANIM AKIŞI

## Yeni Kullanıcı

1 → Kur  
16 → Health Monitor aç  

---

## İleri Kullanıcı

Akıllı Mod + Autohostlist kullan.

---

## Sorun Giderme

Tanılama → Tam temiz kaldır → yeniden kur.

---

# 🚨 KRİTİK UYARI

Rastgele DPI ayarı değiştirmeyin.

Sorunların çoğu şunlardan kaynaklanır:

✔ ISP değişiklikleri  
✔ DNS problemleri  
✔ Yanlış profil  

