#!/usr/bin/env bash
# VPC Reachability Analyzer entre deux instances (nom Name) sur un port TCP.
# Usage : tests/mesures/accessibilite.sh <instance-source> <instance-destination> <port> [port...]
# Exemples : sprint 5/6 -> dev-01-bkay app-01-prod-bkay 8080 ; dev-01-bkay web-01-prod-bkay 22
# shellcheck source=tests/mesures/commun.sh
source "$(dirname "$0")/commun.sh"
SRC=$(instance "${1:?source}"); DST=$(instance "${2:?destination}"); shift 2
titre "Reachability Analyzer : $SRC -> $DST"
declare -A ANALYSES
for P in "$@"; do
  CHEMIN=$(aws ec2 create-network-insights-path --source "$SRC" --destination "$DST" --protocol tcp --destination-port "$P" \
    --tag-specifications "ResourceType=network-insights-path,Tags=[{Key=Projet,Value=SatomCloudNetwork},{Key=Equipe,Value=bkay},{Key=Environnement,Value=${ENV}}]" \
    --query NetworkInsightsPath.NetworkInsightsPathId --output text)
  ANALYSES[$P]=$(aws ec2 start-network-insights-analysis --network-insights-path-id "$CHEMIN" --query NetworkInsightsAnalysis.NetworkInsightsAnalysisId --output text)
done
for P in "$@"; do
  until [[ "$(aws ec2 describe-network-insights-analyses --network-insights-analysis-ids "${ANALYSES[$P]}" --query 'NetworkInsightsAnalyses[0].Status' --output text)" != running ]]; do sleep 5; done
  aws ec2 describe-network-insights-analyses --network-insights-analysis-ids "${ANALYSES[$P]}" \
    --query "NetworkInsightsAnalyses[0].{Port:'tcp/${P}',Accessible:NetworkPathFound,Raison:Explanations[0].ExplanationCode,Chemin:join(' > ', ForwardPathComponents[].Component.Id)}" --output table
done
