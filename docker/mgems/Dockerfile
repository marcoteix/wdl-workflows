FROM ubuntu:18.04

RUN workdir=$(pwd)
RUN apt-get update
RUN apt-get install -y wget

# Download mGEMS's precompiled binaries
RUN wget -P mgems https://github.com/PROBIC/mGEMS/releases/download/v1.3.3/mGEMS-v1.3.3-x86_64-redhat-linux.tar.gz

RUN tar -xvf mgems/mGEMS*.tar.gz -C mgems
RUN rm mgems/*.tar.gz

ENV PATH="$pwd/mgems/mGEMS-v1.3.3-x86_64-redhat-linux:$PATH"

# Install dependencies
RUN apt-get install -y libgomp1 zlib1g-dev

# Check that themisto is added to path
RUN mGEMS