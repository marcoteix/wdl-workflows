FROM nekokoe/plasmer:23.04.20

ENTRYPOINT ["/bin/bash"]

RUN workdir=$(pwd)
RUN apt-get update
RUN apt-get install -y wget

ENV PLASMER="/scripts/Plasmer"
ENV PLASMER_DATABASE="/plasmer_databases"

