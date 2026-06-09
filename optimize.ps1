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

function Status([string]$label, [string]$current, [string]$target) {
    $same = $current -eq $target
    $color = if ($same) { "Green" } else { "Yellow" }
    $mark  = if ($same) { "[OK]" } else { "[>>]" }
    Write-Host ("  {0} {1,-35} actuel: {2,-15} -> cible: {3}" -f $mark, $label, $current, $target) -ForegroundColor $color
}

function Apply([string]$label, [scriptblock]$action) {
    try {
        & $action
        Write-Host ("  [OK] {0}" -f $label) -ForegroundColor Green
    } catch {
        Write-Host ("  [!]  {0} - echec" -f $label) -ForegroundColor Yellow
    }
}

function ServiceStatus([string]$name, [string]$label) {
    $svc = Get-Service -Name $name -EA SilentlyContinue
    if (-not $svc) {
        Write-Host ("  [--] {0,-35} absent du systeme" -f $label) -ForegroundColor Gray
        return
    }
    $state = $svc.StartType.ToString()
    $color = if ($state -eq "Disabled") { "Green" } else { "Yellow" }
    $mark  = if ($state -eq "Disabled") { "[OK]" } else { "[>>]" }
    Write-Host ("  $mark {0,-35} actuel: {1,-15} -> cible: Disabled" -f $label, $state) -ForegroundColor $color
}

function ServiceDisable([string]$name, [string]$label) {
    $svc = Get-Service -Name $name -EA SilentlyContinue
    if (-not $svc) { return }
    if ($svc.StartType -eq 'Disabled') { return }
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
Title "1. PERFORMANCE GENERALE - ETAT ACTUEL"

$powerPlan   = (powercfg -getactivescheme) -replace ".*: (\S+).*","$1"
$powerName   = (powercfg -getactivescheme) -replace ".*\((.+)\)","$1"
$transparency = (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -EA SilentlyContinue).EnableTransparency
$taskbarAnim  = (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -EA SilentlyContinue).TaskbarAnimations
$cpuPrio      = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -EA SilentlyContinue).Win32PrioritySeparation

Status "Plan alimentation"       $powerName.Trim()                                    "Haute performance"
Status "Transparence"            $(if ($transparency -eq 0) {"Desactivee"} else {"Activee"})   "Desactivee"
Status "Animations barre taches" $(if ($taskbarAnim -eq 0) {"Desactivees"} else {"Activees"})  "Desactivees"
Status "Priorite CPU (valeur)"   "$cpuPrio"                                           "38"

Write-Host ""
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
        Set-ItemProperty "HKCU:\Control Panel\Desktop" -Name "UserPreferencesMask" -Value ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) -EA SilentlyContinue
    }
    Apply "Transparence - desactivee" {
        Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "EnableTransparency" -Value 0
    }
    Apply "Animations - desactivees" {
        Set-ItemProperty "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "0"
        Set-ItemProperty "HKCU:\Control Panel\Desktop" -Name "DragFullWindows" -Value "0"
        Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations" -Value 0
    }
    Apply "Priorite CPU - avant-plan" {
        Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 38
    }
    Apply "Tips et suggestions - desactives" {
        Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-338389Enabled" -Value 0 -EA SilentlyContinue
        Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SubscribedContent-310093Enabled" -Value 0 -EA SilentlyContinue
        Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" -Name "SoftLandingEnabled" -Value 0 -EA SilentlyContinue
    }
}

# -----------------------------------------------
Title "2. SERVICES INUTILES - ETAT ACTUEL"

ServiceStatus "SysMain"          "SysMain (Superfetch)"
ServiceStatus "DiagTrack"        "DiagTrack (Telemetrie)"
ServiceStatus "dmwappushservice" "WAP Push"
ServiceStatus "MapsBroker"       "Cartes telechargees"
ServiceStatus "lfsvc"            "Geolocalisation"
ServiceStatus "XblAuthManager"   "Xbox Auth Manager"
ServiceStatus "XblGameSave"      "Xbox Game Save"
ServiceStatus "XboxNetApiSvc"    "Xbox Network"
ServiceStatus "XboxGipSvc"       "Xbox Accessory"
ServiceStatus "RetailDemo"       "Mode demo retail"
ServiceStatus "WMPNetworkSvc"    "Windows Media Player Network"
ServiceStatus "Fax"              "Fax"

Write-Host ""
if (Ask "Desactiver les services inutiles") {
    ServiceDisable "SysMain"          "SysMain (Superfetch)"
    ServiceDisable "DiagTrack"        "DiagTrack (Telemetrie)"
    ServiceDisable "dmwappushservice" "WAP Push"
    ServiceDisable "MapsBroker"       "Cartes telechargees"
    ServiceDisable "lfsvc"            "Geolocalisation"
    ServiceDisable "XblAuthManager"   "Xbox Auth Manager"
    ServiceDisable "XblGameSave"      "Xbox Game Save"
    ServiceDisable "XboxNetApiSvc"    "Xbox Network"
    ServiceDisable "XboxGipSvc"       "Xbox Accessory"
    ServiceDisable "RetailDemo"       "Mode demo retail"
    ServiceDisable "WMPNetworkSvc"    "Windows Media Player Network"
    ServiceDisable "Fax"              "Fax"
}

# -----------------------------------------------
Title "3. GAMING - ETAT ACTUEL"

$gameMode   = (Get-ItemProperty "HKCU:\Software\Microsoft\GameBar" -EA SilentlyContinue).AutoGameModeEnabled
$gameDvr    = (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -EA SilentlyContinue).AppCaptureEnabled
$hags       = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -EA SilentlyContinue).HwSchMode
$gpuPrio    = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -EA SilentlyContinue)."GPU Priority"

Status "Game Mode"               $(if ($gameMode -eq 1) {"Actif"} else {"Inactif"})   "Actif"
Status "Xbox Game Bar (capture)" $(if ($gameDvr -eq 0) {"Desactive"} else {"Active"}) "Desactive"
Status "GPU Scheduling (HAGS)"   $(if ($hags -eq 2) {"Actif"} else {"Inactif"})       "Actif"
Status "Priorite GPU jeux"       "$gpuPrio"                                            "8"

Write-Host ""
if (Ask "Appliquer les optimisations gaming") {
    Apply "Game Mode - active" {
        New-Item "HKCU:\Software\Microsoft\GameBar" -Force -EA SilentlyContinue | Out-Null
        Set-ItemProperty "HKCU:\Software\Microsoft\GameBar" -Name "AutoGameModeEnabled" -Value 1
        Set-ItemProperty "HKCU:\Software\Microsoft\GameBar" -Name "AllowAutoGameMode"   -Value 1
    }
    Apply "Xbox Game Bar - desactive" {
        Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0 -EA SilentlyContinue
        Set-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"       -Name "AllowGameDVR"      -Value 0 -EA SilentlyContinue
    }
    Apply "GPU Scheduling - active" {
        Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Value 2
    }
    Apply "Nagle Algorithm - desactive" {
        $tcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
        Get-ChildItem $tcpPath -EA SilentlyContinue | ForEach-Object {
            Set-ItemProperty $_.PSPath -Name "TcpAckFrequency" -Value 1 -EA SilentlyContinue
            Set-ItemProperty $_.PSPath -Name "TCPNoDelay"      -Value 1 -EA SilentlyContinue
        }
    }
    Apply "Priorite GPU jeux" {
        $gpuPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
        New-Item $gpuPath -Force -EA SilentlyContinue | Out-Null
        Set-ItemProperty $gpuPath -Name "GPU Priority"        -Value 8
        Set-ItemProperty $gpuPath -Name "Priority"            -Value 6
        Set-ItemProperty $gpuPath -Name "Scheduling Category" -Value "High"
    }
}

# -----------------------------------------------
Title "4. TELEMETRIE - ETAT ACTUEL"

$telemetry = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -EA SilentlyContinue).AllowTelemetry
$ads       = (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -EA SilentlyContinue).Enabled
$wer       = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" -EA SilentlyContinue).Disabled
$cortana   = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -EA SilentlyContinue).AllowCortana

Status "Telemetrie (niveau)"     "$telemetry"                                          "0 (minimal)"
Status "Publicites perso"        $(if ($ads -eq 0) {"Desactivees"} else {"Activees"})  "Desactivees"
Status "Rapport d erreurs"       $(if ($wer -eq 1) {"Desactive"} else {"Active"})      "Desactive"
Status "Cortana"                 $(if ($cortana -eq 0) {"Desactivee"} else {"Activee"}) "Desactivee"

Write-Host ""
if (Ask "Desactiver la telemetrie Windows") {
    Apply "Telemetrie - niveau minimal" {
        Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Value 0 -EA SilentlyContinue
        Set-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"                -Name "AllowTelemetry" -Value 0 -EA SilentlyContinue
    }
    Apply "Publicites personnalisees - desactivees" {
        Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -Value 0 -EA SilentlyContinue
    }
    Apply "Rapport d erreurs - desactive" {
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
