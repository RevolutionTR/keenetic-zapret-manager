# 📘 Keenetic Zapret Manager — Tam Kullanım Kılavuzu

Bu doküman betikte bulunan **tüm ana menüleri ve alt menüleri** eksiksiz şekilde açıklar.

Yeni kullanıcılar için olduğu kadar ileri seviye kullanıcılar için de referans niteliğindedir.

---
## 🚀 Kurulum — 30 Saniyede Kurulum

Keenetic Zapret Manager, DPI engellerini minimum yapılandırma ile aşmanızı sağlar.

Kurulum düşündüğünüzden çok daha kolaydır. SSH ile router’a bağlanın ve betiği aşağıdaki komut ile indirin:

```bash
wget -O /opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh \
  https://raw.githubusercontent.com/RevolutionTR/keenetic-zapret-manager/main/keenetic_zapret_otomasyon_ipv6_ipset.sh
chmod +x /opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh
/opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh
```

Veya

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
| 3 | Zapret'i Başlat |
| 4 | Zapret'i Durdur |
| 5 | Zapret'i Yeniden Başlat |
| 6 | Zapret Sürüm Bilgisi |
| 7 | IPv6 Sihirbaz |
| 8 | Yedek / Geri Yükle |
| 9 | DPI Profil Yönetimi |
| 10 | Betik Güncelleme |
| 11 | Hostlist / Autohostlist |
| 12 | IPSet Yönetimi |
| 13 | Rollback (Sürüm Geri Dön) |
| 14 | Tanılama Araçları |
| 15 | Telegram Bildirimleri |
| 16 | Sağlık Monitörü |
| B | Blockcheck |
| L | Dil Değiştir (TR/EN) |
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

✔ Manager (KZM)  
✔ Health Monitor  
✔ Telegram ayarları  

👉 Zapret’i yeniden kurmak isteyen kullanıcılar için idealdir.

**Tam temiz kaldırma değildir.**

---

# 🔹 Menü 3 — Zapret’i Başlat

Zapret servislerini aktif eder ve DPI bypass kurallarını devreye alır.

---

# 🔹 Menü 4 — Zapret’i Durdur

Zapret servisini durdurur. Tüm yönlendirme/bypass işlemleri pasif olur.

---

# 🔹 Menü 5 — Zapret’i Yeniden Başlat

Zapret servisini yeniden başlatır.

👉 Profil değişikliği veya ayar değişimi yaptıysanız önerilir.

---

# 🔹 Menü 6 — Zapret Sürüm Bilgisi (Güncel/Kurulu - GitHub)

GitHub’daki güncel Zapret sürümünü ve cihazda kurulu sürümü gösterir.

---

# 🔹 Menü 7 — Zapret IPv6 Desteği (Sihirbaz)

IPv6 açık hatlarda gerekli yapılandırmayı sihirbaz ile uygular.

---

# 🔹 Menü 8 — Zapret Yedekle / Geri Yükle

Zapret ayarlarını yedekler veya önceki bir yedeği geri yükler.

👉 Büyük değişikliklerden önce yedek almak önerilir.

---

# 🔹 Menü 9 — DPI Profil Yönetimi

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

---

# 🔹 Menü 11 — Hostlist / Autohostlist (Filtreleme + Kapsam Modu)

Bu menü altında; manuel hostlist, otomatik autohostlist ve bypass kapsamı birlikte yönetilir.

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

## Hostlist Yönetimi

Manuel engelli domain listesi.

### Alt Menü:

✔ Domain ekle  
✔ Domain sil  
✔ Çoklu domain ekle  
✔ Listeyi temizle  
✔ Listeyi görüntüle  

👉 Autohostlist’in yakalayamadığı servislerde kullanılır.

---

## Autohostlist

Engellenen servisleri otomatik öğrenir.

### Alt Menü:

✔ Aç / Kapat  
✔ Listeyi sıfırla  
✔ Manuel liste ile birleştir  

👉 Zamanla optimize bypass listesi oluşturur.

**Kur → unut özelliğidir.**

---

---

# 🔹 Menü 12 — IPSet Yönetimi

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

### No Zapret (Muafiyet) Yönetimi

Bu listede bulunan IP’ler Zapret işleminden **muaf** tutulur (örn. IPTV kutuları).

---

# 🔹 Menü 13 — Rollback (Sürüm Geri Dön)

Script güncellemesi sonrası sorun yaşarsanız önceki sürüme dönüş yapmanızı sağlar.

İçerir:

✔ GitHub sürüm listesini alma
✔ Seçilen sürümü kurma
✔ Mevcut dosyayı yedekleme

👉 Güncelleme sonrası hayat kurtarır.

---

# 🔹 Menü 14 — Tanılama Araçları

Sistem sağlığını analiz eder.

### Kontroller:

✔ DPI Health Score  
✔ DNS tutarlılığı  
✔ TLS erişimi  
✔ UDP 443 kontrolü  
✔ Varsayılan rota  

👉 Bir şey çalışmıyorsa ilk buraya bak.

---

---

# 🔹 Menü 15 — Telegram Bildirimleri

Telegram bot entegrasyonunu ve bildirim ayarlarını yönetir.

Ne işe yarar?

- Servis restart / recovery bildirimleri
- Health Monitor uyarıları (CPU/RAM/Disk/WAN vb.)
- Güncelleme bilgilendirmeleri

⚠️ Bot Token ve Chat ID doğru girilmelidir.

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

---

# 🔵 B — Blockcheck Test Menüsü

DPI testlerini çalıştırır ve bağlantı durumunu analiz eder.

Ne işe yarar?

- Hangi protokolün sorunlu olduğunu görmek
- DPI Health Score / test sonuçları ile profil doğrulamak
- Sorun giderme sürecinde hızlı teşhis

---

# 🌐 L — Dil Değiştir (TR/EN)

Arayüz dilini Türkçe / İngilizce arasında değiştirir.

---

# 🔥 Menü U — Tam Temiz Kaldırma

⚠️ Geri alınamaz işlemdir.

Router’ı KZM kurulum öncesi hale getirir.

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

14 → Tanılama → Tam temiz kaldır → yeniden kur.

---

# 🚨 KRİTİK UYARI

Rastgele DPI ayarı değiştirmeyin.

Sorunların çoğu şunlardan kaynaklanır:

✔ ISP değişiklikleri  
✔ DNS problemleri  
✔ Yanlış profil
