library(ggplot2)
library(dplyr)
library(stringr)
library(purrr)
library(tidyr)

output="EVAL/DASHBORD"
dir.create(output)

EVAL_RAW <- paste0(Sys.getenv("EVAL_SUMMARY"), "/RAW_FASTA")
EVAL_DEMUX <- Sys.getenv("EVAL_DEMUX")
EVAL_TRIM <- Sys.getenv("EVAL_TRIMMING")
EVAL_FILT <- Sys.getenv("EVAL_FILT")

seqtab_before_rmchim = paste0(Sys.getenv("DENOISING"), "/stall_no_rmchimera.rds") |>readRDS()
seqtab_after_rmchim = paste0(Sys.getenv("DENOISING"), "/seqtab_rmChimera.rds") |>readRDS()
seqtab_target = paste0(Sys.getenv("CLUSTERING"), "/seqtab_filt.rds") |>readRDS()

seqtab = data.frame(
  file=rownames(seqtab_before_rmchim)|>basename()|>str_remove("(_S|_fwd_).*"),
  DENOIZINIG=rowSums(seqtab_before_rmchim),
  "REMOVE CHIMERA"=rowSums(seqtab_after_rmchim),
  TARGET=rowSums(seqtab_target)
)

seqkit_list = lapply(c(EVAL_RAW, EVAL_DEMUX, EVAL_TRIM, EVAL_FILT), function(x){
    paste0(x, "/seqkit.tsv")|>
      read.table(sep="\t", header=TRUE)|>
      mutate(
        file = basename(file)|>str_remove("(_S|_fwd_).*")
      )|>
      select(file, num_seqs)
  })|>
  setNames(c("RAW", "DEMUX", "TRIM", "FILT"))|>
  imap(\(x, nm){
    x|>
      rename_with(\(col)(nm), .cols=all_of("num_seqs"))
  })|>
    reduce(left_join, by="file")|>
    left_join(seqtab, by="file")

seqkit_rate=seqkit_list[,-2]
colnames(seqkit_rate)[-1] = sprintf("%s to %s",colnames(seqkit_list)[-c(1, ncol(seqkit_list))], colnames(seqkit_rate)[-1])
seqkit_rate[,-1] = sapply(3:ncol(seqkit_list), \(x)seqkit_list[,x]/seqkit_list[,x-1] )
seqkit_rate$`RAW to LAST` = seqkit_list[,ncol(seqkit_list)]/seqkit_list[,2] 

write.csv(seqkit_list, paste0(output, "/num_read_by_step.csv"), row.names = FALSE)
write.csv(seqkit_rate, paste0(output, "/survival_rate_by_step.csv"), row.names = FALSE)

rename_dict = c("RAW"="RAW", DEMUX="DEMUX", TRIM="TRIM", FILT="FILT", 
                DENOIZINIG="DENOIZINIG", REMOVE.CHIMERA="REMOVE\nCHIMERA", TARGET="TARGET")
g1={pivot_longer(seqkit_list, cols=-file, values_to = "Number of reads")|>
  #separate(name, "_seqs_", into=c("num", "step"))|>
  mutate(
    Step=str_remove(name, "num_seqs_"),
    Step = rename_dict[Step]|>
      factor(levels=c("RAW", "DEMUX", "TRIM", "FILT", "DENOIZINIG", "REMOVE\nCHIMERA", "TARGET"))
  )|>
  ggplot(aes(x=Step, y=`Number of reads`+1))+
  geom_line(aes(group=file), color="grey80")+
  geom_hline(yintercept = 2000, linetype=2)+
  geom_point(position = position_jitterdodge(dodge.width = 0.3), size=0.5)+
  geom_boxplot(alpha=0.5, outliers = FALSE, color="royalblue4", fill="aliceblue")+
  scale_y_log10(breaks=c(100,2000, 10000, 50000))
  }

g1|>
  ggsave(filename="EVAL/Num_Reads.pdf", w=6, h=6)


df = seqkit_rate|>
  arrange(`RAW to LAST`)

{
  sink(paste0(output, "/Low_quality_samples.txt"))
  cat("Samples with few remaining reads.\n\nRead loss rate at each step;\n")
  print(head(df, n=10))
  
  lower = seqkit_list|>
    filter(TARGET<2000)|>
    arrange(file)
  
  cat(sprintf("\n%s samples have under 2000 reads\ne.g.\n", nrow(lower)))
  pull(lower, file)|>head(n=20)|>cat()

  sink()
}


