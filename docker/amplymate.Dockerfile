# Versions in programs
ARG R
FROM rocker/rstudio:4.5.3

ARG VSEARCH
ARG CUTADAPT
ARG BIOC
ARG SEQKIT
ARG FASTQC

ARG UID=1000
ARG GID=1000

# Setting environment
ENV DEBIAN_FRONTEND=noninteractive \
    PIPX_HOME=/opt/pipx \
    PIPX_BIN_DIR=/usr/local/bin \
    PATH="$PATH:/root/.local/bin:/home/docker/.local/bin:/usr/local/bin"

# Install programs
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    wget \
    ca-certificates \
    build-essential \
    pkg-config \
    default-jre \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    zlib1g-dev \
    pipx \
    python3-venv \
    perl \
    autoconf \
    automake \
    libtool \
    libcairo2-dev \
    libgit2-dev \
    default-libmysqlclient-dev \
    libpq-dev \
    libsasl2-dev \
    libsqlite3-dev \
    libssh2-1-dev \
    libxtst6 \
    unixodbc-dev \
    libuv1-dev \
    xz-utils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN pipx ensurepath \
    && pipx install cutadapt=="v${CUTADAPT}" \
    && pipx install multiqc

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

RUN R -q -e "install.packages(c('tidyverse','BiocManager','optparse'), repos='https://cloud.r-project.org', Ncpus = parallel::detectCores())"
RUN R -q -e "BiocManager::install( c('dada2','seqinr','Biostrings','ShortRead', 'doParallel'), version='$BIOC')"

RUN wget -O seqkit.tar.gz \
	https://github.com/shenwei356/seqkit/releases/download/v${SEQKIT}/seqkit_linux_amd64.tar.gz \
	&& tar xzf seqkit.tar.gz \
	&& mv seqkit /usr/local/bin/

RUN wget -O fastqc.zip \
	https://www.bioinformatics.babraham.ac.uk/projects/fastqc/fastqc_v${FASTQC}.zip \
	&& unzip fastqc.zip -d /opt \
	&& ln -sf /opt/FastQC/fastqc /usr/local/bin/fastqc \
	&& rm -rf FastQC

RUN wget \
    https://download.opensuse.org/repositories/home:/tange/Debian_10/all/parallel_20260522_all.deb \
    && apt install ./parallel_20260522_all.deb \
    && rm -f parallel_20260522_all.deb
RUN mkdir -p /root/.parallel && \
    touch /root/.parallel/will-cite

# Setting for Rstudio
RUN groupmod -g ${GID} rstudio && \
    usermod -u ${UID} -g ${GID} rstudio
RUN echo "setwd('/data')" >> /home/rstudio/.Rprofile\
    && chown "${UID}:${GID}" /home/rstudio/.Rprofile

# Make directroy to mount
RUN mkdir -p /data /db /data/_SCRIPTS \
    && chmod 775 /data /db /data/_SCRIPTS

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
    } > /data/_SCRIPTS/program_versions.tsv

USER root
