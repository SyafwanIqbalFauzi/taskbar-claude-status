# Claude Gateway Status Tray

Aplikasi kecil untuk Windows yang menampilkan ikon di system tray, menunjukkan
Claude Code sedang memakai akun **Kantor** (kuning, "K") atau **Personal**
(hijau, "P"). Klik kanan ikonnya untuk berpindah di antara keduanya.

> **Catatan:** Ini proyek pribadi yang dibuat untuk kebutuhan saya sendiri.
> Dibagikan apa adanya, tanpa dukungan atau jaminan. Silakan dipakai atau
> dimodifikasi sesuka Anda.

## Pemakaian

- Klik kanan ikon di tray, lalu pilih profil.
- Atau lewat terminal:

```powershell
claude-switch-kantor
claude-switch-personal
```

## Pasang

1. Salin `env-profiles.example.json` ke `~/.claude/env-profiles.json`, lalu isi
   dengan data Anda sendiri.
2. Tambahkan `profile-functions.ps1` ke PowerShell profile.
3. Jalankan `build.ps1` untuk membuat `.exe`.
4. Jalankan `install-startup-shortcut.ps1` agar ikon otomatis muncul saat login.

## Keamanan

Jangan commit file yang berisi token asli. Repo ini hanya menyertakan template
tanpa data rahasia.
