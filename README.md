# penpot-cloud-images

Build and deployment assets for Penpot cloud images.

## Overview

This repository contains the image-build, deployment, and shared runtime assets used to package Penpot for cloud environments. The structure is provider-oriented, with shared runtime components kept separate from provider-specific packaging and deployment definitions.

The goal is to reuse the official Penpot self-hosting path instead of creating a custom runtime.

## Repository Layout

- `clouds/`: provider-specific assets
- [clouds/aws/](clouds/aws/): AWS image build, deployment templates, scripts, and documentation
- `clouds/azure/`: reserved for future Azure-specific assets
- `clouds/gcp/`: reserved for future GCP-specific assets
- [shared/](shared/): runtime assets reused across providers, including scripts, templates, and systemd units
