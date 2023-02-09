#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source "$SCRIPT_DIR/constants.env"

if [ "$#" -lt 1 ]; then
  cat <<HEREDOC

  Usage: $(basename ${BASH_SOURCE[0]}) <environment>

  Deploys the given $APPLICATION environment

HEREDOC

  exit 1
fi

PATH="$PATH:$SCRIPT_DIR/bin"
stackName="$1-$APPLICATION"

accountId=$(aws sts get-caller-identity --output json | jq -r '.Account')
if [ -z "$accountId" ]; then # sandbox account
  echo "authorized aws account id is not recognized, make sure you're logged in" > /dev/stderr
  exit 1
fi

if ! stack-exists "subdomain-$APPLICATION-dns"; then
  echo 'DNS stack not found. create one by following the instructions here: https://github.com/openstax/subdomains' > /dev/stderr
  exit 1
fi
if ! stack-exists "subdomain-$APPLICATION-cert"; then
  echo 'SSL cert stack not found. create one by following the instructions here: https://github.com/openstax/subdomains' > /dev/stderr
  exit 1
fi

# =======
# main deployment includes alt region for failovers
# =======
aws cloudformation deploy \
  --region us-east-2 \
  --no-fail-on-empty-changeset \
  --template-file "$SCRIPT_DIR/deployment-alt-region.cfn.yml" \
  --stack-name "$stackName" \
  --tags "Project=$PROJECT" "Application=$APPLICATION" "Environment=$1" "Owner=$OWNER"

# clouformation cannot reference exports across regions, so these are applied like this
replicaBucketWebsiteURL=$(AWS_DEFAULT_REGION=us-east-2 get-stack-param "$stackName" ReplicaBucketWebsiteURL)

aws cloudformation deploy \
  --region us-east-1 \
  --template-file "$SCRIPT_DIR/deployment.cfn.yml" \
  --stack-name "$stackName" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides "EnvName=$1" "Application=$APPLICATION" "ReplicaBucketWebsiteURL=$replicaBucketWebsiteURL" \
  --tags "Project=$PROJECT" "Application=$APPLICATION" "Environment=$1" "Owner=$OWNER"

domainName=$(get-stack-param "$stackName" DistributionDomainName)
distributionId=$(get-stack-param "$stackName" DistributionId)

aws cloudfront create-invalidation --distribution-id "$distributionId" --paths "/*" --output text --query "Invalidation.Status"

# =======
# done
# =======
echo "deployed: $domainName";
