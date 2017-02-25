TMP=$(mktemp -d)
trap "rm -Rf $TMP" EXIT
PLAN="./plan.sh -D$TMP/.hash"

# hash
echo end to end plan test
echo --------------------

$PLAN pursuit 'n.determine plan cli' 'plan'
# pursuit makes new, if necessary, pursuit entry and new
# goal, if necessary,  of the same name. 
# then adds the $hash to the pursuit goal and opens $hash
$PLAN add 'n.end to end'
# adds to group and removes from stash if it is there
$PLAN open i.e.1
$PLAN add 'n.define query language'
$PLAN add 'n.define commands'
$PLAN move o. i.e.1 e.2
$PLAN open r.^plan$
$PLAN add 'n.think about missing ideas'
$PLAN add 'n.determine types'
$PLAN add 'n.doc api'

$PLAN tree
$PLAN pursuit 'n.design the game' 'gurgeh'
$PLAN stash ensure self move works. If self move is still around
$PLAN edit-note wow meld og gurgeh and nethack like ideas
# appends to notes key
$PLAN show-note wow  # displays notes hierarchy 

$PLAN open g. 
$PLAN pursuit 'n.want' 'album' 
$PLAN add 'n.determine electronics'
$PLAN add 'n.practice fingering'.
$PLAN target-add 'r.^plan$' 'n.tests'
# opens other, adds, returns to previous open
$PLAN add 'n.experiment with rhythms via electronics'
$PLAN groups 
$PLAN pursuit 'n.wasd station' 'computing environment'
$PLAN open r.^plan$
$PLAN add 'n.move plan up and down'

$PLAN pursuit 'n.package for my toolbox' 'computing environment'
$PLAN add 'n.sources'
$PLAN add 'n.Makefile'
$PLAN overview 'computing environment'
