# Runbook - alarm-vpn-siege-bkay / alarm-vpn-agence-bkay (critique)

**Symptome** : `TunnelState` maximal < 1 pendant 5 minutes : aucun des deux tunnels de la connexion n'est UP ; e-mail SNS « ALARM ».

**Diagnostic**
1. `aws ec2 describe-vpn-connections --vpn-connection-ids <id> --query 'VpnConnections[0].VgwTelemetry'` : statut et `StatusMessage` de chaque tunnel (IPSEC IS DOWN, BGP...).
2. Cote site : IP publique du routeur client inchangee ? Pre-cle identique a celle de Secrets Manager (`leman/vpn-precles-bkay`) ? Phase 1 / 2 en IKEv2, AES-256, SHA-256, DH 14 ?
3. BGP : session etablie, prefixes annonces filtres (aucune route par defaut acceptee).

**Action corrective** : corriger la configuration du routeur client ; en cas de rotation des pre-cles, mettre a jour le secret puis redeployer la pile VPN par la pipeline (le template ne contient que la reference dynamique). Noter le MTTR dans `docs/journal.md`.
