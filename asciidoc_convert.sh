#!/bin/bash -x
asciidoctor $1 -D /tmp/
file=$( basename "$1" )
xdg-open /tmp/$file.html
