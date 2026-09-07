Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$statusPath   = "$HOME\.claude\gateway-status.txt"
$profilesPath = "$HOME\.claude\env-profiles.json"
$settingsPath = "$HOME\.claude\settings.json"
$script:lastProfile = $null

function Write-Utf8NoBom([string]$Path, [string]$Content) {
    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($false)))
}

function Get-CurrentProfile {
    if (Test-Path $statusPath) {
        $p = (Get-Content $statusPath -Raw).Trim()
        if ($p -eq "kantor" -or $p -eq "personal") { return $p }
    }
    return "personal"
}

function Set-ActiveProfile([string]$Profile) {
    $profiles = Get-Content $profilesPath -Raw | ConvertFrom-Json
    $activeEnv = $profiles.$Profile

    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
    $settings | Add-Member -NotePropertyName env -NotePropertyValue $activeEnv -Force
    Write-Utf8NoBom -Path $settingsPath -Content ($settings | ConvertTo-Json -Depth 20)

    Write-Utf8NoBom -Path $statusPath -Content $Profile
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

$itemKantor.Add_Click({ Set-ActiveProfile "kantor"; Update-TrayDisplay })
$itemPersonal.Add_Click({ Set-ActiveProfile "personal"; Update-TrayDisplay })
$itemExit.Add_Click({ $timer.Stop(); $notifyIcon.Visible = $false; [System.Windows.Forms.Application]::Exit() })

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
