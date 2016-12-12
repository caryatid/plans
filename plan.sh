#!/bin/sh
# # # # # # plans:
# 
# sregex
# tree
# haskell book
# baudrillard
# go mastery
# nethack mastery
# disciplined
# drum patterns
# structures
# 
#     # <plan action>: <what plan action determines>
# sregex:
#     - intent: implement sre for pipelines
#     - milestones: {ui, data model, operations}
#     - procedure: {filesystem, key-val, rdbms} -> ui
#                  {extract, yank, substitute...} -> operations
#     -> recurse
# 
# disciplined:
#     - intent: maintain habitual behavior beneficial to mind and body
#     - milestones: {plan set, 10 days, 30 days, 90 days, year}
#     - procedure: {attempt simple plan, modify plan if wanted } -> plan set
#                  {calendar marking, journal, reward} -> 10 day               
#     -> recurse
# 
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

# state
#     - current plan -- global
#     - milestones -- union of global and local
#     - plan dirs -- union of global and local
#     - stash -- global ;; references current plan 
#     - history -- global ;; references current plan 
#     - refs -- union of global refs and plan refs
# 
# 
#     global config 
#         ~/.plans
#     local config
#         pwd upwards to nearest .plans dir
  
_unary () {
    test -z "$1" && return 1
    local cmd=$1; shift
    local h=$1
    local hash=''
    test -n "$h" && shift
    case "$h" in
    n.*)  # ref-name
        local match=$(echo $h | cut -c3-)
        local names=$(ls $($PDIR_X)/refs | grep ${match:-'.*'})
        if test $(echo "$names" | wc -l) -eq 1
        then
            hash=$(cat $($PDIR_X)/refs/${names})
        else
            for n in $names
            do
                hash=$(printf '%s\n%17.17s%43.43s\n' "$hash" $n $(_get_ref $n))
            done
        fi
        ;;
    h.*)  # history
        echo foo
        ;;
    p.*)  # parents
        echo foo
        ;;
    s.*)  # stash
        echo foo
        ;;
    *)   # pass to plan
        hash=$($HASH_X id $h)
        ;;
    esac
    case $(echo "$hash" | wc -l) in
    1)
        $cmd $hash "$@" && echo $cmd $hash "$@" >>$($PDIR_X)/history
        ;;
    *)
        echo "$hash"
        ;;
    esac
    return 0
}


_set_ref () {
    test -z "$2" && echo must provide name && return 1
    local P=$($PDIR_X)
    echo $1 >"$P/refs/$2"
}

_get_ref () {
    local P=$($PDIR_X)
    test -f "$P/refs/$1" || return 1
    cat "$P/refs/$1"
    return 0
}

_init_plan_dir () {
    test -n "$1" || { echo must provide directory argument; return 1 ;}
    test -e "$1" && { echo $1 already exists; return 1 ;}
    mkdir -p "$1/refs"  # name -> hash
    mkdir -p "$1/scratch"  # <name of open>/<datetime> -> string
}


. ./config.sh

cmd=intent
test -n "$1" && { cmd=$1; shift ;}
case $cmd in
init) 
    _init_plan_dir "$PWD/.plans"
    ;;
open) 
    _unary _set_ref $1 __open__
    ;;
name)
    _unary _set_ref $1 "$2"
    ;;
intent)
    _unary "$HASH_X edit" $1 __intent__
    ;;
milestone)
    _unary _set_add "$1" __milestone__
    ;;
add)
    _unary _zipper_add "$1" __procedure__
    ;;
advance)
    _zipper_set_idx $(_get_ref __open__) __procedure__ $1
    ;;
display)
    echo
    ;;
stash)
    echo foo
    ;;
organize)
    echo foo
    ;;
help)
    echo you are currently helpless
    ;;
*)
    _unary "$HASH_X $cmd" "$@"
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