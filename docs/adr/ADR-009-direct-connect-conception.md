# ADR-009 - Direct Connect : voie principale et bascule (conception)

- **Statut** : accepte - revue obligatoire du sprint 8
- **Decision** : Direct Connect est la voie principale vers le siege (local-preference 200 sur les routes recues par DX, 100 par VPN), le VPN site-a-site est la voie de secours. Les prefixes annonces vers AWS sont filtres (10.10.0.0/16 siege, 10.20.0.0/16 agence) et aucune route par defaut n'est acceptee depuis les sites.
- **Simulation** : DXGW `dxgw-leman` (ASN 64513) associee a la TGW ; la bascule DX -> VPN a ete demontree sur la maquette du module 8 (FRR, local-pref) : retour automatique et temps mesures dans la documentation du cours. Aucune mesure de debit n'est inventee.
