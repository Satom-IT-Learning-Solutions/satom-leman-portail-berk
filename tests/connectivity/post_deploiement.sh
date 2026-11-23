#!/usr/bin/env bash
# Etape 7 : aucune alarme en etat ALARM, aucune non-conformite AWS Config sur le perimetre.
set -euo pipefail
ENV="${1:?usage: post_deploiement.sh <dev|prod>}"
REGION="${AWS_REGION:-eu-north-1}"
EN_ALARME=$(aws cloudwatch describe-alarms --region "$REGION" --alarm-name-prefix "alarm-" --state-value ALARM \
  --query "MetricAlarms[?contains(AlarmName, '-${ENV}-bkay')].AlarmName" --output text)
echo "Alarmes en etat ALARM : ${EN_ALARME:-aucune}"
aws cloudwatch describe-alarms --region "$REGION" --alarm-name-prefix "alarm-" \
  --query "MetricAlarms[?contains(AlarmName, '-${ENV}-bkay')].[AlarmName,StateValue]" --output table
NON_CONFORMES=$(aws configservice describe-compliance-by-config-rule --region "$REGION" \
  --compliance-types NON_COMPLIANT --query "ComplianceByConfigRules[?contains(ConfigRuleName, 'leman-bkay')].ConfigRuleName" \
  --output text 2>/dev/null || echo "")
echo "Regles Config non conformes : ${NON_CONFORMES:-aucune}"
[[ -z "$EN_ALARME" && -z "$NON_CONFORMES" ]]
