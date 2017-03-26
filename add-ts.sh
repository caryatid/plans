test -z "$1" && { echo please provide script file; exit 1 ;}
SWITCH=''
START=$(./timestamp | tr -d '.')
export PREV=$START; sh -x "$1" 2>&1 >/dev/null | while read ln
do
    CUR=$(./timestamp | tr -d '.')
    DIF=$(printf '%s' $(printf "%08d" $(( $CUR - $PREV )) | sed 's/......$/.&/'))
    TOT=$(printf '%s' $(printf "%10d" $(( $CUR - $START )) | sed 's/......$/.&/'))
    if test -z "$SWITCH"
    then
        OUT="$ln"
        SWITCH=1
    else
        echo $CUR $DIF $TOT "$OUT"
        SWITCH=''
    fi
    PREV=$CUR
 done                                                
test -n "$SWITCH" && echo $CUR $DIF $TOT "$OUT"
