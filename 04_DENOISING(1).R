
# %% CONFIGS
library(dada2)
library(seqinr)
library(tidyverse)

INPUT=Sys.getenv("QUALITY_CONTROL")
OUTPUT=Sys.getenv("DENOISING")
EVAL <- Sys.getenv("EVAL_SUMMARY")

# %% FUNCTION
library(Rcpp)
Sys.setenv("PKG_LIBS" = "-lz")

Rcpp::sourceCpp(code='
#include <Rcpp.h>
#include <zlib.h>
#include <cstring>
using namespace Rcpp;

// [[Rcpp::export]]
CharacterVector uniq_qual_chars(CharacterVector files) {
  bool seen[256] = {};
  char buf[1048576];

  for (String f : files) {
    gzFile fp = gzopen(std::string(f).c_str(), "rb");

    long long n = 0;
    while (gzgets(fp, buf, sizeof(buf))) {
      n++;
      if (n % 4 == 0) {
        size_t len = strlen(buf);
        while (len && (buf[len-1] == \'\\n\' || buf[len-1] == \'\\r\')) len--;
        for (size_t i = 0; i < len; i++)
          seen[(unsigned char)buf[i]] = true;
      }
    }
    gzclose(fp);
  }

  CharacterVector out;
  for (int i = 0; i < 256; i++)
    if (seen[i]) out.push_back(std::string(1, (char)i));
  return out;
}
')

# %% MAIN
dir.create(OUTPUT)

patterns = c("_fwd_FILT_.*.fastq.gz", "_rev_FILT_.*.fastq.gz")
file_names = map(patterns, ~sort(list.files(INPUT, pattern=.x, full.names = TRUE)) )
file_names = map(file_names, ~.x[!str_detect(.x, "Undetermined")])
qscores = lapply(file_names, function(fs){
    if(length(fs)>0){
        qchar = uniq_qual_chars(fs)
        return(sort(utf8ToInt(paste0(qchars, collapse = "")) - 33))
    }
})

 = lapply(1:2, function(i){
  if(length(file_names[[i]])>0){
    dada2::learnErrors(file_names[[i]],
                       multithread = TRUE, nbases = 1e+09)
  }
})
pdf(paste0(EVAL,"/learnErros_wo_binning.pdf"))
plotErrors(errFR_wo[[1]], nominalQ=TRUE)
if(!is.null(errFR_wo[[2]]))plotErrors(errFR_wo[[2]], nominalQ=TRUE)
dev.off()

errFun = lapply(qscores, \(x){
  if(length(x)>0) dada2::makeBinnedQualErrfun(x)
})
errFR = lapply(1:2, function(i){
  if(length(file_names[[i]])>0){
    dada2::learnErrors(file_names[[i]], errorEstimationFunction = errFun[[i]],
                       multithread = TRUE, nbases = 1e+09)
  }
})
pdf(paste0(EVAL,"/learnErros_w_binning.pdf"))
plotErrors(errFR[[1]], nominalQ=TRUE)
if(!is.null(errFR[[2]]))plotErrors(errFR[[2]], nominalQ=TRUE)
dev.off()

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
