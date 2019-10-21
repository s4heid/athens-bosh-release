#!/usr/bin/env bash

set -e

info () { printf "\033[00;34m[$(date +"%r")] $1\033[0m\n"; }

export BOSH_DEPLOYMENT=athens
export BOSH_NON_INTERACTIVE=true

root_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
stemcell_name="${STEMCELL_NAME:-bosh-warden-boshlite-ubuntu-xenial-go_agent}"
stemcell_version="${STEMCELL_VERSION:-456.30}"
stemcell_sha1="${STEMCELL_SHA1:-61791b4d37ee3aacb9db36bb819c1fbcc4785a9e}"
stemcell_os="${STEMCELL_OS:-ubuntu-xenial}"
infra="${INFRA:-lite}"

ops_files=()
if [ "$infra" = "aws" ]; then
    ops_files+=( "--ops-file=./manifests/aws.yml" )
fi

pushd "${root_dir}" > /dev/null

info "Deleting old deployment"
bosh delete-deployment --force

info "Uploading stemcell"
bosh upload-stemcell "https://bosh.io/d/stemcells/${stemcell_name}?v=${stemcell_version}" \
    --name $stemcell_name \
    --sha1 $stemcell_sha1 \
    --version $stemcell_version

info "Deploying $BOSH_DEPLOYMENT"
bosh deploy \
    --ops-file=./manifests/dev.yml \
    --var=os="${stemcell_os}" \
    "${ops_files[@]}" \
    ./manifests/athens.yml

info "Cleaning up"
bosh delete-deployment

popd > /dev/null