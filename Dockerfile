ARG POSTGRES_VERSION
FROM postgres:${POSTGRES_VERSION}

ARG POSTGRES_VERSIONS="9.6 12 13 14 15 16"
ENV SUPPORTED_POSTGRES_VERSIONS=$POSTGRES_VERSIONS

RUN apt-get update && \
    apt-get install -y procps rsync tini && \
    for version in $POSTGRES_VERSIONS; do \
    apt-get install -y "postgresql-$version"; \
    done && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /data && \
    mkdir -p /data/backup && \
    chown -R postgres:postgres /data && \
    chmod -R 0700 /data && \
    chmod -R 0700 /data/backup

COPY upgrade-postgres.sh /usr/local/bin/upgrade-postgres.sh 
RUN chmod +x /usr/local/bin/upgrade-postgres.sh

WORKDIR /data   

USER postgres:postgres

ENTRYPOINT ["tini", "--", "/usr/local/bin/upgrade-postgres.sh"]
