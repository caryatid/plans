TMP=$(mktemp -d)
trap "rm -Rf $TMP" EXIT
HASH="./hash.sh -D$TMP/.hash"
DATA="./data.sh -D$TMP/.hash"
PLAN="./plan.sh -D$TMP/.hash"


# hash
echo hash
echo ----
echo foo | $HASH set n. n.name
echo bar | $HASH set n. n.name
echo more than one word | $HASH set n. n.name
ID_PREFIX=$($HASH id m.name:fo | cut -c-5)
ID_FULL=$($HASH id m.name:ar)
$HASH key $ID_PREFIX m.na
$HASH key ..$ID_FULL name
$HASH id m.name:'h.*d'
echo 
test -n "$1" && $HASH edit n. n.'space key'
$HASH list-hashes | $HASH append @name
echo radical | $HASH set n. n.'space and spaces'
$HASH id m.
$HASH delete-key m.'space.*' m.'and spaces'
$HASH id m.
$HASH ..delete m.name:foo
$HASH id m.

# data
echo 
echo data
echo ----
echo refset | $DATA ..set n. n.name
ID=$($DATA ..id m.name:refset)
$DATA add-ref ..$ID n. n.refs 'n.first ref'
$DATA add-ref ..$ID n. refs 'n.second'
$DATA add-ref ..$ID n. refs 'n.third'
$DATA ..remove-ref ..$ID refs third
$DATA ..show-refs ..$ID refs
ID_REF=$($DATA ..show-ref ..$ID refs k.second | cut -d'|' -f1)
$DATA ..index-ref ..$ID ..$ID_REF refs
echo list | $DATA ..set n. n.name
ID_LIST=$($DATA ..id m.name:list)
seq 10 | xargs -Ixx $DATA ..add-list ..$ID_LIST n. n.list-test e.1 
$DATA len ..$ID_LIST list-test
$DATA ..at-index-list ..$ID_LIST list-test s.2
$DATA ..cursor-list ..$ID_LIST list-test s.3
$DATA ..range-list ..$ID_LIST list-test c. e.3
echo boolean | $DATA ..set n. n.name
ID_BOOL=$($DATA ..id m.name:boolean)
$DATA ..bool ..$ID_BOOL n.bool
$DATA ..bool ..$ID_BOOL bool toggle

# plan
$PLAN pursuit 'n.become pirate' n.pirate
$PLAN add 'n.learn to sail'
$PLAN add 'n.crew'
$PLAN add 'n.boat'
$PLAN add 'n.materials'
$PLAN open _.materials
$PLAN move p. _.'crew'  # parent is source
$PLAN move p. _.'boat'
$PLAN stash fix door
$PLAN stash finish plan.sh
$PLAN stash usb linux
$PLAN stash computing env
$PLAN open '_.learn to sail'
$PLAN add 'n.navigation'
$PLAN add 'n.ship operation'
$PLAN add 'n.international law'
$PLAN add 'n.foreign language'
$PLAN move o. _.foreign s.0  # open is source
$PLAN open _.pirate
$PLAN show$
$PLAN show-stash