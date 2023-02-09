#!/usr/bin/env bash
set -euo pipefail

source "$SCRIPT_DIR/constants.env"

echo

args=("$@")
function getArg() {
  node -e "console.log(require('yargs').argv['_']['$1'] || '')" -- yargs "${args[@]}"
}
function getKwarg() {
  node -e "console.log(require('yargs').argv['$1'] || '')" -- yargs "${args[@]}"
}

region=$(getKwarg r)
region=${region:-us-east-1}

# Prevent bad behavior when trying to upload URL params on awscli v1
aws_version=$(aws --version)
if [ -z "${aws_version##aws-cli/1.*}" ]; then
  # true is the default value for awscli v1
  original_cli_follow_urlparam=$(aws configure get cli_follow_urlparam || echo 'true')

  function restore_cli_follow_urlparam() {
    aws configure set cli_follow_urlparam "$original_cli_follow_urlparam"
  }

  # Needed to upload URLs as secret values. Explanation: https://github.com/aws/aws-cli/issues/2507
  aws configure set cli_follow_urlparam false

  trap restore_cli_follow_urlparam EXIT
fi

function get_value() {
  printf "Enter new value for \"$name\" (leave blank to skip): "
  read -r value
}

function upload_parameter() {
  set +e
  previous_value=$(aws ssm get-parameter --region "$region" --name "$name" --with-decryption \
                   --query Parameter.Value --output text 2>&1)
  get_parameter_failed=$?
  set -e

  if [ "$get_parameter_failed" -eq 0 ]; then
    echo "Parameter \"$name\" already exists"

    if [ -n "${interactive:-}" ]; then
      echo "Current value: \"$previous_value\""

      get_value

      if [ -z "$value" ]; then
        echo "Skipping parameter \"$name\" (previous value kept)"

        return
      fi
    # The parameter store (or maybe the upload command) removes trailing newlines
    # Maybe relevant when uploading public/private key certificates
    elif [ "$value" = "$previous_value" ] || [ "$value" = "$previous_value"$'\n' ]; then
      echo "Skipping parameter \"$name\" as the new and previous values match"

      return
    else
      echo "New and previous values for parameter \"$param\" differ"

      if [ -z "$overwrite" ]; then
        echo "Skipping parameter \"$name\" as the -o option was not set (previous value kept)"

        return
      fi
    fi

    if [ -n "$value" ]; then
      echo "Overwriting parameter \"$name\" with new value"

      aws ssm put-parameter --region "$region" --type SecureString \
        --name "$name" --value "$value" --overwrite
    else
      echo "Skipping parameter \"$name\" (previous value kept)"
    fi
  elif [[ -n "${previous_value##*ParameterNotFound*}" ]]; then
    # Error is NOT ParameterNotFound
    printf "$previous_value\n\n"
    exit 1
  else
    # Error is ParameterNotFound
    if [ -n "${interactive:-}" ]; then
      get_value

      if [ -z "$value" ]; then
        echo "Skipping parameter \"$name\" (not uploaded)"

        return
      fi
    fi

    echo "Uploading new parameter \"$name\""

    aws ssm put-parameter --region "$region" --type SecureString --name "$name" --value "$value" \
      --tags "Key=Project,Value=$PROJECT" "Key=Application,Value=$APPLICATION" \
             'Key=Environment,Value=shared' "Key=Owner,Value=$OWNER"
  fi
}
