#!/usr/bin/env bash
# Suppression confirmee d'un environnement (sprint 13 - reprise apres sinistre).
# Vide les buckets versionnes de l'environnement (journaux ALB, statiques) puis supprime
# la pile edge et la pile racine, avec le role d'execution. Usage : scripts/supprimer.sh <dev|prod> oui
set -euo pipefail
ENV="${1:?usage: supprimer.sh <dev|prod> oui}"
[[ "${2:-}" == "oui" ]] || { echo "Confirmation requise : scripts/supprimer.sh ${ENV} oui"; exit 2; }
[[ "$ENV" == "prod" && "${CONFIRMER_PROD:-non}" != "oui" ]] && { echo "Prod : CONFIRMER_PROD=oui requis"; exit 2; }
REGION="${AWS_REGION:-eu-north-1}"; EQUIPE=bkay
COMPTE="$(aws sts get-caller-identity --query Account --output text)"
ROLE_EXEC="arn:aws:iam::${COMPTE}:role/leman-cfn-execution-${EQUIPE}"
DEBUT=$(date +%s); echo "Debut de la suppression : $(date -u +%FT%TZ)"

vider() {  # supprime toutes les versions et marqueurs d'un bucket versionne
  local B="$1"
  aws s3api head-bucket --bucket "$B" 2>/dev/null || return 0
  while :; do
    LOT=$(aws s3api list-object-versions --bucket "$B" --max-items 500 --output json \
      --query '{Objects: [Versions[].{Key:Key,VersionId:VersionId}, DeleteMarkers[].{Key:Key,VersionId:VersionId}][] }')
    [[ "$(echo "$LOT" | jq '.Objects | length')" -eq 0 ]] && break
    aws s3api delete-objects --bucket "$B" --delete "$(echo "$LOT" | jq -c '{Objects: .Objects, Quiet: true}')" >/dev/null
  done
  echo "Bucket vide : $B"
}
vider "leman-static-${ENV}-${EQUIPE}-${COMPTE}"
vider "leman-alb-logs-${ENV}-${EQUIPE}-${COMPTE}"

for PILE in "stack-leman-${ENV}-edge" "stack-leman-${ENV}"; do
  if aws cloudformation describe-stacks --region "$REGION" --stack-name "$PILE" >/dev/null 2>&1; then
    aws cloudformation delete-stack --region "$REGION" --stack-name "$PILE" --role-arn "$ROLE_EXEC"
    aws cloudformation wait stack-delete-complete --region "$REGION" --stack-name "$PILE"
    echo "Supprimee : $PILE"
  fi
done
echo "Fin de la suppression : $(date -u +%FT%TZ) - duree $(( $(date +%s) - DEBUT )) s"
