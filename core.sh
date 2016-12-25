#!/bin/sh 

# TODO HANDLE ERRO

_return_parse () {
    local len=$(echo "$1" | wc -l)
    test -z "$1" && len=0
    case $len in
    1)
        echo $1 | cut -d' ' -f1
        return 0
        ;;
    0)
        printf 'no matches to provided pattern:\n%s' "$2"
        return 1
        ;;
    *)
        printf "$1"
        return $len
        ;;
    esac
}


_get_plan_dir () {
    p_dir="$PWD"
    while test "$p_dir" != ""
    do
        test -d "$p_dir/.plans" && break || p_dir=${p_dir%/*}
    done
    test -d "$p_dir" || return 1
    echo "$p_dir/.plans"
}

_init_plan_dir () {
    test -e ".plans" && { echo .plans already exists; return 1 ;}
    mkdir -p ".plans/.hash"  
    mkdir -p ".plans/refs"  
    touch ".plans/history"
}

_error () {   # msg -> header -> code
    test -n "$2" && printf "%s\n" "$2"
    printf "%s\n" "$1"
    return ${3:-0}
}

_ask_to_init () {
    if test -t 1
    then
        printf 'There is no plans directory here or in parent directories\n'
        printf 'Make one in the current directory?\n    (%s)\ny/n: ' "$PWD/.plans"
        read answer
        echo "$answer" | grep -qi '^y' && _init_plan_dir && return 0
    fi
    return 1
}

cmd=plan-dir
test -n "$1" && cmd="$1" && shift
case "$cmd" in
return-parse)
    _return_parse "$1" "$2"
    ;;
plan-dir)
    _get_plan_dir || _ask_to_init
    ;;
hash-dir)
    _get_plan_dir || _ask_to_init
    ;;
err-msg)
    _error "$@"
    ;;
temp-dir)
    # yer job to clean up bubbo
    mktemp -d
    ;;
init)
    _init_plan_dir
    ;;
esac
