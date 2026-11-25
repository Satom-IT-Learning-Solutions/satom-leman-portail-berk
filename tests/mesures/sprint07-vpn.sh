#!/usr/bin/env bash
# Sprint 7 : etat des tunnels VPN, metrique TunnelState et alarmes associees, routes des sites dans la TGW.
# shellcheck source=tests/mesures/commun.sh
source "$(dirname "$0")/commun.sh"
titre "Sprint 7 - connexions VPN et tunnels"
aws ec2 describe-vpn-connections --filters Name=tag:Equipe,Values=bkay Name=state,Values=available \
  --query 'VpnConnections[].VgwTelemetry[].[OutsideIpAddress,Status,StatusMessage]' --output table
aws ec2 describe-vpn-connections --filters Name=tag:Equipe,Values=bkay Name=state,Values=available \
  --query "VpnConnections[].[Tags[?Key=='Name'].Value|[0],VpnConnectionId,Options.TunnelOptions[0].IkeVersions[0].Value,Options.TunnelOptions[0].Phase1EncryptionAlgorithms[0].Value,Options.TunnelOptions[0].Phase1DHGroupNumbers[0].Value]" --output table
titre "Metrique TunnelState (10 dernieres minutes, maximum par connexion)"
for V in $(aws ec2 describe-vpn-connections --filters Name=tag:Equipe,Values=bkay Name=state,Values=available --query 'VpnConnections[].VpnConnectionId' --output text); do
  printf '%s  ' "$V"
  aws cloudwatch get-metric-statistics --namespace AWS/VPN --metric-name TunnelState --dimensions "Name=VpnId,Value=$V" \
    --start-time "$(date -u -d '-10 min' +%FT%TZ)" --end-time "$(date -u +%FT%TZ)" --period 300 --statistics Maximum \
    --query 'Datapoints[].Maximum' --output text
done
titre "Alarmes TunnelState"
aws cloudwatch describe-alarms --alarm-name-prefix alarm-vpn- --query 'MetricAlarms[].[AlarmName,StateValue,StateReason]' --output table
