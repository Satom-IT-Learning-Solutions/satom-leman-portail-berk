# ADR-016 — Exceptions SonarQube Cloud acceptées

- **Statut** : accepté — 2026-11-25
- **Contexte** : la première analyse SonarQube Cloud de `main` (organisation `leman-berk`, plan Free) a remonté 35 problèmes de sécurité (note E) et fait échouer la quality gate du stage 1.

## Décision

**Corrigés dans le code (20) :**

| Règle | Correction |
|---|---|
| githubactions:S7637 (10) | Toutes les actions épinglées par SHA de commit complet (tag en commentaire) |
| githubactions:S8541 / S8544 (8) | `pip install --only-binary :all:` + versions verrouillées (`requirements-dev.txt`, nouveau `requirements-securite.txt` pour checkov, Semgrep, pip-audit — aussi audité par pip-audit) |
| githubactions:S6506 (2) | `curl --proto '=https' --tlsv1.2` pour cfn-guard et gitleaks |
| cloudformation:S6321 (1) | `tests/guard/sg-ssh-ouvert.yaml` exclu : c'est le cas négatif volontaire du test cfn-guard |

**Acceptés et documentés (`sonar.issue.ignore.multicriteria`) :**

| Règle | Fichier | Justification |
|---|---|---|
| S6304 — IAM `Resource: "*"` | bootstrap | Actions Describe/List et services sans ARN de ressource ; bornées par `aws:RequestedRegion` et préfixes `stack-leman-*` ailleurs |
| S6329 — IP publique EC2 | 03-calcul | Instances en sous-réseaux privés (`MapPublicIpOnLaunch: false`), aucune route IGW ; modifier le Launch Template remplacerait les instances (ADR-014) |
| S5332 — HTTP en clair | 04-alb, portail.py | Écouteur 80 d'origine joignable uniquement depuis la prefix list CloudFront ; le visiteur est en HTTPS (redirect-to-https) |
| S6258 — journaux S3/CloudFront/WAF | templates | Coût ; journaux ALB, VPC Flow Logs et métriques WAF couvrent l'investigation |
| S6327 — SNS non chiffré | 05-supervision | CloudWatch Alarms ne peut pas publier vers la clé gérée `aws/sns` ; les alertes ne contiennent aucune donnée sensible |

## Conséquences

- Quality gate « Sonar way » évaluée sur `main` à chaque push (gate G1).
- Chaque exception est visible dans `sonar-project.properties` et revue à chaque nouvelle règle activée.
- Évolution possible : CMK dédiée pour SNS et journaux WAF vers S3 si le budget le permet.
