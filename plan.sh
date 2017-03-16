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
OPEN_KEY=__g_
PROC_KEY=__p_ 
STAT_KEY=__b_
OPEN_REF=__o_
KEY_M='^__._'

MARK='+'
UNMARK='.'
HBAR=60
CONF_HASH=$(printf '0%.0s' $(seq 40))
echo config | $DATA set ..$CONF_HASH "..$NAME_KEY" >/dev/null

_parse_plan () {
    local hash=''
    local h="$1"
    test -n "$h" && shift
    local prefix=$(echo "$h" | cut -c-2)
    local pattern=$(echo "$h" | cut -c3-)
    case "$prefix" in
    n.)
        hash=$($DATA id n.)
        echo "$pattern" | $DATA set ..$hash "..$NAME_KEY" >/dev/null
        ;;
    _.)
        hash=$($DATA id "m.$NAME_KEY:$pattern")
        test $? -eq 1 && hash=""
        ;;
    s.)
        if test -z "$pattern"
        then
            hash=$CONF_HASH
        else
            hash=$(_parse_plan c.$CONF_HASH:"$pattern")
        fi
        ;;
    o.)  
        if test -z "$pattern"
        then
            hash=$($DATA show-ref ..$CONF_HASH ..$OPEN_KEY ..$OPEN_REF \
                   | cut -d'|' -f2)
        else
            local _h=''
            _h=$($DATA show-ref ..$CONF_HASH ..$OPEN_KEY "$pattern")
            case $? in
            0)
                hash=$(echo "$_h" | cut -d'|' -f2)
                ;;
            1)  hash='' ;;
            *)
                hash="$_h"
                ;;
            esac
        fi
        ;;
    i.)
        echo "$pattern" | grep -q ':' || pattern="$pattern:"
        local parent=$(echo "$pattern" | cut -d':' -f1)
        local index=$(echo "$pattern" | cut -d':' -f2)
        local _h=''
        _h=$(_parse_plan "$parent")
        case $? in
        0)
            hash=$($DATA at-index-list ..$_h "..$PROC_KEY" "$index")
            ;;
        1)  hash='' ;;
        *)
            hash="$_h"
            ;;
        esac
        ;;
    c.)
        echo "$pattern" | grep -q ':' || pattern="$pattern:"
        local parent=$(echo "$pattern" | cut -d':' -f1)
        local child=$(echo "$pattern" | cut -d':' -f2)
        _parse_plan "${child:-_.}"  >$TMP/children_all
        local _h=''
        _h=$(_parse_plan "$parent")
        case $? in
        0)
            $DATA show-set ..$_h "..$PROC_KEY" >$TMP/children
            hash=$(grep -f $TMP/children  $TMP/children_all)
            ;;
        1)  hash='' ;;
        *)
            hash="$_h"
            ;;
        esac   
        ;;
    p.)
        echo "$pattern" | grep -q ':' || pattern="$pattern:"
        local child=$(echo "$pattern" | cut -d':' -f1)
        local parent=$(echo "$pattern" | cut -d':' -f2)
        _parse_plan "${parent:-_.}"  >$TMP/parents_all
        local _h=''
        _h=$(_parse_plan "$child")
        case $? in
        0)
            _get_parents $_h >$TMP/parents
            if test -s $TMP/parents
            then
                hash=$(grep -f $TMP/parents  $TMP/parents_all \
                       | $DATA append @$NAME_KEY)
            else
                hash=''
            fi
            ;;
        1)
            hash=''
            ;;
        *)
            hash="$_h"
            ;;
        esac   
        ;;
    t.)
        _parse_plan "$pattern" >$TMP/tops_all
        _tops >$TMP/tops_m
        hash=$(grep -f $TMP/tops_m $TMP/tops_all \
               | $DATA append @$NAME_KEY)
        ;;
    *) 
        hash=$($DATA id "$h")
        test $? -eq 1 && hash=""
        ;;
    esac
    $CORE return-parse "$hash" "$h" 
}

_parse_note () { # TODO
    local hash="$1"; shift
    local note=''
    local pattern="${1:-.*}"
    note=$($DATA parse-key ..$hash \
           | grep -v "$KEY_M" | grep "$pattern")
    test -z "$note" && test -n "$1" && note="$1"
    $CORE return-parse "$note" "$1"
}

_headline () {
    local msg=$(printf '--[ %s ]%s' "$1" $(printf '-%.0s' $(seq 80)))
    printf "%${HBAR}.${HBAR}s -\n" "${msg}"
}
    
_header () {
    echo $CONF_HASH | $DATA append "idx" | $DATA append "cursor" \
        | $DATA append "stat" | $DATA append "seen" \
        | $DATA append "note" | $DATA append "open"
}

_data () {
    local hash=$1; local parent=$2;
    local seen=$UNMARK; local stat=$UNMARK; local note=$UNMARK; local focus=0;
    local idx=0; local cursor=$UNMARK; local open=''
    test -n "$parent" && idx=$($DATA index-list ..$parent ..$hash ..$PROC_KEY)
    test -n "$parent" && focus=$($DATA parse-index ..$parent ..$PROC_KEY c.)
    test "$focus" -eq "$idx" && test $idx -ne 0 && cursor="$MARK"
    test -f $TMP/seen || touch $TMP/seen
    grep -q $hash $TMP/seen && seen="$MARK"
    $DATA bool ..$hash ..$STAT_KEY >/dev/null && stat="$MARK" 
    _parse_note $hash >/dev/null 2>&1; test $? -ne 1 && note="$MARK"
    $DATA key ..$CONF_HASH ..$OPEN_KEY  | grep $hash >$TMP/omatch
    test -s $TMP/omatch && open=$(<$TMP/omatch cut -d'|' -f1 \
        | tr '\n' ',' | sed 's/,$//')
    echo $hash | $DATA append "$idx" | $DATA append "$cursor" \
        | $DATA append "$stat" | $DATA append "$seen" \
        | $DATA append "$note" | $DATA append "$open"
    test "$seen" != "$UNMARK" && return 1
    echo $hash >>$TMP/seen
}

_list_children () {
    local hash=$1
    local max=${2:-999}
    local depth=${3:-0}
    local parent=$4; local d=''
    test $depth -ge $max && return 0
    d=$(_data $hash $parent) 
    local ret=$?
    echo "$d" | $DATA append $depth 
    test 0 -ne $ret && return 0
    for h in $($DATA show-list ..$hash ..$PROC_KEY)
    do
        _list_children $h $max "$(( $depth + 1 ))" $hash
    done
}

_get_parents () {
    local hash=$1
    local _h=''
    for _h in $($DATA list-hashes)
    do
        $DATA show-set ..$_h "..$PROC_KEY" | grep -q $hash && echo $_h 
    done
}

_display_plan () { # TODO 
    local hash=$1; local depth=${2:-2}
    _headline name
    $DATA key ..$hash ..$NAME_KEY
    _headline open
    $DATA key ..$CONF_HASH ..$OPEN_KEY  | grep $hash | cut -d'|' -f1
    _headline procedure
    _list_children $hash $depth |  _show_tree 
    _headline status
    $DATA bool ..$hash "..$STAT_KEY"
    _headline note
    _parse_note $hash 2>/dev/null >$TMP/notes 
    test $? -eq 1 && return 0
    while read n
    do
        _headline "$n"
        _show_or_set $hash "$n"
        echo
    done <$TMP/notes
}

_show_tree () {
    _IFS="$IFS"
    while read hline
    do
        IFS='|'
        set $hline
        local header=''
        local h="$1"; local index="$2"; local cursor="$3"
        local status="$4"; local seen="$5"; local note="$6";
        local open="$7"; local depth="$8"
        IFS="$_IFS"
        { test -z "$open" && open="$UNMARK" ;} || open="$MARK"
        local name=$($DATA key ..$h ..$NAME_KEY)
        test "$seen" = "$MARK" && name="]$name["
        test "$cursor" = "$MARK" && name="[$name]"
        local statline=$(printf '%c[%s]' s "$status" \
            n "$note" o "$open")
        test $depth -ge 1 \
            && header=$header$(printf "\__%.0s" $(seq $depth))
        local tree=$(printf '%s %s' "$header" "$name")
        local l=$(printf '%7.7s %12.12s %2.2d %s' $h "$statline" "$index" "$tree")
        printf "%-${HBAR}.${HBAR}s]%s\n" "$l" 
    done
}

_organize () {
    local hash=$1; local key="$2"
    $DATA key ..$hash "..$key" | $DATA append "@$NAME_KEY" >$TMP/proc
    $EDITOR $TMP/proc
    <$TMP/proc cut -d'|' -f1 | $DATA set ..$hash "..$key" >/dev/null
    while read l
    do
        h=$(echo $l | cut -d'|' -f1)
        echo $l | cut -d'|' -f2 | xargs | $DATA set ..$h "..$NAME_KEY" >/dev/null
    done <$TMP/proc
}    

_show_or_set () {
    local hash="$1"; shift
    local key="$1"; shift
    case "$1" in
    '') : ;;
    -)
        $DATA set ..$hash "..$key"
        ;;
    e)
        $DATA edit ..$hash "..$key"
        ;;
    f)  
        shift
        echo "$@" | $DATA set ..$hash "..$key"
        ;;
    *)
        local prev=$($DATA key ..$hash "..$key")
        if test -z "$prev"
        then
            printf '%s\n' "$*" | $DATA set ..$hash "..$key"
        else
            printf '%s\n' "$prev" "$*" | $DATA set ..$hash "..$key"
        fi
        ;;
    esac
    $DATA key ..$hash "..$key"
}

_tops () {
    truncate -s 0 $TMP/tops_
    for h in $($DATA list-hashes)
    do
        $DATA show-list ..$h ..$PROC_KEY >>$TMP/tops_
    done
    <$TMP/tops_ sort | uniq >$TMP/tops
    $DATA list-hashes | grep -v -f $TMP/tops  | grep -v $CONF_HASH 
}

_open () {
    test -z "$1" && return 1
    local hash=$1
    $DATA add-ref ..$CONF_HASH ..$hash \
        ..$OPEN_KEY "..$($DATA key ..$hash ..$NAME_KEY)" >/dev/null
    $DATA add-ref ..$CONF_HASH ..$hash ..$OPEN_KEY ..$OPEN_REF
}

_handle_plan () {
    local header=$($CORE make-header plan "$2")
    hash=$(_parse_plan "$1") || { $CORE err-msg "$hash" "$header" $?; exit 1 ;}
}

_handle_target_source () {
    _handle_plan "$1" "$3"; target=$hash
    _handle_plan "$2" "$3"; source=$hash
}

_handle_target_source_dest () {
    _handle_plan "$1" "$4"; target=$hash
    _handle_plan "$2" "$4"; source=$hash
    _handle_plan "$3" "$4"; dest=$hash
}

_handle_open () {
    local header=$($CORE make-header open "$2")
    open=$($DATA parse-refname ..$CONF_HASH ..$OPEN_KEY "$1") \
           || { $CORE err-msg "$open" "$header" $?; exit 1 ;}
}

_handle_plan_note () {
    _handle_plan "$1" "$3"
    local header=$($CORE make-header note "$3")
    note=$(_parse_note $hash "$2") \
        || { $CORE err-msg "$note" "$header" $?; exit 1 ;}
}

_sort () {
    sort -t'|' -k${1:-2}
}

_table () {
    column -s'|' -t -o'  ][  '
}

cmd="$1"
test -n "$1" && shift
case ${cmd:-''} in
open) 
    _handle_plan "$@"
    _open $hash 
    ;;
show)
    _handle_plan "$@"
    _display_plan $hash
    ;;
name)
    _handle_plan "$@"
    test -n "$1" && shift
    _show_or_set $hash $NAME_KEY "$@"
    ;;
status) 
    _handle_plan "$@"; shift
    $DATA bool ..$hash ..$STAT_KEY "$1"
    ;;
procs)
    _handle_plan "$@"
    test -n "$1" && shift
    _list_children $hash "$@" | _show_tree 
    ;;
add)
    _handle_target_source "$@"
    $DATA remove-list ..$CONF_HASH ..$source ..$PROC_KEY >/dev/null
    $DATA add-list ..$target ..$source "..$PROC_KEY" ${3:-e.1} >/dev/null
    ;;
move) 
     _handle_target_source_dest "$@"
    $DATA remove-list ..$target ..$source "..$PROC_KEY" >/dev/null
    $DATA add-list ..$dest ..$source "..$PROC_KEY" ${4:-e.1} >/dev/null
    ;;
remove)
    _handle_target_source "$@"
    $DATA remove-list ..$target ..$source "..$PROC_KEY" >/dev/null
    ;;
advance)
    _handle_plan "$@"; shift
    $DATA cursor-list ..$hash ..$PROC_KEY "$@"
    ;;
complete)
    _handle_plan "$@"
    if test 0 -ne $($DATA parse-index ..$hash ..$PROC_KEY c.)
    then
        h=$($DATA at-index-list ..$hash ..$PROC_KEY c.)
        $DATA bool ..$h ..$STAT_KEY true >/dev/null
    fi
    $DATA cursor-list ..$hash ..$PROC_KEY  >/dev/null
    ;;
edit)
    _handle_plan "$@"
    _organize $hash $PROC_KEY 
    ;;
note)
    _handle_plan_note "$@"
    shift;shift
    _show_or_set $hash "$note" "$@" 
    ;;
delete-note)
    _handle_plan_note "$@"
    shift;shift
    $DATA delete-key ..$hash "$note"
    ;;
delete)
    _handle_plan "$@"
    for h in $($DATA list-hashes)
    do
        $DATA remove-list ..$h ..$hash ..$PROC_KEY >/dev/null
    done
    $DATA remove-list ..$CONF_HASH ..$hash ..$PROC_KEY >/dev/null
    $DATA key ..$CONF_HASH ..$OPEN_KEY | grep -v $hash >$TMP/o_del
    <$TMP/o_del $DATA set ..$CONF_HASH ..$OPEN_KEY
    $DATA delete ..$hash
    ;;
delete-open) 
    _handle_open "$@"
    echo $open
    $DATA remove-ref ..$CONF_HASH ..$OPEN_KEY "$open"
    ;;
stash)
    if test -z "$1" 
    then
        $DATA show-list ..$CONF_HASH "..$PROC_KEY" \
            | $DATA append @$NAME_KEY 
    else
        hash=$(_parse_plan "n.$*")
        $DATA add-list ..$CONF_HASH ..$hash "..$PROC_KEY" 0 >/dev/null
    fi
    ;;
tops)
    _tops | while read h
    do
        _list_children $h "$1" 
    done
    ;;
overview) 
    :
    ;;
archive)
    file=${1:-$HOME}/$(basename "$PWD")-$(date -I +%a-%d-%m-%Y).pa.tgz
    cd "$PDIR"
    tar -czf "$file" .
    ;;
list) 
    _handle_plan "$@"; shift
    _list_children $hash "$@"  | $DATA append @$NAME_KEY
    ;;
sort)
    _sort "$@"
    ;;
table)
    _table
    ;;
tree)
    grep -v ^$CONF_HASH | _show_tree
    ;;
help)
    echo you are currently helpless
    ;;
parse-plan)
    _parse_plan "$@"
    ;;
parse-note)
    _parse_note $OPEN "$@"; echo "$?"
    ;;
parse-open)
    $DATA parse-refname ..$CONF_HASH ..$OPEN_KEY "$1"
    ;;
append)
    $DATA append "$@"
    ;;
header)
    :
    ;;
headline)
    _headline "$*"
    ;;
*)
    _handle_plan "$@"
    test -n "$1" && shift
    $DATA $cmd ..$hash "$@"
    ;;
esac
