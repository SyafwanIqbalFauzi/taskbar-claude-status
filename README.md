# Claude Gateway Status Tray

Ikon system tray Windows yang menampilkan gateway Claude Code mana yang sedang
aktif (KANTOR / PERSONAL), plus perintah terminal untuk switch di antara
keduanya.

## Isi

- `claude-gateway-tray.ps1` — script sumber tray icon (System.Windows.Forms.NotifyIcon).
  Lingkaran kuning "K" = gateway kantor, lingkaran hijau "P" = akun personal.
  Klik kanan untuk switch langsung dari tray.
- `taskbar-claude-status.exe` — hasil compile dari script di atas (via ps2exe).
  Dipakai untuk Startup supaya muncul sebagai proses `taskbar-claude-status`
  sendiri di Task Manager, bukan sebagai `powershell.exe` generik yang
  tersamar dan sulit dikenali di daftar Startup apps.
- `build.ps1` — compile ulang `claude-gateway-tray.ps1` menjadi `.exe` (jalankan
  setelah mengubah script sumber).
- `profile-functions.ps1` — fungsi `claude-switch-kantor` / `claude-switch-personal`
  untuk ditambahkan ke PowerShell profile (`$PROFILE`).
- `env-profiles.example.json` — template konfigurasi dua profil env. Salin ke
  `~/.claude/env-profiles.json` lalu isi token API kantor Anda sendiri.
- `install-startup-shortcut.ps1` — membuat shortcut di folder Startup Windows
  yang mengarah ke `taskbar-claude-status.exe`, agar tray icon otomatis jalan
  tiap login.

## Cara kerja

Claude Code membaca environment variable (`ANTHROPIC_BASE_URL`,
`ANTHROPIC_AUTH_TOKEN`, dll) dari key `"env"` di `~/.claude/settings.json`.
Karena `settings.json` divalidasi ketat (tidak boleh ada field custom), kedua
profil disimpan terpisah di `~/.claude/env-profiles.json`, dan saat switch,
isi profil yang dipilih disalin ke key `"env"` resmi di `settings.json`.

Status profil aktif juga ditulis ke `~/.claude/gateway-status.txt`, yang
dipantau (polling tiap 1 detik) oleh tray icon supaya selalu sinkron — baik
switch dilakukan lewat terminal maupun lewat menu tray.

## Setup

1. Salin `env-profiles.example.json` ke `~/.claude/env-profiles.json`, isi
   token API kantor Anda pada bagian `"kantor"`.
2. Tambahkan isi `profile-functions.ps1` ke PowerShell profile Anda
   (`$PROFILE`), atau dot-source langsung:
   ```powershell
   . "D:\Projects\taskbar-claude-status\profile-functions.ps1"
   ```
3. Jalankan `build.ps1` sekali untuk compile `taskbar-claude-status.exe`
   (butuh modul `ps2exe`, akan dipasang otomatis jika belum ada).
4. Jalankan `install-startup-shortcut.ps1` sekali untuk auto-start tray icon
   setiap login.
5. (Opsional) Jalankan tray icon sekarang tanpa restart Windows:
   ```powershell
   Start-Process "D:\Projects\taskbar-claude-status\taskbar-claude-status.exe"
   ```

## Kenapa dikompilasi ke .exe?

Saat dijalankan lewat `powershell.exe -File script.ps1`, Windows mencatat
proses di Task Manager / Settings > Startup sebagai **`powershell.exe`**, bukan
dengan nama yang jelas — sehingga entrinya tidak mudah dikenali (dan pada
beberapa kasus registry cache `StartupApproved\StartupFolder` juga baru
di-refresh Explorer di logon berikutnya, jadi bisa terasa "hilang" sesaat
setelah dibuat). Meng-compile ke `.exe` mandiri membuatnya muncul dengan nama
proses sendiri dan lebih konsisten dikenali oleh Windows.

## Pemakaian

```powershell
claude-switch-kantor    # pindah ke gateway kantor
claude-switch-personal  # kembali ke akun Claude Pro pribadi
```

Atau klik kanan ikon di system tray → pilih profil.

## Catatan keamanan

`env-profiles.json` yang berisi token API asli **tidak** disimpan di folder
project ini — hanya template (`.example.json`) tanpa secret. File asli dengan
token hidup di `~/.claude/env-profiles.json`. Jangan commit file berisi token
asli ke version control.
