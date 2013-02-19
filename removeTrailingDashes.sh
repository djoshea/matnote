#!/bin/bash

TMPFILE=`mktemp -t awktemp.XXX`
awk '
  $1=="---" {c++}
  c==2 {exit}
  {print $0}
' "$1" > $TMPFILE && mv $TMPFILE "$1"


