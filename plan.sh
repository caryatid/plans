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
NOTE_KEY=__t_
STASH_KEY=__s_ 
PROC_KEY=__p_ 
PURSUIT_KEY=__r_
STAT_KEY=__b_
OPEN_KEY=__o_
KEY_M='^__._'

HEADER=$(printf '%s| %%-23.23s |\\n' $(printf '-%.0s' $(seq 40)))

CONF_HASH=$(printf '0%.0s' $(seq 40))
echo config | $DATA ..set ..$CONF_HASH "$NAME_KEY" >/dev/null
OPEN=$($DATA ..show-ref ..$CONF_HASH $PURSUIT_KEY \
       $OPEN_KEY | cut -d'|' -f1)

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
        hash=$($DATA ..show-ref ..$CONF_HASH $PURSUIT_KEY "k.$pattern")
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
        hash=$(grep -f $TMP/parents  $TMP/parents_all | \
                $DATA ..append @$NAME_KEY)
        ;;
    c.)  # TODO all children?
        _parse_plan "$pattern" >$TMP/children_all
        $DATA ..show-set ..$OPEN "$PROC_KEY" >$TMP/children
        hash=$(grep -f $TMP/children  $TMP/children_all | \
                $DATA ..append @$NAME_KEY)
        ;;
    s.)
        _parse_plan "$pattern" >$TMP/stash_all
        $DATA ..show-set ..$CONF_HASH "$STASH_KEY" >$TMP/stash
        hash=$(grep -f $TMP/stash $TMP/stash_all | \
                $DATA ..append @$NAME_KEY)
        ;;
    g.) 
        local name="${pattern%%.*}"
        pattern="${pattern#*.}"
        _parse_plan "$pattern" | cut -d'|' -f1 >$TMP/group_all
        _parse_group "m.$name" >$TMP/group_names
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
    local g="$1"
    local prefix=$(echo "$g" | cut -c-2)
    local pattern=$(echo "$g" | cut -c3-)
    case "$prefix" in
    m.) 
        pattern=${pattern:-'.*'}
        group=$(_list_groups | grep "$pattern")
        ;;
    *)
        $DATA ..key ..$CONF_HASH "$GROUP_KEY$g" >/dev/null
        group="$g"
    esac
    $CORE return-parse "$group" "$g"
}

_parse_note () {
    local note=''
    local n="$1"
    local prefix=$(echo "$n" | cut -c-2)
    local pattern=$(echo "$n" | cut -c3-)
    case "$prefix" in
    m.) 
        pattern=${pattern:-'.*'}
        note=$($DATA ..parse-key ..$OPEN | \
            grep -v '$KEY_M' | grep "$pattern")
        ;;
    *)
        $DATA ..key ..$OPEN "$n" >/dev/null
        note="$n"
    esac
    $CORE return-parse "$note" "$n"
}

_list_groups () {
    $DATA ..parse-key ..$CONF_HASH | grep "^$GROUP_KEY" | cut -c5-
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
    test "$seen" != '.' && return 0
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
            | $DATA ..append "$seen"  | $DATA ..append "$index" 
        focus=$($DATA ..parse-index ..$hash "${PROC_KEY}" c.)
    else
        echo $hash
    fi
    echo $hash >>$TMP/seen
    index=1
    for h in $($DATA ..key ..$hash "$PROC_KEY")
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
    printf "$HEADER" name
    printf '  %s\n' "$($DATA ..key ..$hash $NAME_KEY)"
    printf "$HEADER" groups
    printf '  %s\n' $(_get_membership $hash)
    printf "$HEADER" procedure
    printf '  %s\n' "$($DATA ..key ..$hash $PROC_KEY | $DATA ..append @$NAME_KEY)"
    printf "$HEADER" status
    printf '  %s\n' $($DATA ..bool ..$hash "$STAT_KEY")
}

_show_tree () {
    local hash=$1; local max=$2
    _list_children $hash $max | \
    while read hline
    do
        local h=$(echo $hline | cut -d'|' -f1 | xargs -n1)
        local depth=$(echo $hline | cut -d'|' -f2 | xargs -n1)
        local focus=$(echo $hline | cut -d'|' -f3 | xargs -n1)
        local pursuit=$(echo $hline | cut -d'|' -f4 | xargs -n1)
        local status=$(echo $hline | cut -d'|' -f5 | xargs -n1)
        local seen=$(echo $hline | cut -d'|' -f6 | xargs -n1)
        local index=$(echo $hline | cut -d'|' -f7 | xargs -n1)
        test "$seen" = '.' || continue
        local name=$($DATA ..key ..$h "$NAME_KEY")
        test "$pursuit" != '.' && name="[$name]"
        local header=''
        test $depth -ge 1 && header=$header$(printf \
            '|--%.0s' $(seq $depth))
        local st=$(printf '%1.1s' "$status" "$focus")
        local cart=$(printf '%s|> (%2.2d) %s %s' "$header" $index $st "$name")
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
}    


_show_keys () {
    local hash=$1
    local key="$2"
    for h in $(_list_children $hash | cut -d'|' -f1)
    do
        printf "$HEADER" "$($DATA ..key ..$h $NAME_KEY)"
        $DATA ..key ..$h "$key"
        _show_keys $h "$key"
    done
}

_show_or_set () {
    local hash="$1"; shift
    local key="$1"; shift
    case "$1" in
    '') 
        $DATA ..key ..$hash "$key"
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
    pursuit=$($DATA ..parse-refname ..$CONF_HASH $PURSUIT_KEY "$1") \
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

_handle_note () {
    local header=$($CORE make-header note "$2")
    note=$(_parse_note "$1") \
        || { $CORE err-msg "$note" "$header" $?; exit 1 ;}
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
    $DATA ..bool ..$OPEN $STAT_KEY "$1"
    ;;
name)
    _handle_plan "$@"
    test -n "$1" && shift
    _show_or_set $hash $NAME_KEY "$@"
    ;;
show)
    _display_plan $OPEN "$@"
    ;;
tree)
    _show_tree $OPEN "$@"
    ;;
advance)
    $DATA ..cursor-list ..$OPEN $PROC_KEY "$@"
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
    pursuit_hash=$(_parse_plan "r.$pursuit") 
    test $pursuit_hash = $CONF_HASH && pursuit_hash=$(_parse_plan "n.$pursuit")
    group=$($DATA ..key ..$pursuit_hash $NAME_KEY)
    $DATA ..add-set ..$CONF_HASH ..$hash "$GROUP_KEY$group" >/dev/null
    $DATA ..add-ref ..$CONF_HASH ..$pursuit_hash "$PURSUIT_KEY" "$pursuit"
    $DATA ..add-list ..$pursuit_hash ..$hash $PROC_KEY 
    ;;
add)
    _handle_plan "$@"
    group=$($DATA ..key ..$OPEN $NAME_KEY)
    $DATA ..remove-list ..$CONF_HASH ..$hash $STASH_KEY
    $DATA ..add-set ..$CONF_HASH ..$hash "$GROUP_KEY$group" >/dev/null
    $DATA ..add-list ..$OPEN ..$hash "$PROC_KEY" ${2:-e.1}
    ;;
target-add)
    _handle_target_source "$@"
    group=$($DATA ..key ..$target $NAME_KEY)
    $DATA ..remove-list ..$CONF_HASH ..$source $STASH_KEY
    $DATA ..add-set ..$CONF_HASH ..$source "$GROUP_KEY$group" >/dev/null
    $DATA ..add-list ..$target ..$source "$PROC_KEY" ${3:-e.1}
    ;;
goals)
    for g in $(_list_groups)
    do
        hashes=$($DATA ..id "m.$NAME_KEY:$g" | cut -d'|' -f1)
        test $? -eq 1 && exit
        for h in $hashes
        do
            _show_tree $h
        done
    done
    ;;
stash)
    hash=$($DATA ..id n.)
    echo "$*" | $DATA ..set ..$hash "$NAME_KEY" >/dev/null
    $DATA ..add-set ..$CONF_HASH ..$hash "$STASH_KEY"
    ;;
remove-pursuit)
    _handle_pursuit "$@"
    $DATA ..remove-ref ..$CONF_HASH $PURSUIT_KEY "$pursuit"
    ;;
remove)
    _handle_plan "$@"
    $DATA ..remove-list ..$OPEN ..$hash "$PROC_KEY"
    ;;
show-stash)
    $DATA ..show-set ..$CONF_HASH "$STASH_KEY" \
        | $DATA ..append @$NAME_KEY
    ;;
move)
    _handle_target_source "$@"
    $DATA ..remove-list ..$target ..$source "$PROC_KEY"
    $DATA ..add-list ..$OPEN ..$source "$PROC_KEY" ${3:-e.1}
    ;;
overview)
    echo not implemented
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
    _parse_plan "_.$@"
    ;;
parse-group)
    _parse_group "$@"
    ;;
append)
    $DATA ..append "$@"
    ;;
edit-note)
    _handle_note "$1"; shift
    _show_or_set $OPEN "$note" "$@" 
    ;;
show-note)
    _handle_note "$1"; shift
    _show_keys $OPEN "$note" "$@"
    ;;
*)
    _handle_plan "$@"
    test -n "$1" && shift
    $DATA .."$cmd" ..$hash "$@"
    ;;
esac

