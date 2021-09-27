FROM    alpine:3.14

# Build variables
ENV     FILEBEAT_VERSION 7.3.2
ENV     FILEBEAT_URL https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-${FILEBEAT_VERSION}-linux-x86_64.tar.gz

# Environment variables
ENV     FILEBEAT_HOME filebeat-${FILEBEAT_VERSION}-linux-x86_64
ENV     PATH $PATH:${FILEBEAT_HOME}

WORKDIR /opt

ENV PYTHONUNBUFFERED=1
RUN apk add --update --no-cache python3 && ln -sf python3 /usr/bin/python
RUN python3 -m ensurepip
RUN pip3 install --no-cache --upgrade pip setuptools
RUN apk add --update curl gcompat coreutils

RUN     curl -sL ${FILEBEAT_URL} | tar xz -C .
ADD     filebeat.yml ${FILEBEAT_HOME}/
RUN     chmod go-w /opt/${FILEBEAT_HOME}/filebeat.yml
ADD     docker-entrypoint.sh    /entrypoint.sh
RUN     chmod +x /entrypoint.sh

ENTRYPOINT  ["/entrypoint.sh"]
CMD         ["start"]
