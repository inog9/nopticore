# Nopticore — Node Observability Platform: Trust Intelligence CORE

*the watchful core for your device fleet*

Companion project untuk [wazuh-mobile-sentinel](https://github.com/cyberxperts29-sudo/wazuh-mobile-sentinel)
(versi Android), khusus device iOS **jailbreak**. Daemon ini analog ke app
Android tadi: kumpulin posture device + daftar package terinstal, kirim
sebagai JSON ke Flask receiver, lalu Wazuh baca lewat log monitoring.

Dokumen arsitektur lengkap (termasuk temuan audit teknis) ada di dokumen
terpisah "Arsitektur Nopticore (iOS)" -- baca itu dulu sebelum build,
terutama bagian 13 (Temuan Audit & Pengetahuan iOS Development) karena
beberapa hal di skeleton ini sudah dikoreksi sesuai temuan itu:
- `device_id` sekarang pakai UUID persisten sendiri (bukan `kern.uuid`,
  yang bukan sysctl key valid)
- Deteksi path rootful vs rootless otomatis (`/var/jb` prefix) untuk
  path dpkg status dan artifact jailbreak

**Device target:** iPhone 7 / iPad 6th gen (chip A10, kompatibel checkra1n).

## Prasyarat

1. **Device sudah jailbreak** (checkra1n direkomendasikan untuk A10).
2. **Theos** terinstal di mesin dev kamu (macOS atau Linux):
   https://theos.dev/docs/installation
3. Package manager di device (Sileo/Zebra/Cydia) — dipakai daemon buat baca
   `/var/lib/dpkg/status`.
4. OpenSSH terpasang di device (biasanya otomatis kalau checkra1n bootstrap
   lewat Sileo/Cydia) supaya bisa `theos-package --install` lewat SSH.

## Setup

1. Clone/salin folder proyek ini ke mesin dev kamu, pastikan `$THEOS` env var
   sudah di-set sesuai instalasi Theos kamu.

2. **Konfigurasi runtime** — daemon membaca URL backend, token, tier, dan
   interval dari sebuah plist di device (bukan hardcode di kode lagi), jadi
   bisa diganti tanpa rebuild. Buat file ini di device via SSH:

   `/var/mobile/Library/Preferences/com.ptxyz.nopticore.config.plist`

   Isi (plist dict):
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
     <key>backend_url</key><string>https://nopticore.ptxyz.tech/ingest/ios</string>
     <key>auth_token</key><string>TOKEN-UNIK-PER-DEVICE</string>
     <key>tier</key><string>full</string>
     <key>interval</key><integer>300</integer>
   </dict>
   </plist>
   ```

   - `auth_token` **wajib** — backend Flask menolak request tanpa token
     (`401`). Token harus unik per device.
   - `tier` = `full` untuk device jailbreak (default), `lite` untuk
     non-jailbreak nanti.
   - `interval` opsional (detik), default 300, minimum 30.

   Kalau file config belum ada, daemon tetap jalan tapi pakai URL placeholder
   (yang gagal DNS) dan token kosong — log akan memperingatkan.

3. (Opsional) Ganti `THEOS_DEVICE_IP` di `Makefile` kalau mau langsung
   install ke device lewat SSH pas build.

## Build & Install

```bash
export THEOS_DEVICE_IP=192.168.1.50   # IP device kamu di jaringan lokal
make package install
```

Ini akan:
- Compile daemon jadi binary `nopticored`
- Bungkus jadi `.deb`
- Copy ke `/usr/libexec/nopticored` di device
- Copy launchd plist ke `/Library/LaunchDaemons/`
- Load daemon-nya otomatis (lihat `after-install::` di Makefile)

Kalau mau build `.deb` doang tanpa langsung install (misal mau
distribusi manual via `dpkg -i` di device):

```bash
make package
```

File `.deb` hasilnya ada di folder `packages/`.

## Verifikasi jalan

SSH ke device:

```bash
ssh root@<device-ip>
tail -f /var/log/nopticored.log
```

Harusnya muncul log tiap 5 menit: `posture collected: N packages, M
jailbreak artifacts` diikuti status HTTP dari Flask receiver.

## Field yang dikirim (skema JSON)

```json
{
  "device_id": "...",
  "tier": "full",
  "device_model": "iPhone9,1",
  "os_version": "15.8.2 (19H384)",
  "is_jailbroken": true,
  "jailbreak_artifacts": ["/Applications/Cydia.app", "..."],
  "jailbreak_artifact_count": 5,
  "installed_package_count": 42,
  "installed_packages": [{"name": "...", "version": "..."}],
  "disk_usage": {"total_bytes": 0, "free_bytes": 0},
  "uptime_seconds": "123456",
  "timestamp": 1234567890,
  "collector_version": "0.1.0"
}
```

Field ini sengaja dinamai supaya paralel dengan skema Android
(`device_model`, `installed_package_count`, dst) — jadi decoder JSON
bawaan Wazuh yang sudah kamu pakai untuk proyek Android bisa langsung
dipakai ulang, tinggal tambah rule baru yang mencocokkan field khas iOS
ini (`jailbreak_artifact_count`, dll).

## Yang BELUM ada di v0.1.0 (next steps)

- **Deteksi real-time install package baru** — analog `PACKAGE_ADDED`
  broadcast di Android. **Koreksi (lihat dokumen arsitektur bagian
  13.2):** `installd` cuma menangani instalasi app/IPA resmi Apple,
  BUKAN paket dpkg/Cydia — hooking `installd` tidak akan mendeteksi
  instalasi tweak sama sekali. Pendekatan yang benar: kqueue vnode
  event pada file status dpkg, atau hook binary `dpkg`/`apt` pakai
  **ElleKit** (bukan MobileSubstrate/libhooker lama — lihat 13.3).
  Ini langkah lanjutan kalau v0.1.0 sudah stabil.
- Status passcode/enkripsi detail — API publik Apple untuk ini terbatas,
  perlu riset tambahan (kemungkinan lewat private framework, riskier).
- Contoh `local_rules.xml` untuk Wazuh yang cocok dengan skema di atas
  (bisa saya bantu susun setelah data real mulai masuk).
