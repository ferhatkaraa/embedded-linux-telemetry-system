# Gömülü Linux Telemetri Sistemi ve Sürücü Analiz Projesi

Bu proje, ARMv7 (Cortex‑A9) mimarisini hedefleyen simüle bir gömülü Linux sisteminin sıfırdan inşa edilmesini, prosesler arası iletişim (IPC) mekanizmalarının tasarımını, cihaz ağacı (Device Tree) düzenlemelerini ve karakter sürücü (character driver) analizlerini içerir.

## Proje Bilgileri

- **Öğrenci No:** 170425508
- **Ad Soyad:** Ferhat Kara
- **Kurum:** Marmara Üniversitesi — Bilgisayar Mühendisliği

---

## Proje Klasör Yapısı

Proje dizini, tipik bir Linux dosya sistemi hiyerarşisine uygun şekilde düzenlenmiştir:

```text
170425508_ferhatkara/
├── README.md
├── prompts.txt
├── report.pdf
├── screenshots/
├── source_code/
│   ├── telemetry.c
│   ├── telemetry_ipc.c
│   ├── telemetry       # ARMv7 target binary (Verici)
│   └── telemetry_ipc   # ARMv7 target binary (Alıcı)
├── rootfs/
│   └── make_rootfs.sh
├── dts/
│   └── telemetry_led.dts
└── qemu/
    └── rootfs.cpio.gz
```

## Geliştirme ve Derleme Aşamaları

1) Çapraz derleme (Cross‑compile)

Uygulamalar C11 standardına uygun olarak, gerekli POSIX makroları (ör. `#define _POSIX_C_SOURCE 200809L`) tanımlanıp GNU ARM cross‑compiler ile derlenmiştir.

Örnek derleme (source_code içinden):

```bash
cd source_code/
arm-linux-gnueabihf-gcc -Wall -Wextra -O2 -std=c11 telemetry.c -o telemetry
arm-linux-gnueabihf-gcc -Wall -Wextra -O2 -std=c11 telemetry_ipc.c -o telemetry_ipc
```

2) RootFS inşası (BusyBox)

`rootfs/make_rootfs.sh` betiği BusyBox'u statik olarak derler (`CONFIG_STATIC=y`), gerekli dizin ağacını oluşturur ve `inittab`/`rcS` betiklerini yerleştirerek `rootfs.cpio.gz` imajını üretir.

```bash
cd rootfs/
chmod +x make_rootfs.sh
./make_rootfs.sh
```

## IPC (Süreçler Arası İletişim) — Canlı Test Prosedürü

Projede telemetri verileri için adlandırılmış borular (named pipes / FIFO) kullanılmıştır. Vericinin stdout'u satır tamponlu (line‑buffered) olacak şekilde `setvbuf(stdout, NULL, _IOLBF, 0);` uygulanmıştır.

Test adımları (lokal / WSL):

1) Alıcı (dinleyici) terminal:

```bash
cd source_code/
gcc telemetry_ipc.c -o telemetry_ipc_local
./telemetry_ipc_local
# Bu süreç /tmp/telemetry_fifo'yu bloklayarak dinler
```

2) Verici (üreteç) terminal:

```bash
cd source_code/
gcc telemetry.c -o telemetry_local
./telemetry_local > /tmp/telemetry_fifo
# Sensör verisi her saniyede FIFO'ya yazılır
```

Kapanış davranışı: Her iki süreç de `struct sigaction` ile sinyal yönetimi uygular; `SIGINT` (Ctrl+C) ile düzgün kapanma sağlanır.

## Teorik Analiz Özetleri

### Device Tree (Cihaz Ağacı)

`dts/telemetry_led.dts` içinde `compatible = "gpio-leds"` tanımı kullanılarak kernel'in hazır `leds-gpio` desteği etkinleştirilmiş, bu sayede `/sys/class/leds/telemetry-status/` gibi sysfs düğümleri oluşur.

### Karakter Sürücü (Character Driver)

Karakter sürücü tasarımında `file_operations` tablosu üzerinden `open`, `read`, `write` gibi VFS çağrıları çekirdek içi fonksiyonlarla eşleştirilir. Kullanıcı alanı ile çekirdek alanı arasındaki veri geçişleri için `copy_to_user()` ve `copy_from_user()` gibi güvenli API'lerin kullanımı zorunludur.

## Hata Ayıklama Notları (Kısa)

- WSL / NTFS kısıtlaması: NTFS üzerinde `mknod` ve dosya adlarındaki boşluklar sorun çıkardığı için proje saf Linux (`ext4`) bir alana taşındı.
- Dağıtım depo uyuşmazlığı: Ubuntu 24.04'te 32-bit ARM paketleri çekirdek depolarda olmayınca `foreign-architecture` ve `ports.ubuntu.com` kullanılarak multiarch çözümü uygulandı.

Detaylı hata günlükleri ve açıklamalar için `prompts.txt` dosyasına bakın.

---

Güncelleme: README dosyası biçimlendirildi ve kod blokları, başlık yapıları ile maddelemeler düzeltildi.
