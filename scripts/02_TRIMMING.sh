#!/bin/bash
# %% CONFIG
FWD_P=${FWD_P}
REV_P=${REV_P}
REMOVE_SEQ=${REMOVE_SEQ}
ADAPRTOR_MISMATCH=${ADAPRTOR_MISMATCH}

DEMUX_BY_PRIMER="${DEMUX_BY_PRIMER}"
TRIMMING="${TRIMMING}"
EVAL_TRIMMING=${EVAL_TRIMMING}
WORKDIR=${BASE_PATH}/_tmp
THREAD=1
JOBS=$THREADS

REPLACE="DEMUX"
SUFFIX="TRIM"

# %% MAIN
for DIR in ${TRIMMING} ${EVAL_TRIMMING} ${WORKDIR}
do
	if [ -d ${DIR} ]; then
		rm -r ${DIR}
	fi
done
mkdir -p ${TRIMMING} ${EVAL_TRIMMING} $WORKDIR

# Trimming illumina adaptor or forwrad/reverse primer from reverse/foward file
## Function
trimming_seq() {

    r1=$1
    r2=${r1/_fwd_/_rev_}

    out_r1=$(basename "$r1")
    out_r2=$(basename "$r2")

    base=${out_r1%%_fwd*}
	log="${WORKDIR}/${base}.log"

	if [ -f $r2 ];then
		cutadapt \
		  --nextseq-trim 0 -j $THREAD \
		  -e $ADAPRTOR_MISMATCH -n 20 --report minimal --revcomp \
		  -a file:$REV_P -A file:$FWD_P \
		  -b file:${REMOVE_SEQ} -B file:${REMOVE_SEQ} \
		  -o ${TRIMMING}/${out_r1/$REPLACE/$SUFFIX} -p ${TRIMMING}/${out_r2/$REPLACE/$SUFFIX}  \
		  $r1 $r2 \
          > "$log" 2>&1
	else
		cutadapt \
		  --nextseq-trim 0 -j $THREAD \
		  -e $ADAPRTOR_MISMATCH -n 20 --report minimal --revcomp \
		  -a file:$REV_P \
		  -b file:${REMOVE_SEQ} \
		  -o ${TRIMMING}/${out_r1/$REPLACE/$SUFFIX} \
		  $r1  \
          > "$log" 2>&1
	fi
}

export -f trimming_seq
export THREAD WORKDIR
export REPLACE SUFFIX

find "$DEMUX_BY_PRIMER" -maxdepth 1 -name '*_fwd_DEMUX_*.fastq.gz' ! -name '*unmatch*' -print0 | parallel -0 -j $JOBS trimming_seq {}

# Evaluate result
fastqc ${TRIMMING}/*_TRIM*.fastq.gz --quiet -t ${JOBS}
multiqc --outdir  ${EVAL_TRIMMING} --ignore-samples unmatch* ${TRIMMING} --force
seqkit stats -T ${TRIMMING}/*.fastq.gz -o ${EVAL_TRIMMING}/seqkit.tsv

# Logs
first_log=$(find "$WORKDIR" -maxdepth 1 -name "*.log" -print | sort | head -n 1)
{
    head -n 1 "$first_log"
    find "$WORKDIR" -maxdepth 1 -name "*.log" | sort | xargs tail -q -n 1
} > ${EVAL_TRIMMING}/CUTADAPT.log
rm -r ${WORKDIR}
