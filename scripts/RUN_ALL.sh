#!/bin/bash
cd "$(dirname "$0")"

MOUNT_PATH="$(pwd)"
SCRIPT_PATH="$(pwd)/scripts"
COMPOSE_YAML="$(pwd)/amplymate_v1.0.yaml"
GENOME_DB="$HOME/db"

export MOUNT_PATH SCRIPT_PATH GENOME_DB

docker compose -f $COMPOSE_YAML run --rm --user "$(id -u):$(id -g)" amplymate bash /_SCRIPTS/01_CUTADAPT.sh
docker compose -f $COMPOSE_YAML run --rm --user "$(id -u):$(id -g)" amplymate bash /_SCRIPTS/02_TRIMMING.sh
docker compose -f $COMPOSE_YAML run --rm --user "$(id -u):$(id -g)" amplymate Rscript /_SCRIPTS/03_FILTERING.R
docker compose -f $COMPOSE_YAML run --rm --user "$(id -u):$(id -g)" amplymate Rscript /_SCRIPTS/04_DENOISING.R
docker compose -f $COMPOSE_YAML run --rm --user "$(id -u):$(id -g)" amplymate Rscript /_SCRIPTS/05_ANNOTATION.R
docker compose -f $COMPOSE_YAML run --rm --user "$(id -u):$(id -g)" amplymate Rscript /_SCRIPTS/06_CLUSTERING_ASV.R

# Write out program/package versions
docker compose -f $COMPOSE_YAML run --rm --user "$(id -u):$(id -g)" amplymate bash -lc '

    {
      printf "%s\n" "$(R --version | head -n 1)"
      printf "cutadapt\t%s\n" "$(cutadapt --version)"
      printf "multiqc\t%s\n" "$(multiqc --version)"
      printf "vsearch\t%s\n" "$(vsearch --version 2>&1 | head -n 1)"
      printf "seqkit\t%s\n" "$(seqkit version 2>&1 | head -n 1)"
      printf "fastqc\t%s\n" "$(fastqc --version 2>&1 | head -n 1)"

      Rscript -e '\''pkgs <- c("dada2","seqinr"); cat(paste(pkgs, sapply(pkgs, \(p) as.character(packageVersion(p))), sep="\t"), sep="\n")'\''
    } > /data/program_versions.tsv
  '
