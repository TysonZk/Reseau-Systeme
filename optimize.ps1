if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Ce script doit etre execute en administrateur."
    exit 1
}

function Title([string]$t) {
    Write-Host ""
    Write-Host "==============================="
    Write-Host "  $t"
    Write-Host "==============================="
    Write-Host ""
}

function Ask([string]$question) {
    $r = Read-Host "$question (O/N)"
    return $r -match '^[oO]$'
}

function Apply([string]$label, [scriptblock]$action) {
    try {
        & $action
        Write-Host ("  [OK] {0}" -f $label) -ForegroundColor Green
    } catch {
        Write-Host ("  [!]  {0} - echec" -f $label) -ForegroundColor Yellow
    }
}

function ServiceDisable([string]$name, [string]$label) {
    $svc = Get-Service -Name $name -EA SilentlyContinue
    if (-not $svc) {
        Write-Host ("  [--] {0} - service absent" -f $label) -ForegroundColor Gray
        return
    }
    if ($svc.StartType -eq 'Disabled') {
        Write-Host ("  [--] {0} - deja desactive" -f $label) -ForegroundColor Gray
        return
    }
    try {
        Stop-Service -Name $name -Force -EA SilentlyContinue
        Set-Service -Name $name -StartupType Disabled
        Write-Host ("  [OK] {0} - desactive" -f $label) -ForegroundColor Green
    } catch {
        Write-Host ("  [!]  {0} - echec" -f $label) -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "==============================="
Write-Host "         OPTIMIZER"
Write-Host "==============================="

# -----------------------------------------------
Title "1. PERFORMANCE GENERALE"
if (Ask "Appliquer les optimisations de performance generale") {

    Apply "Plan alimentation - Haute performance" {
        powercfg -setactive SCHEME_MIN 2>$null
        if ($LASTEXITCODE -ne 0) {
            $guid = (powercfg -duplicatescheme SCHEME_MIN).Split()[3]
            powercfg -setactive $guid
        }
    }

    Apply "Effets visuels - Performance maximale" {
        Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 2 -EA SilentlyContinue
        $path = "HKCU:\Control Panel\Desktop\WindowMetrics"
        New-Item $path -Force -EA SilentlyContinue | Out-Null
        Set-ItemProperty "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -EA SilentlyContinue
    }

    Apply "Transparence Windows - desactivee" {
        Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 0
    }

    Apply "Animations Windows - desactivees" {
        Set-ItemProperty "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "0"
        Set-ItemProperty "HKCU:\Control Panel\Desktop" -Name "DragFullWindows" -Value "0"
        Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations" -Value 0
    }

    Apply "Priorite CPU - Applications en avant-plan" {
        Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 38
    }

    Apply "Tips et suggestions Windows - desactives" {
        Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338389Enabled" -Value 0 -EA SilentlyContinue
        Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-310093Enabled" -Value 0 -EA SilentlyContinue
        Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SoftLandingEnabled" -Value 0 -EA SilentlyContinue
    }

    Apply "Memoire virtuelle - gestion auto" {
        $cs = Get-CimInstance Win32_ComputerSystem
        $cs | Invoke-CimMethod -MethodName SetPropertyValue -Arguments @{AutomaticManagedPagefile=$true} -EA SilentlyContinue | Out-Null
    }
}

# -----------------------------------------------
Title "2. SERVICES INUTILES"
if (Ask "Desactiver les services inutiles") {

    ServiceDisable "SysMain"              "SysMain (Superfetch)"
    ServiceDisable "DiagTrack"            "DiagTrack (Telemetrie Microsoft)"
    ServiceDisable "dmwappushservice"     "WAP Push Message Routing"
    ServiceDisable "MapsBroker"           "Cartes telechargees"
    ServiceDisable "lfsvc"                "Geolocalisation"
    ServiceDisable "XblAuthManager"       "Xbox Auth Manager"
    ServiceDisable "XblGameSave"          "Xbox Game Save"
    ServiceDisable "XboxNetApiSvc"        "Xbox Network Service"
    ServiceDisable "XboxGipSvc"           "Xbox Accessory Management"
    ServiceDisable "RetailDemo"           "Mode demo retail"
    ServiceDisable "WMPNetworkSvc"        "Windows Media Player Network"
    ServiceDisable "Fax"                  "Fax"
}

# -----------------------------------------------
Title "3. GAMING"
if (Ask "Appliquer les optimisations gaming") {

    Apply "Game Mode - active" {
        New-Item "HKCU:\Software\Microsoft\GameBar" -Force -EA SilentlyContinue | Out-Null
        Set-ItemProperty "HKCU:\Software\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 1
        Set-ItemProperty "HKCU:\Software\Microsoft\GameBar" -Name "AllowAutoGameMode"   -Value 1
    }

    Apply "Xbox Game Bar - desactive" {
        Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled"  -Value 0 -EA SilentlyContinue
        Set-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"       -Name "AllowGameDVR"       -Value 0 -EA SilentlyContinue
    }

    Apply "Hardware GPU Scheduling - active" {
        $path = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
        New-Item $path -Force -EA SilentlyContinue | Out-Null
        Set-ItemProperty $path -Name "HwSchMode" -Value 2
    }

    Apply "Nagle Algorithm - desactive (latence reseau)" {
        $tcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
        Get-ChildItem $tcpPath -EA SilentlyContinue | ForEach-Object {
            Set-ItemProperty $_.PSPath -Name "TcpAckFrequency" -Value 1  -EA SilentlyContinue
            Set-ItemProperty $_.PSPath -Name "TCPNoDelay"      -Value 1  -EA SilentlyContinue
        }
    }

    Apply "Priorite GPU - jeux" {
        $gpuPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
        New-Item $gpuPath -Force -EA SilentlyContinue | Out-Null
        Set-ItemProperty $gpuPath -Name "GPU Priority"       -Value 8
        Set-ItemProperty $gpuPath -Name "Priority"           -Value 6
        Set-ItemProperty $gpuPath -Name "Scheduling Category" -Value "High"
    }

    Apply "HAGS (Accelerated GPU Scheduling) - active" {
        Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Value 2 -EA SilentlyContinue
    }
}

# -----------------------------------------------
Title "4. TELEMETRIE ET CONFIDENTIALITE"
if (Ask "Desactiver la telemetrie Windows") {

    Apply "Telemetrie - niveau minimal" {
        Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Value 0 -EA SilentlyContinue
        Set-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"                -Name "AllowTelemetry" -Value 0 -EA SilentlyContinue
    }

    Apply "Publicites personnalisees - desactivees" {
        Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0 -EA SilentlyContinue
    }

    Apply "Rapport d erreurs Windows - desactive" {
        Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" -Name "Disabled" -Value 1 -EA SilentlyContinue
    }

    Apply "Cortana - desactivee" {
        New-Item "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Force -EA SilentlyContinue | Out-Null
        Set-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -Value 0 -EA SilentlyContinue
    }
}

Write-Host ""
Write-Host "==============================="
Write-Host "  Termine. Redemarrer le PC"
Write-Host "  pour appliquer tous les"
Write-Host "  changements."
Write-Host "==============================="
Write-Host ""
