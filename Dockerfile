FROM nvidia/cuda:11.8.0-base-ubuntu20.04
ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_BREAK_SYSTEM_PACKAGES=1

# Fix for deadsnakes
RUN apt-get update && apt-get install -y \
    software-properties-common \
    gnupg2 && \
    curl -fsSL https://packages.sury.org/php/apt.gpg | tee /etc/apt/trusted.gpg.d/deadsnakes.asc && \
    add-apt-repository ppa:deadsnakes/ppa

# Build deps
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    libpoppler-cpp-dev \
    poppler-utils \
    software-properties-common \
    pkg-config \
    ninja-build \
    meson \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y \
    python3.10 \
    python3.10-venv \
    python3.10-dev \
    python3.10-distutils \
    python3-pybind11 \
    && rm -rf /var/lib/apt/lists/*

RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3.10

# Pyenv setup

ENV PYENV_ROOT="/root/.pyenv"
ENV PATH="$PYENV_ROOT/bin:$PATH"

RUN apt-get update && apt-get install -y \
    make \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    wget \
    llvm \
    libncurses5-dev \
    libncursesw5-dev \
    xz-utils \
    tk-dev \
    libffi-dev \
    liblzma-dev \
    && rm -rf /var/lib/apt/lists/*

# Install pyenv
RUN curl https://pyenv.run | bash

# Update .bashrc to initialize pyenv
RUN echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.bashrc && \
    echo 'eval "$(pyenv init --path)"' >> ~/.bashrc && \
    echo 'eval "$(pyenv init -)"' >> ~/.bashrc && \
    echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.bashrc && \
    /bin/bash -c "source ~/.bashrc"

# Install Python 3.10.4 using pyenv
RUN /bin/bash -c "source ~/.bashrc && pyenv install 3.10.4 && pyenv global 3.10.4"

# Set working directory
WORKDIR /app

# Copy application code into container
COPY . /app

# Create Virtual Environments
RUN python3.10 -m venv sparrow-ml/llm/.env_llamaindex && \
    python3.10 -m venv sparrow-ml/llm/.env_haystack && \
    python3.10 -m venv sparrow-ml/llm/.env_instructor && \
    python3.10 -m venv sparrow-ml/llm/.env_unstructured && \
    python3.10 -m venv sparrow-data/ocr/.env_ocr

# Install dependencies for llamaindex environment
RUN /bin/bash -c ". sparrow-ml/llm/.env_llamaindex/bin/activate && \
    pip install -U pip setuptools wheel && \
    pip install -r sparrow-ml/llm/requirements_llamaindex.txt"

# Install dependencies for haystack environment
RUN /bin/bash -c ". sparrow-ml/llm/.env_haystack/bin/activate && \
    pip install -U pip setuptools wheel && \
    pip install -r sparrow-ml/llm/requirements_haystack.txt"

# Install dependencies for instructor environment
RUN /bin/bash -c ". sparrow-ml/llm/.env_instructor/bin/activate && \
    pip install -U pip setuptools wheel && \
    pip install -r sparrow-ml/llm/requirements_instructor.txt"

# Install dependencies for unstructured environment
RUN /bin/bash -c ". sparrow-ml/llm/.env_unstructured/bin/activate && \
    pip install -U pip setuptools wheel && \
    pip install -r sparrow-ml/llm/requirements_unstructured.txt"

# Install dependencies for OCR environment
RUN /bin/bash -c ". sparrow-data/ocr/.env_ocr/bin/activate && \
    pip install -U pip setuptools wheel meson ninja && \
    pip install -r sparrow-data/ocr/requirements.txt"

# Missing dependencies
RUN pip install --ignore-installed pyyaml fastapi[all] typer[all] weaviate-client llama_index llama-index-vector-stores-weaviate llama-index-embeddings-huggingface

# Hack to set pythonpath due to bug preventing package discovery
ENV PYTHONPATH="/usr/lib/python310.zip:/usr/lib/python3.10:/usr/lib/python3.10/lib-dynload:/usr/local/lib/python3.10/dist-packages:/usr/lib/python3/dist-packages"
RUN echo 'export PYTHONPATH="${PYTHONPATH}"' >> ~/.bashrc

WORKDIR /app/sparrow-ml/llm
ENV PORT=8000
CMD ["/bin/sh"]
