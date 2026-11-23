# satom-leman-portail-berk

TP final DevSecOps - portail du Groupe Leman Finance SA (client fictif), reconstruit en infrastructure as code (AWS CloudFormation) avec une chaine DevSecOps complete.

| Dossier | Contenu |
|---|---|
| `bootstrap/` | Socle G0 : OIDC GitHub, roles de deploiement et d'execution, bucket d'artefacts, budget |
| `templates/` | Un template par domaine (reseau, securite, calcul, ALB, supervision) assembles par `main.yaml` |
| `parameters/` | `dev.json`, `prod.json` (aucun secret) |
| `policies/` | Regles cfn-guard et configuration checkov |
| `app/` | Application Python (bibliotheque standard) et tests unitaires |
| `tests/` | Connectivite, charge (k6), DAST (OWASP ZAP), cas negatifs cfn-guard |
| `sbom/` | SBOM CycloneDX generes par la pipeline |
| `docs/` | Journal et DORA, ADR, runbooks, rapports |
| `.github/workflows/` | Pipeline a sept etapes |

Regles : aucun commit direct sur `main`, pull request relue, Conventional Commits, authentification AWS par OIDC uniquement.

Deploiement local (lecture du change set avant execution) : `scripts/deployer.sh dev`.
