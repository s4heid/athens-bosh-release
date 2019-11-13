#!/usr/bin/env bash

set -eu

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
STATE_DIR=$ROOT_DIR/ci/terraform

source $ROOT_DIR/scripts/utils.sh
mkdir -p $STATE_DIR

get_state() {
  local name="$(git remote get-url origin)//$1"
  if ! lpass show --sync=now --quiet --notes "$name" >/dev/null 2>&1 ; then
    lpass add --notes --non-interactive --sync=now "$name" <<< ""
  else
    lpass show --sync=now --notes "$name" > $1
  fi
}

put_state() {
  lpass edit --non-interactive --notes "$(git remote get-url origin)//$1" < $1
  lpass sync
}

pushd $STATE_DIR

  # pull state from LastPass note
  get_state terraform.tfvars
  get_state terraform.tfstate

  # run terraform
  terraform init
  terraform plan

  # push state to LastPass note
  put_state terraform.tfvars
  put_state terraform.tfstate

  out="$(terraform output --json -state=terraform.tfstate | jq 'to_entries | map({key, "value": .value.value}) | from_entries')"

popd

cat > "$ROOT_DIR"/config/private.yml <<EOF
private_yml: |
  blobstore:
    provider: s3
    options:
      access_key_id: $( jq -r '.athens_access_key' <<< $out )
      secret_access_key: $( jq -r '.athens_secret_key' <<< $out )
EOF