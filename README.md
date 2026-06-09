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

---

### hwinfo.ps1

Collecte et affiche tous les identifiants matériels et logiciels de la machine.

**Utilisation :**

Lancer PowerShell en administrateur et executer :
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```
Quand il demande confirmation taper `O` puis entrée, ensuite :
```powershell
.\hwinfo.ps1
```

Ce que le script récupère :

| Section | Informations |
|---|---|
| Système Windows | OS, version, MachineGuid, ProductId, BuildGUID, SQM MachineId, HwProfileGuid |
| Carte mère / BIOS | Fabricant, modèle, serial, version BIOS, UUID système |
| Processeur | Nom, ID, fabricant, coeurs, threads, fréquence, socket |
| RAM | Capacité, vitesse, fabricant, serial, part number par slot |
| Disques | Nom, serial, taille, interface, PNP Device ID |
| Volumes | Lettre, label, système de fichiers, volume serial |
| GPU | Nom, Device ID, PNP Device ID, version driver, VRAM |
| Réseau | MAC, NetCfgInstanceId, IP, PNP Device ID |
| Moniteurs | Nom, serial, instance |

---

### cleaner.ps1

Nettoie les fichiers temporaires de Windows, navigateurs, GPU et jeux.

**Utilisation :**

Lancer PowerShell en administrateur et executer :
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```
Quand il demande confirmation taper `O` puis entrée, ensuite :
```powershell
.\cleaner.ps1
```

Ce que le script nettoie :

| Catégorie | Détail |
|---|---|
| Windows | Temp, prefetch, Windows Update, WER, miniatures, fichiers récents, jump lists, logs, crash dumps, shader cache, DNS, corbeille |
| Navigateurs | Chrome, Edge, Firefox, Brave, Opera |
| GPU | NVIDIA / AMD / Intel shader cache |
| Jeux | Steam, Epic, EA App, Ubisoft Connect, Battle.net, Riot/Valorant, League of Legends, Minecraft, Rockstar/GTA V, Discord |
