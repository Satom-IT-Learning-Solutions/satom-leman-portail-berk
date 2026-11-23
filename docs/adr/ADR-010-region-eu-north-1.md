# ADR-010 - Region eu-north-1 (Stockholm) au lieu d'eu-central-2 (Zurich)

- **Statut** : accepte avec derogation - 23/11/2026
- **Contexte** : l'enonce fixe eu-central-2. Sur le compte de formation partage Git.swiss (223310160799), `aws account get-region-opt-status --region-name eu-central-2` renvoie `DISABLED` : la region est a activation volontaire (opt-in) et l'activer modifie un reglage du compte de toute la classe, avec un delai pouvant aller jusqu'a plusieurs heures.
- **Decision** : deploiement en eu-north-1, region imposee par la plateforme pendant tout le cours (modules 0 a 13). Les certificats et le WAF de CloudFront restent en us-east-1, ainsi que le budget (service global).
- **Conformite nLPD** : eu-north-1 (Suede) est dans l'Espace economique europeen, que la Suisse reconnait comme offrant un niveau de protection adequat ; chiffrement au repos et en transit et journalisation inchanges.
- **Reversibilite** : la region n'est qu'une variable (`AWS_REGION` de la pipeline, `REGION` des scripts) ; aucun template ne la code en dur. Le passage a eu-central-2 se fera par pull request des que la region sera activee.
- **Proprietaire** : Berk Kaymaz - revue a l'activation de la region par l'administrateur du compte.
