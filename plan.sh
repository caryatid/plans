#!/bin/sh


_match_name () {
    local match="$1"
    ls $(_get_plan_dir)/refs | grep ${match:-'.*'} | \
    while read n 
    do
        echo $(_get_ref "$n") $n
    done
}

_match_history () {
    local match=$1
    cat $(_get_plan_dir)/history | grep ${match:-'.*'}
}

_get_parents () {
    local hash=$1
    for h in $($HASH_X list-hashes)
    do
        $DATA_X key =$h +__procedure__ | grep -q $1 && echo $h $($HASH_X key =$h name)
    done
}
  
_parse_plan () {
    local hash=''
    local h="$1"
    test -n "$h" && shift
    case "$h" in
    .)
        hash=$(_get_ref __open__)
        ;;
    n.*)  # ref-name
        local match=$(echo $h | cut -c3-)
        hash=$(_match_name $match)
        ;;
    i.*)
        hash=$($DATA_X lindex =$(_get_ref __open__) __procedure__ $(echo $h | cut -c3-))
        ;;
    h.*)  # history
        local match=$(echo $h | cut -c3-)
        hash=$(_match_history $match)
        ;;
    s.*)  # stash
        echo foo
        ;;
    *)   # pass to hash
        hash=$($HASH_X id "$h")
        ;;
    esac
    _return_parse "$hash" "$h"    
}


_set_ref () {
    test -z "$2" && echo must provide name && return 1
    echo $1 >"$(_get_plan_dir)/refs/$2"
}

        
_get_ref () {
    local P=$(_get_plan_dir)
    test -f "$P/refs/$1" || return 1
    cat "$P/refs/$1"
    return 0
}

_rm_ref () {
    local P=$(_get_plan_dir)
    test -f "$P/refs/$1" || return 1
    rm "$P/refs/$1"
    return 0
}

_get_status () {
    local hash=$1
    local s=$($HASH_X key =$hash +__status__)
    echo $s | grep -qi true && echo $s && return 0
    echo $s && return 1
}

_gen_status () {
    local parent=$1
    local hash=$2
    local m=-; local i=-; local s=-;
    test -n "$($DATA_X sin =$parent =$hash +__milestone__)" && m=x
    test $hash = "$($DATA_X lindex =$parent +__procedure__)" && i=o
    _get_status $hash >/dev/null && s=x
    echo \[${m}${i}\[${s}\]
}
    

_to_list () {
    local hash=$1
    local max_depth=${2:-9999}
    if test -n "$3"
    then
        local arrow="$3"
        local status="$4"
        local tmp="$5"
        local depth="$6"
    else
        printf ' %0.0s' $(seq 5)
        local arrow=':'
        local status='[mi[s]'
        local tmp=$(mktemp)
        local depth=0
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
        _to_list $h $max_depth "--|$arrow" "$(_gen_status $hash $h)" $tmp $(( $depth + 1 ))
        i=$(( $i + 1 ))
    done
    test $depth -eq 0 && rm $tmp
}
        
_organize () {
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
init) 
    _init_plan_dir "$PWD/.plans"
    ;;
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
intent)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    $HASH_X edit =$hash +__intent__
    ;;
set-status)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    echo "$2" | $HASH_X set =$hash +__status__
    ;;
status)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    ;;
milestone)
    thash=$(_parse_plan "$1") || _err_multi hash "$thash" $?
    shash=$(_parse_plan "$2") || _err_multi hash "$shash" $?
    $DATA_X sadd =$thash =$shash +__milestone__
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
    echo $($DATA_X lfind $hash $cur __procedure__) $(_gen_status $hash $cur) \
        $(echo $cur | cut -c-5) $($HASH_X key $cur name)
    ;;
parents)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    _get_parents $hash
    ;;
stash)
    echo not implemented
    ;;
organize)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    _organize $hash
    ;;
display)
    hash=$(_parse_plan "$1") || _err_multi hash "$hash" $?
    _to_list $hash 
    ;;
tops)
    tmp=$(mktemp)
    for h in $($HASH_X list-hashes)
    do
        test -z "$(_get_parents $h)" && echo $h $($HASH_X key $h name)
    done
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

