#!/bin/bash

MOUNT_PATH="/home/user/miseq_output"
SCRIPT_PATH="./scripts"
COMPOSE_YAML="./docker/amplymate_v1.0.yaml"

UID=$(id -u) GID=$(id -g) docker compose -f $COMPOSE_YAML run --rm amplymate bash
