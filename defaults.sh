#!/bin/sh

if [[ -z "$JACK_OPTS" ]]; then    
    if [[ -z "$SAMPLE_RATE" ]]; then
        SAMPLE_RATE=48000
    fi
    if [[ -z "$BUFFER_SIZE" ]]; then
        BUFFER_SIZE=128
    fi
    JACK_OPTS="-d dummy -C 0 -P 0 --rate $SAMPLE_RATE --period $BUFFER_SIZE"
fi

echo "JACK_OPTS=\"$JACK_OPTS\"" > /etc/default/jack
