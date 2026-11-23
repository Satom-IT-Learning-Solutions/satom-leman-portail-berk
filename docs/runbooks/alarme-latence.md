# Runbook - alarm-latence-p95 / p99

**Symptome** : p95 > 500 ms ou p99 > 1 s sur 5 minutes (SLO).

**Diagnostic** : RequestCount en hausse (charge) ? CPU des instances (`CPUUtilization`) ? Latence limitee a `/api/*` ou generale ? Taux de cache CloudFront en baisse ?

**Action corrective** : charge legitime -> augmenter la taille d'instance par PR (parametre `TypeInstance`) ; cache en baisse -> verifier le comportement `/static/*` et les en-tetes `Cache-Control` ; sinon redemarrer le service et ouvrir un correctif.
