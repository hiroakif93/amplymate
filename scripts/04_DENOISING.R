
# %% CONFIGS
library(dada2)
library(seqinr)
library(purrr)
library(dplyr)
library(stringr)

INPUT=Sys.getenv("QUALITY_CONTROL")
OUTPUT=Sys.getenv("DENOISING")

# %% MAIN
dir.create(OUTPUT)

patterns = c("_fwd_FILT_.*.fastq.gz", "_rev_FILT_.*.fastq.gz")
file_names = map(patterns, ~sort(list.files(INPUT, pattern=.x, full.names = TRUE)) )
file_names = map(file_names, ~.x[!str_detect(.x, "Undetermined")])

errFR_wo = lapply(1:2, function(i){
  if(length(file_names[[i]])>0){
    dada2::learnErrors(file_names[[i]],
                       multithread = TRUE, nbases = 1e+09)
  } 
}) 
plotErrors(errFR_wo[[1]], nominalQ=TRUE)

errFun = lapply(1:2, \(x){
  if(length(x)>0){
    dada2::makeBinnedQualErrfun(c(23, 38))
  } 
}) 

errFR = lapply(1:2, function(i){
  if(length(file_names[[i]])>0){
    dada2::learnErrors(file_names[[i]], errorEstimationFunction = errFun[[i]],
                       multithread = TRUE, nbases = 1e+09)
  } 
}) 
plotErrors(errFR[[1]], nominalQ=TRUE)

# %% dada
derepFR = lapply(file_names, \(x){
  if(length(x)>0)dada2::derepFastq(x)
}) 

dadaFRs = sapply(1:2,  \(x){
  if(!is.null(derepFR[[x]])) dada(derepFR[[x]], err=errFR[[x]], multithread=TRUE)
})


if( any(sapply(dadaFRs, is.null)) ){
  st.all <- makeSequenceTable(dadaFRs[[1]])
}else{
  mergers <- mergePairs(dadaFRs[[1]], file_names[[1]], dadaFRs[[2]], file_names[[2]], verbose=TRUE)
  st.all <- makeSequenceTable(mergers)  
}

seqtab.nochim <- removeBimeraDenovo(st.all, method="consensus", multithread=TRUE, verbose=TRUE)
rownames(seqtab.nochim) = sub("_S.*$", "", rownames(seqtab.nochim))

asv_id = paste0('X_', formatC(1:ncol(seqtab.nochim), width = nchar(ncol(seqtab.nochim)), flag = "0"))
seq.mat <- cbind(colnames(seqtab.nochim),asv_id) 
colnames(seqtab.nochim) = asv_id

saveRDS(st.all, sprintf('%s/stall_no_rmchimera.rds', OUTPUT))
saveRDS(seqtab.nochim, sprintf('%s/seqtab_rmChimera.rds', OUTPUT))
write.fasta(as.list(seq.mat[,1]), seq.mat[,2], sprintf("%s/nonchim_seq.fasta", OUTPUT) )
