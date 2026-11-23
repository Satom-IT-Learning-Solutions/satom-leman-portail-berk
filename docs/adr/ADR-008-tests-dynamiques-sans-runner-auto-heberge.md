# ADR-008 - Tests dynamiques depuis un runner heberge, ressources privees via AWS API

- **Statut** : accepte avec derogation - 23/11/2026
- **Contexte** : l'enonce recommande un runner auto-heberge dans le VPC pour atteindre les ressources privees.
- **Decision** : les tests DAST et de charge visent le point d'entree public (CloudFront), ce qu'un runner heberge atteint. Les verifications privees passent par les API AWS (etat des cibles ALB, VPC Reachability Analyzer, SSM Run Command sur dev-01) : aucun port n'est ouvert vers Internet et aucun runner permanent n'est facture.
- **Risque accepte** : pas de test de charge depuis l'interieur du VPC. Proprietaire bkay, revue si un runner d'organisation est fourni.
