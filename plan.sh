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
STASH_KEY=__s_ 
PROC_KEY=__p_ 
PURSUIT_KEY=__r_
STAT_KEY=__b_
OPEN_KEY=__o_
KEY_M='^__._'

HEADER=$(printf '%s| %%23.23s |\\n' $(printf '-%.0s' $(seq 40)))
CONF_HASH=$(printf '0%.0s' $(seq 40))
echo config | $DATA ..set ..$CONF_HASH "$NAME_KEY" >/dev/null
OPEN=$($DATA ..show-ref ..$CONF_HASH $PURSUIT_KEY $OPEN_KEY \
       | cut -d'|' -f1)

_parse_plan () {
    local hash=''
    local h="$1"
    test -n "$h" && shift
    local prefix=$(echo "$h" | cut -c-2)
    local pattern=$(echo "$h" | cut -c3-)
    case "$prefix" in
    _.)
        hash=$($DATA ..id "m.$NAME_KEY:$pattern")
        ;;
    r.) 
        hash=$($DATA ..show-ref ..$CONF_HASH $PURSUIT_KEY "$pattern")
        ;;
    n.)
        hash=$($DATA ..id n.)
        echo "$pattern" | $DATA ..set ..$hash "$NAME_KEY" >/dev/null
        ;;
    o.)  
        hash=$OPEN
        ;;
    i.)
        test "$pattern" = '.*' && pattern='0'
        hash=$($DATA ..at-index-list ..$OPEN "$PROC_KEY" "$pattern")
        ;;
    p.)
        _parse_plan "$pattern" >$TMP/parents_all
        _get_parents $OPEN >$TMP/parents
        hash=$(grep -f $TMP/parents  $TMP/parents_all \
               | $DATA ..append @$NAME_KEY)
        ;;
    t.)
        _parse_plan "$pattern" >$TMP/tops_all
        _tops >$TMP/tops_m
        hash=$(grep -f $TMP/tops_m $TMP/tops_all \
               | $DATA ..append @$NAME_KEY)
        ;;
    c.)  # TODO all children?
        _parse_plan "$pattern" >$TMP/children_all
        $DATA ..show-set ..$OPEN "$PROC_KEY" >$TMP/children
        hash=$(grep -f $TMP/children  $TMP/children_all \
               | $DATA ..append @$NAME_KEY)
        ;;
    s.)
        _parse_plan "$pattern" >$TMP/stash_all
        $DATA ..show-set ..$CONF_HASH "$STASH_KEY" >$TMP/stash
        hash=$(grep -f $TMP/stash $TMP/stash_all \
               | $DATA ..append @$NAME_KEY)
        ;;
    g.) 
        local name="${pattern%%.*}"
        pattern="${pattern#*.}"
        _parse_plan "$pattern" | cut -d'|' -f1 >$TMP/group_all
        _parse_group "$name" >$TMP/group_names
        while read g
        do
            $DATA ..show-set ..$CONF_HASH "$GROUP_KEY$g" | \
                $DATA ..append "$g" | \
                $DATA ..append @$NAME_KEY >>$TMP/group_tmp
        done <$TMP/group_names
        <$TMP/group_tmp sort | uniq  >$TMP/group
        hash=$(grep -f $TMP/group_all $TMP/group)
        ;;
    *) 
        hash=$($DATA ..id "$h")
        ;;
    esac
    $CORE return-parse "$hash" "$h" 
}

_parse_group () { 
    local group=''
    local pattern="${1:-.*}"
    group=$(_list_groups | grep "$pattern")
    $CORE return-parse "$group" "$1"
}

_parse_note () {
    local note=''
    local pattern="${1:-.*}"
    note=$($DATA ..parse-key ..$OPEN \
           | grep -v "$KEY_M" | grep "$pattern")
    test -z "$note" && test -n "$1" && note="$1"
    $CORE return-parse "$note" "$1"
}

_output_header () {
    echo $CONF_HASH | $DATA ..append "depth" | $DATA ..append "focus" \
        | $DATA ..append "pursuit"  | $DATA ..append "stat" \
        | $DATA ..append "seen"  | $DATA ..append "index" | $DATA ..append @$NAME_KEY
}

_list_groups () {
    local g=$($DATA ..parse-key ..$CONF_HASH | grep "^$GROUP_KEY" | cut -c5-)
    printf '%s\n' "$g"
}

_get_parents () {
    local hash=$1
    for h in $($DATA ..list-hashes)
    do
        $DATA ..show-set ..$h "$PROC_KEY" | grep -q $hash && echo $h 
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
        $DATA ..bool ..$hash $STAT_KEY >/dev/null && stat='-' 
        test $depth -ge $max && return 0
        $DATA ..index-set ..$CONF_HASH ..$hash $PURSUIT_KEY >/dev/null \
            && pursuit='-'
        echo $hash | $DATA ..append "$depth" | $DATA ..append "$iout" \
            | $DATA ..append "$pursuit"  | $DATA ..append "$stat" \
            | $DATA ..append "$seen"  | $DATA ..append "$index" \
            | $DATA ..append @$NAME_KEY
        focus=$($DATA ..parse-index ..$hash "${PROC_KEY}" c.)
    else
        echo $hash
    fi
    index=1
    test "$seen" != '.' && return 0
    echo $hash >>$TMP/seen
    for h in $($DATA ..key ..$hash "$PROC_KEY")
    do
        _list_children $h $max "$(( $depth + 1 ))" "$index" "$focus"
        index=$(( $index + 1 ))
    done
}
    
_get_membership () {
    local hash=$1
    _list_groups | \
    while read  group
    do
        $DATA ..index-set ..$CONF_HASH ..$hash "$GROUP_KEY$group" >/dev/null \
            && echo $group
    done | sort | uniq
}    

_display_plan () {
    local hash=$1; local depth=${2:-2}
    printf "$HEADER" name
    $DATA ..key ..$hash $NAME_KEY
    printf "$HEADER" groups
    _get_membership $hash
    printf "$HEADER" procedure
    $DATA ..key ..$hash $PROC_KEY | \
    while read child
    do
        _show_tree $child
    done
    printf "$HEADER" status
    $DATA ..bool ..$hash "$STAT_KEY"
}

_show_tree () {
    local hash=$1; local max=$2; _IFS="$IFS"
    _list_children $hash $max | \
    while read hline
    do
        IFS='|'
        set $hline
        local h="$1"; local depth="$2"; local focus="$3"
        local pursuit="$4"; local status="$5"; local seen="$6"
        local index="$7"; local name="$8"
        IFS="$_IFS"
        test "$pursuit" != '.' && name="[$name]"
        local header=''
        test $depth -ge 1 && header=$header$(printf \
            '|--%.0s' $(seq $depth))
        local st=$(printf '%1.1s' "$status" "$focus")
        local cart=$(printf '%s|> (%2.2d) %s %s' "$header" $index $st "$name")
        test "$seen" = '.' || { printf '%7.7s<%-75.75s\n' $h "$cart"; continue ;}
        printf '%7.7s %-75.75s\n' $h "$cart"
    done
}

_organize () {
    local hash=$1; local key="$2"
    $DATA ..key ..$hash "$key" | $DATA ..append "@$NAME_KEY" >$TMP/proc
    $EDITOR $TMP/proc
    cat $TMP/proc | cut -d'|' -f1 | $DATA ..set ..$hash "$key" >/dev/null
    while read l
    do
        h=$(echo $l | cut -d'|' -f1)
        echo $l | cut -d'|' -f2 | xargs | $DATA ..set ..$h "$NAME_KEY" >/dev/null
    done <$TMP/proc
    $DATA ..show-set ..$hash "$key" | \
    while read h
    do
        _show_tree $h
    done
}    

_show_keys () {
    local hash=$1
    local key="$2"
    for h in $(_list_children $hash)
    do
        test '.' != $(echo "$h" | cut -d'|' -f6) && continue
        local data=$($DATA ..key ..$h "$key")
        test -z "$data" && continue
        printf "$HEADER" "$($DATA ..key ..$h $NAME_KEY)"
        printf '%s\n' "$data"
    done
}

_show_or_set () {
    local hash="$1"; shift
    local key="$1"; shift
    case "$1" in
    '') 
        $DATA ..key ..$hash "$key"
        return 0  # TODO early leave
        ;;
    -)
        $DATA ..set ..$hash "$key"
        ;;
    e)
        $DATA ..edit ..$hash "$key"
        ;;
    a)  
        shift
        local prev=$($DATA ..key ..$hash "$key")
        printf '%s\n' "$prev" "$*" | $DATA ..set ..$hash "$key"
        ;;
    *)
        echo "$@" | $DATA ..set ..$hash "$key"
        ;;
    esac
    $DATA ..key ..$hash "$key"
}

_tops () {
    truncate -s 0 $TMP/tops_
    for h in $($DATA ..list-hashes)
    do
        $DATA ..show-list ..$h $PROC_KEY >>$TMP/tops_
    done
    cat $TMP/tops_ | sort | uniq >$TMP/tops
    $DATA ..list-hashes | grep -v -f $TMP/tops  | grep -v $CONF_HASH 
}

_open () {
    test -z "$1" && return 1
    local hash=$1
    $DATA ..add-ref ..$CONF_HASH ..$hash $PURSUIT_KEY $OPEN_KEY \
        | $DATA ..append @$NAME_KEY
    OPEN=$hash
}

_handle_plan () {
    local header=$($CORE make-header plan "$2")
    hash=$(_parse_plan "$1") || { $CORE err-msg "$hash" "$header" $?; exit 1 ;}
}


_handle_pursuit () {
    local header=$($CORE make-header pursuit "$2")
    pursuit=$($DATA ..parse-refname $CONF_HASH $PURSUIT_KEY "$1") \
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

_handle_pursuit_group () {
    _handle_pursuit "$1" "$3"
    _handle_group "$2""$3"
}

_handle_note () {
    local header=$($CORE make-header note "$2")
    note=$(_parse_note "$1") \
        || { $CORE err-msg "$note" "$header" $?; exit 1 ;}
}

_sort () {
    sort -t'|' -k${1:-2}
}

_table () {
    column -s'|' -t -o'  ][  '
}

echo "$1" | grep -q '^\-o' && { _handle_plan "$(echo $1 | cut -c3-)" \
                              && OPEN=$hash; shift ;}
unset hash # maybe neurotic. 

cmd=$($CORE parse-cmd "$0" "$1") || { $CORE err-msg "$cmd" \
        "$($CORE make-header command plan)" $?; exit $? ;}

test -n "$1" && shift
case ${cmd:-''} in
open) # plan -> Null
    _handle_plan "$@"
    _open $hash >/dev/null
    ;;
status) # true|false|toggle|'' -> true|false
    $DATA ..bool ..$OPEN $STAT_KEY "$1"
    ;;
name) # plan -> (''|-|a|e text)|text -> text
    _handle_plan "$@"
    test -n "$1" && shift
    _show_or_set $hash $NAME_KEY "$@"
    ;;
plan) # -> { name, groups, procedure, status }
    _display_plan $OPEN
    ;;
tree) # [depth] -> tree
    _show_tree $OPEN "$@"
    ;;
advance) # [index] -> index
    $DATA ..cursor-list ..$OPEN $PROC_KEY "$@"
    ;;
delete) # plan -> Null
    _handle_plan "$@"
    for h in $($DATA ..list-hashes)
    do
        $DATA ..remove-list ..$h ..$hash $PROC_KEY >/dev/null
    done
    for g in $(_list_groups)
    do
        $DATA ..remove-set ..$CONF_HASH ..$hash "$GROUP_KEY$g" >/dev/null 
    done
    $DATA ..remove-list ..$CONF_HASH ..$hash $STASH_KEY >/dev/null
    $DATA ..remove-ref ..$CONF_HASH $PURSUIT_KEY $hash >/dev/null
    $DATA ..delete $hash >/dev/null
    ;;
complete) # -> Null
    h=$($DATA ..at-index-list ..$OPEN $PROC_KEY c.)
    $DATA ..bool ..$h $STAT_KEY true >/dev/null
    $DATA ..cursor-list ..$OPEN $PROC_KEY  >/dev/null
    ;;
edit-procedure) # M => editor -> tree
    _organize $OPEN $PROC_KEY 
    ;;
edit-stash) # M => editor -> tree
    _organize $CONF_HASH $STASH_KEY
    ;;
pursuit) # plan -> pursuit -> Null
    _handle_plan_pursuit "$@"
    _open $hash >/dev/null
    pursuit_hash=$(_parse_plan "r.$pursuit")
    test "$?" -eq 1 && pursuit_hash=$(_parse_plan "n.$pursuit")
    $DATA ..add-ref ..$CONF_HASH ..$pursuit_hash "$PURSUIT_KEY" "$pursuit" >/dev/null
    $DATA ..add-set ..$CONF_HASH ..$hash "$GROUP_KEY$pursuit" >/dev/null
    $DATA ..add-list ..$pursuit_hash ..$hash $PROC_KEY  >/dev/null
    ;;
add) # plan -> Null
    _handle_plan "$@"
    group=$($DATA ..key ..$OPEN $NAME_KEY)
    $DATA ..remove-list ..$CONF_HASH ..$hash $STASH_KEY >/dev/null
    $DATA ..add-set ..$CONF_HASH ..$hash "$GROUP_KEY$group" >/dev/null
    $DATA ..add-list ..$OPEN ..$hash "$PROC_KEY" ${2:-e.1} >/dev/null
    ;;
groups) # -> group -> tree
    _handle_group "$@"
    printf "$HEADER"  "$group"
    for h in $($DATA ..show-list ..$CONF_HASH "$GROUP_KEY$group")
    do
        _show_tree $h
    done
    ;;
stash) # [text] -> Null
    hash=$($DATA ..id n.)
    echo "$*" | $DATA ..set ..$hash "$NAME_KEY" >/dev/null
    $DATA ..add-set ..$CONF_HASH ..$hash "$STASH_KEY" >/dev/null
    ;;
remove-pursuit) # pursuit -> Null
    _handle_pursuit "$@"
    $DATA ..remove-ref ..$CONF_HASH $PURSUIT_KEY "$pursuit" >/dev/null
    ;;
remove) # plan -> Null
    _handle_plan "$@"
    $DATA ..remove-list ..$OPEN ..$hash "$PROC_KEY" >/dev/null
    ;;
show-stash) # -> table 
    $DATA ..show-set ..$CONF_HASH "$STASH_KEY" \
        | $DATA ..append @$NAME_KEY | _table
    ;;
move) # plan -> plan -> Null
     _handle_target_source "$@"
    $DATA ..remove-list ..$target ..$source "$PROC_KEY" >/dev/null
    $DATA ..add-list ..$OPEN ..$source "$PROC_KEY" ${3:-e.1} >/dev/null
    ;;
tops) # -> table
    _tops | while read h
    do
        _list_children $h | sed "1i$(_output_header)" |  _table
    done
    ;;
overview) # pursuit -> tree
    _handle_pursuit "$@"
    _show_tree $($DATA ..show-ref ..$CONF_HASH $PURSUIT_KEY "$pursuit" \
                 | cut -d'|' -f1)
    ;;
edit-note) # note -> (''|-|a|e text)|text -> text
    _handle_note "$1"; shift
    _show_or_set $OPEN "$note" "$@" 
    ;;
show-note) # note -> key-list
    _handle_note "$1"; shift
    _show_keys $OPEN "$note" "$@"
    ;;
archive) # [directory] -> tarball
    file=${1:-$HOME}/$(basename "$PWD")-$(date -I +%a-%d-%m-%Y).pa.tgz
    cd "$PDIR"
    tar -czf "$file" .
    ;;
help)
    echo you are currently helpless
    ;;
parse-plan)
    _parse_plan "_.$@"
    ;;
parse-group)
    _parse_group "$@"
    ;;
append)
    $DATA ..append "$@"
    ;;
table)
    _table
    ;;
sort)
    _sort "$@"
    ;;
xx)
    _output_header
    _list_children $OPEN 
    ;;
*)
    _handle_plan "$@"
    test -n "$1" && shift
    $DATA .."$cmd" $hash "$@"
    ;;
esac

