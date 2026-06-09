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

function Status([string]$label, [string]$current, [string]$target) {
    $same  = $current -eq $target
    $color = if ($same) { "Green" } else { "Yellow" }
    $mark  = if ($same) { "[OK]" } else { "[>>]" }
    Write-Host ("  {0} {1,-35} actuel: {2,-15} -> cible: {3}" -f $mark, $label, $current, $target) -ForegroundColor $color
}

function ServiceStatus([string]$name, [string]$label) {
    $svc = Get-Service -Name $name -EA SilentlyContinue
    if (-not $svc) { return $false }
    $state = $svc.StartType.ToString()
    $color = if ($state -eq "Disabled") { "Green" } else { "Yellow" }
    $mark  = if ($state -eq "Disabled") { "[OK]" } else { "[>>]" }
    Write-Host ("  $mark {0,-35} actuel: {1,-15} -> cible: Disabled" -f $label, $state) -ForegroundColor $color
    return $true
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

# -----------------------------------------------
# DETECTION DU SYSTEME
# -----------------------------------------------
Write-Host ""
Write-Host "==============================="
Write-Host "  ANALYSE DU SYSTEME..."
Write-Host "==============================="
Write-Host ""

$cpu        = Get-CimInstance Win32_Processor | Select-Object -First 1
$gpu        = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notmatch "Microsoft|Basic" } | Select-Object -First 1
$disks      = Get-CimInstance Win32_DiskDrive
$battery    = Get-CimInstance Win32_Battery -EA SilentlyContinue
$os         = Get-CimInstance Win32_OperatingSystem
$ram        = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 0)

$isLaptop   = $null -ne $battery
$gpuVendor  = if ($gpu.Name -match "NVIDIA") { "NVIDIA" } elseif ($gpu.Name -match "AMD|Radeon") { "AMD" } elseif ($gpu.Name -match "Intel") { "Intel" } else { "Inconnu" }
$cpuVendor  = if ($cpu.Name -match "Intel") { "Intel" } elseif ($cpu.Name -match "AMD") { "AMD" } else { "Inconnu" }
$hasSSD     = $disks | Where-Object { $_.MediaType -match "SSD|Solid" -or $_.Caption -match "SSD|NVMe" }
$hasHDD     = $disks | Where-Object { $_.MediaType -match "HDD|Fixed hard disk" }
$hasXbox    = (Get-Service -Name "XblAuthManager" -EA SilentlyContinue) -ne $null
$winBuild   = [int]$os.BuildNumber

Write-Host ("  Type machine   : {0}" -f $(if ($isLaptop) { "Laptop" } else { "Desktop" }))
Write-Host ("  CPU            : {0} ({1})" -f $cpu.Name.Trim(), $cpuVendor)
Write-Host ("  GPU            : {0} ({1})" -f $gpu.Name, $gpuVendor)
Write-Host ("  RAM            : {0} GB" -f $ram)
Write-Host ("  Stockage       : {0}" -f $(
    $parts = @()
    if ($hasSSD) { $parts += "SSD" }
    if ($hasHDD) { $parts += "HDD" }
    $parts -join " + "
))
Write-Host ("  Windows Build  : {0}" -f $winBuild)
Write-Host ("  Services Xbox  : {0}" -f $(if ($hasXbox) { "Presents" } else { "Absents" }))

# -----------------------------------------------
Title "1. PERFORMANCE GENERALE - ETAT ACTUEL"

$powerName   = ((powercfg -getactivescheme) -replace ".*\((.+)\)","$1").Trim()
$transparency = (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -EA SilentlyContinue).EnableTransparency
$taskbarAnim  = (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -EA SilentlyContinue).TaskbarAnimations
$cpuPrio      = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -EA SilentlyContinue).Win32PrioritySeparation

$targetPlan = if ($isLaptop) { "Performances elevees" } else { "Haute performance" }

Status "Plan alimentation"       $powerName                                            $targetPlan
Status "Transparence"            $(if ($transparency -eq 0) {"Desactivee"} else {"Activee"})  "Desactivee"
Status "Animations barre taches" $(if ($taskbarAnim -eq 0) {"Desactivees"} else {"Activees"}) "Desactivees"
Status "Priorite CPU"            "$cpuPrio"                                            "38"

if ($ram -le 8) {
    Write-Host "  [>>] RAM faible ($ram GB) - optimisation memoire virtuelle recommandee" -ForegroundColor Yellow
}

Write-Host ""
if (Ask "Appliquer") {
    Apply "Plan alimentation" {
        if ($isLaptop) {
            powercfg -setactive SCHEME_BALANCED 2>$null
        } else {
            powercfg -setactive SCHEME_MIN 2>$null
            if ($LASTEXITCODE -ne 0) {
                $guid = (powercfg -duplicatescheme SCHEME_MIN).Split()[3]
                powercfg -setactive $guid
            }
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
    if ($ram -le 8) {
        Apply "Memoire virtuelle - ajustement RAM faible" {
            $cs = Get-CimInstance Win32_ComputerSystem
            $cs | Invoke-CimMethod -MethodName SetPropertyValue -Arguments @{AutomaticManagedPagefile=$true} -EA SilentlyContinue | Out-Null
        }
    }
}

# -----------------------------------------------
Title "2. SERVICES INUTILES - ETAT ACTUEL"

$services = @(
    @{ Name="DiagTrack";        Label="DiagTrack (Telemetrie)";         Always=$true  },
    @{ Name="dmwappushservice"; Label="WAP Push";                       Always=$true  },
    @{ Name="MapsBroker";       Label="Cartes telechargees";            Always=$true  },
    @{ Name="lfsvc";            Label="Geolocalisation";                Always=$true  },
    @{ Name="RetailDemo";       Label="Mode demo retail";               Always=$true  },
    @{ Name="WMPNetworkSvc";    Label="Windows Media Player Network";   Always=$true  },
    @{ Name="Fax";              Label="Fax";                            Always=$true  },
    @{ Name="SysMain";          Label="SysMain (Superfetch)";           Always=$false; Condition=($null -ne $hasSSD) },
    @{ Name="XblAuthManager";   Label="Xbox Auth Manager";              Always=$false; Condition=$hasXbox },
    @{ Name="XblGameSave";      Label="Xbox Game Save";                 Always=$false; Condition=$hasXbox },
    @{ Name="XboxNetApiSvc";    Label="Xbox Network";                   Always=$false; Condition=$hasXbox },
    @{ Name="XboxGipSvc";       Label="Xbox Accessory";                 Always=$false; Condition=$hasXbox }
)

$toDisable = @()
foreach ($s in $services) {
    $show = $s.Always -or $s.Condition
    if (-not $show) { continue }
    $exists = ServiceStatus $s.Name $s.Label
    if ($exists) { $toDisable += $s }
}

if ($null -ne $hasSSD) {
    Write-Host "  [INFO] SSD detecte - SysMain (Superfetch) inutile et peut etre desactive" -ForegroundColor Cyan
}
if (-not $hasXbox) {
    Write-Host "  [INFO] Services Xbox absents sur ce systeme" -ForegroundColor Gray
}

Write-Host ""
if ($toDisable.Count -gt 0 -and (Ask "Desactiver ces services")) {
    foreach ($s in $toDisable) { ServiceDisable $s.Name $s.Label }
}

# -----------------------------------------------
Title "3. GAMING - ETAT ACTUEL"

$gameMode = (Get-ItemProperty "HKCU:\Software\Microsoft\GameBar" -EA SilentlyContinue).AutoGameModeEnabled
$gameDvr  = (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" -EA SilentlyContinue).AppCaptureEnabled
$hags     = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -EA SilentlyContinue).HwSchMode
$gpuPrio  = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" -EA SilentlyContinue)."GPU Priority"

Status "Game Mode"               $(if ($gameMode -eq 1) {"Actif"} else {"Inactif"})   "Actif"
Status "Xbox Game Bar"           $(if ($gameDvr -eq 0) {"Desactive"} else {"Active"}) "Desactive"
Status "GPU Scheduling (HAGS)"   $(if ($hags -eq 2) {"Actif"} else {"Inactif"})       "Actif"
Status "Priorite GPU"            "$gpuPrio"                                            "8"

if ($gpuVendor -eq "NVIDIA") {
    Write-Host "  [INFO] GPU NVIDIA detecte - GPU Scheduling compatible" -ForegroundColor Cyan
} elseif ($gpuVendor -eq "AMD") {
    Write-Host "  [INFO] GPU AMD detecte - GPU Scheduling compatible (RDNA2+)" -ForegroundColor Cyan
} elseif ($gpuVendor -eq "Intel") {
    Write-Host "  [INFO] GPU Intel integre - GPU Scheduling disponible mais gain limite" -ForegroundColor Gray
}

if ($winBuild -lt 19041) {
    Write-Host "  [!]  GPU Scheduling requiert Windows 10 2004+ (build 19041)" -ForegroundColor Yellow
}

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
    if ($winBuild -ge 19041) {
        Apply "GPU Scheduling - active" {
            Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -Value 2
        }
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

Status "Telemetrie (niveau)"  "$telemetry"                                             "0"
Status "Publicites perso"     $(if ($ads -eq 0) {"Desactivees"} else {"Activees"})     "Desactivees"
Status "Rapport d erreurs"    $(if ($wer -eq 1) {"Desactive"} else {"Active"})         "Desactive"
Status "Cortana"              $(if ($cortana -eq 0) {"Desactivee"} else {"Activee"})   "Desactivee"

Write-Host ""
if (Ask "Desactiver la telemetrie") {
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
