# Penpot AWS Marketplace Single-Node Scope

## Goal

Define a realistic `Phase 1` for publishing Penpot on AWS Marketplace in a way that can be scoped, prototyped, and reviewed within `2 weeks`.

The recommended initial direction is:

- `Distribution model`: `AMI + CloudFormation`
- `Runtime model`: Penpot official `docker compose` deployment on a single EC2 instance

## Why This Scope

This scope is based on the current Penpot packaging that already exists:

- Official self-hosting path in Penpot is based on `docker compose`
- Official Kubernetes path already exists in `penpot-helm`
- Reusing the official compose path is lower risk than creating a custom installation model for AWS Marketplace

Relevant source artifacts:

- `penpot/penpot`: `docker/images/docker-compose.yaml`
- `penpot/penpot-helm`: `charts/penpot/values.yaml`

## Phase 1 Deployment Shape

### Topology

- `1 EC2 instance`
- `1 CloudFormation template`
- Penpot services started with `docker compose`
- No Kubernetes
- No HA
- No autoscaling

### Core Services from the Official Compose Setup

- `penpot-frontend`
- `penpot-backend`
- `penpot-exporter`
- `penpot-postgres`
- `penpot-valkey`

### Persistence

Initial recommendation:

- PostgreSQL persisted on local Docker volume
- Penpot assets persisted on local Docker volume

This is the fastest path because it matches the official compose deployment.

### Network Exposure

Initial recommendation:

- expose Penpot through the frontend on port `9001`
- add a simple reverse proxy path later if needed for HTTPS/domain integration

For Marketplace prototyping, the first milestone should be a working instance, not a polished ingress story.

## Explicit Non-Goals for Phase 1

- EKS support
- Helm packaging for Marketplace
- Multi-node architecture
- High availability
- Managed database redesign
- S3 object storage by default
- Full production hardening
- Enterprise deployment patterns

## Decisions To Close This Week

These decisions should not stay open for long:

1. `AMI + CloudFormation` is the chosen `Phase 1` distribution model.
2. Penpot installation will be based on the official `docker compose` deployment.
3. `Phase 1` topology is `single-node`.
4. PostgreSQL stays local in the initial prototype.
5. Assets stay on local filesystem in the initial prototype.
6. HTTPS and advanced proxying are not blockers for the first technical spike.

## Technical Questions We Still Need To Resolve

### AMI Build Strategy

- What gets baked into the AMI:
  - Docker engine
  - Docker Compose plugin
  - base system packages
  - Penpot compose file
  - helper scripts and systemd units
- What stays configurable at launch time:
  - Penpot version
  - public URI
  - SMTP settings
  - secret key

### CloudFormation Contract

Likely initial parameters:

- `InstanceType`
- `KeyPairName`
- `VpcId`
- `SubnetId`
- `SecurityGroupId` or generated security group
- `PenpotVersion`
- `PenpotPublicUri`
- `PenpotSecretKey`

Optional later:

- SMTP settings
- EBS size
- domain/TLS inputs

### Lifecycle

- How will updates work:
  - immutable AMI rebuild
  - or runtime image pull on boot
- How will the stack start:
  - user data script
  - systemd service
  - both

## Proposed Deliverables for the Next 2 Weeks

### Week 1

- Finalize `Phase 1` scope and assumptions
- Define EC2-based architecture
- Decide AMI build flow
- Draft CloudFormation template inputs and outputs
- Produce first AMI prototype

### Week 2

- Make the EC2 deployment reproducible
- Add bootstrapping and service startup
- Validate a clean-stack deployment
- Document install, operations, and known limitations
- Produce Marketplace gap analysis

## Immediate Next Steps

1. Extract a minimal production-oriented version of the official `docker-compose.yaml`.
2. Decide which config values must be runtime parameters and which can be baked in.
3. Define the files this repo should own:
   - packer template
   - provisioning scripts
   - systemd unit
   - CloudFormation template
4. Run a first local architecture review before building the AMI.

## Initial Recommendation

Treat `Phase 1` as:

- a distribution and packaging exercise
- based on existing Penpot self-hosting artifacts
- with a narrow operational envelope

Do not treat `Phase 1` as a complete AWS reference architecture.
