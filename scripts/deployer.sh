#!/usr/bin/env bash
# Deploiement d'un environnement par change set (jamais de suppression non confirmee).
# Usage : scripts/deployer.sh <dev|prod> [--auto]   (--auto : execution sans confirmation, utilise par la pipeline)
set -euo pipefail

ENV="${1:?usage: deployer.sh <dev|prod> [--auto]}"
AUTO="${2:-}"
REGION="${AWS_REGION:-eu-north-1}"
EQUIPE="bkay"
PILE="stack-leman-${ENV}"
COMPTE="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="leman-artefacts-${EQUIPE}-${COMPTE}-${REGION}"
VERSION="${GITHUB_SHA:-$(git rev-parse HEAD)}"
VERSION="${VERSION:0:12}"
ROLE_EXEC="arn:aws:iam::${COMPTE}:role/leman-cfn-execution-${EQUIPE}"

echo "== ${PILE} (${REGION}) version ${VERSION}"

# En cas d'echec : causes CloudFormation de la pile et de ses piles imbriquees (diagnostic dans la pipeline)
diagnostic() {
  echo "== Diagnostic : evenements en echec"
  for P in "$PILE" $(aws cloudformation describe-stack-resources --region "$REGION" --stack-name "$PILE" \
      --query "StackResources[?ResourceType=='AWS::CloudFormation::Stack'].PhysicalResourceId" --output text 2>/dev/null); do
    aws cloudformation describe-stack-events --region "$REGION" --stack-name "$P" --max-items 60 \
      --query "StackEvents[?ends_with(ResourceStatus,'FAILED')].[Timestamp,LogicalResourceId,ResourceStatusReason]" --output text | head -5
  done
}
trap 'diagnostic' ERR

# 1. Artefact applicatif versionne
aws s3 cp app/portail.py "s3://${BUCKET}/app/${VERSION}/portail.py" --region "$REGION" --only-show-errors
aws s3 cp app/portail.py "s3://${BUCKET}/app/courant/portail.py" --region "$REGION" --only-show-errors

# 2. Valeurs resolues dynamiquement (jamais de secret)
PL_CF="$(aws ec2 describe-managed-prefix-lists --region "$REGION" \
  --filters Name=prefix-list-name,Values=com.amazonaws.global.cloudfront.origin-facing \
  --query 'PrefixLists[0].PrefixListId' --output text)"
# Certificat importe de l'equipe (ADR-005) : ARN publie dans SSM, jamais la cle privee
CERT="$(aws ssm get-parameter --region "$REGION" --name /leman-bkay/certificat-alb-arn --query Parameter.Value --output text)"

# 3. Paquetage des piles imbriquees
aws cloudformation package --region "$REGION" --template-file templates/main.yaml \
  --s3-bucket "$BUCKET" --s3-prefix "cfn/${ENV}/${VERSION}" --output-template-file "/tmp/main-${ENV}.yaml" >/dev/null

PARAMS=$(python3 - "$ENV" "$PL_CF" "$CERT" "$BUCKET" "$VERSION" <<'PY'
import json, sys
env, pl, cert, bucket, version = sys.argv[1:]
p = json.load(open(f"parameters/{env}.json"))
p.update({"ListePrefixesCloudFront": pl, "CertificatAlbArn": cert, "BucketArtefacts": bucket, "VersionApp": version})
print(" ".join(f"ParameterKey={k},ParameterValue={v}" for k, v in p.items()))
PY
)

# 4. Application d'une pile par change set (meme logique pour la pile racine et la pile edge)
#    appliquer <pile> <fichier-template> "<parametres>" [imbriquees]
appliquer() {
  local PILE_C="$1" MODELE="$2" PARAMS_C="$3" IMBRIQUEES="${4:-}" ETAT TYPE CS RAISON DANGER CS_IMBRIQUE R
  ETAT="$(aws cloudformation describe-stacks --stack-name "$PILE_C" --region "$REGION" --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo ABSENTE)"
  if [[ "$ETAT" == ROLLBACK_COMPLETE ]]; then   # creation echouee : la pile n'a jamais existe
    echo "Pile ${PILE_C} en ROLLBACK_COMPLETE : suppression avant nouvelle tentative"
    aws cloudformation delete-stack --region "$REGION" --stack-name "$PILE_C" --role-arn "$ROLE_EXEC"
    aws cloudformation wait stack-delete-complete --region "$REGION" --stack-name "$PILE_C"
    ETAT=ABSENTE
  fi
  if [[ "$ETAT" == ABSENTE ]]; then TYPE=CREATE; else TYPE=UPDATE; fi
  CS="cs-${VERSION}-$(date +%s)"
  # shellcheck disable=SC2086
  aws cloudformation create-change-set --region "$REGION" --stack-name "$PILE_C" --change-set-name "$CS" \
    --change-set-type "$TYPE" --template-body "file://${MODELE}" --parameters $PARAMS_C \
    --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND --role-arn "$ROLE_EXEC" ${IMBRIQUEES:+--include-nested-stacks} \
    --tags Key=Projet,Value=SatomCloudNetwork Key=Equipe,Value="$EQUIPE" Key=Environnement,Value="$ENV" >/dev/null
  if ! aws cloudformation wait change-set-create-complete --region "$REGION" --stack-name "$PILE_C" --change-set-name "$CS"; then
    RAISON=$(aws cloudformation describe-change-set --region "$REGION" --stack-name "$PILE_C" --change-set-name "$CS" --query StatusReason --output text)
    if [[ "$RAISON" == *"didn't contain changes"* || "$RAISON" == *"No updates"* ]]; then echo "${PILE_C} : aucun changement."; return 0; fi
    echo "Echec du change set ${PILE_C} : $RAISON"; return 1
  fi
  echo "== Change set ${PILE_C}"
  aws cloudformation describe-change-set --region "$REGION" --stack-name "$PILE_C" --change-set-name "$CS" \
    --query 'Changes[].ResourceChange.[Action,LogicalResourceId,ResourceType,Replacement]' --output table

  # Garde-fou (ADR-014) : bloque toute suppression (racine et imbriquees) et tout remplacement a la racine.
  # Dans les change sets imbriques, l'indicateur de remplacement n'est pas fiable (parametres issus des
  # sorties d'autres piles reevalues a chaque deploiement) : detail affiche pour relecture.
  # shellcheck disable=SC2016  # les accents graves sont des litteraux JMESPath, pas une expansion shell
  DANGER=$(aws cloudformation describe-change-set --region "$REGION" --stack-name "$PILE_C" --change-set-name "$CS" \
    --query 'length(Changes[?ResourceChange.Action==`Remove` || ResourceChange.Replacement==`True`])' --output text)
  for CS_IMBRIQUE in $(aws cloudformation describe-change-set --region "$REGION" --stack-name "$PILE_C" --change-set-name "$CS" \
      --query "Changes[?ResourceChange.ChangeSetId].ResourceChange.ChangeSetId" --output text); do
    aws cloudformation describe-change-set --region "$REGION" --change-set-name "$CS_IMBRIQUE" \
      --query 'Changes[].ResourceChange.[Action,LogicalResourceId,ResourceType,Replacement]' --output table
    # shellcheck disable=SC2016
    DANGER=$((DANGER + $(aws cloudformation describe-change-set --region "$REGION" --change-set-name "$CS_IMBRIQUE" \
      --query 'length(Changes[?ResourceChange.Action==`Remove`])' --output text)))
  done
  echo "Suppressions (racine et imbriquees) ou remplacements a la racine : ${DANGER}"
  if [[ "$DANGER" != "0" && "${CONFIRMER_SUPPRESSION:-non}" != "oui" ]]; then
    echo "Le change set supprime ou remplace ${DANGER} ressource(s). Relancer avec CONFIRMER_SUPPRESSION=oui apres relecture."
    return 2
  fi
  if [[ "$AUTO" != "--auto" ]]; then read -r -p "Executer le change set ${CS} ? (oui/non) " R; [[ "$R" == "oui" ]] || return 0; fi
  aws cloudformation execute-change-set --region "$REGION" --stack-name "$PILE_C" --change-set-name "$CS"
  if [[ "$TYPE" == CREATE ]]; then aws cloudformation wait stack-create-complete --region "$REGION" --stack-name "$PILE_C"
  else aws cloudformation wait stack-update-complete --region "$REGION" --stack-name "$PILE_C"; fi
  echo "${PILE_C} : $(aws cloudformation describe-stacks --region "$REGION" --stack-name "$PILE_C" --query 'Stacks[0].StackStatus' --output text)"
}
sortie() { aws cloudformation describe-stacks --region "$REGION" --stack-name "$1" \
  --query "Stacks[0].Outputs[?OutputKey=='$2'].OutputValue" --output text; }

# 5. Pile racine (piles imbriquees)
appliquer "$PILE" "/tmp/main-${ENV}.yaml" "$PARAMS" imbriquees

# 6. Bordure (sprint 11) : CloudFront, OAC, WAF regional - pile separee pour pouvoir la supprimer seule
PARAMS_EDGE="ParameterKey=Environnement,ParameterValue=${ENV} ParameterKey=Equipe,ParameterValue=${EQUIPE}"
PARAMS_EDGE+=" ParameterKey=AlbDns,ParameterValue=$(sortie "$PILE" AlbDns) ParameterKey=AlbArn,ParameterValue=$(sortie "$PILE" AlbArn)"
appliquer "${PILE}-edge" templates/06-edge.yaml "$PARAMS_EDGE"
aws s3 sync app/static "s3://$(sortie "${PILE}-edge" BucketStatique)/static/" --region "$REGION" --only-show-errors --delete
echo "Portail : https://$(sortie "${PILE}-edge" DomaineDistribution)/"
