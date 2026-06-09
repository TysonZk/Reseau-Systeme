if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Ce script doit etre execute en administrateur."
    exit 1
}

$totalFreed = 0

function Get-FolderSize([string]$path) {
    if (-not (Test-Path $path)) { return 0 }
    (Get-ChildItem $path -Recurse -Force -EA SilentlyContinue | Measure-Object -Property Length -Sum).Sum
}

function Clean([string]$label, [string[]]$paths) {
    $freed = 0
    foreach ($p in $paths) {
        if (-not (Test-Path $p)) { continue }
        $freed += Get-FolderSize $p
        Get-ChildItem $p -Recurse -Force -EA SilentlyContinue | Remove-Item -Recurse -Force -EA SilentlyContinue
    }
    $mb = [math]::Round($freed / 1MB, 1)
    $script:totalFreed += $freed
    if ($freed -gt 0) {
        Write-Host ("  [OK] {0,-35} {1} MB liberes" -f $label, $mb) -ForegroundColor Green
    } else {
        Write-Host ("  [--] {0,-35} rien a nettoyer" -f $label) -ForegroundColor Gray
    }
}

function CleanFiles([string]$label, [string[]]$paths) {
    $freed = 0
    foreach ($p in $paths) {
        if (-not (Test-Path $p)) { continue }
        $freed += (Get-Item $p -EA SilentlyContinue).Length
        Remove-Item $p -Force -EA SilentlyContinue
    }
    $mb = [math]::Round($freed / 1MB, 1)
    $script:totalFreed += $freed
    if ($freed -gt 0) {
        Write-Host ("  [OK] {0,-35} {1} MB liberes" -f $label, $mb) -ForegroundColor Green
    } else {
        Write-Host ("  [--] {0,-35} rien a nettoyer" -f $label) -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "==============================="
Write-Host "          CLEANER"
Write-Host "==============================="

Write-Host ""
Write-Host "--- WINDOWS ---"
Clean "Temp utilisateur"          @("$env:TEMP")
Clean "Temp systeme"              @("C:\Windows\Temp")
Clean "Prefetch"                  @("C:\Windows\Prefetch")
Clean "Windows Update cache"      @("C:\Windows\SoftwareDistribution\Download")
Clean "Windows Error Reporting"   @("$env:LOCALAPPDATA\Microsoft\Windows\WER")
Clean "Miniatures (thumbnail)"    @("$env:LOCALAPPDATA\Microsoft\Windows\Explorer")
Clean "Fichiers recents"          @("$env:APPDATA\Microsoft\Windows\Recent")
Clean "Jump Lists"                @("$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations",
                                    "$env:APPDATA\Microsoft\Windows\Recent\CustomDestinations")
Clean "Logs Windows"              @("C:\Windows\Logs")
Clean "Crash dumps"               @("C:\Windows\Minidump", "$env:LOCALAPPDATA\CrashDumps")
Clean "DirectX Shader Cache"      @("$env:LOCALAPPDATA\D3DSCache")

ipconfig /flushdns | Out-Null
Write-Host "  [OK] Cache DNS vide" -ForegroundColor Green

$rb = (New-Object -ComObject Shell.Application).Namespace(0xA)
$rb.Items() | ForEach-Object { Remove-Item $_.Path -Recurse -Force -EA SilentlyContinue }
Write-Host "  [OK] Corbeille videe" -ForegroundColor Green

Write-Host ""
Write-Host "--- NAVIGATEURS ---"
Clean "Chrome cache"              @("$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
                                    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache",
                                    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\GPUCache")
Clean "Edge cache"                @("$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
                                    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache",
                                    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\GPUCache")
Clean "Firefox cache"             @("$env:LOCALAPPDATA\Mozilla\Firefox\Profiles")
Clean "Brave cache"               @("$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Cache",
                                    "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Code Cache")
Clean "Opera cache"               @("$env:APPDATA\Opera Software\Opera Stable\Cache")

Write-Host ""
Write-Host "--- GPU ---"
Clean "NVIDIA Shader Cache"       @("$env:LOCALAPPDATA\NVIDIA\DXCache",
                                    "$env:LOCALAPPDATA\NVIDIA\GLCache",
                                    "$env:APPDATA\NVIDIA\ComputeCache")
Clean "AMD Shader Cache"          @("$env:LOCALAPPDATA\AMD\DXCache",
                                    "$env:TEMP\AMD")
Clean "Intel Shader Cache"        @("$env:LOCALAPPDATA\Intel\ShaderCache")

Write-Host ""
Write-Host "--- JEUX ---"
Clean "Steam cache"               @("$env:LOCALAPPDATA\Steam\htmlcache",
                                    "$env:PROGRAMFILES(x86)\Steam\appcache",
                                    "$env:PROGRAMFILES(x86)\Steam\logs",
                                    "$env:PROGRAMFILES(x86)\Steam\dumps")
Clean "Epic Games cache"          @("$env:LOCALAPPDATA\EpicGamesLauncher\Saved\webcache",
                                    "$env:LOCALAPPDATA\EpicGamesLauncher\Saved\Logs",
                                    "$env:LOCALAPPDATA\EpicGamesLauncher\Saved\Crashes")
Clean "EA App cache"              @("$env:LOCALAPPDATA\Electronic Arts\EA Desktop\cache",
                                    "$env:LOCALAPPDATA\Electronic Arts\EA Desktop\Logs")
Clean "Ubisoft Connect cache"     @("$env:LOCALAPPDATA\Ubisoft Game Launcher\cache",
                                    "$env:LOCALAPPDATA\Ubisoft Game Launcher\logs")
Clean "Battle.net cache"          @("$env:APPDATA\Battle.net\Cache",
                                    "$env:PROGRAMDATA\Battle.net\Agent\Logs")
Clean "Riot / Valorant cache"     @("$env:LOCALAPPDATA\Riot Games\Riot Client\Data\Cache",
                                    "$env:LOCALAPPDATA\Riot Games\Riot Client\Logs")
Clean "League of Legends logs"    @("$env:LOCALAPPDATA\Riot Games\League of Legends\Logs")
Clean "Minecraft cache"           @("$env:APPDATA\.minecraft\logs")
Clean "Rockstar Games cache"      @("$env:LOCALAPPDATA\Rockstar Games\Launcher\cache",
                                    "$env:LOCALAPPDATA\Rockstar Games\GTA V\cache")
Clean "Discord cache"             @("$env:APPDATA\discord\Cache",
                                    "$env:APPDATA\discord\Code Cache",
                                    "$env:APPDATA\discord\GPUCache")

Write-Host ""
Write-Host "==============================="
$totalMB = [math]::Round($totalFreed / 1MB, 1)
$totalGB  = [math]::Round($totalFreed / 1GB, 2)
if ($totalFreed -gt 1GB) {
    Write-Host ("  Total libere : {0} GB" -f $totalGB) -ForegroundColor Cyan
} else {
    Write-Host ("  Total libere : {0} MB" -f $totalMB) -ForegroundColor Cyan
}
Write-Host "==============================="
Write-Host ""
