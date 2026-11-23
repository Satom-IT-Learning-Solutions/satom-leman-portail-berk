# ADR-002 - Authentification OIDC et separation role de pipeline / role d'execution

- **Statut** : accepte - 23/11/2026
- **Decision** : GitHub Actions endosse `leman-github-deploy-bkay` par OIDC (aucune cle longue duree). Ce role ne peut que piloter les piles `stack-leman-*`, ecrire dans le bucket d'artefacts et passer le role `leman-cfn-execution-bkay` a CloudFormation. Seul CloudFormation detient les droits de creation, limites aux services du portail, aux regions eu-north-1 et us-east-1, et aux roles IAM prefixes `stack-leman-*`.
- **Condition de confiance** : `sub` limite au depot, a la branche `main`, aux pull requests et aux environnements GitHub `dev` / `prod`.
- **Risque accepte** : le role d'execution garde des actions `service:*` sur les services du portail (checkov CKV_AWS_107 a 111). Proprietaire : Berk Kaymaz. Revue : 30/11/2026, apres lecture des recommandations IAM Access Analyzer (generation de politique a partir de CloudTrail).
