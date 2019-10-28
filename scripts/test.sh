#!/usr/bin/env bash

set -euo pipefail

info () { printf "\n\033[00;34m[$(date +"%r")] $1\033[0m\n"; }

export BOSH_DEPLOYMENT=athens
export BOSH_NON_INTERACTIVE=true

root_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
stemcell_name="${STEMCELL_NAME:-bosh-warden-boshlite-ubuntu-xenial-go_agent}"
stemcell_version="${STEMCELL_VERSION:-456.30}"
stemcell_sha1="${STEMCELL_SHA1:-61791b4d37ee3aacb9db36bb819c1fbcc4785a9e}"
stemcell_os="${STEMCELL_OS:-ubuntu-xenial}"
terraform_state_dir="ci/terraform.tfstate"

ops_files=()
if [ "$BBL_IAAS" = "aws" ]; then
    ops_files+=( "--ops-file=./manifests/athens-terraform-ops.yml" )
fi

pushd "${root_dir}" > /dev/null

info "Deleting old deployment"
bosh delete-deployment --force

info "Uploading stemcell"
bosh upload-stemcell "https://bosh.io/d/stemcells/${stemcell_name}?v=${stemcell_version}" \
    --name $stemcell_name \
    --sha1 $stemcell_sha1 \
    --version $stemcell_version

info "Uploading cloud config"
bosh update-config \
    --type=cloud \
    --name=athens \
    --vars-file=<(terraform output -state=$terraform_state_dir -json) \
    --var=default_security_group="$( bosh cloud-config | bosh int --path=/networks/name=default/subnets/0/cloud_properties/security_groups/0 - )" \
    ./manifests/cloud-config.yml \

info "Deploying $BOSH_DEPLOYMENT"
bosh deploy \
    --ops-file=./manifests/dev-ops.yml \
    --var=os="${stemcell_os}" \
    --vars-file=<(terraform output -state=ci/terraform.tfstate -json) \
    "${ops_files[@]}" \
    ./manifests/athens.yml

info "Run test application"
go get github.com/s4heid/walkthrough
go clean -modcache

host="$(terraform output -state="$terraform_state_dir" -json | jq -r .external_ip.value)"
export GOPROXY="http://${host}:3000"
export GO111MODULE=on

pushd "$(go env GOPATH)"/src/github.com/s4heid/walkthrough
go run .
popd

disk_version="$(curl -s "http://${host}:3000/catalog" | jq -r '.modules[]|select(.module=="github.com/athens-artifacts/samplelib").version')"
if [ "$disk_version" != "v1.0.0" ]; then
    >&2 echo "app dependencies not found on athens disk"
    exit 1
else
    echo "found $disk_version on athens disk"
fi

info "Cleaning up"
bosh delete-deployment
bosh clean-up --all

popd > /dev/null