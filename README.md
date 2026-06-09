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

### change_hwid.ps1

Change le HWID (identifiants matériels) sur Windows.

**Utilisation :**

Lancer PowerShell en administrateur et executer :
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```
Quand il demande confirmation taper `O` puis entrée, ensuite :
```powershell
.\change_hwid.ps1
```

- Affiche les identifiants actuels (MachineGuid, HwProfileGuid, SQM MachineId)
- Génère de nouveaux identifiants aléatoires
- Redémarrer le PC pour appliquer les changements
