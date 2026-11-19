
# RCA Post mortem

Le RCA (analyse de cause racine) ou post-mortem sert à comprendre pourquoi un incident s’est produit, pour qu’il ne revienne pas. La relance rétablit le service, mais elle ne règle pas la cause.

- Fréquence: Pour les incidents P1 et les récurrents(Par problème ouvert)

- Contenu: Chronologie, 5 pourquoi, cause racine, actions suivies
  

**Exemple RCA-001 – FileNotFoundException**

P1RCA – Exemple

Incident associé : INC-001

Job concerné : ingest_customers_daily

Table cible : silver.crm.customers

Source : ERP – ADLS Gen2


**1- Résumé exécutif**

Le job ingest_customers_daily, planifié quotidiennement à 03:00, a échoué lors de la lecture des fichiers clients ERP.
L'erreur FileNotFoundException a été provoquée par l'absence des fichiers attendus dans le répertoire landing/customers/<DATE>/.
Après investigation, le retard de livraison ERP a été identifié comme cause immédiate.
Le service a été rétabli après réception des fichiers, vérification de leur complétude et relance du traitement.

**2- Impact**

<img width="660" height="406" alt="image" src="https://github.com/user-attachments/assets/36f0db91-2401-4858-ad15-57dcf81f878e" />

**3- Chronologie**

<img width="691" height="513" alt="image" src="https://github.com/user-attachments/assets/b0d62c40-062d-4bab-b1f0-590be2ddf7d6" />

**4- Analyse de la cause racine**

<img width="775" height="478" alt="image" src="https://github.com/user-attachments/assets/6c204fcd-936c-40d6-ae0c-5870c96bc08e" />

**5- Analyse des 5 pourquoi**

<img width="1254" height="423" alt="image" src="https://github.com/user-attachments/assets/324718d3-ecde-43f9-95a9-06d059d815a5" />

**Cause racine retenue :**

Défaut de coordination et de contrôle entre la livraison ERP et le démarrage du pipeline Databricks.

Cause racine : absence de contrôle de collision de planning et de conditions de partition dans le MERGE.

**6- Actions correctives et préventive**

<img width="1224" height="356" alt="image" src="https://github.com/user-attachments/assets/83d90c47-489b-4c03-a351-e663207dd808" />

**7- Critères de clôture**

• Fichiers ERP reçus et complets

• Job exécuté avec succès

• Données clients disponibles dans Silver

• Contrôles d'unicité et de fraîcheur conformes

• SLA réévalué

• Actions préventives affectées à des responsables


--

**Exemple RCA-002 – ConcurrentAppendException**
P2RCA – Exemple

Incident associé : INC-002

Job concerné : transform_products_daily

Table cible : gold.products.catalog

Technologie : Delta Lake / MERGE


**1- Résumé exécutif**

Le job transform_products_daily, planifié quotidiennement à 05:00, a échoué lors de l'écriture dans la table Delta gold.products.catalog.
L'erreur ConcurrentAppendException a été provoquée par une opération d'écriture concurrente réalisée par un autre job sur la table cible.
Après analyse de l'historique Delta et des exécutions Databricks, le chevauchement des traitements a été identifié.
Le service a été rétabli après la fin de l'opération concurrente et la reprise du traitement.

**2- Impact**

<img width="768" height="475" alt="image" src="https://github.com/user-attachments/assets/bc0d9164-2d1c-46bd-a957-5de8e31e3871" />

**3- Chronologie**

<img width="705" height="563" alt="image" src="https://github.com/user-attachments/assets/d3049a22-a612-4ba1-8a83-77485e548433" />

**4- Analyse de la cause racine**

<img width="836" height="430" alt="image" src="https://github.com/user-attachments/assets/5f722f0f-958b-4820-adba-37080dcb07bf" />

**5- Analyse des 5 pourquoi**

<img width="1256" height="480" alt="image" src="https://github.com/user-attachments/assets/4982ee28-e5a9-43f9-a739-61775bc8c3f8" />

**Cause racine retenue**

Absence de gouvernance centralisée des écritures concurrentes sur les tables Delta partagées.

**6- Actions correctives et préventives**

<img width="1226" height="402" alt="image" src="https://github.com/user-attachments/assets/58b8ea14-65c9-4d67-8b13-e664549587e6" />

**7- Critères de clôture**

• Transaction concurrente terminée.

• Job exécuté avec succès

• Historique Delta cohérent

• Aucun doublon sur la clé métier

• Volumes et fraîcheur conformes

• SLA respecté ou écart documenté

• Actions préventives enregistrées


--

**Tableau de synthèse des RCA**


<img width="1009" height="501" alt="image" src="https://github.com/user-attachments/assets/5b96a03c-4eec-435c-b49d-2524bac2cb27" />
