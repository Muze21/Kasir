# KasKita

Aplikasi kasir (POS) untuk toko / usaha keluarga berbasis Flutter dan Supabase. Dibuat dengan konsep shift bersama, jadi beberapa HP/perangkat bisa dipakai transaksi barengan dalam 1 sesi toko.

# Download APK

File APK siap pakai bisa diunduh di [Releases](https://github.com/Muze21/Kasir/releases).

Catatan Install: Jika muncul peringatan _"Install unknown apps"_, aktifkan izin instalasi APK dari browser / file manager di pengaturan Android kamu.

# Fitur Utama

- Shift Bersama: Satu toko buka sesi, semua kasir bisa langsung transaksi di HP masing-masing.
- POS Kasir Cepat: Katalog menu per kategori, kalkulator uang pas & kembalian tunai/QRIS.
- Kirim Struk & Rekap WA: Kirim struk belanja ke pelanggan dan rekap shift ke WhatsApp owner.
- Void Pesanan: Pembatalan pesanan yang salah input (otomatis potong omzet & catat alasan).
- Catat Pengeluaran: Pengeluaran tunai toko langsung memotong kas bersih.
- Kelola Menu: Tambah, ubah harga, dan atur ketersediaan menu langsung di aplikasi.
- Laporan: Ringkasan omzet per shift, kontribusi per kasir, dan laporan berkala.

# Tech Stack

- Framework: Flutter (Dart)
- Backend & Database: Supabase (Auth, PostgreSQL, Row Level Security)
- State Management: Native Flutter (`StatefulWidget` / `setState` & `StreamBuilder`)
- Packages:
  - `supabase_flutter`: Auth & database query client
  - `intl`: Format mata uang Rupiah dan tanggal lokal (`id_ID`)
  - `url_launcher`: Integrasi pesan teks WhatsApp untuk struk & rekap

# Requirement Versi

- Flutter SDK: >= 3.41.0 (dikembangkan di 3.41.5)
- Dart SDK: `^3.11.3`
- Android SDK:
  - `minSdkVersion`: 21 (Android 5.0 Lollipop ke atas, syarat minimum `supabase_flutter`)
  - `compileSdkVersion` / `targetSdkVersion`: 34 atau 35

# Cara Setup (Local Dev)

# 1. Setup Database

1. Buat project baru di [Supabase](https://supabase.com).
2. Buka menu SQL Editor, salin dan jalankan seluruh isi file `supabase_schema.sql`.

# 2. Setup Config

Salin file konfigurasi contoh:

```bash
# Windows (PowerShell / CMD)
copy lib\config\supabase_config.example.dart lib\config\supabase_config.dart

# Linux / Mac / Git Bash
cp lib/config/supabase_config.example.dart lib/config/supabase_config.dart
```

Buka `lib/config/supabase_config.dart`, lalu masukkan `supabaseUrl` dan `supabasePublishableKey` dari project Supabase kamu (Project Settings > API).

# 3. Jalankan Aplikasi

```bash
flutter pub get
flutter run
```

# Build APK Sendiri

```bash
# Universal APK (semua HP Android)
flutter build apk --release

# Atau split per ABI (ukuran jauh lebih kecil)
flutter build apk --split-per-abi
```

File output APK berada di:  
`build/app/outputs/flutter-apk/`
