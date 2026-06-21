#!/bin/bash
# %% CONFIG
FWD_P="$SCRIPT_PATH/FWD.fasta"
REV_P="$SCRIPT_PATH/REV.fasta"
MISMATCH_rate=${MISMATCH_rate}

while getopts "f:r:e:" opt; do
  case "$opt" in
    f) FWD_P="$OPTARG" ;;
    r) REV_P="$OPTARG" ;;
    e) MISMATCH_rate="$OPTARG" ;;
  esac
done

RAW_FASTQ="${BASE_PATH}/DEMUX"
DEMUX_BY_PRIMER="${DEMUX_BY_PRIMER}"
EVAL_SUMMARY=${EVAL_SUMMARY}
EVAL_DEMUX=${EVAL_DEMUX}
WORKDIR=${BASE_PATH}/_tmp
JOBS=$THREADS

# %% MAIN
for DIR in ${DEMUX_BY_PRIMER} ${EVAL_SUMMARY} ${EVAL_DEMUX} ${WORKDIR}
do
	if [ -d ${DIR} ]; then
		rm -r ${DIR}
	fi
done

mkdir -p ${DEMUX_BY_PRIMER} ${EVAL_SUMMARY} ${EVAL_DEMUX} ${WORKDIR}
SUFFIX_fwd="_fwd_DEMUX_{name}.fastq.gz"
SUFFIX_rev="_rev_DEMUX_{name}.fastq.gz"

# DEMULTIPLEX by primer
## Function
demux_by_primer() {
    r1="$1"
    r2="${r1/_R1_/_R2_}"

    base=$(basename "$r1")
    base=${base%%_S*}

    log="${WORKDIR}/${base}.log"

    if [ -f "$r2" ]; then
        cutadapt \
          --nextseq-trim 0 -j "$THREAD" \
          -e $MISMATCH_rate -n 3 --max-n 0 \
          -g file:${FWD_P} \
          -G file:${REV_P} \
          -o "${DEMUX_BY_PRIMER}/${base}${SUFFIX_fwd}" \
          -p "${DEMUX_BY_PRIMER}/${base}${SUFFIX_rev}" \
          --untrimmed-output "${DEMUX_BY_PRIMER}/unmatched_${base}_FWD.fastq.gz" \
          --untrimmed-paired-output "${DEMUX_BY_PRIMER}/unmatched_${base}_REV.fastq.gz" \
          "$r1" "$r2" \
          > "$log" 2>&1
    else
        cutadapt \
          --nextseq-trim 0 -j 1 \
          -e $MISMATCH_rate -n 2 --max-n 0 --report minimal --revcomp \
          -g file:${FWD_P} \
          -o "${DEMUX_BY_PRIMER}/${base}${SUFFIX_fwd}" \
          --untrimmed-output "${DEMUX_BY_PRIMER}/unmatched_${base}.fastq.gz" \
          "$r1" \
          > "$log" 2>&1
    fi
}

## To pass cluster
export -f demux_by_primer
export FWD_P REV_P
export SUFFIX_fwd SUFFIX_rev

find "$RAW_FASTQ" -maxdepth 1 -name '*_R1_*.fastq.gz' -print0 | parallel -0 -j $JOBS demux_by_primer {}

# Evaluate result
fastqc ${DEMUX_BY_PRIMER}/*.fastq.gz --quiet -t $JOBS
multiqc --outdir ${EVAL_DEMUX} --ignore-samples unmatch* ${DEMUX_BY_PRIMER} --force

seqkit stats -T ${DEMUX_BY_PRIMER}/*.fastq.gz -o ${EVAL_DEMUX}/seqkit.tsv

# Logs
first_log=$(find "$WORKDIR" -maxdepth 1 -name "*.log" -print | sort | head -n 1)
{
    head -n 1 "$first_log"
    find "$WORKDIR" -maxdepth 1 -name "*.log" | sort | xargs tail -q -n 1
} > ${EVAL_DEMUX}/CUTADAPT.log
rm -r ${WORKDIR}
