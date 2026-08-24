# Membuat shortcut di folder Startup Windows agar tray icon otomatis
# berjalan setiap kali login. Jalankan sekali saja secara manual.
#
# Mengarah ke taskbar-claude-status.exe (bukan powershell.exe) supaya
# muncul dengan nama proses sendiri di Task Manager > Startup apps.
# Jika taskbar-claude-status.exe belum ada, build dulu dengan build.ps1.

$exePath = Join-Path $PSScriptRoot "taskbar-claude-status.exe"

if (-not (Test-Path $exePath)) {
    Write-Warning "taskbar-claude-status.exe belum ada. Jalankan build.ps1 dulu."
    return
}

$WshShell = New-Object -ComObject WScript.Shell
$shortcutPath = "$([Environment]::GetFolderPath('Startup'))\taskbar-claude-status.lnk"
$Shortcut = $WshShell.CreateShortcut($shortcutPath)
$Shortcut.TargetPath = $exePath
$Shortcut.WorkingDirectory = $PSScriptRoot
$Shortcut.Description = "taskbar-claude-status"
$Shortcut.Save()

Write-Output "Shortcut dibuat di: $shortcutPath"
