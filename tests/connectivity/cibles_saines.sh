#!/usr/bin/env bash
# Verifie que toutes les cibles des groupes de l'ALB d'une pile sont saines (attente max 5 min).
set -euo pipefail
PILE="${1:?usage: cibles_saines.sh <pile>}"
REGION="${AWS_REGION:-eu-north-1}"
ENV="${PILE##*-}"
ALB_ARN=$(aws elbv2 describe-load-balancers --region "$REGION" --names "alb-${ENV}-portail-bkay" \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text)
for essai in $(seq 1 30); do
  MALADES=0
  for TG in $(aws elbv2 describe-target-groups --region "$REGION" --load-balancer-arn "$ALB_ARN" \
      --query 'TargetGroups[].TargetGroupArn' --output text); do
    ETATS=$(aws elbv2 describe-target-health --region "$REGION" --target-group-arn "$TG" \
      --query 'TargetHealthDescriptions[].TargetHealth.State' --output text)
    echo "essai ${essai} - ${TG##*/targetgroup/} : ${ETATS}"
    for e in $ETATS; do [[ "$e" == healthy ]] || MALADES=$((MALADES + 1)); done
  done
  [[ "$MALADES" -eq 0 ]] && { echo "OK : toutes les cibles sont saines"; exit 0; }
  sleep 10
done
echo "ECHEC : cibles non saines apres 5 minutes"; exit 1
