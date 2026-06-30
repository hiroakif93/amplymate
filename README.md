# Amplicon analysis mate
This repository provides a pipeline for analyzing MiSeq/MiSeq i100 outputs.
**This repo is STILL in DEVELOPMENT**

## Requirements
- [Docker](https://docs.docker.com/engine/install/ubuntu/)

## Usage
### Build Docker image
Change the program versions using arguments in amplymate.  
Dockerfile, especially because the version of parallel may change.  
Then,
```
# Open terminal on ampymate, then
UID=$(id -u) GID=$(id -g) docker compose -f docker/amplymate_v1.0.yaml build
```
Do not forget to add the UID and GID, as file permissions are restricted without these prefixes.

### Perform Programs
There are three ways to perform programs.

1. Run without entering the Docker container.
  Copy `amplymate_v1.0.yaml` from the Docker folder to the MiSeq output folder, which often starts with the sequence date.
  e.g. `cp "amplymate_v1.0.yaml" to "20260101_SHxxxx..."`

  Specify a folder to mount on Docker. The path requires the full path, not a relative one.
  ```
  MOUNT_PATH="$(pwd)"
  SCRIPT_PATH="$(pwd)/scripts"
  COMPOSE_YAML="$(pwd)/amplymate_v1.0.yaml"
  GENOME_DB="$HOME/db"
  ```

  Export the above variables to the system and run Docker.
  ```
  export MOUNT_PATH SCRIPT_PATH GENOME_DB
  
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
