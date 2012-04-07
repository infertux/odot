#!/bin/bash

# Settings
ROOT_URL="/odot/"
PUBLIC=public # public files
POSTS=posts # posts directory
PAGES=pages # pages directory
TEMPLATES=templates # templates directory
TMP=tmp # temp file

# /!\ Don't fiddle with the lines below

set -u
set -e

cd "$(dirname $0)"

if [[ $# -gt 1 || $# -gt 0 && "$1" = "--help" ]]; then
  cat >&2 <<USAGE
Generate posts that need to be updated.

Usage: $(basename $0) [-v]

-v  Verbose mode
USAGE
  exit 0
fi

# Functions

verbose() {
  [ "$VERBOSE" ] && echo "$1" || true
}

find_post() {
  local side=$1
  local post=$(echo $2 | cut -d. -f1)
  ls -1 $POSTS | grep -${side}1 "^$post$" | grep -v "^$post$" || true
}

timestamp() {
  date -d $1 +%s
}

previous_post() {
  echo $(find_post B $post)
}

next_post() {
  local next=$(find_post A $post)
  [ "$next" ] && [ $(timestamp $TODAY) -ge $(timestamp $next) ] && echo $next
}

last_post() {
  ls -1 $PUBLIC/$POSTS | tail -1
}

replace() {
  local file=${3:-$TMP}
  sed -i "s/<\!-- $1 -->/$(escape "$2")/" $file
}

escape() {
  echo "${1//\//\\/}" # escape slashes for sed
}

wrap() {
  cat $TEMPLATES/header.html $1 $TEMPLATES/footer.html > $2
  replace ROOT_URL "$ROOT_URL" $2
}

generate_posts() {
  for post in $(ls $POSTS); do
    post_date=$post
    post="${post}.html"

    # if today's post is already generated
    [ -f "$PUBLIC/$POSTS/$TODAY.html" ] && break

    verbose "Processing $post..."

    # find relative posts
    previous=$(previous_post || true)
    next=$(next_post || true)

    # don't regenerate old posts
    [[ -f "$PUBLIC/$POSTS/$post" && \
       ("$post" != "$(last_post)" && "$(last_post)" || -z "$next") \
    ]] && continue

    verbose "Generating $post..."

    # generate new post
    wrap $TEMPLATES/post.html $TMP
    replace DATE "$(date -d $post_date +'%e %b %Y')"

    # replace markers with actual values
    while read line; do
      key=$(echo $line | cut -d: -f1 | tr '[:lower:]' '[:upper:]') # key is uppercase
      value=$(echo $line | cut -d: -f2- | cut -d' ' -f2-)
      replace $key "$value"
    done < $POSTS/$post_date

    # set previous link if any
    [ "$previous" ] && \
      replace PREVIOUS "<a href=\"$ROOT_URL$POSTS/$previous.html\">\&larr; previous</a>"

    # set next link if any
    [ "$next" ] && \
      replace NEXT "<a href=\"$ROOT_URL$POSTS/$next.html\">next \&rarr;</a>"

    cp -f $TMP $PUBLIC/$POSTS/$post
    echo "$post has been generated."
  done
}

generate_pages() {
  for page in $(ls $PAGES); do
    wrap $PAGES/$page $PUBLIC/$page
  done
}

###

[[ "$#" -gt 0 && "$1"  = "-v" ]] && VERBOSE=1 || VERBOSE=
TODAY=$(date +%F)

generate_posts

# symlink most recent post to index
ln -fs $POSTS/$(last_post) $PUBLIC/index.html

generate_pages

# delete temp file
[ -f $TMP ] && rm -f $TMP

# warn if there is no upcoming post
tomorrow=$(find_post A $TODAY)
[ "$tomorrow" ] || echo "Warning: no post for tomorrow yet." >&2

verbose "Done"
exit 0

