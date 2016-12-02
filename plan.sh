#!/bin/sh

_D=./.plans
seed=$(cat /dev/urandom | dd bs=255 count=1 2>/dev/null )
count=0

_gen_hash() {
    echo -n $count$seed | openssl dgst -sha1 | cut -d= -f2 | cut -c2-
    count=$(( $count + 1 ))
}

_list_hashes () {
    find "$_D" -type d | sed "s#$_D##" | sed "s#/##g" | grep -v '^..$' | uniq
}

_list_hkeys () {
    ls "$(_get_hdir $1)" | sort | xargs -L1
}

_match_hash () {
    local MATCH_N=0
    for h in $(_list_hashes)
    do
        case $h in
        $1*)
            echo $h
            MATCH_N=$(( $MATCH_N + 1 ))
            ;;
        esac
    done
    test $MATCH_N -eq 1 || return 1
    return 0
}

_match_key () {
    local MATCH_N=0
    key_match="$1"; test -z "$key_match" && key_match='.*'
    match="$2"; test -z "$match" && match='.*'
    for h in $(_list_hashes)
    do
        for k in $(_list_hkeys $h | grep "$key_match")
        do 
            grep -q "$match" $(_get_hkey $h $k) || continue
            MATCH_N=$(( $MATCH_N + 1 ))
            echo $h $k
        done
    done
    test $MATCH_N -eq 1 || return 1
    return 0
}



_unary () {
    test -z "$1" && return 1
    cmd=$1; shift
    h=$1
    test -n "$h" && shift
    case "$h" in
    *:*)
        key=$(echo $h | cut -d':' -f1)
        match=$(echo $h | cut -d':' -f2)
        hash=$(_match_key "$key" "$match" | cut -d' ' -f1)
        ;;
    _*)
        hash=$(_new_plan $(echo "$h" | cut -c2-))
        ;;
    *)
        hash=$(_match_hash $h)
        ;;
    esac
    if test $? -ne 0
    then
        echo
        for h in $hash
        do
            printf "%s %s\n" $h "$(_get_key $h name)"
        done
        return 1
    else
        $cmd $hash "$@"
    fi
    return 0
}

_binary () {
    test -z "$1" && return 1
    cmd=$1; shift
    _ERR=0
    dhash=$(_unary echo "$1") || _ERR=1
    shash=$(_unary echo "$2") || _ERR=1
    test $_ERR -eq 0 ||
        { printf "%s %s\n\n" source "$shash" destination "$dhash"; return 1 ;}
    shift; shift
    _unary $cmd $dhash $shash "$@"
}
    
_get_hdir() {  
    prefix=$(echo $1 | cut -c-2)
    suffix=$(echo $1 | cut -c3-)
    hdir="$_D/$prefix/$suffix"
    mkdir -p "$hdir"
    echo -n $hdir
}

_get_hkey() {  
    test -z "$2" && { echo must provide key; return 1 ;}
    hkey=$(_get_hdir "$1")/$2
    test -f "$hkey" || touch "$hkey"
    echo -n "$hkey"
}

_new_plan () {
    test -z "$1" && { echo 'provide a name'; return 1 ;}
    hash=$(_gen_hash)
    echo $* >$(_get_hkey $hash name)
    echo 0 >$(_get_hkey $hash status)
    echo 0 >$(_get_hkey $hash procedure_index)
    echo 'what does this plan intend to achieve?' >$(_get_hkey $hash intent)
    echo 'what, generally, does this plan intend to do?' >$(_get_hkey $hash description)
    _get_hkey $hash procedure >/dev/null
    echo $hash
}

_rm_plan () {
    rm -Rf $(_get_hdir $1)
}

_set_current () {
    echo $1 >"$_D/current"
    cat "$_D/current"
}


_to_procedure () {
    idx=$(_get_key $1 procedure_index)
    proc_f=$(_get_hkey $1 procedure)
    pre=$(head -n $idx $proc_f | grep -v $2)
    post=$(tail -n +$(( $idx + 1 )) $proc_f | grep -v $2)
    echo $pre $2 $post | tr ' ' '\n' >$proc_f
}
    
_edit_key () {
    $EDITOR "$(_get_hkey $1 $2)"
}

_get_focus () {
    idx=$(_get_key $1 procedure_index)
    test -n "$idx" && test "$idx" -gt 0 || return 1
    sed -n $(printf '%dp' $idx) "$(_get_hkey $1 procedure)"
}
    
_get_key () {
    key=intent
    test -n "$2" && key=$2
    case "$3" in
    all)
        case $key in
        procedure)
            for h in $(cat $(_get_hkey $1 $key))
            do
                printf "\t%s %s\n" $h "$(_get_key $h name)"
            done
            ;;
        *)
            cat "$(_get_hkey $1 $key)" | tr '\n' '\0' | xargs -0 -L1 printf "\t%s\n" 
            ;;
        esac
        ;;
    *)
        cat "$(_get_hkey $1 $key)" 
        ;;
    esac
}

_set_key () {
    test -z "$2" && { echo must provide key; return 1 ;}
    key="$2"
    cat - >"$(_get_hkey $1 $2)"
}

_set_idx () {
    idx=$2
    test -z "$idx" && idx=0
    test $idx -lt 0 && idx=0
    max=$(_get_key $1 procedure | wc -l)
    test $idx -gt $max && idx=$max
    echo $idx >$(_get_hkey $1 procedure_index)
}

_clear_procedure () {
    tmp=$(mktemp)
    grep -v $2 $(_get_hkey $1 procedure) >$tmp
    cat $tmp >$(_get_hkey $1 procedure)
    rm $tmp
}

_graph () {
    local pre="$2"
    local parent="$3"
    local S=''
    local F=''
    local seen=''
    n=$(_get_key $1 name)
    if test -z "$pre"
    then
        echo $1 >"$_D/seen"
        echo $n
    else
        _pre=${pre%????}
        grep -q $p "$_D/seen" && seen=x
        test "$(_get_focus $parent)" == $1 && F='>'
        test $(_get_key $1 status) -gt 0 && S='x'
        echo "${_pre}-${S:--}${F:--} ${seen:+[}$n${seen:+]}"
        test "$seen" == x && return 0
    fi
    for p in $(_get_key $1 procedure)
    do
        _graph $p "$pre|...." $1
    done
}
    
cmd=key
test -n "$1" && { cmd=$1; shift ;}
case "$cmd" in
delete)  # hash-prefix
    _unary _rm_plan "$@"
    ;;
current)  # hash-prefix
    _unary _set_current "$@"
    ;;
place)  # source:hash-prefix dest:hash-prefix  
    _binary _to_procedure "$@"
    ;;
key)  # hash-prefix -> raw data at key
    _unary _get_key "$@"
    ;;
set)  # hash-prefix
    _unary _set_key "$@"
    ;;
edit)  # hash-prefix 
    _unary _edit_key "$@"
    ;;
position)  # hash-prefix [number]
    _unary _set_idx "$@"
    ;;
advance)  # hash-prefix [number]
    amount=1
    test -n "$2" && amount=$2
    _unary _set_idx "$1" $(( $(_unary _get_key $1 procedure_index) + $amount ))
    ;;
remove)  # hash-prefix
    _binary _clear_procedure "$@"
    ;;
look)  # value-match key-match
    _match_key "$@"
    ;;
graph)  # hash-prefix
    _unary _graph "$@"
    ;;
focus)  # hash-prefix
    _unary _get_focus "$@"
    ;;
*)  # this help
    cat "$0" | grep '^[^[:space:](]\+)'
    ;;
esac

