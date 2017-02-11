#!/bin/sh

CORE=./core.sh
TMP=$(mktemp -d)
trap 'rm -Rf $TMP' EXIT

HSIZE=100
PDIR=.plans
echo "$1" | grep -q "^-D" && { PDIR=$(echo "$1" | cut -c3-); shift ;}
test -d "$PDIR" || mkdir -p "$PDIR"

DATA="./data.sh -D$PDIR"

NAME_KEY=__n_
GROUP_KEY=__g_
DESC_KEY=__d_
STASH_KEY=__s_ 
PROC_KEY=__p_ 
PURSUIT_KEY=__r_
STAT_KEY=__b_
OPEN_KEY=__o_
KEY_M='^__._'


CONF_HASH=$(printf '0%.0s' $(seq 40))
echo config | $DATA ..set ..$CONF_HASH "n.$NAME_KEY" >/dev/null
OPEN=$($DATA ..show-ref ..$CONF_HASH n.$PURSUIT_KEY \
       n.$OPEN_KEY | cut -d'|' -f1)


_parse_plan () {
    local hash=''
    local h="$1"
    test -n "$h" && shift
    local prefix=$(echo "$h" | cut -c-2)
    local pattern=$(echo "$h" | cut -c3-)
    test -z "$pattern" && pattern='.*'  # TODO set in case
    case "$prefix" in
    _.)
        hash=$($DATA ..id "m.$NAME_KEY:$pattern")
        ;;
    r.) 
        hash=$($DATA ..show-ref ..$CONF_HASH n.$PURSUIT_KEY "k.$pattern")
        ;;
    n.)
        test "$pattern" = '.*' && pattern=''
        hash=$($DATA ..id n.)
        echo "$pattern" | $DATA ..set ..$hash "n.$NAME_KEY" >/dev/null
        ;;
    o.)  
        hash=$OPEN
        ;;
    i.)
        test "$pattern" = '.*' && pattern='0'
        hash=$($DATA ..at-index-list ..$OPEN "n.$PROC_KEY" "$pattern")
        ;;
    p.)
        test "$pattern" = '.*' && pattern=''
        _parse_plan "$pattern" >$TMP/parents_all
        _get_parents $OPEN >$TMP/parents
        hash=$(grep -f $TMP/parents  $TMP/parents_all)
        ;;
    c.)
        test "$pattern" = '.*' && pattern=''
        _parse_plan "$pattern" >$TMP/children_all
        $DATA ..show-set ..$OPEN "n.$PROC_KEY" >$TMP/children
        hash=$(grep -f $TMP/children  $TMP/children_all)
        ;;
    s.)
        test "$pattern" = '.*' && pattern=''
        _parse_plan "$pattern" >$TMP/stash_all
        $DATA ..show-set ..$CONF_HASH "n.$STASH_KEY" >$TMP/stash
        hash=$(grep -f $TMP/stash $TMP/stash_all)
        ;;
    h.) # TODO
        echo foo
        ;;
    *) 
        hash=$($DATA ..id "$h")
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
            $DATA ..key ..$CONF_HASH "n.$GROUP_KEY$pattern" >/dev/null
            group="$pattern"
        fi
        ;;
    m.) 
        pattern=${pattern:-'.*'}
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
    $DATA ..parse-key ..$CONF_HASH | grep "^$GROUP_KEY" | cut -c5-
}

_get_parents () {
    local hash=$1
    for h in $($DATA ..list-hashes)
    do
        $DATA ..show-set ..$h "n.$PROC_KEY" | grep -q $hash && echo $h 
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
        $DATA ..bool ..$hash n.$STAT_KEY >/dev/null && stat='-' 
        test $depth -ge $max && return 0
        $DATA ..index-set ..$CONF_HASH ..$hash n.$PURSUIT_KEY >/dev/null \
            && pursuit='-'
        echo $hash | $DATA ..append "$depth" 2 | $DATA ..append "$iout" 2 \
            | $DATA ..append "$pursuit" 2 | $DATA ..append "$stat" 2 \
            | $DATA ..append "$seen" 2 | $DATA ..append "$index" 3
        focus=$($DATA ..parse-index ..$hash "n.${PROC_KEY}" c.)
    else
        echo $hash
    fi
    test "$seen" != '.' && return 0
    echo $hash >>$TMP/seen
    index=1
    for h in $($DATA ..key ..$hash "n.$PROC_KEY")
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
        $DATA ..index-set ..$CONF_HASH ..$hash "$GROUP_KEY$group" >/dev/null \
            && echo $group
    done | sort | uniq
}    

_clean_data () {  # TODO
    echo not implemented
}

_tops () {
    $DATA ..list-hashes >$TMP/tops
    while read h
    do
        cat $TMP/tops | _get_parents $h 
    done <$TMP/tops | sort | uniq
}

_display_plan () {
    local hash=$1; local depth=${2:-2}
    printf '\u254f%s\u254f\n' refs
    printf '  %s\n' $($DATA ..key ..$CONF_HASH n.$PURSUIT_KEY \
                      | grep $hash | cut -d'|' -f2)
    printf '\u254f%s\u254f\n' groups
    printf '  %s\n' $(_get_membership $hash)
    printf '\u254f%s\u254f\n' children
    _show_tree $hash $depth | xargs -Ixx printf '  %s\n' "xx"
    printf '\u254f%s\u254f\n' status
    printf '  %s\n' $($DATA ..bool ..$hash "n.$STAT_KEY")
#    printf '\u254f%s\u254f\n' parents
#    $DATA ..list-hashes | _get_parents $hash \
#        | xargs -Ixx printf '  %s\n' "xx"
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
        local name=$($DATA ..key ..$h "n.$NAME_KEY")
        test "$pursuit" != '.' && name="[$name]"
        local header=''
        test $depth -ge 1 && header=$header$(printf \
            '\u255F\u2508\u2508%.0s' $(seq $depth))
        local st=$(printf '%1.1s' "$status" "$focus")
        local cart=$(printf '%s\u2553\u2524%2.2d %s %s' "$header" $index $st "$name")
        printf '%7.7s %-75.75s\n' $h "$cart"
        $DATA ..key ..$h "n.$DESC_KEY" | sed 's/^/     /'
    done
}

_organize () {
    local hash=$1; local key="$2"
    $DATA ..key ..$hash "n.$key" | $DATA ..append "@$NAME_KEY" 88 \
        | sed 's/[[:space:]]*|$//' >$TMP/proc
    $EDITOR $TMP/proc
    cat $TMP/proc | cut -d'|' -f1 | $DATA ..set ..$hash "n.$key" >/dev/null
    while read l
    do
        h=$(echo $l | cut -d'|' -f1)
        echo $l | cut -d'|' -f2 | xargs | $DATA ..set ..$h "n.$NAME_KEY" >/dev/null
    done <$TMP/proc
}    

_show_set () {
    local hash=$1; local key="$2"; local depth=${3:-1}
    $DATA ..show-set ..$hash "n.$key" | $DATA ..append @$NAME_KEY
}

_add_to_history () {  # TODO
    local hash=$1
    echo $hash >>$PDIR/history
    tail -n$HSIZE $PDIR/history | cat -n - | sort -k2 -u | sort -n \
        | xargs -L1 | cut -d' ' -f2 >$TMP/histcull
    cp $TMP/histcull $PDIR/history
}

_show_or_set () {
    local hash="$1"; shift
    local key="$1"; shift
    case "$1" in
    '') 
        $DATA ..key ..$hash "n.$key"
        ;;
    -)
        $DATA ..set ..$hash "n.$key"
        ;;
    e)
        $DATA ..edit ..$hash "n.$key"
        ;;
    a)  
        shift
        local prev=$($DATA ..key ..$hash "n.$key")
        printf '%s\n' "$prev" "$*" | $DATA ..set ..$hash "n.$key"
        ;;
    *)
        echo "$@" | $DATA ..set ..$hash "n.$key"
        ;;
    esac
}

_open () {
    test -z "$1" && return 1
    local hash=$1
    $DATA ..add-ref ..$CONF_HASH ..$hash n.$PURSUIT_KEY n.$OPEN_KEY
    OPEN=$hash
}

_handle_plan () {
    local header=$($CORE make-header plan "$2")
    hash=$(_parse_plan "$1") || { $CORE err-msg "$hash" "$header" $?; exit 1 ;}
}


_handle_pursuit () {
    local header=$($CORE make-header pursuit "$2")
    pursuit=$($DATA ..parse-refname ..$CONF_HASH n.$PURSUIT_KEY "$1") \
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


cmd=$($CORE parse-cmd "$0" "$1") || { $CORE err-msg "$cmd" \
        "$($CORE make-header command plan)" $?; exit $? ;}
test -n "$1" && shift
case ${cmd:-''} in
open)
    _handle_plan "$@"
    _open $hash
    ;;
status)
    $DATA ..bool ..$OPEN "n.$STAT_KEY" "$2"
    ;;
name)
    _handle_plan "$@"
    test -n "$1" && shift
    _show_or_set $hash "$NAME_KEY" "$@"
    ;;
description)
    _handle_plan "$@"
    test -n "$1" && shift
    _show_or_set $hash "$DESC_KEY" "$@"
    ;;
show-plan)
    _display_plan $OPEN "$@"
    ;;
advance)
    $DATA ..cursor-list ..$OPEN "n.$PROC_KEY" "$@"
    ;;
edit-pursuits)
    $DATA ..edit ..$CONF_HASH n.$PURSUIT_KEY
    ;;
edit-goals)
    echo not-implemented
    # this should allow editing the full set of hashes or subsets
    ;;
edit-history)
    echo not-implemented
    # two stacks: recency and use count?
    ;;
edit-procedure)
    _organize $OPEN $PROC_KEY 
    ;;
edit-stash)
    _organize $CONF_HASH $STASH_KEY
    ;;
pursuit)
    _handle_plan_pursuit "$@"
    _open $hash
    $DATA ..add-ref ..$CONF_HASH ..$hash "n.$PURSUIT_KEY" "n.$pursuit"
    ;;
add)
    _handle_plan "$@"
    group=$($DATA ..key ..$OPEN $NAME_KEY)
    $DATA ..add-set ..$CONF_HASH ..$hash "n.$GROUP_KEY$group" >/dev/null
    $DATA ..add-list ..$OPEN ..$hash "n.$PROC_KEY" ${3:-e.1}
    ;;
stash)
    hash=$($DATA ..id n.)
    echo "$*" | $DATA ..set ..$hash "n.$NAME_KEY" >/dev/null
    $DATA ..add-set ..$CONF_HASH ..$hash "n.$STASH_KEY"
    ;;
remove-pursuit)
    _handle_pursuit "$@"
    $DATA ..remove-ref ..$CONF_HASH n.$PURSUIT_KEY "n.$pursuit"
    ;;
remove-goals)
    echo not-implemented
    # idea is to be different from delete and reversable
    ;;
remove)
    _handle_plan "$@"
    $DATA ..remove-list ..$OPEN ..$hash "n.$PROC_KEY"
    ;;
show-pursuits)
    $DATA ..show-refs $CONF_HASH n.$PURSUIT_KEY | \
    while read pursuit
    do
        h=$(echo $pursuit | cut -d'|' -f1)
        n=$(echo $pursuit | cut -d'|' -f2)
        echo $n
        echo $h | $DATA ..append @$NAME_KEY 23
        echo
    done
    ;;
show-goals)
    $DATA ..list-hashes | $DATA ..append @$NAME_KEY 23
    ;;
show-history)
    echo not-implemented
    ;;
show-groups)
    _list_groups |
    while read group
    do
        echo $group
        _show_set $CONF_HASH $GROUP_KEY$group "$@"
    done    
    ;;
show)
    _show_tree $OPEN 
    ;;
show-stash)
    _show_set $CONF_HASH $STASH_KEY "$@"
    ;;
move)
    _handle_target_source "$@"
    $DATA ..remove-list ..$target ..$source "n.$PROC_KEY"
    $DATA ..add-list ..$OPEN ..$source "n.$PROC_KEY" ${3:-e.1}
    ;;
overview)
    echo pursuits >$TMP/pursuits
    printf '  %s\n' "$($DATA ..show-set ..$CONF_HASH n.$PURSUIT_KEY \
                       | cut -d'|' -f2)" >>$TMP/pursuits
    echo groups >$TMP/groups
    printf '  %s\n' "$(_list_groups)" >>$TMP/groups
    paste -d^ $TMP/pursuits $TMP/groups | column -t -s^ -o "$(printf ' \u257f ')"
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
    $DATA ..append "$@"
    ;;
*)
    _handle_plan "$@"
    test -n "$1" && shift
    $DATA .."$cmd" ..$hash "$@"
    ;;
esac

