#!/usr/bin/env bash
# Fonctions communes de deploiement CloudFormation (sourcees par deployer.sh et connectivite.sh).
# Variables attendues : REGION, ROLE_EXEC, VERSION, EQUIPE, ENV, AUTO.
# Application d'une pile par change set (meme logique pour la pile racine et la pile edge)
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

