# ADR-006 - Budget 150 CHF suivi en USD

- **Statut** : accepte - 23/11/2026
- **Contexte** : AWS Budgets ne compte qu'en USD ; le compte de formation est partage entre plusieurs eleves.
- **Decision** : budget mensuel de 150 USD (proche de 150 CHF au cours de novembre 2026), alerte a 80 % du reel et 100 % du previsionnel, filtre sur la balise `Equipe=bkay`. Les ressources horaires (NAT, Network Firewall, TGW, VPN) sont desactivees par parametre ou supprimees a chaque fin de session.
- **Limite** : le filtre par balise ne compte que si `Equipe` est activee comme balise de repartition des couts par l'administrateur du compte.
