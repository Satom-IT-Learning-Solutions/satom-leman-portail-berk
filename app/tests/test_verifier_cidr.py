import ipaddress
import json

from scripts import verifier_cidr


def test_aucun_chevauchement(tmp_path):
    (tmp_path / "dev.json").write_text(json.dumps({"CidrVpc": "10.1.0.0/16"}))
    (tmp_path / "prod.json").write_text(json.dumps({"CidrVpc": "10.0.0.0/16"}))
    assert verifier_cidr.chevauchements(verifier_cidr.charger_cidr(tmp_path)) == []


def test_chevauchement_detecte():
    reseaux = {"a": ipaddress.ip_network("10.0.0.0/16"), "b": ipaddress.ip_network("10.0.128.0/17")}
    assert verifier_cidr.chevauchements(reseaux) == [("a", "b")]


def test_main_depot(monkeypatch, capsys):
    monkeypatch.setattr("sys.argv", ["verifier_cidr.py", "parameters"])
    assert verifier_cidr.main() == 0
    assert "aucun chevauchement" in capsys.readouterr().out


def test_main_conflit(tmp_path, monkeypatch):
    (tmp_path / "a.json").write_text(json.dumps({"CidrVpc": "10.0.0.0/16"}))
    (tmp_path / "b.json").write_text(json.dumps({"CidrVpc": "10.0.0.0/16"}))
    monkeypatch.setattr("sys.argv", ["verifier_cidr.py", str(tmp_path)])
    assert verifier_cidr.main() == 1
