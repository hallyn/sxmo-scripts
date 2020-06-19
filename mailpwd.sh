#!/bin/sh
# Store a password in the in-kernel keyring
# getpass.sh is a wrapper to retrieve it.

if [ -z "$1" ]; then
	echo "Usage: $0 account"
	echo "    account: i.e. home, gmail, etc"
	exit 1
fi
read -sp "$1 password: " x
keyctl add user $1 $x @s
