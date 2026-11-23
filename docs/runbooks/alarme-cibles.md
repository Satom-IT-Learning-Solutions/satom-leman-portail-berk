# Runbook - alarm-cibles-web-<env>-bkay (critique)

**Symptome** : au moins une cible tg-web en echec pendant 2 minutes.

**Diagnostic** : `describe-target-health` (raison `Target.Timeout`, `Target.ResponseCodeMismatch`...), etat de l'instance (arretee ?), Flow Logs : REJECT entre l'ALB et la cible (SG ou NACL).

**Action corrective** : instance arretee -> la demarrer ; service arrete -> `systemctl restart portail` ; regle reseau -> corriger le template et redeployer. Verifier le retour a OK et noter le MTTR.
