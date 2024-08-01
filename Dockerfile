# Use the NVIDIA CUDA base image
FROM nvidia/cuda:12.5.1-cudnn-runtime-ubuntu22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Install Docker CLI
RUN apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
RUN echo \
    "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
RUN apt-get update && apt-get install -y docker-ce-cli

# Set Docker socket permission
RUN groupadd -g 999 docker

# Install necessary packages
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    git \
    sudo \
    locales \
    build-essential \
    python3-dev \
    python3-pip \
    python3-venv \
    libssl-dev \
    libffi-dev \
    libnss3-dev \
    libsqlite3-dev \
    libreadline-dev \
    libbz2-dev \
    liblzma-dev \
    zlib1g-dev \
    ntp \
    && rm -rf /var/lib/apt/lists/*

RUN service ntp start
RUN ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime

# Set up locales
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# nvm environment variables
RUN mkdir -p /usr/local/nvm
ENV NVM_DIR /usr/local/nvm
ENV NODE_VERSION 20.15.1

# install nvm
# https://github.com/creationix/nvm#install-script
RUN curl --silent -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# install node and npm
RUN /bin/bash -c "source $NVM_DIR/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default"

# add node and npm to path so the commands are available
ENV NODE_PATH $NVM_DIR/v$NODE_VERSION/lib/node_modules
ENV PATH $NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH

# Install Miniforge (a minimal conda installer)
RUN wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh -O Miniforge3.sh \
    && bash Miniforge3.sh -b -p /opt/conda \
    && rm Miniforge3.sh

ENV PATH=/opt/conda/bin:$PATH

# Create a conda environment
RUN conda create -n base2 python=3.12 \
    && conda clean -a -y

# Activate the environment and install JupyterHub and other necessary packages
RUN conda install -n base2 -c conda-forge ipykernel dockerspawner jupyterhub notebook jupyterlab

# pytorch 가상환경 생성 및 패키지 설치
RUN conda create -n pytorch python=3.12 \
    && conda install -n pytorch -y ipykernel pytorch torchvision torchaudio pytorch-cuda=12.4 -c pytorch -c nvidia    

# pytorch kernelspec (all users)
#RUN /opt/conda/envs/pytorch/bin/python -m ipykernel install --name pytorch --display-name "PyTorch (CUDA 12.4)"

# tensorflow 가상환경 생성 및 패키지 설치
RUN conda create -n tensorflow python=3.12 \
    && conda install -n tensorflow -y ipykernel
RUN /opt/conda/envs/tensorflow/bin/python -m pip install --upgrade pip
RUN /opt/conda/envs/tensorflow/bin/python -m pip install tensorflow[and-cuda]

# tensorflow kernelspec (all users)
#RUN /opt/conda/envs/tensorflow/bin/python -m ipykernel install --name tensorflow --display-name "TensorFlow (CUDA 12.4)"

# Install JupyterHub system service
RUN npm install -g configurable-http-proxy

# Create JupyterHub user
RUN useradd -m -s /bin/bash jupyterhub \
    && echo "jupyterhub ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Expose port
EXPOSE 8000

# Set the working directory
WORKDIR /data

# Add a default user with password 
RUN adduser --disabled-password --gecos "" jereiard
RUN echo "jereiard:jereiard" | chpasswd
RUN chmod +w /etc/sudoers
RUN echo 'jereiard ALL=(ALL) NOPASSWD:ALL' | tee -a /etc/sudoers
RUN chmod -w /etc/sudoers

# Ensure the home directory for the default user
#RUN mkdir -p /home/jereiard
#RUN mkdir -p /home/jereiard/notebooks
#RUN chown -R jereiard:jereiard /home/jereiard

# Set proper permissions for the .condarc file
#RUN mkdir -p /home/jereiard/.config/conda
#RUN touch /home/jereiard/.config/conda/.condarc
#RUN chown -R jereiard:jereiard /home/jereiard/.config

# Ensure the base2 environment is activated when the container starts
ENV PATH /opt/conda/envs/base2/bin:$PATH

# Copy configuration files
COPY jupyterhub_config.py /etc/jupyterhub/jupyterhub_config.py
COPY cull_idle_servers.py /usr/local/bin/cull_idle_servers.py

SHELL ["/bin/bash", "-c"]
# Start JupyterHub
CMD ["/opt/conda/envs/base2/bin/jupyterhub", "-f", "/etc/jupyterhub/jupyterhub_config.py"]
