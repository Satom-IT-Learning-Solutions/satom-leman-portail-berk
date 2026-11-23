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

# 1. Artefact applicatif versionne
aws s3 cp app/portail.py "s3://${BUCKET}/app/${VERSION}/portail.py" --region "$REGION" --only-show-errors

# 2. Valeurs resolues dynamiquement (jamais de secret)
PL_CF="$(aws ec2 describe-managed-prefix-lists --region "$REGION" \
  --filters Name=prefix-list-name,Values=com.amazonaws.global.cloudfront.origin-facing \
  --query 'PrefixLists[0].PrefixListId' --output text)"
CERT="$(aws acm list-certificates --region "$REGION" \
  --query "CertificateSummaryList[?DomainName=='portefeuilles.leman-finance.example'].CertificateArn | [0]" --output text)"

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

# 4. Change set
if aws cloudformation describe-stacks --stack-name "$PILE" --region "$REGION" >/dev/null 2>&1; then TYPE=UPDATE; else TYPE=CREATE; fi
CS="cs-${VERSION}-$(date +%s)"
# shellcheck disable=SC2086
aws cloudformation create-change-set --region "$REGION" --stack-name "$PILE" --change-set-name "$CS" \
  --change-set-type "$TYPE" --template-body "file:///tmp/main-${ENV}.yaml" --parameters $PARAMS \
  --capabilities CAPABILITY_IAM CAPABILITY_AUTO_EXPAND --role-arn "$ROLE_EXEC" \
  --tags Key=Projet,Value=SatomCloudNetwork Key=Equipe,Value="$EQUIPE" Key=Environnement,Value="$ENV" >/dev/null

if ! aws cloudformation wait change-set-create-complete --region "$REGION" --stack-name "$PILE" --change-set-name "$CS"; then
  RAISON=$(aws cloudformation describe-change-set --region "$REGION" --stack-name "$PILE" --change-set-name "$CS" --query StatusReason --output text)
  if [[ "$RAISON" == *"didn't contain changes"* || "$RAISON" == *"No updates"* ]]; then echo "Aucun changement."; exit 0; fi
  echo "Echec du change set : $RAISON"; exit 1
fi

aws cloudformation describe-change-set --region "$REGION" --stack-name "$PILE" --change-set-name "$CS" \
  --query 'Changes[].ResourceChange.[Action,LogicalResourceId,ResourceType,Replacement]' --output table

# Garde-fou : aucune suppression ni remplacement non confirme
DANGER=$(aws cloudformation describe-change-set --region "$REGION" --stack-name "$PILE" --change-set-name "$CS" \
  --query "length(Changes[?ResourceChange.Action=='Remove' || ResourceChange.Replacement=='True'])" --output text)
if [[ "$DANGER" != "0" && "${CONFIRMER_SUPPRESSION:-non}" != "oui" ]]; then
  echo "Le change set supprime ou remplace ${DANGER} ressource(s). Relancer avec CONFIRMER_SUPPRESSION=oui apres relecture."
  exit 2
fi

if [[ "$AUTO" != "--auto" ]]; then read -r -p "Executer le change set ${CS} ? (oui/non) " R; [[ "$R" == "oui" ]] || exit 0; fi
aws cloudformation execute-change-set --region "$REGION" --stack-name "$PILE" --change-set-name "$CS"
if [[ "$TYPE" == CREATE ]]; then aws cloudformation wait stack-create-complete --region "$REGION" --stack-name "$PILE"
else aws cloudformation wait stack-update-complete --region "$REGION" --stack-name "$PILE"; fi
aws cloudformation describe-stacks --region "$REGION" --stack-name "$PILE" --query 'Stacks[0].[StackStatus,Outputs]' --output json
