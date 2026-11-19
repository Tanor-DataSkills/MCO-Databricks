
- Fréquence: Un par job, P1 d’abord (100 % des P1 à la semaine 6)
  
- Contenu: Identité, dépendances, erreurs connues, relance, backfill, rollback

## Runbook : sp_sync_hr (P3, secret expiré)

<img width="748" height="392" alt="image" src="https://github.com/user-attachments/assets/f2e4c36b-09f1-44eb-9cd2-1cdddbe481b5" />

**Rôle et dépendances :** synchronisation de données RH (source et cible : À COMPLÉTER)

<img width="1484" height="230" alt="image" src="https://github.com/user-attachments/assets/a5899703-2bd3-4a8b-a548-80cd34dde0c7" />

**Relance sécurisée :**

• Prérequis : secret renouvelé et pris en compte par le secret scope. Ne pas relancer avant : des échecs d’authentification répétés peuvent verrouiller le compte de service

• Idempotence : À COMPLÉTER

• Validation : run SUCCEEDED, données synchronisées cohérentes avec la source

• Ne jamais coller un secret en clair dans un ticket ou un message

**Précédent :** le 03/11, détecté en 15 min, résolu en 2 h

**Correctifs durables :** rotation automatisée (30/11), alerte d’expiration à J-30.
