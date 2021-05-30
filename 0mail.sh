#!/bin/bash

# Originally written by anjan at
#     https://git.sr.ht/~anjan/sxmo-userscripts/tree/master/item/mail.sh
#
# minimal email client.
# script requires mbsync (isync) and mu and mblaze
# mbsync is required to send email
# If you have alot of email use 
# format of MAILDIR should be $MAILDIR/ACCOUNT/{INBOX,Archive,etc.}/{cur,new,tmp}

# shellcheck disable=SC1091
[ -f /usr/bin/sxmo_common.sh ] && . /usr/bin/sxmo_common.sh

# Read config file if it exists
MAILSH_CONFIG="${XDG_CONFIG_HOME}/mailsh/config"
# shellcheck source=/dev/null
[ -f "${MAILSH_CONFIG}" ] && . "${MAILSH_CONFIG}"

# Set any variables unset by user's config
MAILDIR=${MAILDIR:-$HOME/mail}
MBSYNC_CONFIG="${MBSYNC_CONFIG:-$XDG_CONFIG_HOME/isync/mbsyncrc}"
MBLAZE="${MBLAZE:-$XDG_CONFIG_HOME/mblaze}"
MAILCUR="${MAILCUR:-$XDG_CONFIG_HOME/mblaze/cur}"
MAILSEQ="${MAILSEQ:-$XDG_CONFIG_HOME/mblaze/seq}"
MBLAZE_PAGER="${MBLAZE_PAGER:-less -R}"

# export the variables
export MAILDIR
export MBSYNC_CONFIG
export MBLAZE
export MAILCUR
export MAILSEQ
export MBLAZE_PAGER

TERMMODE=$([ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ] && echo "true")
DRAFT_DIR="$XDG_DATA_HOME/sxmo/modem/draft"

termshow() {
	if [ "$TERMMODE" != "true" ]; then
		st -e "$@"
	else
		"$@"
	fi
}

menu() {
	if [ "$TERMMODE" != "true" ]; then
		"$@"
	else
		if [ -n "$LINES" -a $LINES -gt 10 ]; then
			lines=$((LINES - 5))
		else
			lines=10
		fi
		vis-menu -i -l $lines
	fi
}

findaccount() {
	MAILNUM="$1"
	MAILPATH="$(mseq -r "$MAILNUM")"
	REL="$(realpath --relative-to "$MAILDIR" "$MAILPATH")"
	ACCOUNT="$(echo "$REL" | cut -f1 -d '/')"
	echo "$ACCOUNT"
}

finddir() {
	ACCOUNT="$1"

	FINDME="$2"

	# Must be defined by user
	case "$FINDME" in
		"inbox")
			[ -d "$MAILDIR/$ACCOUNT/Inbox" ] && echo "Inbox"
			[ -d "$MAILDIR/$ACCOUNT/INBOX" ] && echo "INBOX"
			;;
		"archive")
			[ -d "$MAILDIR/$ACCOUNT/Archive" ] && echo "Archive"
			;;
		"sent")
			[ -d "$MAILDIR/$ACCOUNT/Sent" ] && echo "Sent"
			[ -d "$MAILDIR/$ACCOUNT/Sent Items" ] && echo "Sent Items"
			;;
	esac

}

prompt() {
	menu dmenu -i -fn Terminus-12 -c -l 15 "$@"
}

attachmenthandler() {
	ATTACH="$1"
	MIME="$(echo "$ATTACH" | cut -f 2 -d ":" | cut -f 2 -d " ")"
	ATTACHNUM="$(echo "$ATTACH" | cut -f1 -d':')"

	tmp="$(mktemp '/tmp/mblaze.XXXXXX')"
	mshow -O "$MAIL" "$ATTACHNUM" > "$tmp"
	# replace this with xdg?
	case "$MIME" in
		"application/pdf")
			zathura "$tmp"
			;;
		"text/html")
			firefox "$tmp" 
			;;
	esac
	rm "$tmp"

}

showmsg() {
	incontext="$1"

	if [ "${incontext}" = 1 ]
	then
		termshow mless .
	else
		termshow mless
	fi

	while : ;
	do
		CHOICE="$(printf %b "attachments\ncontext\nopen url\nrefile\nCancel" | prompt )"
		case "$CHOICE" in
			"attachments")
				ATTACH="$(mshow -t . | prompt )"
				attachmenthandler "$ATTACH"
				;;
			"context")
				[ "$incontext" = 1 ] && showmsg 1 && return
				ACCOUNT="$(findaccount .)"
				SENTDIR="$(finddir "$ACCOUNT" "sent")"
				ARCHIVEDIR="$(finddir "$ACCOUNT" "archive")"
				INBOXDIR="$(finddir "$ACCOUNT" "inbox")"
				mthread -S "$MAILDIR/$ACCOUNT/$SENTDIR" -S "$MAILDIR/$ACCOUNT/$ARCHIVEDIR" -S "$MAILDIR/$ACCOUNT/$INBOXDIR" . | mseq -S
				showmsg 1
				break ;;
			"open url")
				which urlview || echo 'Please install urlview' | prompt
				mshow -O . | grep -Eo "(http|https)://[a-zA-Z0-9./?=_%:-]*" | sort -u | prompt | xargs -r firefox
				;;
			"refile")
				ACCOUNT="$(findaccount .)"
				ARCHIVEDIR="$(finddir "$ACCOUNT" "archive")"
				mrefile -v . "$MAILDIR/$ACCOUNT/$ARCHIVEDIR" || echo "error occured" | prompt
				termshow mless .+1
				;;
			*)
				break ;;
		esac

	done

}

showmsglist() {
	folder=$1
	while : ;
	do
		mlist "$MAILDIR/$account/$(finddir "$account" "inbox")" | msort -dr | mseq -S
		if [ "$TERMMODE" != "true" ]; then
			msgs="$(mscan -f "%n %u %7f %17S" :)"
		else
			msgs="$(mscan : )"
		fi
		answer="$(printf %b "Close\nReply\nNew\n$msgs" | prompt)"
		case "$answer" in
			"Close")
				return
				;;
			"Reply")
				st -e mrep
				;;
			"New")
				st -e mcom
				;;
			*)
				msg=$(echo "$answer" | grep -o -E '[0-9]+' | head -1)
				termshow mless "$msg"
				;;
		esac
	done
}

mainmenu() {
	account="$(ls -1 "$MAILDIR" | prompt)"
	while : ;
	do
		CHOICE="$(printf %b "Get Mail\nChange Account\nShow Inbox\nShow Archive\nCancel" | prompt -p "$account")"
		case "$CHOICE" in
			"Change Account")
				account="$(ls -1 "$MAILDIR" | prompt)"
				;;
			"Get Mail")
				termshow mbsync -a -c "$MBSYNC_CONFIG"
				;;
			"Show Inbox")
				showmsglist "$MAILDIR/$account/$(finddir "$account" "inbox")"
				;;
			"Show Archive")
				showmsglist "$MAILDIR"/"$account"/"$(finddir "$account" "archive")"
				;;
			*)
				kill $$;;
		esac
	done

}

which mbsync || echo 'Please install isync' | prompt

[ -f "$MBSYNC_CONFIG" ] || echo 'Please configure isync' | prompt

mkdir -p "$MBLAZE"
mainmenu
