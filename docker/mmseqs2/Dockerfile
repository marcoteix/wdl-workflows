FROM ghcr.io/soedinglab/mmseqs2

ENTRYPOINT ["/bin/bash"]

RUN mv /usr/local/bin/entrypoint /usr/local/bin/mmseqs
ENV PATH="$PATH:/usr/local/bin/mmseqs"


