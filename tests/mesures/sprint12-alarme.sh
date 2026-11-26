#!/usr/bin/env bash
# Sprint 12 : alarme testee de bout en bout. Panne simulee de web-01 (arret) -> erreurs 5xx cote client,
# alarme alarm-cibles-web-<env>-bkay en ALARM -> notification SNS ; redemarrage -> retour OK (MTTR).
# shellcheck source=tests/mesures/commun.sh
source "$(dirname "$0")/commun.sh"
ALARME="alarm-cibles-web-${ENV}-bkay"
URL="https://$(aws cloudformation describe-stacks --stack-name "stack-leman-${ENV}-edge" --query "Stacks[0].Outputs[?OutputKey=='DomaineDistribution'].OutputValue" --output text)/"
W=$(instance "web-01-${ENV}-bkay")
etat() { aws cloudwatch describe-alarms --alarm-names "$ALARME" --query 'MetricAlarms[0].StateValue' --output text; }
code() { curl -s -o /dev/null -w '%{http_code}' "$URL"; }
titre "Sprint 12 - etat initial : alarme $(etat), portail $(code)"
T0=$(date +%s); echo "$(date -u +%T) arret de web-01 ($W)"
aws ec2 stop-instances --instance-ids "$W" >/dev/null
until [[ "$(etat)" == ALARM ]]; do sleep 10; printf '%s portail=%s alarme=%s\n' "$(date -u +%T)" "$(code)" "$(etat)"; done
T1=$(date +%s); echo "$(date -u +%T) ALARM apres $((T1 - T0)) s (notification SNS envoyee au topic d'exploitation)"
aws ec2 start-instances --instance-ids "$W" >/dev/null; echo "$(date -u +%T) action corrective : redemarrage de web-01 (runbook alarme-cibles)"
until [[ "$(etat)" == OK ]]; do sleep 15; printf '%s portail=%s alarme=%s\n' "$(date -u +%T)" "$(code)" "$(etat)"; done
T2=$(date +%s)
titre "Resultat : detection $((T1 - T0)) s, retour a la normale $((T2 - T1)) s apres l'alerte (MTTR), portail $(code)"
aws cloudwatch describe-alarm-history --alarm-name "$ALARME" --history-item-type StateUpdate --max-items 4 \
  --query 'AlarmHistoryItems[].[Timestamp,HistorySummary]' --output table
