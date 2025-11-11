# Renode Portable Docker

Builds Docker images using the portable Renode binaries, aiming to remain compatible with the official `renode-docker` container interfaces.

This setup supports consistent local builds on both amd64 and arm64 (tested on Apple Silicon) and includes additional dependencies required to run the Robot Framework–based Renode tests inside the container. It avoids the Debian + Mono approach used by the official [`renode-docker`](https://github.com/renode/renode-docker) image, which can fail to build under Rosetta emulation.

## Getting started

Build the image for your host architecture:
```bash
make build
```
Run image test:
```bash
make test-image
```
Optionally pin a specific Renode build:
```bash
RENODE_VERSION=1.16.0+20251108gite785419a6 make build
docker run --rm renode:1.16.0+20251108gite785419a6 renode --version
```


