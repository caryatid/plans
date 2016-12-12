_unary () {
    test -z "$1" && return 1
    local cmd=$1; shift
    local h=${1:-''}
    test -n "$h" && shift
    local hash=$($HASH_X id "$h")
    test -n "$1" && { local key="$1"; shift ;}
    test -z "$key" && key='.*'
    if test $(echo "$hash" | wc -l) -eq 1
    then
        _key="$key"
        key=$($HASH_X keys $hash | grep "^$_key\$")
        test -z "$key" && key="$_key"
        local mnum=$(echo "$key" | wc -l)
        if test "$mnum" -le 1
        then
            $cmd $hash "$key" "$@" && echo $cmd $hash $key "$@" >>$($PDIR_X)/history
            return 0
        fi
        echo $hash
        echo "$key"
        return 1
    fi
    echo "$hash" 
    return 1
}

_binary () {
    test -z "$1" && return 1
    cmd="$1"; shift
    _ERR=0
    local thash=$1; test -n $thash && shift
    local shash=$1; test -n $shash && shift
    local key=$1; test -n $key && shift
    thash=$(_unary echo "$thash" "$key") || _ERR=1
    shash=$(_unary echo "$shash" "$key") || _ERR=1
    test $_ERR -eq 0 ||
        { printf "%s\n%s\n\n" source "$shash" target "$thash"; return 1 ;}
    thash=$(echo $thash | cut -d' ' -f1)
    shash=$(echo $shash | cut -d' ' -f1)
    _unary "$cmd" $thash $shash $key "$@"
}

_set_get () {
    local hash=$1
    local name=$2
    local tmp=$(mktemp)
    $HASH_X key $hash $name 
}

_set_add () {
    local thash=$1
    local shash=$2
    local name=$3
    local tmp=$(mktemp)
    $HASH_X key $thash $name >$tmp
    echo $shash $(cat $tmp) | tr ' ' '\n' | sort | uniq \
        | $HASH_X set $thash $name
    rm $tmp
}

_set_rem () {
    local thash=$1
    local shash=$2
    local name=$3
    local tmp=$(mktemp)
    $HASH_X key $thash $name >$tmp
    cat $tmp | grep -v $shash | $HASH_X set $thash $name
    rm $tmp
}

_list_set_index () {
    local hash=$1
    local name=$2
    local nidx="$3"
    local idx=$($HASH_X key $hash $name.i)
    test -z "$idx" && idx=0
    case "$nidx" in
    +*)
        idx=$(echo $(( $idx + $(echo $nidx | cut -c2-) )))
        ;;
    -*)
        idx=$(( $idx - $(echo $nidx | cut -c2-) ))
        ;;
    =*)
        idx=$(echo $nidx | cut -c2-)
        ;;
    '')
        idx=$(( $idx + 1 ))
        ;;
    *)
        echo $nidx is not an understood index
        return 1
        ;;
    esac
    test $idx -lt 0 && idx=0
    local max=$($HASH_X key $1 "$name" | wc -l) 
    test $idx -gt $max && idx=$max
    echo $idx | $HASH_X set $1 $name.i
}

_list_insert () {
    local thash=$1
    local shash=$2
    local name=$3
    local idx=$($HASH_X key $thash $name.i)
    test -z "$idx" && idx=0 
    test $idx -ne 0 && idx=$(( $idx - 1 ))
    local tmp=$(mktemp)
    $HASH_X key $thash $name >$tmp
    echo $(head -n$idx $tmp) $shash $(tail -n+$(( $idx + 1 )) $tmp) | tr ' ' '\n' \
        | $HASH_X set $thash $name
    rm $tmp
}

_list_range () {
    local hash=$1
    local name=$2
    local lower=$3
    local upper=$4
    lower=${lower:-1}
    upper=${upper:-\$}
    sed_e=$(printf '%s,%sp' $lower "$upper")
    $HASH_X key $hash $name | sed -n "$sed_e"
}

_list_index () {
    local hash=$1
    local name=$2
    local index=$3
    index=${index:-$($HASH_X key $hash $name.i)}
    sed_e=$(printf '%sp' $index)
    $HASH_X key $hash $name | sed -n "$sed_e"
}

_list_len () {
    local hash=$1
    local name=$2
    $HASH_X key $hash $name | wc -l
}

. ./config.sh

cmd=get
test -n "$1" && { cmd=$1; shift ;}
case $cmd in 
smembers)
    _unary _set_get "$@"
    ;;
sadd)
    _binary _set_add "$@"
    ;;
srem)
    _binary _set_rem "$@"
    ;;
scard)
    _unary _set_get "$@" | wc -l
    ;;
lpos)
    _unary _list_set_index "$@"
    ;;
lindex)
    _unary _list_index "$@"
    ;;
linsert)
    _binary _list_insert "$@"
    ;;
lrange)
    _unary _list_range "$@"
    ;;
llen)
    _unary _list_len "$@"
    ;;
*)
    _unary "$HASH_X $cmd" "$@"
    ;;
esac

