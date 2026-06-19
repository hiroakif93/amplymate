# Amplicon analysis mate
This repository provide a pipeline analysing Miseq/Miseq i100 outputs.

## Requirements
- [Docker](https://docs.docker.com/engine/install/ubuntu/)

## Usage
### Build Docker image
```
# Change directory to ampymate, then
UID=$(id -u) GID=$(id -g) docker compose -f $COMPOSE_YAML build
```

###
