#!/usr/bin/env bash

set -euo pipefail

export BOSH_DEPLOYMENT=athens
export BOSH_NON_INTERACTIVE=true
export BOSH_BINARY_PATH=${BOSH_BINARY_PATH:-/usr/local/bin/bosh}

root_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
source "$root_dir"/scripts/utils.sh

stemcell_name="${STEMCELL_NAME:-bosh-warden-boshlite-ubuntu-xenial-go_agent}"
stemcell_version="${STEMCELL_VERSION:-456.30}"
stemcell_sha1="${STEMCELL_SHA1:-61791b4d37ee3aacb9db36bb819c1fbcc4785a9e}"
stemcell_os="${STEMCELL_OS:-ubuntu-xenial}"

pushd "${root_dir}" > /dev/null

info "Deleting old deployment"
# bosh delete-deployment --force

info "Uploading stemcell"
bosh upload-stemcell "https://bosh.io/d/stemcells/${stemcell_name}?v=${stemcell_version}" \
    --name $stemcell_name \
    --sha1 $stemcell_sha1 \
    --version $stemcell_version

ops_files=()

if [[ $stemcell_name == *"aws"* ]]; then
    info "Uploading cloud config"

    bosh update-config \
        --type=cloud \
        --name=athens \
        --vars-file=<(terraform output -state=ci/terraform/terraform.tfstate -json | jq 'to_entries | map({key, "value": .value.value}) | from_entries') \
        --var=default_security_group="$( bosh cloud-config | bosh int --path=/networks/name=default/subnets/0/cloud_properties/security_groups/0 - )" \
        ./manifests/cloud-config.yml

    ops_files+=( "--ops-file=./manifests/operations/aws-terraform-ops.yml" )
fi

ops_files+=( "--ops-file=./manifests/operations/enable-tls.yml" )

info "Deploying $BOSH_DEPLOYMENT"
bosh deploy \
    --ops-file=./manifests/operations/dev-ops.yml \
    --var=repo_dir="$PWD" \
    --var=os="${stemcell_os}" \
    --vars-file=<(terraform output -state=ci/terraform/terraform.tfstate -json | jq 'to_entries | map({key, "value": .value.value}) | from_entries') \
    "${ops_files[@]}" \
    ./manifests/athens.yml

info "Running tests with an errand"
bosh run-errand --keep-alive athens-test-errand

info "Cleaning up"
# bosh delete-deployment
# bosh clean-up --all

popd > /dev/null

info "Done"