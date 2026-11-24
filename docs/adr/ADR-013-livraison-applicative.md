# ADR-013 - Livraison du code applicatif sans remplacement d'instances

- **Statut** : accepte - 24/11/2026
- **Contexte** : la version du code etait ecrite dans le UserData des instances ; chaque commit modifiait les instances, et le change set imbrique annoncait leur remplacement (adresses IP fixes, risque d'echec identique au module 13). Le garde-fou du script a bloque le deploiement (6 remplacements detectes).
- **Decision** : le UserData est stable et lit `s3://leman-artefacts-.../app/courant/portail.py` ; la pipeline publie chaque commit sous `app/<sha>/` (tracabilite) et sous `app/courant/`. La version deployee est tracee par la balise `VersionApp` des instances (mise a jour sans interruption). Une nouvelle version du code est prise en compte au prochain (re)demarrage ou a la recreation de l'environnement.
- **Consequence** : la mise a jour de l'application en continu sur des instances en cours d'execution (SSM Run Command) est hors perimetre tant que les instances privees n'ont pas d'acces SSM (pas de NAT permanente ni de points de terminaison d'interface, pour les couts).
