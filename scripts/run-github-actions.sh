#!/usr/bin/env bash

set -eu

# credhub is required to generate the certs when tls is enabled
/usr/local/bin/start-bosh \
    -o $PWD/manifests/operations/enable-dns.yml \
    -o /usr/local/bosh-deployment/uaa.yml \
    -o /usr/local/bosh-deployment/credhub.yml

source /tmp/local-bosh/director/env

bosh upload-stemcell \
    --name=bosh-warden-boshlite-ubuntu-xenial-go_agent \
    --version=621.5 \
    --sha1=1a18280689eb6b4a459c7924a16cbf9a7ca76043 \
    https://bosh-core-stemcells.s3-accelerate.amazonaws.com/621.5/bosh-stemcell-621.5-warden-boshlite-ubuntu-xenial-go_agent.tgz
    stemcell_os=ubuntu-xenial

export BOSH_DEPLOYMENT=athens
export BOSH_NON_INTERACTIVE=true

bosh update-runtime-config --name=dns /usr/local/bosh-deployment/runtime-configs/dns.yml

bosh deploy \
    --ops-file=./manifests/operations/dev-ops.yml \
    --ops-file=./manifests/operations/enable-tls.yml \
    --var=repo_dir="$PWD" \
    --var=os="${stemcell_os}" \
    --var=external_ip="10.245.0.3" \
    --vars-store=/tmp/deployment-vars.yml \
    ./manifests/athens.yml

set +e
bosh run-errand --keep-alive athens-test-errand
exit=$?
set -e

bosh ssh -c "sudo grep -r '' /var/vcap/sys/log"

bosh delete-deployment
bosh -n clean-up --all
bosh delete-env "/tmp/local-bosh/director/bosh-director.yml" \
    --vars-store="/tmp/local-bosh/director/creds.yml" \
    --state="/tmp/local-bosh/director/state.json"

echo "$exit"