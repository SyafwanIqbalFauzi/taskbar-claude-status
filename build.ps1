# Compile claude-gateway-tray.ps1 + common.ps1 menjadi taskbar-claude-status.exe
# menggunakan modul ps2exe (dipasang otomatis jika belum ada).

if (-not (Get-Module -ListAvailable -Name ps2exe)) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    Install-Module -Name ps2exe -Scope CurrentUser -Force -AllowClobber
}

Import-Module ps2exe

# ps2exe tidak bisa dot-source file lain saat runtime, jadi isi common.ps1
# disisipkan ke salinan sementara dari script tray.
$common = Get-Content (Join-Path $PSScriptRoot "common.ps1") -Raw
$tray   = Get-Content (Join-Path $PSScriptRoot "claude-gateway-tray.ps1") -Raw
$marker = [regex]::Escape('. (Join-Path $PSScriptRoot "common.ps1")') + '.*@@INCLUDE-COMMON@@'
if ($tray -notmatch $marker) { throw "Marker @@INCLUDE-COMMON@@ tidak ditemukan di claude-gateway-tray.ps1" }
$merged = [regex]::Replace($tray, $marker, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $common })

$mergedPath = Join-Path $env:TEMP "taskbar-claude-status.merged.ps1"
[System.IO.File]::WriteAllText($mergedPath, $merged, (New-Object System.Text.UTF8Encoding($true)))

$exePath = Join-Path $PSScriptRoot "taskbar-claude-status.exe"
$before = if (Test-Path $exePath) { (Get-Item $exePath).LastWriteTimeUtc } else { $null }

try {
    Invoke-ps2exe `
        -inputFile $mergedPath `
        -outputFile (Join-Path $PSScriptRoot "taskbar-claude-status.exe") `
        -noConsole -STA `
        -title "taskbar-claude-status" `
        -description "Claude Code gateway status indicator (Kantor/Personal)" `
        -company "Syafwan" `
        -product "taskbar-claude-status" `
        -version "1.1.0.0"
} finally {
    Remove-Item $mergedPath -ErrorAction SilentlyContinue
}

if (-not (Test-Path $exePath) -or ($before -and (Get-Item $exePath).LastWriteTimeUtc -le $before)) {
    throw "Build GAGAL: .exe tidak diperbarui. Tutup taskbar-claude-status.exe yang sedang berjalan lalu ulangi."
}
Write-Output "Build selesai: $exePath"
