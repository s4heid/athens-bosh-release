#!/usr/bin/env bash

set -eux

. /usr/local/bin/start-bosh -o $PWD/manifests/operations/enable-dns.yml

source /tmp/local-bosh/director/env

bosh upload-stemcell \
    --name=bosh-warden-boshlite-ubuntu-xenial-go_agent \
    --version=621.71 \
    --sha1=6190d7f100f9d48fe425c2d69ba93d7137e6bc19 \
    https://bosh-core-stemcells.s3-accelerate.amazonaws.com/621.71/bosh-stemcell-621.71-warden-boshlite-ubuntu-xenial-go_agent.tgz

export BOSH_DEPLOYMENT=athens
export BOSH_NON_INTERACTIVE=true

bosh update-runtime-config --name=dns \
    <(bosh int /usr/local/bosh-deployment/runtime-configs/dns.yml --vars-store=/tmp/deployment-vars.yml)

bosh deploy \
    --ops-file=./manifests/operations/dev-ops.yml \
    --var=repo_dir="$PWD" \
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