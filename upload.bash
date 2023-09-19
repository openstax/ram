#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source "$SCRIPT_DIR/constants.env"

if [ "$#" -lt 1 ]; then
  cat <<HEREDOC

  Usage: $(basename ${BASH_SOURCE[0]}) <environment> <project> <directory-to-upload>

  Deploys the given $APPLICATION environment

HEREDOC

  exit 1
fi

PATH="$PATH:$SCRIPT_DIR/bin"
bucketKey="$2"
prefix=$(cut -d/ -f1 <<< "$bucketKey")
stackName="$1-$APPLICATION"
bucketName=$(get-stack-param "$stackName" StaticBucketName)

echo $bucketName

projects=("rex" "h5p" "analytics")
if [[ ! " ${projects[*]} " == *" ${prefix} "* ]]; then
  echo "$prefix is not a recognized RAM project"
  exit 1;
fi

aws s3 sync --delete "$3" "s3://${bucketName}/${bucketKey}" --region us-east-1

distributionId=$(get-stack-param "$stackName" DistributionId)

aws cloudfront create-invalidation --distribution-id "$distributionId" --paths "/${bucketKey}/*" --output text --query "Invalidation.Status"
