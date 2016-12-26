#!/bin/sh

CORE=./core.sh
TMP=$($CORE temp-dir)
trap 'rm -Rf $TMP' EXIT
PDIR=$($CORE plan-dir) || { $CORE plan-dir; PDIR=$($CORE plan-dir) ;} 
HASH_X=./hash.sh
DATA_X=./data.sh

### parsing
_parse_plan () {  # PlanQ -> ParseReturn
    local hash=''
    local h="$1"
    test -n "$h" && shift
    local open=$(_get_ref __open__)
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
        hash=$($DATA_X lindex =$open __procedure__ "$pattern")
        ;;
    p.*)  # parents
        local all=$($HASH_X list-hashes)
        test "$pattern" = '.*' && pattern=''
        hash=$(echo "$all" | _get_parents $open | $HASH_X id f_"$pattern")
        ;;
    c.*)  # children
        local match=$(echo $h | cut -c3-)
        test "$pattern" = '.*' && pattern=''
        hash=$($HASH_X key =$open __procedure__ | $HASH_X id f_"$pattern")
        ;;
    t.*)  # tops
        hash=$(printf '%s\n' not implemented)
        ;;
    h.*)  # history
        hash=$(printf '%s\n' not implemented)
        ;;
    *)   # pass to hash
        hash=$($HASH_X id "$h")
        ;;
    esac
    $CORE return-parse "$hash" "$h" 
}

_parse_ref () { # TODO new-ref with hash id? maybe current?
    local r=${1:-'.*'}
    local ref=''
    case "$r" in
    +*)
        ref=$(echo "$r" | cut -c2-)
        _set_ref "" "$ref"
        ;;
    *)
        ref=$(ls "$PDIR/refs" | grep "$r")
        ;;
    esac
    $CORE return-parse "$ref" "$r"
}

### query
_match_ref () {  # Regex -> [HashPlus]
    ls "$PDIR/refs" | grep "$1" | \
    while read n 
    do
        echo $(_get_ref "$n") | $HASH_X append $n x
    done
}

_match_history () {  # TODO  Regex -> [HashPlus]
    echo history
    echo not implemented
}

_get_parents () {  # Hash -> [HashPlus]
    local hash=$1
    while read h
    do
        $DATA_X key =$h +__procedure__ | grep -q $hash && echo $h | $HASH_X append name
    done
}

_rev_ref () {  # Hash -> [RefName]
    local hash=$1
    grep -F -H $hash "$PDIR/refs/"* | cut -d':' -f1 | sort | uniq
}
  
_check_status () {
    local hash=$1
    local proc=$($DATA_X key =$hash +__procedure__)
    status=false
    $DATA_X bool =$hash +__status__ "$2" >/dev/null && status=true
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

_gen_status () {  # Hash -> Hash -> StatusString
    local parent=$1
    local hash=$2
    local c=-; local i=''; local s=-;
    test $hash = "$($DATA_X lindex =$parent +__procedure__)" && i=x
    $DATA_X bool =$hash +__status__ "$2" >/dev/null
    _check_status $hash && s=x    
    if test -n "$i"
    then
        echo \[${c}${s}\]
    else
        echo \(${c}${s}\)
    fi
}
    
_list_children () {  # Hash -> [Hash]
    local hash=$1
    echo $hash
    for h in $($DATA_X key =$hash +__procedure__)
    do
        _list_children $h
    done
}
    
_to_list () {  # TODO think about this one
    local hash=$1
    local max_depth=${2:-9999}
    if test -n "$3"
    then
        local arrow="$3"; local status="$4"
        local depth="$5"
    else
        printf ' %0.0s' $(seq 5)
        local arrow='|'; local status='[cs]'
        local depth=0
        truncate -s 0 $TMP/seen
    fi
    local key=$($HASH_X key =$hash name)
    if grep -q $hash $TMP/seen
    then
        printf  '%s |%s [%s]\n' "$status" "$arrow" "$key"
        return 1
    else
        printf  '%s |%s %s\n' "$status" "$arrow" "$key"
    fi
    echo $hash >>$TMP/seen
    test $depth -ge $max_depth && return 1
    local i=1
    for h in $($DATA_X key =$hash +__procedure__)
    do
        printf '%3d] ' $i
        _to_list $h $max_depth "..|$arrow" "$(_gen_status $hash $h)" $(( $depth + 1 ))
        i=$(( $i + 1 ))
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
    for h in $($DATA_X key =$hash +__procedure__)
    do
        echo $h $($HASH_X key =$h name) >>$TMP/proc
    done
    $EDITOR $TMP/proc
    cat $TMP/proc | cut -d' ' -f1 | $HASH_X set =$hash __procedure__
    while read l
    do
        h=$(echo $l | cut -d' ' -f1)
        echo $l | tr -s ' ' | cut -d' ' -f2- | $HASH_X set =$h name
    done <$TMP/proc
}    

_tops () {
    test ! -t 0 && export FROM_STDIN=1
    $HASH_X list-hashes >$TMP/tops
    while read h
    do
        in_refs=""
        test -n "$(_rev_ref $h)" && in_refs="*"
        test -z "$(cat $TMP/tops | _get_parents $h)" && echo $h $($HASH_X key =$h name) "$in_refs"
    done <$TMP/tops
}

_handle_plan () {  # query -> header
    local header=$($CORE make-header plan "$2")
    hash=$(_parse_plan "$1") || { $CORE err-msg "$hash" "$header" $?; exit 1 ;}
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

_handle_target_source_destination () {
    _handle_plan "$1" "$4"; target=$hash
    _handle_plan "$2" "$4"; source=$hash
    _handle_plan "$3" "$4"; destination=$hash
}
    

test -n "$1" && { cmd=$1; shift ;}
case ${cmd:-''} in
rm-ref)
    _handle_ref "$@"
    _rm_ref "$ref"
    ;;
open) 
    _handle_plan "$@"
    _set_ref $hash __open__
    ;;
data)
    _handle_plan "$@"
    $HASH_X parse-key =$hash 
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
    $DATA_X bool =$hash +__status__ "$2"
    ;;
advance)
    _handle_plan "$1"
    $DATA_X lpos =$hash +__procedure__ $2
    ;;
remove)
    _handle_target_source "$@"
    $DATA_X lrem =$target =$source +__procedure__
    ;;
add)
    _handle_target_source "$1" "$2"
    $DATA_X linsert =$target =$source +__procedure__ $3
    ;;
move)
    _handle_target_source_destination "$@"
    $DATA_X linsert =$destination =$source +__procedure__ e.1
    $DATA_X lrem =$target =$source +__procedure__
    ;;
tops)
    _tops
    ;;
archive)
    file=$(readlink -f ${1:-$HOME/pa}_$(basename "$PWD").tgz)
    cd "$PDIR"
    tar -czf "$file" .
    ;;
help)
    echo you are currently helpless
    ;;
list)
    _handle_plan "$1"
    _to_list $hash
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

# TODO groups instead of milestones -- 
# any plan can create a named  "set" that 
# becomes a remembered group name