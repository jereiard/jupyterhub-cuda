FROM nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    vim \
    wget \
    curl \
    nano \
    gcc \
    g++ \
    make \
    libssl-dev \
    bzip2 \
    libffi-dev \
    python3 \
    python3-pip \
    python3-dev \
    sudo \
    git \
    build-essential \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

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

# Install configurable-http-proxy
RUN /bin/bash -c "source $NVM_DIR/nvm.sh && npm install -g configurable-http-proxy"

# Miniforge 설치
RUN curl -LO "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh" && \
    bash Miniforge3-Linux-x86_64.sh -b -p /opt/conda && \
    rm Miniforge3-Linux-x86_64.sh

ENV PATH=/opt/conda/bin:$PATH

# base2 가상환경 생성 및 공통 패키지 설치
RUN conda create -n base2 python=3.12 \
    && conda install -n base2 -y -c conda-forge jupyterhub jupyterlab dockerspawner ipykernel ipywidgets wheel notebook numpy pandas scipy

# JupyterLab 확장 설치
RUN /opt/conda/envs/base2/bin/jupyter labextension install @jupyter-widgets/jupyterlab-manager

# JupyterHub 설정 디렉토리 생성
RUN mkdir -p /srv/jupyterhub

# JupyterHub 설정 파일 복사
COPY jupyterhub_config.py /srv/jupyterhub/jupyterhub_config.py

# 노트북 디렉토리 설정
ENV NOTEBOOK_DIR=/home/jovyan/work
RUN mkdir -p $NOTEBOOK_DIR
WORKDIR $NOTEBOOK_DIR

# pytorch 가상환경 생성 및 패키지 설치
RUN conda create -n pytorch python=3.12 \
    && conda install -n pytorch -y ipykernel pytorch torchvision torchaudio pytorch-cuda=12.4 -c pytorch-nightly -c nvidia

# base2 가상환경을 참조하도록 pytorch 가상환경 설정
RUN echo "source activate pytorch" >> ~/.bashrc \
    && echo "export PATH=/opt/conda/envs/base2/bin:\$PATH" >> ~/.bashrc

# pytorch kernelspec (all users)
RUN /opt/conda/envs/pytorch/bin/python -m ipykernel install --name pytorch --display-name "PyTorch (CUDA 12.4)"

# tensorflow 가상환경 생성 및 패키지 설치
RUN conda create -n tensorflow python=3.12 \
    && conda install -n tensorflow -y ipykernel
RUN /opt/conda/envs/tensorflow/bin/python -m pip install --upgrade pip
RUN /opt/conda/envs/tensorflow/bin/python -m pip install tensorflow[and-cuda]

# base2 가상환경을 참조하도록 tensorflow 가상환경 설정
RUN echo "source activate tensorflow" >> ~/.bashrc \
    && echo "export PATH=/opt/conda/envs/base2/bin:\$PATH" >> ~/.bashrc

# tensorflow kernelspec (all users)
RUN /opt/conda/envs/tensorflow/bin/python -m ipykernel install --name tensorflow --display-name "TensorFlow (CUDA 12.4)"

# Expose port
EXPOSE 8000

# Add a default user with password 
RUN adduser --disabled-password --gecos "" jereiard
RUN echo "jereiard:jereiard" | chpasswd
RUN chmod +w /etc/sudoers
RUN echo 'jereiard ALL=(ALL) NOPASSWD:ALL' | tee -a /etc/sudoers
RUN chmod -w /etc/sudoers

# Ensure the home directory for the default user
RUN mkdir -p /home/jereiard
RUN chown jereiard:jereiard /home/jereiard

# JupyterHub 시작 명령 설정
CMD ["/opt/conda/envs/base2/bin/jupyterhub", "--config", "/srv/jupyterhub/jupyterhub_config.py"]