ARG POSTGRES_VERSION
FROM postgres:${POSTGRES_VERSION}

RUN apt-get update && \
    apt-get install -y tini procps rsync

# in the future: maybe fetch the versions to be downloaded from versions-postgres.yaml file.
ARG POSTGRES_VERSIONS="9.6 10 11 12 13 14 15 16"
ENV SUPPORTED_POSTGRES_VERSIONS=$POSTGRES_VERSIONS

RUN for version in $POSTGRES_VERSIONS; do \
    apt-get install -y postgresql-$version; \
    done && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /data && \
    mkdir -p /data/backup && \
    chown -R postgres:postgres /data && \
    chmod -R 0700 /data && \
    chmod -R 0700 /data/backup

COPY upgrade-postgres.sh /usr/local/bin/upgrade-postgres.sh 
RUN chmod +x /usr/local/bin/upgrade-postgres.sh

WORKDIR /data   

USER postgres:postgres

ENTRYPOINT ["tini", "--", "/usr/local/bin/upgrade-postgres.sh"]