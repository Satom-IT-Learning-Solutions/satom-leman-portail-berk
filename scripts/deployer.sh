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

# 4. Fonctions communes (change set avec garde-fou ADR-014)
# shellcheck source=scripts/lib-cfn.sh
source "$(dirname "$0")/lib-cfn.sh"

# 5. Pile racine (piles imbriquees)
appliquer "$PILE" "/tmp/main-${ENV}.yaml" "$PARAMS" imbriquees

# 6. Bordure (sprint 11) : CloudFront, OAC, WAF regional - pile separee pour pouvoir la supprimer seule
PARAMS_EDGE="ParameterKey=Environnement,ParameterValue=${ENV} ParameterKey=Equipe,ParameterValue=${EQUIPE}"
PARAMS_EDGE+=" ParameterKey=AlbDns,ParameterValue=$(sortie "$PILE" AlbDns) ParameterKey=AlbArn,ParameterValue=$(sortie "$PILE" AlbArn)"
appliquer "${PILE}-edge" templates/06-edge.yaml "$PARAMS_EDGE"
aws s3 sync app/static "s3://$(sortie "${PILE}-edge" BucketStatique)/static/" --region "$REGION" --only-show-errors --delete
echo "Portail : https://$(sortie "${PILE}-edge" DomaineDistribution)/"
