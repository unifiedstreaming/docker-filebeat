#!/bin/sh
set -e

if [ "$1" = 'start' ]; then

  CONTAINERS_FOLDER=/tmp/containers
  NAMED_PIPE=/tmp/pipe

  setConfiguration() {
    KEY=$1
    VALUE=$2
    sed -i "s/{{$KEY}}/$VALUE/g" /opt/${FILEBEAT_HOME}/filebeat.yml
  }

  getRunningContainers() {
    curl --no-buffer -s -XGET --unix-socket /tmp/docker.sock http:/dummy/containers/json | python -c "
import json, sys
containers=json.loads(sys.stdin.readline())
for container in containers:
  print(container['Id'])
"
  }

  getContainerName() {
    curl --no-buffer -s -XGET --unix-socket /tmp/docker.sock http:/dummy/containers/$1/json | python -c "
import json, sys
container=json.loads(sys.stdin.readline())
print(container['Name'])
" | sed 's;/;;'
  }

  createContainerFile() {
    touch "$CONTAINERS_FOLDER/$1"
  }

  removeContainerFile() {
    rm "$CONTAINERS_FOLDER/$1"
  }

  collectContainerLogs() {
    local CONTAINER=$1
    echo "Processing $CONTAINER..."
    createContainerFile $CONTAINER
    CONTAINER_NAME=`getContainerName $CONTAINER`

    # Prepend container name and filter lines too short. Use stdbuf -o0 in
    # sed, not sure it's really needed.
    curl -s --no-buffer -XGET --unix-socket /tmp/docker.sock "http:/dummy/containers/$CONTAINER/logs?stderr=1&stdout=1&tail=1&follow=1" | stdbuf -o0 sed -E "s;^;[$CONTAINER_NAME] ;" > $NAMED_PIPE-$CONTAINER_NAME
    echo "Disconnected from $CONTAINER."
    removeContainerFile $CONTAINER
  }

  if [ -n "${LOGSTASH_HOST+1}" ]; then
    setConfiguration "LOGSTASH_HOST" "$LOGSTASH_HOST"
  else
    echo "LOGSTASH_HOST is needed"
    exit 1
  fi

  if [ -n "${LOGSTASH_PORT+1}" ]; then
    setConfiguration "LOGSTASH_PORT" "$LOGSTASH_PORT"
  else
    echo "LOGSTASH_PORT is needed"
    exit 1
  fi

  if [ -n "${SHIPPER_NAME+1}" ]; then
    setConfiguration "SHIPPER_NAME" "$SHIPPER_NAME"
  else
    setConfiguration "SHIPPER_NAME" "`hostname`"
  fi

  rm -rf "$CONTAINERS_FOLDER"
  mkdir "$CONTAINERS_FOLDER"

  #echo "Initializing Filebeat..."
  #cd /opt/${FILEBEAT_HOME}; cat $NAMED_PIPE | ./filebeat -e -v &

  while true; do
    CONTAINERS=`getRunningContainers`
    for CONTAINER in $CONTAINERS; do
      if ! ls $CONTAINERS_FOLDER | grep -q $CONTAINER; then
        echo $CONTAINER
        CONTAINER_NAME=`getContainerName $CONTAINER`
        rm -rf "$NAMED_PIPE-$CONTAINER_NAME"
        mkfifo -m a=rw "$NAMED_PIPE-$CONTAINER_NAME"
        collectContainerLogs $CONTAINER &
        
        echo "Initializing Filebeat..."
        cd /opt/${FILEBEAT_HOME}; ./filebeat -e -v < $NAMED_PIPE-$CONTAINER_NAME &
      fi
    done
    sleep 5
  done

else
  exec "$@"
fi

