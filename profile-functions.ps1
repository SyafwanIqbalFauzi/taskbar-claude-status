# Perintah terminal: claude-switch-kantor / claude-switch-personal.
#
# Pasang dengan menambahkan SATU baris ini ke PowerShell profile Anda ($PROFILE),
# sesuaikan path-nya:
#
#   . "D:\Projects\taskbar-claude-status\profile-functions.ps1"

. (Join-Path $PSScriptRoot "common.ps1")

function claude-switch-profile {
    param([Parameter(Mandatory)][ValidateSet("kantor","personal")][string]$Profile)

    try { $result = Set-ActiveProfile $Profile }
    catch {
        Write-Host "Gagal pindah profil: $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    # Juga di-mirror ke sesi terminal aktif supaya `claude` langsung memakainya tanpa restart
    "ANTHROPIC_BASE_URL","ANTHROPIC_AUTH_TOKEN","CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY" | ForEach-Object {
        Remove-Item "Env:$_" -ErrorAction SilentlyContinue
    }
    if ($result.Env) {
        foreach ($prop in $result.Env.PSObject.Properties) {
            Set-Item "Env:$($prop.Name)" $prop.Value
        }
    }

    if ($Profile -eq "kantor") {
        Write-Host "Claude Code -> KANTOR gateway [settings.json diperbarui]" -ForegroundColor Yellow
    } else {
        Write-Host "Claude Code -> PERSONAL (akun Pro / login default) [settings.json diperbarui]" -ForegroundColor Green
    }
    if ($result.Hermes) { Write-Host $result.Hermes -ForegroundColor Cyan }
}

function claude-switch-kantor { claude-switch-profile -Profile kantor }
function claude-switch-personal { claude-switch-profile -Profile personal }
function claude-profile { Get-CurrentProfile }
