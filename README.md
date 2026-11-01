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
2. Tambahkan satu baris ke PowerShell profile (`$PROFILE`) agar perintah terminal tersedia:
   `. "D:\path\ke\taskbar-claude-status\profile-functions.ps1"`
3. Jalankan `build.ps1` untuk membuat `.exe`.
4. Jalankan `install-startup-shortcut.ps1` agar ikon otomatis muncul saat login.

## Sinkron ke Hermes Agent (opsional, eksperimental)

Secara default switcher hanya mengubah `~/.claude/settings.json` (dibaca Claude
Code). Hermes Agent tidak membaca file itu. Agar Hermes ikut berpindah, tambahkan
di `env-profiles.json`:

```json
"_options": { "syncHermes": true }
```

Saat switch ke `kantor`, Hermes diatur ke `model.provider: custom` +
`api_mode: anthropic_messages` + `model.base_url` gateway (lewat `hermes config
set`), dan token ditulis ke `.env` Hermes sebagai `<VENDOR>_API_KEY` yang
diturunkan dari host (mis. `gateway.contoh.com` menjadi `CONTOH_API_KEY`). Saat switch
ke `personal`, base_url dan kunci gateway dihapus dan provider kembali ke
`anthropic` (login default).

Kenapa bukan `ANTHROPIC_TOKEN`: dengan provider `anthropic` + `ANTHROPIC_TOKEN`,
request ke gateway ditolak 401 saat diuji. Jalur `custom` sudah diuji
end-to-end. Opsi lain: `hermesTokenVar`, `hermesHome`, `hermesPersonalProvider`.

**Sesi Hermes yang sudah berjalan tidak ikut berpindah** (sudah diuji): Hermes membaca
provider saat sesi dimulai, jadi sesi lama tetap memakai akun/gateway sebelumnya
dan biayanya tetap ke sana. Mulai sesi baru setelah switch.

## Perilaku

- `settings.json` ditulis atomik dan backup disimpan di `settings.json.bak`.
- Hanya key `env` yang dikelola profil yang diubah; key env lain tetap.
- Gagal switch (file hilang, JSON rusak) tampil sebagai notifikasi, dan dicatat
  di `~/.claude/gateway-switch.log` (tanpa token).
- Hanya satu instance tray yang berjalan.

## Keamanan

Jangan commit file yang berisi token asli. Repo ini hanya menyertakan template
tanpa data rahasia.
