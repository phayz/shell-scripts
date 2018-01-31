#!/bin/sh

len='7:00:00'

if [ "$1" != '' ]; then
  len=$1
fi

play -t sl - synth $len  pinknoise \ 
     band -n 1200 200 tremolo 20 .1 < /dev/zero