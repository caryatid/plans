#!/bin/sh

# alt-right is dada
# sregex
# tree
# haskell book
# baudrillard
# go mastery
# nethack mastery
# disciplined
# drum patterns
# structures
 

# $ plan new-ref sregex _sregex  
# af12aac233... # hash of new plan with name and reference "sregex"
# $ plan open sregex # sets "sregex" as current plan
# $ plan intent # intent to stdout. "sregex" plan now implicit
# implementation sre for pipelines
# $ plan milestone _data-model _operations _api
# $ plan add _use-pattern _data-requirements \
#            name:data-model name:operations _testing _refactor-pass name:api
# # stows message in a global queue. just a scratch pad really. appends info from open plan
# $ plan stash "all selectors are limited by currently open plan's descendents by default?"
# $ plan organize... # simple manual procedure reorganization using the EDITOR
# $ plan open use-pattern
# $ plan intent <<<"determine cmd line interface"
# $ plan add _read-paper _interface
# $ plan stash "new selectors for plans - like p: for parents or somesuch" 
# $ plan set-key name:read-paper source <<<"http://doc.cat-v.org/bell_labs/structural_regexps/se.pdf"
# $ plan set-key name:interface intent <<<"describe interface"
# 
# 
# argument types:
#     cmd -- startswith
#     plan -- filter full set by
#         parents
#         current
#         ref-name
#         history
#     value -- regex
# 

_match_name () {
    local match=$1
    local name=$(ls $(_get_plan_dir)/refs | grep ${match:-'.*'})
    for n in $name
    do
        echo $(_get_ref $n) $n
    done
}

_match_history () {
    local match=$1
    cat $(_get_plan_dir)/history | grep ${match:-'.*'}
}

_get_parents () {
    local hash=$1
    for h in $($HASH_X list-hashes)
    do
        $DATA_X lrange $h +__procedure__ | grep -q $1 && echo $h $($HASH_X key $h name)
    done
}
  
_parse_plan () {
    local hash=''
    local h="$1"
    test -n "$h" && shift
    case "$h" in
    .)
        hash=$(_get_ref __open__)
        ;;
    n.*)  # ref-name
        local match=$(echo $h | cut -c3-)
        hash=$(_match_name $match)
        ;;
    h.*)  # history
        local match=$(echo $h | cut -c3-)
        hash=$(_match_history $match)
        ;;
    s.*)  # stash
        echo foo
        ;;
    *)   # pass to hash
        hash=$($HASH_X id "$h")
        ;;
    esac
    _return_parse "$hash" "$h"    
}


_set_ref () {
    test -z "$2" && echo must provide name && return 1
    echo $1 >"$(_get_plan_dir)/refs/$2"
}

_get_ref () {
    local P=$(_get_plan_dir)
    test -f "$P/refs/$1" || return 1
    cat "$P/refs/$1"
    return 0
}

_to_list () {
    local hash=$1
    local pre=${2:-'>'}
    local status=${3:-mi}
    local tmp=${4:-$(mktemp)}
    local dumb_var=${5:-''}
    local key=$($HASH_X key $hash name)
    if grep -q $hash $tmp
    then
        echo ["$status"] "$pre" ["$key"]
    else
        echo ["$status"] "$pre" "$key"
    fi
    echo $hash >>$tmp
    for h in $($DATA_X lrange $hash +__procedure__)
    do
        local m=-; local i=-
        test -n "$($DATA_X sin $hash $h +__milestone__)" && m=x
        test $h = "$($DATA_X lindex $hash +__procedure__)" && i=x
        _to_list $h ..$pre $m$i $tmp x
    done
    test -n "$dumb_var" || rm $tmp
}
        
    
. ./config.sh

test -n "$1" && { cmd=$1; shift ;}
case ${cmd:-''} in
init) 
    _init_plan_dir "$PWD/.plans"
    ;;
open) 
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    _set_ref $hash __open__
    ;;
name)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    _set_ref $hash "$2"
    ;;
intent)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    $HASH_X edit $hash +__intent__
    ;;
milestone)
    thash=$(_parse_plan "$1") || _err_multi hash "$thash" $?
    shash=$(_parse_plan "$2") || _err_multi hash "$shash" $?
    $DATA_X sadd $thash $shash +__milestone__
    ;;
add)
    thash=$(_parse_plan "$1") || _err_multi hash "$thash" $?
    shash=$(_parse_plan "$2") || _err_multi hash "$shash" $?
    $DATA_X linsert $thash $shash +__procedure__
    ;;
advance)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    $DATA_X lpos $hash +__procedure__ $2
    ;;
parents)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    _get_parents $hash
    ;;
stash)
    echo not implemented
    ;;
organize)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    tmp=$(mktemp)
    for h in $($DATA_X lrange $hash +__procedure__)
    do
        echo $h $($HASH_X key $h name) >>$tmp
    done
    $EDITOR $tmp
    cat $tmp | cut -d' ' -f1 | $HASH_X set $hash __procedure__
    ;;
display)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    _to_list $hash
    ;;
help)
    echo you are currently helpless
    ;;
'')
    hash=$(_parse_plan ".") || _err_multi hash "$hash" $?
    _to_list $hash
    ;;
*)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    shift
    $HASH_X $cmd $hash "$@"
    ;;
esac

