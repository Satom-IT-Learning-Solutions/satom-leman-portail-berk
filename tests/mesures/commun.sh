#!/usr/bin/env bash
# Fonctions partagees par les scripts de mesure (lecture seule sauf mention contraire).
set -euo pipefail
REGION="${AWS_REGION:-eu-north-1}"
ENV="${ENV:-dev}"
export AWS_DEFAULT_REGION="$REGION"
instance() { aws ec2 describe-instances --filters "Name=tag:Name,Values=$1" Name=instance-state-name,Values=running \
  --query 'Reservations[0].Instances[0].InstanceId' --output text; }
vpc() { aws ec2 describe-vpcs --filters "Name=tag:Name,Values=vpc-$1-leman-bkay" --query 'Vpcs[0].VpcId' --output text; }
titre() { printf '\n== %s\n' "$*"; }
