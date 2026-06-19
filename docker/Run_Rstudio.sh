#!/bin/bash

export MOUNT_PATH="/home/user/miseq_output"
export SCRIPT_PATH="./scripts"
export COMPOSE_YAML="./docker/amplymate_v1.0.yaml"

if [ "$(docker compose -f "$COMPOSE_YAML" ps --status running -q "$SERVICE")" ]; then
  docker compose -f "$COMPOSE_YAML" down
fi

docker compose -f $COMPOSE_YAML up -d amplymate

open http://localhost:8787/
