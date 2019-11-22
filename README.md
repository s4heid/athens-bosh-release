[![Actions Status](https://github.com/s4heid/athens-bosh-release/workflows/build%20status/badge.svg)](https://github.com/s4heid/athens-bosh-release/actions)

# athens-bosh-release

This BOSH release provides jobs for running the [Athens](https://docs.gomods.io) project in a BOSH environment.


## Getting Started

The following section explains how to set up different environments for deploying the athens-bosh-release and running the integration tests.

### bosh-bootloader (aws)

Deploying a bosh with [bosh-bootloader](https://github.com/cloudfoundry/bosh-bootloader) (bbl) is another possibility to get started. Assuming you have already installed a bosh on AWS as described in [this guide](https://github.com/cloudfoundry/bosh-bootloader/blob/master/docs/getting-started-aws.md), you need to set up a few additional things in the infrastructure. This can be achieved by running

```sh
$ cp ci/terraform/terraform.tfvars{.template,}
```

inside the athens-release root directory and filling in the missing parameters. Thereafter, execute the following script to create the required infrastructure components:

```sh
$ AWS_ACCESS_KEY_ID="..." AWS_SECRET_ACCESS_KEY="..." ./scripts/tf-apply.sh
```

The script will prompt you to log in to your lastpass account, as it will sync the terraform state with a lastpass secret note.

### bosh-lite

If it is sufficient to run the athens server locally (e.g., for testing or development purposes) you might want to use bosh-lite. This is probably the easiest way to spin up a bosh environment and is explained step by step in the [bosh docs](https://bosh.io/docs/bosh-lite).


## Development

After [setting up your bosh environment](#getting-started), deploy an athens server and run the integration tests by executing

```sh
$ ./scripts/test.sh
```


## License

[Apache License, Version 2.0](./LICENSE)