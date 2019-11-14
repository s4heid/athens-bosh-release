[![Actions Status](https://github.com/s4heid/athens-bosh-release/workflows/build%20status/badge.svg)](https://github.com/s4heid/athens-bosh-release/actions)

# athens-bosh-release

This BOSH release provides jobs for running the [Athens](https://docs.gomods.io) project in a BOSH environment.


## Architecture

![Athens Architecture](./docs/athens.png)


## Usage

Upload the athens release from the command line with the bosh-cli:

```sh
$ bosh upload-release --name="athens" --version="latest" \
    "git+https://github.com/s4heid/athens-bosh-release"
```

Or reference it in the `releases` section of the deployment manifest:

```yaml
releases:
- name: athens
  version: latest
  url: git+https://github.com/s4heid/athens-bosh-release
```

Add the athens job to an instance group in the deployment manifest

```yaml
instance_groups:
- name: athens
  persistent_disk: 1024
  jobs:
  - name: athens
    release: athens
    properties:
      storage_type: disk
```

The above example configures the persistent disk as storage provider.


## Getting Started

The following section explains how to set up different environments for deploying the athens-bosh-release and running the integration tests.

### bosh-bootloader (aws)

Deploying a bosh with [bosh-bootloader](https://github.com/cloudfoundry/bosh-bootloader) (bbl) is one possibility to get started. Assuming you have already installed a bosh on AWS as described in [this guide](https://github.com/cloudfoundry/bosh-bootloader/blob/master/docs/getting-started-aws.md), you need to set up a few additional things in the infrastructure. This can be achieved by running

```sh
$ cp ci/terraform/terraform.tfvars{.template,}
```

inside the athens-release root directory and filling in the missing parameters. Thereafter, execute the following script to create the missing infrastructure components:

```sh
$ AWS_ACCESS_KEY_ID="..." AWS_SECRET_ACCESS_KEY="..." ./scripts/tf-apply.sh
```

The script will prompt you to log in to your lastpass account, as it will sync the terraform state with a lastpass secret note.


## Development

Deploy an athens server in your bosh environment and run the integration tests by executing

```sh
$ ./scripts/test.sh
```


## License

[Apache License, Version 2.0](./LICENSE)