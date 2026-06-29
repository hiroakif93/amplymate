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
    libcurl4-openssl-dev \
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

RUN R -q -e "install.packages(c('dplyr', 'stringr', 'purrr', 'ggplot2', 'BiocManager','jsonlite', 'doParallel', 'tidyr', "vegan"), repos='https://cloud.r-project.org', Ncpus = parallel::detectCores(), INSTALL_opts = c('--strip','--no-docs','--no-help','--no-demo','--no-html'))" \
    && R -q -e "BiocManager::install( c('dada2','seqinr','Biostrings','ShortRead'), version='$BIOC', Ncpus = parallel::detectCores(), INSTALL_opts = c('--strip','--no-docs','--no-demo','--no-html'))"

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
    zlib1g zlib1g-dev libbz2-1.0 liblzma5 \
    libcurl4 \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

RUN pipx install --pip-args="--no-cache-dir" cutadapt=="${CUTADAPT}" \
    && pipx install --pip-args="--no-cache-dir" multiqc \
    && rm -rf /root/.cache /tmp/* /var/tmp/*

COPY --from=builder /usr/local/bin/vsearch          /usr/local/bin/vsearch
COPY --from=builder /usr/local/bin/seqkit           /usr/local/bin/seqkit
COPY --from=builder /opt/FastQC                      /opt/FastQC
COPY --from=builder /opt/parallel.deb               /tmp/parallel.deb
COPY --from=builder /usr/local/lib/R/site-library   /usr/local/lib/R/site-library

RUN ln -sf /opt/FastQC/fastqc /usr/local/bin/fastqc

RUN apt-get install -y --no-install-recommends /tmp/parallel.deb \
    && rm -f /tmp/parallel.deb \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* \
    && mkdir -p /root/.parallel && touch /root/.parallel/will-cite

# Setting for Rstudio
RUN groupmod -g ${GID} rstudio \
    && usermod -u ${UID} -g ${GID} rstudio \
    && echo "setwd('/data')" >> /home/rstudio/.Rprofile\
    && chown "${UID}:${GID}" /home/rstudio/.Rprofile

# Make directroy to mount
RUN mkdir -p /data /db /_SCRIPTS \
    && chmod 775 /data /db /_SCRIPTS

WORKDIR /data


USER root
