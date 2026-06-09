if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Ce script doit etre execute en administrateur."
    exit 1
}

function New-RandomGuid { return [System.Guid]::NewGuid().ToString().ToUpper() }

function New-RandomSerial {
    $chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    return -join (1..12 | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
}

function New-RandomHex([int]$length) {
    return -join (1..$length | ForEach-Object { '{0:X2}' -f (Get-Random -Maximum 256) })
}

$vendors  = @("Dell Inc.", "HP", "ASUS", "Lenovo", "Acer", "MSI", "Gigabyte Technology")
$products = @("OptiPlex 7090", "EliteDesk 800 G6", "ROG STRIX B550-F", "ThinkCentre M90q", "Aspire XC-895", "MAG Z590 TOMAHAWK", "B550 AORUS PRO")
$biosVers = @("1.12.0", "2.4.1", "3.0.0", "F15", "F8b", "2.17.1246", "1.8.0")

Write-Host ""
Write-Host "==============================="
Write-Host "        HWID CHANGER"
Write-Host "==============================="
Write-Host ""
Write-Host "Identifiants actuels :"
Write-Host ""

$curMachineGuid = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Cryptography" -EA SilentlyContinue).MachineGuid
$curHwProfile   = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\IDConfigDB\Hardware Profiles\0001" -EA SilentlyContinue).HwProfileGuid
$curSqm         = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\SQMClient" -EA SilentlyContinue).MachineId
$curProductId   = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -EA SilentlyContinue).ProductId
$curBuildGuid   = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -EA SilentlyContinue).BuildGUID
$curBiosVer     = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\SystemInformation" -EA SilentlyContinue).BIOSVersion
$curBiosVendor  = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\SystemInformation" -EA SilentlyContinue).BIOSVendor
$curSysMfg      = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\SystemInformation" -EA SilentlyContinue).SystemManufacturer
$curSysProd     = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\SystemInformation" -EA SilentlyContinue).SystemProductName

Write-Host ("  MachineGuid      : {0}" -f $curMachineGuid)
Write-Host ("  HwProfileGuid    : {0}" -f $curHwProfile)
Write-Host ("  SQM MachineId    : {0}" -f $curSqm)
Write-Host ("  ProductId        : {0}" -f $curProductId)
Write-Host ("  BuildGUID        : {0}" -f $curBuildGuid)
Write-Host ("  BIOSVersion      : {0}" -f $curBiosVer)
Write-Host ("  BIOSVendor       : {0}" -f $curBiosVendor)
Write-Host ("  SystemManufact.  : {0}" -f $curSysMfg)
Write-Host ("  SystemProduct    : {0}" -f $curSysProd)
Write-Host ("  ComputerName     : {0}" -f $env:COMPUTERNAME)
Write-Host ""
Write-Host "==============================="
Write-Host ""

$pcName = Read-Host "Nouveau nom de PC (laisser vide = aleatoire)"
if ($pcName -eq "") {
    $pcName = "DESKTOP-" + (-join (1..7 | ForEach-Object { 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'[(Get-Random -Maximum 36)] }))
}

if ($pcName.Length -gt 15) {
    Write-Host "Le nom ne peut pas depasser 15 caracteres."
    exit 1
}

Write-Host ""

$newGuid       = New-RandomGuid
$newProfile    = "{$(New-RandomGuid)}"
$newSqm        = "{$(New-RandomGuid)}"
$newBuildGuid  = (New-RandomGuid).ToLower()
$newProductId  = "{0}-{1}-{2}-{3}" -f (New-RandomHex 4), (New-RandomHex 4), (New-RandomHex 4), (New-RandomHex 4)
$newBiosVer    = $biosVers[(Get-Random -Maximum $biosVers.Count)]
$newVendor     = $vendors[(Get-Random -Maximum $vendors.Count)]
$newProduct    = $products[(Get-Random -Maximum $products.Count)]
$newInstall    = [int][double]::Parse((Get-Date -UFormat %s)) - (Get-Random -Minimum 2592000 -Maximum 31536000)

Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Cryptography" -Name "MachineGuid" -Value $newGuid -EA SilentlyContinue

Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\IDConfigDB\Hardware Profiles\0001" -Name "HwProfileGuid" -Value $newProfile -EA SilentlyContinue

Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\SQMClient" -Name "MachineId" -Value $newSqm -EA SilentlyContinue

Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "ProductId"   -Value $newProductId  -EA SilentlyContinue
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "BuildGUID"   -Value $newBuildGuid  -EA SilentlyContinue
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name "InstallDate" -Value $newInstall    -EA SilentlyContinue

Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\SystemInformation" -Name "BIOSVersion"       -Value $newBiosVer -EA SilentlyContinue
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\SystemInformation" -Name "BIOSVendor"        -Value $newVendor  -EA SilentlyContinue
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\SystemInformation" -Name "SystemManufacturer" -Value $newVendor  -EA SilentlyContinue
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\SystemInformation" -Name "SystemProductName"  -Value $newProduct -EA SilentlyContinue

Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName"       -Name "ComputerName" -Value $pcName -EA SilentlyContinue
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName" -Name "ComputerName" -Value $pcName -EA SilentlyContinue
Rename-Computer -NewName $pcName -Force -EA SilentlyContinue

Write-Host "Nouveaux identifiants :"
Write-Host ""
Write-Host ("  MachineGuid      : {0}" -f $newGuid)
Write-Host ("  HwProfileGuid    : {0}" -f $newProfile)
Write-Host ("  SQM MachineId    : {0}" -f $newSqm)
Write-Host ("  ProductId        : {0}" -f $newProductId)
Write-Host ("  BuildGUID        : {0}" -f $newBuildGuid)
Write-Host ("  BIOSVersion      : {0}" -f $newBiosVer)
Write-Host ("  BIOSVendor       : {0}" -f $newVendor)
Write-Host ("  SystemManufact.  : {0}" -f $newVendor)
Write-Host ("  SystemProduct    : {0}" -f $newProduct)
Write-Host ("  ComputerName     : {0}" -f $pcName)
Write-Host ""
Write-Host "Redemarrer le PC pour appliquer les changements."
