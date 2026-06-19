#!/bin/bash

export MOUNT_PATH="/home/user/miseq_output"
export SCRIPT_PATH="./scripts"
COMPOSE_YAML="./docker/amplymate_v1.0.yaml"

docker compose -f $COMPOSE_YAML run --user "$(id -u):$(id -g)" --rm amplymate bash
