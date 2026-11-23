"""Sprint 5 - controle de non-chevauchement des CIDR entre environnements (execute par la pipeline)."""

import ipaddress
import json
import pathlib
import sys


def charger_cidr(dossier: pathlib.Path) -> dict[str, ipaddress.IPv4Network]:
    fichiers = sorted(dossier.glob("*.json"))
    return {f.stem: ipaddress.ip_network(json.loads(f.read_text())["CidrVpc"]) for f in fichiers}


def chevauchements(reseaux: dict[str, ipaddress.IPv4Network]) -> list[tuple[str, str]]:
    noms = list(reseaux)
    return [(a, b) for i, a in enumerate(noms) for b in noms[i + 1 :] if reseaux[a].overlaps(reseaux[b])]


def main() -> int:
    reseaux = charger_cidr(pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "parameters"))
    for nom, reseau in reseaux.items():
        print(f"{nom}: {reseau}")
    conflits = chevauchements(reseaux)
    for a, b in conflits:
        print(f"ERREUR : {a} ({reseaux[a]}) chevauche {b} ({reseaux[b]})")
    print("OK : aucun chevauchement" if not conflits else f"{len(conflits)} chevauchement(s)")
    return 1 if conflits else 0


if __name__ == "__main__":
    sys.exit(main())
