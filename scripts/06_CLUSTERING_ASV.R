MIN_th <- 0.96
MAX_th <- 1.00
BY <- 0.02
CLUSTER_TYPE <- "--cluster_size"
target_taxa <- jsonlite::fromJSON(Sys.getenv("TARGET_TAXA"))[[1]]

library(seqinr)
library(purrr)
library(dplyr)

DENOIZING <- Sys.getenv("DENOISING")
ANNOTATION <- Sys.getenv("ANNOTATION")
OUTPUT <- Sys.getenv("CLUSTERING") # "$CLUSTERING"

seqtab <- readRDS(sprintf("%s/seqtab_rmChimera.rds", DENOIZING))
taxa_table <- readRDS(sprintf("%s/taxonomy_list.rds", ANNOTATION))
fasta <- read.fasta(sprintf("%s/nonchim_seq.fasta", DENOIZING))

# %% sMAIN
dir.create(OUTPUT)

## VSEARCH

### Add abundance info to all fasta
total_read_in_asv <- colSums(seqtab)
if (all(names(total_read_in_asv) == names(fasta))) names(fasta) <- sprintf("%s;size=%s", names(fasta), total_read_in_asv)
write.fasta(fasta, names(fasta), sprintf("%s/nonchim_seq_w_size.fasta", OUTPUT))

for (id in seq(MIN_th, MAX_th, BY)) {
  system2(
    "vsearch",
    args = c(
      CLUSTER_TYPE, sprintf("%s/nonchim_seq_w_size.fasta", OUTPUT),
      "--id", id, "--mothur_shared_out", sprintf("%s/ASV_OTU_corestab_%s.txt", OUTPUT, id),
      "--centroids", sprintf("%s/OTUseq_%s.fasta", OUTPUT, id),
      "--msaout", sprintf("%s/seqAlign_%s.fasta", OUTPUT, id)
    )
  )
}

## MERGING
merge_list <- c()
for (id in seq(MIN_th, MAX_th, BY)) {
  asv_otu_tab <- read.table(sprintf("%s/ASV_OTU_corestab_%s.txt", OUTPUT, id), header = TRUE)

  ### make table
  num_asv_inotu <- colSums(asv_otu_tab[, -c(1:3)] > 0)
  otu_col <- map2(names(num_asv_inotu), num_asv_inotu, ~ rep(.x, .y)) |> unlist()

  asv <- asv_otu_tab[, "Group"]
  asv_id <- apply(asv_otu_tab[, -c(1:3)], 2, \(x)which(x > 0))
  asv_col <- sapply(asv_id, \(x)asv[x]) |> unlist()

  id_label <- gsub("\\.", "", as.character(id))
  tmp <- tibble(ASV = asv_col, !!paste0("OTU_", id_label) := otu_col)

  merge_list[[as.character(id)]] <- tmp
}

merged_table <- reduce(merge_list, full_join, by = "ASV") |>
  arrange(ASV)

taxa_table <- merged_table |>
  left_join(taxa_table |> as.data.frame(), by = "ASV")

taxa_table_filt <- taxa_table |>
  filter(
    Kingdom %in% target_taxa,
    Phylum != "Unidentified",
    Order != "Chloroplast", Family != "Mitochondria"
  )
saveRDS(taxa_table, sprintf("%s/taxonomy_list.rds", OUTPUT))
write.csv(taxa_table, sprintf("%s/taxonomy_list.csv", OUTPUT), row.names = FALSE)
saveRDS(taxa_table_filt, sprintf("%s/taxonomy_list_filt.rds", OUTPUT))

id <- as.character(taxa_table_filt$ASV)
saveRDS(seqtab[, id], sprintf("%s/seqtab_filt.rds", OUTPUT))
