# ---------------------------------------------------------------------
# NOTE: 
# This Dockerfile is anonymized for public sharing.
# To use AWS services, provide your own credentials via environment 
# variables, shared config files, or IAM roles.
# ---------------------------------------------------------------------

# Base image
FROM rocker/rstudio:latest

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC
ENV PATH="/opt/venv/bin:/usr/local/bin:$PATH"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3-venv \
    python3-dev \
    jq \
    curl \
    vim \
    git \
    libcurl4-openssl-dev \   
    libssl-dev \            
    libxml2-dev \            
    && rm -rf /var/lib/apt/lists/*

# Create a Python Virtual Environment
RUN python3 -m venv /opt/venv

# Install Python packages
RUN /opt/venv/bin/pip install --no-cache-dir \
    jupyter \
    boto3 \
    awscli

# -----------------------
# Pre-create generic R library path
# -----------------------
RUN mkdir -p /home/rstudio/R/library \
    && chown -R rstudio:rstudio /home/rstudio/R
ENV R_LIBS_USER=/home/rstudio/R/library

# -----------------------
# Install R packages as rstudio user
# -----------------------
USER rstudio

RUN /usr/local/bin/R -e "install.packages(c('curl','httr','xml2','tidyverse','jsonlite'), repos='https://cloud.r-project.org')"
RUN /usr/local/bin/R -e "install.packages('aws.s3', repos=c('cloudyr'='http://cloudyr.github.io/drat'))"

# -----------------------
# Switch back to root
# -----------------------
USER root

# Expose RStudio and Jupyter ports
EXPOSE 8787 
EXPOSE 8888

# Create a startup script
RUN echo '#!/bin/bash\n\
/opt/venv/bin/jupyter notebook --ip=0.0.0.0 --port=8888 --no-browser --allow-root --NotebookApp.token="" --NotebookApp.password="" &\n\
/init' > /usr/local/bin/start_services.sh

RUN chmod +x /usr/local/bin/start_services.sh

CMD ["/usr/local/bin/start_services.sh"]
