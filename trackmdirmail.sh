#!/bin/sh

# For use on sxmo phone.  Watching an mdir (filled with mbsync)
# and when new mail is found, calls ~/bin/newmail-claxon
# /bin/sh because bash isn't on the thing by default.

# Replace with the location of your inboxes, space separated
BOXES="${HOME}/ciscomail/INBOX ${HOME}/gmail/INBOX"
SLEEP=20

# Initialize
MAILCACHE="${HOME}/.cache/maildup"
rm -rf ${MAILCACHE}
mkdir -p ${MAILCACHE}

debug() {
    echo $*
}

initbox() {
    box="$1"
    idx="$2"
    base=$(basename ${box})
    mkdir -p "${MAILCACHE}/${idx}"
    echo "${box}" > "${MAILCACHE}/${idx}/Mailbox"
    for msg in ${box}/new/*; do
        [ ! -f ${msg} ] && continue
        file=$(basename ${msg})
        touch "${MAILCACHE}/${idx}/${file}"
    done
}

checkbox() {
    box="$1"
    idx="$2"
    base=$(basename ${box})
    for msg in ${box}/new/*; do
        [ ! -f ${msg} ] && continue
        file=$(basename ${msg})
        [ "$file" = "Mailbox" ] && continue
        [ "$file" = "summary" ] && continue
        if [ ! -f "${MAILCACHE}/${idx}/${file}" ]; then
            echo "found $file"
            grep "^From:" "${msg}" | cut -c 1-60 >> "${MAILCACHE}/${idx}/summary"
            grep "^Subject:" "${msg}" | cut -c 1-60 >> "${MAILCACHE}/${idx}/summary"
            echo >> "${MAILCACHE}/${idx}/summary"
            touch "${MAILCACHE}/${idx}/${file}"
        fi
    done
}

clearbox() {
    box="$1"
    idx="$2"
    base=$(basename ${box})
    for omsg in ${MAILCACHE}/${idx}/*; do
        [ ! -f ${omsg} ] && continue
        file=$(basename ${omsg})
        [ "$file" = "Mailbox" ] && continue
        [ "$file" = "summary" ] && continue
        if [ ! -f "${box}/new/${file}" ]; then
            echo "deleting ${omsg} bc ${box}/new/${file} didnot exist"
            rm -f "${omsg}"
        fi
    done
    > "${MAILCACHE}/${idx}/summary"
}

count=1
for box in ${BOXES}; do
    initbox $box ${count}
    count=$((count+1))
done

# Watch
while : ; do
    newmails=0
    count=1
    for box in ${BOXES}; do
        debug "checking $box"
        # Delete any cached msgs which are gone
        clearbox "${box}" "${count}"
        checkbox "${box}" "${count}"
        base=$(basename ${box})
        [ -s "${MAILCACHE}/${count}/summary" ] && newmails=1
        count=$((count+1))
    done
    [ ${newmails} -ne 0 ] &&  ${HOME}/bin/newmail-claxon
    sleep "${SLEEP}"
done
