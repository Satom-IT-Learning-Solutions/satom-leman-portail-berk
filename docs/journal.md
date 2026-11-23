# Journal de projet - portail Groupe Leman Finance SA (equipe bkay)

Region : eu-north-1 (Stockholm, voir ADR-010), certificats CloudFront en us-east-1. Compte de formation partage 223310160799.

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

### 23/11/2026 - G0 (suite)
- Premiere execution de la pipeline en echec (attendu, voir taux d'echec DORA) : `AWS::Budgets::Budget` n'existe pas en region (budget deplace dans `bootstrap/01-budget.yaml`, us-east-1) ; action Trivy introuvable (installation par script, version figee).
- eu-central-2 desactivee sur le compte partage : deploiement en eu-north-1 (ADR-010).
- Nom de l'ALB `alb-<env>-portail-bkay` pour eviter la collision avec l'ALB du module 9 (`alb-prod-leman-bkay`) encore present jusqu'a l'evaluation.
- `stack-leman-bootstrap` CREATE_COMPLETE (eu-north-1) : fournisseur OIDC GitHub (aucun n'existait dans le compte), roles `leman-github-deploy-bkay` et `leman-cfn-execution-bkay`, bucket `leman-artefacts-bkay-223310160799-eu-north-1`.
- Pile budget en us-east-1 refusee par une SCP de l'organisation : budget `budget-leman-bkay` du module 0 reutilise (ADR-006), WAF regional sur l'ALB (ADR-011).
- checkov : le cas negatif `tests/guard/` est exclu de l'analyse (il doit echouer volontairement).
- Trivy : installation impossible depuis le runner (binaire de release indisponible) ; analyse SCA par pip-audit sur `requirements-dev.txt` (versions figees, 0 vulnerabilite). L'application n'a aucune dependance tierce.
- AMI Amazon Linux 2023 figee : `ami-083dedce92603a2ad` (eu-north-1, 23/11/2026, ADR-004).
- Certificat de l'ALB : auto-signe `portefeuilles.leman-finance.example` (90 jours) genere dans CloudShell et importe dans ACM avec les balises de l'equipe ; la cle privee est supprimee apres import. ARN publie dans le parametre SSM `/leman-bkay/certificat-alb-arn` (ADR-005). Un certificat homonyme d'un autre eleve existe dans le compte partage : il n'est pas utilise.
- Premier deploiement dev par la pipeline refuse (`Not authorized to perform sts:AssumeRoleWithWebIdentity`). CloudTrail montre le claim `sub` reel : `repo:Satom-IT-Learning-Solutions@155011971/satom-leman-portail-berk@1468476442:environment:dev` (l'organisation ajoute ses identifiants immuables). Condition de confiance du role completee, toujours limitee a ce depot, a `main`, aux PR et aux environnements dev/prod.
