COMPOSE_YAML="$HOME/docker/amplymate_v1.0.yaml"

while getopts "y:" opt; do
  case "$opt" in
    y) COMPOSE_YAML="$OPTARG" ;;
  esac
done

if [ ! -f $MOUNT_PATH ]; then
    read -p "Specify path to a yaml file: " MOUNT_PATH
fi

UID=$(id -u) GID=$(id -g) docker compose -f $COMPOSE_YAML build
