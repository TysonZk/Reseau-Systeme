Si vous souhaitez ouvrir les fichiers .pkt vous avez besoin de Cisco Packet Tracer lien: https://skillsforall.com/fr/course/getting-started-cisco-packet-tracer?courseLang=fr-FR

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
```powershell
.\change_mac.ps1
```
> Lancer PowerShell en administrateur.

- Liste les interfaces réseau physiques disponibles
- Choix entre MAC aléatoire ou manuelle
- Modifie le registre Windows et redémarre l'interface
