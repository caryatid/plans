test -z "$1" && { echo please provide script file; exit 1 ;}
export PREV=0; sh -x "$1" 2>&1 >/dev/null | while read ln
do
    CUR=$(./ts | tr -d '.')
    DIF=$(printf '%s' $(printf "%016d" $(( $CUR - $PREV )) | sed 's/......$/.&/'))
    echo $CUR $DIF "$ln"
    PREV=$CUR
 done                                                
