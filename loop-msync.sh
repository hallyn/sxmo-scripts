#!/bin/sh

SLEEP=3m

#if ! pidof -q trackmdirmail.sh; then
    #trackmdirmail.sh &
#fi

while : ; do
    mbsync -a
    sleep "${SLEEP}"
done
