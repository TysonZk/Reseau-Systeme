if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Ce script doit etre execute en administrateur."
    exit 1
}

function Section([string]$title) {
    Write-Host ""
    Write-Host "==============================="
    Write-Host "  $title"
    Write-Host "==============================="
}

function Row([string]$label, $value) {
    if ($value) { Write-Host ("  {0,-25} : {1}" -f $label, $value) }
}

Section "SYSTEME WINDOWS"
$os = Get-CimInstance Win32_OperatingSystem
Row "OS"              $os.Caption
Row "Version"         $os.Version
Row "Build"           $os.BuildNumber
Row "Architecture"    $os.OSArchitecture
Row "Install Date"    $os.InstallDate
Row "MachineGuid"     (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Cryptography" -EA SilentlyContinue).MachineGuid
Row "ProductId"       (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -EA SilentlyContinue).ProductId
Row "BuildGUID"       (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -EA SilentlyContinue).BuildGUID
Row "SQM MachineId"   (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\SQMClient" -EA SilentlyContinue).MachineId
Row "HwProfileGuid"   (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\IDConfigDB\Hardware Profiles\0001" -EA SilentlyContinue).HwProfileGuid
Row "ComputerName"    $env:COMPUTERNAME

Section "CARTE MERE / BIOS"
$board = Get-CimInstance Win32_BaseBoard
$bios  = Get-CimInstance Win32_BIOS
$sys   = Get-CimInstance Win32_ComputerSystem
Row "Fabricant"       $board.Manufacturer
Row "Modele"          $board.Product
Row "Serial carte"    $board.SerialNumber
Row "BIOS Vendor"     $bios.Manufacturer
Row "BIOS Version"    $bios.SMBIOSBIOSVersion
Row "BIOS Date"       $bios.ReleaseDate
Row "BIOS Serial"     $bios.SerialNumber
Row "System UUID"     (Get-CimInstance Win32_ComputerSystemProduct).UUID
Row "System Manuf."   $sys.Manufacturer
Row "System Modele"   $sys.Model

Section "PROCESSEUR"
Get-CimInstance Win32_Processor | ForEach-Object {
    Row "Nom"             $_.Name
    Row "Fabricant"       $_.Manufacturer
    Row "ID"              $_.ProcessorId
    Row "Coeurs physiques" $_.NumberOfCores
    Row "Threads"         $_.NumberOfLogicalProcessors
    Row "Socket"          $_.SocketDesignation
    Row "Frequence (MHz)" $_.MaxClockSpeed
}

Section "RAM"
$totalRam = 0
Get-CimInstance Win32_PhysicalMemory | ForEach-Object {
    $totalRam += $_.Capacity
    Row "Slot"            $_.DeviceLocator
    Row "Capacite"        ("{0} GB" -f [math]::Round($_.Capacity / 1GB, 0))
    Row "Vitesse (MHz)"   $_.Speed
    Row "Fabricant"       $_.Manufacturer
    Row "Serial"          $_.SerialNumber
    Row "Part Number"     $_.PartNumber.Trim()
    Write-Host ""
}
Write-Host ("  {0,-25} : {1} GB" -f "Total RAM", [math]::Round($totalRam / 1GB, 0))

Section "DISQUES"
Get-CimInstance Win32_DiskDrive | ForEach-Object {
    Row "Nom"             $_.Caption
    Row "Serial"          $_.SerialNumber.Trim()
    Row "Taille"          ("{0} GB" -f [math]::Round($_.Size / 1GB, 0))
    Row "Interface"       $_.InterfaceType
    Row "Device ID"       $_.DeviceID
    Row "PNP Device ID"   $_.PNPDeviceID
    Write-Host ""
}

Section "VOLUMES"
Get-Volume | Where-Object { $_.DriveLetter } | ForEach-Object {
    $serial = (Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($_.DriveLetter):'").VolumeSerialNumber
    Row "Lecteur"         "$($_.DriveLetter):"
    Row "Label"           $_.FileSystemLabel
    Row "Systeme fichier" $_.FileSystem
    Row "Taille"          ("{0} GB" -f [math]::Round($_.Size / 1GB, 0))
    Row "Volume Serial"   $serial
    Write-Host ""
}

Section "GPU"
Get-CimInstance Win32_VideoController | ForEach-Object {
    Row "Nom"             $_.Caption
    Row "Device ID"       $_.DeviceID
    Row "PNP Device ID"   $_.PNPDeviceID
    Row "Driver"          $_.DriverVersion
    Row "VRAM"            ("{0} MB" -f [math]::Round($_.AdapterRAM / 1MB, 0))
    Write-Host ""
}

Section "ADAPTATEURS RESEAU"
Get-CimInstance Win32_NetworkAdapter | Where-Object { $_.PhysicalAdapter -eq $true } | ForEach-Object {
    $cfg   = Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "Index=$($_.DeviceID)"
    $regP  = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002BE10318}"
    $guid  = Get-ChildItem $regP -EA SilentlyContinue | Where-Object {
        (Get-ItemProperty $_.PSPath -EA SilentlyContinue).DriverDesc -eq $_.Name
    } | ForEach-Object { (Get-ItemProperty $_.PSPath).NetCfgInstanceId } | Select-Object -First 1

    Row "Nom"             $_.Name
    Row "MAC"             $_.MACAddress
    Row "NetCfgInstanceId" $guid
    Row "IP"              ($cfg.IPAddress -join ", ")
    Row "PNP Device ID"   $_.PNPDeviceID
    Write-Host ""
}

Section "MONITEURS"
Get-CimInstance WmiMonitorID -Namespace root\wmi -EA SilentlyContinue | ForEach-Object {
    $name = ($_.UserFriendlyName | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ }) -join ''
    $serial = ($_.SerialNumberID | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ }) -join ''
    Row "Nom"             $name
    Row "Serial"          $serial
    Row "Instance"        $_.InstanceName
    Write-Host ""
}

Section "PILOTES GPU - MISE A JOUR"
Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notmatch "Microsoft|Basic" } | ForEach-Object {
    $name          = $_.Name
    $driverVersion = $_.DriverVersion
    $driverDate    = $_.DriverDate
    $vendor        = if ($name -match "NVIDIA") { "NVIDIA" } elseif ($name -match "AMD|Radeon") { "AMD" } elseif ($name -match "Intel") { "Intel" } else { "Inconnu" }

    Row "GPU"             $name
    Row "Version pilote"  $driverVersion
    Row "Date pilote"     $driverDate

    $ageJours = if ($driverDate) { ([datetime]::Now - $driverDate).Days } else { $null }

    if ($ageJours -ne $null) {
        if ($ageJours -gt 180) {
            Write-Host ("  {0,-25} : PILOTE ANCIEN ({1} jours) - mise a jour recommandee" -f "Statut", $ageJours) -ForegroundColor Yellow
        } else {
            Write-Host ("  {0,-25} : OK ({1} jours)" -f "Statut", $ageJours) -ForegroundColor Green
        }
    }

    switch ($vendor) {
        "NVIDIA" { Write-Host "  Telecharger             : https://www.nvidia.com/fr-fr/drivers/" }
        "AMD"    { Write-Host "  Telecharger             : https://www.amd.com/fr/support" }
        "Intel"  { Write-Host "  Telecharger             : https://www.intel.fr/content/www/fr/fr/download-center/home.html" }
    }

    Write-Host ""
}

Write-Host ""
