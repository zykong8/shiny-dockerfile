FROM ubuntu:20.04

LABEL maintainer "Pengfei Liu & pfliu@aptbiotech.com"

# Mirrors
RUN sed -i 's#http://security.ubuntu.com/ubuntu/#http://mirrors.aliyun.com/ubuntu/#' /etc/apt/sources.list
RUN sed -i 's#http://archive.ubuntu.com/ubuntu/#http://mirrors.aliyun.com/ubuntu/#' /etc/apt/sources.list

## Set a default user. Available via runtime flag `--user docker`
## Add user to 'staff' group, granting them write privileges to /usr/local/lib/R/site.library
## User should also have & own a home directory (for rstudio or linked volumes to work properly).
RUN useradd docker \
    && mkdir /home/docker \
    && chown docker:docker /home/docker \
    && addgroup docker staff

## Configure default locale, see https://github.com/rocker-org/rocker/issues/19
RUN apt-get update \
    && apt-get install -y --no-install-recommends ed less locales vim wget ca-certificates fonts-texgyre \
    && rm -rf /var/lib/apt/lists/*

RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
    && locale-gen en_US.utf8 \
    && /usr/sbin/update-locale LANG=en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8

# Configure Timezone 
ENV TZ=Asia/Shanghai DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -yq tzdata \
	&& ln -fs /usr/share/zoneinfo/${TZ} /etc/localtime \
	&& echo ${TZ} > /etc/timezone \
	&& dpkg-reconfigure --frontend noninteractive tzdata \
	&& rm -rf /var/lib/apt/lists/*

# Basic configure
RUN apt-get update \
    && apt-get install -yq gcc cmake libcurl4-openssl-dev libxml2 libxml2-dev curl \
    && apt-get install -yq libcairo2-dev libssl-dev git g++ sudo gdebi-core pandoc \
	&& apt-get install -yq pandoc-citeproc libcurl4-gnutls-dev libcairo2-dev xtail \
    && apt-get install -yq apt-utils software-properties-common gfortran libxt-dev \
    && apt-get install -yq locales unzip dos2unix sudo build-essential libxml++2.6-dev \
    && apt-get install -yq libncurses5-dev libgdbm-dev libnss3-dev zlib1g-dev \
    && apt-get install -yq libreadline-dev libffi-dev openjdk-8-jdk libfribidi-dev \
    && apt-get install -yq libwww-perl libcurl4-gnutls-dev libexpat1-dev libtiff-dev \
	&& apt-get install -yq libgeos-dev \
    && rm -rf /var/lib/apt/lists/*

# Install python
WORKDIR /
RUN wget https://www.python.org/ftp/python/3.10.5/Python-3.10.5.tgz
RUN tar -zxf Python-3.10.5.tgz
WORKDIR /Python-3.10.5
RUN ./configure
RUN make altinstall
RUN make install
RUN ln -s /usr/local/bin/python3 /usr/local/bin/python
RUN wget https://bootstrap.pypa.io/get-pip.py
RUN python3 get-pip.py
RUN pip3 install --upgrade pip
RUN pip3 install setuptools

# Install R 4.2
RUN apt-get update && apt-get install -y --no-install-recommends software-properties-common dirmngr
RUN wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | tee -a /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc
RUN gpg --show-keys /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc
RUN add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/"
RUN apt-get update && apt-get install -y --no-install-recommends r-base r-base-dev


# Download and install shiny server
RUN wget --no-verbose https://download3.rstudio.org/ubuntu-14.04/x86_64/VERSION -O "version.txt" && \
    VERSION=$(cat version.txt)  && \
    wget --no-verbose "https://download3.rstudio.org/ubuntu-14.04/x86_64/shiny-server-$VERSION-amd64.deb" -O ss-latest.deb && \
    gdebi -n ss-latest.deb && \
    rm -f version.txt ss-latest.deb && \
    . /etc/environment && \
    R -e 'install.packages(c("shiny", "rmarkdown"), repos="http://mirrors.tuna.tsinghua.edu.cn/CRAN")' && \
    cp -R /usr/local/lib/R/site-library/shiny/examples/* /srv/shiny-server/ && \
    chown shiny:shiny /var/lib/shiny-server

EXPOSE 3838

COPY shiny-server.sh /usr/bin/shiny-server.sh

CMD ["/usr/bin/shiny-server.sh"]

# Basic packages
RUN Rscript -e 'install.packages(c("glue", "magrittr", "proxy", "Rcpp"), quiet=TRUE, repos="http://mirrors.tuna.tsinghua.edu.cn/CRAN")'
RUN Rscript -e 'install.packages(c("zip", "plyr", "stringr", "shiny"), quiet=TRUE, repos="http://mirrors.tuna.tsinghua.edu.cn/CRAN")'
RUN Rscript -e 'install.packages(c("stringi", "e1071", "openxlsx", "reshape2", "markdown"), quiet=TRUE, repos="http://mirrors.tuna.tsinghua.edu.cn/CRAN")'
RUN Rscript -e 'install.packages(c("dplyr", "stringr", "car", "ggplot2"), quiet=TRUE, repos="http://mirrors.tuna.tsinghua.edu.cn/CRAN")'

# Bioconductor
RUN Rscript -e 'install.packages(c("BiocManager", "devtools"), repos="http://mirrors.tuna.tsinghua.edu.cn/CRAN")'
RUN Rscript -e 'options(BioC_mirror="https://mirrors.tuna.tsinghua.edu.cn/bioconductor");BiocManager::install(c("impute"), update=FALSE)'

WORKDIR /home
