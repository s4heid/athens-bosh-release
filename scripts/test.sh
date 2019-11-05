#!/usr/bin/env bash

set -euo pipefail

info () { printf "\n\033[00;34m[$(date +"%r")] $1\033[0m\n"; }

export BOSH_DEPLOYMENT=athens
export BOSH_NON_INTERACTIVE=true
export BOSH_BINARY_PATH=${BOSH_BINARY_PATH:-/usr/local/bin/bosh}

root_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

stemcell_name="${STEMCELL_NAME:-bosh-warden-boshlite-ubuntu-xenial-go_agent}"
stemcell_version="${STEMCELL_VERSION:-456.30}"
stemcell_sha1="${STEMCELL_SHA1:-61791b4d37ee3aacb9db36bb819c1fbcc4785a9e}"
stemcell_os="${STEMCELL_OS:-ubuntu-xenial}"

pushd "${root_dir}" > /dev/null

info "Deleting old deployment"
bosh delete-deployment --force

info "Uploading stemcell"
bosh upload-stemcell "https://bosh.io/d/stemcells/${stemcell_name}?v=${stemcell_version}" \
    --name $stemcell_name \
    --sha1 $stemcell_sha1 \
    --version $stemcell_version

ops_files=()
if [ "$BBL_IAAS" = "aws" ]; then
    info "Uploading cloud config"

    bosh update-config \
        --type=cloud \
        --name=athens \
        --vars-file=<(terraform output -state=ci/terraform.tfstate -json) \
        --var=default_security_group="$( bosh cloud-config | bosh int --path=/networks/name=default/subnets/0/cloud_properties/security_groups/0 - )" \
        ./manifests/cloud-config.yml

    ops_files+=( "--ops-file=./manifests/operations/aws-terraform-ops.yml" )
fi

info "Deploying $BOSH_DEPLOYMENT"
bosh deploy \
    --ops-file=./manifests/operations/dev-ops.yml \
    --var=repo_dir="$PWD" \
    --var=os="${stemcell_os}" \
    --vars-file=<(terraform output -state=ci/terraform.tfstate -json) \
    "${ops_files[@]}" \
    ./manifests/athens.yml

info "Running tests with an errand"
bosh run-errand --keep-alive athens-test-errand

info "Cleaning up"
bosh delete-deployment
bosh clean-up --all

popd > /dev/null

info "Done"