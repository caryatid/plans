#!/bin/sh

### parsing
_parse_plan () {  # PlanQ -> ParseReturn
    local hash=''
    local h="$1"
    test -n "$h" && shift
    local limit=''
    echo $h | grep -q ^f_ && h=$(echo $h | cut -c3-) && limit=on
    case "$h" in
    .)
        hash=$(_get_ref __open__)
        ;;
    n.*)  # ref-name
        local match=$(echo $h | cut -c3-)
        hash=$(_match_ref $match)
        ;;
    i.*)
        hash=$($DATA_X lindex =$(_get_ref __open__) __procedure__ $(echo $h | cut -c3-))
        ;;
    h.*)  # history
        local match=$(echo $h | cut -c3-)
        hash=$(_match_history $match)
        ;;
    *)   # pass to hash
        hash=$($HASH_X id "$h")
        ;;
    esac
    test -n "$limit" && hash=$(echo "$hash" | grep -F -e"$(_list_children $(_get_ref __open__))")
    _return_parse "$hash" "$h"    
}

### query
_match_ref () {  # Regex -> [HashPlus]
    local match="$1"
    ls $(_get_plan_dir)/refs | grep ${match:-'.*'} | \
    while read n 
    do
        echo $(_get_ref "$n") $n
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
        $DATA_X key =$h +__procedure__ | grep -q $hash && echo $h $($HASH_X key =$h name)
    done
}

_rev_ref () {  # Hash -> [RefName]
    local hash=$1
    local P=$(_get_plan_dir)
    local ret=1
    for r in $(ls "$P/refs")
    do
        if grep -q $hash "$P/refs/$r"
        then
            ret=0
            echo $r
        fi
    done
    return $ret
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
    test -z "$2" && echo must provide name && return 1
    echo $1 >"$(_get_plan_dir)/refs/$2"
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

_get_status () {  # Hash -> Status
    local hash=$1
    local s=$($HASH_X key =$hash +__status__)
    echo $s
    echo $s | grep -qi '^true' && return 0
    echo $s | grep -qi '^false' && return 2
    return 1
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
open) 
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    _set_ref $hash __open__
    ;;
ref)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    _set_ref $hash "$2"
    ;;
rm-ref)
    _rm_ref "$1"
    ;;
name)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    test -n "$1" && shift
    test -z "$1" && $DATA_X key =$hash +name && exit 1
    echo "$@" | $HASH_X set =$hash +name
    ;;
data)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    $HASH_X parse-key =$hash | grep -v '^__'
    ;;
n)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    $HASH_X edit =$hash +notes
    ;;
d)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    $HASH_X edit =$hash +description
    ;;
set-status)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    echo "$2" | $HASH_X set =$hash +__status__
    ;;
status)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    _get_status $hash
    ;;
add)
    thash=$(_parse_plan "$1") || _err_multi hash "$thash" $?
    shash=$(_parse_plan "$2") || _err_multi hash "$shash" $?
    $DATA_X linsert =$thash =$shash +__procedure__ $3
    ;;
remove)
    thash=$(_parse_plan "$1") || _err_multi hash "$thash" $?
    shash=$(_parse_plan "$2") || _err_multi hash "$shash" $?
    $DATA_X slrem =$thash =$shash +__procedure__
    ;;
move)
    thash=$(_parse_plan "$1") || _err_multi hash "$thash" $?
    shash=$(_parse_plan "$2") || _err_multi hash "$shash" $?
    dhash=$(_parse_plan "$3") || _err_multi hash "$dhash" $?
    $DATA_X linsert =$dhash =$shash +__procedure__
    $DATA_X slrem =$thash =$shash +__procedure__
    ;;
advance)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    $DATA_X lpos =$hash +__procedure__ $2
    ;;
current)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    cur=$($DATA_X lindex =$hash +__procedure__ +0)
    test -z "$cur" && exit 1
    echo $($DATA_X lfind =$hash $cur __procedure__) $(_gen_status =$hash $cur) \
        $(echo $cur | cut -c-5) $($HASH_X key =$cur name)
    ;;
parents)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    $HASH_X list-hashes | _get_parents $hash 
    ;;
organize)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    _organize $hash
    ;;
list-children)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    _list_children $hash 
    ;;
display)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    _to_list $hash $2
    ;;
tops)
    tmp=$(mktemp)
    all=$($HASH_X list-hashes)
    for h in $all
    do
        in_refs=""
        _rev_ref $h >/dev/null && in_refs="*"
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
    $DATA_X $cmd =$hash "$@"
    ;;
esac

