#!/usr/bin/env bash
# Sprints 4 a 7 : piles de connectivite facturees a l'heure, creees pour une session puis supprimees.
# Usage : scripts/connectivite.sh <firewall|peering|tgw|vpn> <deployer|supprimer>
#   firewall : NAT + Network Firewall dans vpc-prod (sprint 4)
#   peering  : peering dev <-> prod (sprint 5) - exclusif avec tgw
#   tgw      : Transit Gateway et tables par environnement (sprint 6) - exclusif avec peering
#   vpn      : deux VPN site a site sur la TGW (sprint 7) - necessite tgw
set -euo pipefail
PILE_TYPE="${1:?usage: connectivite.sh <firewall|peering|tgw|vpn> <deployer|supprimer>}"
ACTION="${2:?usage: connectivite.sh <firewall|peering|tgw|vpn> <deployer|supprimer>}"
REGION="${AWS_REGION:-eu-north-1}"; EQUIPE=bkay; ENV=prod; AUTO=--auto
COMPTE="$(aws sts get-caller-identity --query Account --output text)"
ROLE_EXEC="arn:aws:iam::${COMPTE}:role/leman-cfn-execution-${EQUIPE}"
VERSION="${GITHUB_SHA:-$(git rev-parse HEAD)}"; VERSION="${VERSION:0:12}"
PILE="stack-leman-${PILE_TYPE}"
# shellcheck source=scripts/lib-cfn.sh
source "$(dirname "$0")/lib-cfn.sh"
p() { printf 'ParameterKey=%s,ParameterValue=%s ' "$1" "$2"; }
cidr_sous_reseau() { aws ec2 describe-subnets --region "$REGION" --subnet-ids "$1" --query 'Subnets[0].CidrBlock' --output text; }

if [[ "$ACTION" == supprimer ]]; then
  [[ "$PILE_TYPE" == tgw ]] && aws cloudformation describe-stacks --region "$REGION" --stack-name stack-leman-vpn >/dev/null 2>&1 \
    && { echo "Supprimer d'abord la pile vpn (elle depend de la TGW)"; exit 2; }
  DEBUT=$(date +%s)
  aws cloudformation delete-stack --region "$REGION" --stack-name "$PILE" --role-arn "$ROLE_EXEC"
  aws cloudformation wait stack-delete-complete --region "$REGION" --stack-name "$PILE"
  echo "${PILE} supprimee en $(( $(date +%s) - DEBUT )) s"
  exit 0
fi

case "$PILE_TYPE" in
  firewall)
    PARAMS="$(p Environnement prod)$(p Equipe "$EQUIPE")$(p VpcId "$(sortie stack-leman-prod VpcId)")"
    PARAMS+="$(p SubFw1a "$(sortie stack-leman-prod SubFw1a)")$(p SubPublic1a "$(sortie stack-leman-prod SubPublic1a)")"
    PARAMS+="$(p RtPrivee "$(sortie stack-leman-prod RtPrivee)")$(p RtPublique "$(sortie stack-leman-prod RtPublique)")"
    PARAMS+="$(p RtFw "$(sortie stack-leman-prod RtFw)")$(p CleJournauxArn "$(sortie stack-leman-prod CleJournauxArn)")"
    PARAMS+="$(p CidrPrive1a "$(cidr_sous_reseau "$(sortie stack-leman-prod SubPrive1a)")")"
    PARAMS+="$(p CidrPrive1b "$(cidr_sous_reseau "$(sortie stack-leman-prod SubPrive1b)")")"
    appliquer "$PILE" templates/07-firewall.yaml "$PARAMS" ;;
  peering|tgw)
    AUTRE=$([[ "$PILE_TYPE" == peering ]] && echo tgw || echo peering)
    if aws cloudformation describe-stacks --region "$REGION" --stack-name "stack-leman-${AUTRE}" >/dev/null 2>&1; then
      echo "La pile stack-leman-${AUTRE} existe : peering et TGW utilisent les memes routes, supprimer l'autre d'abord"; exit 2
    fi
    PARAMS="$(p Equipe "$EQUIPE")$(p VpcProd "$(sortie stack-leman-prod VpcId)")$(p VpcDev "$(sortie stack-leman-dev VpcId)")"
    PARAMS+="$(p CidrProd "$(sortie stack-leman-prod CidrVpc)")$(p CidrDev "$(sortie stack-leman-dev CidrVpc)")"
    PARAMS+="$(p RtPriveeProd "$(sortie stack-leman-prod RtPrivee)")$(p RtPriveeDev "$(sortie stack-leman-dev RtPrivee)")"
    PARAMS+="$(p RtPubliqueDev "$(sortie stack-leman-dev RtPublique)")"
    if [[ "$PILE_TYPE" == tgw ]]; then
      # Liste : virgule echappee pour la syntaxe abregee de l'AWS CLI
      PARAMS+="ParameterKey=SubnetsProd,ParameterValue=$(sortie stack-leman-prod SubPrive1a)\\,$(sortie stack-leman-prod SubPrive1b) "
      PARAMS+="ParameterKey=SubnetsDev,ParameterValue=$(sortie stack-leman-dev SubPrive1a)\\,$(sortie stack-leman-dev SubPrive1b) "
      appliquer "$PILE" templates/09-tgw.yaml "$PARAMS"
    else
      appliquer "$PILE" templates/08-peering.yaml "$PARAMS"
    fi ;;
  vpn)
    TGW="$(sortie stack-leman-tgw TgwId)"
    # Pre-cles : creees une seule fois dans Secrets Manager, jamais affichees ni versionnees
    if ! aws secretsmanager describe-secret --region "$REGION" --secret-id leman/vpn-precles-bkay >/dev/null 2>&1; then
      cle() { aws secretsmanager get-random-password --region "$REGION" --password-length 32 --exclude-punctuation \
        --query RandomPassword --output text | sed 's/^0/A/'; }
      aws secretsmanager create-secret --region "$REGION" --name leman/vpn-precles-bkay \
        --description "Pre-cles des tunnels VPN du portail Leman (sprint 7)" \
        --tags Key=Projet,Value=SatomCloudNetwork Key=Equipe,Value="$EQUIPE" Key=Environnement,Value=prod \
        --secret-string "{\"siege1\":\"$(cle)\",\"siege2\":\"$(cle)\",\"agence1\":\"$(cle)\",\"agence2\":\"$(cle)\"}" >/dev/null
      echo "Secret leman/vpn-precles-bkay cree (valeurs non affichees)"
    fi
    TOPIC="$(aws sns list-topics --region "$REGION" --query "Topics[?ends_with(TopicArn,':sns-exploitation-leman-prod-${EQUIPE}')].TopicArn | [0]" --output text)"
    PARAMS="$(p Equipe "$EQUIPE")$(p TgwId "$TGW")$(p TopicAlertes "$TOPIC")"
    appliquer "$PILE" templates/10-vpn.yaml "$PARAMS"
    # Les attachements VPN de la TGW n'ont pas d'attribut CloudFormation : association a la table prod
    # et propagation des sites dans la table prod seulement (dev ne joint pas les sites).
    TABLE_PROD="$(sortie stack-leman-tgw TableProd)"
    for VPN in $(sortie "$PILE" VpnSiege) $(sortie "$PILE" VpnAgence); do
      ATT=$(aws ec2 describe-transit-gateway-attachments --region "$REGION" \
        --filters "Name=resource-id,Values=${VPN}" "Name=transit-gateway-id,Values=${TGW}" \
        --query 'TransitGatewayAttachments[0].TransitGatewayAttachmentId' --output text)
      aws ec2 associate-transit-gateway-route-table --region "$REGION" --transit-gateway-route-table-id "$TABLE_PROD" \
        --transit-gateway-attachment-id "$ATT" >/dev/null 2>&1 || true
      aws ec2 enable-transit-gateway-route-table-propagation --region "$REGION" --transit-gateway-route-table-id "$TABLE_PROD" \
        --transit-gateway-attachment-id "$ATT" >/dev/null 2>&1 || true
      echo "Attachement ${ATT} (${VPN}) : associe et propage dans ${TABLE_PROD}"
    done ;;
  *) echo "Pile inconnue : ${PILE_TYPE}"; exit 2 ;;
esac
