# %% CONFIGS
MIN_LEN <- jsonlite::fromJSON(Sys.getenv("MIN_LEN"))
MAXEE <- jsonlite::fromJSON(Sys.getenv("MAXEE"))
TRUNCLEN <- jsonlite::fromJSON(Sys.getenv("TRUNCLEN"))
TRUNCLEN2 <- jsonlite::fromJSON(Sys.getenv("TRUNCLEN2"))
MINQ <- jsonlite::fromJSON(Sys.getenv("MINQ"))

library(dada2)
library(stringr)

INPUT <- Sys.getenv("TRIMMING")
OUTPUT <- Sys.getenv("QUALITY_CONTROL")
THREADS <- Sys.getenv("THREADS") |> as.integer()
EVAL_FILT <- Sys.getenv("EVAL_FILT")

dir.create(OUTPUT)
dir.create(EVAL_FILT)
## -- Set random seeds (for reproduction)
ran.seed <- 1234
set.seed(ran.seed)

## -- Filtering
patterns <- c("_fwd_TRIM_.*.fastq.gz", "_rev_TRIM_.*.fastq.gz")
file_names <- lapply(patterns, function(pattern) {
  sort(list.files(INPUT, pattern = pattern, full.names = TRUE))
})
sample_names <- basename(file_names[[1]]) |> str_remove("_(fwd|rev)_TRIM.*")

## -- Path to output directory
filtered_file <- lapply(file_names, \(x)str_replace_all(x, INPUT, OUTPUT) |> str_replace_all("_TRIM", "_FILT"))

## -- Filtering process
if (length(file_names[[2]]) == 0) {
  out <- filterAndTrim(
    file_names[[1]], filtered_file[[1]],
    maxN = 0, rm.lowcomplex = 10, matchIDs = TRUE,
    maxEE = MAXEE, minLen = MIN_LEN, truncLen = TRUNCLEN, minQ = MINQ, truncQ = MINQ,
    rm.phix = TRUE, compress = TRUE, multithread = TRUE
  )
} else {
  out <- filterAndTrim(
    file_names[[1]], filtered_file[[1]], file_names[[2]], filtered_file[[2]],
    maxN = 0, rm.lowcomplex = 10, matchIDs = TRUE,
    maxEE = MAXEE, minLen = MIN_LEN, truncLen = c(TRUNCLEN, TRUNCLEN2), minQ = MINQ, truncQ = MINQ,
    rm.phix = TRUE, compress = TRUE, multithread = TRUE
  )
}

system2(
  "fastqc",
  args = c(paste0(OUTPUT, "/*FILT*gz"), "--quiet", "-t", THREADS)
)

system2(
  "multiqc",
  args = c(
    "--outdir", EVAL_FILT, "--clean-up",
    "--ignore-samples", "unmatch*", OUTPUT
  )
)

system2(
  "seqkit",
  args = c(
    "stats", paste0(OUTPUT, "/*FILT*gz"),
    "-T", "-o", paste0(EVAL_FILT, "/seqkit.tsv")
  )
)
