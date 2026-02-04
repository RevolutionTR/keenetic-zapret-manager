# 🤖 Telegram Bildirimleri – Kurulum Rehberi

Bu rehber, Keenetic Zapret Manager için **Telegram bildirimlerini** birkaç adımda
nasıl kuracağınızı anlatır.

Telegram bildirimi sayesinde router’dan **anlık sistem ve Zapret durumu**
mesajları alabilirsiniz.

---

## 📌 Telegram Bildirimleri Nedir?

Telegram üzerinden otomatik olarak şu bildirimleri alırsınız:

- 🚨 Zapret durmuş olabilir (auto-restart başarısızsa)
- ✅ Zapret tekrar çalışıyor
- ⚠️ CPU / RAM / Disk kullanımı yüksek
- 📌 Başlıklı ve tarih-saatli durum mesajları

> Telegram bildirimi **opsiyoneldir**. Kurmazsanız sistem normal çalışır.

---

## 1️⃣ Telegram Bot Oluşturma

1. Telegram’da **@BotFather** ile konuşun
2. Sırasıyla şu komutları yazın:

/start

/newbot

3. BotFather size bir **BOT TOKEN** verecek  
(örnek: `123456:ABC-DEF...`)
4. Bu token’ı bir yere kaydedin ve KESİNLİKLE HİÇ KİMSE İLE PAYLAŞMAYIN !!!

---

## 2️⃣ Chat ID Öğrenme

1. Oluşturduğunuz bot’a Telegram’dan **en az bir mesaj gönderin**
2. Tarayıcıda şu adresi açın:

   https://api.telegram.org/bot<BOT_TOKEN>/getUpdates

Not: BOT_TOKEN yazarken <> işaretlerini kaldırarak bot12345:KEKDK..../ gibi yazın !

Bu sayı sizin Chat ID’nizdir

3. Çıktıda aşağıdaki alanı bulun:

"chat": {"id": 123456789
Bu sayı sizin Chat ID’nizdir

---

## 3️⃣ Script Üzerinden Kaydetme
Daha sonra Keenetic Zapret Manager'ı çalıştırın ve Telegram Bildirim Ayarları menüsüne gidin.

Buradan:

Bot Token’ı girin
Chat ID’yi girin
Test Mesajı Gönder seçeneğini kullanın

Test mesajı Telegram’a gelirse kurulum tamamdır ✅

---
---
🔒 Güvenlik

Bildirimler sadece tanımlanan Chat ID’ye gönderilir
Telegram üzerinden komut çalıştırma güvenlik nedeni ile yoktur
Sistem tek yönlü çalışır (router → Telegram)


❓ Sık Sorulan Sorular

Telegram zorunlu mu?
Hayır. Ayarlamazsanız sistem normal çalışır.

Reboot sonrası tekrar ayar yapmam gerekir mi?
Hayır. Bot Token ve Chat ID kalıcıdır.

Telegram’dan “Durum” yazınca cevap gelir mi?
Hayır. Mevcut sürümde Telegram sadece bildirim gönderir.

Loglar disk doldurur mu?
Hayır. Loglar /tmp altında tutulur ve kontrollüdür.


🧪 Sorun Giderme

Test mesajı gelmiyor
Bot Token doğru mu?
Chat ID doğru mu?
Bot’a en az bir mesaj gönderdiniz mi?
Bildirim gelmiyor ama test çalışıyor
Health Monitor açık mı?
Zapret gerçekten durmuş durumda mı?


