# Tambahkan isi file ini ke PowerShell profile Anda ($PROFILE)
# untuk perintah claude-switch-kantor / claude-switch-personal.

function claude-switch-profile {
    param([Parameter(Mandatory)][ValidateSet("kantor","personal")][string]$Profile)

    $profilesPath = "$HOME\.claude\env-profiles.json"
    $settingsPath = "$HOME\.claude\settings.json"

    $profiles = Get-Content $profilesPath -Raw | ConvertFrom-Json
    $activeEnv = $profiles.$Profile

    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
    $settings | Add-Member -NotePropertyName env -NotePropertyValue $activeEnv -Force

    $settings | ConvertTo-Json -Depth 20 | Set-Content -Path $settingsPath -Encoding utf8NoBOM

    # Juga di-mirror ke sesi terminal aktif supaya `claude` langsung memakainya tanpa restart
    "ANTHROPIC_BASE_URL","ANTHROPIC_AUTH_TOKEN","CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY" | ForEach-Object {
        Remove-Item "Env:$_" -ErrorAction SilentlyContinue
    }
    foreach ($prop in $activeEnv.PSObject.Properties) {
        Set-Item "Env:$($prop.Name)" $prop.Value
    }

    Set-Content -Path "$HOME\.claude\gateway-status.txt" -Value $Profile -Encoding utf8NoBOM -NoNewline

    if ($Profile -eq "kantor") {
        Write-Host "Claude Code -> KANTOR gateway [settings.json diperbarui]" -ForegroundColor Yellow
    } else {
        Write-Host "Claude Code -> PERSONAL (akun Pro / login default) [settings.json diperbarui]" -ForegroundColor Green
    }
}

function claude-switch-kantor { claude-switch-profile -Profile kantor }
function claude-switch-personal { claude-switch-profile -Profile personal }
