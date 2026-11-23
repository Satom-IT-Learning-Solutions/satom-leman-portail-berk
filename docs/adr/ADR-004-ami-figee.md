# ADR-004 - AMI Amazon Linux 2023 figee dans les parametres

- **Statut** : accepte - 23/11/2026
- **Contexte** : au module 13, une AMI resolue dynamiquement (SSM) a provoque un remplacement d'instances inattendu et un rollback.
- **Decision** : l'AMI est un parametre `AmiId` fige dans `parameters/<env>.json`. Sa mise a jour est un changement explicite, relu en pull request, dont le change set montre le remplacement.
