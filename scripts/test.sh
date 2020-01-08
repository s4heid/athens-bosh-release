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

pushd "${root_dir}" > /dev/null

info "Deleting old deployment"
bosh delete-deployment --force

info "Uploading stemcell"
bosh upload-stemcell "https://bosh.io/d/stemcells/${stemcell_name}?v=${stemcell_version}" \
    --name $stemcell_name \
    --sha1 $stemcell_sha1 \
    --version $stemcell_version

deploy_files=()
deploy_vars=$(mktemp -d /tmp/aws-vars.XXXXXX); trap 'echo "Deleting $deploy_vars" 1>&2; rm -rf $deploy_vars' 0 2 3 15
if [[ $stemcell_name == *"aws"* ]]; then
    terraform output -state=ci/terraform/terraform.tfstate -json \
        | jq 'to_entries | map({key, "value": .value.value}) | from_entries' \
        > $deploy_vars/raw
    default_group="$( bosh cloud-config | bosh int --path=/networks/name=default/subnets/0/cloud_properties/security_groups/0 - )"
    jq -r --arg dg $default_group '.athens_security_groups = [.athens_security_group, $dg]' <$deploy_vars/raw >$deploy_vars/filled

    info "Uploading cloud config"
    bosh update-config \
        --type=cloud \
        --name=athens \
        --vars-file=<(cat ${deploy_vars}/filled) \
        ./manifests/cloud-config.yml

    deploy_files+=( "--ops-file=./manifests/operations/aws-terraform-ops.yml" )
else
    # bosh lite
    echo "{\"external_ip\": \"10.244.0.2\"}" > ${deploy_vars}/filled
fi

info "Deploying $BOSH_DEPLOYMENT"
bosh deploy \
    --ops-file=./manifests/operations/dev-ops.yml \
    --ops-file=./manifests/operations/with-tls.yml \
    --ops-file=./manifests/operations/with-persistent-disk.yml \
    --var=repo_dir="$PWD" \
    --var=disk_size=1024 \
    --vars-file=<(cat "${deploy_vars}"/filled) \
    "${deploy_files[@]}" \
    ./manifests/athens.yml

info "Running tests with an errand"
bosh run-errand --keep-alive athens-test-errand

info "Cleaning up"
bosh delete-deployment
bosh clean-up --all

popd > /dev/null

info "Done"
