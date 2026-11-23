#!/usr/bin/env bash
# Sprint 3 : VPC Reachability Analyzer web-01 -> app-01 sur 8080 (attendu : accessible) et 22 (attendu : bloque).
# shellcheck source=tests/mesures/commun.sh
source "$(dirname "$0")/commun.sh"
W=$(instance "web-01-${ENV}-bkay"); A=$(instance "app-01-${ENV}-bkay")
titre "Sprint 3 - Reachability Analyzer (web-01 $W -> app-01 $A)"
declare -A ANALYSES
for P in 8080 22; do
  CHEMIN=$(aws ec2 create-network-insights-path --source "$W" --destination "$A" --protocol tcp --destination-port "$P" \
    --tag-specifications "ResourceType=network-insights-path,Tags=[{Key=Name,Value=web-vers-app-${P}-${ENV}-bkay},{Key=Projet,Value=SatomCloudNetwork},{Key=Equipe,Value=bkay},{Key=Environnement,Value=${ENV}}]" \
    --query NetworkInsightsPath.NetworkInsightsPathId --output text)
  ANALYSES[$P]=$(aws ec2 start-network-insights-analysis --network-insights-path-id "$CHEMIN" \
    --query NetworkInsightsAnalysis.NetworkInsightsAnalysisId --output text)
done
for P in 8080 22; do
  until [[ "$(aws ec2 describe-network-insights-analyses --network-insights-analysis-ids "${ANALYSES[$P]}" --query 'NetworkInsightsAnalyses[0].Status' --output text)" != running ]]; do sleep 5; done
  aws ec2 describe-network-insights-analyses --network-insights-analysis-ids "${ANALYSES[$P]}" \
    --query "NetworkInsightsAnalyses[0].{Chemin:'web-01 -> app-01 tcp/${P}',Statut:Status,Accessible:NetworkPathFound,Raison:Explanations[0].ExplanationCode}" --output table
done
