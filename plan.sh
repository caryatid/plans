#!/bin/sh

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
    _return_parse "$hash" "$h" 
}

### query
_match_ref () {  # Regex -> [HashPlus]
    ls $(_get_plan_dir)/refs | grep "$1" | \
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
    local P=$(_get_plan_dir)
    grep -F -H $hash "$P/refs/"* | cut -d':' -f1 | sort | uniq
}
  
_gen_status () {  # Hash -> Hash -> StatusString
    local parent=$1
    local hash=$2
    local c=-; local i=''; local s=-;
    test $($DATA_X key =$hash +__procedure__ | wc -l) -gt 1 && c=x
    test $hash = "$($DATA_X lindex =$parent +__procedure__)" && i=x
    _get_status $hash >/dev/null
    case $? in
    0)
        s=o
        ;;
    2)
        s=x
        ;;
    esac
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
        local tmp="$5"; local depth="$6"
    else
        printf ' %0.0s' $(seq 5)
        local arrow='|'; local status='[cs]'
        local tmp=$(mktemp); local depth=0
    fi
    local key=$($HASH_X key =$hash name)
    if grep -q $hash $tmp
    then
        printf  '%s |%s [%s]\n' "$status" "$arrow" "$key"
        return 1
    else
        printf  '%s |%s %s\n' "$status" "$arrow" "$key"
    fi
    echo $hash >>$tmp
    test $depth -ge $max_depth && return 1
    local i=1
    for h in $($DATA_X key =$hash +__procedure__)
    do
        printf '%3d] ' $i
        _to_list $h $max_depth "..|$arrow" "$(_gen_status $hash $h)" $tmp $(( $depth + 1 ))
        i=$(( $i + 1 ))
    done
    test $depth -eq 0 && rm $tmp
}

### operations
_set_ref () {  # Hash -> RefName -> Bool
    local hash=$1; shift
    test -z "$1" && echo must provide name && return 1
    echo $hash >"$(_get_plan_dir)/refs/$@"
}

_get_ref () {  # RefName -> Maybe Hash
    local P=$(_get_plan_dir)
    test -f "$P/refs/$1" || return 1
    cat "$P/refs/$1"
    return 0
}

_rm_ref () {  # RefName -> Bool
    local P=$(_get_plan_dir)
    test -f "$P/refs/$1" || return 1
    rm "$P/refs/$1"
    return 0
}


        
_organize () {  # Hash -> Bool
    local hash=$1
    tmp=$(mktemp)
    for h in $($DATA_X key =$hash +__procedure__)
    do
        echo $h $($HASH_X key =$h name) >>$tmp
    done
    $EDITOR $tmp
    cat $tmp | cut -d' ' -f1 | $HASH_X set =$hash __procedure__
    while read l
    do
        h=$(echo $l | cut -d' ' -f1)
        echo $l | tr -s ' ' | cut -d' ' -f2- | $HASH_X set =$h name
        
    done <$tmp
    rm $tmp
}    

. ./config.sh

test -n "$1" && { cmd=$1; shift ;}
case ${cmd:-''} in
rm-ref)
    _rm_ref "$1"
    ;;
open) 
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    _set_ref $hash __open__
    ;;
data)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    $HASH_X parse-key =$hash 
    ;;
organize)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    _organize $hash
    ;;
ref)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    shift
    _set_ref $hash "$@"
    ;;
status)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    $DATA_X bool $hash +__status__ $2
    ;;
advance)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    $DATA_X lpos =$hash +__procedure__ $2
    ;;
remove)
    thash=$(_parse_plan "$1") || _err_multi hash "$thash" $?
    shash=$(_parse_plan "$2") || _err_multi hash "$shash" $?
    $DATA_X slrem =$thash =$shash +__procedure__
    ;;
add)
    thash=$(_parse_plan "$1") || _err_multi hash "$thash" $?
    shash=$(_parse_plan "$2") || _err_multi hash "$shash" $?
    $DATA_X linsert =$thash =$shash +__procedure__ $3
    ;;
move)
    thash=$(_parse_plan "$1") || _err_multi hash "$thash" $?
    shash=$(_parse_plan "$2") || _err_multi hash "$shash" $?
    dhash=$(_parse_plan "$3") || _err_multi hash "$dhash" $?
    $DATA_X linsert =$dhash =$shash +__procedure__ e.1
    $DATA_X slrem =$thash =$shash +__procedure__
    ;;
tops)
    tmp=$(mktemp)
    all=$($HASH_X list-hashes)
    for h in $all
    do
        in_refs=""
        test -n "$(_rev_ref $h)" && in_refs="*"
        test -z "$(echo "$all" | _get_parents $h)" && echo $h $($HASH_X key =$h name) "$in_refs"
    done
    ;;
archive)
    file=$(readlink -f ${1:-$HOME/pa}_$(basename "$PWD").tgz)
    pd=$(_get_plan_dir)
    cd "$pd"
    tar -czf "$file" .
    ;;
help)
    echo you are currently helpless
    ;;
'')
    hash=$(_parse_plan ".") || _err_multi hash "$hash" $?
    _to_list $hash 1
    ;;
*)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    shift
    key=$($HASH_X parse-key =$hash "$cmd") || _err_multi key "$key" $?
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
