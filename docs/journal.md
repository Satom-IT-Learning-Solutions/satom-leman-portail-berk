# Journal de projet - portail Groupe Leman Finance SA (equipe bkay)

Region : eu-central-2 (Zurich), certificats CloudFront en us-east-1. Compte de formation partage 223310160799.

## Indicateurs DORA (mis a jour a chaque sprint)

| Sprint | Deploiements dev / prod | Delai commit -> prod | Taux d'echec des changements | MTTR |
|---|---|---|---|---|
| G0 | 0 / 0 | - | - | - |

## Entrees

### 23/11/2026 - Gate G0 (preparation)
- Depot public `Satom-IT-Learning-Solutions/satom-leman-portail-berk` cree (le depot `Morrad-Satom-IT/satom-leman-portail` de l'enonce n'existe pas ; convention de la classe `satom-leman-portail-<prenom>`).
- Premier commit d'amorcage pousse directement sur `main` (depot vide, avant protection de branche) ; toutes les modifications suivantes passent par pull request.
- Structure du depot, application Python (stdlib, journaux JSON), tests unitaires (couverture 93 %), templates reseau / securite / calcul / ALB / supervision, regles cfn-guard et checkov, pipeline a sept etapes, ADR 001 a 009, runbooks des alarmes critiques.
- Controles locaux : cfn-lint OK, cfn-guard OK (cas negatif SSH ouvert correctement refuse), checkov 0 echec, ruff OK, shellcheck OK, pytest 18/18.
