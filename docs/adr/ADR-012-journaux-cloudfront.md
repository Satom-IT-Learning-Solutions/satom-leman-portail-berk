# ADR-012 - Journalisation CloudFront

- **Statut** : accepte avec derogation - 23/11/2026
- **Contexte** : les journaux standard CloudFront vers S3 exigent un bucket avec ACL activees, ce que les regles de l'equipe interdisent (`BucketOwnerEnforced`).
- **Decision** : la tracabilite des acces repose sur les journaux d'acces de l'ALB (bucket chiffre, 30 jours), les metriques CloudFront (requetes, taux d'erreur, CacheHitRate) et les echantillons du WAF.
- **Risque accepte** : les requetes servies depuis le cache (/static/*) ne sont pas journalisees individuellement ; elles ne contiennent aucune donnee personnelle. Proprietaire bkay, revue 30/11/2026.
