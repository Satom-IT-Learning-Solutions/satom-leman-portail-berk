# ADR-007 - Derogations checkov documentees

| Controle | Motif | Proprietaire | Revue |
|---|---|---|---|
| CKV_AWS_18 | Pas de journal d'acces sur les buckets qui recoivent deja des journaux (boucle) | bkay | 30/11/2026 |
| CKV_AWS_144 | Replication inter-regions hors perimetre (pas de donnees client reelles) | bkay | 30/11/2026 |
| CKV_AWS_26 | Topic SNS non chiffre KMS : les alarmes CloudWatch exigent une cle dediee avec politique specifique ; aucune donnee personnelle dans les notifications | bkay | 30/11/2026 |
| CKV_AWS_158 | Groupe de journaux applicatif avec chiffrement par defaut du service ; le groupe Flow Logs utilise KMS | bkay | 30/11/2026 |
| CKV_AWS_107 a 111 | Role d'execution CloudFormation (voir ADR-002) | bkay | 30/11/2026 |
| CKV_AWS_116/117/173 | Concernent les Lambda ; aucune Lambda applicative | bkay | 30/11/2026 |
| CKV_GHA_7 | Le workflow `connectivite-session` choisit une operation (pile, action) parmi des listes fermees ; il ne produit aucun artefact de build | bkay | 30/11/2026 |
