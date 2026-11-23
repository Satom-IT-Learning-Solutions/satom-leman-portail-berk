# ADR-005 - Certificats pour le domaine fictif leman-finance.example

- **Statut** : accepte avec derogation - 23/11/2026
- **Contexte** : ACM ne peut pas valider `portefeuilles.leman-finance.example` (domaine non delegue).
- **Decision** : l'ALB utilise un certificat importe dans ACM (eu-north-1), genere dans CloudShell ; la cle privee n'est jamais ecrite dans le depot. CloudFront presente son certificat par defaut `*.cloudfront.net` ; un nom reel (ex. `berk.animalux.ch`, fourni par le formateur) est ajoute en alias avec un certificat ACM us-east-1 valide par DNS lorsqu'il est disponible.
- **Risque accepte** : CloudFront refuse un certificat d'origine non public ; le trajet CloudFront -> ALB se fait donc en HTTP 80, sur le reseau AWS, l'ALB n'acceptant que la liste de prefixes `com.amazonaws.global.cloudfront.origin-facing` (une seule regle 80-443 pour respecter le quota de regles). Le navigateur -> CloudFront reste en HTTPS obligatoire (`redirect-to-https`, TLS 1.2 minimum). L'ecouteur HTTPS 443 de l'ALB reste en place comme demande au sprint 9. Proprietaire Berk Kaymaz, revue a l'attribution d'un domaine reel (certificat ACM valide pour l'origine).
