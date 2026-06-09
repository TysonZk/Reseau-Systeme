if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Ce script doit etre execute en administrateur."
    exit 1
}

function New-Guid {
    return [System.Guid]::NewGuid().ToString().ToUpper()
}

$machineGuidPath  = "HKLM:\SOFTWARE\Microsoft\Cryptography"
$hwProfilePath    = "HKLM:\SYSTEM\CurrentControlSet\Control\IDConfigDB\Hardware Profiles\0001"
$sqmPath          = "HKLM:\SOFTWARE\Microsoft\SQMClient"

$currentMachineGuid  = (Get-ItemProperty $machineGuidPath).MachineGuid
$currentHwProfile    = (Get-ItemProperty $hwProfilePath -ErrorAction SilentlyContinue).HwProfileGuid
$currentSqm          = (Get-ItemProperty $sqmPath -ErrorAction SilentlyContinue).MachineId

Write-Host ""
Write-Host "HWID actuel :"
Write-Host ""
Write-Host "  MachineGuid   : $currentMachineGuid"
Write-Host "  HwProfileGuid : $currentHwProfile"
Write-Host "  SQM MachineId : $currentSqm"
Write-Host ""
Write-Host "  [1] Generer de nouveaux identifiants aleatoires"
Write-Host "  [2] Annuler"
Write-Host ""
$choix = Read-Host "Choix"

if ($choix -ne "1") {
    Write-Host "Annule."
    exit 0
}

$newMachineGuid = New-Guid
$newHwProfile   = "{$( New-Guid )}"
$newSqm         = "{$( New-Guid )}"

Set-ItemProperty -Path $machineGuidPath -Name "MachineGuid" -Value $newMachineGuid

if ($currentHwProfile) {
    Set-ItemProperty -Path $hwProfilePath -Name "HwProfileGuid" -Value $newHwProfile
}

if ($currentSqm) {
    Set-ItemProperty -Path $sqmPath -Name "MachineId" -Value $newSqm
}

Write-Host ""
Write-Host "OK"
Write-Host ""
Write-Host "  MachineGuid   : $newMachineGuid"
Write-Host "  HwProfileGuid : $newHwProfile"
Write-Host "  SQM MachineId : $newSqm"
Write-Host ""
Write-Host "Redemarrer le PC pour appliquer les changements."
