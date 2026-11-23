# Runbook - alarm-5xx-portail-<env>-bkay (critique)

**Symptome** : plus de 5 reponses 5xx des cibles en une minute ; e-mail SNS « ALARM ».

**Diagnostic**
1. Tableau de bord `db-portail-leman-<env>-bkay` : quelle cible, depuis quand, la latence a-t-elle monte ?
2. `aws elbv2 describe-target-health` sur tg-web et tg-app.
3. Logs Insights sur `/leman-bkay/<env>/portail` : `fields ts, role, chemin, statut | filter statut >= 500 | sort ts desc`.
4. Dernier deploiement : `aws cloudformation describe-stack-events --stack-name stack-leman-<env>`.

**Action corrective** : si le dernier deploiement est en cause, revenir au commit precedent (revert en PR, la pipeline redeploie) ; sinon redemarrer le service `portail` par Session Manager (`sudo systemctl restart portail`). Consigner l'incident et le MTTR dans `docs/journal.md`.
