
MOUNT_PATH="/home/user/miseq_output"
SCRIPT_PATH="./scripts"
COMPOSE_YAML="./docker/amplymate_v1.0.yaml"

CUTADAPT_eroor="0.2"

while getopts "m:s:y:c:" opt; do
  case "$opt" in
    m) MOUNT_PATH="$OPTARG" ;;
    s) SCRIPT_PATH="$OPTARG" ;;
    y) COMPOSE_YAML="$OPTARG" ;;
    c) CUTADAPT_eroor="$OPTARG" ;;
  esac
done

if [ ! -d $MOUNT_PATH ]; then
    read -p "Specify path to mount on docker: " MOUNT_PATH
fi

if [ ! -d $SCRIPT_PATH ]; then
    read -p "Specify path to directory containg scripts: " SCRIPT_PATH
fi

if [ ! -f $SCRIPT_PATH ]; then
    read -p "Specify path to docker compose file (.yaml): " COMPOSE_YAML
fi

UID=$(id -u)
GID=$(id -g)

docker compose -f $COMPOSE_YAML run --rm amplymate bash /data/_SCRIPTS/01_CUTADAPT.sh -f ${SCRIPT_PATH}/FWD.fasta -e ${CUTADAPT_eroor}
docker compose -f $COMPOSE_YAML run --rm amplymate bash /data/_SCRIPTS/02_TRIMMING.sh  -f ${SCRIPT_PATH}/FWD.fasta -e ${CUTADAPT_eroor}
docker compose -f $COMPOSE_YAML run --rm amplymate Rscript /data/_SCRIPTS/03_FILTERING.R
docker compose -f $COMPOSE_YAML run --rm amplymate Rscript /data/_SCRIPTS/04_DENOISING.R
docker compose -f $COMPOSE_YAML run --rm amplymate Rscript /data/_SCRIPTS/05_ANNOTATION.R
docker compose -f $COMPOSE_YAML run --rm amplymate Rscript /data/_SCRIPTS/06_CLUSTERING_ASV.R
