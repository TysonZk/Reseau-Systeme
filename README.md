---

### change_mac.sh

Change l'adresse MAC d'une interface réseau.

**Utilisation :**
```
./change_mac.sh
```

- Liste les interfaces réseau disponibles
- Choix entre MAC aléatoire ou manuelle
- Le changement est temporaire (perdu au redémarrage)

---

### change_mac.ps1

Change l'adresse MAC d'une interface réseau (Windows).

**Utilisation :**

Lancer PowerShell en administrateur et executer :
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```
Quand il demande confirmation taper `O` puis entrée, ensuite :
```powershell
.\change_mac.ps1
```

- Liste les interfaces réseau physiques disponibles
- Choix entre MAC aléatoire ou manuelle
- Modifie le registre Windows et redémarre l'interface

---

### spoofing.ps1

Spoof les identifiants matériels et logiciels sur Windows.

**Utilisation :**

Lancer PowerShell en administrateur et executer :
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```
Quand il demande confirmation taper `O` puis entrée, ensuite :
```powershell
.\spoofing.ps1
```

Ce que le script modifie :

| Identifiant | Description |
|---|---|
| MachineGuid | Identifiant principal de la machine Windows |
| HwProfileGuid | GUID du profil matériel |
| SQM MachineId | Identifiant de télémétrie Microsoft |
| ProductId | Identifiant produit Windows |
| BuildGUID | GUID de build Windows |
| InstallDate | Date d'installation Windows (aléatoire) |
| BIOS Version / Vendor | Informations BIOS spoofées |
| System Manufacturer / Product | Fabricant et modèle carte mère spoofés |
| ComputerName | Nom du PC (personnalisable ou aléatoire) |
| SMBIOS UUID | UUID système lu par WMI (patch binaire) |
| NIC GUIDs | GUID de chaque adaptateur réseau physique |
| Volume Serial (C:) | Numéro de série du volume C: via VolumeID Sysinternals |

> **Note :** Ce script couvre le spoofing au niveau registre et logiciel. Les anti-cheats kernel-level comme Vanguard, EAC ou BattlEye utilisent des drivers ring-0 qui lisent le hardware directement (serial disque, GPU HWID, TPM) et ne sont pas affectés par ce script.
