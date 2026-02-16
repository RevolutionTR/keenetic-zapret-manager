# KEENETİC ROUTER'LAR İÇİN ÖZELLEŞTİRİLMİŞ ZAPRET BETİĞİ


  
## ZAPRET nedir ve ne işe yarar?
Zapret kelime olarak Rusca “Yasak” anlamına gelir. Rus bir programcının Linux sistemler için geliştirdiği bir yazılım olup GitHub üzerinden açık kaynak kodlu olarak dağıtılmaktadır. Zapret, ISS’larının DPI (Deep Packet Inspection) yoluyla web sitelerine getirdiği erişim engellerini kaldırmak için kullanılan bir araçtır.
  
## Erişim engelini aşmanın Zapret’ten başka yolu yok mu?
ISS’larının en güncel sofistike erişim engelleme metodu DPI’dır. Bazı ISS’lerde DNS değişikliği ile erişim engeli aşılabilir. O sebepten ISS’nızın erişim engelleme metodunu bilmiyorsanız Zapret’i kurmadan önce DNS değişikliğini deneyin.

Önerilen DNS adresleri:  
1-    Google DNS: 8.8.8.8 ve 8.8.4.4  
2-    Cloudflare DNS: 1.1.1.1 ve 1.0.0.1  
3-    Quad9 DNS: 9.9.9.9 ve 149.112.112.112  
4-    OpenDNS: 208.67.222.222 ve 208.67.220.220
  
## Neden özelleştirilmiş betiğe ihtiyaç var; güvenilir mi?
Zapret kurulumu düz kullanıcılar için oldukça karmaşıktır. Betikler aracılığı ile kurulum ve yönetimler kolaylıkla yapılabilmektedir. Sayfamızda paylaştığımız Keenetic Zapret Manager betiğinin geliştiricisi DH forum üyesi de olan @Revolution_TR arkadaşımızdır. Bu betik ile Zapret kurulumu ve yönetimi oldukça basittir; Türk Telekom başta olmak üzere yaygın ISS’ler için hazır profillerin seçimi, cihaz bazlı çalıştırma, yedek alma, güncelleme gibi pek çok pratik işlevi barındırmakta olup halen geliştirilmektedir. Betik, GitHub üzerinden açık kaynak kodlu olarak dağıtılmaktadır; dolayısı ile güvenlidir.
  
## Tüm Keenetic router’lara bu betik (Zapret) kurulabilir mi; kurulum için ön şart var mı?
Bir USB portu ve/veya dahili depolaması olan, OPKG paket yöneticisi kurulabilen, v3.x ve üzeri OS yüklü Keenetic modellerinde kullanabilirsiniz. OPKG, router gibi yerleşik tip sistemler için ücretsiz bir paket yöneticisidir.
  
  
# BETİK KURULUMU ÖNCESİ ÖN HAZIRLIK:
  
## === Kurulması gerekli Bileşen seçenekleri ===
Router’ınızın web arayüzüne, YÖNETİM / Sistem Ayarları / Bileşen seçenekleri’ne giderek IPv6, DoT (DNS-over-TLS), DoH (DNS-over-HTTPS) ve OPKG bileşenlerini işaretleyip KeeneticOS’yi güncelleyin. Cihaz yeniden başlatılacaktır (OS güncel versiyonda değilseniz DİKKAT! Bileşen ayarlarını değiştirmek KeeneticOS 'u en güncel versiyona yükseltecektir).


<img src="/docs/images/KZM1.png" width="800">



## === DNS Ayarları ===

Router’ınızın web arayüzüne, AĞ KURALLARI / İnternet Güvenliği / DNS Yapılandırması’na gidin. “+ Sunucu Ekle” butonunu kullanarak DoT ve DoH DNS sunucuları ekleyin. DoH için önerilen DNS sunucuları: Google, CloudFlare, Adguard, Quad9’dur. Sonraki adım olan İSP'den gelen DNS’leri yoksay’madan önce mutlaka DoT, DoH, ISP'nin DNS’i, girili olmalıdır.

<img src="/docs/images/KZM2.png" width="800">

DNS kontrollerinizi aşağıdaki adreslerden yapabilirsiniz:  
DNS leak test , Browser leaks
  
## === ISP’den gelen DNS’leri yoksayın === 
Router’ınızın web arayüzünde, internet hizmeti aldığınız bağlantıya göre İNTERNET / Ethernet Kablosu (veya DSL) girin. İSS Kimlik Doğrulama (PPPoE / PPTP / L2TP) / Gelişmiş PPPoE ayarlarını göster’de  
İSP'den gelen DNSv4 yoksay’ı, IPv6 kullanıyorsanız aynı şekilde DNSv6 yoksay’ı işaretleyip kaydedin.

<img src="/docs/images/KZM3.png" width="800">

(Mevcut kurulu düzeninizde OPKG paketlerini yükleyebilecek şekilde router’ınızı hazırlamış hatta OPKG paketleri kuruyor/kurmuşsanız bundan sonra anlatılan ön hazırlık faslını atlayabilirsiniz)
  
Sonraki ön hazırlık adımları yazıyı uzatacağı ve Zapret kurulumuyla ilgisi dolaylı olduğu için detaya girmeyerek anlatımı cihazlarımızın çevrimiçi Kullanım Kılavuzu’na havale ediyorum. Kullanım Kılavuzu’na Keenetic Destek web sayfasında; ilgili alana ürününüzün adı veya model numarasını girerek ulaşabilirsiniz: Keenetic Destek
  
Ön hazırlık aşamaları web linki ile ulaşacağınız Kullanım Kılavuzu / Yönetim / OPKG yolunda detaylı bir şekilde anlatılmaktadır. Aralarda örnek olması adına Titan (KN-1812)’dan linkler vereceğim, sizler kendi cihazlarınıza göre takip edebilirsiniz: Titan (KN-1812) – çevrimiçi Kullanım Kılavuzu / Yönetim / OPKG
  
OPKG paketlerini dahili bellek veya harici USB sürücü birimlerine kurabilirsiniz. Hariciye kurmak için router'a bağlayacağınız USB sürücüsü EXT4 dosya sistemiyle biçimlendirilmelidir. Sürücülerin EXT4 ile çalışması için Keenetic router'ınızda “Ext Dosya Sistemi” bileşeninin kurulu olması gerekir. Bunu, Genel Sistem Ayarları sayfasında KeeneticOS Güncelleme ve Bileşen Seçenekleri altındaki Bileşen Seçenekleri'ne tıklayarak kontrol edip kurulu değilse kurabilirsiniz.
  
Dahili bellek birimlerinin boyutu güncel cihazlarda 100 MB civarıdır; Zapret ile beraber birkaç uygulama kurulması için yeterlidir. Eski Keenetic modellerinde bu boyut daha düşüktür. 50 MB’ın altında boyuta sahip eski Keenetic modellerinde yalnız Zapret kurulacak olsa bile dahili belleğe değil, USB arayüzü ile harici sürücü kullanılması tavsiye edilir.
  
Kullanacağınız depolamayı önce OPKG Entware paket yöneticisini kurarak hazırlamamız gerekiyor. İki depolama seçeneği için yapılması gereken adımları yine online kullanım kılavuzlarında ilgili başlıklara havale ediyorum.
  
## === Dahili Bellek kullanılacaksa ===
Kullanım Kılavuzu / Yönetim / OPKG / OPKG Entware'i Router'ın Dahili Belleğine Kurma  
Titan (KN-1812)’dan örnek link.
  
## === USB Sürücüsü (harici depolama) kullanılacaksa ===
Kullanım Kılavuzu / Yönetim / OPKG / USB Sürücüye Entware Deposunu Kurma  
Titan (KN-1812)’dan örnek link.  
  
Bu aşamada dikkat etmeniz gereken nokta kurulum yapılacak cihazın işlemci mimarisine göre OPKG Entware paket yöneticisi kurmanızdır. İşlemleri, önerdiğim gibi cihazınızın online kullanım kılavuzundan bakarak yapıyorsanız orada cihazın işlemci mimarisine uygun paketin linki olacaktır. Ben yine de üç işlemci mimarisi için linkleri aşağıya yazayım (cihazınızın işlemci mimarisini kullanım kılavuzundan öğrenebilirsiniz):
  
- aarch64  
- mips  
- mipsel

Ayrıca arayıp bulamayan, nerde bu diyenler SSH bağlı iken 'show version' yazarlarsa cihazın mimarisi en üstteki satırlarda yazar

<img src="/docs/images/KZM7.jpeg" width="800">
  
OPKG ile ilgili daha detaylı bilgi almak için online kullanım kılavuzlarınızda, altta yolu tarif edilmiş yazıyı okuyabilirsiniz.  
Kullanım Kılavuzu / Yönetim / OPKG / OPKG bileşen açıklaması  
Titan (KN-1812)’dan örnek link
  

# BETİK KURULUMU
  
Kurulum için PC veya mobilde SSH/telnet aracı programa ihtiyacınız olacak. PC için PuTTY, mobil için Termius tavsiye edilir.
  
- PC için PuTTY indir:  
  
- Mobil için Termius indir:  
Android için  
iOS için
  
## === PuTTY / Termius aracılığıyla ile SSH üzerinden yapılacak işlemler ===
  
Uygulamada ilgili alana router’ınızın web arayüzüne ulaşmak için kullandığınız IP adresini girin; genelde 192.168.1.1’dir. Port olarak duruma göre 22 veya 222 girin. (PuTTY / Termius'un router bağlantısı için; Keenetic'deki "Bileşen Seçenekleri" nde “SSH Sunucu”sunu daha önce kurmadıysanız OPKG için varsayılan portunuz 22 olacaktır. Ancak daha önce SSH bileşenini kurduysanız OPKG için varsayılan portunuz 222 olacaktır.)

<img src="/docs/images/KZM4.png" width="800">

Open dedikten sonra gelen ekrana default olarak:
  
login as: root  
root@192.168.1.1’s password: keenetic
  
(Uyarı: Password yazılırken yazı gözükmez, ekran tepkisizdir. Siz yazmaya devam edip onaylayın.) İşlem sonunda komut girme ekranı gelecektir.
  
<img src="/docs/images/KZM5.png" width="800">

- Varsayılan keenetic parolasını değiştirmek için aşağıdaki komutu girin:
  
~ # passwd
  
Sistem sırayla eski parolayı (keenetic) girmenizi isteyecek. Sonraki adımda yeni parolayı girin ve parolayı doğrulayın.
  
Başlıca opkg komutları:  
(update, upgrade komutlarını SHH bağlantısı yaptığınız her fırsatta yapmaya çalışın ki OPKG güncellemeleri kontrol edilip güncelleme yapılsın)
  
~ # opkg update  
~ # opkg upgrade  
~ # opkg install <paket_adı>
  
  
## === Keenetic Zapret Manager betiği’nin kurulumu ===
  
Yöntem 1 (pratik):  
PuTTY / Termius’daki komut satırına aşağıdaki komutu yazıp onaylayın. Betik internetten indirip kurulacaktır:
  
```bash
curl -fsSLhttps://raw.githubusercontent.com/RevolutionTR/keenetic-zapret-manager/main/keenetic_zapret_otomasyon_ipv6_ipset.sh \
-o /opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh
chmod +x /opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh
/opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh
```
  
İşlem tamamlandıktan sonra kurulu betiği komut satırına "keenetic" veya "keenetic-zapret" yazıp onaylayarak kullanmaya başlayabilirsiniz.

<img src="/docs/images/KZM8.png" width="800">
  
Yöntem 2 (klasik):  
DH'den @Revolution_TR 'nin geliştirdiği Keenetic router’lar için özelleştirilmiş Zapret betiğini githup linkinden indirin:
  
Router'ın web arayüzüne girip dosya gezgini yardımı ile indirdiğiniz keenetic_zapret_otomasyon_ipv6_ipset.sh dosyasını router'ınızın dahili depolamasında lib/opkg yoluna kopyalayın.
  
PC'de Putty, mobilde Termius ile önce betiğin çalışmasına izin veren sonrada çalıştıran komutları verin (Betik’teki son güncellemeler ile çalışmasına izin vermek için bir komuta ihtiyacı yoktur, betik kendi iznini kendisi almaktadır. Çalıştırmak içinde uzunca komut ve isim yazmak yerine “keenetic” veya “keenetic-zapret” yazıp onaylamak yeterlidir. Ayrıca kurulum için dosyanın kopyalandığı yer yanlış olsa da betik kurulumu doğru yere yapmaktadır).
  
Komutlar:  
Çalışmasına izin vermek için:  
chmod +x /opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh
  
Çalıştırmak için:  
/opt/lib/opkg/keenetic_zapret_otomasyon_ipv6_ipset.sh
  
İşlem tamamlandıktan sonra kurulu betiği komut satırına "keenetic" veya "keenetic-zapret" yazıp onaylayarak kullanmaya başlayabilirsiniz.
  

Keenetic Zapret Manager’ın Tam Kullanım Kılavuzu için geliştiricinin github’daki ilgili sayfasını ziyaret edebilirsiniz.
  



Okuduğunuz için teşekkürler; umarım faydalı bir kaynak olmuştur.

Hazırlayan ve derleyen
- **[@tayaydin](https://forum.donanimhaber.com/profil/173164)**


## Yazının hazırlanmasında istifade edilen kaynaklar:
- **[Keenetic Destek](https://destek.keenetic.com.tr/?lang=tr)**  
- **[Keenetic Zapret Manager github sayfası](https://github.com/RevolutionTR/keenetic-zapret-manager)**  
- **[Forum Keenetic TR](https://forum.keenetictr.com/d/108-keenetic-cihazlarda-zapret-kurulumu-detayli-anlatim)**  
  
