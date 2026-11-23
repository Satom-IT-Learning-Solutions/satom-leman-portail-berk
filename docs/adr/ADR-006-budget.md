# ADR-006 - Budget : reutilisation de budget-leman-bkay (150, alerte 80 %)

- **Statut** : accepte - 23/11/2026
- **Contexte** : `AWS::Budgets::Budget` n'est pas disponible en eu-north-1 et une politique de controle de service (SCP) de l'organisation interdit CloudFormation en us-east-1 (`AccessDenied ... explicit deny in a service control policy`). AWS Budgets ne compte qu'en USD.
- **Decision** : le budget `budget-leman-bkay` cree au module 0 par l'API Budgets (150 USD, proche de 150 CHF, alerte a 80 % du reel, adresse e-mail verifiee) satisfait la gate G0 ; il est documente ici plutot que recree.
- **Observation du 23/11/2026** : depense mensuelle calculee 74,55 USD (49,7 %). Ce budget n'est pas filtre par balise : il reflete le compte de formation partage, pas seulement l'equipe bkay. Les ressources horaires sont desactivees par parametre (`ActiverNat=false`) ou supprimees en fin de session.
- **Limite** : un filtre `Equipe=bkay` exige l'activation de la balise de repartition des couts par l'administrateur du compte de gestion.
