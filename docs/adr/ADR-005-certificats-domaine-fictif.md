# ADR-005 - Certificats pour le domaine fictif leman-finance.example

- **Statut** : accepte avec derogation - 23/11/2026
- **Contexte** : ACM ne peut pas valider `portefeuilles.leman-finance.example` (domaine non delegue).
- **Decision** : l'ALB utilise un certificat importe dans ACM (eu-central-2), genere dans CloudShell ; la cle privee n'est jamais ecrite dans le depot. CloudFront presente son certificat par defaut `*.cloudfront.net` ; un nom reel (ex. `berk.animalux.ch`, fourni par le formateur) est ajoute en alias avec un certificat ACM us-east-1 valide par DNS lorsqu'il est disponible.
- **Risque accepte** : CloudFront -> ALB en HTTPS avec certificat non public impose `OriginSSLProtocols` TLSv1.2 et le mode `https-only` ; proprietaire Berk Kaymaz, revue a l'attribution d'un domaine reel.
