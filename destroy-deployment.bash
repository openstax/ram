#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source "$SCRIPT_DIR/constants.env"

function print_usage_and_exit() {
  cat <<HEREDOC

  Usage: $(basename ${BASH_SOURCE[0]}) <environment> [options]

  Destroys the given $APPLICATION environment

  Options:
    -y - skips confirmation prompts to empty frontend buckets and delete stacks - default: don't skip

HEREDOC

  exit 1
}

if [ "$#" -lt 1 ]; then
  print_usage_and_exit
fi

args=("$@")
function getArg() {
  node -e "console.log(require('yargs').argv['_']['$1'] || '')" -- yargs "${args[@]}"
}

environment=$(getArg 0)

if [ -z "$environment" ]; then
  print_usage_and_exit
fi

function getKwarg() {
  node -e "console.log(require('yargs').argv['$1'] || '')" -- yargs "${args[@]}"
}

yes=$(getKwarg y)

if [ -n "$yes" ]; then
  empty=y
else
  printf "This will destroy the $APPLICATION $environment environment. Proceed? [y/N]: "
  read -r do_it

  if [ "$do_it" != "y" ]; then
    exit 1
  fi

  printf "Empty frontend buckets? [y/N]: "
  read -r empty
fi

PATH="$PATH:$SCRIPT_DIR/bin"
stackName="$1-$APPLICATION"

# Empty the buckets if requested, then delete the stacks in reverse creation order

if [ "$empty" == "y" ]; then
  cliVersion=$(aws --version)
  if [[ "$cliVersion" == aws-cli/2* ]]; then
    pager=--no-cli-pager
  else
    pager=
  fi

  empty_bucket () {
    bucketName=$1
    # Deleting versioned buckets is harder than non-versioned ones

    versions=$(aws s3api list-object-versions \
                  --bucket "$bucketName" \
                  --output json \
                  --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
                  "$pager")

    versionsWithQuietFlag="${versions:0:$((${#versions}-1))}, \"Quiet\": true }"

    if [[ ${versions} =~ Objects\":\ null ]]; then
      echo "$bucketName" is empty.
    else
      echo "Deleting files in $bucketName."
      aws s3api delete-objects --bucket "$bucketName" --delete "$versionsWithQuietFlag" "$pager"
    fi
  }

  primaryBucket=$(get-stack-param "$stackName" StaticBucketName)
  replicaBucket=$(AWS_DEFAULT_REGION=us-east-2 get-stack-param "$stackName" ReplicaBucketName)

  empty_bucket "$primaryBucket"
  empty_bucket "$replicaBucket"
fi

delete_stack () {
  name=$1
  region=$2

  printf "\nchecking $1 stack..."
  if $(AWS_DEFAULT_REGION="$region" stack-exists "$1"); then
    printf " deleting it"
    AWS_DEFAULT_REGION="$region" aws cloudformation delete-stack --region "$region" --stack-name "$1"

    while stack-exists "$1"; do
      printf "."
      sleep 5
    done
    echo
  fi
}

delete_stack "$stackName" us-east-1
delete_stack "$stackName" us-east-2

echo "done."
