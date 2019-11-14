#!/usr/bin/env bash

set -eu

ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
STATE_DIR=$ROOT_DIR/ci/terraform

source "$ROOT_DIR"/scripts/utils.sh

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

is-installed terraform
is-installed lpass
logged-in

mkdir -p $STATE_DIR

pushd "$STATE_DIR" > /dev/null

  info "pull state from lastpass note"
  get_state terraform.tfvars
  get_state terraform.tfstate

  info "run terraform apply"
  terraform init
  terraform plan

  info "push state to lastpass note"
  put_state terraform.tfvars
  put_state terraform.tfstate

  out="$(terraform output --json -state=terraform.tfstate | jq 'to_entries | map({key, "value": .value.value}) | from_entries')"

popd > /dev/null

cat > "$ROOT_DIR"/config/private.yml <<EOF
private_yml: |
  blobstore:
    provider: s3
    options:
      access_key_id: $( jq -r '.athens_access_key' <<< $out )
      secret_access_key: $( jq -r '.athens_secret_key' <<< $out )
EOF

if [ ! -f "$ROOT_DIR"/.envrc ]; then
  cat > "$ROOT_DIR"/.envrc <<EOF
#!/bin/bash

# bbl environment (https://github.com/cloudfoundry/bosh-bootloader)
export BBL_STATE_DIR=~/workspace/bosh-openstack-cpi-shared/aws
eval "$(bbl --state-dir "${BBL_STATE_DIR}" print-env)"

# bosh stemcell (https://bosh.io/stemcells)
export STEMCELL_NAME=bosh-aws-xen-hvm-ubuntu-xenial-go_agent
export STEMCELL_VERSION=456.30
export STEMCELL_SHA1=4926ffe4755c18ac7836cdcfb294e6ae02fc84a9

# aws access keys
export AWS_ACCESS_KEY_ID="$( jq -r '.athens_access_key' <<< $out )"
export AWS_SECRET_ACCESS_KEY="$( jq -r '.athens_secret_key' <<< $out )"
EOF
fi

info "Done"