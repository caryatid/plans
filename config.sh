#!/bin/sh 

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

_err_multi () {
#    printf '%s choices:\n' "$1"  
    echo "$2" | tr '\n' '\0' | xargs -0 -L1 printf '  %s\n'
    local ret=${3:-1}
    if test $ret -ne 0; then exit $ret; fi
    return $ret
}

_get_plan_dir () {
    p_dir="$PWD"
    while test "$p_dir" != ""
    do
        test -d "$p_dir/.plans" && break || p_dir=${p_dir%/*}
    done
    test -d "$p_dir" || { echo no plan dir; return 1 ;}
    echo "$p_dir/.plans"
}

_init_plan_dir () {
    test -e ".plans" && { echo .plans already exists; return 1 ;}
    mkdir -p ".plans/.hash"  
    mkdir -p ".plans/refs"  
    mkdir -p ".plans/stash"  
}

if ! _pd=$(_get_plan_dir)
then
    printf 'there is no plan dir\n'
    printf 'make one here?\n'
    read answer
    if echo "$answer" | grep -qi '^y'
    then
        _init_plan_dir
        _pd=$(_get_plan_dir)
    else
        exit 1
    fi
fi
HASH_X=$(printf './hash.sh -D%s/.hash' "$_pd")
DATA_X="./data.sh"
    
