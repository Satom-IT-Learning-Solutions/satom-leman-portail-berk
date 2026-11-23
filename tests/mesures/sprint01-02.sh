#!/usr/bin/env bash
# Sprints 1-2 : plages, zones et routage (aucune route privee vers l'IGW).
# shellcheck source=tests/mesures/commun.sh
source "$(dirname "$0")/commun.sh"
V=$(vpc "$ENV")
titre "Sprint 1 - sous-reseaux de vpc-${ENV}-leman-bkay ($V)"
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$V" \
  --query "sort_by(Subnets,&CidrBlock)[].[Tags[?Key=='Name']|[0].Value,CidrBlock,AvailabilityZone,MapPublicIpOnLaunch]" --output table
titre "Sprint 2 - routes par defaut"
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$V" \
  --query "RouteTables[?Tags].[Tags[?Key=='Name']|[0].Value, Routes[?DestinationCidrBlock=='0.0.0.0/0']|[0].[GatewayId||NatGatewayId]|[0] || 'aucune']" --output table
PRIVE_IGW=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$V" "Name=tag:Name,Values=rt-prive-*" \
  --query "RouteTables[].Routes[?starts_with(GatewayId||'', 'igw-')]" --output text)
if [[ -n "$PRIVE_IGW" ]]; then echo "ECHEC : route privee vers l'IGW"; exit 1; fi
echo "OK : aucune route privee vers l'Internet Gateway"
