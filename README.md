# Amplicon analysis mate
This repository provide a pipeline analysing Miseq/Miseq i100 outputs.
**This repo is STILL in DEVELOPMENT**

## Requirements
- [Docker](https://docs.docker.com/engine/install/ubuntu/)

## Usage
### Build Docker image
```
# Change directory to ampymate, then
UID=$(id -u) GID=$(id -g) docker compose -f $COMPOSE_YAML build
```

###　Perform programs
There are three ways to perform programs.

1. Run w/o entering to docker conteiner.
e.g. Run Cutadapt.
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
