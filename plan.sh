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
STAT_KEY=__s_ 
PROC_KEY=__p_ 
KEY_M='^__._'

CONF_HASH=$(printf '0%0.0s' $(seq 40))
echo config | $DATA_I set ..$CONF_HASH "n.$NAME_KEY" >/dev/null
REF_KEY=__r_
OPEN_KEY=__o_

GROUP_KEY=__g_
#
###

###
# queries:
_parse_plan () {
    local hash=''
    local h="$1"
    test -n "$h" && shift
    local open=$(_get_ref "$OPEN_KEY" | cut -d'|' -f1)
    local prefix=$(echo "$h" | cut -c-2)
    local pattern=$(echo "$h" | cut -c3-)
    test -z "$pattern" && pattern='.*'
    case "$prefix" in
    n.)
        hash=$($DATA_P id n.)
        echo "$pattern" | $DATA_P set ..$hash "n.$NAME_KEY" >/dev/null
        ;;
    o.)  
        hash=$open
        ;;
    r.)
        hash=$($DATA_I ref ..$CONF_HASH "n.$REF_KEY" "k.$pattern")
        ;;
    i.)
        test "$pattern" = '.*' && pattern='0'
        hash=$($DATA_P lindex ..$open "n.$PROC_KEY" "$pattern")
        ;;
    p.)
        test "$pattern" = '.*' && pattern=''
        hash=$($DATA_P list-hashes | _get_parents $open | $DATA_P id f_"$pattern")
        ;;
    g.)
        echo "$pattern" | grep -q -v '\.' && pattern="${pattern}."
        local g_pattern=$(echo "$pattern" | cut -d'.' -f1)
        local h_pattern=$(echo "$pattern" | cut -d'.' -f2)
        _list_groups | grep "$g_pattern" | \
        while read g
        do
            $DATA_I smembers ..$CONF_HASH "n.$GROUP_KEY$g"
        done | $DATA_P id f_"$h_pattern" >$TMP/gmatch
        hash=$(cat $TMP/gmatch)
        ;;
    c.)
        test "$pattern" = '.*' && pattern=''
        hash=$(_list_children $open | $DATA_P id f_"$pattern")
        ;;
    t.)
        test "$pattern" = '.*' && pattern=''
        hash=$(_tops | $DATA_P id f_"$pattern")
        ;;
    h.) # TODO
        test "$pattern" = '.*' && pattern=''
        hash=$(cat $PDIR/history | $DATA id f_"$pattern")
        ;;
    *) 
        hash=$($DATA_P id "$h")
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
            $DATA_I key ..$CONF_HASH "n.$GROUP_KEY$pattern" >/dev/null
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
        group=$(_list_groups | grep "^$g\$")
        ;;
    esac
    $CORE return-parse "$group" "$g"
}
#
###

_list_groups () {
    $DATA_I parse-key ..$CONF_HASH | grep "^$GROUP_KEY" | cut -c5-
}

_get_parents () {
    local hash=$1
    while read h
    do
        $DATA_P key ..$h "n.$PROC_KEY" | grep -q $hash && echo $h \
            | $DATA_P append @$NAME_KEY
    done
}

_status () {
    local hash=$1
    $DATA_P bool ..$hash "n.$STAT_KEY" "$2"
}

_list_children () {
    local hash=$1
    local depth=${2:-0}
    local index=${3:-1}
    local focus=${4:-0}
    test -f $TMP/seen || touch $TMP/seen
    local iout=''; test "$focus" -eq "$index" && iout='x'
    echo $hash | $DATA_P append "$depth" 5 | $DATA_P append "$iout" 3
    focus=$($DATA_P lpos ..$hash "n.${PROC_KEY}" c.)
    grep -q $hash $TMP/seen && return 0;
    echo $hash >>$TMP/seen
    for h in $($DATA_P key ..$hash "n.$PROC_KEY")
    do
        _list_children $h "$(( $depth + 1 ))" "$index" "$focus"
        index=$(( $index + 1 ))
    done
}
    
_get_membership () {
    local hash=$1
    _list_groups | \
    while read group
    do
        $DATA_I sfind ..$CONF_HASH ..$hash "$GROUP_KEY$group" >/dev/null \
            && echo $group
    done | sort | uniq
}    

_add_header () {
    local header=${2:-''}
    local width=${3:-10}
    local s=$(printf 's/^/%-*.*s/' "$header" "$width" "$width")
    sed "$s" $1
}

_tops () {
    $DATA_P list-hashes >$TMP/tops
    while read h
    do
        cat $TMP/tops | _get_parents $h 
    done <$TMP/tops | sort | uniq
}

_display_plan () {
    local hash=$1
    _get_membership $hash
    _list_children $hash | $DATA_P append @"$NAME_KEY"
    $DATA_P bool ..$hash "n.$STAT_KEY" 
    $DATA_P list-hashes | _get_parents $hash
}

_set_ref () {
    local hash=$1; local rname="$2"
    $DATA_I ref-add ..$CONF_HASH ..$hash "n.$REF_KEY" "n.$rname"
}

_get_ref () {
    $DATA_I ref ..$CONF_HASH "n.$REF_KEY" "n.$1"
}

_rm_ref () {
    $DATA_I ref-remove ..$CONF_HASH "n.$REF_KEY" "$1"
}

_organize () {
    local hash=$1
    $DATA_P key ..$hash "n.$PROC_KEY" | $DATA_P append "@$NAME_KEY" | tee $TMP/proc
    $EDITOR $TMP/proc
    cat $TMP/proc | cut -d'|' -f1 | $DATA_P set ..$hash "n.$PROC_KEY" >/dev/null
    while read l
    do
        h=$(echo $l | cut -d'|' -f1)
        echo $l | cut -d'|' -f2 | xargs | $DATA_P set ..$h "n.$NAME_KEY" >/dev/null
    done <$TMP/proc
}    

_add_to_history () {  # TODO
    local hash=$1
    echo $hash >>$PDIR/history
    tail -n$HSIZE $PDIR/history | cat -n - | sort -k2 -u | sort -n \
        | xargs -L1 | cut -d' ' -f2 >$TMP/histcull
    cp $TMP/histcull $PDIR/history
}

_handle_plan () {
    local header=$($CORE make-header plan "$2")
    hash=$(_parse_plan "$1") || { $CORE err-msg "$hash" "$header" $?; exit 1 ;}
}


_handle_ref () {
    local header=$($CORE make-header ref "$2")
    ref=$($DATA_I parse-refname ..$CONF_HASH "n.$REF_KEY" "$1") \
            || { $CORE err-msg "$ref" "$header" $?; exit 1 ;}
}

_handle_plan_ref () {
    _handle_plan "$1" "$3"
    _handle_ref "$2" "$3"
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
    
test -n "$1" && { cmd=$1; shift ;}
case ${cmd:-''} in
rm-ref)
    _handle_ref "$@"
    $DATA_I ref-remove ..$CONF_HASH "n.$REF_KEY" "$ref"
    ;;
open) 
    _handle_plan "$@"
    _set_ref $hash $OPEN_KEY
    ;;
show-plan)
    _handle_plan "$@"
    _display_plan $hash
    ;;
show-list)
    _handle_plan "$@"
    _list_children $hash
    ;;
show-tree)
    _handle_plan "$@"
    _list_children $hash | \
    while read hline
    do
        h=$(echo $hline | cut -d'|' -f1 | xargs -L1)
        depth=$(( $(echo $hline | cut -d'|' -f2 | xargs -L1) + 1 ))
        focus=$(echo $hline | cut -d'|' -f3 | xargs -L1)
        name=$($DATA_P key ..$h "n.$NAME_KEY")
        header=$(printf '..%.0s' $(seq $depth))
        printf '%s [%s] %7.7s %s\n' $header ${focus:-' '} $h "$name"
    done
    ;;
show-group)
    _handle_group "$@"
    $DATA_I key ..$CONF_HASH "n.$GROUP_KEY$group" | $DATA_P append @"$NAME_KEY"
    ;;
show-history)
    echo foo
    ;;
organize)
    _handle_plan "$@"
    _organize $hash
    ;;
ref)
    _handle_plan_ref "$@"
    $DATA_I ref-add ..$CONF_HASH ..$hash "n.$REF_KEY" "$ref"
    ;;
status)
    _handle_plan "$1"
    $DATA_P bool ..$hash "n.$STAT_KEY" "$2"
    ;;
add)
    _handle_target_source "$1" "$2"
    $DATA_P linsert ..$target ..$source "n.$PROC_KEY" ${3:-e.1}
    ;;
remove)
    _handle_target_source "$@"
    $DATA_P lrem ..$target ..$source "n.$PROC_KEY"
    ;;
advance)
    _handle_plan "$1"
    $DATA_P lpos ..$hash "n.$PROC_KEY" "$2"
    ;;
move)
    _handle_target_source_destination "$@"
    $DATA_P linsert ..$destination ..$source "n.$PROC_KEY" ${4:-e.1}
    $DATA_P lrem ..$target ..$source "n.$PROC_KEY"
    ;;
member)
    _handle_plan_group "$@"
    $DATA_I sfind ..$CONF_HASH ..$hash "$GROUP_KEY$group"
    ;;
group)
    _handle_plan_group "$@"
    $DATA_I sadd ..$CONF_HASH ..$hash "$GROUP_KEY$group"
    ;;
ungroup)
    _handle_plan_group "$@"
    $DATA_I srem ..$CONF_HASH ..$hash "$GROUP_KEY$group"
    ;;

archive)
    file=$(readlink -f ${1:-$HOME}/plan_archive_$(basename "$PWD").tgz)
    cd "$PDIR"
    tar -czf "$file" .
    ;;
name)
    _handle_plan "$1"
    test -n "$1" && shift
    echo "$@" | $DATA_P set ..$hash "n.$NAME_KEY"
    ;;
help)
    echo you are currently helpless
    ;;
parse-plan)
    _handle_plan "$@"
    echo $hash
    ;;
append)
    $DATA_P append "$@"
    ;;
*)
    _handle_plan "$@"
    test -n "$1" && shift
    $DATA_P "$cmd" ..$hash "$@"
    ;;
esac

