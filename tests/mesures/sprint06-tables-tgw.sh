#!/usr/bin/env bash
# Sprint 6 : separation des tables de routage de la TGW (chaque environnement ne voit que l'autre).
# shellcheck source=tests/mesures/commun.sh
source "$(dirname "$0")/commun.sh"
for T in $(aws ec2 describe-transit-gateway-route-tables --filters Name=tag:Equipe,Values=bkay \
    --query 'TransitGatewayRouteTables[].TransitGatewayRouteTableId' --output text); do
  NOM=$(aws ec2 describe-transit-gateway-route-tables --transit-gateway-route-table-ids "$T" --query "TransitGatewayRouteTables[0].Tags[?Key=='Name'].Value|[0]" --output text)
  titre "Table ${NOM} (${T})"
  aws ec2 search-transit-gateway-routes --transit-gateway-route-table-id "$T" --filters Name=state,Values=active \
    --query 'Routes[].[DestinationCidrBlock,Type,TransitGatewayAttachments[0].ResourceType,TransitGatewayAttachments[0].ResourceId]' --output table
done
