# Amplicon analysis mate
This repository provides a pipeline for analyzing MiSeq/MiSeq i100 outputs.
**This repo is STILL in DEVELOPMENT**

## Requirements
- [Docker](https://docs.docker.com/engine/install/ubuntu/)

## Usage
### Build Docker image
```
# Change directory to ampymate, then
UID=$(id -u) GID=$(id -g) docker compose -f docker/amplymate_v1.0.yaml build
```
Do not forget to add the UID and GID, as file permissions are restricted without these prefixes.

### Perform Programs
There are three ways to perform programs.

1. Run without entering the Docker container.
For example, to run Cutadapt.
```
docker compose -f $COMPOSE_YAML \
  run --rm --user "$(id -u):$(id -g)" amplymate \
  bash /data/_SCRIPTS/01_CUTADAPT.sh -f ${SCRIPT_PATH}/FWD.fasta -e ${CUTADAPT_eroor}
```

2. Run interactively.
```
docker compose -f $COMPOSE_YAML run --user "$(id -u):$(id -g)" --rm amplymate bash
```

3. Run on Rstudio server.
```
docker compose -f $COMPOSE_YAML up -d amplymate
open http://localhost:8787/
```