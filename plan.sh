#!/bin/sh

CORE=./core.sh
TMP=$($CORE temp-dir)
trap 'rm -Rf $TMP' EXIT
PDIR=$($CORE plan-dir) || { $CORE plan-dir; PDIR=$($CORE plan-dir) ;} 
HASH_X=./hash.sh
DATA_X=./data.sh

HSIZE=100
PRE_M='^__._'
PRE_P=__p_  # procedure
PRE_G=__g_  # group
PRE_S=__s_  # status

### parsing
_parse_plan () {  # PlanQ -> ParseReturn
    local hash=''
    local h="$1"
    test -n "$h" && shift
    local open=$(_get_ref __o_)
    local pattern='.*'
    echo "$h" | grep -q '^.\.' && pattern=${h#??}
    test -z "$pattern" && pattern='.*'
    case "$h" in
    .)  # current
        hash=$open
        ;;
    r.*)  # refs
        hash=$(_match_ref "$pattern")
        ;;
    i.*)  # index
        test "$pattern" = '.*' && pattern='0'
        hash=$($DATA_X lindex =$open +$PRE_P "$pattern")
        ;;
    p.*)  # parents
        local all=$($HASH_X list-hashes)
        test "$pattern" = '.*' && pattern=''
        hash=$(echo "$all" | _get_parents $open | $HASH_X id f_"$pattern")
        ;;
    c.*)  # children
        local match=$(echo $h | cut -c3-)
        test "$pattern" = '.*' && pattern=''
        hash=$($HASH_X key =$open +$PRE_P| $HASH_X id f_"$pattern")
        ;;
    t.*)  # tops
        hash=$(echo 'not implemented\nwill be shortly')
        ;;
    h.*)  # history
        local match=$(echo $h | cut -c3-)
        test "$pattern" = '.*' && pattern=''
        hash=$(cat $PDIR/history | $HASH_X id f_"$pattern")
        ;;
    *)   # pass to hash
        hash=$($HASH_X id "$h")
        ;;
    esac
    $CORE return-parse "$hash" "$h" 
}

_parse_ref () { 
    local r=${1:-'.*'}
    local open=$(_get_ref __o_)
    local ref=''
    case "$r" in
    +*)
        ref=$(echo "$r" | cut -c2-)
        _set_ref $open "$ref"
        ;;
    *)
        ref=$(ls "$PDIR/refs" | grep "$r")
        ;;
    esac
    $CORE return-parse "$ref" "$r"
}


_parse_plan_data () {
    local hash=$1
    local d=${2:-'.*'}    
    local data=''
    case "$d" in
    +*)
        $HASH_X key $hash "$data"
        ;;
    *)
        data=$($HASH_X parse-key $hash | grep -v "$PRE_M" | grep "$d")
        ;;
    esac
    $CORE return-parse "$data" "$d"
}

_parse_plan_group () { 
    local hash=$1
    local g=${2:-'.*'}
    local group=''
    case "$g" in
    +*)
        group=$(echo "$g" | cut -c2-)
        $DATA_X scard $hash "+$PRE_G$group" >/dev/null
        ;;
    *)
        group=$(_list_groups $hash | grep "$g")
        ;;
    esac
    $CORE return-parse "$group" "$g"
}

### query
_list_groups () {
    local hash=$1
    $HASH_X parse-key $1 | grep "^$PRE_G" | cut -c5-
}

_match_ref () {  # Regex -> [HashPlus]
    ls "$PDIR/refs" | grep "$1" | \
    while read n 
    do
        echo $(_get_ref "$n") | $HASH_X append $n x
    done
}

_get_parents () {  # TODO permormance
    local hash=$1
    while read h
    do
        $DATA_X key =$h +$PRE_P | grep -q $hash && echo $h | $HASH_X append name
    done
}

_rev_ref () {  # Hash -> [RefName]
    local hash=$1
    grep -F -H $hash "$PDIR/refs/"* | cut -d':' -f1 | sort | uniq
}
  
_check_status () {
    local hash=$1
    local proc=$($DATA_X key =$hash +$PRE_P)
    local status=false
    $DATA_X bool =$hash +$PRE_S >/dev/null && status=true
    if test $(echo "$proc" | wc -l) -gt 1 && test $status = true
    then
        for h in $proc
        do
            _check_status $h || return 1
        done
    elif test $status = true
    then
        return 0
    else
        return 1
    fi
}

_get_status () {
    _check_status "$1" && echo true && return 0
    echo false; return 1
}

_list_children () {  # TODO depth
    local hash=$1
    echo $hash
    for h in $($DATA_X key =$hash +$PRE_P)
    do
        _list_children $h
    done
}
    
_get_membership () {
    local hash=$1; local parent=$2
    for group in $(_list_groups $parent)
    do
        $DATA_X sfind $parent $hash $PRE_G$group >/dev/null && echo $group
    done | sort | uniq
}    

_display_list () {  # TODO move to core.sh?
    local header=${2:-''}
    local s=$(printf 's/^/%-10.10s/' "$header")
    sed "$s" $1
}

_tops () {  # TODO get into parsing
    test ! -t 0 && export FROM_STDIN=1
    $HASH_X list-hashes >$TMP/tops
    while read h
    do
        in_refs=""
        test -n "$(_rev_ref $h)" && in_refs="*"
        test -z "$(cat $TMP/tops | _get_parents $h)" && echo $h $($HASH_X key =$h name) "$in_refs"
    done <$TMP/tops
}

_display_plan () { # TODO design outputs
                   # TODO show index
    local hash=$1; local parent=$2; local type=$3
    echo $hash >$TMP/hash
    $HASH_X key $hash name >$TMP/name
    $HASH_X key $hash creation_time | cut -d, -f1 >$TMP/creation_time
    truncate -s 0 $TMP/status-line
    test -n "$parent" && _get_membership $hash $parent >$TMP/membership
    # $HASH_X list-hashes | _get_parents $hash >$TMP/parents
    $HASH_X key $hash +$PRE_P | $HASH_X append >$TMP/children
    _list_groups $hash >$TMP/groups
    _parse_plan_data $hash | grep -v -e"$(printf '%s\n' name creation_time)" >$TMP/data
    _check_status $hash && { local left='['; local right=']' ;}
    printf '%c %5.5s %c' ${left:-(} "$(cat $TMP/hash)" ${right:-)}
    printf ' %c %-23.23s %c' ${left:-(} "$(cat $TMP/name)" ${right:-)}
    printf ' %c %19.19s %c' ${left:-(} "$(cat $TMP/creation_time)" ${right:-)}

    local lists='membership children groups data'
    case $type in
    oneline)
        for n in $lists
        do
            local marker=-
            test $(wc -l $TMP/$n | cut -d' ' -f1) -ge 1 && marker=x
            printf '%1.1s[%s]' "$n" "$marker" >>$TMP/status-line
        done
        printf ' %s' "$(cat $TMP/status-line)"
        echo
        ;;
    *)
        echo
        for n in $lists
        do
            printf ' %s:\n' $n
            _display_list $TMP/$n "    "
        done
        printf '.\n'
        ;;
    esac
}

_to_list () {
    local hash=$1
    local type=${2:-full}
    local depth=${3:-0}
    local max_depth=${4:-9999}
    local parent=${5:-NONE}
    local header=${6:-.}
    test -f $TMP/seen || touch $TMP/seen
    if grep -q $hash $TMP/seen
    then
        _display_plan $hash $parent $type >$TMP/plan
        _display_list $TMP/plan "$header".
        return 0
    else
        _display_plan $hash $parent $type >$TMP/plan
        _display_list $TMP/plan "$header"\|
        echo $hash >>$TMP/seen
    fi
    for h in $($DATA_X key =$hash +$PRE_P)
    do
        _to_list $h $type $(( $depth + 1 )) $max_depth $hash "..$header"
    done
}


### operations
_set_ref () {  # Hash -> RefName -> Bool
    local hash=$1; shift
    test -z "$1" && echo must provide name && return 1
    echo $hash >"$PDIR/refs/$@"
}

_get_ref () {  # RefName -> Maybe Hash
    test -f "$PDIR/refs/$1" || return 1
    cat "$PDIR/refs/$1"
    return 0
}

_rm_ref () {  # RefName -> Bool
    test -f "$PDIR/refs/$1" || return 1
    rm "$PDIR/refs/$1"
    return 0
}

_organize () {  # Hash -> Bool
    local hash=$1
    for h in $($DATA_X key =$hash +$PRE_P)
    do
        echo $h $($HASH_X key =$h name) >>$TMP/proc
    done
    $EDITOR $TMP/proc
    cat $TMP/proc | cut -d' ' -f1 | $HASH_X set =$hash $PRE_P
    while read l
    do
        h=$(echo $l | cut -d' ' -f1)
        echo $l | tr -s ' ' | cut -d' ' -f2- | $HASH_X set =$h name
    done <$TMP/proc
}    


_add_to_history () {  # TODO good cause for file locking review
    local hash=$1
    echo $hash >>$PDIR/history
    tail -n$HSIZE $PDIR/history | cat -n - | sort -k2 -u | sort -n \
        | xargs -L1 | cut -d' ' -f2 >$TMP/histcull
    cp $TMP/histcull $PDIR/history
}

_handle_plan () {  # query -> header
    local header=$($CORE make-header plan "$2")
    hash=$(_parse_plan "$1") || { $CORE err-msg "$hash" "$header" $?; exit 1 ;}
    _add_to_history $hash
}

_handle_plan_key () {
    _handle_plan "$1" "$3"
    local header=$($CORE make-header key "$3")
    key=$($HASH_X parse-key =$hash "$2") || { $CORE err-msg "$key" "$header" $?; exit 1 ;}
}

_handle_ref () {
    local header=$($CORE make-header ref "$2")
    ref=$(_parse_ref "$1") || { $CORE err-msg "$ref" "$header" $?; exit 1 ;}
}

_handle_plan_ref () {
    _handle_plan "$1" "$3"
    _handle_ref "$2" "$3"
}

_handle_target_source () {
    _handle_plan "$1" "$3"; target=$hash
    _handle_plan "$2" "$3"; source=$hash
}

_handle_target_source_group () {
    _handle_plan "$1" "$4"; target=$hash
    _handle_plan "$2" "$4"; source=$hash
    local header=$($CORE make-header group "$4")
    group=$(_parse_plan_group $target "$3") || { $CORE err-msg "$group" "$header" $?; exit 1 ;}
}

_handle_target_source_destination () {
    _handle_plan "$1" "$4"; target=$hash
    _handle_plan "$2" "$4"; source=$hash
    _handle_plan "$3" "$4"; destination=$hash
}
    
_handle_plan_data () {
    _handle_plan "$1" "$3"
    local header=$($CORE make-header available-data "$3")
    data=$(_parse_plan_data $hash "$2") || { $CORE err-msg "$data" "$header" $?; exit 1 ;}
}

test -n "$1" && { cmd=$1; shift ;}
case ${cmd:-''} in
rm-ref)
    _handle_ref "$@"
    _rm_ref "$ref"
    ;;
open) 
    _handle_plan "$@"
    _set_ref $hash __o_
    ;;
data)
    _handle_plan_data "$@"
    echo $data
    ;;
organize)
    _handle_plan "$@"
    _organize $hash
    ;;
ref)
    _handle_plan_ref "$@"
    _set_ref $hash "$ref"
    ;;
status)
    _handle_plan "$1"
    $DATA_X bool =$hash +$PRE_S "$2"
    ;;
advance)
    _handle_plan "$1"
    $DATA_X lpos =$hash +$PRE_P $2
    ;;
remove)
    _handle_target_source "$@"
    $DATA_X lrem =$target =$source +$PRE_P
    ;;
add)
    _handle_target_source "$1" "$2"
    $DATA_X linsert =$target =$source +$PRE_P $3
    ;;
move)
    _handle_target_source_destination "$@"
    $DATA_X linsert =$destination =$source +$PRE_P $4
    $DATA_X lrem =$target =$source +$PRE_P 
    ;;
group-member)
    _handle_target_source_group "$@"
    $DATA_X sfind =$target =$source $PRE_G$group
    ;;
group-add)
    _handle_target_source_group "$@"
    $DATA_X sadd =$target =$source $PRE_G$group
    ;;
group-remove)
    _handle_target_source_group "$@"
    $DATA_X srem =$target =$source $PRE_G$group
    ;;
archive)
    file=$(readlink -f ${1:-$HOME}/plan_archive_$(basename "$PWD").tgz)
    cd "$PDIR"
    tar -czf "$file" .
    ;;
help)
    echo you are currently helpless
    ;;
list)
    _handle_plan "$1"
    shift
    _to_list $hash "$@"
    ;;

hash)
    test -z "$1" && { echo command required; exit 1 ;}
    cmd="$1"; shift
    _handle_plan "$1"; shift
    $HASH_X $cmd =$hash "$@"
    ;;
*)
    _handle_plan_key "$1" "$cmd"; shift
    if test -t 0 && test -z "$1"
    then
        $HASH_X edit =$hash +$key
    elif test -n "$1"
    then
        echo "$@" | $HASH_X set =$hash +$key
    else
        $HASH_X set =$hash +$key
    fi
    ;;
esac

