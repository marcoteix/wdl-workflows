FROM condaforge/miniforge3:latest

RUN apt-get update && \
    apt-get install -y --no-install-recommends git build-essential && \
    rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/RasmussenLab/PlasMAAG /opt/PlasMAAG

RUN mamba env create -n PlasMAAG --file=/opt/PlasMAAG/envs/PlasMAAG.yaml && \
    mamba clean --all --yes

ENV PATH=/opt/conda/envs/PlasMAAG/bin:$PATH

ENTRYPOINT ["/bin/sh"]
