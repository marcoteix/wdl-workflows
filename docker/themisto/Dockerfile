FROM ubuntu:18.04

RUN workdir=$(pwd)
RUN apt-get update
RUN apt-get install -y wget

# Download Themisto's precompiled binaries
RUN wget -P themisto https://github.com/algbio/themisto/releases/download/v3.2.2/themisto_linux-v3.2.2.tar.gz

RUN tar -xvf themisto/themisto*.tar.gz -C themisto
RUN rm themisto/*.tar.gz

ENV PATH="$pwd/themisto/themisto_linux-v3.2.2:$PATH"

# Install dependencies
RUN apt-get install -y libgomp1 zlib1g-dev

# Check that themisto is added to path
RUN themisto