#!/bin/sh

CORE=./core.sh
TMP=$(mktemp -d)
trap 'rm -Rf $TMP' EXIT

###
# data
HSIZE=100
PDIR=.plans
echo "$1" | grep -q "^-D" && { PDIR=$(echo "$1" | cut -c3-); shift ;}
test -d "$PDIR" || mkdir -p "$PDIR"
IDIR="$PDIR/../.ihash"
test -d "$IDIR" || mkdir -p "$IDIR"

DATA_P="./data.sh -D$PDIR"
DATA_I="./data.sh -D$IDIR"

NAME_KEY=__n_
DESC_KEY=__d_
STAT_KEY=__s_ 
PROC_KEY=__p_ 
PURSUIT_KEY=__u_
STASH_KEY=__b_
REF_KEY=__r_
OPEN_KEY=__o_
GROUP_KEY=__g_
KEY_M='^__._'

CONF_HASH=$(printf '0%0.0s' $(seq 40))
echo config | $DATA_I ..set ..$CONF_HASH "n.$NAME_KEY" >/dev/null

_parse_plan () {
    local hash=''
    local h="$1"
    test -n "$h" && shift
    local open=$($DATA_I ..show-ref ..$CONF_HASH "n.$REF_KEY" \
                    "n.$OPEN_KEY" | cut -d'|' -f1)
    local prefix=$(echo "$h" | cut -c-2)
    local pattern=$(echo "$h" | cut -c3-)
    test -z "$pattern" && pattern='.*'
    case "$prefix" in
    _.)
        hash=$($DATA_P ..id "m.__n_:$pattern")
        ;;
    a.) 
        hash=$($DATA_I ..show-ref ..$CONF_HASH "n.$PURSUIT_KEY" "k.$pattern")
        ;;
    n.)
        test "$pattern" = '.*' && pattern=''
        hash=$($DATA_P ..id n.)
        echo "$pattern" | $DATA_P ..set ..$hash "n.$NAME_KEY" >/dev/null
        ;;
    o.)  
        hash=$open
        ;;
    r.)
        hash=$($DATA_I ..show-ref ..$CONF_HASH "n.$REF_KEY" "k.$pattern")
        ;;
    i.)
        test "$pattern" = '.*' && pattern='0'
        hash=$($DATA_P ..at-index-list ..$open "n.$PROC_KEY" "$pattern")
        ;;
    p.)
        test "$pattern" = '.*' && pattern=''
        hash=$($DATA_P ..list-hashes | _get_parents $open | $DATA_P ..id f_"$pattern")
        ;;
    g.)
        echo "$pattern" | grep -q -v '\.' && pattern="${pattern}."
        local g_pattern=$(echo "$pattern" | cut -d'.' -f1)
        local h_pattern=$(echo "$pattern" | cut -d'.' -f2-)
        _list_groups | grep "$g_pattern" | \
        while read g
        do
            $DATA_I ..show-set ..$CONF_HASH "$GROUP_KEY$g"
        done | $DATA_P ..id f_"$h_pattern" >$TMP/gmatch
        hash=$(cat $TMP/gmatch)
        ;;
    c.)
        test "$pattern" = '.*' && pattern=''
        hash=$(_list_children $open 0 | $DATA_P ..id f_"$pattern")
        ;;
    t.)
        test "$pattern" = '.*' && pattern=''
        hash=$(_tops | $DATA_P ..id f_"$pattern")
        ;;
    h.) # TODO
        test "$pattern" = '.*' && pattern=''
        hash=$(cat $PDIR/history | $DATA_P ..id f_"$pattern")
        ;;
    *) 
        hash=$($DATA_P ..id "$h")
        ;;
    esac
    $CORE return-parse "$hash" "$h" 
}

_parse_group () { 
    local group=''
    local g="$1"
    local prefix=$(echo "$g" | cut -c-2)
    local pattern=$(echo "$g" | cut -c3-)
    case "$prefix" in
    n.)
        if test -n "$pattern"
        then
            $DATA_I ..key ..$CONF_HASH "n.$GROUP_KEY$pattern" >/dev/null
            group="$pattern"
        fi
        ;;
    m.) 
        pattern=${pattern:-'.*'}
        echo _list_groups
        group=$(_list_groups | grep "$pattern")
        ;;
    *)
        g=${g:-'.*'}
        group=$(_list_groups | grep "^$g")
        ;;
    esac
    $CORE return-parse "$group" "$g"
}

_list_groups () {
    $DATA_I ..parse-key ..$CONF_HASH | grep "^$GROUP_KEY" | cut -c5-
}

_get_parents () {
    local hash=$1
    while read h
    do
        $DATA_P ..key ..$h "n.$PROC_KEY" | grep -q $hash && echo $h \
            | $DATA_P ..append @$NAME_KEY
    done
}

_list_children () {
    local hash=$1
    local max=${2:-999}
    local depth=${3:-0}
    local index=${4:-1}
    local focus=${5:-0}
    test -f $TMP/seen || touch $TMP/seen
    local seen='.'
    grep -q $hash $TMP/seen && seen='-'
    if test $max -ne 0 
    then
        local iout='.'; local pursuit='.'; local stat='.'
        test "$focus" -eq "$index" && iout='-'
        $DATA_P ..bool ..$hash n.$STAT_KEY >/dev/null && stat='-' 
        test $depth -ge $max && return 0
        $DATA_I ..index-set ..$CONF_HASH ..$hash "n.$PURSUIT_KEY" >/dev/null \
            && pursuit='-'
        echo $hash | $DATA_P ..append "$depth" 2 | $DATA_P ..append "$iout" 2 \
            | $DATA_P ..append "$pursuit" 2 | $DATA_P ..append "$stat" 2 \
            | $DATA_P ..append "$seen" 2 | $DATA_P ..append "$index" 3
        focus=$($DATA_P ..parse-index ..$hash "n.${PROC_KEY}" c.)
    else
        echo $hash
    fi
    test "$seen" != '.' && return 0
    echo $hash >>$TMP/seen
    index=1
    for h in $($DATA_P ..key ..$hash "n.$PROC_KEY")
    do
        _list_children $h $max "$(( $depth + 1 ))" "$index" "$focus"
        index=$(( $index + 1 ))
    done
}
    
_get_membership () {
    local hash=$1
    _list_groups | \
    while read group
    do
        $DATA_I ..index-set ..$CONF_HASH ..$hash "$GROUP_KEY$group" >/dev/null \
            && echo $group
    done | sort | uniq
}    


_tops () {
    $DATA_P ..list-hashes >$TMP/tops
    while read h
    do
        cat $TMP/tops | _get_parents $h 
    done <$TMP/tops | sort | uniq
}

_display_plan () {
    local hash=$1; local depth=${2:-2}
    printf '\u254f%s\u254f\n' refs
    printf '  %s\n' $($DATA_I ..key ..$CONF_HASH "n.$REF_KEY" \
                      | grep $hash | cut -d'|' -f2)
    printf '\u254f%s\u254f\n' groups
    printf '  %s\n' $(_get_membership $hash)
    printf '\u254f%s\u254f\n' children
    _show_tree $hash $depth | xargs -Ixx printf '  %s\n' "xx"
    printf '\u254f%s\u254f\n' status
    printf '  %s\n' $($DATA_P ..bool ..$hash "n.$STAT_KEY")
    printf '\u254f%s\u254f\n' parents
    $DATA_P ..list-hashes | _get_parents $hash \
        | xargs -Ixx printf '  %s\n' "xx"
}

_show_tree () {
    local hash=$1; local max=$2
    _list_children $hash $max | \
    while read hline
    do
        local h=$(echo $hline | cut -d'|' -f1 | xargs -L1)
        local depth=$(echo $hline | cut -d'|' -f2 | xargs -L1)
        local focus=$(echo $hline | cut -d'|' -f3 | xargs -L1)
        local pursuit=$(echo $hline | cut -d'|' -f4 | xargs -L1)
        local status=$(echo $hline | cut -d'|' -f5 | xargs -L1)
        local seen=$(echo $hline | cut -d'|' -f6 | xargs -L1)
        local index=$(echo $hline | cut -d'|' -f7 | xargs -L1)
        test "$seen" = '.' || continue
        local name=$($DATA_P ..key ..$h "n.$NAME_KEY")
        test "$pursuit" != '.' && name="[$name]"
        local header=''
        test $depth -ge 1 && header=$header$(printf \
            '\u255F\u2508\u2508%.0s' $(seq $depth))
        local st=$(printf '%1.1s' "$status" "$focus")
        local cart=$(printf '%s\u2553\u2524%2.2d %s %s' "$header" $index $st "$name")
        printf '%7.7s %-75.75s\n' $h "$cart"
    done
}

_organize () {
    local hash=$1; local key="$2"; local cmd="$3"
    $cmd ..key ..$hash "n.$key" | $DATA_P ..append "@$NAME_KEY" 88 \
        | sed 's/[[:space:]]*|$//' >$TMP/proc
    $EDITOR $TMP/proc
    cat $TMP/proc | cut -d'|' -f1 | $cmd ..set ..$hash "n.$key" >/dev/null
    while read l
    do
        h=$(echo $l | cut -d'|' -f1)
        echo $l | cut -d'|' -f2 | xargs | $DATA_P ..set ..$h "n.$NAME_KEY" >/dev/null
    done <$TMP/proc
}    

_show_set () {
    local hash=$1; local key="$2"; local cmd="$3"; local depth=${4:-1}
    $cmd ..show-set ..$hash "n.$key" | cut -d'|' -f1 |  \
    while read h
    do
        _show_tree $h $depth
    done
}

_add_to_history () {  # TODO
    local hash=$1
    echo $hash >>$PDIR/history
    tail -n$HSIZE $PDIR/history | cat -n - | sort -k2 -u | sort -n \
        | xargs -L1 | cut -d' ' -f2 >$TMP/histcull
    cp $TMP/histcull $PDIR/history
}

_show_or_set () {
    test -z "$1" && return 1
    local key="$1"; shift
    if test -z "$1"
    then 
        $DATA_P ..key ..$hash "n.$key"
    elif test "$1" = '-'
    then
        $DATA_P ..set ..$hash "n.$key"
    else
        echo "$@" | $DATA_P ..set ..$hash "n.$key"
    fi
}

_handle_plan () {
    local header=$($CORE make-header plan "$2")
    hash=$(_parse_plan "$1") || { $CORE err-msg "$hash" "$header" $?; exit 1 ;}
}


_handle_ref () {
    local header=$($CORE make-header ref "$2")
    ref=$($DATA_I ..parse-refname ..$CONF_HASH "n.$REF_KEY" "$1") \
            || { $CORE err-msg "$ref" "$header" $?; exit 1 ;}
}

_handle_plan_ref () {
    _handle_plan "$1" "$3"
    _handle_ref "$2" "$3"
}

_handle_pursuit () {
    local header=$($CORE make-header pursuit "$2")
    pursuit=$($DATA_I ..parse-refname ..$CONF_HASH "n.$PURSUIT_KEY" "$1") \
              || { $CORE err-msg "$pursuit" "$header" $?; exit 1 ;}
}

_handle_plan_pursuit () {
    _handle_plan "$1" "$3"
    _handle_pursuit "$2" "$3"
}


_handle_target_source () {
    _handle_plan "$1" "$3"; target=$hash
    _handle_plan "$2" "$3"; source=$hash
}

_handle_group () {
    local header=$($CORE make-header group "$2")
    group=$(_parse_group "$1") \
        || { $CORE err-msg "$group" "$header" $?; exit 1 ;}
}

_handle_plan_group () {
    _handle_plan "$1" "$3"
    _handle_group "$2" "$3"
}

_handle_target_source_destination () {
    _handle_plan "$1" "$4"; target=$hash
    _handle_plan "$2" "$4"; source=$hash
    _handle_plan "$3" "$4"; destination=$hash
}


cmd=$($CORE parse-cmd "$0" "$1") || { $CORE err-msg "$cmd" \
        "$($CORE make-header command plan)" $?; exit $? ;}
test -n "$1" && shift
case ${cmd:-''} in
open)
    _handle_plan "$@"
    $DATA_I ..add-ref ..$CONF_HASH ..$hash "n.$REF_KEY" "n.$OPEN_KEY"
    ;;
status)
    _handle_plan "$1"
    $DATA_P ..bool ..$hash "n.$STAT_KEY" "$2"
    ;;
name)
    _handle_plan "$1"
    test -n "$1" && shift
    _show_or_set "$NAME_KEY" "$@"
    ;;
description)
    _handle_plan "$1"
    test -n "$1" && shift
    _show_or_set "$DESC_KEY" "$@"
    ;;
show-plan)
    _handle_plan "$@"
    test -n "$1" && shift
    _display_plan $hash "$@"
    ;;
advance)
    _handle_plan "$1"
    $DATA_P ..cursor-list ..$hash "n.$PROC_KEY" "$2"
    ;;
edit-group)
    _handle_group "$1"
    _organize $CONF_HASH "$GROUP_KEY$group" "$DATA_I"
    ;;
edit-pursuits)
    $DATA_I ..edit ..$CONF_HASH "n.$PURSUIT_KEY"
    ;;
edit-goals)
    echo not-implemented
    # this should allow editing the full set of hashes or subsets
    ;;
edit-refs)
    $DATA_I ..edit ..$CONF_HASH "n.$REF_KEY"
    ;;
edit-history)
    echo not-implemented
    # two stacks: recency and use count
    ;;
edit-procedure)
    _handle_plan "$@"
    _organize $hash $PROC_KEY "$DATA_P"
    ;;
edit-stash)
    _organize $CONF_HASH "$STASH_KEY" "$DATA_I"
    ;;
add-group)
    _handle_plan_group "$@"
    $DATA_I ..add-set ..$CONF_HASH ..$hash "$GROUP_KEY$group"
    ;;
add-pursuits)
    _handle_plan_pursuit "$@"
    $DATA_I ..add-ref ..$CONF_HASH ..$hash "n.$PURSUIT_KEY" "n.$pursuit"
    ;;
add-goals)
    _handle_plan "$@"
    $DATA_P ..id ..$hash
    ;;
add-refs)
    _handle_plan_ref "$@"
    $DATA_I ..add-ref ..$CONF_HASH ..$hash "n.$REF_KEY" "$ref"
    ;;
add-history)
    echo not-implemented
    ;;
add-procedure)
    _handle_target_source "$@"
    $DATA_P ..add-list ..$target ..$source "n.$PROC_KEY" ${3:-e.1}
    ;;
add-stash)
    _handle_plan "$@"
    $DATA_I ..add-set ..$CONF_HASH ..$hash "n.$STASH_KEY"
    ;;
remove-group)
    _handle_plan_group "$@"
    $DATA_I ..remove-set ..$CONF_HASH ..$hash "$GROUP_KEY$group"
    ;;
remove-pursuits)
    _handle_plan_pursuit "$@"
    $DATA_I ..remove-ref ..$CONF_HASH ..$hash "n.$PURSUIT_KEY" "n.$pursuit"
    ;;
remove-goals)
    echo not-implemented
    # idea is to be different from delete and reversable
    ;;
remove-refs)
    _handle_ref "$@"
    $DATA_I ..remove-ref ..$CONF_HASH "n.$REF_KEY" "$ref"
    ;;
remove-history)
    echo not-implemented
    ;;
remove-procedure)
    _handle_target_source "$@"
    $DATA_P ..remove-list ..$target ..$source "n.$PROC_KEY"
    ;;
remove-stash)
    _handle_plan "$@"
    $DATA_I ..remove-set ..$CONF_HASH ..$hash "n.$STASH_KEY"
    ;;
show-group)
    _handle_group "$@"
    test -n "$1" && shift
    _show_set $CONF_HASH "$GROUP_KEY$group" "$DATA_I" "$@"
    ;;
show-pursuits)
    _show_set $CONF_HASH $PURSUIT_KEY "$DATA_I" "$@"
    ;;
show-goals)
    $DATA_P ..list-hashes | $DATA_P ..append @$NAME_KEY 23
    ;;
show-refs)
    _show_set $CONF_HASH $REF_KEY "$DATA_I" "$@"
    ;;
show-history)
    echo not-implemented
    ;;
show-procedure)
    _handle_plan "$@"
    test -n "$1" && shift
    _show_tree $hash "$@"
    ;;
show-stash)
    _show_set $CONF_HASH $STASH_KEY "$DATA_I" "$@"
    ;;
delete-group)
    _parse_group "$@"
    $DATA_I ..delete-key ..$CONF_HASH "$GROUP_KEY$group"
    ;;
delete-plan)
    _parse_plan "$@"
    $DATA_P ..delete ..$hash
    ;;
move)
    _handle_target_source_destination "$@"
    $DATA_P ..remove-list ..$target ..$source "n.$PROC_KEY"
    $DATA_P ..add-list ..$destination ..$source "n.$PROC_KEY" ${4:-e.1}
    ;;
overview)
    echo pursuits >$TMP/pursuits
    printf '  %s\n' $($DATA_I ..show-set ..$CONF_HASH "n.$PURSUIT_KEY" \
                      | cut -d'|' -f2) >>$TMP/pursuits
    echo groups >$TMP/groups
    printf '  %s\n' $(_list_groups) >>$TMP/groups
    echo refs >$TMP/refs
    printf '  %s\n' $($DATA_I ..show-set ..$CONF_HASH "n.$REF_KEY" \
                      | cut -d'|' -f2) >>$TMP/refs
    paste -d^ $TMP/pursuits $TMP/groups $TMP/refs | column -t -s^ -o "$(printf ' \u257f ')"
    ;;
archive)
    file=$(readlink -f ${1:-$HOME}/plan_archive_$(basename "$PWD").tgz)
    cd "$PDIR"
    tar -czf "$file" .
    ;;
help)
    echo you are currently helpless
    ;;
parse-plan)
    _handle_plan "$@"
    echo $hash
    ;;
append)
    $DATA_P ..append "$@"
    ;;
*)
    _handle_plan "$@"
    test -n "$1" && shift
    $DATA_P .."$cmd" ..$hash "$@"
    ;;
esac

