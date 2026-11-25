# ADR-015 - VPN vers des passerelles client fictives : tunnels DOWN attendus

- **Statut** : accepte avec derogation - 25/11/2026
- **Contexte** : l'enonce impose les passerelles 203.0.113.10 et 198.51.100.20 (plages de documentation RFC 5737). Aucun routeur ne repond a ces adresses : les tunnels ne peuvent pas monter.
- **Decision** : les deux connexions sont deployees conformement a l'enonce (BGP, IKEv2, AES-256, SHA-256, DH 14, pre-cles par reference dynamique Secrets Manager) et le controle porte sur la supervision : `TunnelState` = 0 et passage en ALARM des deux alarmes, avec notification SNS. La montee des tunnels et la bascule ont ete demontrees au module 7 du cours avec un site simule (strongSwan sur EC2, tunnels UP, bascule sans perte).
- **Risque accepte** : la mesure « tunnels UP 2/2 » de la section 5 n'est pas atteinte dans ce depot. Proprietaire bkay ; revue si une passerelle de test reelle est fournie (il suffit alors de changer `IpAddress` des deux CustomerGateway).
