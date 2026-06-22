# %% Configs

REF_PATH="/db"
REFERENCE = jsonlite::fromJSON(Sys.getenv("REF_DB"))[[1]]
REFERENCE_ADD_SP="/db/silva_v138.2_assignSpecies.fa.gz"

# %% MAIN
library(dada2)
library(seqinr)
library(stringr)
library(dplyr)

INPUT=Sys.getenv("DENOISING")
OUTPUT=Sys.getenv("ANNOTATION")

dir.create(OUTPUT)

seqtab = readRDS( sprintf("%s/seqtab_rmChimera.rds",INPUT))
cols = colnames(seqtab)
seqfasta = read.fasta(sprintf("%s/nonchim_seq.fasta",INPUT))

seqlist <- sapply(seqfasta, paste, collapse="")
taxa <- assignTaxonomy(seqlist, paste0(REF_PATH, "/",REFERENCE), multithread=TRUE)
if(str_detect(REFERENCE, "silva") & !all(colnames(taxa)=="Species")) taxa <- addSpecies(taxa, REFERENCE_ADD_SP)

taxa.print <- cbind(ASV=names(seqlist),taxa)  # Removing sequence rownames for display only

if( max( sapply(strsplit(taxa.print[,"Kingdom"], "k__"), length), na.rm=TRUE ) > 1){
  taxa.print[,"Kingdom"] <- sapply(strsplit(taxa.print[,"Kingdom"], "k__"),  "[" ,2)
}

taxa.print[,"Phylum"] <- gsub("p__", "", taxa.print[,"Phylum"])
taxa.print[,"Class"] <- gsub("c__", "", taxa.print[,"Class"])
taxa.print[,"Order"] <- gsub("o__", "", taxa.print[,"Order"])
taxa.print[,"Family"] <- gsub("f__", "", taxa.print[,"Family"])
taxa.print[,"Genus"] <- gsub("g__", "", taxa.print[,"Genus"])
taxa.print[,"Species"] <- gsub("s__", "", taxa.print[,"Species"])

taxa.print[is.na(taxa.print)] <- "Unidentified"
taxa.print <- gsub("unidentified", "Unidentified", taxa.print)
taxa.print = cbind(taxa.print, seq=rownames(taxa.print))
rownames(taxa.print) = NULL

taxa_filterd = taxa.print|>
  as.data.frame() |>
  filter(
    Phylum!="Unidentified",
    Order!="Chloroplast", Family!="Mitochondria"
  )

saveRDS(taxa.print, sprintf("%s/taxonomy_list.rds", OUTPUT))
write.csv(taxa.print, sprintf("%s/taxonomy_list.csv", OUTPUT), row.names = FALSE)
saveRDS(taxa_filterd, sprintf("%s/taxonomy_list_filt.rds", OUTPUT))

id = pull(taxa_filterd, ASV)
saveRDS(seqtab[,id], sprintf("%s/seqtab_filt.rds", OUTPUT))
write.fasta(taxa_filterd$seq, taxa_filterd$ASV,  sprintf("%s/target_seq.fasta", OUTPUT))
