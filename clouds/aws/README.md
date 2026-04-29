# AWS

AWS-specific assets for building and deploying Penpot in AWS.

## Directory Layout

- [packer/](packer/): `Packer` templates for building the AWS machine image
- [cloudformation/](cloudformation/): `CloudFormation` templates for deploying the image
- [scripts/](scripts/): operational helper scripts for validation, reporting, cleanup, and release helpers
- [docs/](docs/): AWS-specific execution and operational documentation

## Main Files

- [single-node.pkr.hcl](packer/single-node.pkr.hcl): main `Packer` template for the AWS image build
- [penpot-single-node.yaml](cloudformation/penpot-single-node.yaml): main `CloudFormation` template for the current deployment flow
- [validate.sh](scripts/validate.sh): lightweight validation entry point for the AWS assets

## Documentation

- [Execution Guide](docs/execution-guide.md)
- [Cleanup Checklist](docs/cleanup-checklist.md)
- [Commands Cheatsheet](docs/commands-cheatsheet.md)
