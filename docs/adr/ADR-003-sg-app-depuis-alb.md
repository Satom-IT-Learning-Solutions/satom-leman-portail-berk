# ADR-003 - sg-app accepte 8080 depuis sg-web et depuis l'ALB

- **Statut** : accepte - 23/11/2026
- **Contexte** : l'enonce demande « sg-app : 8080 depuis sg-web seulement », mais exige aussi une regle ALB `/api/*` vers `tg-app` : les health checks et requetes de l'ALB viennent de sg-alb.
- **Decision** : sg-app autorise 8080 depuis sg-web **et** sg-alb (et, sprint 5, depuis le CIDR du VPC dev). Aucune autre source. sg-web n'expose que 80 depuis sg-alb ; le 443 public est porte par sg-alb, lui-meme restreint a la liste de prefixes CloudFront.
- **Consequences** : aucune instance n'est exposee directement ; aucun port d'administration (22/3389) n'existe, l'administration passe par Session Manager.
