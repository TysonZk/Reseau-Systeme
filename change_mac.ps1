if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Ce script doit etre execute en administrateur."
    exit 1
}

$adapters = Get-NetAdapter | Where-Object { $_.InterfaceType -ne 24 -and $_.Virtual -eq $false }

if ($adapters.Count -eq 0) {
    Write-Host "Aucune interface trouvee."
    exit 1
}

Write-Host ""
Write-Host "Interfaces disponibles :"
Write-Host ""
for ($i = 0; $i -lt $adapters.Count; $i++) {
    $a = $adapters[$i]
    Write-Host ("  [{0}] {1,-20} MAC: {2,-20} Etat: {3}" -f ($i+1), $a.Name, $a.MacAddress, $a.Status)
}

Write-Host ""
$choix = Read-Host "Interface [1-$($adapters.Count)]"

if ($choix -notmatch '^\d+$' -or [int]$choix -lt 1 -or [int]$choix -gt $adapters.Count) {
    Write-Host "Choix invalide."
    exit 1
}

$adapter = $adapters[[int]$choix - 1]
Write-Host ""
Write-Host "$($adapter.Name) -> $($adapter.MacAddress)"
Write-Host ""
Write-Host "  [1] MAC aleatoire"
Write-Host "  [2] MAC manuelle"
Write-Host ""
$mode = Read-Host "Choix"

function New-RandomMac {
    $bytes = 1..6 | ForEach-Object { '{0:X2}' -f (Get-Random -Maximum 256) }
    $bytes[0] = '{0:X2}' -f (([Convert]::ToInt32($bytes[0], 16) -band 0xFE) -bor 0x02)
    return $bytes -join ''
}

switch ($mode) {
    "1" {
        $newMac = New-RandomMac
    }
    "2" {
        $newMac = Read-Host "Nouvelle MAC (xxxxxxxxxxxx sans separateur)"
        if ($newMac -notmatch '^[0-9a-fA-F]{12}$') {
            Write-Host "Format invalide."
            exit 1
        }
        $newMac = $newMac.ToUpper()
    }
    default {
        Write-Host "Choix invalide."
        exit 1
    }
}

Write-Host ""

$regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002BE10318}"
$found = $false

Get-ChildItem $regPath -ErrorAction SilentlyContinue | ForEach-Object {
    $key = $_
    $driverDesc = (Get-ItemProperty $key.PSPath -ErrorAction SilentlyContinue).DriverDesc
    if ($driverDesc -eq $adapter.InterfaceDescription) {
        Set-ItemProperty $key.PSPath -Name "NetworkAddress" -Value $newMac -ErrorAction Stop
        $found = $true
    }
}

if (-not $found) {
    Write-Host "Impossible de trouver la cle registre pour cette interface."
    exit 1
}

Disable-NetAdapter -Name $adapter.Name -Confirm:$false
Start-Sleep -Seconds 2
Enable-NetAdapter -Name $adapter.Name -Confirm:$false
Start-Sleep -Seconds 2

$verify = (Get-NetAdapter -Name $adapter.Name).MacAddress -replace '-', ''
if ($verify -eq $newMac) {
    Write-Host "OK -> $($verify -replace '(.{2})(?=.)', '$1:')"
} else {
    Write-Host "Echec. MAC actuelle : $verify"
    exit 1
}
