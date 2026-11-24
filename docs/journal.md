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
- Deuxieme tentative : OIDC accepte, creation de `stack-leman-dev` en ROLLBACK_COMPLETE : le role d'execution doit pouvoir se transmettre aux piles imbriquees (`iam:PassRole` sur lui-meme et `cloudformation:*Stack` sur `stack-leman-*`). Le script supprime desormais une pile en ROLLBACK_COMPLETE avant de recreer.
- Troisieme tentative : reseau cree ; Security Groups refuses (`Group names may not be in the format sg-*`). Noms de groupe `alb-sg-*`, `web-sg-*`, `app-sg-*` ; les balises Name conservent sg-alb / sg-web / sg-app de l'enonce.

### 23/11/2026 - Sprints 1 a 3 (dev) et preparation du sprint 11
- `stack-leman-dev` CREATE_COMPLETE par la pipeline (etape 4) ; etape 5 verte (cibles tg-web et tg-app saines). Etape 6 en attente d'approbation manuelle (environnement GitHub `prod`).
- Mesure sprint 1 : 5 sous-reseaux sur eu-north-1a et 1b (10.1.1.0/24, 10.1.2.0/24, 10.1.3.0/24, 10.1.4.0/28, 10.1.5.0/24), aucune IP publique automatique.
- Mesure sprint 2 : table privee sans route par defaut (NAT desactivee hors session), aucune route privee vers l'IGW.
- Mesure sprint 3 : Reachability Analyzer web-01 -> app-01 tcp/8080 accessible (True), tcp/22 bloque (False, `ENI_SG_RULES_MISMATCH`).
- Sprint 11 prepare : pile `stack-leman-<env>-edge` (CloudFront, /static/* depuis S3 avec OAC, /api/* sans cache, en-tetes de securite, WAF regional). Derogations checkov documentees dans les templates (ADR-005, ADR-011, ADR-012).
- Mise a jour de dev en UPDATE_ROLLBACK_COMPLETE (sprint 11) : la modification de `GroupDescription` de sg-alb impose un **remplacement**, impossible avec un `GroupName` fixe (`AlreadyExists`). Le garde-fou du script ne voyait que la pile racine : il inspecte desormais aussi les change sets imbriques (`--include-nested-stacks`). Description d'origine retablie. Taux d'echec des changements du sprint : voir DORA.

### 24/11/2026 - Garde-fou et reprise
- Le garde-fou imbrique a bloque un deploiement : 6 remplacements annonces (instances, groupes cibles, filtre de metrique) causes par la version du code dans le UserData. Correction ADR-013 (UserData stable, `app/courant/`, balise `VersionApp`).
- Plutot que de forcer le remplacement, dev est supprime puis recree depuis le depot : c'est aussi la mesure de reprise du sprint 13 (`scripts/supprimer.sh`, puis pipeline).
- Mesure de reprise (sprint 13, dev) : suppression lancee a 13:12:55 UTC, terminee a 13:19:33 (338 s, buckets vides puis piles supprimees). Recreation par la pipeline declenchee a 13:21:30 (fusion de la PR #10), `stack-leman-dev` et `stack-leman-dev-edge` creees a 13:35:39, cibles saines a 13:35:5x. **RTO mesure : environ 14 min** depuis le declenchement (23 min depuis le debut du sinistre). **RPO : 0 pour les donnees applicatives** (application sans etat, donnees fictives versionnees dans le depot) ; les journaux d'acces ALB et les Flow Logs de dev anterieurs a la suppression sont perdus (perte acceptee pour dev, a exporter avant suppression en prod).
- Etape 5 en echec : k6 absent du runner (`spawn k6 ENOENT`) ; ajout de `grafana/setup-k6-action`.
- Le garde-fou bloque encore : la balise `VersionApp` sur les instances suffit a faire annoncer leur remplacement dans le change set imbrique. La version n'entre plus du tout dans la pile de calcul (sortie de la pile racine). Le tableau du garde-fou affiche desormais les proprietes qui imposent une recreation.
