#!/usr/bin/env bash
# Sprint 4 : depuis app-01 (prod, sous-reseau prive), un domaine autorise passe et un domaine non
# autorise est bloque par le Network Firewall, qui le journalise. Prerequis : pile stack-leman-firewall.
# shellcheck source=tests/mesures/commun.sh
source "$(dirname "$0")/commun.sh"
A=$(instance "app-01-prod-bkay")
titre "Sprint 4 - tests de sortie depuis app-01 ($A) via Session Manager"
for _ in $(seq 1 30); do   # l'agent SSM se connecte une fois la sortie Internet (NAT + pare-feu) disponible
  [[ "$(aws ssm describe-instance-information --filters "Key=InstanceIds,Values=$A" --query 'InstanceInformationList[0].PingStatus' --output text)" == Online ]] && break
  sleep 10
done
# shellcheck disable=SC2016  # commande executee sur l'instance, pas dans ce shell
CMD=$(aws ssm send-command --instance-ids "$A" --document-name AWS-RunShellScript --comment "mesure sprint 4" \
  --parameters 'commands=["for u in https://s3.eu-north-1.amazonaws.com https://example.com https://www.google.com; do printf \"%-40s \" $u; curl -s -o /dev/null -m 8 -w \"%{http_code}\\n\" $u || echo BLOQUE; done; dnf -q makecache >/dev/null 2>&1 && echo \"depot de paquets AL2023 (dnf)           OK\" || echo \"depot de paquets AL2023 (dnf)           BLOQUE\""]' \
  --query Command.CommandId --output text)
sleep 25
aws ssm get-command-invocation --command-id "$CMD" --instance-id "$A" --query StandardOutputContent --output text
titre "Journal du pare-feu (alertes des 10 dernieres minutes)"
aws logs filter-log-events --log-group-name /leman-bkay/prod/firewall --start-time $(( ($(date +%s) - 600) * 1000 )) \
  --query 'events[].message' --output text | jq -r '[.event.timestamp, .event.src_ip, .event.dest_ip, .event.tls.sni // .event.http.hostname // "-", .event.alert.action] | @tsv' 2>/dev/null | sort -u | tail -8
