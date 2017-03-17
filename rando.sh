#!/bin/sh
_random_range () {
    dd if=/dev/urandom bs=255 count=5 2>/dev/null | tr -dc "${1:-a-z}" \
        | fold -w${2:-80} 2>/dev/null | head -n1
}

_rnd_len () {
    local range="$1"; local max=${2:-12}
    _random_range "$range" $(( $RANDOM % $max + 1 ))
}

_rnd_words () {
    for _ in $(seq ${1:-7})
    do
        printf '%s ' $(_rnd_len "$2" "$3")
    done
}

_rnd_words "$@"