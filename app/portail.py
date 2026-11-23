"""Portail Groupe Leman Finance SA - service web et API (bibliotheque standard uniquement).

Le meme fichier sert deux roles :
  - role "web" (web-01, port 80)  : page d'accueil, ressources /static/*, /health
  - role "api" (app-01, port 8080) : /api/health, /api/portefeuilles

Journaux structures en JSON sur la sortie standard (collectes par journald puis CloudWatch Logs).
Aucune donnee client reelle : jeu de donnees fictif conforme a l'exercice.
"""

from __future__ import annotations

import json
import logging
import os
import sys
import time
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

VERSION = os.environ.get("PORTAIL_VERSION", "dev")
ENVIRONNEMENT = os.environ.get("PORTAIL_ENV", "dev")

PORTEFEUILLES = [
    {"id": "PF-001", "conseiller": "C-12", "devise": "CHF", "valeur": 125000.0},
    {"id": "PF-002", "conseiller": "C-07", "devise": "CHF", "valeur": 89000.5},
    {"id": "PF-003", "conseiller": "C-12", "devise": "EUR", "valeur": 42000.0},
]

PAGE_ACCUEIL = """<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="description" content="Portail des conseillers - Groupe Leman Finance SA">
<title>Portail Leman Finance</title>
<link rel="stylesheet" href="/static/style.css">
</head>
<body>
<main>
<h1>Portail des conseillers</h1>
<p>Groupe Leman Finance SA - environnement {env} - version {version}</p>
</main>
</body>
</html>
"""

STYLE = "body{font-family:system-ui,sans-serif;margin:2rem;color:#1a1a1a;background:#fff}h1{color:#0b3d6b}"

EN_TETES_SECURITE = {
    "X-Content-Type-Options": "nosniff",
    "X-Frame-Options": "DENY",
    "Referrer-Policy": "no-referrer",
    "Content-Security-Policy": "default-src 'self'; frame-ancestors 'none'; form-action 'self'",
    "Permissions-Policy": "geolocation=(), camera=(), microphone=()",
    "Cross-Origin-Resource-Policy": "same-origin",
    "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
}


class JournalJson(logging.Formatter):
    """Formate chaque enregistrement en une ligne JSON."""

    def format(self, record: logging.LogRecord) -> str:
        donnees = {
            "ts": time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime(record.created)),
            "niveau": record.levelname,
            "message": record.getMessage(),
        }
        donnees.update(getattr(record, "contexte", {}))
        return json.dumps(donnees, ensure_ascii=False)


def creer_journal() -> logging.Logger:
    journal = logging.getLogger("portail")
    if not journal.handlers:
        sortie = logging.StreamHandler(sys.stdout)
        sortie.setFormatter(JournalJson())
        journal.addHandler(sortie)
        journal.setLevel(logging.INFO)
    return journal


JOURNAL = creer_journal()


def router(role: str, chemin: str) -> tuple[int, str, bytes]:
    """Retourne (statut, type de contenu, corps) pour un chemin donne, sans effet de bord."""
    chemin = chemin.split("?", 1)[0]
    if role == "api":
        if chemin == "/api/health":
            return HTTPStatus.OK, "application/json", b'{"etat":"ok"}'
        if chemin == "/api/portefeuilles":
            corps = json.dumps({"portefeuilles": PORTEFEUILLES, "total": len(PORTEFEUILLES)})
            return HTTPStatus.OK, "application/json", corps.encode()
        return HTTPStatus.NOT_FOUND, "application/json", b'{"erreur":"introuvable"}'
    if chemin == "/health":
        return HTTPStatus.OK, "text/plain; charset=utf-8", b"OK"
    if chemin == "/":
        page = PAGE_ACCUEIL.format(env=ENVIRONNEMENT, version=VERSION)
        return HTTPStatus.OK, "text/html; charset=utf-8", page.encode()
    if chemin == "/static/style.css":
        return HTTPStatus.OK, "text/css; charset=utf-8", STYLE.encode()
    return HTTPStatus.NOT_FOUND, "text/plain; charset=utf-8", b"Introuvable"


def fabriquer_gestionnaire(role: str) -> type[BaseHTTPRequestHandler]:
    class Gestionnaire(BaseHTTPRequestHandler):
        server_version = "portail"
        sys_version = ""

        def _repondre(self, avec_corps: bool) -> None:
            debut = time.perf_counter()
            statut, type_contenu, corps = router(role, self.path)
            self.send_response(statut)
            self.send_header("Content-Type", type_contenu)
            self.send_header("Content-Length", str(len(corps)))
            cache = "public, max-age=86400" if self.path.startswith("/static/") else "no-store"
            self.send_header("Cache-Control", cache)
            for nom, valeur in EN_TETES_SECURITE.items():
                self.send_header(nom, valeur)
            self.end_headers()
            if avec_corps:
                self.wfile.write(corps)
            JOURNAL.info(
                "requete",
                extra={
                    "contexte": {
                        "role": role,
                        "methode": self.command,
                        "chemin": self.path.split("?", 1)[0],
                        "statut": int(statut),
                        "duree_ms": round((time.perf_counter() - debut) * 1000, 2),
                        "trace": self.headers.get("X-Amzn-Trace-Id", ""),
                    }
                },
            )

        def do_GET(self) -> None:  # noqa: N802 (nom impose par http.server)
            self._repondre(avec_corps=True)

        def do_HEAD(self) -> None:  # noqa: N802
            self._repondre(avec_corps=False)

        def log_message(self, format: str, *args: object) -> None:  # noqa: A002
            """Journalisation deja faite en JSON dans _repondre."""

    return Gestionnaire


def main() -> None:
    role = os.environ.get("PORTAIL_ROLE", "web")
    port = int(os.environ.get("PORTAIL_PORT", "80" if role == "web" else "8080"))
    serveur = ThreadingHTTPServer(("0.0.0.0", port), fabriquer_gestionnaire(role))  # noqa: S104  # nosec B104 - acces filtre par sg-web/sg-app
    JOURNAL.info("demarrage", extra={"contexte": {"role": role, "port": port, "version": VERSION}})
    serveur.serve_forever()


if __name__ == "__main__":
    main()
