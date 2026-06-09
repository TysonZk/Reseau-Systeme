if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Ce script doit etre execute en administrateur."
    exit 1
}

function New-RandomGuid { return [System.Guid]::NewGuid().ToString().ToUpper() }

function New-RandomSerial([int]$len = 12) {
    $chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    return -join (1..$len | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
}

function New-RandomHex([int]$length) {
    return -join (1..$length | ForEach-Object { '{0:X2}' -f (Get-Random -Maximum 256) })
}

function Set-SmbiosUuid {
    $key  = "HKLM:\SYSTEM\CurrentControlSet\Services\mssmbios\Data"
    $data = (Get-ItemProperty $key -EA SilentlyContinue).SMBiosData
    if (-not $data) { return $false }

    $i = 0
    while ($i -lt ($data.Length - 4)) {
        $type = $data[$i]
        $len  = $data[$i + 1]
        if ($len -lt 4) { break }

        if ($type -eq 1 -and $len -ge 24) {
            $uuid = [System.Guid]::NewGuid().ToByteArray()
            for ($j = 0; $j -lt 16; $j++) { $data[$i + 8 + $j] = $uuid[$j] }
            Set-ItemProperty $key -Name "SMBiosData" -Value $data -EA SilentlyContinue
            return $true
        }

        $i += $len
        while ($i -lt ($data.Length - 1)) {
            if ($data[$i] -eq 0 -and $data[$i + 1] -eq 0) { $i += 2; break }
            $i++
        }
    }
    return $false
}

function Update-NicGuids {
    $nicPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002BE10318}"
    $count   = 0
    Get-ChildItem $nicPath -EA SilentlyContinue | ForEach-Object {
        $props = Get-ItemProperty $_.PSPath -EA SilentlyContinue
        if ($props.NetCfgInstanceId -and
            $props.DriverDesc -notmatch "WAN Miniport|Virtual|Tunnel|Loopback|Bluetooth|Hyper-V|VMware|VirtualBox") {
            Set-ItemProperty $_.PSPath -Name "NetCfgInstanceId" -Value "{$(New-RandomGuid)}" -EA SilentlyContinue
            $count++
        }
    }
    return $count
}

function Set-VolumeSerial {
    try {
        $drive  = "\\.\C:"
        $access = [System.IO.FileAccess]::ReadWrite
        $share  = [System.IO.FileShare]::ReadWrite
        $fs     = [System.IO.FileStream]::new($drive, [System.IO.FileMode]::Open, $access, $share)
        $sector = New-Object byte[] 512
        $null   = $fs.Read($sector, 0, 512)
        $serial = [byte[]](1..4 | ForEach-Object { Get-Random -Maximum 256 })
        [System.Buffer]::BlockCopy($serial, 0, $sector, 0x48, 4)
        $fs.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null
        $fs.Write($sector, 0, 512)
        $fs.Close()
        return $true
    } catch {
        return $false
    }
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
Write-Host ("  MachineGuid      : {0}" -f (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Cryptography" -EA SilentlyContinue).MachineGuid)
Write-Host ("  HwProfileGuid    : {0}" -f (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\IDConfigDB\Hardware Profiles\0001" -EA SilentlyContinue).HwProfileGuid)
Write-Host ("  SQM MachineId    : {0}" -f (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\SQMClient" -EA SilentlyContinue).MachineId)
Write-Host ("  ProductId        : {0}" -f (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -EA SilentlyContinue).ProductId)
Write-Host ("  BuildGUID        : {0}" -f (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -EA SilentlyContinue).BuildGUID)
Write-Host ("  BIOSVersion      : {0}" -f (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\SystemInformation" -EA SilentlyContinue).BIOSVersion)
Write-Host ("  SystemManufact.  : {0}" -f (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\SystemInformation" -EA SilentlyContinue).SystemManufacturer)
Write-Host ("  ComputerName     : {0}" -f $env:COMPUTERNAME)
Write-Host ""
Write-Host "==============================="
Write-Host ""

$pcName = Read-Host "Nouveau nom de PC (vide = aleatoire)"
if ($pcName -eq "") {
    $pcName = "DESKTOP-" + (New-RandomSerial 7)
}
if ($pcName.Length -gt 15) {
    Write-Host "Le nom ne peut pas depasser 15 caracteres."
    exit 1
}

Write-Host ""
Write-Host "Application en cours..."
Write-Host ""

$newGuid      = New-RandomGuid
$newProfile   = "{$(New-RandomGuid)}"
$newSqm       = "{$(New-RandomGuid)}"
$newBuildGuid = (New-RandomGuid).ToLower()
$newProductId = "{0}-{1}-{2}-{3}" -f (New-RandomHex 4),(New-RandomHex 4),(New-RandomHex 4),(New-RandomHex 4)
$newBiosVer   = $biosVers[(Get-Random -Maximum $biosVers.Count)]
$newVendor    = $vendors[(Get-Random -Maximum $vendors.Count)]
$newProduct   = $products[(Get-Random -Maximum $products.Count)]
$newInstall   = [int][double]::Parse((Get-Date -UFormat %s)) - (Get-Random -Minimum 2592000 -Maximum 31536000)

Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Cryptography"                                              -Name "MachineGuid"          -Value $newGuid      -EA SilentlyContinue
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\IDConfigDB\Hardware Profiles\0001"           -Name "HwProfileGuid"        -Value $newProfile   -EA SilentlyContinue
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\SQMClient"                                                 -Name "MachineId"            -Value $newSqm       -EA SilentlyContinue
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"                                 -Name "ProductId"            -Value $newProductId -EA SilentlyContinue
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"                                 -Name "BuildGUID"            -Value $newBuildGuid -EA SilentlyContinue
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"                                 -Name "InstallDate"          -Value $newInstall   -EA SilentlyContinue
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\SystemInformation"                           -Name "BIOSVersion"          -Value $newBiosVer   -EA SilentlyContinue
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\SystemInformation"                           -Name "BIOSVendor"           -Value $newVendor    -EA SilentlyContinue
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\SystemInformation"                           -Name "SystemManufacturer"   -Value $newVendor    -EA SilentlyContinue
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\SystemInformation"                           -Name "SystemProductName"    -Value $newProduct   -EA SilentlyContinue
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName"                   -Name "ComputerName"         -Value $pcName       -EA SilentlyContinue
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName"             -Name "ComputerName"         -Value $pcName       -EA SilentlyContinue
Rename-Computer -NewName $pcName -Force -EA SilentlyContinue

$smbios = Set-SmbiosUuid
$nics   = Update-NicGuids
$vol    = Set-VolumeSerial

Write-Host ("  [OK] MachineGuid      : {0}" -f $newGuid)
Write-Host ("  [OK] HwProfileGuid    : {0}" -f $newProfile)
Write-Host ("  [OK] SQM MachineId    : {0}" -f $newSqm)
Write-Host ("  [OK] ProductId        : {0}" -f $newProductId)
Write-Host ("  [OK] BuildGUID        : {0}" -f $newBuildGuid)
Write-Host ("  [OK] BIOS             : {0} {1}" -f $newVendor, $newBiosVer)
Write-Host ("  [OK] Carte mere       : {0} {1}" -f $newVendor, $newProduct)
Write-Host ("  [OK] ComputerName     : {0}" -f $pcName)

if ($smbios) {
    Write-Host "  [OK] SMBIOS UUID      : modifie"
} else {
    Write-Host "  [--] SMBIOS UUID      : non modifie (cle absente)"
}

if ($nics -gt 0) {
    Write-Host ("  [OK] NIC GUIDs        : {0} adaptateur(s) modifie(s)" -f $nics)
} else {
    Write-Host "  [--] NIC GUIDs        : aucun adaptateur trouve"
}

if ($vol) {
    Write-Host "  [OK] Volume serial    : modifie"
} else {
    Write-Host "  [--] Volume serial    : echec (acces disque refuse)"
}

Write-Host ""
Write-Host "Redemarrer le PC pour appliquer les changements."
