# ADR-001 - CloudFormation en piles imbriquees, un template par domaine

- **Statut** : accepte - 23/11/2026
- **Contexte** : l'enonce impose CloudFormation, un YAML par domaine et deux piles `stack-leman-dev` / `stack-leman-prod` issues des memes templates.
- **Decision** : une pile racine `templates/main.yaml` assemble les domaines (reseau, securite, calcul, alb, supervision) en piles imbriquees ; `aws cloudformation package` publie les sous-templates dans le bucket d'artefacts. Les differences d'environnement vivent uniquement dans `parameters/<env>.json`. Les composants factures a l'heure ou mondiaux (edge us-east-1, TGW, VPN, pare-feu) sont dans des piles separees pour pouvoir etre supprimes a chaque fin de session sans toucher au portail.
- **Consequences** : une seule commande deploie un environnement ; les sorties transitent par `GetAtt` (pas d'exports globaux qui bloqueraient les suppressions).
