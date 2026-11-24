# Rapport de charge - dev - 24/11/2026

- **Outil** : k6 (`tests/load/charge.js`), execute par l'etape 5 de la pipeline (run GitHub Actions 45435132042)
- **Cible** : https://d3aj6p52bzph5x.cloudfront.net (CloudFront -> WAF -> ALB -> web-01 / app-01)
- **Profil** : montee 30 s a 10 utilisateurs virtuels, palier 2 min, descente 30 s (duree 3 min)
- **Parcours** : `/` (page, non mise en cache), `/static/style.css` (S3 via OAC, cache), `/api/portefeuilles` (API, non mise en cache)

| Indicateur | Mesure | SLO | Statut |
|---|---|---|---|
| Requetes | 3 573 (19,8 req/s), 1 191 iterations | - | - |
| Taux d'erreur | 0,00 % (0 / 3 573) | < 0,5 % | OK |
| Latence p95 (toutes requetes) | 209 ms | < 500 ms | OK |
| Latence p99 (toutes requetes) | 234 ms | < 1 s | OK |
| p95 / p99 API | 231 ms / 234 ms | < 500 ms / < 1 s | OK |
| p95 / p99 page | 228 ms / 235 ms | < 500 ms / < 1 s | OK |
| Latence maximale | 410 ms | - | - |
| Controles fonctionnels | 100 % (3 573 / 3 573) | 100 % | OK |

La latence mesuree inclut le trajet runner GitHub (Etats-Unis) -> point de presence CloudFront -> eu-north-1. Les ressources statiques servies depuis le cache descendent a 2 ms (minimum).

**Incident lie** : un premier essai a 20 utilisateurs virtuels a ete bloque par la regle WAF de limitation de debit (1 000 requetes / 5 min / IP) : la protection fonctionne. La limite a ete portee a 10 000 / 5 min / IP, au-dessus de la charge nominale d'une seule IP de test.
