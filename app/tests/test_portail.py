import json
import logging
import threading
import urllib.request
from http.server import ThreadingHTTPServer

import pytest

from app import portail


@pytest.mark.parametrize(
    ("role", "chemin", "statut"),
    [
        ("web", "/", 200),
        ("web", "/health", 200),
        ("web", "/static/style.css", 200),
        ("web", "/inconnu", 404),
        ("api", "/api/health", 200),
        ("api", "/api/portefeuilles?x=1", 200),
        ("api", "/api/inconnu", 404),
    ],
)
def test_router_statuts(role, chemin, statut):
    assert portail.router(role, chemin)[0] == statut


def test_portefeuilles_json():
    _, type_contenu, corps = portail.router("api", "/api/portefeuilles")
    donnees = json.loads(corps)
    assert type_contenu == "application/json"
    assert donnees["total"] == len(donnees["portefeuilles"]) == 3


def test_page_accueil_contient_env():
    _, _, corps = portail.router("web", "/")
    assert portail.ENVIRONNEMENT.encode() in corps


def test_journal_json():
    enregistrement = logging.LogRecord("portail", logging.INFO, __file__, 1, "msg", None, None)
    enregistrement.contexte = {"statut": 200}
    ligne = json.loads(portail.JournalJson().format(enregistrement))
    assert ligne["message"] == "msg"
    assert ligne["statut"] == 200


def test_creer_journal_idempotent():
    assert portail.creer_journal() is portail.creer_journal()
    assert len(portail.creer_journal().handlers) == 1


@pytest.fixture
def serveur():
    srv = ThreadingHTTPServer(("127.0.0.1", 0), portail.fabriquer_gestionnaire("web"))
    fil = threading.Thread(target=srv.serve_forever, daemon=True)
    fil.start()
    yield f"http://127.0.0.1:{srv.server_address[1]}"
    srv.shutdown()


def test_serveur_en_tetes_securite(serveur):
    with urllib.request.urlopen(serveur + "/") as reponse:
        assert reponse.status == 200
        assert reponse.headers["X-Content-Type-Options"] == "nosniff"
        assert reponse.headers["Cache-Control"] == "no-store"


def test_serveur_cache_statique(serveur):
    with urllib.request.urlopen(serveur + "/static/style.css") as reponse:
        assert "max-age" in reponse.headers["Cache-Control"]


def test_serveur_head(serveur):
    requete = urllib.request.Request(serveur + "/health", method="HEAD")
    with urllib.request.urlopen(requete) as reponse:
        assert reponse.status == 200
        assert reponse.read() == b""
