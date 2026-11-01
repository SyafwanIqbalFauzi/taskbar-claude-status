Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Logika bersama. Saat dijalankan sebagai .ps1 ia di-dot-source; build.ps1
# mengganti baris ini dengan isi common.ps1 agar .exe berdiri sendiri.
. (Join-Path $PSScriptRoot "common.ps1")  # @@INCLUDE-COMMON@@

$script:lastProfile = $null

# Hanya satu instance tray.
$script:mutex = New-Object System.Threading.Mutex($false, "Local\taskbar-claude-status")
if (-not $script:mutex.WaitOne(0)) { return }

function Switch-Profile([string]$Profile) {
    try {
        $result = Set-ActiveProfile $Profile
        $label = $Profile.ToUpper()
        $text = "Claude Code -> $label"
        if ($result.Hermes) { $text += "`n" + $result.Hermes }
        $notifyIcon.ShowBalloonTip(2500, "Claude Gateway", $text, [System.Windows.Forms.ToolTipIcon]::Info)
    } catch {
        Write-SwitchLog "GAGAL switch ke '$Profile': $($_.Exception.Message)"
        $notifyIcon.ShowBalloonTip(5000, "Gagal pindah profil", $_.Exception.Message, [System.Windows.Forms.ToolTipIcon]::Error)
    }
    Update-TrayDisplay
}

function New-DotIcon([string]$Letter, [System.Drawing.Color]$Color) {
    $bmp = New-Object System.Drawing.Bitmap 32,32
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)
    $brush = New-Object System.Drawing.SolidBrush $Color
    $g.FillEllipse($brush, 1, 1, 30, 30)
    $font = New-Object System.Drawing.Font "Segoe UI", 14, ([System.Drawing.FontStyle]::Bold)
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $g.DrawString($Letter, $font, [System.Drawing.Brushes]::White, 16, 17, $sf)
    $g.Dispose()
    return [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
}

$iconKantor   = New-DotIcon "K" ([System.Drawing.Color]::FromArgb(255, 204, 102, 0))
$iconPersonal = New-DotIcon "P" ([System.Drawing.Color]::FromArgb(255, 34, 139, 34))

$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Visible = $true

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$itemKantor   = $menu.Items.Add("Kantor")
$itemPersonal = $menu.Items.Add("Personal")
$menu.Items.Add("-") | Out-Null
$itemExit = $menu.Items.Add("Keluar")
$notifyIcon.ContextMenuStrip = $menu

function Update-TrayDisplay {
    $p = Get-CurrentProfile
    if ($p -eq "kantor") {
        $notifyIcon.Icon = $iconKantor
        $notifyIcon.Text = "Claude Gateway: KANTOR"
    } else {
        $notifyIcon.Icon = $iconPersonal
        $notifyIcon.Text = "Claude Gateway: PERSONAL (akun Pro)"
    }
    $itemKantor.Checked = ($p -eq "kantor")
    $itemPersonal.Checked = ($p -eq "personal")
    $script:lastProfile = $p
}

$itemKantor.Add_Click({ Switch-Profile "kantor" })
$itemPersonal.Add_Click({ Switch-Profile "personal" })
$itemExit.Add_Click({
    $timer.Stop()
    $notifyIcon.Visible = $false
    $notifyIcon.Dispose()
    $script:mutex.ReleaseMutex()
    [System.Windows.Forms.Application]::Exit()
})

Update-TrayDisplay

# Poll the status file so switching from the terminal (claude-switch-kantor/personal) also updates the tray live
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$timer.Add_Tick({
    $current = Get-CurrentProfile
    if ($current -ne $script:lastProfile) { Update-TrayDisplay }
})
$timer.Start()

[System.Windows.Forms.Application]::Run()
