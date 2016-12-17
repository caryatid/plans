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
    for h in $($HASH_X id '' | cut -d' ' -f1)
    do
        $DATA_X lrange $h +__procedure__ | grep -q $1 && echo $h $($HASH_X key $h name)
    done
}
  
_parse_plan () {
    local hash=''
    local h=$1
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
        hash=$($HASH_X id $h)
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

. ./config.sh

cmd=intent
test -n "$1" && { cmd=$1; shift ;}
case $cmd in
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
    $HASH_X edit $hash __intent__
    ;;
milestone)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    $DATA_X sadd $(_get_ref __open__) $hash +__milestone__
    ;;
add)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    $DATA_X linsert $(_get_ref __open__) $hash +__procedure__
    ;;
advance)
    $DATA_X lpos $(_get_ref __open__) +__procedure__ $1
    ;;
parents)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    _get_parents $hash
    ;;
stash)
    sdir=$(_get_plan_dir)/stash/$($HASH_X key $(_get_ref __open__) name)
    mkdir -p "$sdir"
    echo $@ >>"$sdir/$(date -Iseconds)"
    ;;
organize)
    local tmp=$(mktemp)
    for h in $($DATA_X lrange $(_get_ref __open__) +__procedure__)
    do
        echo $h $($HASH_X key $h $name) >>$tmp
    done
    $EDITOR $tmp
    ;;
display)
    echo
    ;;
help)
    echo you are currently helpless
    ;;
*)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    shift
    $HASH_X $cmd $hash "$@"
    ;;
esac


# _graph () {
#     local pre="$2"
#     local parent="$3"
#     local S=''
#     local F=''
#     local seen=''
#     n=$(_get_key $1 name)
#     if test -z "$pre"
#     then
#         echo $1 >"$_D/seen"
#         echo $n
#     else
#         _pre=${pre%????}
#         grep -q $p "$_D/seen" && seen=x
#         test "$(_get_focus $parent)" == $1 && F='>'
#         test $(_get_key $1 status) -gt 0 && S='x'
#         echo "${_pre}-${S:--}${F:--} ${seen:+[}$n${seen:+]}"
#         test "$seen" == x && return 0
#     fi
#     for p in $(_get_key $1 procedure)
#     do
#         _graph $p "$pre|...." $1
#     done
# }
# 