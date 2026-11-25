# Rapport - TP final DevSecOps : portail Groupe Leman Finance SA

Berk Kaymaz (equipe bkay) - depot `Satom-IT-Learning-Solutions/satom-leman-portail-berk` - novembre 2026

## 1. Architecture

Le portail est entierement decrit en CloudFormation et deploye par une pipeline GitHub Actions authentifiee par OIDC (aucune cle d'acces).

- **Socle (G0)** : `stack-leman-bootstrap` - fournisseur OIDC, role de pipeline (pilote CloudFormation uniquement), role d'execution (seul a creer des ressources, limite aux services et piles du portail), bucket d'artefacts chiffre. Branche `main` protegee, environnement GitHub `prod` soumis a approbation.
- **Pile racine par environnement** `stack-leman-<env>` (memes templates, `parameters/dev.json` et `prod.json`) en piles imbriquees : reseau (VPC /16, 5 sous-reseaux sur 2 zones, NACL, Flow Logs chiffres KMS), securite (sg-alb / sg-web / sg-app, aucun port d'administration), calcul (web-01, app-01 prives, IMDSv2, EBS chiffre), ALB (HTTPS TLS 1.2+, `/api/*` priorite 10, journaux d'acces), supervision (alarmes, SNS, tableau de bord).
- **Bordure** `stack-leman-<env>-edge` : CloudFront (statique S3 via OAC, API sans cache, en-tetes de securite), WAF regional (regles gerees + limitation de debit). L'ALB n'accepte que la liste de prefixes CloudFront.
- **Connectivite par session** (workflow `connectivite-session`) : NAT + Network Firewall, peering, Transit Gateway, VPN, Direct Connect gateway. Crees, mesures puis supprimes (facturation horaire).

```
Internet -> CloudFront (OAC /static -> S3) -> WAF -> ALB (2 AZ) -> web-01 :80 / app-01 :8080 (prives)
vpc-prod 10.0.0.0/16 <-> (peering | TGW 64512) <-> vpc-dev 10.1.0.0/16 ; TGW <- VPN siege/agence, DXGW 64513
```

## 2. Resultats des mesures

| Domaine | Indicateur | Mesure | Seuil | Statut |
|---|---|---|---|---|
| IaC | cfn-lint, cfn-guard, checkov | 0 erreur, 0 echec (cas negatif SSH ouvert refuse) | 0 | OK |
| Securite | gitleaks (historique), Semgrep, pip-audit | 0 secret, 0 finding high, 0 vulnerabilite | 0 | OK |
| Securite | DAST ZAP baseline | 0 alerte high (64 regles PASS, 4 WARN analyses) | 0 high | OK |
| Qualite | Couverture des tests | 93 % (pytest) | >= 80 % | OK (SonarQube : voir 3) |
| Reseau | Sous-reseaux / routage (S1-2) | 2 zones, aucune route privee vers l'IGW | - | OK |
| Reseau | Reachability web-01 -> app-01 (S3) | 8080 accessible, 22 bloque | - | OK |
| Reseau | Pare-feu (S4) | amazonaws.com et depot AL2023 OK, example.com et google.com bloques et journalises | - | OK |
| Connectivite | Peering (S5) / TGW (S6) | dev-01 -> app-01:8080 accessible, 22 bloque ; tables TGW separees | - | OK |
| Connectivite | VPN (S7) | IKEv2 / AES-256 / DH14, alarmes TunnelState en ALARM | 2/2 UP | Ecart (ADR-015) |
| Connectivite | Direct Connect (S8) | DXGW 64513 associee a la TGW, prefixe 10.0.0.0/16 seul | - | OK (conception) |
| Performance | k6 10 VU, 3 min | 3 573 req, 0 % erreur, p95 209 ms, p99 234 ms | < 0,5 % / 500 ms / 1 s | OK |
| Fiabilite | Reprise de dev (S13) | suppression 338 s, recreation ~14 min ; RPO 0 (donnees) | documentes | OK |
| Couts | Budget | 74,55 USD / 150 au 23/11 (compte partage) | < 80 % | OK |
| Gouvernance | DORA | 6/18 deploiements dev reussis, 1 prod, delai 31 min, MTTR ~43 min | renseignes | OK |

## 3. Ecarts et actions correctives

| Ecart | Cause | Action / decision |
|---|---|---|
| Region eu-north-1 au lieu d'eu-central-2 | Region desactivee (opt-in) sur le compte partage | ADR-010, region parametrable |
| Budget et WAF hors us-east-1 | SCP de l'organisation interdisant CloudFormation en us-east-1 | Budget du module 0 reutilise (ADR-006), WAF regional (ADR-011) |
| CloudFront -> ALB en HTTP | Certificat d'origine non public (domaine fictif) | Liste de prefixes CloudFront, HTTPS obligatoire cote client (ADR-005) |
| Tunnels VPN DOWN | Passerelles client fictives (RFC 5737) | Supervision demontree ; tunnels UP au module 7 (ADR-015) |
| Tests depuis un runner heberge | Pas de runner dans le VPC | API AWS (Reachability Analyzer, SSM) pour le prive (ADR-008) |
| Remplacements annonces dans les piles imbriquees | Limite des change sets imbriques | Garde-fou sur suppressions et racine, relecture en PR (ADR-014) |
| Version applicative dans le UserData | Remplacement d'instances a chaque commit | UserData stable, `app/courant/` (ADR-013) |

Incidents traites (journal) : rollback du sg-alb (23/11), blocage du test de charge par le WAF (24/11), OIDC refuse a cause du claim `sub` de l'organisation (23/11, diagnostique dans CloudTrail).

## 4. Risques acceptes

Chaque derogation a un proprietaire (bkay) et une date de revue (30/11/2026) : role d'execution aux actions `service:*` (ADR-002), regles checkov non applicables (ADR-007), journaux standard CloudFront (ADR-012), absence de runner auto-heberge (ADR-008), mesure « tunnels UP » non atteignable (ADR-015).
