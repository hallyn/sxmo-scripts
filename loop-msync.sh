#!/bin/sh

SLEEP=1m

if ! pidof -q trackmdirmail.sh; then
    ${HOME}/.config/sxmo/userscripts/trackmdirmail.sh &
fi

while : ; do
    mbsync -a
    sleep "${SLEEP}"
done
