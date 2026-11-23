# ADR-011 - SCP interdisant CloudFormation en us-east-1 : WAF regional sur l'ALB

- **Statut** : accepte avec derogation - 23/11/2026
- **Contexte** : la SCP `p-wuod5goi` de l'organisation refuse CloudFormation en us-east-1. Un WebACL WAF de portee CLOUDFRONT doit pourtant etre cree en us-east-1.
- **Decision** : la distribution CloudFront (ressource mondiale) est decrite dans une pile eu-north-1. Le WAF est un WebACL de portee REGIONAL associe a l'ALB (regles gerees AWS Common, Known Bad Inputs, IP reputation et limitation de debit par IP). L'ALB n'accepte que la liste de prefixes CloudFront : tout le trafic passe donc par CloudFront puis par le WAF.
- **Risque accepte** : le filtrage a lieu a l'origine plutot qu'en bordure (le trafic bloque traverse CloudFront). Proprietaire bkay, revue si la SCP est assouplie.
