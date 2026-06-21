#!/bin/bash
cd "$(dirname "$0")"

MOUNT_PATH="$(pwd)"
SCRIPT_PATH="$(pwd)/scripts"
COMPOSE_YAML="$(pwd)/amplymate_v1.0.yaml"
GENOME_DB="$HOME/db"

export MOUNT_PATH SCRIPT_PATH GENOME_DB

docker compose -f $COMPOSE_YAML run --rm --user "$(id -u):$(id -g)" amplymate bash /data/_SCRIPTS/01_CUTADAPT.sh
docker compose -f $COMPOSE_YAML run --rm --user "$(id -u):$(id -g)" amplymate bash /data/_SCRIPTS/02_TRIMMING.sh
docker compose -f $COMPOSE_YAML run --rm --user "$(id -u):$(id -g)" amplymate Rscript /data/_SCRIPTS/03_FILTERING.R
docker compose -f $COMPOSE_YAML run --rm --user "$(id -u):$(id -g)" amplymate Rscript /data/_SCRIPTS/04_DENOISING.R
docker compose -f $COMPOSE_YAML run --rm --user "$(id -u):$(id -g)" amplymate Rscript /data/_SCRIPTS/05_ANNOTATION.R
docker compose -f $COMPOSE_YAML run --rm --user "$(id -u):$(id -g)" amplymate Rscript /data/_SCRIPTS/06_CLUSTERING_ASV.R
