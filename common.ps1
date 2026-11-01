# Logika bersama untuk tray (claude-gateway-tray.ps1) dan perintah terminal
# (profile-functions.ps1). build.ps1 menyisipkan file ini ke dalam .exe.
# Kompatibel dengan Windows PowerShell 5.1.

$script:ClaudeDir     = Join-Path $HOME ".claude"
$script:StatusPath    = Join-Path $script:ClaudeDir "gateway-status.txt"
$script:ProfilesPath  = Join-Path $script:ClaudeDir "env-profiles.json"
$script:SettingsPath  = Join-Path $script:ClaudeDir "settings.json"
$script:LogPath       = Join-Path $script:ClaudeDir "gateway-switch.log"
$script:ValidProfiles = @("kantor", "personal")

function Write-Utf8NoBom([string]$Path, [string]$Content) {
    # Tulis ke file sementara lalu tukar, supaya file tujuan tidak pernah setengah tertulis.
    $tmp = "$Path.tmp"
    [System.IO.File]::WriteAllText($tmp, $Content, (New-Object System.Text.UTF8Encoding($false)))
    if (Test-Path $Path) {
        [System.IO.File]::Replace($tmp, $Path, "$Path.bak")
    } else {
        [System.IO.File]::Move($tmp, $Path)
    }
}

function Write-SwitchLog([string]$Message) {
    # Jangan pernah menulis token ke log.
    try {
        $line = "{0}  {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
        Add-Content -Path $script:LogPath -Value $line -Encoding UTF8
    } catch {}
}

function Read-JsonFile([string]$Path, [string]$Label) {
    if (-not (Test-Path $Path)) { throw "$Label tidak ditemukan: $Path" }
    $raw = Get-Content $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) { throw "$Label kosong: $Path" }
    try { return ($raw | ConvertFrom-Json) }
    catch { throw "$Label bukan JSON valid: $Path" }
}

function Get-CurrentProfile {
    if (Test-Path $script:StatusPath) {
        $p = (Get-Content $script:StatusPath -Raw).Trim()
        if ($script:ValidProfiles -contains $p) { return $p }
    }
    return "personal"
}

# --- Claude Code --------------------------------------------------------------

function Set-ClaudeSettingsEnv($Profiles, [string]$Profile) {
    # Hanya menyentuh key env yang dikelola profil (gabungan semua profil).
    # Key env lain di settings.json milik Anda dibiarkan.
    $activeEnv = $Profiles.$Profile
    $managed = @{}
    foreach ($name in $script:ValidProfiles) {
        $p = $Profiles.$name
        if ($p) { foreach ($prop in $p.PSObject.Properties) { $managed[$prop.Name] = $true } }
    }

    $settings = Read-JsonFile $script:SettingsPath "settings.json"
    $newEnv = [ordered]@{}
    if ($settings.env) {
        foreach ($prop in $settings.env.PSObject.Properties) {
            if (-not $managed.ContainsKey($prop.Name)) { $newEnv[$prop.Name] = $prop.Value }
        }
    }
    if ($activeEnv) {
        foreach ($prop in $activeEnv.PSObject.Properties) { $newEnv[$prop.Name] = $prop.Value }
    }
    $settings | Add-Member -NotePropertyName env -NotePropertyValue ([pscustomobject]$newEnv) -Force
    Write-Utf8NoBom -Path $script:SettingsPath -Content ($settings | ConvertTo-Json -Depth 20)
}

# --- Hermes (opsional) --------------------------------------------------------
# Aktifkan dengan menambah di env-profiles.json:
#   "_options": { "syncHermes": true }
# Opsional: "hermesTokenVar" (override nama variabel kunci), "hermesHome",
# dan "hermesPersonalProvider" (default "anthropic").

function Get-HermesHome($Options) {
    if ($Options -and $Options.hermesHome) { return [string]$Options.hermesHome }
    if ($env:HERMES_HOME) { return $env:HERMES_HOME }
    $local = Join-Path $env:LOCALAPPDATA "hermes"
    if (Test-Path $local) { return $local }
    return (Join-Path $HOME ".hermes")
}

function Get-HermesExe([string]$HermesHome) {
    $cmd = Get-Command hermes -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidate = Join-Path $HermesHome "bin\hermes.exe"
    if (Test-Path $candidate) { return $candidate }
    return $null
}

function Set-DotEnvVar([string]$Path, [string]$Name, $Value) {
    # $Value = $null menghapus variabel. Baris/komentar lain tidak diubah.
    $lines = @()
    if (Test-Path $Path) { $lines = [System.IO.File]::ReadAllLines($Path) }
    $out = New-Object System.Collections.Generic.List[string]
    $written = $false
    $pattern = "^\s*" + [regex]::Escape($Name) + "\s*="
    foreach ($l in $lines) {
        if ($l -match $pattern) {
            if ($null -ne $Value -and -not $written) { $out.Add("$Name=$Value"); $written = $true }
        } else { $out.Add($l) }
    }
    if ($null -ne $Value -and -not $written) { $out.Add("$Name=$Value") }
    Write-Utf8NoBom -Path $Path -Content (($out -join "`r`n") + "`r`n")
}

function Get-HermesKeyVar([string]$BaseUrl) {
    # Meniru aturan Hermes: <VENDOR>_API_KEY, vendor = label domain terdaftar
    # (gateway.contoh.com -> CONTOH_API_KEY). Kosong jika tidak bisa diturunkan.
    try { $hostName = ([Uri]$BaseUrl).Host } catch { return "" }
    if (-not $hostName -or $hostName -eq "localhost" -or $hostName -match "^[\d.]+$") { return "" }
    $labels = New-Object System.Collections.Generic.List[string]
    foreach ($l in $hostName.Split(".")) { if ($l) { $labels.Add($l) } }
    while ($labels.Count -gt 0 -and ($labels[0] -eq "api" -or $labels[0] -eq "www")) { $labels.RemoveAt(0) }
    if ($labels.Count -lt 2) { return "" }
    $name = ($labels[$labels.Count - 2] -replace "[^A-Za-z0-9]", "_").ToUpper()
    if ($name -notmatch "^[A-Z]" -or @("OPENAI","OPENROUTER","OLLAMA") -contains $name) { return "" }
    return "${name}_API_KEY"
}

function Sync-HermesProfile($Profiles, [string]$Profile) {
    # Mengembalikan teks status singkat, atau $null jika sync tidak aktif.
    #
    # Hermes dengan provider "anthropic" mengabaikan model.base_url dan tetap menembak
    # api.anthropic.com. Gateway kustom harus lewat provider "custom" + api_mode
    # anthropic_messages, dengan kunci di <VENDOR>_API_KEY (bukan ANTHROPIC_TOKEN).
    # Profil personal mengembalikan provider ke "anthropic" (login default / OAuth).
    $opts = $Profiles._options
    if (-not ($opts -and $opts.syncHermes)) { return $null }

    $hermesHome = Get-HermesHome $opts
    $hermes = Get-HermesExe $hermesHome
    if (-not $hermes) { Write-SwitchLog "Hermes sync dilewati: hermes.exe tidak ditemukan"; return "Hermes: hermes.exe tidak ditemukan" }
    if (-not (Test-Path $hermesHome)) { Write-SwitchLog "Hermes sync dilewati: $hermesHome tidak ada"; return "Hermes: folder home tidak ada" }

    $activeEnv = $Profiles.$Profile
    $baseUrl   = if ($activeEnv) { [string]$activeEnv.ANTHROPIC_BASE_URL } else { "" }
    $token     = if ($activeEnv -and $activeEnv.ANTHROPIC_AUTH_TOKEN) { [string]$activeEnv.ANTHROPIC_AUTH_TOKEN } else { $null }
    $isGateway = [bool]$baseUrl

    # Kunci gateway dikelola per host, jadi kunci milik profil lain dibersihkan.
    $keyVar = if ($opts.hermesTokenVar) { [string]$opts.hermesTokenVar } else { $null }
    $allUrls = @()
    foreach ($n in $script:ValidProfiles) {
        $pe = $Profiles.$n
        if ($pe -and $pe.ANTHROPIC_BASE_URL) { $allUrls += [string]$pe.ANTHROPIC_BASE_URL }
    }
    $envPath = Join-Path $hermesHome ".env"
    foreach ($u in $allUrls) {
        $v = if ($keyVar) { $keyVar } else { Get-HermesKeyVar $u }
        if ($v -and -not ($isGateway -and $u -eq $baseUrl)) { Set-DotEnvVar -Path $envPath -Name $v -Value $null }
    }
    if ($isGateway) {
        $v = if ($keyVar) { $keyVar } else { Get-HermesKeyVar $baseUrl }
        if (-not $v) { Write-SwitchLog "Hermes sync gagal: nama variabel kunci tidak bisa diturunkan dari host; set hermesTokenVar"; return "Hermes: set hermesTokenVar" }
        # Token (rahasia) ditulis langsung ke .env, bukan lewat argumen command line.
        Set-DotEnvVar -Path $envPath -Name $v -Value $token
        $provider = "custom"
    } else {
        $provider = if ($opts.hermesPersonalProvider) { [string]$opts.hermesPersonalProvider } else { "anthropic" }
    }

    # Nilai non-rahasia lewat CLI resmi (config.yaml tidak diedit manual). Satu proses cmd
    # berurutan di background karena `hermes` butuh beberapa detik per perintah.
    $h = "`"$hermes`""
    # Tanda kutip terluar wajib: cmd /c membuang kutip pertama dan terakhir jika baris diawali kutip.
    # base_url kosong tidak boleh dikirim sebagai argumen "" (cmd merusaknya), jadi pakai `unset`.
    $urlCmd = if ($isGateway) { "$h config set model.base_url `"$baseUrl`"" } else { "$h config unset model.base_url" }
    $cmdLine = "/c `"$h config set model.provider $provider && $h config set model.api_mode anthropic_messages && $urlCmd`""
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "cmd.exe"
    $psi.Arguments = $cmdLine
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.EnvironmentVariables["HERMES_HOME"] = $hermesHome
    # Switch beruntun cepat: tunggu proses sebelumnya selesai agar urutan tulis tidak tertukar.
    if ($script:HermesProc -and -not $script:HermesProc.HasExited) { [void]$script:HermesProc.WaitForExit(30000) }
    $script:HermesProc = [System.Diagnostics.Process]::Start($psi)

    $target = if ($isGateway) { "gateway ($provider)" } else { "login default ($provider)" }
    Write-SwitchLog "Hermes disinkronkan ke profil '$Profile': $target"
    return "Hermes: $target"
}

# --- Entry point --------------------------------------------------------------

function Set-ActiveProfile([string]$Profile) {
    # Melempar exception dengan pesan jelas jika gagal. Tidak mengubah apa pun
    # sebelum profil terbukti ada.
    if ($script:ValidProfiles -notcontains $Profile) { throw "Profil tidak dikenal: $Profile" }
    $profiles = Read-JsonFile $script:ProfilesPath "env-profiles.json"
    if ($null -eq $profiles.$Profile) { throw "Profil '$Profile' tidak ada di env-profiles.json" }

    Set-ClaudeSettingsEnv -Profiles $profiles -Profile $Profile
    Write-Utf8NoBom -Path $script:StatusPath -Content $Profile
    Write-SwitchLog "Claude Code dialihkan ke profil '$Profile'"

    $hermesStatus = $null
    try { $hermesStatus = Sync-HermesProfile -Profiles $profiles -Profile $Profile }
    catch {
        Write-SwitchLog "Hermes sync gagal: $($_.Exception.Message)"
        $hermesStatus = "Hermes: sync gagal (lihat gateway-switch.log)"
    }
    return [pscustomobject]@{ Profile = $Profile; Hermes = $hermesStatus; Env = $profiles.$Profile }
}
