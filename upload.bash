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

prefix="$2"
stackName="$1-$APPLICATION"
bucketName=$(get-stack-param "$stackName" StaticBucketName)

projects=("rex" "other")
if [[ ! " ${projects[*]} " == *" ${prefix} "* ]]; then
  echo "$prefix is not a recognized RAM project"
  exit 1;
fi

aws s3 sync "$3" "s3://${bucketName}${prefix}" --region us-east-1
