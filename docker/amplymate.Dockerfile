# Build base
FROM rocker/rstudio:4.5.3 AS builder

ARG VSEARCH
ARG BIOC
ARG SEQKIT
ARG FASTQC
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates wget unzip \
    build-essential pkg-config autoconf automake libtool \
    zlib1g-dev libbz2-dev liblzma-dev \
    libcurl4-openssl-dev libssl-dev libxml2-dev \
    libfontconfig1-dev libharfbuzz-dev libfribidi-dev \
    libfreetype6-dev libpng-dev libtiff5-dev libjpeg-dev \
    libcairo2-dev libgit2-dev libsqlite3-dev libssh2-1-dev \
    default-libmysqlclient-dev libpq-dev libsasl2-dev unixodbc-dev \
    && rm -rf /var/lib/apt/lists/*

RUN wget -O vsearch.tar.gz \
    https://github.com/torognes/vsearch/archive/v${VSEARCH}.tar.gz \
    && tar xzf vsearch.tar.gz \
    && cd vsearch-${VSEARCH} \
    && ./autogen.sh \
    && ./configure CFLAGS="-O2" CXXFLAGS="-O2" \
    && make ARFLAGS="cr" \
    && make install \
    && cd ../ \
    && rm -rf vsearch-${VSEARCH} vsearch.tar.gz

RUN R -q -e "install.packages(c('tidyverse','BiocManager','jsonlite'), repos='https://cloud.r-project.org', Ncpus = parallel::detectCores())" \
    && R -q -e "BiocManager::install( c('dada2','seqinr','Biostrings','ShortRead', 'doParallel'), version='$BIOC', Ncpus = parallel::detectCores())"

RUN wget -O seqkit.tar.gz \
	https://github.com/shenwei356/seqkit/releases/download/v${SEQKIT}/seqkit_linux_amd64.tar.gz \
	&& tar xzf seqkit.tar.gz \
	&& mv seqkit /usr/local/bin/ \
    && rm -rf seqkit.tar.gz

RUN wget -O fastqc.zip \
	https://www.bioinformatics.babraham.ac.uk/projects/fastqc/fastqc_v${FASTQC}.zip \
	&& unzip fastqc.zip -d /opt \
	&& chmod 777 /opt/FastQC/fastqc \
	&& rm -rf fastqc.zip

RUN wget -O /opt/parallel.deb \
      https://download.opensuse.org/repositories/home:/tange/Debian_10/all/parallel_20260522_all.deb

#
FROM rocker/rstudio:4.5.3

ARG CUTADAPT
ARG UID=1000
ARG GID=1000

# Setting environment
ENV DEBIAN_FRONTEND=noninteractive \
    PIPX_HOME=/opt/pipx \
    PIPX_BIN_DIR=/usr/local/bin \
    PATH="$PATH:/root/.local/bin:/home/docker/.local/bin:/usr/local/bin"

# Install programs
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates perl \
    default-jre-headless \
    pipx python3-venv \
    libgomp1 \
    zlib1g libbz2-1.0 liblzma5 \
    libcurl4 libssl3 libxml2 \
    libfontconfig1 libharfbuzz0b libfribidi0 libfreetype6 \
    libpng16-16 libtiff6 libjpeg-turbo8 \
    libcairo2 libgit2-1.7 libsqlite3-0 libssh2-1 \
    libpq5 libmariadb3 libsasl2-2 libodbc2 libxtst6 \
    && rm -rf /var/lib/apt/lists/*

RUN pipx ensurepath \
    && pipx install cutadapt=="v${CUTADAPT}" \
    && pipx install multiqc

COPY --from=builder /usr/local/bin/vsearch          /usr/local/bin/vsearch
COPY --from=builder /usr/local/bin/seqkit           /usr/local/bin/seqkit
COPY --from=builder /opt/FastQC                      /opt/FastQC
COPY --from=builder /opt/parallel.deb               /tmp/parallel.deb
COPY --from=builder /usr/local/lib/R/site-library   /usr/local/lib/R/site-library

RUN ln -sf /opt/FastQC/fastqc /usr/local/bin/fastqc

RUN apt-get install -y --no-install-recommends /tmp/parallel.deb \
    && rm -f /tmp/parallel.deb \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /root/.parallel && touch /root/.parallel/will-cite

RUN mkdir -p /root/.parallel && \
    touch /root/.parallel/will-cite

# Setting for Rstudio
RUN groupmod -g ${GID} rstudio \
    && usermod -u ${UID} -g ${GID} rstudio \
    && echo "setwd('/data')" >> /home/rstudio/.Rprofile\
    && chown "${UID}:${GID}" /home/rstudio/.Rprofile

# Make directroy to mount
RUN mkdir -p /data /db /_SCRIPTS \
    && chmod 775 /data /db /_SCRIPTS

WORKDIR /data

# Write out program/package versions
RUN { \
      echo "R	$(R --version | head -n 1)"; \
      echo "cutadapt	$(cutadapt --version)"; \
      echo "multiqc	$(multiqc --version)"; \
      echo "vsearch	$(vsearch --version 2>&1 | head -n 1)"; \
      echo "seqkit	$(seqkit version 2>&1 | head -n 1)"; \
      echo "fastqc	$(fastqc --version 2>&1 | head -n 1)"; \
      Rscript -e 'pkgs <- c("tidyverse", "dada2","seqinr"); cat(paste(pkgs, sapply(pkgs, \(p) as.character(packageVersion(p))), sep="\t"), sep="\n")'; \
    } > /_SCRIPTS/program_versions.tsv

USER root
