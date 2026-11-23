#!/usr/bin/env bash
# Affiche l'URL publique (CloudFront) de l'environnement, vide si la pile edge n'existe pas encore.
set -euo pipefail
ENV="${1:?usage: url_publique.sh <dev|prod>}"
DOMAINE=$(aws cloudformation describe-stacks --region us-east-1 --stack-name "stack-leman-${ENV}-edge" \
  --query "Stacks[0].Outputs[?OutputKey=='DomaineDistribution'].OutputValue" --output text 2>/dev/null || true)
[[ -n "$DOMAINE" && "$DOMAINE" != "None" ]] && echo "https://${DOMAINE}" || echo ""
