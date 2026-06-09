if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Ce script doit etre execute en administrateur."
    exit 1
}

function New-RandomGuid { return [System.Guid]::NewGuid().ToString().ToUpper() }

function New-RandomSerial {
    $chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    return -join (1..12 | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
}

$paths = @{
    MachineGuid   = "HKLM:\SOFTWARE\Microsoft\Cryptography"
    HwProfile     = "HKLM:\SYSTEM\CurrentControlSet\Control\IDConfigDB\Hardware Profiles\0001"
    SQM           = "HKLM:\SOFTWARE\Microsoft\SQMClient"
    ProductId     = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
    SysInfo       = "HKLM:\SYSTEM\CurrentControlSet\Control\SystemInformation"
}

Write-Host ""
Write-Host "Identifiants actuels :"
Write-Host ""
Write-Host ("  MachineGuid      : {0}" -f (Get-ItemProperty $paths.MachineGuid -EA SilentlyContinue).MachineGuid)
Write-Host ("  HwProfileGuid    : {0}" -f (Get-ItemProperty $paths.HwProfile   -EA SilentlyContinue).HwProfileGuid)
Write-Host ("  SQM MachineId    : {0}" -f (Get-ItemProperty $paths.SQM         -EA SilentlyContinue).MachineId)
Write-Host ("  ProductId        : {0}" -f (Get-ItemProperty $paths.ProductId    -EA SilentlyContinue).ProductId)
Write-Host ("  BIOSVersion      : {0}" -f (Get-ItemProperty $paths.SysInfo      -EA SilentlyContinue).BIOSVersion)
Write-Host ("  BIOSVendor       : {0}" -f (Get-ItemProperty $paths.SysInfo      -EA SilentlyContinue).BIOSVendor)
Write-Host ("  SystemManufact.  : {0}" -f (Get-ItemProperty $paths.SysInfo      -EA SilentlyContinue).SystemManufacturer)
Write-Host ("  SystemProduct    : {0}" -f (Get-ItemProperty $paths.SysInfo      -EA SilentlyContinue).SystemProductName)
Write-Host ("  ComputerName     : {0}" -f $env:COMPUTERNAME)
Write-Host ""
Write-Host "  [1] Tout changer (aleatoire)"
Write-Host "  [2] Annuler"
Write-Host ""
$choix = Read-Host "Choix"

if ($choix -ne "1") {
    Write-Host "Annule."
    exit 0
}

$newGuid     = New-RandomGuid
$newProfile  = "{$(New-RandomGuid)}"
$newSqm      = "{$(New-RandomGuid)}"
$newSerial   = New-RandomSerial
$newBios     = "BIOS_$(New-RandomSerial)"
$newComputer = "DESKTOP-$(( -join (1..7 | ForEach-Object { 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'[(Get-Random -Maximum 36)] }) ))"

$vendors  = @("Dell Inc.", "HP", "ASUS", "Lenovo", "Acer", "MSI", "Gigabyte")
$products = @("OptiPlex 7090", "EliteDesk 800", "ROG STRIX", "ThinkCentre M90", "Aspire XC", "MAG Z590", "B550 AORUS")
$newVendor  = $vendors[(Get-Random -Maximum $vendors.Count)]
$newProduct = $products[(Get-Random -Maximum $products.Count)]

Set-ItemProperty -Path $paths.MachineGuid -Name "MachineGuid" -Value $newGuid -EA SilentlyContinue

if ((Get-ItemProperty $paths.HwProfile -EA SilentlyContinue).HwProfileGuid) {
    Set-ItemProperty -Path $paths.HwProfile -Name "HwProfileGuid" -Value $newProfile -EA SilentlyContinue
}

if ((Get-ItemProperty $paths.SQM -EA SilentlyContinue).MachineId) {
    Set-ItemProperty -Path $paths.SQM -Name "MachineId" -Value $newSqm -EA SilentlyContinue
}

Set-ItemProperty -Path $paths.ProductId -Name "ProductId" -Value $newSerial -EA SilentlyContinue

if (Get-ItemProperty $paths.SysInfo -EA SilentlyContinue) {
    Set-ItemProperty -Path $paths.SysInfo -Name "BIOSVersion"      -Value $newBios    -EA SilentlyContinue
    Set-ItemProperty -Path $paths.SysInfo -Name "BIOSVendor"       -Value $newVendor  -EA SilentlyContinue
    Set-ItemProperty -Path $paths.SysInfo -Name "SystemManufacturer" -Value $newVendor  -EA SilentlyContinue
    Set-ItemProperty -Path $paths.SysInfo -Name "SystemProductName"  -Value $newProduct -EA SilentlyContinue
}

Rename-Computer -NewName $newComputer -Force -EA SilentlyContinue

Write-Host ""
Write-Host "OK"
Write-Host ""
Write-Host ("  MachineGuid      : {0}" -f $newGuid)
Write-Host ("  HwProfileGuid    : {0}" -f $newProfile)
Write-Host ("  SQM MachineId    : {0}" -f $newSqm)
Write-Host ("  ProductId        : {0}" -f $newSerial)
Write-Host ("  BIOSVersion      : {0}" -f $newBios)
Write-Host ("  BIOSVendor       : {0}" -f $newVendor)
Write-Host ("  SystemManufact.  : {0}" -f $newVendor)
Write-Host ("  SystemProduct    : {0}" -f $newProduct)
Write-Host ("  ComputerName     : {0}" -f $newComputer)
Write-Host ""
Write-Host "Redemarrer le PC pour appliquer les changements."
