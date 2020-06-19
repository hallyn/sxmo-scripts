#!/bin/sh
# Get a password from the in-kernel keyring
# Easy way to add it is the mailpwd.sh script
keyctl print $(keyctl request user $1)
