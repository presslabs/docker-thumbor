#!/bin/bash

set -e
set -o pipefail

dockerize -template /usr/local/docker/templates:/usr/local/docker/etc -no-overwrite

if [ -z "$THUMBOR_PROCS" ] ; then
    THUMBOR_PROCS=4
fi

for i in $(seq "$THUMBOR_PROCS") ; do
    port="$(( 10800 + i ))"
    /opt/thumbor/bin/thumbor -p $port -i 127.0.0.1 -c /usr/local/docker/etc/thumbor.conf &
    pids[${i}]=$!
done

for pid in ${pids[*]}; do wait $pid; done;
