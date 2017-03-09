#!/bin/sh 

_return_parse () {
    local len=$(echo "$1" | wc -l)
    test -z "$1" && len=0
    case $len in
    1)
        echo $1 | cut -d'|' -f1
        return 0
        ;;
    0)
        printf 'no matches to provided pattern:\n%s\n.\n' "$2"
        return 1
        ;;
    *)
        printf '%s\n' "$1"
        return $len
        ;;
    esac
}

_error () {
    local header=$(echo "$2" | tr '\n' '\0' | xargs -0 -n1)
    local msg="$1"
    test -t 1 && test -n "$header" && printf "%s\n" "$header"
    test -n "$msg" && printf "%s\n" "$msg"
    return ${3:-0}
}

_parse_cmd () {
    local cmd=''
    local cfile=$(readlink -f "$1")
    local cmds=$(sed -n 's/\(^[^[:space:]]\+\)).*/\1/p' "$cfile" )
    local c=${2:-'.*'}
    local prefix=$(echo "$c" | cut -c-2)
    local pattern=$(echo "$c" | cut -c3-)
    case "$prefix" in
    ..)
        cmd="$pattern"
        ;;
    *)
        cmd=$(echo "$cmds" | grep "^$c")
        ;;
    esac
    _return_parse "$cmd" "$c"
}

cmd=plan-dir
test -n "$1" && cmd="$1" && shift
case "$cmd" in
return-parse)
    _return_parse "$1" "$2"
    ;;
parse-cmd)
    _parse_cmd "$@"
    ;;
make-header)
    printf '[ %s ] - %s -\n' "$1" "${2:--}"
    ;;
err-msg)
    _error "$@" 
    ;;
esac
