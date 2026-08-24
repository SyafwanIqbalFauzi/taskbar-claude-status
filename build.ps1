# Compile claude-gateway-tray.ps1 menjadi taskbar-claude-status.exe
# menggunakan modul ps2exe (dipasang otomatis jika belum ada).

if (-not (Get-Module -ListAvailable -Name ps2exe)) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    Install-Module -Name ps2exe -Scope CurrentUser -Force -AllowClobber
}

Import-Module ps2exe

Invoke-ps2exe `
    -inputFile (Join-Path $PSScriptRoot "claude-gateway-tray.ps1") `
    -outputFile (Join-Path $PSScriptRoot "taskbar-claude-status.exe") `
    -noConsole -STA `
    -title "Claude Gateway Status" `
    -description "Claude Code gateway status indicator (Kantor/Personal)" `
    -company "Syafwan" `
    -product "Claude Gateway Status Tray" `
    -version "1.0.0.0"

Write-Output "Build selesai: $(Join-Path $PSScriptRoot 'taskbar-claude-status.exe')"
